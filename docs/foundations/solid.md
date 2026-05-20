# SOLID

> **TL;DR.** Cinco princípios para escrever código orientado a objetos que tolera mudança: uma responsabilidade por classe, aberto à extensão, substituível por subtipos, interfaces enxutas e dependências apontando para abstrações.

## O quê

SOLID é o acrônimo que reúne cinco princípios de design popularizados por Robert C. Martin nos anos 2000:

- **S** - Single Responsibility Principle (SRP)
- **O** - Open/Closed Principle (OCP)
- **L** - Liskov Substitution Principle (LSP)
- **I** - Interface Segregation Principle (ISP)
- **D** - Dependency Inversion Principle (DIP)

Os princípios surgiram de trabalhos de Bertrand Meyer (OCP), Barbara Liskov (LSP) e do próprio Robert Martin, e foram consolidados em *Agile Software Development: Principles, Patterns, and Practices* (2002) e mais tarde em *Clean Architecture* (2017).

## Por quê

Código que ignora SOLID tende a apresentar três sintomas, descritos por Robert Martin em *Clean Architecture* (cap. 7):

- **Rigidez**: mudanças simples cascateiam para muitos arquivos.
- **Fragilidade**: mudar uma área quebra outra aparentemente não-relacionada.
- **Imobilidade**: não dá para reaproveitar uma parte sem trazer o resto junto.

SOLID não é mágica nem dogma, é um conjunto de heurísticas que combatem esses sintomas.

## Como aplicar

### S: Single Responsibility Principle

> "Uma classe deve ter um, e apenas um, motivo para mudar."

A leitura ingênua ("uma classe faz uma coisa") é fraca. A leitura útil de Robert Martin é: cada módulo deve responder a **um único ator** (um stakeholder, uma área do negócio). Quando o módulo serve a múltiplos atores, mudanças solicitadas por um quebram o outro.

```ts
// ❌ Atende três atores diferentes: RH, contabilidade e DBA
class Employee {
  calculatePay(): Money { /* regra do RH */ }
  reportHours(): Report { /* regra da contabilidade */ }
  save(): void       { /* SQL, preocupação do DBA */ }
}

// ✅ Cada componente tem um ator próprio
class PayCalculator      { calculatePay(emp: Employee): Money {} }
class HourReporter       { report(emp: Employee): Report      {} }
class EmployeeRepository { save(emp: Employee): void          {} }
```

### O: Open/Closed Principle

> "Entidades de software devem ser abertas para extensão, fechadas para modificação."
> (Bertrand Meyer, *Object-Oriented Software Construction* (1988))

Adicionar comportamento novo não deve exigir alterar código que já funciona. A ferramenta usual é polimorfismo: o "novo" entra como uma nova implementação de uma abstração existente.

```ts
// ❌ Adicionar PIX exige mexer no switch
function processPayment(method: 'card' | 'boleto', amount: number) {
  switch (method) {
    case 'card':   return chargeCard(amount);
    case 'boleto': return generateBoleto(amount);
  }
}

// ✅ Adicionar PIX = criar uma nova classe que implementa PaymentMethod
interface PaymentMethod { charge(amount: number): Receipt; }

class CardPayment   implements PaymentMethod { charge(a: number) { /* … */ } }
class BoletoPayment implements PaymentMethod { charge(a: number) { /* … */ } }

function processPayment(method: PaymentMethod, amount: number) {
  return method.charge(amount);
}
```

### L: Liskov Substitution Principle

> "Subtipos devem ser substituíveis por seus tipos-base sem alterar a corretude do programa."
> (Barbara Liskov, 1987)

Se `Bird` tem um método `fly()`, criar `Penguin extends Bird` viola LSP, o subtipo enfraquece um contrato do supertipo. Hierarquias que parecem fazer sentido linguisticamente ("pinguim é uma ave") podem ser ruins para modelagem.

