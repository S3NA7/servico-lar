# ServiçoLar

Marketplace de serviços residenciais com sistema de agendamento. Clientes
encontram eletricistas, encanadores, diaristas, pintores e montadores, veem a
agenda real do profissional e solicitam um horário livre. O profissional
aceita, recusa ou conclui; o cliente avalia.

Trabalho acadêmico desenvolvido em **Flutter + Supabase**.

| RGM | Integrante | Responsabilidade |
|---|---|---|
| 46388761 | Arthur Sena Duarte da Silva | Coordenação e integração |
| 45660751 | Eduardo dos Santos Golzio | Serviços e agendamentos |
| 43863957 | Joalisson David da Silva Lemos | Backend e banco de dados |
| 43900119 | Paula Tiffany Gomes Dias | Interface e experiência do usuário |
| 42066859 | Thalyson Chaves Nunes | Testes e documentação |

## Funcionalidades

- Cadastro e login com papéis **cliente** e **profissional**
- Catálogo por categoria com busca
- Profissional cadastra, edita e desativa serviços (título, descrição, preço inicial, duração)
- Profissional configura horários semanais e bloqueios pontuais
- Cliente vê apenas horários realmente livres e envia solicitação
- Estados: pendente → aceita / recusada / cancelada / expirada → concluída
- Pendentes expiram em 24 h (ou no início do horário, o que vier antes)
- **Impossível** haver duas solicitações ativas sobrepostas para o mesmo profissional (constraint no Postgres)
- Avaliação de 1 a 5 estrelas após a conclusão, uma por atendimento
- Row Level Security: cada usuário só acessa o que lhe pertence

## Estrutura

```
lib/
  core/            tema, rotas, cliente Supabase, utilitários
  features/
    auth/          login, cadastro, sessão
    profile/       perfil do usuário
    catalog/       categorias e serviços
    availability/  horários semanais, bloqueios, cálculo de horários livres
    bookings/      solicitações e estados
    reviews/       avaliações
supabase/
  migrations/      schema, regras de negócio (triggers/funções), RLS
  seed.sql         categorias, usuários e serviços de demonstração
  tests/           testes pgTAP (regras e permissões)
docs/
  superpowers/specs/   documento de design
  superpowers/plans/   plano de implementação
  MANUAL_DO_USUARIO.md
  TESTES.md
```

Cada feature segue `domain/` (modelos e lógica pura), `data/` (acesso ao
Supabase) e `presentation/` (telas e providers Riverpod).

## Pré-requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) 3.47 ou superior (canal stable)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) em execução
- [Node.js](https://nodejs.org/) 18+ (para rodar a CLI do Supabase com `npx`)
- Chrome (para rodar na web)

## Como rodar

1. Subir o Supabase local (primeira vez baixa as imagens Docker):

   ```bash
   npx supabase start
   ```

2. Aplicar migrations e seed:

   ```bash
   npx supabase db reset
   ```

3. Rodar o app no Chrome:

   ```bash
   flutter run -d chrome
   ```

   Ou em um emulador Android: `flutter run -d android`.

O app já aponta por padrão para o Supabase local (`http://127.0.0.1:54321`).
O Studio (interface do banco) fica em <http://127.0.0.1:54323>.

### Contas de demonstração

| Perfil | E-mail | Senha |
|---|---|---|
| Cliente | `cliente@demo.com` | `demo1234` |
| Profissional (eletricista) | `prestador@demo.com` | `demo1234` |
| Profissional (diarista) | `prestador2@demo.com` | `demo1234` |

### Usando um projeto Supabase na nuvem

1. Crie um projeto em <https://supabase.com>.
2. Vincule e envie o schema:

   ```bash
   npx supabase link --project-ref SEU_PROJECT_REF
   npx supabase db push
   ```

3. Rode o app apontando para ele:

   ```bash
   flutter run -d chrome --dart-define=SUPABASE_URL=https://SEU_REF.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_...
   ```

   Na nuvem, habilite a extensão `pg_cron` em *Database → Extensions* para a
   expiração automática; sem ela, a expiração acontece ao abrir as listas.

## Testes

```bash
flutter analyze
flutter test
npx supabase test db
```

Detalhes e resultados em [docs/TESTES.md](docs/TESTES.md).

## Build

```bash
flutter build web
flutter build apk
```

O build web fica em `build/web/` e pode ser servido por qualquer servidor estático.

## Decisões técnicas

- **Conflito de horários no banco**: `EXCLUDE USING gist (professional_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE status IN ('pending','accepted')`. Duas solicitações simultâneas para o mesmo horário: a segunda recebe erro `23P01` e o app mostra "Esse horário acabou de ser ocupado".
- **Transições de estado** validadas por trigger (`validate_request_transition`): quem pode mudar para qual estado e quando.
- **Expiração** pela função `expire_pending_requests()`, agendada com `pg_cron` a cada 5 min e também chamada quando o app carrega as listas.
- **Avaliações** validadas por trigger: apenas o cliente, apenas após `completed`, uma por solicitação.
- **Horários livres** calculados no app (`SlotCalculator`) a partir das regras semanais, bloqueios e ocupações; o banco faz a validação final.

## Fora do escopo (versão 1)

Pagamentos, chat, WhatsApp, GPS, notificações push, build iOS.
