# Layered Architecture

> **TL;DR.** Organize o código em camadas horizontais (Apresentação, Aplicação, Domínio, Infraestrutura) com regras claras sobre quem pode chamar quem. É a arquitetura mais comum, e funciona bem quando aplicada com disciplina.

## O quê

**Layered Architecture** (também *N-tier* ou *Multi-layered*) divide a aplicação em **camadas horizontais**, cada uma com uma responsabilidade clara. A camada superior depende das inferiores; as inferiores ignoram quem está acima.

Estrutura clássica em 4 camadas:

```
┌─────────────────────────────┐
│       Presentation          │  HTTP handlers, UI, CLI
├─────────────────────────────┤
│       Application           │  Use cases / orquestração
├─────────────────────────────┤
│         Domain              │  Regras de negócio puras
├─────────────────────────────┤
│      Infrastructure         │  Banco, APIs externas, filas
└─────────────────────────────┘
```

O conceito é antigo (ver Edsger Dijkstra, *The Structure of the "THE"-Multiprogramming System*, 1968), mas foi popularizado em livros como *Patterns of Enterprise Application Architecture* (Fowler, 2002) e *Domain-Driven Design* (Evans, 2003).

## Por quê

Layered é a arquitetura **default** da maioria dos projetos pelo motivo certo: separa preocupações de forma que cabeças e ferramentas conhecem. A camada de apresentação muda pelo design da UI; a de banco muda pelo schema; o domínio idealmente muda pelo negócio. Mudanças tendem a ficar localizadas.

Os ganhos:

- **Familiaridade.** Quase todo desenvolvedor reconhece "controller → service → repository".
- **Reuso.** Múltiplas presentations (HTTP, gRPC, CLI) podem compartilhar a mesma camada de aplicação.
- **Testabilidade.** Cada camada testável independentemente, domínio com unit tests, infra com integração.

Trade-offs aparecem quando o sistema cresce, ver [Hexagonal](./hexagonal-ports-adapters.md) e [Clean Architecture](./clean-architecture.md), que tratam de problemas que Layered tradicional não resolve bem.

## Como aplicar

### As 4 camadas

#### 1) Presentation

Adaptação a um canal específico, HTTP, gRPC, CLI, fila, UI. Traduz entrada do mundo externo em chamadas para a aplicação, e o retorno em formato do canal.

```ts
// src/presentation/http/order-controller.ts
export async function createOrderHandler(req: Request, res: Response) {
  const input = CreateOrderInput.parse(req.body);     // valida entrada
  const order = await createOrderUseCase.exec(input); // chama aplicação
  res.status(201).json(order);                        // serializa saída
}
```

A camada de apresentação **não tem regra de negócio**. Se você está escrevendo `if (order.total > 100) { ... }` no controller, isso pertence ao domínio.

#### 2) Application (ou Use Cases)

Orquestra um caso de uso completo, combina chamadas de domínio + infraestrutura para entregar uma operação do sistema.

```ts
// src/application/create-order-use-case.ts
export class CreateOrderUseCase {
  constructor(
    private orderRepo: OrderRepository,
    private payments:  PaymentService,
    private events:    EventBus,
  ) {}

  async exec(input: CreateOrderInput): Promise<Order> {
    const order   = Order.create(input);              // domínio puro
    const charged = await this.payments.charge(order);
    if (!charged.ok) throw new Error('payment_failed');

    await this.orderRepo.save(order);
    await this.events.publish('OrderCreated', order); // efeitos colaterais
    return order;
  }
}
```

A camada de aplicação coordena, mas **não decide regras**. "Pedido com mais de R$ 100 ganha desconto" é do domínio.

#### 3) Domain

Regras de negócio puras. Idealmente sem dependências externas (sem banco, sem HTTP, sem framework).

```ts
// src/domain/order.ts
export class Order {
  private constructor(
    readonly id: OrderId,
    readonly items: ReadonlyArray<OrderItem>,
    readonly status: OrderStatus,
  ) {}

  static create(input: CreateOrderInput): Order {
    if (input.items.length === 0) throw new EmptyOrderError();
    return new Order(OrderId.next(), input.items, 'placed');
  }

  totalWithDiscount(): Money {
    const subtotal = this.items.reduce((acc, i) => acc.plus(i.price.times(i.quantity)), Money.zero());
    return subtotal.isAbove(100) ? subtotal.times(0.9) : subtotal;
  }
}
```

