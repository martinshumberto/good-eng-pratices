# Padrões Estruturais

> **TL;DR.** Padrões que descrevem **como compor classes/objetos** em estruturas maiores. Os clássicos do GoF: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy. Resolvem problemas de **composição** sem herança rígida.

## O quê

**Padrões estruturais** lidam com **composição**: como objetos se combinam para formar estruturas maiores enquanto mantêm flexibilidade.

Os 7 clássicos do *Gang of Four*:

| Padrão | Intenção |
|---|---|
| **Adapter** | Compatibilizar interfaces incompatíveis |
| **Bridge** | Separar abstração de implementação |
| **Composite** | Tratar objeto individual e composição uniformemente |
| **Decorator** | Adicionar responsabilidades dinamicamente |
| **Facade** | Fornecer interface simplificada para subsistema complexo |
| **Flyweight** | Compartilhar objetos para economizar memória |
| **Proxy** | Substituir objeto controlando acesso |

## Por quê

Estruturais resolvem problemas onde **composição via herança seria rígida ou impossível**:

- **Interfaces que não batem** entre código novo e legado.
- **Comportamento que combina dinamicamente** em runtime.
- **Estruturas hierárquicas** com nós que são também sub-árvores.
- **Wrappers** que adicionam capacidades sem mudar o original.

## Como aplicar

### Adapter

**Intenção:** adapta a interface de uma classe para outra que o cliente espera.

```ts
// Interface esperada pelo cliente
interface PaymentGateway {
  charge(amountInCents: number, currency: string): Promise<PaymentResult>;
}

// Classe de terceiro com interface diferente
class StripeSDK {
  async createCharge(opts: {
    amount: number;       // já em cents
    currency: string;
    source: string;
  }): Promise<StripeResponse> { /* ... */ }
}

// Adapter
class StripeAdapter implements PaymentGateway {
  constructor(private stripe: StripeSDK, private cardToken: string) {}

  async charge(amountInCents: number, currency: string): Promise<PaymentResult> {
    const res = await this.stripe.createCharge({
      amount: amountInCents,
      currency,
      source: this.cardToken,
    });
    return {
      ok: res.status === 'succeeded',
      transactionId: res.id,
    };
  }
}
```

**Quando usar:**
- Integrar biblioteca externa com sua interface.
- Migrar de implementação A para B sem mudar consumidores.
- Esconder API legada atrás de interface moderna.

**Comum em** Hexagonal Architecture, *driven adapters* são literalmente este padrão.

### Bridge

**Intenção:** separar abstração da implementação, permitindo que **as duas variem independentemente**.

```ts
// Implementação
interface Renderer {
  draw(shape: string, x: number, y: number): void;
}

class CanvasRenderer implements Renderer {
  draw(shape: string, x: number, y: number) { /* ... */ }
}

class SVGRenderer implements Renderer {
  draw(shape: string, x: number, y: number) { /* ... */ }
}

// Abstração, usa a implementação via bridge
abstract class Shape {
  constructor(protected renderer: Renderer) {}
  abstract draw(): void;
}

class Circle extends Shape {
  constructor(renderer: Renderer, private x: number, private y: number) {
    super(renderer);
  }
  draw() { this.renderer.draw('circle', this.x, this.y); }
}

class Square extends Shape {
  draw() { /* ... */ }
}

// Combina livremente
const a = new Circle(new CanvasRenderer(), 0, 0);
const b = new Square(new SVGRenderer(), ...);
```

Sem Bridge, você teria explosão combinatória: `CanvasCircle`, `CanvasSquare`, `SVGCircle`, `SVGSquare`...

**Quando usar:**
- Duas dimensões ortogonais variam (shape × renderer; engine × theme).
- Quer evitar hierarquia de herança que explode.

### Composite

**Intenção:** compor objetos em árvores; trate folhas e composições uniformemente.

