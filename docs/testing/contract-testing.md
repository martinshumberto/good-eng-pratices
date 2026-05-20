# Contract Testing

> **TL;DR.** Cada consumidor define **o contrato** (request → response) que espera do provider. O provider verifica que cumpre todos os contratos antes de deploy. Substitui boa parte do teste E2E entre serviços, com feedback rápido e por equipe.

## O quê

**Contract testing** é uma abordagem para validar que dois serviços que se comunicam **continuam compatíveis** ao longo do tempo. A variante mais usada é **Consumer-Driven Contract Testing (CDCT)**, popularizada por **Ian Robinson** e formalizada na ferramenta [Pact](https://pact.io) (criada por Beth Skurrie: DiUS, 2012).

O fluxo:

```
1. Consumer escreve teste contra um mock do provider, gera um "pact" (JSON).
2. Pact é publicado num broker (Pact Broker).
3. Provider, antes do deploy, baixa todos os pacts e verifica que cumpre.
4. Provider publica se "compatível"; broker atualiza status do contrato.
```

Resultado: o consumidor sabe o que precisa; o provider sabe se vai quebrar alguém **antes** de subir.

## Por quê

Em arquiteturas com vários serviços, validar integração tradicionalmente cai em duas abordagens ruins:

- **E2E completos**: sobe todo o sistema. Lento, frágil, caro.
- **Documentação manual de API**: desatualiza. Bugs descobertos só em produção.

Contract testing oferece um meio termo:

- **Rápido**: testa-se localmente, contra mock, sem subir nada.
- **Confiável**: o que o consumidor *de fato* usa vira o contrato. Sem ambiguidade.
- **Distribuído**: cada time trabalha no seu repositório, sincronizando via broker.
- **Pega quebras cedo**: provider sabe se vai quebrar antes de publicar.

Trade-off: **só cobre interfaces**. Lógica interna do provider continua precisando de testes próprios.

> "Consumer-driven contracts are about making integration testing scale."
> (Ian Robinson)

## Como aplicar

### Anatomia de um contrato

Um pact descreve as **interações** que o consumidor faz com o provider:

```json
{
  "consumer": { "name": "WebApp" },
  "provider": { "name": "OrdersService" },
  "interactions": [
    {
      "description": "a request to get an order",
      "request": {
        "method": "GET",
        "path":   "/orders/123",
        "headers": { "Accept": "application/json" }
      },
      "response": {
        "status": 200,
        "headers": { "Content-Type": "application/json" },
        "body": {
          "id":     "123",
          "status": "placed",
          "total":  { "amount": "100.00", "currency": "BRL" }
        }
      }
    }
  ]
}
```

### Lado do consumer

```ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact';

const provider = new PactV3({
  consumer: 'WebApp',
  provider: 'OrdersService',
});

describe('OrdersClient', () => {
  it('fetches an order', async () => {
    provider.addInteraction({
      states: [{ description: 'order 123 exists' }],
      uponReceiving: 'a request to get an order',
      withRequest: {
        method: 'GET',
        path:   '/orders/123',
      },
      willRespondWith: {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: MatchersV3.like({
          id:     '123',
          status: 'placed',
          total:  { amount: '100.00', currency: 'BRL' },
        }),
      },
    });

    await provider.executeTest(async (mockServer) => {
      const client = new OrdersClient(mockServer.url);
      const order  = await client.getById('123');

      expect(order.id).toBe('123');
      expect(order.status).toBe('placed');
    });
  });
});
```

Ao rodar, Pact:

1. Sobe um **servidor mock** local com a resposta configurada.
2. Cliente real (`OrdersClient`) faz request.
3. Verifica que o request bate com o esperado.
4. Grava o JSON do pact.

### Pact Broker: coração da arquitetura

O **Pact Broker** ([opensource](https://github.com/pact-foundation/pact_broker) ou [PactFlow](https://pactflow.io) managed) armazena pacts e seu status. Comandos típicos:

```bash
# Consumer publica seu pact após testes verdes
pact-broker publish ./pacts --consumer-app-version=$GIT_SHA --broker-base-url=https://broker.example.com

# Provider verifica todos os pacts que apontam pra ele
pact-broker verify --provider=OrdersService --provider-base-url=http://localhost:3000

# Pode-se aplicar?
pact-broker can-i-deploy --pacticipant=WebApp --version=$GIT_SHA --to-environment=production
```

`can-i-deploy` é a chave do fluxo CI/CD: bloqueia deploy quando o consumer não foi verificado contra a versão produção do provider.

### Lado do provider

```ts
import { Verifier } from '@pact-foundation/pact';
import { startApp } from './app';

describe('OrdersService Pact Verification', () => {
  let server;

  beforeAll(async () => { server = await startApp(3000); });
  afterAll(() => server.close());

  it('verifies all consumer contracts', async () => {
    await new Verifier({
      provider:        'OrdersService',
      providerBaseUrl: 'http://localhost:3000',
      pactBrokerUrl:   'https://broker.example.com',
      publishVerificationResult: true,
      providerVersion: process.env.GIT_SHA,

      // Provider states, setup específico antes de cada interaction
      stateHandlers: {
        'order 123 exists': async () => {
          await db.orders.insert({ id: '123', status: 'placed', /* ... */ });
        },
      },
    }).verifyProvider();
  });
});
```

O `Verifier` baixa pacts do broker, executa cada interação contra a app real, valida, e publica o resultado.

### Provider states

Cada interação pode requerer um **estado prévio** do provider. Antes de "GET /orders/123 retorna 200", o serviço precisa ter o pedido 123 no banco.

```ts
// Consumer declara o estado necessário
{
  states: [{ description: 'order 123 exists' }],
  uponReceiving: 'a request to get an order',
  // ...
}

// Provider implementa o setup desse estado
stateHandlers: {
  'order 123 exists': async () => {
    await db.orders.insert({ id: '123', /* ... */ });
  },
}
```

Use estados textuais bem nomeados, eles viram parte do contrato.

### Matchers: flexibilidade controlada

Contratos exatos demais quebram em qualquer mudança. Pact tem matchers:

```ts
MatchersV3.like({                        // estrutura, valores como exemplo
  id: '123',
  total: MatchersV3.decimal(100.0),       // qualquer decimal
  createdAt: MatchersV3.iso8601DateTime(), // qualquer ISO timestamp
  items: MatchersV3.eachLike({             // array de pelo menos 1, com formato do exemplo
    sku: 'A',
    quantity: 1,
  }),
});
```

Resultado: o consumer fixa **forma**, não valores específicos.

### Quando contract testing brilha

✅ **Múltiplos consumers compartilham um provider** (microsserviços internos, API gateway).
✅ **Equipes distribuídas** trabalham em consumer e provider separadamente.
✅ **Mudança coordenada** entre serviços é cara.

### Quando não brilha

❌ **Sistemas pub-sub assíncronos.** Pact tem suporte para [message contracts](https://docs.pact.io/getting_started/how_pact_works#non-http-testing-message-pact) mas é menos maduro.
❌ **GraphQL.** Resolvers são dinâmicos; contratos por query ficam frágeis.
❌ **Mudanças muito frequentes.** Tooling de pact tem overhead, comum em monolitos e early-stage.

### Limites: o que contract testing não substitui

- **Testes de integração no provider.** Pact verifica que o endpoint responde como espera; não verifica que ele faz a coisa certa internamente.
- **E2E críticos.** Fluxos com múltiplos serviços ainda precisam de smoke E2E.
- **Validação de schemas**: OpenAPI / Protobuf cobrem schema, pact cobre comportamento.

Contract testing **complementa**; não substitui.

### Bi-directional contract testing: alternativa moderna

[PactFlow Bi-Directional Contracts](https://pactflow.io/blog/bi-directional-contract-testing/) usa **OpenAPI spec do provider** + **testes do consumer contra mocks gerados do spec**. Provider testa contra o spec; consumer testa contra mock derivado do mesmo spec.

Vantagem: menos coordenação. Provider trabalha contra spec (single source of truth) sem precisar rodar verificação de cada pact.

### Boas práticas

- **Pacts são fontes do consumer.** Não edite manualmente, gere via teste.
- **Publique no broker em CI**, não localmente.
- **`can-i-deploy` em CD**: bloqueio de deploy se não compatível.
- **Provider states curtos e bem nomeados.** "order 123 exists" > "the test setup".
- **Matchers liberais.** Não cole valores que vão mudar.
- **Versione consumers e providers**: use git SHA ou semver.

## Quando *não* usar

- **Monolito**: sem múltiplos serviços conversando.
- **Time pequeno (1–2 devs)**: overhead de broker e CI não se paga.
- **APIs raramente alteradas**: investimento em pact não compensa.
- **Sem cultura DevOps**: sem CI/CD maduro, broker vira mais um sistema desatualizado.

## Conceitos relacionados

- [Microsserviços](../architecture/microservices.md), onde contract testing brilha.
- [API design (REST](../backend/api-design-rest.md) e [gRPC](../backend/api-design-grpc.md)) contratos como fonte.
- [Versionamento de API](../backend/api-versioning.md), evolução de contrato.
- [CI/CD](../delivery/ci-cd.md), onde `can-i-deploy` se encaixa.

## Referências

- **Site.** [pact.io](https://pact.io). Documentação central do Pact.
- **Site.** [docs.pact.io](https://docs.pact.io). Guia mais detalhado.
- **Livro.** Ian Robinson, ["Consumer-Driven Contracts: A Service Evolution Pattern"](https://martinfowler.com/articles/consumerDrivenContracts.html) (Martin Fowler's site, 2006). Texto fundador.
- **Livro.** Sam Newman, *Building Microservices*, 2ª ed. (O'Reilly, 2021). Capítulo sobre testes em microsserviços.
- **Livro.** Vladimir Khorikov, *Unit Testing* (Manning, 2020). Discute contract tests no contexto da pirâmide.
- **Artigo.** Beth Skurrie & Matt Fellows, ["The Contract Testing in Practice"](https://pactflow.io/blog/contract-testing-vs-integration-testing/).
- **Documentação.** [PactFlow: Bi-Directional Contract Testing](https://docs.pactflow.io/docs/bi-directional-contract-testing/).
- **Artigo.** Martin Fowler, ["ContractTest"](https://martinfowler.com/bliki/ContractTest.html).
