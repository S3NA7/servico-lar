-- Testes pgTAP das regras de negócio (transições, conflitos, expiração, avaliações)
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Helpers --------------------------------------------------------------------
create or replace function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

-- Próxima segunda-feira às 09:00 (horário de atendimento do Carlos).
create or replace function pg_temp.next_monday_at(p_hour int) returns timestamptz language sql as $$
  select ((date_trunc('week', (now() at time zone 'America/Sao_Paulo')::date + 7)::date)::timestamp
          + make_interval(hours => p_hour)) at time zone 'America/Sao_Paulo';
$$;

-- IDs do seed
\set cliente  '11111111-1111-1111-1111-111111111111'
\set carlos   '22222222-2222-2222-2222-222222222222'
\set ana      '33333333-3333-3333-3333-333333333333'
\set servico  'aaaaaaaa-0000-0000-0000-000000000001'

-- 1. Cliente cria solicitação válida --------------------------------------------
select pg_temp.login(:'cliente');
select lives_ok(
  $$ select public.create_service_request('aaaaaaaa-0000-0000-0000-000000000001', pg_temp.next_monday_at(9), 'Teste') $$,
  'cliente cria solicitação em horário livre'
);
select is(
  (select status from public.service_requests where client_id = :'cliente' limit 1),
  'pending'::public.request_status,
  'nova solicitação nasce pendente'
);
select is(
  (select ends_at - starts_at from public.service_requests where client_id = :'cliente' limit 1),
  interval '60 minutes',
  'ends_at calculado pela duração do serviço'
);

-- 2. Conflito de horário (Review Focus 3) -------------------------------------
select throws_ok(
  $$ select public.create_service_request('aaaaaaaa-0000-0000-0000-000000000001', pg_temp.next_monday_at(9), null) $$,
  '23P01',
  null,
  'segunda solicitação no mesmo horário viola a exclusion constraint'
);
select throws_ok(
  $$ select public.create_service_request('aaaaaaaa-0000-0000-0000-000000000002', pg_temp.next_monday_at(9) + interval '30 minutes', null) $$,
  '23P01',
  null,
  'sobreposição parcial também é bloqueada'
);

-- 3. Fora do horário de atendimento / horário passado ------------------------
select throws_ok(
  $$ select public.create_service_request('aaaaaaaa-0000-0000-0000-000000000001', pg_temp.next_monday_at(6), null) $$,
  'P0001',
  'Fora do horário de atendimento do profissional',
  'horário fora da disponibilidade é recusado'
);
select throws_ok(
  $$ select public.create_service_request('aaaaaaaa-0000-0000-0000-000000000001', now() - interval '1 day', null) $$,
  'P0001',
  'Esse horário já passou',
  'horário no passado é recusado'
);

-- 4. Transições --------------------------------------------------------------
-- cliente não pode aceitar
select throws_ok(
  $$ update public.service_requests set status = 'accepted' where client_id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'cliente não pode aceitar a própria solicitação'
);
select pg_temp.logout();

-- profissional aceita
select pg_temp.login(:'carlos');
select lives_ok(
  $$ update public.service_requests set status = 'accepted' where professional_id = '22222222-2222-2222-2222-222222222222' and status = 'pending' $$,
  'profissional aceita solicitação pendente'
);

-- Review Focus 4: concluir antes do início
select throws_ok(
  $$ update public.service_requests set status = 'completed' where professional_id = '22222222-2222-2222-2222-222222222222' and status = 'accepted' $$,
  'P0001',
  'Só é possível concluir após o horário de início',
  'não conclui antes do horário de início'
);
-- transição inválida
select throws_ok(
  $$ update public.service_requests set status = 'pending' where professional_id = '22222222-2222-2222-2222-222222222222' and status = 'accepted' $$,
  'P0001',
  null,
  'accepted -> pending é transição inválida'
);
select pg_temp.logout();

-- 5. Expiração ---------------------------------------------------------------
-- Insere pendente antiga diretamente (como postgres), com respond_by no passado.
insert into public.service_requests (id, service_id, client_id, professional_id, starts_at, ends_at, status, respond_by, created_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', :'servico', :'cliente', :'carlos',
        pg_temp.next_monday_at(13), pg_temp.next_monday_at(14), 'pending', now() - interval '1 hour', now() - interval '25 hours');

select pg_temp.login(:'cliente');
select throws_ok(
  $$ update public.service_requests set status = 'expired' where id = 'bbbbbbbb-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'usuário não marca expiração manualmente'
);
select is(public.expire_pending_requests(), 1, 'função expira exatamente a pendente vencida');
select is(
  (select status from public.service_requests where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'expired'::public.request_status,
  'pendente vencida ficou expired'
);
select pg_temp.logout();

-- 6. Avaliações (Review Focus 5) ----------------------------------------------
-- Atendimento concluído no passado, inserido diretamente.
insert into public.service_requests (id, service_id, client_id, professional_id, starts_at, ends_at, status, respond_by, created_at)
values ('cccccccc-0000-0000-0000-000000000001', :'servico', :'cliente', :'carlos',
        now() - interval '3 days', now() - interval '3 days' + interval '1 hour', 'completed', now() - interval '4 days', now() - interval '5 days');

select pg_temp.login(:'cliente');
-- avaliar solicitação apenas aceita (a de 09:00) deve falhar
select throws_ok(
  $$ insert into public.reviews (request_id, client_id, professional_id, rating)
     select id, client_id, professional_id, 5 from public.service_requests where status = 'accepted' limit 1 $$,
  'P0001',
  'Só é possível avaliar atendimentos concluídos',
  'não avalia atendimento não concluído'
);
select lives_ok(
  $$ insert into public.reviews (request_id, client_id, professional_id, rating, comment)
     values ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 5, 'Excelente!') $$,
  'cliente avalia atendimento concluído'
);
select pg_temp.logout();

select * from finish();
rollback;
