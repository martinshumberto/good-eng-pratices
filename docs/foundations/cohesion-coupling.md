# Coesão e Acoplamento

> **TL;DR.** Bons módulos têm **alta coesão** (o que está junto faz sentido junto) e **baixo acoplamento** (mudar um módulo não obriga mexer em outros). É a métrica de design mais antiga e mais útil.

## O quê

- **Coesão**: o grau em que os elementos *dentro de* um módulo pertencem juntos.
- **Acoplamento**: o grau de interdependência *entre* módulos.

Os termos foram introduzidos por **Larry Constantine** nos anos 60 e popularizados por **Edward Yourdon & Constantine** em *Structured Design* (1979). Apesar da idade, continuam sendo o vocabulário central para discutir qualidade de design.

## Por quê

Coesão e acoplamento são os dois lados do mesmo objetivo: **localizar mudança**. Quando os módulos são bem definidos, uma mudança no requisito altera poucos módulos; quando são mal definidos, a mudança "vaza" pelo sistema todo.

> "Cohesion and coupling are the most important concepts in software design."
> (Glenford Myers, *Composite/Structured Design* (1978))

Os sintomas de baixa coesão / alto acoplamento aparecem como [code smells](./code-smells.md): *Shotgun Surgery* (uma mudança força edições em muitos lugares), *Feature Envy* (um método usa mais outra classe do que a sua), *Divergent Change* (uma classe muda por motivos não-relacionados).

## Como aplicar

### Alta coesão: separação de responsabilidades

Cada módulo deve ter um foco claro. Camadas bem definidas permeiam toda a base:

- **Funções**: uma função, uma operação.
- **Estruturas de dados**: um tipo, um conceito.
- **Regras de negócio (domínios)**: um domínio, uma fronteira.

```ts
// ❌ Baixa coesão: a mesma classe gerencia auth, perfil e billing
class User {
  authenticate(password: string) {}
  updateAvatar(file: Buffer)     {}
  chargeMonthlyFee()             {}
}

// ✅ Alta coesão: cada classe foca em um conceito
class AuthUser    { authenticate(password: string) {} }
class ProfileUser { updateAvatar(file: Buffer)     {} }
class Billing     { chargeMonthlyFee(user: User)   {} }
```

> "Gather together those things that change for the same reason, and separate those things that change for different reasons."
> (Robert C. Martin (formulação alternativa do SRP))

### Baixo acoplamento: interdependência reduzida

Cada módulo deve saber **o mínimo** sobre os outros. Quando A "sabe demais" sobre B, alterar B força alterar A.

```ts
// ❌ Acoplamento alto: Order conhece a estrutura interna do Customer
function shouldOffer Discount(order: Order) {
  return order.customer.address.country === 'BR' &&
         order.customer.purchases.length > 10;
}

// ✅ Customer expõe a abstração; Order não precisa saber como é calculado
function shouldOfferDiscount(order: Order) {
  return order.customer.isLoyalCustomer();
}
```

### Modularização

Organize o código em módulos baseados em **funcionalidade ou domínio**, não em tipo técnico (`controllers/`, `services/`, `models/`).

```
// ❌ Por camada técnica, mudar a feature "checkout" exige tocar 5 pastas
src/
├─ controllers/
├─ services/
├─ models/
├─ validators/
└─ repositories/

// ✅ Por domínio, checkout vive numa pasta só
src/
├─ checkout/
├─ catalog/
├─ payments/
└─ shipping/
```

Essa organização aproxima coesão (tudo de checkout junto) e reduz acoplamento (mudar checkout não exige tocar payments).

### Tipos de coesão (do pior para o melhor)

Constantine catalogou 7 níveis:

1. **Coincidental**: agrupamento aleatório. Pior caso.
2. **Lógica**: funções da mesma "categoria genérica" (ex.: `utils/`).
3. **Temporal**: coisas executadas no mesmo tempo (ex.: `init()` que faz 10 coisas).
4. **Procedural**: passos de um mesmo procedimento.
5. **Communicational**: operam nos mesmos dados.
6. **Sequencial**: saída de uma é entrada da próxima.
7. **Funcional**: todos os elementos contribuem para uma única tarefa bem definida. **Ideal.**

### Tipos de acoplamento (do melhor para o pior)

1. **Data**: passam só dados primitivos. **Ideal.**
2. **Stamp**: passam estruturas mas usam só parte.
3. **Control**: um módulo controla o fluxo do outro via flags.
4. **External**: dependem do mesmo formato externo (ex.: arquivo).
5. **Common**: compartilham estado global mutável.
6. **Content**: um módulo modifica diretamente o interior do outro. **Pior caso.**

## Quando *não* usar

- **Coesão extrema** pode levar a uma explosão de classes mínimas, cada uma com um método público. SRP (ver [SOLID](./solid.md)) é sobre **atores**, não sobre número de linhas.
- **Desacoplar tudo** custa: cada interface introduz indireção e dificulta navegação. Acople deliberadamente quando dois conceitos realmente vivem juntos no domínio.

## Conceitos relacionados

- [SOLID](./solid.md), especialmente SRP e DIP.
- [DRY: KISS, YAGNI](./dry-kiss-yagni.md)
- [Code smells](./code-smells.md)
- [Modelagem por domínio (DDD)](../architecture/domain-driven-design.md)

## Referências

- **Livro.** Edward Yourdon & Larry Constantine, *Structured Design: Fundamentals of a Discipline of Computer Program and Systems Design* (Prentice Hall, 1979). Texto fundador.
- **Livro.** Steve McConnell, *Code Complete*, 2ª ed. (Microsoft Press, 2004), capítulo 5: *Design in Construction*.
- **Livro.** Robert C. Martin, *Clean Architecture* (Prentice Hall, 2017), capítulos sobre SRP e Component Cohesion (REP, CCP, CRP).
- **Artigo.** Martin Fowler, ["Cohesion"](https://martinfowler.com/bliki/Cohesion.html), bliki.
