# ServiçoLar — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Flutter + Supabase onde clientes agendam serviços residenciais em horários realmente livres de profissionais, com estados de solicitação, expiração e avaliações.

**Architecture:** Feature-first (`lib/features/<área>/{domain,data,presentation}`), lógica de agenda e estados em Dart puro (testável sem rede), persistência e regras de segurança no Postgres do Supabase (RLS, exclusion constraint, triggers). Riverpod expõe repositórios e estados assíncronos às telas; go_router decide a área (cliente/profissional) pela sessão.

**Tech Stack:** Flutter 3.47 / Dart 3.13, flutter_riverpod, go_router, supabase_flutter, table_calendar, intl, flutter_test, mocktail; Supabase CLI 3 (Docker) com pgTAP para testes de RLS.

**Spec:** `docs/superpowers/specs/2026-11-06-marketplace-servicos-design.md`

## Global Constraints

- Pacote Dart `servico_lar`; título do app **ServiçoLar**; textos de UI em português; identificadores em inglês.
- Estados exatos: `pending, accepted, rejected, completed, cancelled, expired`. Papéis: `client, professional`.
- Pendentes expiram 24 h após `created_at` (`respond_by`).
- Passo de horários 30 min; nunca oferecer horário com início <= agora.
- Rating inteiro 1–5; uma review por `request_id`.
- Todo acesso a dados passa por RLS; nenhuma tabela pública sem política.
- Credenciais via `--dart-define`; padrão local `http://127.0.0.1:54321` com a anon key padrão do Supabase local.

## Review Focus

1. Serviço de 90 min em intervalo 08:00–09:00: nenhum horário deve ser oferecido (teste em Task 5).
2. Bloqueio parcial 10:00–10:15 com passo 30 e duração 60: 09:30 e 10:00 não aparecem, 10:30 aparece (Task 5).
3. Dois clientes pedem o mesmo horário quase ao mesmo tempo: o segundo recebe erro de conflito do banco, não um horário duplicado (Task 3, pgTAP).
4. Profissional tenta concluir solicitação `accepted` antes de `starts_at`: trigger rejeita (Task 3).
5. Cliente tenta avaliar solicitação `accepted` (não concluída) ou de outro cliente: trigger rejeita (Task 3).

---

### Task 1: Projeto Flutter, dependências e estrutura

**Files:**
- Create: projeto via `flutter create --project-name servico_lar --org br.edu.servicolar --platforms web,android,ios .`
- Modify: `pubspec.yaml` (deps: flutter_riverpod, go_router, supabase_flutter, table_calendar, intl; dev: mocktail)
- Create: `lib/main.dart`, `lib/app.dart`, `lib/core/config/env.dart`, `lib/core/theme/app_theme.dart`, `lib/core/router/app_router.dart`
- Create: `README.md` (visão geral, como rodar)

**Produces:** `Env.supabaseUrl`, `Env.supabaseAnonKey` (const String via `String.fromEnvironment`), `AppTheme.light`, `routerProvider`.

- [ ] Criar projeto e adicionar dependências; `flutter pub get` sem erro.
- [ ] `main.dart`: `Supabase.initialize(url, anonKey)` → `runApp(ProviderScope(child: ServicoLarApp()))`.
- [ ] `flutter analyze` limpo; `flutter test` passa.
- [ ] `git init`, commit `chore: projeto Flutter inicial`.

### Task 2: Supabase local e schema

**Files:**
- Create: `supabase/config.toml` (via `supabase init`; `[auth] enable_confirmations = false`)
- Create: `supabase/migrations/20261106000001_schema.sql`
- Create: `supabase/seed.sql`

**Produces:** tabelas do spec; enums `user_role`, `request_status`; trigger `handle_new_user` em `auth.users`; view `professional_ratings(professional_id, avg_rating numeric(3,2), review_count int)`.

- [ ] Migration: extensões `btree_gist`, `pg_cron`; enums; tabelas com FKs e CHECKs (`end_time > start_time`, `ends_at > starts_at`, `rating between 1 and 5`, `duration_minutes > 0`, `base_price >= 0`); exclusion constraint em `service_requests`.
- [ ] Trigger `set_updated_at` em `service_requests`; trigger `handle_new_user` cria `profiles` com `full_name`, `role` do metadata (padrão `client`).
- [ ] Seed: 6 categorias (`eletrica, encanamento, limpeza, pintura, montagem, reparos`), 2 usuários demo via `auth.users`/`auth.identities` com `crypt('demo1234', gen_salt('bf'))`, 3 serviços do prestador, disponibilidade seg–sex 08:00–12:00 e 13:00–18:00.
- [ ] `npx supabase start` sobe; `npx supabase db reset` aplica sem erro.
- [ ] Commit `feat(db): schema inicial e seed`.

