# Clean Architecture

> **TL;DR.** Quatro camadas concêntricas (Entities, Use Cases, Adapters, Frameworks/Drivers) com uma única regra inviolável: dependências só apontam para **dentro**. O domínio no centro nunca depende de detalhes externos.

## O quê

**Clean Architecture** foi descrita por **Robert C. Martin (Uncle Bob)** em 2012 no [post original](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) e expandida no livro homônimo de 2017.

É uma síntese de várias arquiteturas que apareceram nos anos 2000:

- **Hexagonal**: Alistair Cockburn (2005)
- **Onion Architecture**: Jeffrey Palermo (2008)
- **DCI**: James Coplien e Trygve Reenskaug (2009)
- **BCE**: Ivar Jacobson (1992)

Todas chegam à mesma conclusão: o domínio precisa ficar isolado dos detalhes (UI, banco, framework). Clean Architecture é a versão mais conhecida dessa ideia.

```
                  ┌─────────────────────────────────┐
                  │   Frameworks & Drivers          │  ← Web, DB, Devices
                  │   ┌──────────────────────────┐  │
                  │   │   Interface Adapters     │  │  ← Controllers, Presenters, Gateways
                  │   │   ┌─────────────────────┐│  │
                  │   │   │   Use Cases         ││  │  ← Application Business Rules
                  │   │   │   ┌────────────────┐││  │
                  │   │   │   │   Entities     │││  │  ← Enterprise Business Rules
                  │   │   │   └────────────────┘││  │
                  │   │   └─────────────────────┘│  │
                  │   └──────────────────────────┘  │
                  └─────────────────────────────────┘

                  ← dependências apontam para dentro
```

## Por quê

A motivação central de Clean Architecture é resumida por Uncle Bob na frase:

> "A good architecture allows decisions to be deferred."

Decidir banco, framework, formato de UI **cedo** te trava. Clean Architecture organiza o código para que essas decisões sejam **detalhes substituíveis**: implementadas nas camadas externas, sem contaminar as internas.

Ganhos:

- **Independência de framework.** Substituir Express por Fastify (ou Node por qualquer outra coisa) afeta uma camada só.
- **Independência de UI.** Mesma lógica acessível por web, mobile, CLI, fila.
- **Independência de banco.** Trocar Postgres por DynamoDB sem mexer em regras de negócio.
- **Testabilidade.** As entidades e use cases são testáveis sem framework, banco, UI ou servidor.

A **regra fundamental** (*The Dependency Rule*):

> "Source code dependencies must point only inward, toward higher-level policies."
> (Robert C. Martin, *Clean Architecture*)

Nada em uma camada interna pode saber **alguma coisa** sobre as camadas externas.

## Como aplicar

### As 4 camadas

#### 1) Entities: regras corporativas

Os modelos de negócio mais estáveis, que sobreviveriam mesmo se o software mudasse de framework, banco ou domínio computacional. São **políticas corporativas**, não aplicacionais.

```ts
// src/entities/order.ts
export class Order {
  private constructor(
    readonly id: OrderId,
    readonly items: ReadonlyArray<OrderItem>,
    readonly status: OrderStatus,
  ) {}

  static create(items: OrderItem[]): Order {
    if (items.length === 0) throw new EmptyOrderError();
    return new Order(OrderId.next(), items, 'placed');
  }

  totalWithDiscount(): Money {
    const subtotal = this.items.reduce((acc, i) => acc.plus(i.price), Money.zero());
    return subtotal.isAbove(Money.of(100)) ? subtotal.times(0.9) : subtotal;
  }
}
```

Entidades **não importam** de Use Cases, Adapters ou Frameworks.

#### 2) Use Cases: regras aplicacionais

Orquestram entidades para entregar uma operação específica do sistema. Conhecem entidades e definem interfaces para o que precisam (repositórios, gateways).

```ts
// src/use-cases/create-order.ts
export interface OrderRepository {
  save(order: Order): Promise<void>;
}

export interface PaymentGateway {
  charge(order: Order): Promise<ChargeResult>;
}

export class CreateOrderUseCase {
  constructor(
    private orderRepo: OrderRepository,
    private payments:  PaymentGateway,
  ) {}

  async exec(input: CreateOrderInput): Promise<Order> {
    const order = Order.create(input.items);

    const result = await this.payments.charge(order);
    if (!result.ok) throw new PaymentFailedError(result.reason);

    await this.orderRepo.save(order);
    return order;
  }
}
```

#### 3) Interface Adapters

Convertem dados entre os formatos externos e internos. Aqui vivem:

- **Controllers**: recebem HTTP e chamam use cases.
- **Presenters**: formatam dados para a UI.
- **Gateways**: implementam interfaces declaradas pelos use cases.

