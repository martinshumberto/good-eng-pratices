# Code Smells

> **TL;DR.** *Code smells* são pistas (não certezas) de que algo pode estar errado no design. Aprenda a identificá-los para guiar refatorações, mas não os trate como regras absolutas.

## O quê

O termo *code smell* foi cunhado por **Kent Beck** e popularizado por **Martin Fowler** em *Refactoring* (1999). A definição é deliberadamente vaga:

> "A code smell is a surface indication that usually corresponds to a deeper problem in the system."
> (Martin Fowler, [Bliki: Code Smell](https://martinfowler.com/bliki/CodeSmell.html))

Não é um bug, o código funciona. É um **sinal** de que a manutenção do código vai doer mais do que precisava.

## Por quê

Smells dão vocabulário para conversas de design. Em vez de dizer "esse código está estranho", você diz "isso é *Feature Envy*" ou "isso é *Shotgun Surgery*". Diagnóstico nomeado leva a tratamento conhecido, *Refactoring* cataloga, para cada smell, as refatorações que normalmente o resolvem.

## Como aplicar

### Os smells mais comuns

#### Funções longas (*Long Function*)

Funções que fazem muitas coisas. Quanto maior, maior a chance de violar [SRP](./solid.md) e dificultar leitura.

> "Whenever we feel the need to comment something, we write a method instead."
> (Fowler & Beck, *Refactoring* (2018))

**Tratamento:** *Extract Function*, decompondo em funções menores nomeadas pelo propósito.

#### Longa lista de parâmetros (*Long Parameter List*)

Mais de 3–4 parâmetros é sinal amarelo. Sugere que a função faz coisas demais ou que existe um conceito agrupado escondido.

**Tratamento:** *Introduce Parameter Object*, agrupe parâmetros relacionados em um tipo.

```ts
// ❌
function bookFlight(from: string, to: string, dateOut: Date, dateIn: Date,
                    adults: number, children: number, seatPref: string) {}

// ✅
interface BookingRequest {
  route: { from: string; to: string };
  dates: { out: Date; in: Date };
  passengers: { adults: number; children: number };
  preferences: { seat?: string };
}
function bookFlight(req: BookingRequest) {}
```

#### Repetição de código (*Duplicated Code*)

Trechos iguais ou quase iguais em vários lugares. Violação direta de [DRY](./dry-kiss-yagni.md), mas cuidado com falsa duplicação (trechos que coincidem hoje mas têm motivações diferentes).

**Tratamento:** *Extract Function* / *Extract Class*, ou *Pull Up Method* em hierarquias.

#### Instruções de `switch` complexas (*Switch Statements*)

`switch` em um *tipo discriminador* (`type === 'card' | 'boleto' | 'pix'`) que se repete espalhado pela base é candidato a polimorfismo (violação de [OCP](./solid.md)).

**Tratamento:** *Replace Conditional with Polymorphism*.

#### Acoplamento excessivo (*Inappropriate Intimacy*, *Feature Envy*)

- ***Feature Envy***, um método em A usa mais a classe B do que A própria. Sinal de que o método deveria viver em B.
- ***Inappropriate Intimacy***, duas classes que conhecem detalhes privados uma da outra. Acoplamento alto, baixa coesão.

**Tratamento:** *Move Method*, *Move Field*, *Hide Delegate*.

#### Classes/funções com muitas responsabilidades (*Divergent Change*, *Large Class*)

Quando uma mesma classe muda por dois motivos diferentes em momentos diferentes, ela está servindo a múltiplos atores, violação de [SRP](./solid.md).

**Tratamento:** *Extract Class*.

#### Mudança em estilingue (*Shotgun Surgery*)

Para fazer uma única mudança lógica, você precisa editar muitos arquivos. O oposto de *Divergent Change*, aqui a responsabilidade ficou esparramada.

**Tratamento:** *Move Method* / *Move Field* para juntar o que pertence junto.

#### Obsessão por primitivos (*Primitive Obsession*)

Usar `string`/`number` para conceitos que merecem tipos próprios (`Email`, `Money`, `OrderId`).

**Tratamento:** *Replace Primitive with Object* ou branded types. Ver [MISU](./make-illegal-states-unrepresentable.md).

#### Generalidade especulativa (*Speculative Generality*)

Abstrações criadas "para o caso de". Hooks, parâmetros, classes-base sem uso real. Violação direta de [YAGNI](./dry-kiss-yagni.md).

**Tratamento:** *Collapse Hierarchy*, *Inline Class*, *Remove Parameter*.

#### Comentários (*Comments* como smell)

Comentários explicativos podem ser cheiro de que o código não está se explicando sozinho. Frequentemente são oportunidade de *Extract Function* ou *Rename Variable*.

> "Don't comment bad code, rewrite it."
> (Kernighan & Plauger, *The Elements of Programming Style*)

---

### O anti-padrão "helpers / utils"

Um caso muito comum no dia a dia: criar `lib/helpers.ts` ou `utils.ts` "pra guardar funções comuns". Parece útil; com o tempo vira depósito de tudo que ninguém soube onde colocar.

```ts
// ❌ helpers.ts vira lixeira de contextos não-relacionados
export function formatCurrency(amount: number): string { /* ... */ }
export function formatDate(date: Date): string { /* ... */ }
export function debounce<T>(fn: T, ms: number): T { /* ... */ }
export function slugify(text: string): string { /* ... */ }
```

Problemas:

- **Coesão zero**: o módulo agrega coisas só pela negação ("não pertence a lugar nenhum").
- **Acoplamento alto**: qualquer mudança no arquivo afeta todo mundo que importa dele.
- **Crescimento descontrolado**: vira candidato a ter 500+ linhas e dezenas de exports.

Solução: divida por **contexto explícito**, mesmo que comece pequeno:

```
formatting/
├─ currency.ts
├─ date.ts
└─ string.ts
async/
├─ debounce.ts
└─ throttle.ts
```

Cada arquivo tem propósito claro. Aumentar o `formatting/currency.ts` é seguro, afeta só quem se importa com moeda.

## Quando *não* usar

- **Como regra rígida.** Smells são heurísticas. Há contextos em que uma função longa é mais clara que dez funções curtas, ou em que uma duplicação é o caminho certo (Sandi Metz: "duplication is far cheaper than the wrong abstraction").
- **Como justificativa para refatoração sem objetivo.** Smell aponta para *possível* problema. Antes de refatorar, identifique o que dói na prática (manutenção difícil, bugs recorrentes) e mire a refatoração nele.

## Conceitos relacionados

- [DRY: KISS, YAGNI](./dry-kiss-yagni.md)
- [SOLID](./solid.md)
- [Coesão e acoplamento](./cohesion-coupling.md)

## Referências

- **Livro.** Martin Fowler, *Refactoring: Improving the Design of Existing Code*, 2ª ed. (Addison-Wesley, 2018). Capítulo 3: *Bad Smells in Code*.
- **Livro.** Kent Beck, *Implementation Patterns* (Addison-Wesley, 2007).
- **Site.** [Refactoring Guru: Code Smells](https://refactoring.guru/refactoring/smells). Catálogo visual e bem organizado.
- **Artigo.** Sandi Metz, ["The Wrong Abstraction"](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction) (2016). Por que duplicação às vezes é mais barata.
- **Artigo.** Martin Fowler, ["Code Smell"](https://martinfowler.com/bliki/CodeSmell.html), bliki.
