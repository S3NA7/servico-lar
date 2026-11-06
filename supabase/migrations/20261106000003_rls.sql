-- ServiçoLar — segurança (Row Level Security)

alter table public.profiles                  enable row level security;
alter table public.categories                enable row level security;
alter table public.services                  enable row level security;
alter table public.professional_availability enable row level security;
alter table public.availability_blocks       enable row level security;
alter table public.service_requests          enable row level security;
alter table public.reviews                   enable row level security;

create or replace function public.is_professional(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = p_uid and role = 'professional');
$$;

-- Perfis: todos os logados leem (nomes aparecem no catálogo); só o dono edita.
create policy "profiles: leitura para logados"
  on public.profiles for select to authenticated using (true);
create policy "profiles: dono edita"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid() and role = (select p.role from public.profiles p where p.id = auth.uid()));

-- Categorias: leitura para logados.
create policy "categories: leitura para logados"
  on public.categories for select to authenticated using (true);

-- Serviços: ativos visíveis a todos; o profissional vê e gerencia os seus.
create policy "services: leitura de ativos ou próprios"
  on public.services for select to authenticated
  using (is_active or professional_id = auth.uid());
create policy "services: profissional cria"
  on public.services for insert to authenticated
  with check (professional_id = auth.uid() and public.is_professional(auth.uid()));
create policy "services: dono edita"
  on public.services for update to authenticated
  using (professional_id = auth.uid()) with check (professional_id = auth.uid());
create policy "services: dono remove"
  on public.services for delete to authenticated
  using (professional_id = auth.uid());

-- Disponibilidade semanal: pública para logados (necessária para a agenda); dono gerencia.
create policy "availability: leitura para logados"
  on public.professional_availability for select to authenticated using (true);
create policy "availability: dono gerencia"
  on public.professional_availability for all to authenticated
  using (professional_id = auth.uid()) with check (professional_id = auth.uid());

-- Bloqueios: só o dono vê os detalhes; os períodos aparecem via professional_busy_slots.
create policy "blocks: dono gerencia"
  on public.availability_blocks for all to authenticated
  using (professional_id = auth.uid()) with check (professional_id = auth.uid());

-- Solicitações: só as partes envolvidas; cliente cria; transições validadas por trigger.
create policy "requests: partes leem"
  on public.service_requests for select to authenticated
  using (client_id = auth.uid() or professional_id = auth.uid());
create policy "requests: cliente cria"
  on public.service_requests for insert to authenticated
  with check (client_id = auth.uid());
create policy "requests: partes atualizam"
  on public.service_requests for update to authenticated
  using (client_id = auth.uid() or professional_id = auth.uid())
  with check (client_id = auth.uid() or professional_id = auth.uid());

-- Avaliações: leitura para logados; inserção validada por trigger; sem edição.
create policy "reviews: leitura para logados"
  on public.reviews for select to authenticated using (true);
create policy "reviews: cliente avalia"
  on public.reviews for insert to authenticated
  with check (client_id = auth.uid());

-- Views e funções
grant select on public.professional_ratings   to authenticated;
grant select on public.professional_busy_slots to authenticated;

revoke all on function public.expire_pending_requests() from public;
grant execute on function public.expire_pending_requests() to authenticated;
grant execute on function public.create_service_request(uuid, timestamptz, text) to authenticated;
grant execute on function public.is_professional(uuid) to authenticated;

-- Nada para usuários anônimos.
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon;
