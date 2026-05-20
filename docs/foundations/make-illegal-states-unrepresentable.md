# Make Illegal States Unrepresentable (MISU)

> **TL;DR.** Use o sistema de tipos para que estados inválidos nem consigam existir. Em vez de validar em runtime, faça o compilador rejeitar o que não deveria ser representável.

## O quê

O princípio diz: **modele seus tipos de forma que combinações inválidas de estado sejam impossíveis de construir**. Validação em runtime continua existindo nas bordas (entrada do usuário, deserialização), mas o núcleo opera com tipos que só admitem estados legítimos.

A formulação ficou famosa em duas frentes:

- Yaron Minsky cunhou a frase em F#/OCaml: *"Make illegal states unrepresentable."*
- Scott Wlaschin popularizou a ideia em livros e palestras sobre *Domain Modeling Made Functional*.

## Por quê

A alternativa (modelar com flags booleanas, campos opcionais e validações dispersas) empurra a checagem para todo chamador. O sistema fica salpicado de `if`s defensivos, e basta um esquecimento para o estado inválido contaminar o resto.

Quando um estado inválido é **impossível de construir**, ele desaparece como classe de bug. Você não precisa testar, alertar, nem recuperar dele, ele simplesmente não existe.

## Como aplicar

### Substitua flags por *sum types* (discriminated unions)

```ts
// ❌ Permite estados inválidos: dead + hungry, alive + dead
interface UserState {
  alive: boolean;
  hungry: boolean;
}
const bad: UserState = { alive: false, hungry: true };  // ?!

// ✅ Apenas estados legítimos
type UserState =
  | { type: 'alive'; hungry: boolean }
  | { type: 'dead' };
```

O compilador agora **força** o cliente a tratar cada caso:

```ts
function describe(state: UserState): string {
  switch (state.type) {
    case 'alive': return state.hungry ? 'vivo e com fome' : 'vivo e satisfeito';
    case 'dead':  return 'morto';
    // Sem `default`: o compilador avisa se um caso novo for adicionado.
  }
}
```

### Tipos para dados validados

Não confunda `string` (qualquer string) com `Email` (string validada). Branded types deixam isso explícito:

```ts
type Email = string & { readonly __brand: 'Email' };

function parseEmail(raw: string): Email | null {
  return /^[^@]+@[^@]+\.[^@]+$/.test(raw) ? (raw as Email) : null;
}

// Aceita só Email, não qualquer string
function sendReceipt(to: Email, amount: number) { /* ... */ }
```

A validação acontece **uma vez** em `parseEmail`. Daí pra frente, `Email` carrega a garantia.

### Estados de processo via *state machines* tipadas

Um pedido pode estar em vários estados, mas cada estado tem dados diferentes. Modele isso explicitamente:

```ts
// ❌ Tudo opcional, qualquer combinação de campos é representável
interface Order {
  status: 'draft' | 'placed' | 'shipped' | 'delivered';
  trackingCode?: string;   // só faz sentido após shipped
  deliveredAt?: Date;      // só faz sentido em delivered
  cancelReason?: string;   // só faz sentido se cancelado (mas e o status?)
}

// ✅ Cada status tem exatamente os dados que pertencem a ele
type Order =
  | { status: 'draft' }
  | { status: 'placed';    placedAt: Date }
  | { status: 'shipped';   placedAt: Date; trackingCode: string }
  | { status: 'delivered'; placedAt: Date; trackingCode: string; deliveredAt: Date }
  | { status: 'canceled';  canceledAt: Date; reason: string };
```

Agora `order.trackingCode` só está acessível depois que o TypeScript confirma que `order.status === 'shipped' | 'delivered'`.

### Non-empty arrays

Listas vazias frequentemente não fazem sentido em domínio (uma fatura precisa de pelo menos um item, uma reunião de pelo menos um participante). Modele:

```ts
type NonEmpty<T> = [T, ...T[]];

function totalInvoice(items: NonEmpty<InvoiceItem>): Money {
  // items[0] é seguro, o compilador garante.
  return items.reduce((acc, it) => acc.plus(it.price), Money.zero());
}
```

## Quando *não* usar

- **Bordas do sistema**: dados que vêm de fora (HTTP, fila, banco) começam como `unknown`/`any`. MISU exige *parsing*, não casting. Use libraries como [Zod](https://zod.dev), [io-ts](https://gcanti.github.io/io-ts) ou [Valibot](https://valibot.dev) para validar e converter na entrada.
- **Tipos extremamente dinâmicos**: quando o domínio é genuinamente fluido (ex.: estado de UI em um editor visual livre), forçar todos os estados em tipos pode engessar mais que ajudar.
- **Linguagens com sistema de tipos fraco.** MISU brilha em linguagens com tipos algébricos (TypeScript, Rust, Swift, F#, Kotlin, Scala). Em linguagens dinâmicas, o ganho diminui.

## Conceitos relacionados

- [Funções puras](./pure-functions.md)
- [DDD: Value Objects](../architecture/domain-driven-design.md)
- [Validação de entrada](../backend/input-validation.md)

## Referências

- **Livro.** Scott Wlaschin, *Domain Modeling Made Functional* (Pragmatic Bookshelf, 2018). Capítulo central sobre MISU.
- **Artigo.** Yaron Minsky, ["Effective ML"](https://blog.janestreet.com/effective-ml-revisited/): Jane Street blog (2010). Origem da expressão.
- **Site.** Scott Wlaschin, [F# for Fun and Profit: Designing with Types](https://fsharpforfunandprofit.com/series/designing-with-types). Série completa.
- **Artigo.** Richard Feldman, ["Making Impossible States Impossible"](https://www.youtube.com/watch?v=IcgmSRJHu_8) (palestra: Elm Conf 2016).
