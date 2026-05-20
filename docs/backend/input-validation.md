# Validação de Entrada

> **TL;DR.** Valide na borda: todo dado externo é hostil até prova em contrário. Use schemas declarativos para validar e *parsear* simultaneamente, depois confie nos tipos.

## O quê

**Validação de entrada** é o processo de garantir que dados recebidos do mundo externo (requests HTTP, mensagens de fila, leitura de arquivos, retornos de APIs de terceiros) atendem às expectativas antes de chegar à lógica de negócio.

A abordagem moderna é **parse, don't validate**: em vez de validar e continuar usando `any`/`unknown`, transforme o dado em um tipo refinado. Daí pra frente, o tipo carrega a garantia.

> "Parse, don't validate."
> (Alexis King ([2019](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/)))

## Por quê

Sem validação na borda, dois problemas aparecem:

1. **Dados malformados poluem o sistema**: `null` onde se esperava string, `"42"` onde se esperava número, datas em formatos imprevistos.
2. **Validação ad-hoc se espalha**: cada handler escreve a sua, o que abre brechas e cria mensagens de erro inconsistentes.

Validar uma vez, com schema declarativo, na entrada do sistema:

- Garante uma única fonte de verdade do contrato.
- Gera mensagens de erro padronizadas (acoplam ao [tratamento de erros](./error-handling.md)).
- Habilita tipagem estática a partir do schema, o que entra na função vem **já tipado**.

## Como aplicar

### Schema declarativo + parse

Use uma library de schema que **parseia** (não só valida). Em TypeScript, [Zod](https://zod.dev), [Valibot](https://valibot.dev), [io-ts](https://gcanti.github.io/io-ts) e [ArkType](https://arktype.io) são opções consolidadas.

```ts
import { z } from 'zod';

const LoginInput = z.object({
  username: z.string().min(1),
  password: z.string().min(8),
});

type LoginInput = z.infer<typeof LoginInput>;  // tipo deduzido

function login(rawBody: unknown): Result {
  const input = LoginInput.parse(rawBody);  // lança se inválido
  // input: { username: string; password: string }  ← tipado, seguro
  return authenticate(input);
}
```

O schema define **uma vez** o que é um input válido. O tipo TypeScript vem de graça.

### Branded types para domínio

Quando um campo tem semântica (CPF, e-mail, telefone), valide e converta para um tipo nominal:

```ts
const Email = z.string().email().brand<'Email'>();
type Email = z.infer<typeof Email>;  // string & { readonly [brand]: 'Email' }

const SignupInput = z.object({
  email: Email,
  age:   z.number().int().min(18),
});

// Funções de domínio aceitam o tipo refinado
function sendWelcome(to: Email) { /* ... */ }
```

Daí pra frente, o TypeScript impede passar uma string qualquer onde se espera `Email`. Ver [MISU](../foundations/make-illegal-states-unrepresentable.md).

### Múltiplos erros

Reporte **todos** os erros encontrados, não só o primeiro, o usuário deve poder corrigir tudo de uma vez.

```ts
const result = LoginInput.safeParse(rawBody);

if (!result.success) {
  const errors = result.error.issues.map(issue => ({
    field:   issue.path.join('.'),
    code:    `field_${issue.path.join('_')}_${issue.code}`,
    message: issue.message,
  }));
  throw new DomainErrorList(errors);
}
```

### Integração com mensagens de erro

A library de validação produz mensagens em inglês por padrão. Para internacionalizar, mapeie o **code** do issue para a tabela de [exceptions](./error-handling.md), seguindo a convenção:

- `field_<nome>`: nome amigável do campo (ex.: `field_password` → "Senha").
- `validator_<regra>`: descrição da regra (ex.: `validator_required` → "%s é um campo obrigatório").

A camada de erro busca a mensagem traduzida e interpola o nome do campo:

```
field=password, validator=required → "Senha é um campo obrigatório"
```

### Validadores customizados

Implemente validadores específicos do domínio (CPF, CNPJ, IBAN, código interno) e registre-os no schema:

```ts
const cpfRegex = /* ... */;

const Cpf = z.string().regex(cpfRegex, { message: 'validator_cpf' }).brand<'CPF'>();

const PersonInput = z.object({
  name: z.string(),
  cpf:  Cpf,
});
```

### Tags úteis (Zod / Valibot)

Operação comum em qualquer library:

- `required` (default em Zod), `optional()`
- `min(n)`, `max(n)`, `length(n)`
- `email()`, `url()`, `uuid()`, `regex()`
- `int()`, `positive()`, `negative()`
- `array().nonempty()`

### Erros comuns

- **Validar mas ignorar o resultado**: chamar `.parse()` e seguir usando o `any` original. Use o **valor retornado** pelo parse.
- **Validar em vários lugares**: borda da API valida, use case valida de novo, repositório valida mais uma vez. Valide na entrada, confie nos tipos depois.
- **Mensagens vazando código**: `Invalid input: expected string, received number at age` não é mensagem para usuário. Mapeie para mensagens humanas.

## Quando *não* usar

- **Dados internos confiáveis**: entre serviços do mesmo dono, com contratos versionados (gRPC, schemas Avro/Protobuf), a validação rigorosa pode ser excesso. Confie no contrato e foque em mudanças de schema.
- **Performance crítica**: em hot paths com milhões de eventos por segundo, parse completo pode ser caro. Use *streaming parsers* ou validação amostral.
- **Tipos extremamente dinâmicos**: admin tools, editores visuais. O schema engessa demais; trabalhe com `unknown` controlado.

## Conceitos relacionados

- [Tratamento de erros](./error-handling.md), onde as mensagens de validação são formatadas.
- [MISU](../foundations/make-illegal-states-unrepresentable.md), validar uma vez, confiar no tipo depois.
- [API design: REST](./api-design-rest.md)

## Referências

- **Artigo.** Alexis King, ["Parse, don't validate"](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) (2019). Texto canônico da abordagem.
- **Documentação.** [Zod docs](https://zod.dev). Library mais popular do ecossistema TypeScript.
- **Documentação.** [Valibot](https://valibot.dev). Alternativa modular e tree-shakable.
- **Artigo.** Mark Seemann, ["Design by Type: Static Types Are Documentation"](https://blog.ploeh.dk/2011/06/13/StaticstronglytypedlanguagesEmpiricalevidence/).