```ts
// src/adapters/http/order-controller.ts
export function makeOrderRouter(createOrder: CreateOrderUseCase) {
  const router = Router();
  router.post('/orders', async (req, res) => {
    const input = CreateOrderInputSchema.parse(req.body);
    const order = await createOrder.exec(input);
    res.status(201).json(toJSON(order));
  });
  return router;
}

// src/adapters/persistence/postgres-order-repository.ts
export class PostgresOrderRepository implements OrderRepository {
  constructor(private db: Pool) {}
  async save(order: Order): Promise<void> {
    await this.db.query('INSERT INTO orders ...', [/* ... */]);
  }
}
```

Adapters dependem de Use Cases e Entities, não o contrário.

#### 4) Frameworks & Drivers

Componentes externos: web framework, ORM, broker, cliente HTTP. **Apenas configuração e inicialização** vive aqui.

```ts
// src/main.ts
async function main() {
  const db = await createDb();

  const orderRepo = new PostgresOrderRepository(db);
  const payments  = new StripeGateway(process.env.STRIPE_KEY!);

  const createOrder = new CreateOrderUseCase(orderRepo, payments);

  const app = express();
  app.use('/api', makeOrderRouter(createOrder));
  app.listen(3000);
}
```

### A regra de dependência

```
Frameworks  →  Adapters  →  Use Cases  →  Entities
```

Nunca o inverso. Se um Use Case precisa de algo que vive na camada externa (ex.: enviar email), ele **declara a interface** que precisa; um adapter na camada externa implementa.

Esse é o princípio [DIP](../foundations/solid.md) operacionalizado em escala arquitetural.

### Cruzando as fronteiras

Quando uma chamada precisa cruzar uma fronteira (ex.: dados saindo do Use Case para o Presenter), use **estruturas de dados simples**, não objetos do domínio diretamente.

```ts
// Output do use case, DTO simples, sem comportamento
interface CreateOrderOutput {
  id:     string;
  status: 'placed' | 'paid' | 'shipped';
  total:  { amount: number; currency: string };
}

class CreateOrderUseCase {
  async exec(input: CreateOrderInput): Promise<CreateOrderOutput> {
    const order = Order.create(input.items);
    /* ... */
    return {
      id:     order.id.value,
      status: order.status,
      total:  { amount: order.totalWithDiscount().amount, currency: 'BRL' },
    };
  }
}
```

Por quê? Para que mudanças internas em `Order` (adicionar campo, mudar método) não obriguem mudanças no adapter HTTP.

### Hexagonal vs. Clean: qual a diferença?

Na prática, **são a mesma ideia com vocabulários diferentes**:

| Hexagonal | Clean Architecture |
|---|---|
| Domínio | Entities + Use Cases |
| Driving ports | Interfaces dos Use Cases |
| Driven ports | Interfaces definidas pelos Use Cases |
| Driving adapters | Controllers (Interface Adapters) |
| Driven adapters | Gateways (Interface Adapters) |
| (sem camada explícita) | Frameworks & Drivers |

Clean Architecture é mais explícita sobre a separação entre **regras corporativas** (Entities, mais estáveis) e **regras aplicacionais** (Use Cases, mais voláteis).

## Quando *não* usar

- **Sistemas pequenos / scripts.** O overhead de quatro camadas e DTOs entre fronteiras é desproporcional.
- **CRUD direto**: quando 90% das operações são "ler/criar/atualizar registro", a arquitetura completa cria atrito sem ganho proporcional. *Transaction Script* ou Layered simples basta.
- **Equipe sem maturidade para a disciplina.** Clean Architecture exige convicção. Se "só nesse caso vamos burlar a regra de dependência", o ganho desaparece em poucos meses.

## Conceitos relacionados

- [Hexagonal](./hexagonal-ports-adapters.md), parente próximo.
- [Layered Architecture](./layered-architecture.md), versão mais simples.
- [Domain-Driven Design](./domain-driven-design.md), combina bem; bounded contexts viram aplicações Clean.
- [SOLID](../foundations/solid.md), todos os 5 princípios sustentam Clean Architecture.

## Referências

- **Livro.** Robert C. Martin, *Clean Architecture* (Prentice Hall, 2017). Texto canônico.
- **Artigo.** Robert C. Martin, ["The Clean Architecture"](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) (2012). Post original.
- **Artigo.** Jeffrey Palermo, ["The Onion Architecture: Part 1"](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/) (2008). Predecessor de Clean.
- **Livro.** Tom Hombergs, *Get Your Hands Dirty on Clean Architecture* (Packt, 2019). Aplicação prática.
- **Artigo.** Herberto Graça, ["DDD: Hexagonal, Onion, Clean, CQRS, How I put it all together"](https://herbertograca.com/2017/11/16/explicit-architecture-01-ddd-hexagonal-onion-clean-cqrs-how-i-put-it-all-together/). Síntese clara das relações entre elas.
- **Artigo.** Mark Seemann, ["Layers: Onions, Ports, Adapters: it's all the same"](https://blog.ploeh.dk/2013/12/03/layers-onions-ports-adapters-its-all-the-same/). Defesa pragmática da equivalência das abordagens.
