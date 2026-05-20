# Transações e Níveis de Isolamento

> **TL;DR.** Transações garantem ACID dentro do banco. Níveis de isolamento são um **trade-off entre consistência e concorrência**: saiba qual seu banco usa por default, quais anomalias ele previne, e use o mais alto que sua workload tolerar.

## O quê

Uma **transação** é uma unidade lógica de trabalho que satisfaz as propriedades **ACID**:

- **Atomicity**: tudo ou nada. Se uma operação falha, todas são desfeitas.
- **Consistency**: o banco vai de um estado válido a outro estado válido.
- **Isolation**: transações concorrentes não enxergam mudanças parciais umas das outras.
- **Durability**: após commit, mudanças sobrevivem a crashes.

**Isolation** é o aspecto mais sutil. SQL define quatro níveis (ANSI/ISO SQL-92), do mais fraco ao mais forte:

| Nível | Permite |
|---|---|
| **Read Uncommitted** | Dirty reads, non-repeatable reads, phantom reads |
| **Read Committed** | Non-repeatable reads, phantom reads |
| **Repeatable Read** | Phantom reads (em alguns bancos) |
| **Serializable** | Nenhuma anomalia |

Bancos modernos usam **MVCC (Multi-Version Concurrency Control)**: em vez de locks pesados, mantêm versões dos registros. Postgres, Oracle, MySQL (InnoDB) implementam MVCC.

## Por quê

Sem entender isolation, você convive com bugs sutis:

- "Por que esse valor mudou no meio da transação?"
- "Por que esse `INSERT ... WHERE NOT EXISTS` deixou passar duas linhas iguais?"
- "Por que o saldo ficou negativo?"

Esses são **anomalias de concorrência**: clássicas na literatura. Cada nível de isolation permite/previne um conjunto delas.

> "Database isolation is one of those topics that everyone knows about, until they have to think really hard about it."
> (Martin Kleppmann)

## Como aplicar

### Anomalias clássicas

#### Dirty Read

Transação A lê dados **não-commitados** de B. Se B faz rollback, A trabalhou com lixo.

```
T1:                              T2:
BEGIN;                           BEGIN;
UPDATE accounts
  SET balance = balance - 100;
                                 SELECT balance FROM accounts;   -- vê o valor decrementado
ROLLBACK;                                                        -- mas T1 reverte!
```

**Prevenida a partir de Read Committed.** Bancos modernos nunca permitem por default.

#### Non-Repeatable Read

Transação A lê uma linha; depois B atualiza e commita; A relê a mesma linha e vê valor diferente.

```
T1:                              T2:
BEGIN;
SELECT balance WHERE id=1;       -- vê 100
                                 BEGIN;
                                 UPDATE accounts SET balance = 200 WHERE id=1;
                                 COMMIT;
SELECT balance WHERE id=1;       -- vê 200 (mudou!)
```

**Prevenida a partir de Repeatable Read.**

#### Phantom Read

Transação A lê um conjunto de linhas via WHERE; B insere uma nova linha que satisfaz o WHERE; A relê e vê uma linha "fantasma".

```
T1:                              T2:
BEGIN;
SELECT COUNT(*) WHERE active;    -- vê 10
                                 INSERT INTO users (active) VALUES (true);
                                 COMMIT;
SELECT COUNT(*) WHERE active;    -- vê 11 (apareceu uma!)
```

**Prevenida em Serializable** (em alguns bancos, também em Repeatable Read via locks de range).

#### Lost Update

Duas transações leem o mesmo valor, ambas calculam novo valor, ambas escrevem, uma atualização é **perdida**.

```
T1:                              T2:
BEGIN;                           BEGIN;
SELECT balance WHERE id=1;       -- 100
                                 SELECT balance WHERE id=1;       -- 100
UPDATE balance = 100 + 50;
COMMIT;                          UPDATE balance = 100 + 30;
                                 COMMIT;                          -- balance = 130, +50 perdido
```

