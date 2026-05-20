# Design de Componentes

> **TL;DR.** Cada componente vive na sua pasta com index, estilos e testes próximos. Organize por domínio (feature), não por tipo. Exponha uma API pública mínima e clara.

## O quê

Design de componentes é o conjunto de decisões sobre:

- **Granularidade**: quão pequeno cada componente deve ser?
- **Encapsulamento**: o que fica exposto, o que é interno?
- **Organização**: onde cada arquivo mora?
- **Composição**: como componentes se combinam?

Aplica-se primariamente a React/Vue/Svelte/Solid, mas os princípios gerais (encapsulamento, organização por domínio, API mínima) valem para qualquer modelo de UI baseado em componentes.

## Por quê

Componentes mal projetados sintomatizam três problemas que crescem com a base:

1. **Acoplamento espalhado**: componentes que conhecem detalhes uns dos outros tornam mudança custosa.
2. **Navegação difícil**: onde fica o estilo desse botão? Em `styles/buttons.css`? `components/Button/Button.module.css`? `theme/colors.ts`?
3. **API pública volátil**: props mudando todo sprint, breaking changes acidentais.

Design consistente resolve antes desses sintomas aparecerem.

## Como aplicar

### Organização por domínio (feature), depois por tipo

```
src/
├─ library/                    ← lógica de domínio (hooks, types, API)
│  ├─ profile/
│  ├─ checkout/
│  └─ flights/
└─ ui/
   ├─ components/              ← componentes reutilizáveis genéricos
   │  ├─ Button/
   │  ├─ Modal/
   │  └─ Input/
   ├─ checkout/                ← UI da feature checkout
   │  ├─ CartSummary/
   │  └─ PaymentForm/
   ├─ profile/
   │  ├─ ProfileHeader/
   │  └─ AvatarEditor/
   └─ flights/
      ├─ ProductCard/
      └─ ProductFilters/
```

Princípios:

- **Por feature primeiro.** Mudar a feature `checkout` mexe em uma pasta só.
- **Componentes verdadeiramente reutilizáveis** ficam em `ui/components/`. "Verdadeiramente reutilizável" = usado em pelo menos 3 features.
- **Não force reuso prematuro.** Um componente que parece reutilizável mas é usado em só um lugar não precisa subir para `ui/components/`.

### Componente em sua pasta

Cada componente tem **sua própria pasta**, com tudo que precisa:

```
src/ui/components/Button/
├─ index.ts            ← API pública (re-exporta o componente)
├─ Button.tsx          ← implementação
├─ Button.test.tsx     ← testes
├─ Button.stories.tsx  ← Storybook (se aplicável)
├─ styles.ts           ← estilos (styled-components, CSS modules, etc.)
└─ types.ts            ← tipos exclusivos do componente
```

Vantagens:

- **Encapsulamento.** Tudo do `Button` está numa pasta. Excluir o componente = excluir a pasta.
- **Localização eficiente.** Para entender o componente, basta abrir a pasta, sem caça pelo projeto.
- **API explícita.** O `index.ts` controla o que é exportado. Detalhes internos (`styles.ts`, tipos de helpers) ficam invisíveis fora da pasta.

```ts
// src/ui/components/Button/index.ts
export { Button } from './Button';
export type { ButtonProps } from './types';
// styles.ts NÃO é re-exportado, é interno
```

### Tamanho: pequeno e focado

Heurística: **um componente faz uma coisa**. Se você precisa explicar com "e" o que o componente faz, ele provavelmente deveria ser dois.

```tsx
// ❌ ProductCard faz demais
function ProductCard({ product }: Props) {
  // 200 linhas: imagem, preço, detalhes, botão de compra, modal de seleção, ...
}

// ✅ ProductCard compõe peças menores
function ProductCard({ product }: Props) {
  return (
    <Card>
      <ProductImage src={product.imageUrl} />
      <ProductSummary product={product} />
      <ProductPrice amount={product.price} />
      <PurchaseButton productId={product.id} />
    </Card>
  );
}
```

Cada subcomponente é entendido isoladamente e testável separadamente.

### Tipos de componente

Mental model útil:

- **Presentational**: recebe props, renderiza UI. Sem lógica de domínio nem efeitos colaterais. Trivial de testar e reusar.
- **Container / connected**: busca dados, conecta a stores, lida com efeitos. Compõe presentational components.

Não é uma divisão rígida, mas ajuda a manter componentes presentational livres de detalhes técnicos (banco, API, store):

