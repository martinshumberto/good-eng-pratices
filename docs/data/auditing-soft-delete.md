# Auditoria e Soft Delete

> **TL;DR.** Toda tabela deve ter `created_at`, `updated_at` e `deleted_at`. Use `deleted_at` para exclusão lógica e *expurgo físico* em rotina separada, com critérios e prazo claros.

## O quê

**Auditoria mínima** é o conjunto de colunas que todo registro deve ter para responder a três perguntas básicas:

- *Quando foi criado?*, `created_at`
- *Quando foi alterado pela última vez?*, `updated_at`
- *Foi excluído? Quando?*, `deleted_at`

**Soft delete** é o padrão de marcar um registro como excluído sem removê-lo fisicamente da tabela. O registro continua existindo, apenas filtrado das queries normais.

Em alguns contextos, vale também rastrear *quem* fez a mudança: `created_by`, `updated_by`, `deleted_by`: geralmente o `id` de um usuário/profile.

## Por quê

### Auditoria

- **Diagnóstico.** "Esse pedido foi alterado quando?", pergunta trivial só se `updated_at` existir.
- **Cache busting / replicação.** `updated_at` permite *change data capture* incremental sem mudar a aplicação.
- **Auditoria regulatória.** LGPD, SOX, normas setoriais geralmente exigem trilha mínima.

### Soft delete

- **Reversibilidade.** Erros operacionais (delete acidental, sincronização errada) podem ser revertidos.
- **Integridade referencial.** Outros registros podem ainda apontar para o item "excluído"; mantê-lo evita FK órfãs.
- **Histórico.** Análises retroativas, relatórios.

Soft delete tem **custos** reais, não é gratuito (ver "Quando não usar").

## Como aplicar

### Estrutura base

```sql
CREATE TABLE users (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_int     BIGSERIAL UNIQUE,
  email      VARCHAR(255) NOT NULL,
  -- demais colunas

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);
```

Convenções:

- **`TIMESTAMPTZ`** (com fuso), nunca `TIMESTAMP` sem fuso.
- **`DEFAULT NOW()`** em `created_at` e `updated_at`.
- **`deleted_at NULL`** = ativo; valor presente = excluído.

### Auto-atualização do `updated_at`

Atualizar via aplicação está sujeito a esquecimento. Use trigger no banco como rede de segurança:

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

Repita para cada tabela. ORMs como Prisma, TypeORM, GORM normalmente cuidam disso, mas a trigger garante mesmo se alguém usar SQL direto.

### Auditoria por usuário

Quando vale a pena registrar quem fez a alteração:

```sql
ALTER TABLE users
  ADD COLUMN created_by UUID,
  ADD COLUMN updated_by UUID;
```

`created_by` e `updated_by` apontam para o `id` de quem realizou a operação. Como o usuário muitas vezes vive em outro schema/serviço, mantenha como `UUID` sem FK.

### Soft delete: leitura

Filtre `deleted_at IS NULL` em todas as queries normais. ORMs maduros fazem isso automaticamente:

```ts
// Prisma com middleware
prisma.$use(async (params, next) => {
  if (params.action === 'findMany' || params.action === 'findFirst') {
    params.args ??= {};
    params.args.where = { deleted_at: null, ...params.args.where };
  }
  return next(params);
});
```

Em SQL puro, use uma **view** para representar "registros vivos":

```sql
CREATE VIEW users_active AS
  SELECT * FROM users WHERE deleted_at IS NULL;
```

### Soft delete: escrita

```ts
// Em vez de DELETE
await db.users.update({
  where: { id },
  data:  { deleted_at: new Date() },
});
```

Quando precisar de delete *físico* (LGPD, expurgo de logs, dados sensíveis), exponha um caminho explícito:

```ts
async function hardDelete(id: string) {
  await db.users.delete({ where: { id } });
  await audit.log({ action: 'hard_delete', table: 'users', id });
}
```

### Constraints e índices com soft delete

Cuidado: `UNIQUE (email)` impede recriar um usuário com o mesmo email após exclusão. Use **índice único parcial** para considerar só os ativos:

```sql
CREATE UNIQUE INDEX users_email_unique
  ON users (email)
  WHERE deleted_at IS NULL;
```

### Expurgo físico

Soft delete sem rotina de expurgo vira lixo acumulado. Defina:

- **Critério**: qual é o tempo de retenção? 30 dias? 1 ano?
- **Disparador**: cron, job manual, evento de aniversário?
- **Cuidados**: registros referenciados por outros (FK) precisam ser tratados antes.

```sql
-- Job diário: expurgar usuários soft-deletados há mais de 90 dias
DELETE FROM users
WHERE deleted_at < NOW() - INTERVAL '90 days';
```

### LGPD / GDPR: direito ao esquecimento

Soft delete **não cumpre** "direito ao esquecimento". Para requests legais de exclusão:

1. Hard delete (ou anonimização) do registro principal.
2. Anonimização em backups e logs.
3. Registro auditável da operação.

## Quando *não* usar

### Soft delete

- **Volume massivo de inserts/deletes.** A tabela cresce indefinidamente; queries degradam. Use particionamento ou audit log separado.
- **Dados altamente sensíveis (PII, segredos, dados de pagamento).** Manter mais tempo aumenta superfície de ataque e risco de vazamento. Delete físico + log de auditoria.
- **Tabelas append-only (log, eventos, métricas).** A operação natural é insert; "delete" não faz sentido conceitualmente.

### Campos de auditoria

- **Tabelas de cache / *materialized views*.** Não precisam, são derivadas, podem ser recriadas.
- **Snapshots históricos.** Já carregam o tempo na chave; auditoria seria redundante.

## Conceitos relacionados

- [Modelagem relacional](./relational-modeling.md)
- [Identificadores: UUID vs serial](./identifiers-uuid-vs-serial.md)
- [Migrations](./migrations.md)

## Referências

- **Livro.** Martin Fowler, *Patterns of Enterprise Application Architecture* (Addison-Wesley, 2002). Capítulo "Audit Log" / "Temporal Patterns".
- **Artigo.** Udi Dahan, ["Don't Delete: Just Don't"](https://udidahan.com/2009/09/01/dont-delete-just-dont/) (2009). Defesa contundente de soft delete como prática padrão.
- **Documentação.** [Prisma: Soft delete middleware](https://www.prisma.io/docs/orm/prisma-client/client-extensions/middleware/soft-delete-middleware) (legacy, ainda referência).
- **Artigo.** [Brent Ozar: Implementing Soft Deletes in SQL Server](https://www.brentozar.com/archive/2017/01/implementing-soft-deletes/).
