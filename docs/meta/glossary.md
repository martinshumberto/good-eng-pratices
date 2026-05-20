# Glossário

Termos técnicos recorrentes neste repositório. Quando um documento usa um destes termos, prefere linkar para cá em vez de redefinir.

> **Em construção.** Adicione um termo quando notar que ele aparece em mais de um documento sem definição.

---

## A

**ADR (Architecture Decision Record).** Registro curto que documenta uma decisão arquitetural significativa: contexto, opção escolhida, alternativas consideradas, consequências. Ver [ADRs](../architecture/architecture-decision-records.md).

**Acoplamento (*coupling*).** Grau de interdependência entre módulos. Alto acoplamento dificulta mudança isolada. Ver [Coesão e acoplamento](../foundations/cohesion-coupling.md).

## C

**Coesão (*cohesion*).** Grau em que os elementos dentro de um módulo pertencem juntos. Alta coesão é desejável.

## D

**DDD (Domain-Driven Design).** Abordagem de modelagem centrada no domínio do negócio, definida por Eric Evans. Ver [DDD](../architecture/domain-driven-design.md).

## I

**Idempotência.** Propriedade de uma operação que pode ser executada várias vezes com o mesmo efeito. Crítica em APIs distribuídas. Ver [Idempotência](../backend/idempotency.md).

## L

**LSP (Liskov Substitution Principle).** O "L" do SOLID: objetos de uma subclasse devem ser substituíveis pelos da superclasse sem alterar a correção. Ver [SOLID](../foundations/solid.md).

## M

**MISU (Make Illegal States Unrepresentable).** Usar o sistema de tipos para tornar combinações inválidas de estado impossíveis de existir. Ver [MISU](../foundations/make-illegal-states-unrepresentable.md).

## S

**SLA / SLO / SLI.** *Service Level Agreement / Objective / Indicator*. Ver [SLO/SLI/SLA](../observability/slo-sli-sla.md).

**SOLID.** Conjunto de cinco princípios de design OO: Single Responsibility, Open/Closed, Liskov, Interface Segregation, Dependency Inversion. Ver [SOLID](../foundations/solid.md).
