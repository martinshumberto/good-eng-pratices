# Padrões Comportamentais

> **TL;DR.** Padrões que descrevem **interação e responsabilidade** entre objetos. Os 11 do GoF: Strategy, Observer, Command, Iterator, State, Template Method, Chain of Responsibility, Visitor, Mediator, Memento, Interpreter. Strategy e Observer são os mais úteis no dia a dia moderno.

## O quê

**Padrões comportamentais** lidam com **algoritmos e atribuição de responsabilidades** entre objetos. Não são sobre estrutura, são sobre **comportamento dinâmico** e **comunicação**.

Os 11 clássicos do *Gang of Four*:

| Padrão | Intenção |
|---|---|
| **Strategy** | Trocar algoritmo em runtime |
| **Observer** | Notificar múltiplos objetos sobre mudanças |
| **Command** | Encapsular requisição como objeto |
| **Iterator** | Percorrer coleção sem expor estrutura |
| **State** | Comportamento muda com o estado interno |
| **Template Method** | Esqueleto de algoritmo com passos substituíveis |
| **Chain of Responsibility** | Passa requisição por cadeia até um manipular |
| **Visitor** | Operação aplicada a estrutura sem alterá-la |
| **Mediator** | Centralizar comunicação entre objetos |
| **Memento** | Capturar e restaurar estado |
| **Interpreter** | Avaliar linguagens/expressões |

## Por quê

Comportamentais surgem quando:

- O comportamento muda **dependendo de contexto** (Strategy, State).
- Múltiplos objetos precisam ser **notificados** (Observer).
- A operação precisa ser **enfileirada, undoable** ou **logada** (Command).
- Há uma **família de operações** sobre estrutura imutável (Visitor).
- Há **pipeline de processamento** com etapas independentes (Chain of Responsibility).

## Como aplicar

### Strategy

**Intenção:** definir família de algoritmos intercambiáveis em runtime.

```ts
interface DiscountStrategy {
  apply(total: number): number;
}

class NoDiscount implements DiscountStrategy {
  apply(total: number) { return total; }
}

class PercentageDiscount implements DiscountStrategy {
  constructor(private percent: number) {}
  apply(total: number) { return total * (1 - this.percent); }
}

class CouponDiscount implements DiscountStrategy {
  constructor(private code: string, private amount: number) {}
  apply(total: number) { return Math.max(0, total - this.amount); }
}

class Cart {
  constructor(private strategy: DiscountStrategy) {}
  total(subtotal: number) { return this.strategy.apply(subtotal); }
}

// Escolha em runtime
const cart = new Cart(user.hasPremium ? new PercentageDiscount(0.1) : new NoDiscount());
```

**Quando usar:**
- Múltiplas variações do mesmo algoritmo.
- Decisão em runtime.
- Quer evitar `if/switch` espalhado.

**Strategy é provavelmente o padrão mais útil no dia a dia.** Frequentemente nem precisa de classe, função basta:

```ts
type DiscountStrategy = (total: number) => number;

const noDiscount: DiscountStrategy = total => total;
const percent10:  DiscountStrategy = total => total * 0.9;
const coupon:     DiscountStrategy = total => Math.max(0, total - 20);
```

### Observer

**Intenção:** quando um objeto muda, todos os dependentes são notificados.

```ts
type Listener<T> = (data: T) => void;

class EventEmitter<T> {
  private listeners: Set<Listener<T>> = new Set();

  on(listener: Listener<T>): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);   // unsubscribe
  }

  emit(data: T) {
    this.listeners.forEach(l => l(data));
  }
}

// Uso
const orderPlaced = new EventEmitter<Order>();

orderPlaced.on(order => sendEmail(order));
orderPlaced.on(order => updateInventory(order));
orderPlaced.on(order => publishMetric(order));

orderPlaced.emit(myOrder);   // todos os listeners chamados
```

**Quando usar:**
- Múltiplos componentes reagem a um evento.
- Quer desacoplar fonte do consumidor.
- UI reativa (frameworks frontend são todos baseados nisso).

