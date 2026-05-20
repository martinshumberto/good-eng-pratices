# Tratamento de Erros

> **TL;DR.** Padronize a forma como erros são gerados, propagados e expostos pela API. Use códigos estáveis, mensagens traduzíveis e separe erro técnico (para log) de mensagem (para o usuário).

## O quê

Tratamento de erros é a **disciplina de comunicar falhas** ao longo do sistema: do código que detecta o problema até o cliente que recebe a resposta. Inclui três aspectos:

1. **Identificação**: cada categoria de erro tem um *code* estável (não depende de texto).
2. **Propagação**: o erro caminha pela stack mantendo contexto (causa raiz, dados associados).
3. **Apresentação**: o cliente HTTP recebe um payload previsível, traduzido e seguro (sem vazar detalhes internos em produção).

## Por quê

Sem padronização, cada endpoint inventa o seu jeito de falhar: alguns retornam `{ error: 'string' }`, outros HTTP 200 com `{ success: false }`, outros lançam stack traces. O cliente é obrigado a tratar N formatos. Logs e métricas perdem sentido, não há um campo confiável para "tipo do erro".

Um esquema único traz:

- **Contratos previsíveis** para o cliente.
- **Observabilidade real** (métricas por `code` de erro, alertas por classe).
- **Internacionalização nativa**: mensagens viajam separadas dos códigos.
- **Segurança**: detalhes técnicos ficam fora da resposta em produção.

## Como aplicar

### Envelope padrão

Toda resposta (sucesso ou falha) segue o mesmo envelope. Em caso de erro:

```json
{
  "success": false,
  "return": null,
  "errors": [
    {
      "code":    "resource_not_found",
      "error":   "user_id=abc not found in repository",
      "message": "Recurso 'abc' não encontrado!"
    }
  ]
}
```

| Campo | Para quem | Conteúdo |
|---|---|---|
| `code` | Cliente (programa) | Identificador estável da exceção. Use snake_case. |
| `error` | Operação (log/debug) | Erro técnico cru. **Omitido em produção** para não vazar detalhes. |
| `message` | Usuário final | Mensagem traduzida pelo `Accept-Language`. |

### Codes estáveis, mensagens externas

Mantenha mensagens fora do código, em tabela do banco, arquivo i18n versionado ou serviço de tradução. O *code* fica no source code; o **texto** muda sem rebuild.

```sql
-- Exemplo de tabela de exceptions
CREATE TABLE exceptions (
  id           UUID PRIMARY KEY,
  code         TEXT NOT NULL,
  status_code  INT  NOT NULL,
  language     TEXT NOT NULL,           -- 'PT', 'EN', 'ES'
  message      TEXT NOT NULL,
  UNIQUE (code, language)
);

INSERT INTO exceptions (code, status_code, language, message) VALUES
  ('invalid_alphanum', 400, 'PT', '%s deve ser alfanumérico'),
  ('invalid_alphanum', 400, 'EN', '%s must be alphanumeric'),
  ('invalid_alphanum', 400, 'ES', '%s debe ser alfanumérico');
```

Mensagens podem ter argumentos posicionais (`%s`, `%d`) preenchidos em runtime.

### Modelagem do erro de domínio

Em TypeScript, defina um tipo único para erros estruturados. Use *discriminated union* ou uma classe com propriedades explícitas.

```ts
export interface AppError {
  code: string;            // ex.: 'resource_not_found'
  cause?: Error;           // erro original (para log)
  args?: unknown[];        // valores para interpolar na mensagem
}

export class DomainError extends Error implements AppError {
  constructor(
    public readonly code: string,
    public readonly cause?: Error,
    public readonly args?: unknown[],
  ) {
    super(code);
  }
}
```

### Geração de resposta

A camada HTTP traduz `AppError` em resposta:

```ts
async function errorMiddleware(err: unknown, req: Request, res: Response) {
  const lang = req.header('Accept-Language') ?? 'PT';

  // Erros não conhecidos → fallback 500
  if (!(err instanceof DomainError)) {
    return res.status(500).json(envelope([{
      code: 'internal_server_error',
      error: isProd ? null : String(err),
      message: await translate('internal_server_error', lang),
    }]));
  }

  const meta = await exceptions.lookup(err.code, lang);
  return res.status(meta.statusCode).json(envelope([{
    code: err.code,
    error: isProd ? null : err.cause?.message ?? null,
    message: format(meta.message, err.args ?? []),
  }]));
}
```

### Cadeia de erros: preserve a causa raiz

Quando um erro vem de outra função, encadeie sem perder a origem. O cliente vê o erro mais profundo na cadeia (o mais específico):

```ts
async function someUseCase() {
  try {
    return await other();
  } catch (cause) {
    throw new DomainError('some_use_case_error', cause as Error);
  }
}

async function other() {
  throw new DomainError('another_function_error');
}
```

Retorno ao cliente:

```json
{
  "code":    "another_function_error",
  "message": "Erro especificado!"
}
```

A camada HTTP propaga o erro mais específico; o log retém a cadeia completa.

### Múltiplos erros: array

Validações independentes (vários campos inválidos) devem retornar todos os problemas de uma vez. O cliente conserta tudo em uma única ida:

```ts
const errors: DomainError[] = [];

if (!isValidEmail(input.email))
  errors.push(new DomainError('field_email_invalid'));

if (!isStrongPassword(input.password))
  errors.push(new DomainError('field_password_weak'));

if (errors.length) throw new DomainErrorList(errors);
```

Resposta:

```json
{
  "success": false,
  "return": null,
  "errors": [
    { "code": "field_email_invalid",   "message": "E-mail inválido" },
    { "code": "field_password_weak",   "message": "Senha fraca" }
  ]
}
```

### Argumentos contextuais

Permita que o erro carregue valores que entram na mensagem:

```ts
throw new DomainError('resource_not_found', cause, [resourceId]);
```

Mensagem registrada como `"Recurso '%s' não encontrado!"` → renderiza `"Recurso '18' não encontrado!"`.

## Quando *não* usar

- **APIs públicas com padrão de mercado.** Se você está expondo um padrão estabelecido ([RFC 7807 Problem Details](https://www.rfc-editor.org/rfc/rfc7807), [JSON:API errors](https://jsonapi.org/format/#errors)), siga o padrão da comunidade, não invente envelope próprio.
- **Microsserviços internos com gRPC.** gRPC tem [seu próprio modelo de erro](https://grpc.io/docs/guides/error/) (status codes + Status proto). Adapte; não recrie.
- **Erros inesperados (panics, OOM).** Não tente "tratar", deixe quebrar, log estruturado + alerta, reinicie a instância.

## Conceitos relacionados

- [Validação de entrada](./input-validation.md), onde o erro de validação nasce.
- [API design (REST](./api-design-rest.md)) uso correto de status codes HTTP.
- [Structured logging](../observability/structured-logging.md), como persistir a cadeia de erros.

## Referências

- **RFC.** Erik Wilde, [RFC 7807: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807) (IETF, 2016). Padrão recomendado.
- **Livro.** Michael Nygard, *Release It!*, 2ª ed. (Pragmatic Bookshelf, 2018). Capítulos sobre falhas em produção.
- **Artigo.** Vlad Khononov, ["Designing API error responses"](https://blog.restcase.com/rest-api-error-handling-problem-details-response/).
- **Site.** [microservices.io: Microservice Architecture pattern: Distributed tracing](https://microservices.io/patterns/observability/distributed-tracing.html). Como erros se conectam a traces.