```ts
interface FileSystemNode {
  size(): number;
  print(indent?: string): void;
}

class File implements FileSystemNode {
  constructor(private name: string, private bytes: number) {}
  size() { return this.bytes; }
  print(indent = '') {
    console.log(`${indent}📄 ${this.name} (${this.bytes}B)`);
  }
}

class Folder implements FileSystemNode {
  private children: FileSystemNode[] = [];
  constructor(private name: string) {}

  add(node: FileSystemNode) { this.children.push(node); }

  size() {
    return this.children.reduce((sum, c) => sum + c.size(), 0);
  }

  print(indent = '') {
    console.log(`${indent}📁 ${this.name}/`);
    this.children.forEach(c => c.print(indent + '  '));
  }
}

// Cliente trata folder e file da mesma forma
const root = new Folder('root');
root.add(new File('readme.md', 1024));
root.add(new Folder('src'));
root.print();
console.log(`Total: ${root.size()}B`);
```

**Quando usar:**
- Estruturas hierárquicas (DOM, AST, file system, organograma).
- Cliente não distingue folha vs ramo.

### Decorator

**Intenção:** adicionar responsabilidades a um objeto **dinamicamente**, sem alterar sua classe.

```ts
interface Notifier {
  send(message: string): void;
}

class EmailNotifier implements Notifier {
  send(msg: string) { /* ... */ }
}

// Decorator base
abstract class NotifierDecorator implements Notifier {
  constructor(protected wrapped: Notifier) {}
  send(msg: string) { this.wrapped.send(msg); }
}

class SMSDecorator extends NotifierDecorator {
  send(msg: string) {
    super.send(msg);
    this.sendSMS(msg);
  }
  private sendSMS(msg: string) { /* ... */ }
}

class SlackDecorator extends NotifierDecorator {
  send(msg: string) {
    super.send(msg);
    this.postToSlack(msg);
  }
  private postToSlack(msg: string) { /* ... */ }
}

// Combina dinamicamente
let notifier: Notifier = new EmailNotifier();
notifier = new SMSDecorator(notifier);
notifier = new SlackDecorator(notifier);
notifier.send('Hello');  // envia por email + SMS + Slack
```

**Quando usar:**
- Combinar comportamentos em runtime.
- Evitar herança múltipla / hierarquia explosiva.

**Em TS moderno:** `Higher-Order Functions` e `function composition` substituem em muitos casos:

```ts
const send: Notifier['send'] = compose(
  withEmail,
  withSMS,
  withSlack,
)(message => baseStorage.save(message));
```

Decorators (`@decorator`) do TS são diferentes, sintaxe para anotar classes/métodos, mais próximos de aspect-oriented programming.

### Facade

**Intenção:** fornecer **interface simples** para subsistema complexo.

```ts
// Subsistema complexo
class Encoder { encode(file: File): EncodedData { /* ... */ } }
class Bitrate { adjust(data: EncodedData, kbps: number): EncodedData { /* ... */ } }
class Watermark { apply(data: EncodedData, image: Image): EncodedData { /* ... */ } }
class Uploader { upload(data: EncodedData, dest: string): Promise<void> { /* ... */ } }

// Facade, esconde a complexidade
class VideoConverterFacade {
  async convert(file: File, dest: string): Promise<void> {
    let data = new Encoder().encode(file);
    data = new Bitrate().adjust(data, 1500);
    data = new Watermark().apply(data, defaultWatermark);
    await new Uploader().upload(data, dest);
  }
}

// Cliente, vida simples
new VideoConverterFacade().convert(file, 's3://...');
```

**Quando usar:**
- Subsistema com muitas peças que sempre são usadas juntas.
- Esconder complexidade de bibliotecas/SDKs.
- Camada anti-corrupção sobre código legado.

**Diferença para Adapter:** Adapter muda **forma**; Facade simplifica **uso** (frequentemente do mesmo subsistema).

### Flyweight

**Intenção:** compartilhar objetos pequenos para **economizar memória** quando você precisa de milhares.

