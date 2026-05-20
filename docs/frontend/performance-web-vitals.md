# Performance e Core Web Vitals

> **TL;DR.** Google mede performance via **Core Web Vitals**: **LCP** (rapidez do principal conteúdo), **INP** (responsividade a interações), **CLS** (estabilidade visual). Otimize com: imagens responsivas + lazy loading, code splitting, minimizar JS na main thread, evitar layout shifts. Meça em produção com RUM, não só em laboratório.

## O quê

**Core Web Vitals** ([web.dev/vitals](https://web.dev/vitals/)) são as métricas que o Google usa para avaliar UX. Estão integradas ao ranking de busca. As três principais:

| Métrica | O que mede | Alvo (bom) |
|---|---|---|
| **LCP**: Largest Contentful Paint | Tempo até o maior elemento de conteúdo renderizar | < 2.5s |
| **INP**: Interaction to Next Paint | Latência de interação (cliques, teclados) | < 200ms |
| **CLS**: Cumulative Layout Shift | Soma de deslocamentos visuais inesperados | < 0.1 |

**INP** substituiu FID (First Input Delay) em março de 2024 como métrica oficial.

Métricas complementares (não-Core, mas valiosas):

- **TTFB**: Time To First Byte (latência de servidor).
- **FCP**: First Contentful Paint (primeiro pixel pintado).
- **TTI**: Time To Interactive (quando a página fica utilizável).

## Por quê

Performance ruim tem **impactos diretos**:

- **Conversão.** Amazon reportou que 100ms de latência custa 1% de venda.
- **Bounce rate.** Google: 53% dos usuários mobile abandonam se carregamento > 3s.
- **SEO.** Web Vitals afetam ranking desde 2021.
- **Acessibilidade.** Conexões lentas (3G em países em desenvolvimento) sofrem desproporcionalmente.
- **Bateria / dados.** Em mobile, JS pesado consome bateria e plano de dados do usuário.

> "Performance is a feature. The 'cost' of performance is borne by the user, not the developer."
> (Comum em discussões da web.dev)

## Como aplicar

### LCP: Largest Contentful Paint

Tempo para o maior elemento visível (geralmente hero image, headline, banner) terminar de renderizar.

**Causas comuns de LCP ruim:**

- TTFB alto (servidor lento).
- Render-blocking CSS/JS.
- Imagens não otimizadas.
- Web fonts bloqueando texto.
- Client-side rendering de tudo (vê tela em branco até JS carregar).

#### Como melhorar

##### Servidor rápido (TTFB)

- **CDN** para assets e HTML.
- **Edge functions** / SSR em CDN edge (Cloudflare Workers, Vercel Edge).
- **Cache HTTP** agressivo.
- Banco indexado, queries rápidas (ver [caching](../backend/caching-strategies.md)).

##### Eliminar render-blocking

```html
<!-- ❌ CSS bloqueia render -->
<link rel="stylesheet" href="huge.css" />

<!-- ✅ Crítico inline, resto async -->
<style>/* CSS crítico above-the-fold */</style>
<link rel="preload" href="rest.css" as="style" onload="this.rel='stylesheet'" />
```

```html
<!-- ❌ JS bloqueia render -->
<script src="app.js"></script>

<!-- ✅ defer (espera HTML parse, executa em ordem) -->
<script src="app.js" defer></script>

<!-- ✅ async (executa assim que carrega) -->
<script src="analytics.js" async></script>
```

##### Imagens responsivas

```html
<img
  src="hero-1200.jpg"
  srcset="hero-400.jpg 400w, hero-800.jpg 800w, hero-1200.jpg 1200w"
  sizes="(max-width: 600px) 100vw, 1200px"
  alt="..."
  loading="eager"
  fetchpriority="high"
  width="1200"
  height="600"
/>
```

- `srcset`: browser escolhe a versão certa por tamanho.
- `sizes`: informa quanto espaço a imagem vai ocupar.
- `fetchpriority="high"`: prioriza download.
- `width`/`height`: reserva espaço (previne CLS).

##### Modern formats

- **AVIF** (~50% menor que JPEG, suporte amplo).
- **WebP** (~30% menor, suporte mais antigo).
- **JPEG/PNG** apenas como fallback.

```html
<picture>
  <source srcset="hero.avif" type="image/avif" />
  <source srcset="hero.webp" type="image/webp" />
  <img src="hero.jpg" alt="..." />
</picture>
```

Em frameworks: Next.js `<Image>`, Astro `<Image>`, Nuxt `<NuxtImage>` fazem isso automaticamente.

##### Preload do LCP

```html
<link rel="preload" as="image" href="hero.avif" type="image/avif" fetchpriority="high" />
```

##### Web fonts

```css
/* font-display: swap mostra fallback até a font carregar */
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter.woff2') format('woff2');
  font-display: swap;
}
```

Ou use `optional` para sumir com fallback se a font não carregar rápido.

Otimize:

- Inclua só os pesos/estilos que usa.
- Preload da font:
  ```html
  <link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin />
  ```

### INP: Interaction to Next Paint

Latência entre interação do usuário (clique, tecla) e a próxima atualização visual.

Métrica de "main thread responsiveness". JS pesado bloqueia a thread principal → INP ruim.

**Causas comuns:**

- Tasks longas (> 50ms) bloqueando a main thread.
- Event handlers caros.
- Re-renders pesados (React inteiro re-renderiza).

#### Como melhorar

##### Quebre tasks longas

```ts
// ❌ Trava a thread
function processItems(items: Item[]) {
  for (const item of items) {
    expensiveOperation(item);   // 10s no total
  }
}

// ✅ Cede ao browser entre itens
async function processItems(items: Item[]) {
  for (const item of items) {
    expensiveOperation(item);
    await scheduler.yield?.() ?? new Promise(r => setTimeout(r, 0));
  }
}
```

API moderna: [`scheduler.yield()`](https://developer.chrome.com/blog/introducing-scheduler-yield-origin-trial) (Chrome).

##### Web Workers para trabalho pesado

CPU intensivo? Use Worker:

```ts
const worker = new Worker(new URL('./heavy.worker.ts', import.meta.url));
worker.postMessage({ data });
worker.onmessage = (e) => setResult(e.data);
```

Encripta/decripta, parseia, calcula, qualquer coisa pesada que não toca DOM vai pro Worker.

##### Memoização e renders custosos

React:

```tsx
// useMemo para cálculo caro
const sortedItems = useMemo(() => items.sort(/* ... */), [items]);

// memo para componentes com props estáveis
const ItemRow = memo(({ item }: Props) => <li>{item.name}</li>);
```

Cuidado: não memoize tudo. Memoização **tem custo** (comparação de deps).

##### Virtualização para listas longas

Renderizar 10.000 linhas trava qualquer thread. Use virtualização:

- [TanStack Virtual](https://tanstack.com/virtual).
- [react-virtuoso](https://virtuoso.dev).
- [react-window](https://github.com/bvaughn/react-window).

Renderiza só o que está visível + buffer.

##### Debounce / throttle de inputs

```tsx
import { useDebouncedCallback } from 'use-debounce';

function Search() {
  const [query, setQuery] = useState('');
  const debouncedSearch = useDebouncedCallback((q: string) => {
    fetchResults(q);
  }, 300);

  return (
    <input
      value={query}
      onChange={(e) => {
        setQuery(e.target.value);
        debouncedSearch(e.target.value);
      }}
    />
  );
}
```

##### React 18: `useTransition`, `useDeferredValue`

```tsx
const [isPending, startTransition] = useTransition();

function handleChange(value: string) {
  setQuery(value);                 // urgente
  startTransition(() => {
    setResults(searchExpensive(value));   // pode esperar
  });
}
```

`useDeferredValue` para o mesmo conceito com prop.

### CLS: Cumulative Layout Shift

Mede deslocamentos visuais inesperados, quando algo "pula" durante o carregamento.

**Causas comuns:**

- Imagens sem `width`/`height` definidos.
- Ads/embeds que carregam tarde e empurram conteúdo.
- Fonts swapping (fonte fallback diferente de tamanho).
- Conteúdo inserido dinamicamente acima do que o usuário já está vendo.
- Animações com `top`/`left` em vez de `transform`.

#### Como melhorar

##### Sempre defina dimensões em imagens e vídeos

```html
<img src="..." width="800" height="600" alt="..." />
<video width="800" height="450" src="..."></video>
```

Browser reserva espaço **antes** de baixar a imagem.

##### Para containers de tamanho dinâmico

```css
.video-container {
  aspect-ratio: 16 / 9;   /* reserva espaço pela proporção */
}
```

##### Fonts: minimize swap

```css
@font-face {
  font-family: 'Inter';
  src: url(/inter.woff2);
  font-display: swap;
  size-adjust: 100.5%;       /* compensa diferença de tamanho */
  ascent-override: 90%;
  descent-override: 22%;
}
```

[Font Style Matcher](https://meowni.ca/font-style-matcher/) calcula esses overrides.

##### Conteúdo inserido dinamicamente

- Insira **abaixo** da viewport quando possível.
- Use placeholders (skeletons) com mesma altura.
- `min-height` em containers.

##### Animações via `transform`

```css
/* ❌ Causa reflow */
.modal { top: 0; }
.modal.open { top: 50px; }

/* ✅ Não causa reflow */
.modal { transform: translateY(0); }
.modal.open { transform: translateY(50px); }
```

`transform` e `opacity` são animados pela GPU, sem layout shift.

### Code splitting

Não envie JS que o usuário não vai usar **agora**. Divida.

```tsx
// React.lazy + Suspense
const AdminPanel = lazy(() => import('./AdminPanel'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <Routes>
        <Route path="/admin" element={<AdminPanel />} />
      </Routes>
    </Suspense>
  );
}
```

Bundlers (Vite, Webpack, esbuild) fazem o split automaticamente em `import()`.

**Heurísticas:**

- **Por rota**: cada página/rota é um chunk.
- **Por feature pesada**: admin, editor, dashboard.
- **Bibliotecas grandes**: carregue `chart.js` apenas se for renderizar gráfico.

### Otimizar bundle

Use **bundle analyzer** para ver o que tem dentro:

```bash
# Vite
npm install --save-dev rollup-plugin-visualizer

# Next.js
ANALYZE=true npm run build
```

Procure:

- **Bibliotecas duplicadas.**
- **Locales completas** quando você só usa uma.
- **Tree-shaking falhando** (imports `import * as X`).
- **Moment.js** com todas as locales (use `dayjs` ou `date-fns`).
- **Lodash** inteiro (use `lodash-es` + imports específicos, ou `radash`).

### Cache HTTP: não esqueça

```http
Cache-Control: public, max-age=31536000, immutable
```

Para assets versionados (`/static/abc123.js`). Versão muda → URL muda → cache invalidado naturalmente.

Para HTML:

```http
Cache-Control: no-cache
```

(Always revalidate, but allow caching with ETag.)

### Resource Hints

```html
<!-- DNS resolve antecipado -->
<link rel="dns-prefetch" href="https://api.example.com" />

<!-- TCP+TLS handshake antecipado -->
<link rel="preconnect" href="https://api.example.com" />

<!-- Carrega recurso crítico antes do parser pedir -->
<link rel="preload" href="hero.avif" as="image" />

<!-- Carrega recurso para próxima navegação (low priority) -->
<link rel="prefetch" href="/next-page-data.json" />
```

Use com **moderação**: preconnect demais consome recursos.

### Server-side / Edge rendering

Frameworks modernos enviam HTML pronto:

- **Next.js** App Router (RSC + ISR).
- **Remix** (Server Components style).
- **Astro** (Islands architecture, JS só onde precisa).
- **Qwik** (resumability, quase zero JS no client inicialmente).

**SSR/SSG > CSR para LCP** em quase todos os casos. Use CSR (SPA pura) só quando faz sentido (admin tools internas, app tipo Figma).

### Imagens com framework

Use componentes de imagem dos frameworks:

```tsx
// Next.js
import Image from 'next/image';

<Image src="/hero.jpg" alt="..." width={1200} height={600} priority />
```

Fazem automaticamente:

- Geração de tamanhos múltiplos.
- AVIF/WebP com fallback.
- Lazy loading.
- `width`/`height` para previnir CLS.

### Medição: RUM > lab

**Lab data** (Lighthouse local) é útil mas **não reflete usuários reais**:

- Sua máquina é rápida.
- Sua rede é boa.
- Você não tem 30 abas abertas.

**RUM** (Real User Monitoring) captura dados de usuários reais:

```ts
// web-vitals library
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals';

onCLS(metric => sendToAnalytics(metric));
onINP(metric => sendToAnalytics(metric));
onLCP(metric => sendToAnalytics(metric));
```

Envie para analytics próprio ou serviços:

- **[Vercel Analytics](https://vercel.com/analytics)**.
- **[Cloudflare Web Analytics](https://www.cloudflare.com/web-analytics/)**.
- **[SpeedCurve](https://www.speedcurve.com)**.
- **[Sentry Performance](https://sentry.io/for/performance/)**.
- **[Datadog RUM](https://www.datadoghq.com/product/real-user-monitoring/)**.

Olhe **percentis** (p75, p95), não médias. Usuário no p95 é experiência real para milhões.

### Performance budgets

Defina **limites** que não podem ser violados sem decisão consciente:

```yaml
# .lighthouserc.yml
assert:
  assertions:
    metrics:largest-contentful-paint: ["error", { maxNumericValue: 2500 }]
    metrics:interaction-to-next-paint: ["error", { maxNumericValue: 200 }]
    metrics:cumulative-layout-shift: ["error", { maxNumericValue: 0.1 }]
    resource-summary:script:size: ["error", { maxNumericValue: 200000 }]
```

CI bloqueia PR que estoure. Ferramentas: [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci), [Calibre](https://calibreapp.com), [SpeedCurve](https://www.speedcurve.com).

### Anti-padrões

#### "Optimize on my machine"

Otimizar com base no que **você** vê em desktop com fibra é enganoso. Throttle para 3G no DevTools; teste em devices reais lentos.

#### Lazy loading everything

`loading="lazy"` na imagem hero atrasa LCP. Use `eager` + `fetchpriority="high"` no LCP.

#### Cargo cult de "every framework"

Adicionar `<link rel="preconnect">` para 50 domínios não acelera nada, atrasa.

#### Bundle minificado mas com JS desnecessário

Você comprimiu de 800KB para 600KB. Cliente ainda baixa 600KB. **Reduza JS antes de minificar**.

#### Performance só na primeira página

LCP da home é bom, mas usuários ficam horas no app interno lento. Olhe **todas** as views.

## Quando *não* usar (todas as técnicas)

- **Página administrativa que 5 pessoas usam.** Performance excessiva não vale o esforço.
- **Quando outras prioridades são mais críticas.** Acessibilidade básica > otimização avançada.

Mas para qualquer site público, performance é UX. Não opcional.

## Conceitos relacionados

- [Design de componentes](./component-design.md).
- [Data fetching](./data-fetching.md), prefetching e cache.
- [Acessibilidade](./accessibility.md), performance impacta a11y.
- [Caching strategies](../backend/caching-strategies.md), server-side cache.

## Referências

- **Site.** [web.dev/vitals](https://web.dev/vitals/). Hub oficial Google.
- **Site.** [web.dev: Learn Performance](https://web.dev/learn/performance). Curso completo.
- **Site.** [Core Web Vitals](https://web.dev/explore/learn-core-web-vitals). Aprofundamento.
- **Documentação.** [web-vitals library](https://github.com/GoogleChrome/web-vitals). Medição em produção.
- **Site.** [PageSpeed Insights](https://pagespeed.web.dev). Auditoria gratuita.
- **Documentação.** [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci).
- **Livro.** Tammy Everts, Tim Kadlec, *Time Is Money* (O'Reilly, 2016). Custo de performance ruim.
- **Livro.** Steve Souders, *High Performance Web Sites* (O'Reilly, 2007). Texto fundador.
- **Artigo.** Addy Osmani, ["The Cost of JavaScript"](https://medium.com/@addyosmani/the-cost-of-javascript-in-2018-7d8950fbb5d4). Atualizado anualmente.
- **Site.** [web.dev: INP](https://web.dev/inp/). Mudança de FID para INP.
- **Artigo.** [Etsy: Why Performance Matters](https://www.etsy.com/codeascraft/web-performance). Caso real.
