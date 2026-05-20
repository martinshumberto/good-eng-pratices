# Gerenciamento de Estado

> **TL;DR.** Separe **server state** (dados de API (use React Query / TanStack Query) de **client state** (estado da UI) use Redux Toolkit, Zustand ou local). Não use a mesma ferramenta para os dois.

## O quê

Gerenciamento de estado é como uma aplicação organiza, persiste e atualiza dados ao longo do tempo. O insight central da última década: **nem todo estado é igual**.

Dan Abramov (criador do Redux) e Tanner Linsley (criador do React Query) consolidaram a distinção que hoje organiza o ecossistema:

| Tipo | Origem | Características | Ferramenta típica |
|---|---|---|---|
| **Server state** | API remota | Async, fica desatualizado, compartilhado entre usuários | React Query, SWR, Apollo |
| **UI / client state global** | Local (memória) | Síncrono, dono é o cliente, persistente entre rotas | Redux, Zustand, Jotai |
| **Local component state** | Local (memória) | Síncrono, escopo de um componente | `useState`, `useReducer` |
| **Form state** | Local (input) | Síncrono, semântica específica (dirty, touched, validação) | React Hook Form, Formik |
| **URL state** | URL/rota | Síncrono, navegável, compartilhável via link | Router (Next.js, React Router) |

## Por quê

Tratar todos os estados com a mesma ferramenta gera problemas previsíveis:

- **Redux para tudo (incluindo server state):** boilerplate enorme, lógica de cache reinventada, *race conditions* em refetch, sincronização manual.
- **`useState` para tudo (incluindo global):** prop drilling, *re-renders* mal localizados, estado duplicado em vários componentes.
- **Form state em Redux:** cada keystroke vira action; performance ruim, código verbose.

Cada ferramenta tem sua zona de excelência. Misturar derrota o propósito.

> "Most of the global state you might think you need is actually server state."
> (Tanner Linsley)

## Como aplicar

### React Query: server state

