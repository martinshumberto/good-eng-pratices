# Estratégias de Cache

> **TL;DR.** Cache é troca consciente de **frescor** por **latência/custo**. Escolha o padrão (cache-aside, write-through, write-behind, read-through) consciente das garantias que dá e perde. Invalidação é o problema mais difícil, modele-a desde o início.

## O quê

**Cache** é uma cópia de dados mantida em um local de acesso mais rápido (geralmente em memória, próximo ao consumidor) para evitar trabalho repetido.

> "There are only two hard things in Computer Science: cache invalidation and naming things."
> (Phil Karlton)

Cache aparece em todo lugar:

- **Cliente / browser.** Cache HTTP via `Cache-Control`, `ETag`, `If-None-Match`.
- **CDN.** Cloudflare, Fastly, CloudFront. Edge cache para assets e responses.
- **Aplicação.** Redis, Memcached, processo local (in-memory).
- **Banco.** Query cache, buffer pool, materialized views.

Este documento foca em **cache aplicacional**: quando seu código decide o quê e quando armazenar.

## Por quê

Cache resolve dois problemas:

- **Latência.** Buscar do cache (~1ms) é dramaticamente mais rápido que do banco (~50ms) ou de uma API externa (~200ms+).
- **Carga.** Reduz queries no banco, chamadas externas, throughput necessário do backend.

Custos:

- **Frescor.** Dados em cache podem estar desatualizados.
- **Consistência.** Múltiplas réplicas/regiões podem divergir.
- **Complexidade.** Invalidar corretamente é não-trivial.
- **Custo financeiro.** Cache distribuído (Redis cluster) tem preço.

Regra geral: **comece sem cache**. Adicione quando medir gargalo real. Cache prematuro complica sem ganho proporcional.

## Como aplicar

### Padrões clássicos

#### Cache-aside (lazy loading)

O **mais comum**. A aplicação consulta cache primeiro; em miss, busca da fonte, popula cache, retorna.

```ts
async function getUser(id: string): Promise<User> {
  // 1. Tenta o cache
  const cached = await cache.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  // 2. Miss, busca da fonte
  const user = await db.users.findById(id);

  // 3. Popula o cache (com TTL)
  await cache.set(`user:${id}`, JSON.stringify(user), { ex: 300 });

  return user;
}
```

**Vantagens:**

- Simples.
- Sobreviver à falha do cache (degrada para banco).
- Cache armazena só o que foi pedido.

**Desvantagens:**

- Primeira request é lenta (cache miss).
- Cache pode ficar desatualizado (até o TTL ou invalidação explícita).
- Sob alta concorrência, várias requests podem disparar fetch simultâneo (cache stampede, ver abaixo).

#### Read-through

Cache atua como **proxy de leitura**. A aplicação só fala com o cache; o cache busca da fonte em miss.

```ts
// Camada de cache implementa busca
class CachedUserRepository {
  async findById(id: string): Promise<User> {
    return this.cache.getOrFetch(`user:${id}`, async () => {
      return this.db.users.findById(id);
    }, { ttl: 300 });
  }
}
```

**Vantagens:**

- Encapsula a lógica de fetch.
- Cliente não precisa saber sobre cache.

**Desvantagens:**

- Mais código de infra.
- Mesma issue de stampede do cache-aside.

#### Write-through

Toda escrita vai **para o cache e para a fonte** simultaneamente.

```ts
async function updateUser(id: string, data: Partial<User>): Promise<User> {
  const updated = await db.users.update(id, data);
  await cache.set(`user:${id}`, JSON.stringify(updated), { ex: 300 });
  return updated;
}
```

**Vantagens:**

- Cache sempre fresh para o que foi escrito.

**Desvantagens:**

- Escrita mais lenta (duas operações).
- Pode popular cache com dados que ninguém vai ler.

#### Write-behind (write-back)

Escrita vai para o **cache imediatamente**; cache propaga para a fonte de forma assíncrona.

**Vantagens:**

- Escritas muito rápidas.

**Desvantagens:**

- Risco de perda de dados se cache cair antes de propagar.
- Garantias de consistência fracas.

Use só quando perda de algumas escritas é tolerável (analytics, métricas).

### TTL: *Time To Live*

A forma mais simples de invalidar: dado expira após X tempo.

```ts
await cache.set('user:42', value, { ex: 300 });   // 5 minutos
```

**TTL curto** = mais misses, mais carga, dados mais frescos.
**TTL longo** = mais hits, menos carga, dados mais velhos.

Heurísticas:

- **Dados quase imutáveis** (configurações, países): TTL alto (horas/dias).
- **Dados com mudança frequente mas tolerável**: minutos.
- **Dados que mudam raramente mas devem ser frescos**: TTL longo + invalidação explícita.

### Invalidação explícita

Quando o dado muda, **derrube o cache**:

```ts
async function updateUser(id: string, data: Partial<User>): Promise<User> {
  const updated = await db.users.update(id, data);
  await cache.del(`user:${id}`);   // invalidação
  return updated;
}
```

**Cuidados:**

- **Inválide tudo que depende.** Atualizar `user:42` pode exigir invalidar `team:7:members`, `org:1:users`, etc. Mapear essas dependências é o "problema duro" de cache invalidation.
- **Race conditions.** Entre invalidação e próxima leitura, alguém pode popular cache com dado velho. Use *versioning* ou *write-through* combinado.

