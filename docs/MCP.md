# Acesso por IA: tokens pessoais, servidor MCP e questões para Anki

Tudo aqui exige a variável `mcp_access` no plano (hoje só o Pro; admin sempre
pode, ver `docs/PLANOS.md`). Sem ela, o MCP, a rota de questões e a criação de
token respondem 403 com `error: "upgrade_required"` e `recurso: "mcp_access"`.
Listar e revogar tokens continua liberado, para quem perdeu o acesso conseguir
apagar os antigos.

## Token pessoal

O usuário gera o token em **Configurações > Acesso por IA**. O token começa com
`apl_`, aparece uma única vez e pode ser revogado na mesma tela.

- Tabela `api_tokens`: guarda só o SHA-256 do token, o nome, os primeiros
  caracteres (`token_prefixo`), `last_used_at` e `revogado_em`.
- Um token ativo por usuário: gerar outro revoga o anterior na hora. O
  índice único parcial `index_api_tokens_on_user_id_ativo` garante isso no banco.
- O token pessoal só funciona em `/api/mcp` e `/api/anki/questoes`. O resto da
  API continua aceitando apenas a sessão do site, então um token colado num
  cliente de IA não apaga cadernos, não mexe em pagamentos e não cria outros
  tokens.
- Limite de 60 requisições por minuto por token, usando o `Rails.cache`
  (Redis em produção).

Rotas (sessão do site):

| Método | Rota | O que faz |
|---|---|---|
| GET | `/api/api_tokens` | Lista o token ativo (0 ou 1) |
| POST | `/api/api_tokens` `{ api_token: { nome } }` | Cria, revoga o anterior e devolve `token` uma vez |
| DELETE | `/api/api_tokens/:id` | Revoga |

## Servidor MCP

`/api/mcp`, montado com a gem oficial [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk)
(~> 1.7) no padrão "Rails (controller)": um `MCP::Server` por requisição, com
o usuário no `server_context`, e o `StreamableHTTPTransport` em modo sem
estado (`stateless: true`) com resposta JSON. Funciona com vários processos
Puma e não guarda sessão em memória.

- `app/services/mcp/ferramentas.rb`: schemas e lógica de cada ferramenta.
- `app/services/mcp/servidor.rb`: transforma as definições em `MCP::Tool` e monta o servidor.
- `config/initializers/mcp.rb`: erros das ferramentas vão para o log.
- A proteção contra DNS rebinding da gem está desligada: ela só libera
  localhost e serve para servidores locais sem autenticação. Aqui toda
  requisição já passou pelo token antes de chegar ao transporte.

Depois de adicionar a gem, rode `bundle install` para atualizar o
`Gemfile.lock` (entram `mcp`, `json_schemer`, `hana`, `regexp_parser` e
`simpleidn`). O Dockerfile usa `BUNDLE_DEPLOYMENT=1`, então o build falha se o
lock não tiver a gem.

Conectar no Claude Code:

```
claude mcp add --transport http apolo https://SEU_DOMINIO/api/mcp \
  --header "Authorization: Bearer apl_..."
```

Ferramentas (todas só de leitura):

| Ferramenta | Fonte |
|---|---|
| `listar_cadernos` | `EstatisticasService#contagens_por_caderno` |
| `estatisticas_caderno(caderno_id)` | `EstatisticasService#caderno` (só cadernos do usuário) |
| `estatisticas_gerais(dias \| data_inicio, data_fim)` | `#resumo`, `#por_disciplina`, `#por_dia` |
| `desempenho_por_assunto(..., disciplina_id?)` | `#hierarquia`; exige `show_stats_table_by_assunto_basic` |
| `pontos_fracos(..., limite, minimo_resolucoes)` | `#pontos_fracos` |
| `questoes_erradas(caderno_id?, dias?, apenas_pendentes?)` | `#questoes_erradas` |
| `questoes_do_caderno(caderno_id, quantidade?, pagina? \| inicio?, situacao?, incluir_comentarios?)` | `AnkiQuestoesService` (até 100 por chamada, paginado; só cadernos do usuário) |
| `questoes_para_anki(ids, incluir_comentarios?)` | `AnkiQuestoesService` (até 100 ids) |

