# Feature Flags

> **TL;DR.** Feature flags (toggles) **separam deploy de release**. Permitem mergear código incompleto sem ativá-lo, ligar features para subconjuntos de usuários, e desligar features em incidente. Flags são poderosas, e viram dívida técnica se ficam para sempre.

## O quê

**Feature flag** (também *feature toggle*) é uma técnica para **mudar comportamento do sistema sem mudar código**: o código está lá, mas a flag controla se ele executa.

```ts
if (featureFlags.isEnabled('new_checkout_flow', user)) {
  return newCheckout();
} else {
  return oldCheckout();
}
```

**Pete Hodgson** ([Martin Fowler's site, 2017](https://martinfowler.com/articles/feature-toggles.html)) categorizou em **4 tipos**, cada um com características distintas:

| Tipo | Quanto dura | Quem decide | Mudança |
|---|---|---|---|
| **Release** | Curto (semanas) | Equipe de produto | Frequente, então remoção |
| **Experiment** | Curto-médio | A/B test, segmento | Frequente |
| **Ops** | Longo | Ops / SRE | Em incidente |
| **Permission** | Permanente | Per-user, plano comercial | Quando usuário muda |

A categoria define **como** lidar com cada flag, não tudo é igual.

## Por quê

Antes de flags, "release" e "deploy" eram sinônimos. Você não podia mergear código não-pronto. Resultado:

- **Branches longas** que dão merge hell.
- **"Big bang" releases** com 50 features juntas.
- **Rollback** = deploy de versão anterior (lento, arriscado).

Flags resolvem:

- **Trunk-based development**: merge sem ativar.
- **Deploy seguro**: código novo já está em produção, mas dormente.
- **Release gradual**: 1% dos usuários, depois 10%, depois 100%.
- **Kill switch**: desliga feature em incidente sem rollback.
- **Experimentação**: A/B tests reais.
- **Customização por plano**: feature paga só para tier premium.

> "Deploys should be boring."
> (Charity Majors)

Feature flags são o que tornam isso possível.

## Como aplicar

### Os 4 tipos

#### Release toggles

**Propósito:** permitir merge antes do código estar pronto, ou liberar feature gradualmente.

**Características:**

- Dura **semanas**, no máximo.
- Controle binário (on/off) ou percentual de tráfego.
- Removida assim que a feature for adotada.

```ts
// Mergeado, mas dormente em produção
if (featureFlags.isEnabled('new_checkout_v2')) {
  return checkoutV2(order);
}
return checkoutV1(order);
```

#### Experiment toggles

**Propósito:** A/B testing, comparar variantes em segmento de usuários.

**Características:**

- Dura o tempo do experimento (semanas).
- Decisão baseada em **métrica**: qual variante converte melhor?
- Granularidade fina, atribuição por user/session ID.

```ts
const variant = featureFlags.getVariant('checkout_button_color', user);
// variant: 'green' | 'blue' | 'control'

return <Button color={variant === 'green' ? 'green' : 'blue'}>Comprar</Button>;
```

Combine com analytics, meça conversão por variante.

#### Ops toggles

**Propósito:** controle operacional em produção. *Kill switch* para features pesadas, *circuit breaker* manual, throttling.

**Características:**

- Dura **muito tempo**: frequentemente permanente.
- Ativada por ops/SRE durante incidente.
- Permite degradação graciosa.

```ts
if (featureFlags.isEnabled('enable_personalized_recommendations')) {
  return getPersonalizedRecommendations(user);
}
return getDefaultRecommendations();   // fallback barato
```

Quando o sistema de recomendação ML cai, desliga a flag → fallback rápido → usuário não vê erro.

#### Permission toggles

**Propósito:** features acessíveis a subconjuntos de usuários por **direito** (plano comercial, role, geografia).

**Características:**

- **Permanente**: não vão sair.
- Mudam quando o status do usuário muda (upgrade de plano).
- Frequentemente são "entitlements" em sistemas de billing.

```ts
if (featureFlags.isEnabled('advanced_analytics', user)) {
  return showAdvancedAnalytics();
}
return showBasicAnalytics();
```

### Lifecycle: flags morrem (a maioria)

Flags **release** e **experiment** são **temporárias por definição**. Quando a feature é estabilizada:

1. Remova a flag.
2. Remova o branch "antigo".
3. Limpe o config do sistema de flags.

Sem essa disciplina, o código vira floresta de `if`s mortos.

> "Feature toggles are a debt. Pay them off."
> (Pete Hodgson)

#### Política de expiração

Algumas equipes implementam **TTL** em flags:

```ts
@flag('new_checkout_v2', { expires: '2024-09-01', owner: 'checkout-team' })
function newCheckout() { /* ... */ }
```

Após expirar, alertas + bloqueio de PRs. Ferramentas como [LaunchDarkly](https://launchdarkly.com) e [Unleash](https://www.getunleash.io) trazem isso.

### Targeting: quem recebe a feature

Estratégias comuns:

#### Boolean: on/off global

```ts
featureFlags.isEnabled('new_checkout_v2');  // → true | false
```

Simplest. Usado em ops e em flags totalmente prontas.

#### Percentage rollout

```ts
// 10% dos usuários vê a feature nova
featureFlags.isEnabled('new_checkout_v2', user);  // → consistente por user.id
```

Crucial: **consistente por usuário**. Se Alice viu a versão nova, sempre veja, não pode alternar.

#### Segment-based

```ts
// Só usuários do plano "pro"
featureFlags.isEnabled('advanced_analytics', user);
// Decide internamente: if (user.plan === 'pro') return true;
```

#### Multivariate

```ts
const variant = featureFlags.getVariant('checkout_button', user);
// 'green' (33%) | 'blue' (33%) | 'red' (34%)
```

### Implementação

#### DIY simples

```ts
class FeatureFlags {
  constructor(private config: Record<string, FlagConfig>) {}

  isEnabled(key: string, user?: User): boolean {
    const flag = this.config[key];
    if (!flag) return false;
    if (!flag.enabled) return false;

    if (flag.percentage !== undefined && user) {
      const hash = sha1(`${key}:${user.id}`).slice(0, 4);
      const bucket = parseInt(hash, 16) % 100;
      return bucket < flag.percentage;
    }

    return flag.enabled;
  }
}
```

Boa para sistemas simples ou começo. Limites: sem UI, sem audit, sem update em runtime sem deploy.

#### Plataformas dedicadas

| Ferramenta | Notas |
|---|---|
| **[LaunchDarkly](https://launchdarkly.com)** | Líder do mercado. SDK em todas as linguagens. Caro. |
| **[Unleash](https://www.getunleash.io)** | Open source, self-hosted. Excelente alternativa. |
| **[Flagsmith](https://flagsmith.com)** | Open source, gratuito para começar. |
| **[ConfigCat](https://configcat.com)** | Foco em simplicidade. |
| **[GrowthBook](https://www.growthbook.io)** | Open source, foco em experiments. |
| **[Split.io](https://www.split.io)** | Feature flags + experimentation. |

#### Caching e performance

Flags são consultadas **muito** (potencialmente cada request). Use cache local com refresh:

```ts
// SDK busca flags do servidor a cada 30s; consulta em memória é instantânea
const client = new UnleashClient({
  url: process.env.UNLEASH_URL,
  appName: 'orders-service',
  refreshInterval: 30_000,
});
```

### Boas práticas

#### Nomes claros e contextuais

```ts
// ❌
featureFlags.isEnabled('flag1');
featureFlags.isEnabled('new_thing');

// ✅
featureFlags.isEnabled('checkout_v2_enabled');
featureFlags.isEnabled('recommendation_engine_personalized');
```

Convenções:

- `<feature>_<aspect>`: `checkout_v2_enabled`.
- Sufixo `_kill_switch` em flags de ops.
- Sufixo `_experiment` em flags de A/B.

#### Default seguro

Quando o sistema de flags cair, o app deve **funcionar**:

```ts
// ✅ Default conservador
function isEnabled(key: string, user?: User): boolean {
  try {
    return flagClient.evaluate(key, user);
  } catch {
    // Sistema de flags fora → default seguro
    return false;
  }
}
```

#### Ownership por flag

Cada flag tem **dono**: pessoa ou time. Sem dono, ninguém limpa.

#### Audit log

Mudanças em flags são **mudanças no comportamento de produção**. Loge:

- Quem mudou.
- O quê.
- Quando.

Use ferramentas que trazem isso nativamente.

#### Não use flags para config

Config (URL do banco, timeout, limite) **vai no env**. Flag é para **feature**.

```ts
// ❌ Config como flag
const dbUrl = featureFlags.getString('database_url');

// ✅ Flag para feature; config em env
const dbUrl = process.env.DATABASE_URL;
const useNewCheckout = featureFlags.isEnabled('checkout_v2');
```

### Pega-pegas

#### Combinação combinatória

Múltiplas flags interagindo = explosão de casos. Limite combinações ativas simultaneamente.

```
flag_a (on/off) × flag_b (on/off) × flag_c (on/off) = 8 cenários
```

Pode virar 32, 64... Cada combinação é um sistema diferente. Testes não cobrem todos.

#### Estado distribuído

Frontend e backend podem ter visões **diferentes** do estado de uma flag se atualizam em momentos diferentes. Trate transições com graciosidade.

#### Race conditions com cache local

Mudou no servidor → instâncias caches divergem por segundos. Aceite latência ou force refresh em mudanças críticas.

#### Performance

Avaliação de flag tem custo (especialmente com targeting complexo). Cache local + refresh assíncrono mitigam.

### Testes

Testes precisam **cobrir ambos os lados** da flag:

```ts
describe('checkout', () => {
  describe('when new_checkout_v2 is enabled', () => {
    beforeEach(() => featureFlags.enable('new_checkout_v2'));
    it('uses v2 flow', /* ... */);
  });

  describe('when new_checkout_v2 is disabled', () => {
    beforeEach(() => featureFlags.disable('new_checkout_v2'));
    it('uses v1 flow', /* ... */);
  });
});
```

Use mock/in-memory flag client em testes.

## Quando *não* usar

- **Para tudo.** Flag deveria ser exceção, não regra. Cada flag é dívida potencial.
- **Para versionar API.** Use [versionamento](../backend/api-versioning.md), não flag em cada endpoint.
- **Para esconder bugs.** Se feature precisa de flag "para o caso de quebrar", melhore-a antes.
- **Em sistemas extremamente regulados** onde mudanças em prod via UI são auditadas com rigor que flag dificulta.

## Conceitos relacionados

- [CI/CD](./ci-cd.md), flags desacoplam deploy de release.
- [Release strategies](./release-strategies.md), canary deploy frequentemente combinado com flags.
- [Trunk-Based Development](../collaboration/git-flow.md#alternativa-trunk-based-development-tbd), flags são pré-requisito.
- [Twelve-Factor App](./twelve-factor-app.md), flags como config dinâmico.

## Referências

- **Artigo.** Pete Hodgson, ["Feature Toggles (aka Feature Flags)"](https://martinfowler.com/articles/feature-toggles.html) (2017, site de Martin Fowler). Texto canônico, categoriza os 4 tipos.
- **Livro.** Adam Zimman, Heidi Waterhouse, Edith Harbaugh, *Effective Feature Management* (LaunchDarkly e-book). Free.
- **Livro.** Jez Humble & David Farley, *Continuous Delivery* (Addison-Wesley, 2010). Onde flags se encaixam.
- **Documentação.** [LaunchDarkly](https://docs.launchdarkly.com).
- **Documentação.** [Unleash](https://docs.getunleash.io). Open source.
- **Documentação.** [GrowthBook](https://docs.growthbook.io). Open source + experimentation.
- **Artigo.** Martin Fowler, ["FeatureToggle"](https://martinfowler.com/bliki/FeatureToggle.html). Bliki entry.
- **Artigo.** Charity Majors, ["The Engineer/Manager Pendulum"](https://charity.wtf/2017/05/11/the-engineer-manager-pendulum/). Não sobre flags, mas a citação sobre deploys.