### Task 3: Regras no banco: transições, expiração, reviews, RLS

**Files:**
- Create: `supabase/migrations/20261106000002_rules.sql`
- Create: `supabase/migrations/20261106000003_rls.sql`
- Create: `supabase/tests/rules.test.sql`, `supabase/tests/rls.test.sql` (pgTAP)

**Produces:** função `expire_pending_requests() returns int` (security definer, agendada via `cron.schedule` a cada 5 min); função RPC `create_service_request(p_service_id uuid, p_starts_at timestamptz, p_note text) returns service_requests` (calcula `ends_at` pela duração e `respond_by`); trigger `validate_request_transition`; trigger `validate_review`; view `professional_busy_slots(professional_id, starts_at, ends_at)`.

- [ ] Testes pgTAP cobrindo a tabela de transições do spec, Review Focus 3–5, e RLS (cliente A não lê request de B; profissional só edita seus serviços; qualquer logado lê serviços ativos e perfis; horários ocupados de um profissional visíveis só via view sem dados pessoais).
- [ ] `npx supabase test db` falha (funções ausentes).
- [ ] Implementar funções, triggers e políticas.
- [ ] `npx supabase test db` passa.
- [ ] Commit `feat(db): transições, expiração, reviews e RLS`.

### Task 4: Modelos de domínio e autenticação

**Files:**
- Create: `lib/features/auth/domain/user_role.dart`, `lib/features/profile/domain/profile.dart`
- Create: `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/{auth_providers.dart,login_screen.dart,register_screen.dart}`
- Create: `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/core/router/app_router.dart` (redirect: sem sessão → `/login`; com sessão → `/client` ou `/pro` conforme `role`)
- Test: `test/features/profile/profile_test.dart`

**Produces:** `enum UserRole { client, professional }` com `fromDb/toDb`; `class Profile { id, fullName, role, phone, bio }` com `fromJson`; `AuthRepository.signIn/signUp(fullName, role)/signOut`; `currentProfileProvider: FutureProvider<Profile?>`.

- [ ] Teste `Profile.fromJson` mapeia `role: 'professional'` → `UserRole.professional`; falha; implementar; passa.
- [ ] Telas de login e cadastro (campo papel: cliente/profissional) com validação de email e senha >= 6.
- [ ] Redirect do router por sessão e papel; logout no AppBar.
- [ ] Commit `feat(auth): login, cadastro e perfis`.

### Task 5: Lógica pura de agenda

**Files:**
- Create: `lib/features/availability/domain/{availability_rule.dart,availability_block.dart,time_range.dart,slot_calculator.dart}`
- Test: `test/features/availability/slot_calculator_test.dart`

**Produces:** `class TimeRange(DateTime start, DateTime end)` com `overlaps(TimeRange)`; `class AvailabilityRule(int weekday /*1=seg..7=dom, DateTime.weekday*/, int startMinutes, int endMinutes)`; `class AvailabilityBlock(id, TimeRange range, String? reason)`; `List<DateTime> SlotCalculator.freeSlots({required DateTime day, required List<AvailabilityRule> rules, required List<TimeRange> blocked, required Duration duration, Duration step = 30min, required DateTime now})`.

- [ ] Testes: dia sem regra → `[]`; regra 08–12, duração 60, now anterior → `[08:00, 08:30, ..., 11:00]`; Review Focus 1 e 2; ocupação 09:00–10:00 remove 08:30, 09:00, 09:30; `now` = 09:10 no mesmo dia remove tudo <= 09:10.
- [ ] Rodar: falham; implementar; passam.
- [ ] Commit `feat(agenda): cálculo de horários livres`.

### Task 6: Catálogo de serviços

**Files:**
- Create: `lib/features/catalog/domain/{category.dart,service.dart}`, `lib/features/catalog/data/catalog_repository.dart`
- Create: `lib/features/catalog/presentation/{client_home_screen.dart,service_list_screen.dart,service_detail_screen.dart,my_services_screen.dart,service_form_screen.dart,catalog_providers.dart}`
- Test: `test/features/catalog/service_test.dart`

**Produces:** `Service { id, professionalId, professionalName, categoryId, title, description, basePrice (double), durationMinutes, isActive, avgRating?, reviewCount }`; `CatalogRepository.categories()`, `.activeServices({categoryId?, query?})` (join `profiles` e `professional_ratings`), `.myServices()`, `.upsert(Service)`, `.setActive(id, bool)`.

