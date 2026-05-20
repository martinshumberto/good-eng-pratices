# Padrões Criacionais

> **TL;DR.** Padrões que **encapsulam a criação** de objetos. Os clássicos do GoF: Factory Method, Abstract Factory, Builder, Prototype, Singleton. Em linguagens modernas (TypeScript, Kotlin, Python), nem todos são necessários, funções de fábrica e literais cobrem boa parte dos casos.

## O quê

**Design Patterns** ganharam protagonismo com o livro do *Gang of Four (GoF)* (Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides) em *Design Patterns: Elements of Reusable Object-Oriented Software* (Addison-Wesley, 1994).

Os **padrões criacionais** abstraem **como objetos são instanciados**. Em vez de `new Foo(...)` espalhado, encapsulam a criação para:

- Desacoplar cliente da classe concreta.
- Permitir variação de objeto criado em runtime.
- Centralizar lógica complexa de instanciação.

Os 5 clássicos:

| Padrão | Intenção |
|---|---|
| **Factory Method** | Defina uma interface para criar, mas deixe subclasses decidirem qual classe instanciar |
| **Abstract Factory** | Crie famílias de objetos relacionados sem especificar suas classes concretas |
| **Builder** | Construa objetos complexos passo-a-passo |
| **Prototype** | Clone um objeto existente em vez de criar do zero |
| **Singleton** | Garanta uma única instância acessível globalmente |

## Por quê

Em código simples, `new` direto é suficiente. Padrões criacionais entram quando:

- **A classe concreta depende de contexto.** Em testes, quero `InMemoryRepo`; em prod, `PostgresRepo`.
- **A construção é complexa.** Objeto com muitos campos opcionais, validações cruzadas, dependências.
- **A criação muda ao longo do tempo.** Hoje crio `BasicProduct`; amanhã, `DiscountedProduct` baseado em regra.
- **Você quer controlar quantas instâncias existem.**

Em linguagens modernas, **funções de fábrica** e **objetos literais** frequentemente substituem padrões formais, o conceito vale, a sintaxe é mais leve.

## Como aplicar

### Factory Method

**Intenção:** delegar a criação para um método (geralmente abstrato), permitindo que subclasses escolham a classe concreta.

```ts
abstract class Logger {
  abstract createTransport(): Transport;   // factory method

  log(message: string) {
    const transport = this.createTransport();
    transport.send(message);
  }
}

class FileLogger extends Logger {
  createTransport(): Transport {
    return new FileTransport('/var/log/app.log');
  }
}

class HttpLogger extends Logger {
  createTransport(): Transport {
    return new HttpTransport('https://logs.example.com');
  }
}
```

**Quando usar:**
- O cliente trabalha com um tipo base, mas a subclasse decide o concreto.
- Hierarquia de classes onde algumas decisões "vazam" para subtipos.

**Em TS moderno:** frequentemente substituído por **funções**:

```ts
function makeLogger(target: 'file' | 'http'): Logger {
  return new Logger(target === 'file' ? new FileTransport(...) : new HttpTransport(...));
}
```

### Abstract Factory

**Intenção:** criar **famílias** de objetos relacionados sem amarrar ao tipo concreto.

```ts
interface UIFactory {
  createButton(): Button;
  createCheckbox(): Checkbox;
  createMenu(): Menu;
}

class MacUIFactory implements UIFactory {
  createButton()    { return new MacButton(); }
  createCheckbox()  { return new MacCheckbox(); }
  createMenu()      { return new MacMenu(); }
}

class WindowsUIFactory implements UIFactory {
  createButton()    { return new WindowsButton(); }
  createCheckbox()  { return new WindowsCheckbox(); }
  createMenu()      { return new WindowsMenu(); }
}

function buildApp(factory: UIFactory) {
  const btn = factory.createButton();
  const cb  = factory.createCheckbox();
  // todos consistentes, Mac ou Windows, nunca misturados
}
```

**Quando usar:**
- Família de produtos que devem ser usados juntos (botões e checkboxes do mesmo tema).
- Cliente deve ser independente de qual conjunto está usando.

**Cuidado:** vira pesado se a família crescer. Considere DI (injeção de dependências) ou Strategy.

### Builder

**Intenção:** construir objeto complexo **passo-a-passo**, com a possibilidade de variar a representação.

```ts
class HttpRequestBuilder {
  private method: string = 'GET';
  private url: string = '';
  private headers: Record<string, string> = {};
  private body: unknown = undefined;
  private timeout: number = 30_000;

  setMethod(m: string): this   { this.method = m; return this; }
  setUrl(u: string):    this   { this.url = u; return this; }
  addHeader(k: string, v: string): this { this.headers[k] = v; return this; }
  setBody(b: unknown):  this   { this.body = b; return this; }
  setTimeout(t: number): this  { this.timeout = t; return this; }

  build(): HttpRequest {
    if (!this.url) throw new Error('URL required');
    return new HttpRequest(this.method, this.url, this.headers, this.body, this.timeout);
  }
}

const req = new HttpRequestBuilder()
  .setMethod('POST')
  .setUrl('https://api.example.com/orders')
  .addHeader('Content-Type', 'application/json')
  .setBody({ items: [...] })
  .build();
```

**Quando usar:**
- Construtor com muitos parâmetros (4+).
- Combinações inválidas precisam ser prevenidas.
- Objeto imutável construído passo-a-passo.