```tsx
// ✅ Apresentação pura, testável sem mocks
function ProductCardView({ product, onBuy }: { product: Product; onBuy: () => void }) {
  return (
    <Card>
      <h3>{product.name}</h3>
      <p>{product.price}</p>
      <Button onClick={onBuy}>Comprar</Button>
    </Card>
  );
}

// ✅ Container, conecta dados e ações
function ProductCard({ productId }: { productId: string }) {
  const { data: product } = useProduct(productId);
  const buy = usePurchaseProduct();

  if (!product) return null;
  return <ProductCardView product={product} onBuy={() => buy.mutate(product.id)} />;
}
```

### API mínima e explícita

Componentes públicos devem expor o mínimo necessário. Mais props = mais combinações = mais bugs.

```tsx
// ❌ API gorda, todas as combinações precisam ser pensadas
<Button
  primary={false}
  secondary={true}
  danger={false}
  large={true}
  small={false}
  rounded={true}
  outlined={false}
  loading={false}
  disabled={false}
/>

// ✅ API enxuta, papéis discriminados
<Button variant="secondary" size="large">Salvar</Button>
```

Outra heurística: **prefira composição sobre configuração**. Em vez de uma `Card` com 20 props para customizar header/body/footer, ofereça subcomponentes:

```tsx
<Card>
  <Card.Header>Título</Card.Header>
  <Card.Body>...</Card.Body>
  <Card.Footer><Button>OK</Button></Card.Footer>
</Card>
```

### Nomes

- **PascalCase para componentes** (`ProductCard`).
- **camelCase para hooks e funções** (`useProducts`, `formatPrice`).
- **Nome do arquivo = nome do componente.** `ProductCard.tsx` exporta `ProductCard`.
- **Pasta = nome do componente.** `ProductCard/index.ts` reexporta.

### Props patterns úteis

- **Children como render prop** quando o consumidor precisa controlar parte da estrutura:

  ```tsx
  <List items={users}>
    {(user) => <UserCard key={user.id} user={user} />}
  </List>
  ```

- **Compound components** para APIs declarativas (Tabs, Accordion, Menu):

  ```tsx
  <Tabs defaultValue="profile">
    <Tabs.List>
      <Tabs.Tab value="profile">Perfil</Tabs.Tab>
      <Tabs.Tab value="settings">Configurações</Tabs.Tab>
    </Tabs.List>
    <Tabs.Content value="profile">...</Tabs.Content>
    <Tabs.Content value="settings">...</Tabs.Content>
  </Tabs>
  ```

- **`forwardRef`** quando o componente envolve um elemento HTML e o consumidor pode precisar do ref:

  ```tsx
  export const Input = forwardRef<HTMLInputElement, InputProps>((props, ref) => (
    <input ref={ref} {...props} className="..." />
  ));
  ```

## Quando *não* usar

- **Pasta-por-componente em componentes triviais.** Um helper de uma linha não precisa de pasta. Critério prático: se tem `styles`, `tests`, ou mais de 50 linhas, vire pasta.
- **Compound components para componentes simples.** Um `Card` sem variação interna não precisa de `Card.Header`. Apenas children + estilo já basta.
- **Separar container/presentational à força.** Para componentes pequenos com pouca lógica, juntar é mais legível.

## Conceitos relacionados

- [Gerenciamento de estado](./state-management.md), onde os containers se conectam.
- [Modular monorepo](../architecture/modular-monorepo.md), onde libs de UI vivem.
- [Code smells: Helpers/Utils](../foundations/code-smells.md#o-anti-padrão-helpers--utils).

## Referências

- **Livro.** Brad Frost, *Atomic Design* (2016). Disponível em [atomicdesign.bradfrost.com](https://atomicdesign.bradfrost.com).
- **Artigo.** Dan Abramov, ["Presentational and Container Components"](https://medium.com/@dan_abramov/smart-and-dumb-components-7ca2f9a7c7d0) (2015). E [o follow-up](https://medium.com/@dan_abramov/presentational-and-container-components-b6bfb0a3a5d2) revisando a ideia.
- **Artigo.** Kent C. Dodds, ["When to break up a component into multiple components"](https://kentcdodds.com/blog/when-to-break-up-a-component-into-multiple-components).
- **Artigo.** Tanner Linsley & Adam Wathan, *muitas referências sobre compound components*; ver [React Patterns by Kent Dodds](https://kentcdodds.com/blog/compound-components-with-react-hooks).
- **Documentação.** [React: Thinking in React](https://react.dev/learn/thinking-in-react). Texto oficial sobre decomposição.