Domínio é **funções puras + dados imutáveis** sempre que possível. Ver [funções puras](../foundations/pure-functions.md).

#### 4) Infrastructure

Tudo que toca o mundo externo: bancos, APIs de terceiros, sistema de arquivos, filas.

```ts
// src/infrastructure/postgres-order-repository.ts
export class PostgresOrderRepository implements OrderRepository {
  constructor(private db: Pool) {}

  async save(order: Order): Promise<void> {
    await this.db.query('INSERT INTO orders (id, status, items) VALUES ($1, $2, $3)',
      [order.id.value, order.status, JSON.stringify(order.items)]);
  }
}
```

A interface `OrderRepository` vive na camada de domínio ou aplicação, a implementação concreta fica na infra. Isso é a essência da [DIP](../foundations/solid.md).

### Estrutura típica de pastas

```
src/
├─ presentation/
│  ├─ http/
│  ├─ grpc/
│  └─ cli/
├─ application/
│  └─ use-cases/
├─ domain/
│  ├─ entities/
│  ├─ value-objects/
│  └─ services/
└─ infrastructure/
   ├─ persistence/
   ├─ external/
   └─ messaging/
```

Em projetos maiores, considere **organização por feature** dentro de cada camada, ver [Modular Monorepo](./modular-monorepo.md).

### Regra de dependência: aponta para baixo

```
Presentation  →  Application  →  Domain
                  ↓
              Infrastructure  →  Domain (apenas para implementar interfaces)
```

Domain **nunca** importa de Application, Presentation ou Infrastructure. Application importa de Domain. Presentation importa de Application e (idealmente) só conhece Domain via DTOs. Infrastructure implementa interfaces declaradas em Domain ou Application.

### Strict vs. Relaxed

Há duas formas de aplicar a regra:

- **Strict layering**: uma camada só pode chamar a **imediatamente abaixo**. Presentation → Application → Domain. Sem atalhos.
- **Relaxed layering**: uma camada pode chamar **qualquer camada abaixo**. Presentation pode chamar Domain diretamente quando faz sentido.

Para a maioria dos sistemas, **relaxed** é mais prático. Strict obriga criar "passa-fios" sem valor agregado.

## Quando *não* usar

- **Sistemas muito pequenos**: Layered cria overhead. Um script de 200 linhas não precisa de 4 camadas; uma estrutura plana basta.
- **Quando a regra "aponta para baixo" virou ficção.** Se na prática Domain importa do banco "só dessa vez", você na verdade não tem Layered, tem código emaranhado pintado de camadas. Hexagonal/Clean forçam o isolamento via tipos.
- **Aplicações com lógica predominantemente CRUD.** Frequentemente uma estrutura mais simples (transaction script + repository) cabe melhor que 4 camadas formais.

## Conceitos relacionados

- [Hexagonal (Ports & Adapters)](./hexagonal-ports-adapters.md), versão mais rigorosa do isolamento do domínio.
- [Clean Architecture](./clean-architecture.md), extensão com regras mais elaboradas de dependência.
- [DDD](./domain-driven-design.md): Layered é frequentemente usado como base estrutural para DDD tático.
- [SOLID (DIP](../foundations/solid.md)) princípio que sustenta a "inversão" das interfaces.

## Referências

- **Livro.** Martin Fowler, *Patterns of Enterprise Application Architecture* (Addison-Wesley, 2002). Capítulo 1, *Layering*.
- **Livro.** Eric Evans, *Domain-Driven Design* (Addison-Wesley, 2003). Capítulo 4, *Isolating the Domain*.
- **Livro.** Mark Richards & Neal Ford, *Fundamentals of Software Architecture* (O'Reilly, 2020). Capítulo 10, *Layered Architecture Style*.
- **Artigo.** Edsger Dijkstra, ["The Structure of the 'THE'-Multiprogramming System"](https://www.cs.utexas.edu/~EWD/transcriptions/EWD01xx/EWD196.html) (Communications of the ACM, 1968). Origem do conceito de camadas.
- **Site.** [microservices.io: Pattern: Layered Architecture](https://microservices.io/patterns/index.html).
