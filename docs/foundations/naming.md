# Naming

> **TL;DR.** Bons nomes revelam intenção. Eles são a documentação que não envelhece, porque vivem nos identificadores que o código de fato usa. Renomear é uma das refatorações mais baratas e mais transformadoras.

## O quê

*Naming* é o conjunto de decisões sobre como chamar variáveis, funções, classes, módulos, tabelas, eventos, métricas, tudo que tem um nome no sistema. Bons nomes:

- **Revelam intenção**: explicam o "por quê", não só o "o quê".
- **Distinguem-se entre si**: `getActiveCustomers` é diferente de `getActiveAccounts`.
- **São pronunciáveis**: facilita conversas verbais durante review e debug.
- **São pesquisáveis**: `MAX_CLASSES_PER_STUDENT` é encontrável; `7` não é.

> "There are only two hard things in Computer Science: cache invalidation and naming things."
> (Phil Karlton)

## Por quê

Nomes ruins envenenam a base lentamente. Cada nome confuso obriga o leitor a deduzir do contexto, abrir o arquivo, ler implementação, perguntar para o autor. Multiplicado por toda a base, vira atrito permanente.

Bons nomes:

- **Reduzem necessidade de comentários**: se `daysSinceLastLogin` está claro, comentar é redundante.
- **Aceleram revisão**: o reviewer entende o diff sem precisar reconstruir o contexto.
- **Onboarding mais rápido**: código que se explica sozinho diminui a curva.
- **Facilitam refatoração**: encontrar todos os usos de `customer` é trivial; de `c` é caça ao tesouro.

## Como aplicar

### Revele intenção

```ts
// ❌ O quê é d? Qual a unidade?
const d = 86400000;

// ✅
const ONE_DAY_IN_MS = 86_400_000;
```

```ts
// ❌
function check(u: User): boolean {
  return u.s && u.p > 0;
}

// ✅
function canPurchase(user: User): boolean {
  return user.isSubscribed && user.balance > 0;
}
```

### Use distinções significativas

Evite "ruído" (`Manager`, `Data`, `Info`, `Helper`) quando não acrescenta sentido:

```ts
// ❌ Qual a diferença entre Customer, CustomerInfo, CustomerData?
class CustomerInfo { /* ... */ }
class CustomerData { /* ... */ }

// ✅ Discrimina por papel
class Customer       { /* ... */ }
class CustomerProfile { /* ... */ }
class CustomerOrders  { /* ... */ }
```

### Use nomes pronunciáveis e pesquisáveis

```ts
// ❌ "ymdh em ess", impossível de discutir verbalmente
const ymdhmsstamp = '2024-01-15T10:30:00Z';

// ✅
const isoTimestamp = '2024-01-15T10:30:00Z';
```

```ts
// ❌ Procurar "7" no projeto retorna milhares de matches
if (age >= 7) { /* ... */ }

// ✅
const MINIMUM_AGE_FOR_LEGAL_CONSENT = 7;
if (age >= MINIMUM_AGE_FOR_LEGAL_CONSENT) { /* ... */ }
```

### Substantivos para classes, verbos para funções

- **Classes / tipos / variáveis** → substantivos (`Customer`, `OrderRepository`, `cart`).
- **Funções** → verbos ou frases verbais (`save`, `calculateTotal`, `isExpired`).
- **Booleanos** → prefixo afirmativo (`isActive`, `hasPermission`, `canEdit`). Evite negações duplas: prefira `isEnabled` a `notDisabled`.

```ts
// ✅
class OrderService {
  createOrder(items: Item[]): Order { /* ... */ }
  isOrderPaid(order: Order):  boolean { /* ... */ }
}
```

### Tamanho proporcional ao escopo

Variáveis de escopo curto podem ter nomes curtos. Variáveis de escopo amplo precisam de nomes mais expressivos.

```ts
// ✅ Loop pequeno, `i` é convenção universal
for (let i = 0; i < items.length; i++) { /* ... */ }

// ✅ Callback curto, `item` está claro pelo contexto
items.filter((item) => item.active);

// ❌ Variável "global" do módulo com nome curto perde contexto
let s = new Server(); // o quê é s?

// ✅
let server = new Server();
```

Heurística (Steve McConnell, *Code Complete*): nome de 8–20 caracteres tende a ser ideal para identificadores de escopo amplo.

### Convenções por linguagem

Cada comunidade tem convenções dominantes. Siga as da sua linguagem para que seu código pareça "normal" para quem chega.

