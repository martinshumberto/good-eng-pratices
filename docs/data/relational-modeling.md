# Modelagem Relacional

> **TL;DR.** Use tipos certos para cada campo, prefira `NOT NULL` por padrão, defina `UNIQUE` e *foreign keys* dentro do mesmo schema, e nunca use `float` para dinheiro.

## O quê

Modelagem relacional é a tradução do domínio para tabelas, colunas, tipos e restrições em um SGBD relacional. As decisões aqui afetam **integridade**, **performance** e **velocidade de evolução** do sistema por anos.

Este documento foca em convenções de **estrutura de tabelas**. Para versionar mudanças no schema, ver [Migrations](./migrations.md). Para escolha de identificador, ver [UUID vs serial](./identifiers-uuid-vs-serial.md). Para campos de auditoria e soft delete, ver [Auditoria](./auditing-soft-delete.md).

Os exemplos usam PostgreSQL, mas as diretrizes aplicam-se a qualquer SGBD relacional.

## Por quê

O banco é, em geral, o componente mais difícil de evoluir do sistema:

- Dados existentes não somem só porque mudamos a aplicação.
- Migrations mal pensadas geram bloqueios em tabelas grandes.
- Constraints ausentes deixam dados inválidos entrarem e contaminam tudo.

Modelar com cuidado desde o início **economiza incidentes** depois. Validação no banco é a última linha de defesa quando a aplicação falha em validar.

## Como aplicar

### Nomenclatura

- **`snake_case`** para tabelas e colunas. É a convenção dominante em SQL.
- **Plural para tabelas** (`users`, `orders`), **singular para colunas** (`user_id`).
- **Sufixe FKs com `_id`**: `customer_id`, `order_id`. Quando a relação for *role-based*, deixe o papel explícito: `approver_profile_id` em vez de só `approver_id`.

### Constraints essenciais

#### `NOT NULL` por padrão

Comece com `NOT NULL` e só relaxe quando o valor for genuinamente opcional. Colunas anuláveis exigem tratamento extra em todo lugar; reduza-as ao mínimo.

```sql
-- ✅
email VARCHAR(255) NOT NULL,
phone VARCHAR(20)            -- explicitamente opcional
```

#### `UNIQUE` para chaves naturais

Toda chave de negócio única deve ter constraint. Quando a unicidade é composta, use índice único:

```sql
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);

CREATE UNIQUE INDEX subscriptions_user_plan_unique
  ON subscriptions (user_id, plan_id)
  WHERE deleted_at IS NULL;
```

#### `FOREIGN KEY` dentro do mesmo schema

Use FK para garantir integridade referencial dentro do mesmo schema/microsserviço.

**Não use FK entre schemas de microsserviços diferentes.** FK entre serviços reintroduz o acoplamento que a separação tentou eliminar, qualquer mudança de schema vira coordenação entre times.

```sql
-- ✅ FK dentro do mesmo schema
ALTER TABLE order_items
  ADD CONSTRAINT order_items_order_fk
  FOREIGN KEY (order_id) REFERENCES orders(id);

-- ❌ FK entre schemas de serviços diferentes
-- (orders.users.id sai do controle do serviço de orders)
```

### Tipos adequados

| Tipo | Uso |
|---|---|
| `UUID` | Identificadores principais. Ver [identificadores](./identifiers-uuid-vs-serial.md). |
| `BIGINT` / `SERIAL` | Numéricos incrementais, contadores. |
| `TIMESTAMP WITH TIME ZONE` (`TIMESTAMPTZ`) | **Sempre** que armazenar instante no tempo. Evite `TIMESTAMP` sem fuso. |
| `DATE` | Data sem hora (aniversário, vencimento). |
| `VARCHAR(n)` | Texto com limite conhecido. |
| `TEXT` | Texto livre, sem limite prático. No PostgreSQL, `VARCHAR` e `TEXT` têm performance equivalente. |
| `BOOLEAN` | Flags binárias. |
| `JSONB` | Estruturas semi-estruturadas, queries pontuais. **Não use** para dados que você consultará frequentemente, vira coluna disfarçada. |
| `ARRAY` | Listas simples acopladas ao registro pai. Para relações reais, normalize. |
| `NUMERIC(precision, scale)` / `VARCHAR` decimal | **Sempre** para valores monetários. **Nunca** `FLOAT`/`DOUBLE`. |
| `BYTEA` | Bytes brutos. Use com moderação, prefira object storage para arquivos grandes. |

