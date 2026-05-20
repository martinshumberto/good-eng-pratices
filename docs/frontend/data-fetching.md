# Data Fetching

> **TL;DR.** Use ferramenta dedicada ao **server state** (React Query, SWR), não escreva `useEffect + fetch` à mão. Trate estados de loading/error explicitamente. Para mutations, use optimistic updates quando seguro. Para listas longas, considere paginação por cursor + infinite scroll.

## O quê

**Data fetching** é o conjunto de práticas para **buscar, exibir e sincronizar** dados de uma API com a UI. É um dos problemas mais complexos do frontend moderno, envolve:

- Estado assíncrono (pending/success/error).
- Cache (não buscar de novo o que já temos).
- Invalidação (quando o dado mudou no servidor).
- Re-fetching (foco da janela, reconexão, polling).
- Race conditions (request mais recente, não o último a chegar).
- Optimistic UI (mostrar mudança antes da confirmação).

Frameworks resolvem 90% disso. Não reinvente.

## Por quê

A abordagem "ingênua", `useEffect + fetch + useState`: tem problemas graves:

```tsx
// ❌ Anti-padrão clássico
function Profile() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetch('/api/user')
      .then(r => r.json())
      .then(setUser)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <Spinner />;
  if (error)   return <ErrorState />;
  return <ProfileView user={user!} />;
}
```

Problemas:

- **Race conditions:** se usuário troca de rota e volta rápido, request antiga pode setar state depois da nova.
- **Sem cache:** monta o componente de novo = nova request.
- **Sem refetch:** dado fica desatualizado.
- **Boilerplate massivo** repetido em todo componente.
- **Sem invalidação cross-componente:** outra parte da UI atualizou usuário, este componente não sabe.

Ferramentas dedicadas resolvem tudo isso por você.

## Como aplicar

### React Query / TanStack Query

