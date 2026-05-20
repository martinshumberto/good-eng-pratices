# Rate Limiting

> **TL;DR.** Limita quantas requests um cliente pode fazer em uma janela de tempo. Protege o sistema contra abuso, garante fairness entre tenants e dá previsibilidade de carga. Implemente em camadas (CDN → gateway → aplicação) e responda com `429` e headers padronizados.

## O quê

**Rate limiting** (também *throttling*) é a prática de **limitar a taxa** de requests aceitas de um cliente, identificador, IP, ou endpoint.

Razões para aplicar:

- **Proteção contra abuso**: DDoS leve, scraping, força bruta.
- **Fairness multi-tenant**: um cliente não pode sufocar os outros.
- **Proteção de custo**: APIs pagas precisam evitar cliente que estoura quota.
- **Estabilidade**: limites previsíveis evitam picos que derrubam o sistema.

> Rate limiting é **antes** de elasticidade, escalar não resolve um cliente malicioso ou mal configurado.

## Por quê

Sem rate limiting, todo sistema está vulnerável a:

- **Bot scraping a coleção inteira em loop.**
- **Cliente com bug em retry exponencial mal configurado** (que vira retry linear infinito).
- **Tentativa de força bruta** em endpoint de login.
- **Cliente fazendo polling agressivo** quando deveria usar webhook.

Rate limiting é a primeira linha de defesa, **sem ele, qualquer outra proteção é em vão**.

## Como aplicar

### Algoritmos

#### Token Bucket

O mais usado. Cada cliente tem um "balde" com capacidade fixa, que se reenche a uma taxa constante.

```
Capacidade: 100 tokens
Taxa de refill: 10 tokens/segundo

t=0:   balde cheio (100)
t=10:  cliente fez 80 requests → balde tem 20 + 100 refilled = 120 (limitado a 100)
```

- **Vantagem:** permite **bursts** curtos (até a capacidade do balde).
- **Implementação:** contador + timestamp do último refill.

```ts
class TokenBucket {
  private tokens: number;
  private lastRefill: number;

  constructor(
    private capacity: number,
    private refillRatePerSec: number,
  ) {
    this.tokens     = capacity;
    this.lastRefill = Date.now();
  }

  tryConsume(n = 1): boolean {
    this.refill();
    if (this.tokens < n) return false;
    this.tokens -= n;
    return true;
  }

  private refill() {
    const now = Date.now();
    const elapsedSec = (now - this.lastRefill) / 1000;
    this.tokens     = Math.min(this.capacity, this.tokens + elapsedSec * this.refillRatePerSec);
    this.lastRefill = now;
  }
}
```

#### Leaky Bucket

Inverso conceitual: requests "entram" no balde com qualquer taxa; saem (são processadas) a uma taxa constante. Excesso é descartado.

- **Vantagem:** **suaviza** picos, saída sempre constante.
- **Desvantagem:** não permite bursts.

Útil em filas de processamento, menos em APIs HTTP onde bursts são esperados.

#### Fixed Window Counter

Conta requests em janelas fixas (ex.: por minuto).

```
Janela 10:00-10:01:  100 reqs permitidas
Janela 10:01-10:02:  contador reseta
```

- **Vantagem:** trivial de implementar (`INCR` em Redis com TTL).
- **Desvantagem:** permite **dobra de carga na borda**: 100 reqs em 10:00:59 + 100 em 10:01:00 = 200 em 1 segundo.

#### Sliding Window Log

Armazena timestamps de cada request; conta quantas caem na janela em movimento.

- **Vantagem:** preciso, sem efeito de borda.
- **Desvantagem:** memória cresce com volume.

#### Sliding Window Counter

Aproximação: combina contadores da janela atual e anterior, ponderados por overlap.

```
Janela 10:00-10:01:  90 reqs
Janela 10:01-10:02 (em t=10:01:30):  contagem = 90 * 0.5 + reqs_da_janela_atual
```

- **Vantagem:** quase tão preciso quanto log, com memória constante.
- **Desvantagem:** mais código.

#### Comparação

| Algoritmo | Bursts | Precisão | Complexidade |
|---|---|---|---|
| Token Bucket | Permite | Boa | Média |
| Leaky Bucket | Não permite | Boa | Média |
| Fixed Window | Permite (com borda) | Baixa | Trivial |
| Sliding Log | Permite | Alta | Alta (memória) |
| Sliding Counter | Permite | Boa | Média |

**Default sensato:** Token Bucket ou Sliding Counter.

### Implementação distribuída: Redis

Em sistemas com múltiplas instâncias, o estado de rate limiting precisa ser **compartilhado**:

```ts
// Sliding window counter em Redis (Lua script atômico)
const LUA_SCRIPT = `
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, '-inf', now - window)
local count = redis.call('ZCARD', key)

if count < limit then
  redis.call('ZADD', key, now, now)
  redis.call('EXPIRE', key, math.ceil(window / 1000))
  return 1
end
return 0
`;

async function isAllowed(userId: string, limit = 100, windowMs = 60_000): Promise<boolean> {
  const result = await redis.eval(LUA_SCRIPT, 1, `rl:${userId}`, Date.now(), windowMs, limit);
  return result === 1;
}
```