### `questoes_do_caderno`

Devolve as questões de um caderno no mesmo formato de `questoes_para_anki`, na
ordem do caderno.

- `quantidade`: 1 a 100 (padrão 20).
- `pagina` (1, 2, 3...) ou `inicio` (posição a partir de 0; tem prioridade).
- `situacao`: `todas` (padrão), `nao_respondidas`, `erradas` ou `acertadas`,
  pela resolução mais recente do usuário **neste caderno**.
- A resposta traz `paginacao` (`total`, `quantidade`, `inicio`, `entregues`,
  `pagina`, `total_paginas`, `tem_mais`, `proximo_inicio`, `proxima_pagina`) e
  `cota`.

## Cota diária (`McpCotaDiaria`)

Cada questão entregue com dados completos conta 1: `questoes_do_caderno`,
`questoes_para_anki` e `/api/anki/questoes` **quando chamada com token
pessoal**. Limite de **1000 questões por usuário por dia** (horário de
Brasília) e **100 por chamada**. Listar cadernos, estatísticas e
`questoes_erradas` (só ids e classificação) não contam.

- Tabela `mcp_usos_diarios` (`user_id`, `dia`, `questoes`), uma linha por
  usuário e dia. A reserva trava a linha (`SELECT ... FOR UPDATE`), então
  chamadas simultâneas não passam do limite. Ids inexistentes são devolvidos à
  cota.
- Se a chamada pede mais do que resta, entrega só o que cabe: no MCP vem
  `mensagem` e, em `questoes_do_caderno`, `paginacao.proximo_inicio` para
  continuar no dia seguinte; em `questoes_para_anki` e na rota REST, os ids
  que ficaram de fora vêm em `nao_entregues_pela_cota`.
- Com a cota zerada: o MCP responde erro de ferramenta (`isError`) com a hora
  da renovação; a rota REST responde 429 com `Retry-After`.
- `cota` em `listar_cadernos` e nas respostas de questões: `limite_diario`,
  `usadas_hoje`, `restantes_hoje`, `max_por_chamada`, `renova_em`.
- Com a sessão do site, `/api/anki/questoes` não tem cota.

`criar_caderno_de_erros` ficou para uma fase seguinte.

Testar localmente com o MCP Inspector:

```
npx @modelcontextprotocol/inspector
# Transport: Streamable HTTP, URL: http://localhost:3000/api/mcp
# Header: Authorization: Bearer apl_...
```

## Questões para Anki

Aceita token pessoal ou sessão do site, com `mcp_access` no plano. Até 100 ids por requisição.
Com token pessoal, conta na cota diária (ver acima).

```
GET  /api/anki/questoes/123
GET  /api/anki/questoes?ids=123,456       (ou ids[]=123&ids[]=456, ou id=123)
POST /api/anki/questoes   { "ids": [123, 456] }
```

Opcionais: `incluir_comentarios=true` e `limite_comentarios=1..5`.

Cada questão traz `id`, `tipo` (`multipla_escolha`, `certo_errado`,
`discursiva`), `ano`, `banca`, `orgao`, `concurso`, `prova`, `disciplina`,
`assunto`, `topico`, `anulada`, `desatualizada`, `texto_apoio`,
`texto_apoio_imagem`, `enunciado` (texto), `enunciado_html`, `alternativas`
(`letra`, `texto`, `correta`), `gabarito` (`letra`, `texto`),
`cards_ia_existentes`, `minha_resolucao` e, se pedido, `comentarios` (texto e
votos, sem o nome do autor). A lista vem na ordem dos ids pedidos, com
`nao_encontradas` ao final.

## Estatísticas

As consultas que estavam no `ResolucoesController` foram para o
`EstatisticasService`. O controller e o MCP chamam o mesmo código; as respostas
das rotas existentes não mudaram. O `CadernosController#index` passou a contar
acertos e erros de todos os cadernos numa consulta só.
