# Domain-Driven Design (DDD)

> **TL;DR.** DDD é uma abordagem para modelar software complexo aproximando código e domínio: linguagem única (*ubiquitous language*), fronteiras explícitas (*bounded contexts*), modelos ricos (entities, value objects, aggregates).

## O quê

**Domain-Driven Design** foi introduzido por **Eric Evans** no livro homônimo de 2003. É uma resposta a um padrão comum de fracasso: software complexo construído com modelos anêmicos, terminologia inconsistente e fronteiras mal definidas, código que cresce mas não escala em compreensão.

DDD propõe duas frentes:

- **Strategic DDD**: modelagem do domínio em alto nível: identificar subdomínios, definir *bounded contexts*, mapear relações entre eles.
- **Tactical DDD**: padrões de modelagem dentro de um *bounded context*: entities, value objects, aggregates, repositories, domain services, domain events.

> "DDD is a way of thinking and a set of priorities, aimed at accelerating software projects that have to deal with complicated domains."
> (Eric Evans)

## Por quê

Sistemas complexos sofrem três problemas que DDD endereça:

1. **Confusão terminológica.** "Cliente" no produto é a mesma coisa que "Cliente" no jurídico? E no marketing? Quando ninguém alinhou, o código mistura tudo.
2. **Modelos sem profundidade.** Classes `User` com 50 campos opcionais e sem comportamento; toda regra mora em "Services". O domínio fica espalhado.
3. **Fronteiras invisíveis.** Equipes pisam no mesmo modelo, mudanças em uma área quebram outra "que parecia não-relacionada".

DDD não é mágica. É um conjunto de **práticas de modelagem** que, aplicadas com disciplina, ajudam código e domínio a evoluírem juntos.

DDD funciona melhor quando:

- O domínio é **genuinamente complexo** (regras de negócio são o coração do produto).
- Há **acesso a especialistas de domínio** dispostos a conversar.
- O time tem **maturidade** para investir em modelagem antes de codar.

DDD é **excesso** para CRUDs simples, ferramentas internas, dashboards.

## Como aplicar

### Strategic DDD

#### Ubiquitous language

Uma única linguagem usada **igualmente** por especialistas de domínio, designers e desenvolvedores, refletida nas conversas, na documentação e no código.

```ts
// ❌ Linguagem técnica desalinhada do domínio
class CustomerRecord {
  validateOrderFlag: boolean;
  doProcess() { /* ... */ }
}

// ✅ Linguagem do domínio
class Customer {
  canPlaceOrder(): boolean { /* ... */ }
  placeOrder(items: OrderItem[]): Order { /* ... */ }
}
```

Se um especialista de domínio leria o código sem precisar de tradução, você está no caminho certo.

#### Bounded Context

Uma fronteira explícita dentro da qual um modelo (e sua linguagem) tem significado bem definido.

> "Bounded Context: A description of a boundary (typically a subsystem, or the work of a particular team) within which a particular model is defined and applicable."
> (Eric Evans)

Exemplo: em um marketplace, `Product` pode significar coisas diferentes:

- **Catalog Context**: `Product` tem nome, descrição, fotos, categorias.
- **Inventory Context**: `Product` tem SKU, quantidade em estoque, localização.
- **Pricing Context**: `Product` tem preço base, regras de desconto, histórico.

Forçar um único modelo "Product" para cobrir tudo gera uma classe gorda e infeliz. DDD recomenda **três modelos**, um por contexto, conectados por integrações explícitas (eventos, APIs).

#### Context Map

Diagrama que mostra como os bounded contexts se relacionam. Padrões comuns:

- **Customer/Supplier**: um contexto consome o outro, com expectativas formalizadas.
- **Conformist**: um contexto adota o modelo do upstream sem alteração.
- **Anticorruption Layer (ACL)**: camada que traduz o modelo externo para o interno, protegendo o domínio.
- **Shared Kernel**: partes do modelo compartilhadas explicitamente entre contextos.
- **Open Host Service**: contexto expõe uma API estável e bem documentada.

### Tactical DDD

Padrões para modelar **dentro** de um bounded context.

#### Entity

Objeto com **identidade** que persiste ao longo do tempo. Dois `Customer` com mesmos dados mas IDs diferentes são entidades diferentes.

```ts
class Customer {
  constructor(
    readonly id: CustomerId,       // identidade
    private email: Email,
    private name:  string,
  ) {}

  changeEmail(newEmail: Email): void {
    this.email = newEmail;
  }

  equals(other: Customer): boolean {
    return this.id.equals(other.id);   // igualdade por identidade
  }
}
```

#### Value Object

Objeto definido pelos **seus valores**, sem identidade. Dois `Money(100, 'BRL')` são intercambiáveis. Tipicamente **imutáveis**.

```ts
class Money {
  private constructor(
    readonly amount: number,
    readonly currency: 'BRL' | 'USD',
  ) {}

  static of(amount: number, currency: 'BRL' | 'USD'): Money {
    if (amount < 0) throw new InvalidMoneyError();
    return new Money(amount, currency);
  }

  plus(other: Money): Money {
    if (other.currency !== this.currency) throw new CurrencyMismatchError();
    return Money.of(this.amount + other.amount, this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }
}
```

Value Objects são o "tijolo" de DDD. Use generosamente, `Email`, `Phone`, `Address`, `Coordinates`, `DateRange`, `Money`. Evita [Primitive Obsession](../foundations/code-smells.md).

#### Aggregate

