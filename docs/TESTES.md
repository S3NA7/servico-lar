# ServiçoLar — Plano e Registro de Testes

Última execução: 06/11/2026, ambiente local (Windows 11, Flutter 3.47.9,
Supabase CLI 3.0.0, Postgres 17 via Docker).

## 1. Como executar

```bash
flutter analyze          # lint estático
flutter test             # testes unitários e de widget
npx supabase test db     # testes pgTAP (regras de negócio e RLS)
```

## 2. Testes automatizados

### 2.1 Flutter (`flutter test`) — 34 testes, todos passando

| Arquivo | O que cobre | Qtde |
|---|---|---|
| `test/features/availability/slot_calculator_test.dart` | Geração de horários livres: dia sem regra, passo de 30 min, duração maior que o intervalo, bloqueio parcial, ocupação, horários passados, dois intervalos no dia; `TimeRange.overlaps`; conversão de dia da semana do banco | 11 |
| `test/features/profile/profile_test.dart` | Mapeamento de perfil e papel | 3 |
| `test/features/catalog/service_test.dart` | Modelo de serviço com joins, formatação de preço/duração, reputação, ícone de categoria | 5 |
| `test/features/bookings/request_status_test.dart` | Labels dos estados, quem pode cancelar/responder/concluir e quando, leitura de solicitação com joins e detecção de avaliação | 8 |
| `test/features/reviews/review_test.dart` | Validação da nota 1–5, leitura de avaliação | 2 |
| `test/widgets/login_screen_test.dart` | Validação de e-mail e senha na tela de login | 2 |
| `test/widgets/request_card_test.dart` | Botões exibidos por estado e por papel (Cancelar, Aceitar/Recusar, Concluir habilitado só após o início, Avaliar só sem avaliação) | 3 |

### 2.2 Banco (`npx supabase test db`) — 28 verificações, todas passando

**`supabase/tests/rules.test.sql`** (16)

- Cliente cria solicitação em horário livre; nasce `pending`; `ends_at` = início + duração.
- Segunda solicitação no mesmo horário → erro `23P01` (exclusion constraint).
- Sobreposição parcial → erro `23P01`.
- Fora do horário de atendimento → recusado.
- Horário no passado → recusado.
- Cliente não pode aceitar a própria solicitação (`42501`).
- Profissional aceita pendente.
- Profissional não conclui antes do horário de início.
- `accepted → pending` é transição inválida.
- Usuário não marca expiração manualmente; `expire_pending_requests()` expira exatamente as pendentes vencidas.
- Não avalia atendimento não concluído; cliente avalia atendimento concluído.

**`supabase/tests/rls.test.sql`** (12)

- Todas as tabelas de `public` têm RLS habilitado.
- Profissional não envolvido não lê solicitações de outros, mas vê os períodos ocupados via `professional_busy_slots`.
- Update em serviço de outro profissional não afeta linhas; inserir serviço em nome de outro é negado.
- Cliente lê a própria solicitação e todos os serviços ativos; não cria serviços; não lê detalhes de bloqueios alheios, mas vê os períodos via view.
- Cliente não consegue mudar o próprio papel.
- Usuário anônimo não lê serviços.

## 3. Critérios de validação do projeto × evidência

| Critério (plano de projeto) | Como foi validado | Resultado |
|---|---|---|
| Cadastro, autenticação e acesso aos perfis | Manual (web): cadastro cria perfil via trigger; login redireciona por papel; logout | OK |
| Criação, edição e desativação de serviços | Manual: tela Meus serviços, formulário, switch Ativo/Inativo; RLS por pgTAP | OK |
| Configuração e atualização da disponibilidade | Manual: intervalos por dia e bloqueios; RLS por pgTAP | OK |
| Exibição correta dos horários livres | Unitário (`slot_calculator_test`) + manual: serviço de 1h com agenda 08–12/13–18 exibe 08:00–11:00 e 13:00–17:00 | OK |
| Impedimento de agendamentos conflitantes | pgTAP: exclusion constraint rejeita sobreposição total e parcial | OK |
| Funcionamento dos estados das solicitações | pgTAP (trigger de transições) + widget test + manual (pendente → aceita) | OK |
| Liberação dos horários após cancelamento/expiração | Constraint só considera `pending`/`accepted`; pgTAP de expiração | OK |
| Restrição de acesso a informações de outros usuários | pgTAP de RLS | OK |
| Avaliação só após conclusão | pgTAP (trigger) + manual: botão Avaliar só em concluídas sem avaliação; nota aparece no catálogo | OK |
| Funcionamento das telas nas plataformas previstas | `flutter build web` e `flutter build apk --debug` concluídos; web testada no Chrome | Web OK; Android compilado, não testado em dispositivo; iOS sem Mac |

## 4. Roteiro de teste manual (demonstração)

1. Entrar como `cliente@demo.com` / `demo1234`.
2. Buscar → categoria Elétrica → "Troca de tomadas e interruptores" → Ver horários e agendar.
3. Escolher uma segunda-feira → observar horários 08:00–11:00 e 13:00–17:00 → escolher 09:00 → enviar com observação.
4. Em Solicitações, ver o cartão **Pendente** com prazo de resposta.
5. Sair; entrar como `prestador@demo.com` / `demo1234`.
6. Painel → Pendentes → **Aceitar**. Em Agendados, botão **Concluir** desabilitado (antes do início).
7. Agenda → adicionar intervalo ou bloqueio; Serviços → editar ou desativar um serviço.
8. Sair; entrar como cliente → Solicitações → Histórico → **Avaliar** a "Limpeza pós-obra" → ver a nota da Ana no catálogo e no detalhe.

## 5. Limitações conhecidas

- Conclusão do atendimento exige que o horário de início já tenha passado; para demonstrar o fluxo completo em sala, o seed já inclui atendimentos concluídos.
- A expiração automática por `pg_cron` roda a cada 5 min no ambiente local; na nuvem a extensão precisa ser habilitada no painel do Supabase. Em ambos os casos a expiração também é aplicada ao abrir as listas.
- Fuso horário assumido: America/Sao_Paulo.