### Padrão chave/escopo

Convenção para keys:

```
<entidade>:<id>                       user:42
<entidade>:<id>:<aspecto>             user:42:permissions
<entidade>:list:<filtro-hash>         orders:list:status=placed&customer=42
<versão>:<entidade>:<id>              v2:user:42
```

Versão na key facilita "expirar tudo de uma vez", bumpa `v2` para `v3` e o cache antigo fica órfão.

### Stampede / Thundering Herd

Cenário: 1000 requests caem em uma key que acabou de expirar. Todas tentam buscar da fonte simultaneamente, banco sofre.

#### Soluções

**1. Lock distribuído (single-flight).** Apenas uma request faz fetch; o resto espera.

```ts
async function getUser(id: string): Promise<User> {
  const cached = await cache.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  return await lockingCache.singleFlight(`user:${id}`, async () => {
    const user = await db.users.findById(id);
    await cache.set(`user:${id}`, JSON.stringify(user), { ex: 300 });
    return user;
  });
}
```

**2. Early refresh probabilístico ([XFetch](https://www.vldb.org/pvldb/vol8/p886-vattani.pdf)).** Refaz cache antes do TTL com probabilidade crescente, espalha o refresh no tempo.

**3. Stale-while-revalidate.** Retorna dado expirado **e** dispara refresh em background. Cliente recebe rápido; cache fica atualizado para a próxima.

### Caches de tipo especial

#### Negative caching

Cachê também os **misses**: se buscar um ID que não existe, marque como "not found" por algum tempo. Evita martelar o banco com pesquisas inválidas.

```ts
const cached = await cache.get(`user:${id}`);
if (cached === '__NOT_FOUND__') return null;
if (cached) return JSON.parse(cached);

const user = await db.users.findById(id);
if (!user) {
  await cache.set(`user:${id}`, '__NOT_FOUND__', { ex: 60 });  // TTL curto
  return null;
}

await cache.set(`user:${id}`, JSON.stringify(user), { ex: 300 });
return user;
```

#### Memoization (cache local em memória)

Para dados muito frequentes e leves, um *cache local* in-process (LRU, sem rede) tem latência ainda menor que Redis.

```ts
import LRU from 'lru-cache';

const localCache = new LRU<string, User>({ max: 1000, ttl: 60_000 });

async function getUser(id: string): Promise<User> {
  const local = localCache.get(id);
  if (local) return local;

  // Cai pra Redis ou banco
  const user = await getUserFromRedisOrDb(id);
  localCache.set(id, user);
  return user;
}
```

**Cuidado:** cache local **não invalida** entre processos. Use TTL curto, ou pub/sub para invalidação cross-process.

### Cache HTTP: não esqueça

Antes de cachear no Redis, considere se headers HTTP resolvem:

```http
GET /api/products/42 HTTP/1.1

HTTP/1.1 200 OK
Cache-Control: public, max-age=300, s-maxage=600
ETag: "abc123"
```

- **`Cache-Control`**: instrui browser, CDN, proxies.
- **`ETag` + `If-None-Match`**: validação condicional, retorna 304 quando inalterado.
- **`Vary`**: diz por quais headers o cache deve segmentar.

CDN bem configurado vai cobrir 80% do que se costuma fazer "manualmente" com Redis. Ver [Mozilla Developer Network: HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching).

### Coerência multi-camada

Quando há **vários níveis** (local → Redis → DB), o TTL no local **deve ser ≤** TTL no Redis. Senão você guarda mais velho que poderia.

## Quando *não* usar

- **Dados muito voláteis** (mudam toda chamada). Cache não dá ganho, só introduz risco de inconsistência.
- **Dados muito específicos por usuário e raramente repetidos.** Cache não tem hit rate.
- **Dados onde frescor é absoluto** (saldo bancário em transação em andamento). Vá direto à fonte.
- **Quando o gargalo está em outro lugar.** Cache em frente a CPU bound não ajuda. Meça antes.

## Conceitos relacionados

- [API design (REST](./api-design-rest.md)) cache HTTP.
- [Rate limiting](./rate-limiting.md), também usa cache distribuído.
- [Idempotência](./idempotency.md), caches de idempotency keys.

## Referências

- **Livro.** Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017). Capítulos 1, 5 e 9 discutem cache e consistência.
- **Livro.** Sergey Korban, *Designing Distributed Systems* (Microsoft, 2018). Patterns de cache distribuído.
- **Artigo.** Facebook, ["Scaling Memcache at Facebook"](https://research.facebook.com/publications/scaling-memcache-at-facebook/) (NSDI 2013). Paper canônico sobre cache em escala.
- **Paper.** Andrea Vattani et al., ["Optimal Probabilistic Cache Stampede Prevention"](http://www.vldb.org/pvldb/vol8/p886-vattani.pdf) (VLDB 2015). XFetch.
- **Artigo.** AWS, ["Caching Best Practices"](https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/BestPractices.html). Práticas em ElastiCache.
- **Documentação.** [Redis: Best Practices](https://redis.io/docs/manual/patterns/).
- **Documentação.** [MDN: HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching). Excelente para cache HTTP.
- **Artigo.** Phil Karlton, origem da citação (ver [Martin Fowler: TwoHardThings](https://martinfowler.com/bliki/TwoHardThings.html)).