[React Query](https://tanstack.com/query) (oficialmente *TanStack Query*) facilita buscar, sincronizar e armazenar em cache dados assíncronos. Resolve:

- **Data fetching** declarativo via `useQuery`.
- **Mutations** com invalidação automática via `useMutation`.
- **Cache inteligente** por query key, com TTL e *stale-while-revalidate*.
- **Refetching automático** em foco da janela, reconexão de rede, intervalo.
- **Sincronização** entre componentes que pedem o mesmo dado.

```ts
// libs/product/src/use-products.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@core/api';
import type { Product } from './types';

export function useProducts(filters: ProductFilters) {
  return useQuery({
    queryKey: ['products', filters],
    queryFn:  () => apiClient.get<Product[]>('/products', { params: filters }).then(r => r.data),
    staleTime: 60_000, // considera fresh por 1min
  });
}

export function usePurchaseProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (productId: string) => apiClient.post('/orders', { productId }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['orders'] }),
  });
}
```

No componente:

```tsx
function ProductList({ filters }: { filters: ProductFilters }) {
  const { data: products, isLoading, isError } = useProducts(filters);

  if (isLoading) return <Spinner />;
  if (isError)   return <ErrorState />;

  return <ul>{products?.map(p => <ProductCard key={p.id} product={p} />)}</ul>;
}
```

### Redux Toolkit: UI state global

[Redux Toolkit (RTK)](https://redux-toolkit.js.org) é a forma moderna de usar Redux: pouco boilerplate, imutabilidade segura (via Immer), tipagem TypeScript-friendly.

Conceitos centrais:

- **Actions**: descrições declarativas de uma intenção de mudança. `{ type: 'cart/itemAdded', payload: {...} }`.
- **Reducers**: funções puras que recebem estado + action e retornam novo estado. Em RTK, escritos com sintaxe "mutável" via Immer.
- **Selectors**: funções que derivam valores do estado. Memoizadas (`createSelector`) para evitar recálculo desnecessário.
- **Middlewares**: funções entre dispatch e reducer. Tratam efeitos colaterais: lógica async, logging, side effects controlados.

```ts
// libs/state/src/cart/slice.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface CartState {
  items: CartItem[];
  coupon: string | null;
}

const slice = createSlice({
  name: 'cart',
  initialState: { items: [], coupon: null } as CartState,
  reducers: {
    itemAdded:   (state, action: PayloadAction<CartItem>) => { state.items.push(action.payload); },
    itemRemoved: (state, action: PayloadAction<string>)   => { state.items = state.items.filter(i => i.id !== action.payload); },
    couponSet:   (state, action: PayloadAction<string>)   => { state.coupon = action.payload; },
  },
});

export const { itemAdded, itemRemoved, couponSet } = slice.actions;
export default slice.reducer;
```

```ts
// libs/state/src/cart/selectors.ts
import { createSelector } from '@reduxjs/toolkit';
import type { RootState } from '../store';

export const selectCart       = (s: RootState) => s.cart;
export const selectCartItems  = (s: RootState) => s.cart.items;
export const selectCartTotal  = createSelector(
  [selectCartItems],
  (items) => items.reduce((sum, item) => sum + item.price * item.quantity, 0),
);
```

### Alternativas a Redux

Redux nem sempre é a melhor escolha para client state global. Avalie:

- **[Zustand](https://github.com/pmndrs/zustand)**: minimalista, sem providers. Boa quando o estado global é simples.
- **[Jotai](https://jotai.org)**: átomos primitivos. Boa para estados granulares e derivações dinâmicas.
- **[Valtio](https://github.com/pmndrs/valtio)**: proxy mutável. Boa para mental model OOP.
- **Context API + `useReducer`**: built-in, sem dependência. OK para estado simples; não escala bem.

### Form state: ferramenta dedicada

[React Hook Form](https://react-hook-form.com) é o padrão de fato. Tracking de `dirty`, `touched`, validação integrada com schemas:

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { LoginInput } from './schemas';

function LoginForm() {
  const { register, handleSubmit, formState: { errors } } = useForm({
    resolver: zodResolver(LoginInput),
  });

  const onSubmit = async (data: LoginInput) => { await login(data); };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}
      <input type="password" {...register('password')} />
      <button type="submit">Login</button>
    </form>
  );
}
```

### URL state: para tudo que é navegável

Filtros de listagem, paginação, tabs ativas, ordenação, preferencialmente na URL:

```tsx
// Next.js App Router
const searchParams = useSearchParams();
const router       = useRouter();

const filter = searchParams.get('filter') ?? 'all';

function setFilter(value: string) {
  const params = new URLSearchParams(searchParams);
  params.set('filter', value);
  router.push(`?${params}`);
}
```

Benefício: o usuário pode compartilhar o link, voltar pelo histórico, e o estado sobrevive ao refresh.

### Heurística: onde mora cada estado?

Pergunte, em ordem:

1. **Vem de uma API?** → React Query.
2. **É navegável (deveria estar num link)?** → URL.
3. **Pertence a um formulário?** → React Hook Form.
4. **É usado por mais de um componente irmão / em rotas diferentes?** → Estado global (Redux/Zustand).
5. **É de um componente só?** → `useState` local.

A maioria do "estado global" de aplicações modernas vira **server state** no React Query. O Redux fica para coisas genuinamente do cliente: auth ativa, tema, sidebar aberta, carrinho offline.

## Quando *não* usar

- **Redux para estado trivial.** Toggle de modal não precisa ir num slice. Use `useState`.
- **React Query para dados que nunca mudam.** Constantes, configuração estática, importe direto.
- **Múltiplas ferramentas globais.** Use uma única convenção (RTK *ou* Zustand) por projeto. Misturar gera fadiga de decisão.

## Conceitos relacionados

- [Design de componentes](./component-design.md)
- [Funções puras](../foundations/pure-functions.md), reducers são funções puras.
- [Modular monorepo](../architecture/modular-monorepo.md), onde encaixa `libs/state`.

## Referências

- **Documentação.** [TanStack Query: Overview](https://tanstack.com/query/latest/docs/framework/react/overview).
- **Documentação.** [Redux Toolkit: Quick Start](https://redux-toolkit.js.org/tutorials/quick-start).
- **Artigo.** Tanner Linsley, ["Practical React Query"](https://tkdodo.eu/blog/practical-react-query) (série de TkDodo, mantenedor da lib).
- **Artigo.** Dan Abramov, ["You Might Not Need Redux"](https://medium.com/@dan_abramov/you-might-not-need-redux-be46360cf367) (2016).
- **Artigo.** Kent C. Dodds, ["Application State Management with React"](https://kentcdodds.com/blog/application-state-management-with-react).
- **Documentação.** [React Hook Form](https://react-hook-form.com/get-started).
