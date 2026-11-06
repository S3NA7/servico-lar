-- ServiçoLar — schema inicial
-- Tabelas, enums, constraints e trigger de criação de perfil.

create extension if not exists btree_gist;
create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
create type public.user_role as enum ('client', 'professional');

create type public.request_status as enum (
  'pending', 'accepted', 'rejected', 'completed', 'cancelled', 'expired'
);

-- -----------------------------------------------------------------------------
-- Perfis
-- -----------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null check (char_length(full_name) between 1 and 120),
  role        public.user_role not null default 'client',
  phone       text,
  bio         text,
  created_at  timestamptz not null default now()
);

comment on table public.profiles is 'Dados públicos do usuário e seu papel na plataforma.';

-- Cria o perfil automaticamente quando um usuário se cadastra.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.user_role;
begin
  v_role := case
    when new.raw_user_meta_data ->> 'role' = 'professional' then 'professional'
    else 'client'
  end;

  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(new.email, '@', 1)),
    v_role
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Categorias e serviços
-- -----------------------------------------------------------------------------
create table public.categories (
  id    serial primary key,
  name  text not null,
  slug  text not null unique,
  icon  text not null default 'build'
);

create table public.services (
  id               uuid primary key default gen_random_uuid(),
  professional_id  uuid not null references public.profiles (id) on delete cascade,
  category_id      int  not null references public.categories (id),
  title            text not null check (char_length(title) between 3 and 80),
  description      text not null default '',
  base_price       numeric(10, 2) not null check (base_price >= 0),
  duration_minutes int  not null check (duration_minutes > 0 and duration_minutes <= 720),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);

create index services_category_active_idx on public.services (category_id) where is_active;
create index services_professional_idx on public.services (professional_id);

-- -----------------------------------------------------------------------------
-- Disponibilidade
-- -----------------------------------------------------------------------------
-- weekday segue o Postgres: 0 = domingo … 6 = sábado.
create table public.professional_availability (
  id               uuid primary key default gen_random_uuid(),
  professional_id  uuid not null references public.profiles (id) on delete cascade,
  weekday          smallint not null check (weekday between 0 and 6),
  start_time       time not null,
  end_time         time not null,
  check (end_time > start_time)
);

create index availability_professional_idx on public.professional_availability (professional_id);

create table public.availability_blocks (
  id               uuid primary key default gen_random_uuid(),
  professional_id  uuid not null references public.profiles (id) on delete cascade,
  starts_at        timestamptz not null,
  ends_at          timestamptz not null,
  reason           text,
  check (ends_at > starts_at)
);

create index blocks_professional_range_idx on public.availability_blocks using gist (professional_id, tstzrange(starts_at, ends_at, '[)'));

-- -----------------------------------------------------------------------------
-- Solicitações de atendimento
-- -----------------------------------------------------------------------------
create table public.service_requests (
  id               uuid primary key default gen_random_uuid(),
  service_id       uuid not null references public.services (id),
  client_id        uuid not null references public.profiles (id),
  professional_id  uuid not null references public.profiles (id),
  starts_at        timestamptz not null,
  ends_at          timestamptz not null,
  status           public.request_status not null default 'pending',
  note             text,
  respond_by       timestamptz not null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (ends_at > starts_at),
  check (client_id <> professional_id),

  -- Um profissional nunca tem duas solicitações ativas no mesmo período.
  constraint no_overlapping_requests exclude using gist (
    professional_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status in ('pending', 'accepted'))
);

create index requests_client_idx on public.service_requests (client_id, starts_at desc);
create index requests_professional_idx on public.service_requests (professional_id, starts_at desc);
create index requests_pending_respond_by_idx on public.service_requests (respond_by) where status = 'pending';

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger service_requests_set_updated_at
  before update on public.service_requests
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Avaliações
-- -----------------------------------------------------------------------------
create table public.reviews (
  id               uuid primary key default gen_random_uuid(),
  request_id       uuid not null unique references public.service_requests (id),
  client_id        uuid not null references public.profiles (id),
  professional_id  uuid not null references public.profiles (id),
  rating           smallint not null check (rating between 1 and 5),
  comment          text check (comment is null or char_length(comment) <= 500),
  created_at       timestamptz not null default now()
);

create index reviews_professional_idx on public.reviews (professional_id);

-- Reputação agregada por profissional.
create view public.professional_ratings
with (security_invoker = true) as
select
  professional_id,
  round(avg(rating)::numeric, 2) as avg_rating,
  count(*)::int                  as review_count
from public.reviews
group by professional_id;