- [ ] Teste `Service.fromJson` com join aninhado; `priceLabel` → `R$ 120,00`; falha; implementar; passa.
- [ ] Telas: início do cliente (grid de categorias + busca), lista, detalhe (nota média + botão Agendar), meus serviços (lista com switch ativo), formulário.
- [ ] Commit `feat(catalogo): categorias e serviços`.

### Task 7: Disponibilidade e bloqueios (profissional)

**Files:**
- Create: `lib/features/availability/data/availability_repository.dart`
- Create: `lib/features/availability/presentation/{availability_screen.dart,block_form_sheet.dart,availability_providers.dart}`

**Produces:** `AvailabilityRepository.rules(professionalId)`, `.replaceRules(List<AvailabilityRule>)`, `.blocks(professionalId, from, to)`, `.addBlock/removeBlock`, `.busySlots(professionalId, from, to) → List<TimeRange>` (view `professional_busy_slots`).

- [ ] Tela: 7 dias da semana, cada um com lista de intervalos (adicionar/remover via TimePicker); seção bloqueios com data+hora início/fim e motivo.
- [ ] Commit `feat(agenda): disponibilidade e bloqueios`.

### Task 8: Agendamento e solicitações

**Files:**
- Create: `lib/features/bookings/domain/{request_status.dart,service_request.dart}`, `lib/features/bookings/data/bookings_repository.dart`
- Create: `lib/features/bookings/presentation/{booking_screen.dart,my_requests_screen.dart,pro_dashboard_screen.dart,request_card.dart,bookings_providers.dart}`
- Test: `test/features/bookings/request_status_test.dart`

**Produces:** `enum RequestStatus` com `label` em pt-BR, `canClientCancel`, `canProfessionalRespond`, `canComplete(now, startsAt)`; `ServiceRequest { id, service, clientName, professionalName, startsAt, endsAt, status, note, respondBy }`; `BookingsRepository.create(serviceId, startsAt, note)` (RPC), `.mine()`, `.received()`, `.updateStatus(id, RequestStatus)`, `.expirePending()` (RPC).

- [ ] Testes de `RequestStatus` (labels e permissões de ação); falham; implementar; passam.
- [ ] `booking_screen`: `TableCalendar` do mês → ao escolher dia, chama `SlotCalculator.freeSlots` com regras, bloqueios e `busySlots` → chips de horário → confirmação → `create`; erro `23P01` (exclusion) vira mensagem "Esse horário acabou de ser ocupado".
- [ ] `my_requests_screen` (abas Ativas/Histórico, botão cancelar), `pro_dashboard_screen` (aceitar/recusar/concluir), chamar `expirePending()` no carregamento.
- [ ] Commit `feat(agendamento): solicitações e estados`.

### Task 9: Avaliações

**Files:**
- Create: `lib/features/reviews/domain/review.dart`, `lib/features/reviews/data/reviews_repository.dart`, `lib/features/reviews/presentation/{review_sheet.dart,review_list.dart}`
- Modify: `request_card.dart` (botão Avaliar quando `completed` e sem review), `service_detail_screen.dart` (lista de avaliações)
- Test: `test/features/reviews/review_test.dart`

**Produces:** `Review { id, requestId, rating, comment, clientName, createdAt }`; `ReviewsRepository.create(requestId, rating, comment)`, `.forProfessional(id)`, `.existsForRequest(id)`.

- [ ] Teste de validação: rating fora de 1–5 lança `ArgumentError`; falha; implementar; passa.
- [ ] UI de estrelas + comentário; lista no detalhe.
- [ ] Commit `feat(avaliacoes): nota e comentário`.

### Task 10: Testes de widget e verificação final

**Files:**
- Test: `test/widgets/login_screen_test.dart`, `test/widgets/request_card_test.dart`
- Modify: `README.md`, `docs/MANUAL_DO_USUARIO.md`, `docs/TESTES.md`

- [ ] Widget tests: login mostra erro com email inválido; `RequestCard` com `pending` mostra "Cancelar" para cliente e "Aceitar/Recusar" para profissional.
- [ ] `flutter analyze` limpo; `flutter test` verde; `npx supabase test db` verde; `flutter build web` gera `build/web`.
- [ ] Rodar o app no Chrome contra o Supabase local e percorrer: cadastro → serviço → disponibilidade → agendamento → aceitar → concluir → avaliar.
- [ ] README: pré-requisitos, `supabase start`, `flutter run -d chrome`, como apontar para projeto na nuvem; manual e registro de testes.
- [ ] Commit `docs: README, manual e registro de testes`.