```ts
// Sem flyweight, cada partícula carrega sprite
class Particle {
  constructor(
    public x: number, public y: number,
    public vx: number, public vy: number,
    public spriteData: Uint8Array,   // 1MB!
  ) {}
}
// 1000 partículas = 1GB

// Com flyweight, sprite compartilhado
const SHARED_SPRITE: Uint8Array = loadSprite();   // uma cópia

class Particle {
  constructor(
    public x: number, public y: number,
    public vx: number, public vy: number,
  ) {}

  get sprite() { return SHARED_SPRITE; }
}
// 1000 partículas = trivial
```

**Quando usar:**
- Milhões de objetos compartilham parte do estado.
- Memória é restrição real.

**Exemplo real:** strings interned em Java. Caracteres em renderização de jogos. Tokens em compiladores.

### Proxy

**Intenção:** **representar** um objeto, controlando acesso a ele.

```ts
interface ImageLoader {
  load(): Image;
}

class RealImage implements ImageLoader {
  constructor(private url: string) {}
  load() {
    console.log(`Loading ${this.url}...`);   // operação cara
    return downloadAndDecode(this.url);
  }
}

// Lazy proxy, carrega apenas quando necessário
class LazyImageProxy implements ImageLoader {
  private cached?: Image;
  constructor(private url: string) {}

  load(): Image {
    if (!this.cached) {
      this.cached = new RealImage(this.url).load();
    }
    return this.cached;
  }
}

// Cliente não sabe se é Real ou Lazy
const img = new LazyImageProxy('large.png');
// img.load() carrega na primeira chamada, cacheia nas próximas
```

**Variantes:**

- **Virtual Proxy**: lazy load (exemplo acima).
- **Protection Proxy**: verifica permissões antes de delegar.
- **Remote Proxy**: abstrai chamada remota (stub gRPC, RMI).
- **Smart Reference**: conta referências, logs, etc.
- **Cache Proxy**: cacheia respostas.

**Em TS moderno:** o objeto `Proxy` da linguagem permite construir proxies dinâmicos com handlers genéricos.

### Comparação rápida

| Quero... | Use |
|---|---|
| Interface diferente para classe existente | **Adapter** |
| Variar dimensões ortogonais sem explosão de classes | **Bridge** |
| Estrutura em árvore com folhas e ramos uniformes | **Composite** |
| Adicionar capacidades em runtime | **Decorator** |
| Interface simples sobre subsistema complexo | **Facade** |
| Economizar memória com objetos compartilhados | **Flyweight** |
| Controlar acesso a um objeto (lazy, cache, security) | **Proxy** |

## Quando *não* usar

- **Para parecer arquiteto.** Não envolva tudo em Facade só porque "fica mais limpo".
- **Quando linguagem oferece mecanismo nativo.** Lazy loading em JS = uma `Promise` ou módulo dinâmico, não precisa de Proxy formal.
- **Quando 1–2 linhas de código resolvem.** Padrão é solução para **problema recorrente**: não para qualquer integração de duas classes.

## Conceitos relacionados

- [Padrões criacionais](./creational.md)
- [Padrões comportamentais](./behavioral.md)
- [Enterprise patterns](./enterprise-patterns.md)
- [Hexagonal](../architecture/hexagonal-ports-adapters.md), adapters viraram primeira classe.
- [Coesão e acoplamento](../foundations/cohesion-coupling.md), vários padrões reduzem acoplamento.

## Referências

- **Livro.** Gamma et al., *Design Patterns* (Addison-Wesley, 1994). *Gang of Four*.
- **Site.** [Refactoring Guru: Structural Patterns](https://refactoring.guru/design-patterns/structural-patterns). Material visual com exemplos.
- **Livro.** Eric Freeman, Elisabeth Robson, *Head First Design Patterns*, 2ª ed. (O'Reilly, 2020).
- **Site.** [SourceMaking: Structural Patterns](https://sourcemaking.com/design_patterns/structural_patterns).
- **Livro.** Joshua Bloch, *Effective Java*, 3ª ed. (Addison-Wesley, 2017). Item sobre composition over inheritance.
- **Documentação.** [MDN: JavaScript Proxy](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy). Proxy nativo em JS.