**Em TS moderno:** `EventEmitter` (Node), `EventTarget` (browser), RxJS `Observable`, [eventemitter3](https://github.com/primus/eventemitter3) cobrem o padrão.

Para reatividade pesada: **signals** ([Solid](https://docs.solidjs.com/concepts/signals), [Angular Signals](https://angular.dev/guide/signals), [Preact Signals](https://preactjs.com/guide/v10/signals/)) refinam o padrão.

### Command

**Intenção:** encapsular uma operação como objeto, permitindo enfileirar, logar ou desfazer.

```ts
interface Command {
  execute(): void;
  undo(): void;
}

class AddTextCommand implements Command {
  constructor(private editor: Editor, private text: string) {}
  execute() { this.editor.insert(this.text); }
  undo()    { this.editor.removeLast(this.text.length); }
}

class Editor {
  private history: Command[] = [];

  do(cmd: Command) {
    cmd.execute();
    this.history.push(cmd);
  }

  undo() {
    const cmd = this.history.pop();
    if (cmd) cmd.undo();
  }

  insert(text: string) { /* ... */ }
  removeLast(n: number) { /* ... */ }
}
```

**Quando usar:**
- Undo/redo.
- Logging/auditoria de operações.
- Fila de comandos (jobs assíncronos).
- Transações compostas.

Eventos vs Comandos: **comandos** dizem "faça X" para destinatário específico. **Eventos** dizem "X aconteceu" para quem quiser ouvir.

### Iterator

**Intenção:** acessar elementos de coleção sem expor representação interna.

```ts
// Em TS moderno, o protocolo de iterador já é nativo
class Range implements Iterable<number> {
  constructor(public start: number, public end: number) {}

  *[Symbol.iterator]() {
    for (let i = this.start; i < this.end; i++) yield i;
  }
}

for (const n of new Range(1, 5)) console.log(n);   // 1, 2, 3, 4
```

**Quando usar:**
- Coleção customizada.
- Iteração lazy (gera valores sob demanda).
- Múltiplas formas de percorrer (DFS, BFS).

**Status moderno:** o padrão **é a linguagem**. JS/TS, Python, Go, Rust, todas têm protocolos nativos de iterador.

### State

**Intenção:** comportamento muda dependendo do **estado interno**, simulando uma máquina de estados.

```ts
interface OrderState {
  pay(order: Order): void;
  cancel(order: Order): void;
  ship(order: Order): void;
}

class PlacedState implements OrderState {
  pay(order: Order)    { order.setState(new PaidState()); }
  cancel(order: Order) { order.setState(new CanceledState()); }
  ship(order: Order)   { throw new Error('Cannot ship unpaid order'); }
}

class PaidState implements OrderState {
  pay(order: Order)    { throw new Error('Already paid'); }
  cancel(order: Order) { order.setState(new CanceledState()); /* refund */ }
  ship(order: Order)   { order.setState(new ShippedState()); }
}

class Order {
  private state: OrderState = new PlacedState();
  setState(s: OrderState) { this.state = s; }
  pay()    { this.state.pay(this); }
  cancel() { this.state.cancel(this); }
  ship()   { this.state.ship(this); }
}
```

**Quando usar:**
- Comportamento muda com o estado.
- Transições restritas (não pode ir de A para C diretamente).
- `if (state === 'X') ... else if (state === 'Y') ...` espalhado.

**Alternativas modernas:** [XState](https://stately.ai/docs) (machine de estado para JS), discriminated unions com TypeScript (ver [MISU](../foundations/make-illegal-states-unrepresentable.md)).

### Template Method

**Intenção:** define esqueleto de algoritmo, deixando passos para subclasses preencherem.

```ts
abstract class DataProcessor {
  // Template method, define a ordem
  process(): void {
    const data = this.read();
    const transformed = this.transform(data);
    this.write(transformed);
  }

  abstract read(): RawData;
  abstract transform(data: RawData): ProcessedData;
  abstract write(data: ProcessedData): void;
}

class CSVProcessor extends DataProcessor {
  read()      { /* ... */ }
  transform() { /* ... */ }
  write()     { /* ... */ }
}
```

**Quando usar:**
- Algoritmo com **estrutura fixa** mas passos variáveis.
- Eliminar duplicação entre variantes que diferem em passos pontuais.

**Em TS moderno:** frequentemente substituído por **composição** (passa funções como parâmetros), evita herança.

### Chain of Responsibility

**Intenção:** passa requisição por cadeia de handlers até um deles tratá-la.

```ts
interface Handler {
  setNext(handler: Handler): Handler;
  handle(request: Request): Response | null;
}

abstract class BaseHandler implements Handler {
  private next: Handler | null = null;

  setNext(handler: Handler): Handler {
    this.next = handler;
    return handler;
  }

  handle(request: Request): Response | null {
    return this.next ? this.next.handle(request) : null;
  }
}

class AuthHandler extends BaseHandler {
  handle(request: Request): Response | null {
    if (!request.token) return { status: 401 };
    return super.handle(request);
  }
}

class RateLimitHandler extends BaseHandler {
  handle(request: Request): Response | null {
    if (this.isLimited(request)) return { status: 429 };
    return super.handle(request);
  }
  private isLimited(req: Request): boolean { /* ... */ return false; }
}

const chain = new AuthHandler();
chain.setNext(new RateLimitHandler())
     .setNext(/* ... próximo handler */);
```

**Quando usar:**
- Pipeline com etapas que podem **interromper**.
- Middleware (Express, Koa, gRPC interceptors são exatamente isso).
- Validações em sequência.

### Visitor

**Intenção:** define operações sobre estrutura sem modificar suas classes.

```ts
interface ShapeVisitor<T> {
  visitCircle(c: Circle): T;
  visitSquare(s: Square): T;
}

interface Shape {
  accept<T>(visitor: ShapeVisitor<T>): T;
}

class Circle implements Shape {
  constructor(public radius: number) {}
  accept<T>(v: ShapeVisitor<T>): T { return v.visitCircle(this); }
}

class Square implements Shape {
  constructor(public side: number) {}
  accept<T>(v: ShapeVisitor<T>): T { return v.visitSquare(this); }
}

class AreaVisitor implements ShapeVisitor<number> {
  visitCircle(c: Circle) { return Math.PI * c.radius ** 2; }
  visitSquare(s: Square) { return s.side ** 2; }
}

class JsonVisitor implements ShapeVisitor<string> {
  visitCircle(c: Circle) { return JSON.stringify({ type: 'circle', radius: c.radius }); }
  visitSquare(s: Square) { return JSON.stringify({ type: 'square', side: s.side }); }
}

const shape: Shape = new Circle(5);
shape.accept(new AreaVisitor());   // 78.5
shape.accept(new JsonVisitor());   // '{"type":"circle",...}'
```

**Quando usar:**
- Estrutura estável; muitas operações novas.
- Operações que cruzam toda a estrutura (compiladores, AST processors).

**Em TS moderno:** discriminated unions + `switch` cobrem melhor a maior parte dos casos:

```ts
type Shape = { type: 'circle'; radius: number } | { type: 'square'; side: number };

function area(s: Shape): number {
  switch (s.type) {
    case 'circle': return Math.PI * s.radius ** 2;
    case 'square': return s.side ** 2;
  }
}
```

### Mediator

**Intenção:** centralizar comunicação entre objetos para reduzir acoplamento.

```ts
class ChatMediator {
  private users: User[] = [];

  register(user: User) {
    this.users.push(user);
    user.mediator = this;
  }

  send(message: string, from: User) {
    this.users.forEach(u => {
      if (u !== from) u.receive(message, from);
    });
  }
}

class User {
  mediator?: ChatMediator;
  constructor(public name: string) {}

  send(message: string) {
    this.mediator?.send(message, this);
  }

  receive(message: string, from: User) {
    console.log(`${this.name} got "${message}" from ${from.name}`);
  }
}
```

**Quando usar:**
- N objetos comunicando entre si → acoplamento N×N. Mediator vira N×1.
- UI complexa com componentes que dependem uns dos outros.

### Memento

**Intenção:** captura estado para restaurar depois (snapshot).

```ts
class EditorMemento {
  constructor(readonly content: string) {}
}

class Editor {
  private content = '';

  save(): EditorMemento {
    return new EditorMemento(this.content);
  }

  restore(memento: EditorMemento) {
    this.content = memento.content;
  }

  type(text: string) { this.content += text; }
}
```

**Quando usar:**
- Undo/redo (combinado com Command).
- Checkpointing.
- Save state.

### Interpreter

**Intenção:** definir representação para gramática de uma linguagem e interpretar instâncias dela.

```ts
interface Expression {
  evaluate(context: Record<string, number>): number;
}

class NumberExpr implements Expression {
  constructor(private value: number) {}
  evaluate() { return this.value; }
}

class VarExpr implements Expression {
  constructor(private name: string) {}
  evaluate(ctx: Record<string, number>) { return ctx[this.name] ?? 0; }
}

class AddExpr implements Expression {
  constructor(private left: Expression, private right: Expression) {}
  evaluate(ctx: Record<string, number>) {
    return this.left.evaluate(ctx) + this.right.evaluate(ctx);
  }
}

// Avalia "x + 5" com x=10
const expr = new AddExpr(new VarExpr('x'), new NumberExpr(5));
expr.evaluate({ x: 10 });   // 15
```

**Quando usar:**
- DSL pequena (filtros, expressões matemáticas).
- Linguagem de regras.

**Raramente prática.** Para qualquer linguagem séria, use parser generator ([nearley](https://nearley.js.org), [pegjs](https://pegjs.org)) ou linguagem embarcada (Lua: JS via QuickJS).

### Comparação rápida

| Quero... | Use |
|---|---|
| Trocar algoritmo em runtime | **Strategy** |
| Múltiplos componentes reagem a evento | **Observer** |
| Operação como objeto (undo, queue, log) | **Command** |
| Percorrer coleção sem expor estrutura | **Iterator** |
| Comportamento muda com estado | **State** |
| Algoritmo fixo, passos variáveis | **Template Method** |
| Pipeline de handlers com interrupção | **Chain of Responsibility** |
| Operações sobre estrutura estável | **Visitor** |
| Centralizar comunicação N×N | **Mediator** |
| Snapshot de estado | **Memento** |
| Avaliar pequena DSL | **Interpreter** |

## Em TypeScript moderno: alternativas

Vários padrões são **substituídos por features nativas**:

- **Strategy** → função first-class.
- **Iterator** → `Symbol.iterator`, generators.
- **Observer** → `EventTarget`, signals, RxJS.
- **State** → discriminated unions ou XState.
- **Visitor** → switch sobre discriminated union.
- **Command** → tupla `[action, payload]` ou Redux actions.

Padrões viram **vocabulário** mais que estrutura prescritiva.

## Quando *não* usar

- **Para projeto pequeno.** Strategy entre 2 funções triviais é overhead.
- **Para "parecer profissional".** Aplicar Visitor a domínio com 2 tipos não justifica.
- **Quando linguagem oferece.** Não reimplemente Iterator em JS.

## Conceitos relacionados

- [Padrões criacionais](./creational.md)
- [Padrões estruturais](./structural.md)
- [Enterprise patterns](./enterprise-patterns.md)
- [SOLID (OCP](../foundations/solid.md)) Strategy é OCP aplicado.
- [Event-Driven Architecture](../architecture/event-driven.md): Observer em escala.
- [MISU](../foundations/make-illegal-states-unrepresentable.md), alternativa a State em TS.

## Referências

- **Livro.** Gamma et al., *Design Patterns* (Addison-Wesley, 1994). Texto fundador.
- **Site.** [Refactoring Guru: Behavioral Patterns](https://refactoring.guru/design-patterns/behavioral-patterns). Material visual.
- **Livro.** Eric Freeman, Elisabeth Robson, *Head First Design Patterns*, 2ª ed. (O'Reilly, 2020).
- **Site.** [SourceMaking: Behavioral Patterns](https://sourcemaking.com/design_patterns/behavioral_patterns).
- **Documentação.** [XState](https://stately.ai/docs). Statecharts em JS, supera State pattern clássico.
- **Documentação.** [RxJS](https://rxjs.dev): Observer levado a sério.
- **Documentação.** [TC39 Iterator Helpers Proposal](https://github.com/tc39/proposal-iterator-helpers). Iterators nativos do JS.
