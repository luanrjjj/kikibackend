# Acesso por IA: tokens pessoais, servidor MCP e questões para Anki

## Token pessoal

O usuário gera o token em **Configurações > Acesso por IA**. O token começa com
`apl_`, aparece uma única vez e pode ser revogado na mesma tela.

- Tabela `api_tokens`: guarda só o SHA-256 do token, o nome, os primeiros
  caracteres (`token_prefixo`), `last_used_at` e `revogado_em`.
- Máximo de 10 tokens ativos por usuário.
- O token pessoal só funciona em `/api/mcp` e `/api/anki/questoes`. O resto da
  API continua aceitando apenas a sessão do site, então um token colado num
  cliente de IA não apaga cadernos, não mexe em pagamentos e não cria outros
  tokens.
- Limite de 60 requisições por minuto por token, usando o `Rails.cache`
  (Redis em produção).

Rotas (sessão do site):

| Método | Rota | O que faz |
|---|---|---|
| GET | `/api/api_tokens` | Lista os tokens ativos |
| POST | `/api/api_tokens` `{ api_token: { nome } }` | Cria e devolve `token` uma vez |
| DELETE | `/api/api_tokens/:id` | Revoga |

## Servidor MCP

`POST /api/mcp`, transporte Streamable HTTP sem estado, resposta em JSON.
Implementado à mão em `app/services/mcp/` (sem a gem `mcp`), com
`initialize`, `ping`, `tools/list` e `tools/call`. GET e DELETE devolvem 405.

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
| `questoes_para_anki(ids, incluir_comentarios?)` | `AnkiQuestoesService` (até 50 ids) |

`criar_caderno_de_erros` ficou para uma fase seguinte.

Testar localmente com o MCP Inspector:

```
npx @modelcontextprotocol/inspector
# Transport: Streamable HTTP, URL: http://localhost:3000/api/mcp
# Header: Authorization: Bearer apl_...
```

## Questões para Anki

Aceita token pessoal ou sessão do site. Até 100 ids por requisição.

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
