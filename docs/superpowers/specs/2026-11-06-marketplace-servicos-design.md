# ServiçoLar — Documento de Design

Marketplace de serviços residenciais com sistema de agendamento.
Trabalho acadêmico. Equipe: Arthur Sena (coordenação), Paula Tiffany (UI/UX),
Eduardo Golzio (serviços e agendamentos), Joalisson Lemos (backend/banco),
Thalyson Nunes (testes e documentação).

## Intenção

Conectar clientes a profissionais autônomos (eletricista, encanador, diarista,
pintor, montador de móveis, pequenos reparos). O profissional anuncia serviços
com preço inicial e duração estimada e configura sua agenda; o cliente escolhe
um horário livre e envia uma solicitação, que o profissional aceita ou recusa.
O diferencial é o agendamento sem conflito de horários, validado no banco.

## Objetivos

- Cadastro/login/logout com papéis **cliente** e **profissional**.
- Catálogo por categoria com busca por texto.
- CRUD de serviços pelo profissional (criar, editar, desativar).
- Disponibilidade semanal (vários intervalos por dia) + bloqueios pontuais.
- Agenda do cliente mostra só horários realmente livres.
- Solicitação com estados: `pending`, `accepted`, `rejected`, `completed`,
  `cancelled`, `expired`. Pendentes expiram em **24 horas** sem resposta.
- Impossível existir duas solicitações `pending`/`accepted` sobrepostas para
  o mesmo profissional (constraint no Postgres).
- Avaliação (1 a 5 estrelas + comentário opcional) só após `completed`,
  uma por solicitação, feita pelo cliente.
- RLS: cada usuário só lê/altera o que lhe pertence.

## Não-objetivos (versão 1)

Pagamentos, comissões, chat, WhatsApp, GPS, push, mediação de conflitos,
upload de foto de perfil, build iOS (sem Mac disponível).

## Anti-objetivos

- Lógica de conflito só no cliente: o banco é a fonte de verdade.
- Horário "fantasma": solicitação pendente travando a agenda para sempre.
- Qualquer usuário conseguir ler dados de outro via API direta.

## Decisões de como será feito (tomadas pelo Claude, não pela equipe)

| Área | Decisão |
|---|---|
| App | Flutter stable (canal `stable`, clonado em `C:\src\flutter`), Dart 3. Pacote `servico_lar`, nome exibido **ServiçoLar**. |
| Plataformas | Web (alvo principal de demonstração) e Android. iOS configurado, não compilado. |
| Estado | `flutter_riverpod` (providers + `AsyncValue`). |
| Rotas | `go_router` com redirecionamento por sessão e papel. |
| Backend | Supabase (Auth + Postgres + RLS). Local via `supabase start` (Docker) para desenvolvimento; o mesmo SQL sobe para um projeto na nuvem via `supabase db push`. |
| Credenciais | `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`; padrão aponta para o Supabase local (`http://127.0.0.1:54321`). |
| Calendário | `table_calendar` para o mês; lista de horários gerada pelo app a partir de regras, bloqueios e ocupações. |
| Horários | Passo de **30 min**; um horário é oferecido se `[início, início+duração)` cabe dentro de um intervalo de disponibilidade, não cruza bloqueio nem solicitação `pending`/`accepted`, e início > agora. |
| Fuso | Tudo em `timestamptz` no banco; regras semanais em `time` local do profissional (v1 assume fuso único, America/Sao_Paulo). |
| Perfil | Criado automaticamente por trigger em `auth.users` com `full_name` e `role` vindos de `raw_user_meta_data`. |
| Transições | Trigger no banco valida quem pode mudar para qual estado (ver tabela abaixo). |
| Expiração | Função `expire_pending_requests()`; `pg_cron` a cada 5 min + chamada via RPC ao abrir a lista de solicitações. |
| Avaliações | Trigger garante `request.status = completed` e `client_id` = autor. View `professional_ratings` (média e total). |
| Testes | `flutter_test` para lógica pura (geração de horários, máquina de estados, validações) e widgets; testes de RLS em SQL (`supabase test db`, pgTAP). |
| Idioma | Identificadores em inglês, textos de interface em português. |

### Transições permitidas

| De | Para | Quem |
|---|---|---|
| pending | accepted, rejected | profissional da solicitação |
| pending | cancelled | cliente |
| pending | expired | sistema (função) |
| accepted | cancelled | cliente ou profissional |
| accepted | completed | profissional, só após `starts_at` |

## Modelo de dados

- `profiles(id → auth.users, full_name, role, phone, bio, created_at)`
- `categories(id, name, slug, icon)`
- `services(id, professional_id, category_id, title, description, base_price, duration_minutes, is_active, created_at)`
- `professional_availability(id, professional_id, weekday 0–6, start_time, end_time)`
- `availability_blocks(id, professional_id, starts_at, ends_at, reason)`
- `service_requests(id, service_id, client_id, professional_id, starts_at, ends_at, status, note, respond_by, created_at, updated_at)`
  com `EXCLUDE USING gist (professional_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','accepted'))`
- `reviews(id, request_id UNIQUE, client_id, professional_id, rating 1–5, comment, created_at)`

## Fluxos de tela

Cliente: Login/Cadastro → Início (categorias + busca) → Lista de serviços →
Detalhe do serviço → Agendar (mês → dia → horários livres → confirmar) →
Minhas solicitações (abas por estado, cancelar) → Avaliar (após concluído).

Profissional: Login/Cadastro → Painel (solicitações recebidas; aceitar,
recusar, concluir) → Meus serviços (CRUD, ativar/desativar) → Minha agenda
(intervalos por dia da semana + bloqueios) → Perfil.

## Contas de demonstração (apenas local)

`cliente@demo.com` e `prestador@demo.com`, senha `demo1234`, criadas no
`seed.sql` junto com as categorias e alguns serviços.

## Deixado ao construtor

Paleta e tipografia (dentro do Material 3), textos de erro, ordenação de
listas, layout responsivo web/mobile.