| Linguagem | Variáveis/Funções | Classes / Tipos | Constantes |
|---|---|---|---|
| TypeScript / JavaScript | `camelCase` | `PascalCase` | `SCREAMING_SNAKE_CASE` |
| Python | `snake_case` | `PascalCase` | `SCREAMING_SNAKE_CASE` |
| Go | `camelCase` (privado), `PascalCase` (público) | `PascalCase` | `PascalCase` |
| Rust | `snake_case` | `PascalCase` | `SCREAMING_SNAKE_CASE` |
| SQL | `snake_case` (tabelas: plural; colunas: singular) |, | `SCREAMING_SNAKE_CASE` |

### Não codifique tipo no nome (notação húngara)

Linguagens com tipagem estática tornam prefixos de tipo redundantes:

```ts
// ❌
const strName: string = 'Alice';
const intAge:  number = 30;
const bIsActive: boolean = true;

// ✅
const name: string  = 'Alice';
const age:  number  = 30;
const isActive: boolean = true;
```

Notação húngara fazia sentido em C nos anos 80, quando o compilador não ajudava. Em TypeScript, é ruído.

### Nomes para tipos de domínio

Tipos do domínio merecem nomes próprios, não use `string` ou `number` cruamente para conceitos importantes. Ver [MISU](./make-illegal-states-unrepresentable.md).

```ts
// ❌
function chargeCustomer(customerId: string, amount: number) {}

// ✅ Branded types
type CustomerId = string & { readonly __brand: 'CustomerId' };
type Money      = { amount: number; currency: 'BRL' | 'USD' };

function chargeCustomer(customerId: CustomerId, amount: Money) {}
```

### Nomes para funções booleanas

Funções que retornam booleano devem **soar como pergunta**:

```ts
// ❌ Parece pedir uma ação
function process(order: Order): boolean { /* ... */ }

// ✅ Parece pergunta
function isProcessable(order: Order): boolean { /* ... */ }
function canFulfill(order: Order):     boolean { /* ... */ }
function hasItems(order: Order):       boolean { /* ... */ }
```

### Nomes para coleções

- **Plural** para coleções: `users`, `orders`.
- **Singular** para o item: `for (const user of users)`.

```ts
// ❌
const userList = [];        // redundante: o tipo já diz que é lista
const allUsers = [];        // redundante: variáveis nomeadas pelo conteúdo
const arrUsers = [];        // notação húngara

// ✅
const users = [];
```

### Evite contexto desnecessário no nome

Quando o nome do módulo/classe já fornece contexto, não repita:

```ts
// ❌
class User {
  userName:  string;
  userEmail: string;
  userAge:   number;
}

// ✅
class User {
  name:  string;
  email: string;
  age:   number;
}
// Acesso: user.name, "user" já está no contexto.
```

### Renomear é barato e curativo

IDEs modernas renomeiam com segurança em segundos. Se um nome melhor surgiu na sua cabeça durante o trabalho, **renomeie agora**. O custo é mínimo; o benefício composto ao longo dos meses é enorme.

> "If you have a bad name, you should change it as soon as you discover the bad name."
> (Robert C. Martin, *Clean Code* (cap. 2))

## Quando *não* usar

- **Nomes longos em escopos muito curtos.** `for (let customerIndex = 0; ...)` em um loop de 3 linhas é overkill, `i` basta.
- **Convenções estranhas só por estética.** Não invente padrões, siga o que o ecossistema já estabeleceu (ver tabela acima).
- **Refatorar nomes em código que vai ser deletado.** Não invista esforço em código que sai amanhã.

## Conceitos relacionados

- [Code smells](./code-smells.md), *Mysterious Name*, *Magic Number*.
- [MISU](./make-illegal-states-unrepresentable.md), nomes para tipos de domínio.
- [DRY: KISS, YAGNI](./dry-kiss-yagni.md).

## Referências

- **Livro.** Robert C. Martin, *Clean Code* (Prentice Hall, 2008). Capítulo 2 ("Meaningful Names") é a referência mais citada sobre o tema.
- **Livro.** Steve McConnell, *Code Complete*, 2ª ed. (Microsoft Press, 2004). Capítulo 11 ("The Power of Variable Names") discussão extensiva e baseada em pesquisa.
- **Livro.** Tim Ottinger, capítulo "Meaningful Names" em diversas coletâneas de Robert Martin.
- **Artigo.** Phil Karlton, origem da frase canônica sobre naming (ver [Martin Fowler: TwoHardThings](https://martinfowler.com/bliki/TwoHardThings.html)).
- **Artigo.** Joel Spolsky, ["Making Wrong Code Look Wrong"](https://www.joelonsoftware.com/2005/05/11/making-wrong-code-look-wrong/). Defesa pragmática de "Apps Hungarian".
- **Artigo.** [Google Engineering Practices: Naming](https://google.github.io/styleguide). Style guides com decisões justificadas.
