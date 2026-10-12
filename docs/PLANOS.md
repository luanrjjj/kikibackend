# Planos e variáveis

Cada plano (tabela `planos`, editável no painel admin) tem uma lista
`variaveis` no formato `chave:valor`. `true`/`false` podem vir em qualquer
caixa; números viram inteiros; `chave` sozinha vale `true`. A lógica está em
`app/models/plano.rb` e `User#variaveis`.

| Variável | O que controla | Free | Básico | Pro |
|---|---|---|---|---|
| `limit_resolutions_free` | Questões que dá para resolver (total) | 100 | ilimitado | ilimitado |
| `anki_export_by_week_free` | Exportações para o Anki por semana (segunda a domingo) | 1 | ilimitado | ilimitado |
| `create_notebook_basic` | Criar cadernos | sim | sim | sim |
| `guide_access` | Abrir os guias (a lista continua pública) | não | sim | sim |
| `show_stats_table_by_assunto_basic` | Estatísticas por assunto | não | sim | sim |
| `edital_verticalized_advanced` | Exportar o edital verticalizado | não | sim | sim |
| `excel_stats_export_advanced` | Exportar estatísticas para Excel | não | não | sim |
| `ankis_personalized_advanced` | Ankis personalizados | não | não | sim |
| `ia_concept_question_extraction_advanced` | Flashcards de conceitos com IA | não | não | sim |
| `mcp_access` | Gerar token e usar MCP / questões para Anki | não | não | sim |

- Recurso sem a variável conta como `false`; limite sem a variável é ilimitado.
- Quem não tem assinatura ativa (inclusive expirada) usa o plano Free. Assinante
  com `plan` contendo "basic" usa o Básico; os demais usam o Pro (`Advanced`,
  `Pro` e `Avançado` são o mesmo nível). Admin pode tudo, sem limites.
- Se o plano não existir na tabela, valem os padrões de `Plano::PADROES`.
- A migração `db/data/20261012160000_reconfigura_planos.rb` grava esses valores.
  Rode com `bin/rails seed:migrate`. Variáveis desconhecidas (como
  `max_caderno_questoes`) são mantidas.
- `limit_resolutions_free` agora vem só do plano; a configuração global com o
  mesmo nome deixou de ser usada.

Quando o plano não libera algo, a API responde 403:

```json
{ "error": "upgrade_required", "recurso": "guide_access", "plano_minimo": "basic", "message": "...", "limite": 1 }
```

O frontend abre o modal de assinatura sempre que recebe esse erro.