### Valores decimais: **nunca** `float`

Ponto flutuante perde precisão em operações simples:

```ts
0.1 + 0.2 === 0.3   // false → 0.30000000000000004
```

Para dinheiro e valores com precisão fixa:

- **PostgreSQL:** use `NUMERIC(15, 2)` (15 dígitos, 2 decimais).
- **Camada de aplicação:** use uma library decimal, [`decimal.js`](https://mikemcl.github.io/decimal.js/) ou [`big.js`](https://mikemcl.github.io/big.js/) em TypeScript.

```ts
import Decimal from 'decimal.js';

const subtotal = new Decimal(item.price).times(item.quantity);
const tax      = subtotal.times(0.1);
const total    = subtotal.plus(tax);
```

Outra estratégia: armazenar como inteiro de centavos (`amount_cents BIGINT`). Evita ambiguidade de escala, simples para somar e ordenar.

### Validação de constraints customizadas

Para regras que o tipo não cobre (string não-vazia, UUID não-zero), use `CHECK` constraints com funções:

```sql
CREATE FUNCTION validate_non_empty_string(val VARCHAR) RETURNS BOOLEAN AS $$
BEGIN
  RETURN val IS NULL OR val <> '';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

ALTER TABLE users
  ADD CONSTRAINT users_name_not_empty
  CHECK (validate_non_empty_string(name));
```

Convenção: quando uma string opcional não tem valor, persista `NULL`: não string vazia.

Validar no banco **não substitui** validar no código. O banco é a última linha de defesa, não a primeira.

### Index design: princípios

- **Crie índices guiado por queries reais**, não por intuição. Use `EXPLAIN ANALYZE`.
- **FKs precisam de índice no lado "muitos"** (a maioria dos SGBDs não cria automaticamente).
- **Índices têm custo**: toda escrita atualiza todos os índices da tabela. Excesso degrada gravação.
- **Índices parciais** filtram o que importa: `WHERE deleted_at IS NULL`, `WHERE status = 'active'`.

### Schema por microsserviço

Cada microsserviço tem seu próprio schema dentro do banco. Isso:

- Localiza acidentes, uma migration errada não destrói tabelas de outro serviço.
- Permite migrar para banco próprio depois (Database per Service).
- Mantém FK e constraints dentro do schema (alta integridade interna, baixo acoplamento externo).

```sql
CREATE SCHEMA auth;
CREATE TABLE auth.users (...);

CREATE SCHEMA orders;
CREATE TABLE orders.orders (...);
-- Sem FK entre auth.users e orders.orders
```

Quando o serviço de orders precisa do `user_id`, ele guarda como `UUID` simples e consulta o serviço de auth via API/gRPC.

## Quando *não* usar

- **Workloads não-relacionais.** Documentos com hierarquia profunda, séries temporais massivas, grafos, full-text search, relacional pode não ser a ferramenta certa. Avalie MongoDB, ClickHouse, Neo4j, Elasticsearch para o caso.
- **Escala massiva com requisitos específicos.** Para milhões de eventos por segundo, mesmo Postgres tem limites. Considere event sourcing, particionamento agressivo ou alternativas dedicadas.

## Conceitos relacionados

- [Identificadores: UUID vs serial](./identifiers-uuid-vs-serial.md)
- [Auditoria e soft delete](./auditing-soft-delete.md)
- [Migrations](./migrations.md)
- [Validação de entrada](../backend/input-validation.md), validação no código.

## Referências

- **Livro.** Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017). Capítulos 2–3 sobre modelos de dados e armazenamento.
- **Livro.** Bill Karwin, *SQL Antipatterns: Avoiding the Pitfalls of Database Programming* (Pragmatic Bookshelf, 2010). Catálogo de erros comuns.
- **Livro.** Markus Winand, *SQL Performance Explained* (2012). Também disponível como [use-the-index-luke.com](https://use-the-index-luke.com).
- **Documentação.** [PostgreSQL Documentation: Data Types](https://www.postgresql.org/docs/current/datatype.html).
- **Artigo.** Joel Spolsky, ["Back to Basics"](https://www.joelonsoftware.com/2001/12/11/back-to-basics/) (2001). Por que ponto flutuante é o errado para dinheiro.
