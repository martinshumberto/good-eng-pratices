# Migrations

> **TL;DR.** Versione o schema com a mesma disciplina do código: migrations numeradas, idempotentes, reversíveis e aplicadas pela própria aplicação na inicialização (ou por uma etapa explícita no pipeline).

## O quê

**Migration** é um arquivo versionado que descreve uma mudança no schema do banco, criar tabela, adicionar coluna, alterar índice. Cada mudança é aplicada de forma ordenada e auditável, transformando o schema do estado anterior para o atual.

Ferramentas dedicadas resolvem três problemas duros:

1. **Ordenação determinística**: a mesma sequência rodando em qualquer ambiente leva ao mesmo schema.
2. **Idempotência por ambiente**: uma migration já aplicada não é re-executada.
3. **Reversão**: voltar a um estado anterior em caso de erro.

Ferramentas comuns:

- **TypeScript / Node:** [Prisma Migrate](https://www.prisma.io/migrate), [TypeORM migrations](https://typeorm.io/migrations), [Knex migrations](https://knexjs.org/guide/migrations.html), [Drizzle Kit](https://orm.drizzle.team/kit-docs/overview).
- **Multi-linguagem:** [Flyway](https://flywaydb.org), [Liquibase](https://liquibase.org), [`golang-migrate/migrate`](https://github.com/golang-migrate/migrate).

## Por quê

Sem migrations versionadas, o schema vira **conhecimento tácito**:

- Cada desenvolvedor tem uma versão local levemente diferente.
- Subir um ambiente novo exige caça em scripts antigos.
- Rollback é uma oração.

Migrations resolvem ao tornar o schema **código**: revisado, testado e versionado junto com a aplicação.

## Como aplicar

### Estrutura de arquivos

Convenção comum: pares `up`/`down` numerados por timestamp:

```
migrations/
├─ up/
│  ├─ 20240115093000_create_users.up.sql
│  ├─ 20240115101200_add_phone_to_users.up.sql
│  └─ 20240116144500_create_orders.up.sql
└─ down/
   ├─ 20240115093000_create_users.down.sql
   ├─ 20240115101200_add_phone_to_users.down.sql
   └─ 20240116144500_create_orders.down.sql
```

O timestamp garante ordem; o nome descreve a intenção.

### Geração automática

Disponibilize um comando que cria os arquivos já formatados:

```bash
make gen-migration name=add_phone_to_users
# → cria migrations/up/<ts>_add_phone_to_users.up.sql
#   e migrations/down/<ts>_add_phone_to_users.down.sql
```

### Exemplo: criação de tabela

```sql
-- up
CREATE TABLE IF NOT EXISTS users (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_int     BIGSERIAL UNIQUE,
  email      VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique
  ON users (email)
  WHERE deleted_at IS NULL;

-- down
DROP TABLE IF EXISTS users;
```

### Exemplo: alteração

```sql
-- up
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- down
ALTER TABLE users DROP COLUMN IF EXISTS phone_number;
```

### Onde rodar?

Duas estratégias comuns:

#### A) Rodar na inicialização da aplicação

O serviço aplica suas migrations no startup, antes de aceitar tráfego.

```ts
async function bootstrap() {
  await db.connect();
  await migrate.up({ database: db });
  app.listen(8080);
}
```

**Vantagem:** simples. Cada serviço cuida do seu schema.
**Cuidado:** com múltiplas instâncias, use *lock* (a ferramenta normalmente já tem) para impedir migrations concorrentes.

#### B) Etapa separada no pipeline

Migration é um passo do pipeline antes do deploy do app.

**Vantagem:** controle preciso, possibilidade de rollback antes de qualquer tráfego.
**Cuidado:** mais complexo de orquestrar. Ideal para sistemas que exigem zero-downtime estrito.

A escolha depende da maturidade do time. **Começar pela A** é uma escolha sensata para a maioria dos cenários.

### Boas práticas

#### Idempotência (`IF NOT EXISTS`, `IF EXISTS`)

Toda operação que pode ser repetida deve **falhar silenciosamente** quando já aplicada:

```sql
CREATE TABLE IF NOT EXISTS ...
CREATE INDEX  IF NOT EXISTS ...
ALTER TABLE   ... ADD COLUMN IF NOT EXISTS ...
DROP TABLE    IF EXISTS ...
```

Por quê? Migrations parcialmente aplicadas podem precisar ser rodadas de novo. Se a primeira instrução já passou e a segunda falhou, rerunning deve funcionar.

#### Reversibilidade real

Toda `up.sql` deve ter um `down.sql` correspondente. Em casos sem rollback possível (data loss inevitável), seja explícito:

```sql
-- down
-- This migration cannot be reverted without data loss.
-- Restore from backup if needed.
```

#### Atomicidade

Cada migration deve ser **atomicamente aplicável**. Se uma instrução falhar, nenhuma mudança deve ficar:

```sql
BEGIN;
  ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);
  UPDATE users SET phone_number = profile.phone FROM profiles WHERE profiles.user_id = users.id;
  ALTER TABLE users ALTER COLUMN phone_number SET NOT NULL;
COMMIT;
```

PostgreSQL aplica DDL em transação por default; bancos como MySQL/MariaDB nem sempre, verifique.

#### Testes antes de produção

- Aplicar em desenvolvimento e CI.
- Rodar contra um snapshot de produção em staging.
- Para tabelas grandes, medir tempo e impacto antes do deploy.

#### Operações pesadas em tabelas grandes

Algumas operações **bloqueiam a tabela**:

- `ALTER TABLE ... ADD COLUMN` com default não-constante (Postgres < 11).
- `CREATE INDEX` sem `CONCURRENTLY`.
- `ALTER COLUMN ... TYPE` que reescreve toda a tabela.

Em tabelas grandes em produção:

```sql
-- ✅ Não bloqueia escrita
CREATE INDEX CONCURRENTLY users_email_idx ON users (email);

-- ✅ Em duas migrations: adicionar nullable, backfill, then NOT NULL
ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);          -- mig 1
UPDATE users SET phone_number = ... WHERE phone_number IS NULL; -- backfill (fora de migration)
ALTER TABLE users ALTER COLUMN phone_number SET NOT NULL;       -- mig 2
```

#### Mudanças de schema com zero downtime

Quando aplicação antiga e nova coexistem (rolling deploy, blue-green):

- **Adicionar coluna** → seguro (nullable; default só se a versão antiga aceita ignorar).
- **Remover coluna** → faça em duas releases: primeira para de usar, segunda remove.
- **Renomear coluna** → impossível sem downtime direto. Faça em três passos: adiciona nova, copia, remove antiga.
- **Mudar tipo de coluna** → idem renomear.

Padrão: [*expand-and-contract*](https://martinfowler.com/bliki/ParallelChange.html).

## Quando *não* usar

- **Bancos NoSQL schema-less**: MongoDB, DynamoDB. Migrations são substituídas por *schema versioning* nos próprios documentos.
- **Aplicações de prova de conceito**: overhead não se paga. Volte ao versionamento quando a aplicação for compartilhada.
- **Dados em vez de schema**: não use migrations para inserir dados de produção (seeds, fixtures). Use mecanismo separado.

## Conceitos relacionados

- [Modelagem relacional](./relational-modeling.md)
- [Versionamento de API](../backend/api-versioning.md), mesma disciplina, contexto diferente.
- [CI/CD](../delivery/ci-cd.md), onde migrations rodam no pipeline.

## Referências

- **Livro.** Pramod Sadalage & Scott Ambler, *Refactoring Databases: Evolutionary Database Design* (Addison-Wesley, 2006). Texto fundador sobre migrations.
- **Livro.** Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017). Discussão sobre schema evolution.
- **Artigo.** Martin Fowler, ["Parallel Change"](https://martinfowler.com/bliki/ParallelChange.html). Padrão *expand-and-contract*.
- **Artigo.** Martin Fowler, ["Evolutionary Database Design"](https://martinfowler.com/articles/evodb.html).
- **Documentação.** [Flyway docs](https://documentation.red-gate.com/flyway). Boa referência de práticas, mesmo se você não usar Flyway.