**Prevenida em Repeatable Read (em alguns bancos) ou via locks explícitos / OCC.**

#### Write Skew

Mais sutil. Duas transações leem dados sobrepostos, decidem com base na leitura, escrevem em locais diferentes, cada uma vista isoladamente é válida, mas o resultado final viola a invariante.

```
Invariante: pelo menos um médico de plantão.

Dr. Alice e Dr. Bob estão de plantão.

T1 (Alice):                      T2 (Bob):
BEGIN;                           BEGIN;
SELECT count(*) on call;         -- 2
                                 SELECT count(*) on call;         -- 2
-- "tem 2, posso sair"
UPDATE Alice SET on_call=false;
COMMIT;                          -- "tem 2, posso sair"
                                 UPDATE Bob SET on_call=false;
                                 COMMIT;

-- Resultado: zero médicos de plantão.
```

**Prevenida apenas em Serializable.**

### Níveis na prática

#### PostgreSQL

- **Default:** `READ COMMITTED`.
- **Implementa:** Read Committed, Repeatable Read (== Snapshot Isolation), Serializable (via [SSI: Serializable Snapshot Isolation](https://wiki.postgresql.org/wiki/Serializable)).
- **Nota:** o "Repeatable Read" do Postgres é tecnicamente mais forte que o do padrão SQL, implementa **Snapshot Isolation**, que previne phantoms também. Mas **não previne write skew**: para isso, use `SERIALIZABLE`.

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
-- ...
COMMIT;
```

Em Serializable do Postgres, transações com conflito **falham** no commit, você precisa estar preparado para retry.

#### MySQL (InnoDB)

- **Default:** `REPEATABLE READ`.
- **Implementa:** todos os 4 níveis.
- **Nota:** o Repeatable Read do InnoDB também previne phantoms via gap locks.

#### SQL Server

- **Default:** `READ COMMITTED` (sem snapshot, usa locks).
- **Variações:** `READ COMMITTED SNAPSHOT` (snapshot-based), `SNAPSHOT` (similar a Postgres RR).

### Quando usar cada nível

| Cenário | Nível recomendado |
|---|---|
| Leituras analíticas, reports | Read Committed (default) |
| CRUD comum | Read Committed |
| Operações que leem e atualizam o mesmo registro | Repeatable Read ou Locks explícitos |
| Operações com invariantes envolvendo múltiplos registros | Serializable |
| Sistemas financeiros (transferências, débitos) | Serializable ou locks explícitos com SELECT FOR UPDATE |

**Heurística:** comece com o default do banco. Se observar anomalia, suba o nível na transação específica.

### Locks explícitos

#### SELECT FOR UPDATE

Trava as linhas selecionadas até o final da transação. Outras transações que tentem `UPDATE`/`DELETE` ou `FOR UPDATE` esperam.

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
-- nenhuma outra transação pode mexer em accounts.id=1 até commit
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

Use para **pessimistic locking**: útil quando concorrência é alta e retry seria caro.

#### SELECT FOR UPDATE NOWAIT / SKIP LOCKED

- **`NOWAIT`**: falha imediatamente se o lock está tomado, em vez de esperar.
- **`SKIP LOCKED`**: ignora linhas locked, retorna o resto. Excelente para implementar **filas em SQL**:

```sql
-- Worker pegando próximo job
SELECT * FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
```

### Optimistic Concurrency Control (OCC)

Em vez de lock, adicione uma **version column**. Update só passa se a versão não mudou.

```sql
UPDATE products
SET price = $new, version = version + 1
WHERE id = $id AND version = $current_version;

-- 0 rows affected = alguém atualizou primeiro; recarregue e tente de novo
```

Comum em ORMs (Hibernate `@Version`, TypeORM, Prisma).

**Vantagens:** menos contenção, melhor concorrência.
**Desvantagens:** precisa lidar com retry no código.

### Deadlocks

Dois transações esperando uma a outra:

```
T1: UPDATE accounts WHERE id=1;
T2: UPDATE accounts WHERE id=2;
T1: UPDATE accounts WHERE id=2;   -- espera T2
T2: UPDATE accounts WHERE id=1;   -- espera T1 → DEADLOCK
```

Bancos detectam e abortam **uma das transações** com erro de deadlock. Seu código deve estar preparado para **retry**.

**Prevenção:**

- **Ordem consistente de acesso.** Sempre lock recursos na mesma ordem (ex.: por ID crescente).
- **Transações curtas.** Quanto menos tempo segurando lock, menor chance de cruzar com outra.
- **Use FOR UPDATE com ORDER BY.**

### Boas práticas

- **Transações curtas.** Não faça I/O externo (HTTP, fila) dentro de transação, mantém locks por tempo demais.
- **Sem chamadas externas no meio.** Se precisar enviar email após save, use [outbox pattern](../architecture/event-driven.md).
- **Falha-rápido em retry.** Se um banco retornou deadlock, retry no máximo 3 vezes. Mais que isso, devolve erro.
- **Não confie em READ COMMITTED para invariantes.** Para regras como "saldo nunca negativo", use Serializable ou SELECT FOR UPDATE.
- **Teste em concorrência.** A maioria dos bugs de isolation só aparece com 2+ transações paralelas. Use [Jepsen](https://jepsen.io)-style tests para sistemas críticos.

### Distributed transactions: evite

Transações **across multiple databases or services** (2PC, XA) são notoriamente frágeis. Em sistemas distribuídos, prefira:

- **Sagas**: sequência de operações locais com compensações.
- **Outbox**: garante consistência entre escrita local e publicação de evento.
- **Eventual consistency**: aceite que o sistema convirja com tempo.

Ver [Event-Driven Architecture](../architecture/event-driven.md).

## Quando *não* usar

- **Operações idempotentes simples sem invariantes.** Não embrulhe trivialmente em transação se não há múltiplas escritas relacionadas.
- **Reports / analytics.** Geralmente Read Committed é suficiente; não precisa subir nível.
- **Operações cross-service.** Transações distribuídas (2PC) são caras e frágeis, modele com sagas em vez.

## Conceitos relacionados

- [Modelagem relacional](./relational-modeling.md), onde constraints reforçam consistência.
- [Migrations](./migrations.md): DDL em transação (na maioria dos bancos).
- [Event-Driven Architecture](../architecture/event-driven.md), alternativa em sistemas distribuídos.
- [Idempotência](../backend/idempotency.md), pré-requisito para retry após conflito.

## Referências

- **Livro.** Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017). Capítulo 7 (*Transactions*) é a referência moderna mais clara sobre isolation.
- **Livro.** Alex Petrov, *Database Internals* (O'Reilly, 2019). Implementação interna de MVCC, locks.
- **Paper.** Hal Berenson et al., ["A Critique of ANSI SQL Isolation Levels"](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/tr-95-51.pdf) (Microsoft, 1995). Crítica clássica; introduz Snapshot Isolation.
- **Paper.** Michael Cahill et al., ["Serializable Isolation for Snapshot Databases"](https://courses.cs.washington.edu/courses/cse444/08au/544M/READING-LIST/fekete-sigmod2008.pdf). Base do SSI do Postgres.
- **Documentação.** [PostgreSQL: Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html). Documentação canônica.
- **Documentação.** [MySQL: InnoDB Transaction Model](https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-model.html).
- **Site.** [Jepsen](https://jepsen.io). Análise empírica de garantias em bancos distribuídos.
- **Artigo.** Martin Kleppmann, ["Hermitage: testing the 'I' in ACID"](https://martin.kleppmann.com/2014/11/25/hermitage-testing-the-i-in-acid.html). Tests de isolation em bancos populares.