[**TanStack Query**](https://tanstack.com/query) é a referência do ecossistema React. Multi-framework: React: Vue, Solid, Svelte.

```tsx
import { useQuery } from '@tanstack/react-query';

function Profile() {
  const { data: user, isLoading, isError, error } = useQuery({
    queryKey: ['user'],
    queryFn: () => fetch('/api/user').then(r => r.json()),
  });

  if (isLoading) return <Spinner />;
  if (isError)   return <ErrorState error={error} />;
  return <ProfileView user={user} />;
}
```

Você ganha de graça:

- **Cache** por `queryKey`.
- **Deduplicação** de requests paralelas.
- **Refetch automático** em foco da janela, reconexão de rede, intervalo.
- **Race-condition safe** (descarta resultado obsoleto).
- **Background revalidation** (mostra cache + atualiza em paralelo).

### SWR

[**SWR**](https://swr.vercel.app) (Vercel), alternativa minimalista. Mesmo conceito (stale-while-revalidate).

```tsx
import useSWR from 'swr';

const fetcher = (url: string) => fetch(url).then(r => r.json());

function Profile() {
  const { data, error, isLoading } = useSWR('/api/user', fetcher);

  if (isLoading) return <Spinner />;
  if (error)     return <ErrorState />;
  return <ProfileView user={data} />;
}
```

Mais simples; menos features. Bom para apps pequenos.

### Quando cada um

| | TanStack Query | SWR |
|---|---|---|
| **API surface** | Maior (`useQuery`, `useMutation`, `useInfiniteQuery`, etc.) | Menor |
| **Mutations** | Primeira classe | Adicionado depois, menos completo |
| **DevTools** | Excelente | Boa |
| **Curva de aprendizado** | Média | Baixa |
| **Multi-framework** | React, Vue, Solid, Svelte | React |

**Default sensato:** TanStack Query. SWR para apps simples ou se prefere API minimalista.

### Mutations

#### Mutation básica

```tsx
import { useMutation, useQueryClient } from '@tanstack/react-query';

function CreateOrderButton() {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (input: CreateOrderInput) =>
      fetch('/api/orders', { method: 'POST', body: JSON.stringify(input) }).then(r => r.json()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });

  return (
    <button
      disabled={mutation.isPending}
      onClick={() => mutation.mutate({ items: [...] })}
    >
      {mutation.isPending ? 'Criando...' : 'Criar pedido'}
    </button>
  );
}
```

`invalidateQueries` faz com que todas as queries com a key `['orders']` busquem de novo.

#### Optimistic updates

Para UX rápido, atualize o cache **antes** da resposta. Reverta se der erro.

```tsx
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    const previous = queryClient.getQueryData(['todos']);

    queryClient.setQueryData(['todos'], (old: Todo[]) =>
      old.map(t => t.id === newTodo.id ? newTodo : t)
    );

    return { previous };   // contexto para rollback
  },
  onError: (err, variables, context) => {
    queryClient.setQueryData(['todos'], context?.previous);   // rollback
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] });   // garantir consistência
  },
});
```

Resultado: UI muda instantaneamente; se falhar, reverte. Excelente UX em features como likes, toggles, edições rápidas.

### Loading states: não esconda erro

Há **três estados** que toda fetch tem:

1. **Pending** (loading).
2. **Success**: com dados.
3. **Error**: com erro.

Trate **explicitamente** cada um. Não ignore erro:

```tsx
// ❌ Erro silencioso
if (isLoading) return <Spinner />;
return <List items={data ?? []} />;   // erro? lista vazia

// ✅ Estados explícitos
if (isLoading) return <Spinner />;
if (isError)   return <ErrorState onRetry={refetch} />;
return <List items={data} />;
```

### Suspense (React)

React Suspense permite tratar loading de forma **declarativa**:

```tsx
function Profile() {
  const { data: user } = useSuspenseQuery({
    queryKey: ['user'],
    queryFn: fetchUser,
  });

  return <ProfileView user={user} />;   // user nunca é null aqui
}

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <ErrorBoundary fallback={<ErrorState />}>
        <Profile />
      </ErrorBoundary>
    </Suspense>
  );
}
```

Loading e error sobem para boundaries pais. Componente fica mais limpo.

### Paginação: cursor > offset

#### Offset (frágil em datasets que mudam)

```
GET /orders?offset=20&limit=10
```

Problema: se entrou registro novo entre páginas, você duplica ou pula linhas.

#### Cursor (estável)

```
GET /orders?after=cur_abc123&limit=10
```

```tsx
const { data, fetchNextPage, hasNextPage } = useInfiniteQuery({
  queryKey: ['orders'],
  queryFn: ({ pageParam = null }) =>
    fetch(`/api/orders?after=${pageParam ?? ''}&limit=20`).then(r => r.json()),
  initialPageParam: null,
  getNextPageParam: (lastPage) => lastPage.nextCursor,
});

return (
  <>
    {data?.pages.map(page =>
      page.items.map(order => <OrderRow key={order.id} order={order} />)
    )}
    {hasNextPage && <button onClick={() => fetchNextPage()}>Carregar mais</button>}
  </>
);
```

### Infinite scroll

Combine `useInfiniteQuery` com `IntersectionObserver`:

```tsx
import { useEffect, useRef } from 'react';

function InfiniteList() {
  const { data, fetchNextPage, hasNextPage } = useInfiniteQuery(/* ... */);
  const observer = useRef<IntersectionObserver>();

  const lastRef = useCallback((node: HTMLElement | null) => {
    if (observer.current) observer.current.disconnect();

    observer.current = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && hasNextPage) fetchNextPage();
    });

    if (node) observer.current.observe(node);
  }, [hasNextPage, fetchNextPage]);

  return (
    <ul>
      {data?.pages.flatMap(p => p.items).map((item, idx, arr) =>
        <li key={item.id} ref={idx === arr.length - 1 ? lastRef : null}>...</li>
      )}
    </ul>
  );
}
```

Ferramentas como [react-intersection-observer](https://github.com/thebuilder/react-intersection-observer) simplificam.

**Considere virtualização** para listas grandes: [TanStack Virtual](https://tanstack.com/virtual), [react-virtuoso](https://virtuoso.dev).

### Polling

Quando você precisa de "tempo real" mas WebSocket é overkill:

```tsx
const { data } = useQuery({
  queryKey: ['notifications'],
  queryFn: fetchNotifications,
  refetchInterval: 30_000,         // 30s
  refetchIntervalInBackground: false,
});
```

`refetchInterval: false` quando não precisa; usuário vai notar.

### Real-time: WebSocket / SSE

Para tempo real **de verdade** (chat, atualizações ao vivo), prefira:

- **WebSocket** (bidirecional, full-duplex).
- **Server-Sent Events (SSE)** (unidirecional, mais simples sobre HTTP).

Combine com React Query para hidratar estado inicial + atualizar via socket:

```tsx
function useChat(roomId: string) {
  const queryClient = useQueryClient();
  const { data } = useQuery({
    queryKey: ['chat', roomId],
    queryFn: () => fetchMessages(roomId),
  });

  useEffect(() => {
    const ws = new WebSocket(`wss://chat.example.com/${roomId}`);
    ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      queryClient.setQueryData(['chat', roomId], (old: Message[]) => [...old, msg]);
    };
    return () => ws.close();
  }, [roomId, queryClient]);

  return data;
}
```

### Prefetching

Carregue dados **antes** do usuário precisar:

```tsx
function ProductCard({ product }: Props) {
  const queryClient = useQueryClient();

  return (
    <Link
      to={`/products/${product.id}`}
      onMouseEnter={() => {
        queryClient.prefetchQuery({
          queryKey: ['product', product.id],
          queryFn: () => fetchProduct(product.id),
        });
      }}
    >
      {product.name}
    </Link>
  );
}
```

Quando usuário clica, dado já está no cache → navegação instantânea.

### GraphQL: alternativa

Para apis GraphQL, ferramentas equivalentes:

- **[Apollo Client](https://www.apollographql.com/docs/react/)**: cache normalizado, mutations, subscriptions.
- **[urql](https://commerce.nearform.com/open-source/urql/)**: alternativa mais leve.
- **[Relay](https://relay.dev)**: Meta, foco em performance, "Relay-style".

Princípios similares; sintaxe diferente.

### Server Components / Server-Side Rendering

Em frameworks como **Next.js (App Router)**, **Remix**, **Astro**, parte do fetch acontece no servidor:

```tsx
// Next.js Server Component
async function Profile() {
  const user = await fetch('https://api.example.com/user', {
    next: { revalidate: 60 },   // ISR
  }).then(r => r.json());

  return <ProfileView user={user} />;
}
```

Sem loading state no client, vem pronto. Quando precisa de interatividade, comparta dados via Server Actions / props para componentes client.

### Anti-padrões

#### Fetch em `useEffect` ad-hoc

Já discutido. Use ferramenta.

#### Cascading requests

```tsx
const { data: user } = useQuery({ queryKey: ['user'], queryFn: fetchUser });
const { data: orders } = useQuery({
  queryKey: ['orders', user?.id],
  queryFn: () => fetchOrders(user.id),
  enabled: !!user,   // espera user carregar
});
```

Dois round-trips sequenciais = latência alta. Onde possível, faça **uma única chamada** no backend que retorna user + orders.

#### Cache muito longo / muito curto

Default do React Query é razoável (5min stale, ~5min em cache). Ajuste por dado:

```tsx
useQuery({
  queryKey: ['user-config'],
  queryFn: fetchConfig,
  staleTime: 60 * 60 * 1000,   // 1h, config muda raramente
});
```

#### Não tratar offline

Usuário em metrô. Cache ajuda. Veja `networkMode: 'offlineFirst'` (React Query).

#### Setar muitos `refetchInterval`

Polling em vários componentes = N requests por segundo. Consolide.

## Quando *não* usar (ferramenta dedicada)

- **App super-simples** com 1–2 endpoints sem cache complexo.
- **Static site** sem dados dinâmicos.
- **Frameworks que já cobrem** (Next.js Server Components, Remix loaders).

Para qualquer app real com várias telas e dados, ferramenta dedicada é higiene.

## Conceitos relacionados

- [Gerenciamento de estado](./state-management.md), server vs client state.
- [Design de componentes](./component-design.md).
- [Performance e Web Vitals](./performance-web-vitals.md).
- [API design (REST](../backend/api-design-rest.md)) paginação, idempotência.
- [Os três pilares](../observability/three-pillars.md), observabilidade do client.

## Referências

- **Documentação.** [TanStack Query: Overview](https://tanstack.com/query/latest/docs/framework/react/overview).
- **Documentação.** [SWR](https://swr.vercel.app).
- **Artigo.** Tanner Linsley, ["Practical React Query"](https://tkdodo.eu/blog/practical-react-query). Série TkDodo, referência didática.
- **Artigo.** Kent C. Dodds, ["Stop using isLoading booleans"](https://kentcdodds.com/blog/stop-using-isloading-booleans). Estados explícitos.
- **Artigo.** Dan Abramov, ["A Complete Guide to useEffect"](https://overreacted.io/a-complete-guide-to-useeffect/). Por que useEffect para fetch é difícil.
- **Documentação.** [Apollo Client](https://www.apollographql.com/docs/react/).
- **Documentação.** [Relay](https://relay.dev/docs/).
- **Documentação.** [Next.js: Data Fetching](https://nextjs.org/docs/app/building-your-application/data-fetching).
- **Documentação.** [Remix: Data Loading](https://remix.run/docs/en/main/discussion/data-flow).