```ts
// ❌ LSP violado: Square promete ser Rectangle, mas quebra o contrato
class Rectangle { setWidth(w: number) {} setHeight(h: number) {} }
class Square extends Rectangle {
  setWidth(w: number)  { /* também muda height */ }
  setHeight(h: number) { /* também muda width  */ }
}
// Código que assume "alterar width não muda height" quebra com Square.
```

A correção: modele `Shape` como abstração comum em vez de forçar Square a herdar de Rectangle.

### I: Interface Segregation Principle

> "Clientes não devem ser forçados a depender de interfaces que não usam."

Interfaces "gordas" obrigam implementações a fornecer (ou stubar) métodos irrelevantes. Quebre interfaces grandes em várias menores, agrupadas por papel.

```ts
// ❌ Worker força quem só lê arquivos a implementar escrita também
interface FileWorker {
  read(path: string): Buffer;
  write(path: string, data: Buffer): void;
  delete(path: string): void;
}

// ✅ Quem lê depende só de Reader; quem escreve depende só de Writer
interface FileReader { read(path: string): Buffer; }
interface FileWriter { write(path: string, data: Buffer): void; }
interface FileEraser { delete(path: string): void; }
```

### D: Dependency Inversion Principle

> "Módulos de alto nível não devem depender de módulos de baixo nível. Ambos devem depender de abstrações."

Inverter dependências significa que a **regra de negócio define a interface** que o detalhe (banco, API externa, framework) deve atender, e não o contrário.

```ts
// ❌ Use case depende do Postgres concretamente
import { PostgresUserRepo } from './infra/postgres-user-repo';

class CreateUser {
  constructor(private repo = new PostgresUserRepo()) {}
  exec(data: UserData) { return this.repo.save(data); }
}

// ✅ Use case define a interface que precisa; infra implementa
interface UserRepository { save(data: UserData): Promise<User>; }

class CreateUser {
  constructor(private repo: UserRepository) {}
  exec(data: UserData) { return this.repo.save(data); }
}
// PostgresUserRepo, MongoUserRepo, InMemoryUserRepo implementam UserRepository.
```

Esse é o motor que viabiliza [Arquitetura Hexagonal](../architecture/hexagonal-ports-adapters.md) e [Clean Architecture](../architecture/clean-architecture.md).

## Quando *não* usar

- **SRP levado ao extremo:** classes "anêmicas" com um único método cada multiplicam arquivos sem ganho de clareza. SRP é sobre atores, não sobre linhas.
- **OCP especulativo:** criar abstração para um caso que pode nunca se repetir é YAGNI. Abstraia quando houver pelo menos duas implementações concretas.
- **DIP em toda dependência:** inverter dependência de bibliotecas estáveis (`Math.random`, `JSON.parse`) só polui o código. Inverta nas dependências que mudam ou que você quer trocar em testes.

## Conceitos relacionados

- [DRY: KISS, YAGNI](./dry-kiss-yagni.md)
- [Coesão e acoplamento](./cohesion-coupling.md)
- [Arquitetura Hexagonal](../architecture/hexagonal-ports-adapters.md)
- [Clean Architecture](../architecture/clean-architecture.md)

## Referências

- **Livro.** Robert C. Martin, *Clean Architecture* (Prentice Hall, 2017), capítulos 7–11.
- **Livro.** Robert C. Martin, *Agile Software Development: Principles, Patterns, and Practices* (Prentice Hall, 2002).
- **Livro.** Bertrand Meyer, *Object-Oriented Software Construction*, 2ª ed. (Prentice Hall, 1997). Origem do OCP.
- **Paper.** Barbara Liskov & Jeannette Wing, "A Behavioral Notion of Subtyping", *ACM TOPLAS*, 1994. Fundamento formal do LSP.
- **Artigo.** Robert C. Martin, ["The Single Responsibility Principle"](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html).
- **Site.** [Refactoring Guru: SOLID Principles](https://refactoring.guru/design-patterns) (apresentação visual).
