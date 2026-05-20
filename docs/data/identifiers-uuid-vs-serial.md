# Identificadores: UUID vs Serial

> **TL;DR.** Use UUID como chave primária pública (opaca, gerável no cliente, sem revelar volume) e mantenha um `BIGSERIAL` interno para ordenação eficiente e integrações que não aceitam UUID.

## O quê

Toda tabela precisa de um identificador único. As duas escolhas dominantes:

- **UUID** (Universally Unique Identifier), 128 bits, geralmente exibido como `550e8400-e29b-41d4-a716-446655440000`. Pode ser gerado em qualquer lugar (cliente, servidor, banco) sem coordenação.
- **Serial / Auto-increment**: inteiro sequencial gerenciado pelo banco (`SERIAL`, `BIGSERIAL`, `IDENTITY`).

Não é uma escolha *ou exclusivo*: a recomendação prática é **manter os dois**.

## Por quê

| Aspecto | UUID | Serial |
|---|---|---|
| **Opacidade** | Não revela ordem nem volume | Revela quantos registros existem (information leak) |
| **Geração** | Pode ser gerado no cliente / antes do insert | Só após o insert |
| **Sharding / distribuição** | Trivial (qualquer nó pode gerar | Difícil) exige coordenação ou ranges |
| **Tamanho** | 16 bytes (ou 36 como texto) | 4–8 bytes |
| **Ordenação natural** | UUID v4 random é hostil para índices | Cresce monotonicamente, ótimo para B-tree |
| **Legibilidade humana** | Ruim | Excelente (`pedido #4231`) |
| **Compatibilidade externa** | Alguns sistemas legados não aceitam | Aceito universalmente |

A estratégia híbrida tira o melhor dos dois:

- **`id UUID`**: chave pública, exposta em APIs, URLs, eventos. Opaco e seguro.
- **`id_int BIGSERIAL`**: uso interno para ordenação, exibição humana ("pedido nº"), integrações legadas.

## Como aplicar

### Estrutura base

```sql
CREATE TABLE orders (
  id         UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_int     BIGSERIAL NOT NULL UNIQUE,
  -- demais colunas
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);
```

Em PostgreSQL, habilite a extensão:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- ou pgcrypto: gen_random_uuid()
```

### Versão do UUID: escolha consciente

| Versão | Característica | Quando usar |
|---|---|---|
| **v4 (random)** | Aleatório puro | Padrão. Boa para a maioria dos casos. |
| **v7 (time-ordered, RFC 9562)** | Prefixo de timestamp, sufixo aleatório | Melhor para índices, ordena por criação. **Recomendado se disponível.** |
| **v1** (MAC + tempo) | Inclui MAC address da máquina | Evite, vaza identidade da máquina. |
| **ULID** | Variação de v7 anterior à RFC, codificação Crockford | Boa alternativa, formato mais curto e legível. |

Para tabelas grandes (milhões de linhas), prefira **UUID v7** ou **ULID**: UUIDs random destroem a localidade do B-tree e fazem o índice inchar.

### Identificador de negócio (opcional)

Quando o domínio tem um identificador legível pelo usuário (matrícula, código de produto, número da nota fiscal), adicione uma coluna dedicada:

```sql
CREATE TABLE products (
  id          UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_int      BIGSERIAL UNIQUE,
  sku         VARCHAR(50) NOT NULL UNIQUE,  -- identificador de negócio
  -- ...
);
```

Em multi-tenant, o `sku` é único **por organização**, não global:

```sql
UNIQUE (organization_id, sku)
```

### Exposição em APIs

- **Use UUID nas URLs e payloads externos.** Nunca exponha `id_int`.
- **Use `id_int` para campos voltados ao humano** ("pedido nº 4231"), mas mantenha o UUID como referência canônica.

```http
GET /v1/orders/550e8400-e29b-41d4-a716-446655440000

{
  "id":          "550e8400-e29b-41d4-a716-446655440000",
  "order_number": 4231,
  "items":        [...]
}
```

### Geração no cliente

Uma vantagem subutilizada de UUID: o **cliente** pode gerar o ID antes mesmo do request. Isso destrava:

- **Idempotência natural**: o cliente envia o mesmo UUID em retry; o servidor detecta duplicata.
- **Otimistic UI**: o frontend cria a entidade localmente e sincroniza depois.

```ts
import { v7 } from 'uuid';

const orderId = v7();
await api.post(`/v1/orders`, { id: orderId, items });
// Mesmo se o request falhar e for retried, o servidor detecta pelo ID.
```

Ver [idempotência](../backend/idempotency.md).

## Quando *não* usar

- **UUID v4 em tabelas com milhões de linhas e B-tree único**: a fragmentação do índice cresce muito. Prefira v7/ULID ou avalie um esquema com `id_int` como PK e UUID como coluna única.
- **Sistemas extremamente sensíveis a tamanho**: em embedded ou IoT com armazenamento contado em bytes, UUID pode ser overhead. Inteiros sequenciais bastam.
- **Quando o banco controla tudo e não há distribuição.** Em monolitos simples sem necessidade de gerar IDs em outros lugares, `BIGSERIAL` puro é mais barato e tão correto quanto.

## Conceitos relacionados

- [Modelagem relacional](./relational-modeling.md)
- [Auditoria e soft delete](./auditing-soft-delete.md)
- [Idempotência](../backend/idempotency.md)

## Referências

- **RFC.** [RFC 9562: Universally Unique IDentifiers (UUIDs)](https://www.rfc-editor.org/rfc/rfc9562) (IETF, 2024). Define v6, v7, v8, substituiu RFC 4122.
- **Spec.** [ULID Spec](https://github.com/ulid/spec). Alternativa popular com formato mais compacto.
- **Artigo.** [PostgreSQL: UUID vs Serial](https://www.cybertec-postgresql.com/en/uuid-vs-serial-pros-and-cons/) (Cybertec).
- **Artigo.** [Brandur Leach: Identity in Postgres](https://brandur.org/identifiers). Comparação detalhada para sistemas modernos.
- **Documentação.** [PostgreSQL, uuid-ossp](https://www.postgresql.org/docs/current/uuid-ossp.html).
