-- ServiçoLar — regras de negócio no banco
-- Transições de estado, criação segura de solicitações, expiração e avaliações.

-- -----------------------------------------------------------------------------
-- Transições de estado
-- -----------------------------------------------------------------------------
--   pending  -> accepted | rejected   (profissional)
--   pending  -> cancelled             (cliente)
--   pending  -> expired               (sistema)
--   accepted -> cancelled             (cliente ou profissional, antes do início)
--   accepted -> completed             (profissional, após o início)
create or replace function public.validate_request_transition()
returns trigger
language plpgsql
as $$
declare
  v_uid    uuid := auth.uid();
  v_system boolean := coalesce(current_setting('app.system', true), 'off') = 'on';
begin
  -- Dados do agendamento são imutáveis depois de criados.
  if new.service_id <> old.service_id
     or new.client_id <> old.client_id
     or new.professional_id <> old.professional_id
     or new.starts_at <> old.starts_at
     or new.ends_at <> old.ends_at
     or new.respond_by <> old.respond_by
     or new.created_at <> old.created_at then
    raise exception 'Os dados da solicitação não podem ser alterados'
      using errcode = '42501';
  end if;

  if new.status = old.status then
    return new;
  end if;

  if old.status = 'pending' and new.status in ('accepted', 'rejected') then
    if v_uid is distinct from old.professional_id then
      raise exception 'Apenas o profissional pode responder à solicitação'
        using errcode = '42501';
    end if;
    if now() > old.respond_by then
      raise exception 'Esta solicitação já expirou' using errcode = 'P0001';
    end if;

  elsif old.status = 'pending' and new.status = 'cancelled' then
    if v_uid is distinct from old.client_id then
      raise exception 'Apenas o cliente pode cancelar uma solicitação pendente'
        using errcode = '42501';
    end if;

  elsif old.status = 'pending' and new.status = 'expired' then
    if not v_system then
      raise exception 'A expiração é feita pelo sistema' using errcode = '42501';
    end if;

  elsif old.status = 'accepted' and new.status = 'cancelled' then
    if v_uid is distinct from old.client_id and v_uid is distinct from old.professional_id then
      raise exception 'Apenas as partes podem cancelar o atendimento'
        using errcode = '42501';
    end if;
    if now() >= old.starts_at then
      raise exception 'Não é possível cancelar um atendimento já iniciado'
        using errcode = 'P0001';
    end if;

  elsif old.status = 'accepted' and new.status = 'completed' then
    if v_uid is distinct from old.professional_id then
      raise exception 'Apenas o profissional pode concluir o atendimento'
        using errcode = '42501';
    end if;
    if now() < old.starts_at then
      raise exception 'Só é possível concluir após o horário de início'
        using errcode = 'P0001';
    end if;

  else
    raise exception 'Transição inválida: % -> %', old.status, new.status
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger service_requests_validate_transition
  before update on public.service_requests
  for each row execute function public.validate_request_transition();

-- -----------------------------------------------------------------------------
-- Criação de solicitação (RPC)
-- -----------------------------------------------------------------------------
-- Calcula ends_at pela duração do serviço, valida horário de atendimento e
-- bloqueios, e deixa a exclusion constraint impedir sobreposição.
-- respond_by = min(agora + 24h, início do atendimento).
create or replace function public.create_service_request(
  p_service_id uuid,
  p_starts_at  timestamptz,
  p_note       text default null
)
returns public.service_requests
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_service public.services%rowtype;
  v_ends_at timestamptz;
  v_local   timestamp;
  v_request public.service_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'É preciso estar autenticado' using errcode = '42501';
  end if;

  select * into v_service from public.services where id = p_service_id and is_active;
  if not found then
    raise exception 'Serviço indisponível' using errcode = 'P0002';
  end if;

  if v_service.professional_id = v_uid then
    raise exception 'Você não pode agendar o próprio serviço' using errcode = 'P0001';
  end if;

  if p_starts_at <= now() then
    raise exception 'Esse horário já passou' using errcode = 'P0001';
  end if;

  v_ends_at := p_starts_at + make_interval(mins => v_service.duration_minutes);
  v_local   := p_starts_at at time zone 'America/Sao_Paulo';

  if not exists (
    select 1
    from public.professional_availability a
    where a.professional_id = v_service.professional_id
      and a.weekday = extract(dow from v_local)
      and v_local::time >= a.start_time
      and (v_ends_at at time zone 'America/Sao_Paulo')::time <= a.end_time
      and (v_ends_at at time zone 'America/Sao_Paulo')::date = v_local::date
  ) then
    raise exception 'Fora do horário de atendimento do profissional' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.availability_blocks b
    where b.professional_id = v_service.professional_id
      and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(p_starts_at, v_ends_at, '[)')
  ) then
    raise exception 'O profissional bloqueou esse horário' using errcode = 'P0001';
  end if;

  insert into public.service_requests
    (service_id, client_id, professional_id, starts_at, ends_at, respond_by, note)
  values
    (p_service_id, v_uid, v_service.professional_id, p_starts_at, v_ends_at,
     least(now() + interval '24 hours', p_starts_at), nullif(trim(p_note), ''))
  returning * into v_request;

  return v_request;
end;
$$;

-- -----------------------------------------------------------------------------
-- Expiração de pendentes
-- -----------------------------------------------------------------------------
create or replace function public.expire_pending_requests()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  perform set_config('app.system', 'on', true);
  update public.service_requests
     set status = 'expired'
   where status = 'pending'
     and respond_by < now();
  get diagnostics v_count = row_count;
  perform set_config('app.system', 'off', true);
  return v_count;
end;
$$;

-- Agenda a expiração a cada 5 minutos quando pg_cron estiver disponível.
do $outer$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron indisponível; expiração só via RPC.';
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'expire-pending-requests',
      '*/5 * * * *',
      $job$ select public.expire_pending_requests(); $job$
    );
  end if;
end;
$outer$;

-- -----------------------------------------------------------------------------
-- Avaliações: só o cliente, só após conclusão
-- -----------------------------------------------------------------------------
create or replace function public.validate_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.service_requests%rowtype;
begin
  select * into v_request from public.service_requests where id = new.request_id;
  if not found then
    raise exception 'Solicitação não encontrada' using errcode = 'P0002';
  end if;
  if v_request.status <> 'completed' then
    raise exception 'Só é possível avaliar atendimentos concluídos' using errcode = 'P0001';
  end if;
  if auth.uid() is distinct from v_request.client_id then
    raise exception 'Apenas o cliente do atendimento pode avaliar' using errcode = '42501';
  end if;

  new.client_id       := v_request.client_id;
  new.professional_id := v_request.professional_id;
  return new;
end;
$$;

create trigger reviews_validate
  before insert on public.reviews
  for each row execute function public.validate_review();

-- -----------------------------------------------------------------------------
-- Horários ocupados visíveis a qualquer usuário logado (sem dados pessoais)
-- -----------------------------------------------------------------------------
create view public.professional_busy_slots
with (security_invoker = false) as
select professional_id, starts_at, ends_at, 'request'::text as kind
  from public.service_requests
 where status in ('pending', 'accepted')
union all
select professional_id, starts_at, ends_at, 'block'::text as kind
  from public.availability_blocks;
