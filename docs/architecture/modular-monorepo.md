# Modular Monorepo

> **TL;DR.** Um repositório, vários projetos isolados. Cada lib resolve uma responsabilidade clara, com suas próprias regras de build e teste. Ferramentas como Nx tornam esse modelo viável em escala.

## O quê

**Monorepo** é o padrão de manter múltiplos projetos relacionados em um único repositório de código. **Modular** significa que dentro do repositório os projetos são *bibliotecas independentes* com fronteiras claras, não um único codebase entrelaçado.

Casos famosos: Google, Facebook, Microsoft (Windows), Babel, Angular, React (Meta), Nx (workspace tools).

Ferramentas populares para monorepo modular:

- **[Nx](https://nx.dev)**: orquestrador com grafo de dependências, build cache distribuído, geradores.
- **[Turborepo](https://turbo.build)**: foco em cache de build.
- **[pnpm workspaces](https://pnpm.io/workspaces)** / **[Yarn workspaces](https://classic.yarnpkg.com/lang/en/docs/workspaces/)**: primitivos sem orquestração.
- **[Bazel](https://bazel.build)**: para casos grandes, multi-linguagem.
- **[Lerna](https://lerna.js.org)**: versionamento e publicação.

Este doc usa **Nx** como referência, mas as ideias se aplicam a qualquer ferramenta.

## Por quê

Comparado a **muitos repositórios**:

| Aspecto | Monorepo | Polyrepo |
|---|---|---|
| **Refatoração cross-cutting** | Trivial (uma PR atravessa libs | Difícil) sincronizar várias PRs |
| **Versionamento de libs internas** | Tag global ou per-package via Changesets | Cada repo tem o seu, sync vira projeto |
| **Visibilidade** | Tudo num lugar; navegação simples | Engenheiros precisam saber onde achar |
| **CI** | Pode rodar só o que foi afetado | Cada repo dispara o seu CI |
| **Ownership** | CODEOWNERS por pasta | Permissão por repo (mais simples) |
| **Onboarding** | Um clone, um setup | Vários clones, vários setups |

O ganho do **modular**: o repositório único não vira monolito de código. Cada lib é **isolável**: testável, construível e (se necessário) extraível.

> "If you're building a non-trivial application, you have two choices: monolithic monorepo or polyrepo of polyrepos."
> (Jeff Cross (Nrwl/Nx co-founder))

## Como aplicar

### Estrutura base

```
.
├── apps/
│   ├── web/
│   ├── mobile/
│   └── admin/
└── libs/
    ├── api/
    ├── state/
    ├── product/     ← lib de domínio
    ├── checkout/    ← lib de domínio
    └── utils/
```

- **`apps/`**: aplicações que consomem libs. Em geral pouco código próprio, combinam libs.
- **`libs/`**: bibliotecas modulares. Cada pasta é um projeto independente.

Adicione uma lib `libs/<domain>` para cada **bounded context** relevante (ver [DDD](./domain-driven-design.md)).

### Tipos de libs (categorização Nx)

Nx sugere classificar libs em quatro categorias:

| Tipo | Propósito | Pode depender de |
|---|---|---|
| **Feature** | Implementa uma feature (lida com estado, integrações, UI da feature) | `ui`, `data-access`, `util` |
| **UI** | Componentes apresentacionais puros | `util` |
| **Data-access** | Acesso a API/dados externos | `util` |
| **Util** | Utilitários puros, sem dependência externa | (ninguém) |

A regra de dependência (uma feature pode usar uma util, mas util não usa feature) é **enforced** por linting:

```jsonc
// .eslintrc, exemplo de regra de boundaries
{
  "@nx/enforce-module-boundaries": [
    "error",
    {
      "depConstraints": [
        { "sourceTag": "type:util",        "onlyDependOnLibsWithTags": ["type:util"] },
        { "sourceTag": "type:ui",          "onlyDependOnLibsWithTags": ["type:ui", "type:util"] },
        { "sourceTag": "type:data-access", "onlyDependOnLibsWithTags": ["type:util"] },
        { "sourceTag": "type:feature",     "onlyDependOnLibsWithTags": ["*"] }
      ]
    }
  ]
}
```

### Comandos típicos

```bash
# Gerar uma nova lib
npx nx g @nx/react:lib product --tags=type:feature,scope:product
npx nx g @nx/js:lib    utils  --tags=type:util,scope:shared

# Rodar testes só do que mudou
nx affected --target=test  --base=main

# Build incremental: só rebuilda o que mudou
nx affected --target=build --base=main

# Visualizar o grafo de dependências
nx graph
```

`affected` é o ganho central de monorepo em CI: PR que mexe só em uma lib não dispara build do repositório inteiro.

### Bibliotecas comuns (template inicial)

#### `libs/api`

Cliente HTTP e definições de chamadas a APIs. Independente de UI e de estado global.

```ts
// libs/api/src/client.ts
import axios from 'axios';

export const apiClient = axios.create({
  baseURL: process.env.API_BASE_URL,
  timeout: 10_000,
});

apiClient.interceptors.request.use((config) => {
  const token = getTokenFromStore();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
```

#### `libs/state`

Gerenciamento de estado global. Configuração de Redux store, persistor, queryClient.

```ts
// libs/state/src/store.ts
import { configureStore } from '@reduxjs/toolkit';
import { persistStore, persistReducer } from 'redux-persist';

export const store = configureStore({ /* ... */ });
export const persistor = persistStore(store);
```

Regras:

- Sem componentes React aqui, só lógica de estado.
- Pode depender de `api` se necessário, mas `api` permanece independente.

#### `libs/<domain>` (ex.: `libs/product`)

Lógica do domínio. Tipos, hooks, regras.

```ts
// libs/product/src/use-products.ts
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@core/api';
import type { Product } from './types';

export function useProducts() {
  return useQuery<Product[]>({
    queryKey: ['products'],
    queryFn:  () => apiClient.get<Product[]>('/products').then(r => r.data),
  });
}
```

#### `libs/utils`

Funções puras genéricas. **Sem hooks React, sem dependências de domínio.**

```ts
// libs/utils/src/format-currency.ts
export function formatCurrency(amount: number, locale = 'pt-BR'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency', currency: 'BRL',
  }).format(amount);
}
```

Cuidado: utils tende a virar [depósito de helpers](../foundations/code-smells.md#o-anti-padrão-helpers--utils). Divida por contexto explícito assim que cresce.

### Inicialização nas apps

A app consome as libs:

```tsx
// apps/web/src/main.tsx
import { queryClient, store, persistor } from '@core/state';
import { Provider as ReduxProvider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { QueryClientProvider } from '@tanstack/react-query';

function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <ReduxProvider store={store}>
        <PersistGate loading={null} persistor={persistor}>
          {children}
        </PersistGate>
      </ReduxProvider>
    </QueryClientProvider>
  );
}
```

```tsx
// apps/web/src/pages/products.tsx
import { useProducts } from '@core/product';

export function ProductsPage() {
  const { data: products, isLoading } = useProducts();
  if (isLoading) return <p>Carregando...</p>;
  return <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>;
}
```

### Versionamento

Duas estratégias quando libs são publicadas:

#### Fixed/locked versioning
Todas as libs sobem juntas. Simples. Útil quando elas evoluem em conjunto.

#### Independent versioning (Changesets)
Cada lib tem sua versão. Mais complexo, mas dá liberdade.

Com [Changesets](https://github.com/changesets/changesets):

```bash
# 1. Após mudança
pnpx changeset
# Selecione lib(s) afetada(s) e tipo (patch/minor/major).

# 2. Verifique
nx affected --target=test  --base=main
nx affected --target=build --base=main

# 3. Versione
pnpx changeset version

# 4. Publique
pnpx changeset publish
```

Detalhes em [Versionamento de API](../backend/api-versioning.md).

## Quando *não* usar

- **Equipes pequenas com um único projeto.** O overhead de configurar monorepo não se paga até a 2ª ou 3ª app/lib.
- **Quando os projetos têm ciclos de release muito diferentes.** Mobile vs. web vs. CLI publicando em momentos completamente desconectados. Polyrepo pode ser mais simples.
- **Tooling incompatível.** Se as linguagens / build systems não conversam (ex.: Java + iOS Swift + JS), Bazel pode ser overkill. Polyrepos com integração via artifact repository é mais barato.

## Conceitos relacionados

- [Domain-Driven Design](./domain-driven-design.md), *bounded contexts* são candidatos naturais a libs.
- [Versionamento de API](../backend/api-versioning.md), para libs publicadas.
- [Code smells: Helpers/Utils](../foundations/code-smells.md#o-anti-padrão-helpers--utils).

## Referências

- **Livro.** Victor Savkin & Jeff Cross, *Monorepos in the Wild* (Nrwl, 2020). Disponível em [monorepo.tools](https://monorepo.tools).
- **Site.** [monorepo.tools](https://monorepo.tools), comparação de ferramentas.
- **Artigo.** Rachel Potvin & Josh Levenberg, ["Why Google Stores Billions of Lines of Code in a Single Repository"](https://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/) (Communications of the ACM, 2016).
- **Artigo.** Dan Luu, ["Advantages of monorepos"](https://danluu.com/monorepo/).
- **Documentação.** [Nx Documentation](https://nx.dev/concepts/more-concepts/why-monorepos).