Use bibliotecas testadas em produção quando possível: [`@upstash/ratelimit`](https://github.com/upstash/ratelimit-js), [`rate-limiter-flexible`](https://github.com/animir/node-rate-limiter-flexible), [`bottleneck`](https://github.com/SGrondin/bottleneck).

### Identificadores: quem é o "cliente"

Possibilidades, da mais específica à mais genérica:

| Chave | Quando usar |
|---|---|
| `user_id` ou `api_key` | Padrão para APIs autenticadas |
| `tenant_id` / `organization_id` | Para limitar uma organização inteira |
| `ip` | Para endpoints públicos (login, signup) |
| `ip + endpoint` | Para endpoints específicos sensíveis |
| `device_fingerprint` | Anti-abuso em apps mobile |

**Combine quando necessário:** rate limit global por API key **e** local por endpoint.

### Resposta HTTP: RFC 6585 e draft IETF

Quando o limite é atingido, retorne **`429 Too Many Requests`** ([RFC 6585](https://www.rfc-editor.org/rfc/rfc6585)):

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 30
RateLimit-Limit:     100
RateLimit-Remaining: 0
RateLimit-Reset:     30

{
  "type": "https://example.com/probs/rate-limited",
  "title": "Too Many Requests",
  "status": 429,
  "detail": "Rate limit of 100 requests per minute exceeded. Try again in 30s."
}
```

Headers padronizados ([draft IETF: RateLimit Header Fields](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)):

- **`RateLimit-Limit`**: limite máximo na janela.
- **`RateLimit-Remaining`**: quantas requests ainda cabem.
- **`RateLimit-Reset`**: segundos até a janela resetar.
- **`Retry-After`**: quanto tempo esperar antes de tentar de novo (segundos ou HTTP-date).

Inclua os headers **em todas as responses**, não só nas 429, clientes bem-comportados ajustam.

### Camadas: onde aplicar

Aplique em múltiplas camadas, cada uma protegendo a próxima:

```
Cliente → CDN/WAF → Gateway/Load Balancer → Aplicação → Banco
          (DDoS)    (API quota)              (per user)   (connection pool)
```

| Camada | Limite típico |
|---|---|
| **CDN/WAF (Cloudflare, etc.)** | Por IP, milhares/min. Bloqueia abuso massivo. |
| **API Gateway** | Por API key / plano contratado. |
| **Aplicação** | Por user / endpoint / operação específica. |
| **Banco** | Connection pool, statement timeout. |

Quem chegou ao banco já passou por filtros, então o banco protege com pouco esforço.

### Limites por endpoint: escolha consciente

Nem todo endpoint deve ter o mesmo limite. Modelo típico:

| Endpoint | Limite sugerido |
|---|---|
| `POST /auth/login` | 5 / min por IP (anti-brute-force) |
| `POST /auth/signup` | 3 / hora por IP (anti-spam) |
| `GET /resources` (listar) | 100 / min por user |
| `POST /resources` (criar) | 30 / min por user |
| `GET /search` | 30 / min por user (caro) |
| `GET /static/*` | sem limite (servido por CDN) |

### Estratégias quando o limite é atingido

- **Hard reject** com 429, padrão.
- **Soft throttling**: adiciona delay artificial em vez de rejeitar. Útil em alguns casos, mas raro em APIs.
- **Queue and process**: enfileira e processa depois. Útil para jobs assíncronos.
- **Adaptive (load shedding)**: quando o sistema está sobrecarregado, derruba % das requests proativamente. Ver [Release It!](#referências).

### Boas práticas

- **Comece liberal.** Limites apertados demais frustram clientes legítimos.
- **Monitore.** Métrica de "429 emitidos por endpoint" deve ser dashboard padrão.
- **Documente.** APIs públicas precisam ter os limites em docs claros, clientes bem-intencionados querem cumprir.
- **Diferencie planos.** SaaS, planos pagos têm limites maiores. Codifique isso explicitamente.
- **Whitelist crítica.** Health checks, sistemas internos, podem precisar passar por cima do limit.
- **Idempotency-Key conta separado.** Retries com a mesma key não deveriam consumir quota (decisão consciente).

## Quando *não* usar

- **Sistemas internos confiáveis sem multi-tenancy.** Service mesh + retry budget faz mais sentido.
- **APIs com SLA de throughput conhecido e cliente único.** Limite externo (provisioned capacity) já basta.
- **Quando o gargalo está no cliente.** Cliente que bate de menos não precisa de rate limit; precisa de back-pressure.

## Conceitos relacionados

- [API design (REST](./api-design-rest.md)) semântica HTTP de 429.
- [Estratégias de cache](./caching-strategies.md), frequentemente Redis serve aos dois.
- [Tratamento de erros](./error-handling.md), corpo da 429.
- [Background jobs](./background-jobs.md), alternativa para operações pesadas.

## Referências

- **RFC.** [RFC 6585: Additional HTTP Status Codes](https://www.rfc-editor.org/rfc/rfc6585). Define status 429.
- **Draft IETF.** [RateLimit Header Fields for HTTP](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/). Padronização dos headers.
- **Livro.** Michael Nygard, *Release It!*, 2ª ed. (Pragmatic Bookshelf, 2018). Padrões de load shedding e throttling.
- **Artigo.** Stripe, ["Scaling your API with rate limiters"](https://stripe.com/blog/rate-limiters) (2017). Texto referência sobre rate limiting em produção.
- **Artigo.** Cloudflare, ["How we built rate limiting capable of scaling to millions of domains"](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/) (2017).
- **Artigo.** Figma, ["An Alternative Approach to Rate Limiting"](https://www.figma.com/blog/an-alternative-approach-to-rate-limiting/) (2021).
- **Documentação.** [GitHub REST API: Rate limits](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting). Boa referência de docs.
- **Site.** [microservices.io: Rate Limiting](https://microservices.io/patterns/index.html).
