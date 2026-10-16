# Explicação de questões por IA (kikiapps#22)

No Resolver, o botão de IA (ao lado de Exportar) abre um modal com a
explicação da questão: o que ela cobra, por que o gabarito está certo, um
comentário por alternativa, conceitos-chave e uma dica.

## Como funciona

1. `POST /api/questaos/:id/explicacao_ia` (usuário logado), body opcional `{ provedor: "deepseek" }`.
2. Se `questaos.deepseek_explicacao` já está preenchida, devolve a explicação salva **sem chamar a IA**.
3. Se não, chama o DeepSeek (`DeepSeekService.chat_json`, modelo `deepseek-chat`, resposta em JSON), normaliza e salva na coluna.
   - A gravação só acontece se a coluna ainda estiver vazia. Se duas pessoas pedirem a mesma questão ao mesmo tempo, a primeira explicação salva vale para as duas.
4. O usuário avalia em `POST /api/questaos/:id/explicacao_ia/avaliacao` `{ util: true | false }` (tabela `explicacao_ia_avaliacoes`, uma por usuário, questão e provedor; dá para trocar).

Resposta:

```json
{
  "provedor": "deepseek", "provedor_nome": "DeepSeek", "questao_id": 123,
  "gerada_agora": false,
  "explicacao": {
    "resumo": "...", "gabarito": "B", "explicacao": "...",
    "alternativas": [{ "letra": "A", "correta": false, "comentario": "..." }],
    "conceitos": ["..."], "dica": "...",
    "versao": 1, "modelo": "deepseek-chat", "gerada_em": "2026-10-16T02:00:00Z"
  },
  "avaliacao": true,
  "avaliacoes": { "uteis": 10, "nao_uteis": 1 }
}
```

## Limites e erros

- Até 30 explicações **novas** (que chamam a IA) por usuário por dia (`Rails.cache`). As já salvas não contam. Admin não tem limite.
- 503 se a IA falhar ou devolver algo sem explicação; 429 no limite; 404 ao avaliar uma questão sem explicação.
- Admin pode mandar `regenerar: true` para gerar de novo e sobrescrever (por exemplo, quando a explicação teve muitas avaliações negativas).

## Outros provedores

Cada provedor tem a própria coluna (`<provedor>_explicacao`, jsonb) e uma
entrada em `ExplicacaoIaService::PROVEDORES` com um serviço que responda a
`chat_json(prompt)`. O frontend manda `provedor` no body.

Requer `DEEPSEEK_API_KEY` no ambiente.
