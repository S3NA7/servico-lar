-- Testes pgTAP de permissões (RLS)
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

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

\set cliente  '11111111-1111-1111-1111-111111111111'
\set carlos   '22222222-2222-2222-2222-222222222222'
\set ana      '33333333-3333-3333-3333-333333333333'

-- Dados: uma solicitação do cliente com o Carlos e um bloqueio da Ana.
insert into public.service_requests (id, service_id, client_id, professional_id, starts_at, ends_at, status, respond_by)
values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', :'cliente', :'carlos',
        now() + interval '2 days', now() + interval '2 days 1 hour', 'pending', now() + interval '1 day');

insert into public.availability_blocks (id, professional_id, starts_at, ends_at, reason)
values ('eeeeeeee-0000-0000-0000-000000000001', :'ana', now() + interval '3 days', now() + interval '3 days 4 hours', 'Consulta médica');

-- Todas as tabelas públicas têm RLS ------------------------------------------
select is(
  (select count(*) from pg_tables where schemaname = 'public' and not rowsecurity),
  0::bigint,
  'todas as tabelas do schema public têm RLS habilitado'
);

-- Ana (outra profissional) não vê a solicitação do Carlos -----------------------
select pg_temp.login(:'ana');
select is(
  (select count(*) from public.service_requests),
  0::bigint,
  'profissional não envolvido não lê solicitações de outros'
);
-- mas vê o período ocupado, sem saber de quem é
select is(
  (select count(*) from public.professional_busy_slots where professional_id = :'carlos'),
  1::bigint,
  'horários ocupados do Carlos aparecem na view pública'
);
-- Ana não pode editar serviço do Carlos
update public.services set title = 'Hackeado' where professional_id = :'carlos';
select is(
  (select count(*) from public.services where title = 'Hackeado'),
  0::bigint,
  'update em serviço de outro profissional não afeta linhas'
);
-- Ana não pode inserir serviço em nome do Carlos
select throws_ok(
  $$ insert into public.services (professional_id, category_id, title, base_price, duration_minutes)
     values ('22222222-2222-2222-2222-222222222222', 1, 'Falso', 10, 30) $$,
  '42501',
  null,
  'inserir serviço para outro profissional é negado'
);
select pg_temp.logout();

-- Cliente ---------------------------------------------------------------------
select pg_temp.login(:'cliente');
select is(
  (select count(*) from public.service_requests),
  1::bigint,
  'cliente lê a própria solicitação'
);
select is(
  (select count(*) from public.services where is_active),
  5::bigint,
  'cliente lê todos os serviços ativos'
);
select throws_ok(
  $$ insert into public.services (professional_id, category_id, title, base_price, duration_minutes)
     values ('11111111-1111-1111-1111-111111111111', 1, 'Cliente não anuncia', 10, 30) $$,
  '42501',
  null,
  'cliente não pode criar serviços'
);
select is(
  (select count(*) from public.availability_blocks),
  0::bigint,
  'cliente não lê detalhes de bloqueios de outros'
);
select is(
  (select count(*) from public.professional_busy_slots where professional_id = :'ana' and kind = 'block'),
  1::bigint,
  'mas vê o período bloqueado da Ana via view'
);
-- cliente não muda o próprio papel
select throws_ok(
  $$ update public.profiles set role = 'professional' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'cliente não consegue se promover a profissional'
);
select pg_temp.logout();

-- Anônimo -----------------------------------------------------------------------
set local role anon;
select throws_ok(
  $$ select count(*) from public.services $$,
  '42501',
  null,
  'anônimo não lê serviços'
);
reset role;

select * from finish();
rollback;