Cluster de entidades + value objects tratado como uma **unidade de consistência**. Tem uma **entidade raiz** (Aggregate Root), o único ponto de acesso de fora.

```ts
class Order {  // ← Aggregate Root
  private items: OrderItem[] = [];

  constructor(
    readonly id: OrderId,
    readonly customerId: CustomerId,
  ) {}

  addItem(productId: ProductId, quantity: number, price: Money): void {
    if (this.items.length >= 50) throw new TooManyItemsError();
    this.items.push(new OrderItem(productId, quantity, price));
  }

  total(): Money {
    return this.items.reduce((acc, i) => acc.plus(i.subtotal()), Money.of(0, 'BRL'));
  }
}

// OrderItem é interno ao aggregate Order, não acessado de fora
class OrderItem {
  constructor(
    readonly productId: ProductId,
    readonly quantity:  number,
    readonly unitPrice: Money,
  ) {}
  subtotal(): Money { return this.unitPrice.times(this.quantity); }
}
```

Regras:

- **Acesso externo só pelo Root.** Ninguém de fora manipula `OrderItem` direto.
- **Invariantes preservadas em uma transação.** O aggregate completo está sempre consistente.
- **Aggregates pequenos.** "Quando em dúvida, mantenha pequeno" (Vernon).
- **Referências entre aggregates por ID, não por objeto.** `Order` guarda `customerId: CustomerId`, não `customer: Customer`.

#### Repository

Abstração para persistir/recuperar aggregates como se fossem coleções em memória.

```ts
interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
}
```

A interface vive no domínio; implementações concretas (Postgres, Mongo, in-memory) vivem fora. Ver [Hexagonal](./hexagonal-ports-adapters.md).

#### Domain Service

Quando uma operação envolve múltiplos aggregates ou não pertence naturalmente a um deles, modele como **domain service**: função/classe sem estado, vivendo no domínio.

```ts
class FundsTransferService {
  transfer(from: Account, to: Account, amount: Money): void {
    from.withdraw(amount);
    to.deposit(amount);
    // operação não cabe em from nem em to isoladamente
  }
}
```

#### Domain Event

Algo importante que aconteceu no domínio. Permite desacoplar reações ao evento da operação que o causou.

```ts
class OrderPlaced {
  constructor(
    readonly orderId: OrderId,
    readonly customerId: CustomerId,
    readonly total: Money,
    readonly occurredAt: Date = new Date(),
  ) {}
}

class Order {
  place(): OrderPlaced {
    this.status = 'placed';
    return new OrderPlaced(this.id, this.customerId, this.total());
  }
}
```

Ver [Event-Driven Architecture](./event-driven.md).

#### Factory

Construir aggregates complexos pode envolver invariantes que nem o construtor consegue garantir. Encapsule em uma factory:

```ts
class OrderFactory {
  static create(customer: Customer, items: { productId: ProductId; qty: number; price: Money }[]): Order {
    if (items.length === 0) throw new EmptyOrderError();
    if (!customer.canPlaceOrder()) throw new CustomerCannotOrderError();

    const order = new Order(OrderId.next(), customer.id);
    items.forEach(i => order.addItem(i.productId, i.qty, i.price));
    return order;
  }
}
```

### Quando ir além: *Strategic*

Para sistemas grandes, **strategic DDD** é frequentemente mais valioso que *tactical*. Definir bem os bounded contexts:

- Reduz acoplamento entre equipes.
- Permite cada contexto evoluir no seu ritmo.
- Encaixa naturalmente em [microsserviços](./microservices.md) (cada bounded context candidato a um serviço).

## Quando *não* usar

- **CRUDs simples.** Aggregates e value objects são overhead se a regra de negócio é "salvar/recuperar registro".
- **Domínios pequenos.** Se o modelo cabe em uma página, DDD adiciona estrutura sem ganho proporcional.
- **Sem acesso a especialistas.** *Ubiquitous language* exige interlocutores. Sem eles, vira modelagem artificial.
- **Equipe sem disciplina para sustentar.** DDD parcial é pior que DDD ausente, gera falsa expectativa de aderência.

## Conceitos relacionados

- [Hexagonal](./hexagonal-ports-adapters.md) e [Clean Architecture](./clean-architecture.md), arquiteturas favoritas para sustentar DDD tático.
- [Microsserviços](./microservices.md), bounded contexts geralmente viram microsserviços.
- [MISU](../foundations/make-illegal-states-unrepresentable.md), value objects são a forma DDD-ística de aplicar MISU.

## Referências

- **Livro.** Eric Evans, *Domain-Driven Design: Tackling Complexity in the Heart of Software* (Addison-Wesley, 2003). Texto fundador. Denso.
- **Livro.** Vaughn Vernon, *Implementing Domain-Driven Design* (Addison-Wesley, 2013). Aplicação prática com código. Frequentemente recomendado **junto** com Evans.
- **Livro.** Vaughn Vernon, *Domain-Driven Design Distilled* (Addison-Wesley, 2016). Versão condensada (~200 páginas).
- **Livro.** Vlad Khononov, *Learning Domain-Driven Design* (O'Reilly, 2021). Moderna, didática.
- **Documento.** Eric Evans, [*Domain-Driven Design Reference*](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf) (PDF gratuito). Sumário de definições.
- **Artigo.** Martin Fowler, ["BoundedContext"](https://martinfowler.com/bliki/BoundedContext.html) e ["UbiquitousLanguage"](https://martinfowler.com/bliki/UbiquitousLanguage.html).
- **Site.** [domainlanguage.com](https://www.domainlanguage.com), site oficial de Eric Evans.
