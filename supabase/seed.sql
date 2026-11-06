-- ServiçoLar — dados de demonstração (apenas ambiente local)

-- Categorias ----------------------------------------------------------------
insert into public.categories (name, slug, icon) values
  ('Elétrica',           'eletrica',     'electrical_services'),
  ('Encanamento',        'encanamento',  'plumbing'),
  ('Limpeza',            'limpeza',      'cleaning_services'),
  ('Pintura',            'pintura',      'format_paint'),
  ('Montagem de móveis', 'montagem',     'chair'),
  ('Pequenos reparos',   'reparos',      'handyman');

-- Usuários de demonstração (senha: demo1234) ----------------------------------
-- O trigger handle_new_user cria o perfil a partir de raw_user_meta_data.
create or replace function pg_temp.seed_user(p_id uuid, p_email text, p_name text, p_role text)
returns void language plpgsql as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    p_email, crypt('demo1234', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', p_name, 'role', p_role),
    now(), now(), '', '', '', ''
  );
  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), p_id, p_id,
    jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
    'email', now(), now(), now()
  );
end;
$$;

select pg_temp.seed_user('11111111-1111-1111-1111-111111111111', 'cliente@demo.com',    'Marina Cliente',   'client');
select pg_temp.seed_user('22222222-2222-2222-2222-222222222222', 'prestador@demo.com',  'Carlos Eletricista', 'professional');
select pg_temp.seed_user('33333333-3333-3333-3333-333333333333', 'prestador2@demo.com', 'Ana Diarista',     'professional');

update public.profiles set phone = '(11) 98888-1111', bio = 'Eletricista há 12 anos. Instalações, reparos e laudos residenciais.'
 where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set phone = '(11) 97777-2222', bio = 'Limpeza residencial completa, pós-obra e passadoria.'
 where id = '33333333-3333-3333-3333-333333333333';

-- Serviços ------------------------------------------------------------------
insert into public.services (id, professional_id, category_id, title, description, base_price, duration_minutes) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   (select id from public.categories where slug = 'eletrica'),
   'Troca de tomadas e interruptores',
   'Substituição de até 5 pontos. Material não incluso.', 120.00, 60),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   (select id from public.categories where slug = 'eletrica'),
   'Instalação de chuveiro elétrico',
   'Instalação com verificação do disjuntor e da fiação.', 180.00, 90),
  ('aaaaaaaa-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222',
   (select id from public.categories where slug = 'reparos'),
   'Instalação de luminárias e ventilador de teto',
   'Fixação e ligação elétrica de até 2 peças.', 150.00, 120),
  ('aaaaaaaa-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333',
   (select id from public.categories where slug = 'limpeza'),
   'Diária de limpeza residencial',
   'Apartamentos de até 80 m². Produtos por conta do cliente.', 220.00, 480),
  ('aaaaaaaa-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333',
   (select id from public.categories where slug = 'limpeza'),
   'Limpeza pós-obra (meio período)',
   'Remoção de poeira fina e resíduos de obra.', 300.00, 240);

-- Disponibilidade: Carlos seg–sex 08–12 e 13–18; Ana seg–sáb 07–16 ---------------
insert into public.professional_availability (professional_id, weekday, start_time, end_time)
select '22222222-2222-2222-2222-222222222222', d, t.s, t.e
  from generate_series(1, 5) d
  cross join (values ('08:00'::time, '12:00'::time), ('13:00'::time, '18:00'::time)) as t(s, e);

insert into public.professional_availability (professional_id, weekday, start_time, end_time)
select '33333333-3333-3333-3333-333333333333', d, '07:00'::time, '16:00'::time
  from generate_series(1, 6) d;

-- Histórico de demonstração: atendimentos concluídos e avaliações ----------------
-- (inseridos diretamente; o trigger de avaliação exige auth.uid() = cliente)
insert into public.service_requests (id, service_id, client_id, professional_id, starts_at, ends_at, status, note, respond_by, created_at)
values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   now() - interval '10 days', now() - interval '10 days' + interval '90 minutes', 'completed',
   'Chuveiro novo já comprado.', now() - interval '11 days', now() - interval '12 days'),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   now() - interval '5 days', now() - interval '5 days' + interval '8 hours', 'completed',
   null, now() - interval '6 days', now() - interval '7 days'),
  ('cccccccc-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   now() - interval '20 days', now() - interval '20 days' + interval '60 minutes', 'completed',
   null, now() - interval '21 days', now() - interval '22 days');

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.reviews (request_id, client_id, professional_id, rating, comment) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 5, 'Pontual, explicou tudo e deixou o banheiro limpo. Recomendo!'),
  ('cccccccc-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 4, 'Bom serviço, só atrasou uns 15 minutos.'),
  ('cccccccc-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 5, 'Apartamento ficou impecável.');
select set_config('request.jwt.claim.sub', '', false);

-- Atendimento concluído ainda sem avaliação (para demonstrar o fluxo de avaliar)
insert into public.service_requests (id, service_id, client_id, professional_id, starts_at, ends_at, status, note, respond_by, created_at)
values
  ('cccccccc-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000005',
   '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   now() - interval '2 days', now() - interval '2 days' + interval '4 hours', 'completed',
   'Obra do banheiro terminou ontem.', now() - interval '3 days', now() - interval '4 days');