**Em TS moderno:** muitos casos resolvem com **destructuring + defaults**:

```ts
function createHttpRequest(opts: {
  method?: string;
  url: string;
  headers?: Record<string, string>;
  body?: unknown;
  timeout?: number;
}): HttpRequest {
  return new HttpRequest({
    method: 'GET',
    headers: {},
    timeout: 30_000,
    ...opts,
  });
}
```

Builder fluente é mais expressivo quando há validações entre passos.

### Prototype

**Intenção:** criar novo objeto **clonando** um existente, em vez de instanciar do zero.

```ts
interface Prototype<T> {
  clone(): T;
}

class Document implements Prototype<Document> {
  constructor(
    public title: string,
    public sections: Section[],
    public styles: Style[],
  ) {}

  clone(): Document {
    return new Document(
      this.title,
      this.sections.map(s => s.clone()),
      this.styles.map(s => ({ ...s })),
    );
  }
}
```

**Quando usar:**
- Criação do zero é cara.
- Você quer cópias de um template configurado.
- Configurações pré-prontas servem de "blueprint".

**Em TS moderno:** `structuredClone()` (nativo) ou bibliotecas (Lodash `cloneDeep`) cobrem a maior parte dos casos. Prototype formal é raro.

### Singleton

**Intenção:** garantir que uma classe tenha **apenas uma instância** e fornecer um ponto de acesso global.

```ts
class Database {
  private static instance: Database;
  private connection: any;

  private constructor() {
    this.connection = createConnection();
  }

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }
}

const db = Database.getInstance();
```

**Quando usar:**
- Recurso compartilhado realmente único (logger global, pool de conexão).
- Componente caro de inicializar.

**Cuidados sérios:**

- **Estado global oculto.** Testes ficam frágeis (instância persiste entre testes).
- **Acoplamento forte.** Cliente conhece classe concreta.
- **Concorrência.** Inicialização precisa ser thread-safe (em linguagens com threads reais).

**Em TS moderno:** prefira **módulos**: toda exportação de módulo é singleton naturalmente:

```ts
// db.ts
let connection: Connection | null = null;

export function getDb(): Connection {
  if (!connection) connection = createConnection();
  return connection;
}
```

Ou ainda melhor: **injeção de dependência** no `composition root`: passa a instância única para quem precisa, sem estado global.

> "Singleton is usually considered an anti-pattern in modern OO code."
> (Comum em discussões modernas)

### Comparação rápida

| Quero... | Use |
|---|---|
| Esconder qual classe concreta criar | **Factory Method** ou função de fábrica |
| Criar família de objetos consistentes | **Abstract Factory** |
| Construir objeto complexo passo-a-passo | **Builder** |
| Clonar um template configurado | **Prototype** |
| Instância única compartilhada | **Singleton** (com cuidado), ou DI |

### Em TypeScript moderno: alternativas

Muitos padrões GoF nasceram em linguagens **sem suporte a funções de primeira classe** (Smalltalk, C++ early). Em TS:

| GoF Pattern | TS Alternativa |
|---|---|
| Factory Method | Função de fábrica |
| Abstract Factory | Objeto contendo funções |
| Builder | Destructuring + defaults |
| Prototype | `structuredClone()` |
| Singleton | Módulo + função exportada |

Padrões viram **vocabulário** mais que **estrutura prescritiva**. Saber o nome ainda ajuda comunicação ("isso é uma factory" comunica mais que "isso é uma função que cria").

## Quando *não* usar

- **Quando o problema não existe.** Construtor com 2 parâmetros não precisa de Builder.
- **Quando linguagem já oferece nativamente.** Singleton em Python? Use módulo, não classe com `__new__`.
- **Para "parecer profissional".** Padrões aplicados sem necessidade são complexidade, antipadrão clássico em código de júnior tentando "estruturar bem".

> "Patterns are not formulas to be applied. They are reminders that other people have solved similar problems before."

## Conceitos relacionados

- [Padrões estruturais](./structural.md)
- [Padrões comportamentais](./behavioral.md)
- [Enterprise patterns](./enterprise-patterns.md)
- [SOLID (DIP](../foundations/solid.md)) DI substitui muitos padrões criacionais.
- [Hexagonal](../architecture/hexagonal-ports-adapters.md), usa factories naturalmente.

## Referências

- **Livro.** Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides, *Design Patterns: Elements of Reusable Object-Oriented Software* (Addison-Wesley, 1994). O *Gang of Four*. Texto fundador.
- **Site.** [Refactoring Guru: Creational Patterns](https://refactoring.guru/design-patterns/creational-patterns). Excelente material visual com exemplos em várias linguagens.
- **Livro.** Eric Freeman, Elisabeth Robson, *Head First Design Patterns*, 2ª ed. (O'Reilly, 2020). Apresentação acessível dos padrões GoF.
- **Site.** [SourceMaking: Creational Patterns](https://sourcemaking.com/design_patterns/creational_patterns).
- **Livro.** Joshua Bloch, *Effective Java*, 3ª ed. (Addison-Wesley, 2017). Capítulos 2–3 trazem padrões criacionais com nuances modernas.
- **Artigo.** Martin Fowler, ["Singleton"](https://martinfowler.com/eaaCatalog/registry.html) e ["Registry"](https://martinfowler.com/eaaCatalog/registry.html). Alternativas modernas.
