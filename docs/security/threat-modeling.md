# Threat Modeling

> **TL;DR.** Pensar como atacante **antes** de codar. Quatro perguntas: *O que estamos construindo? O que pode dar errado? O que vamos fazer a respeito? Fizemos um bom trabalho?* STRIDE é o framework mais usado. Faça em equipe, escreva o resultado, revise quando o sistema mudar.

## O quê

**Threat modeling** é um processo estruturado para **identificar ameaças** a um sistema **antes** que se manifestem em produção. Em vez de descobrir vulnerabilidades em pentest (caro, tardio), você as antecipa em design.

**Adam Shostack** consolidou o framework moderno em *Threat Modeling: Designing for Security* (Wiley, 2014). O **Threat Modeling Manifesto** ([threatmodelingmanifesto.org](https://www.threatmodelingmanifesto.org), 2020) sintetizou os princípios.

As quatro perguntas centrais (Shostack):

1. **O que estamos construindo?**: modelar o sistema.
2. **O que pode dar errado?**: identificar ameaças (STRIDE, attack trees).
3. **O que vamos fazer?**: definir mitigações.
4. **Fizemos um bom trabalho?**: validar o threat model.

## Por quê

Sem threat modeling, segurança é reativa:

- Pentest descobre vulnerabilidade em produção → custa caro corrigir.
- Bug bounty paga por algo que poderia ter sido evitado no design.
- Compliance reprova arquitetura que ficou pronta sem revisão.

Com threat modeling:

- **Bugs prevenidos custam ~100× menos** que descobertos depois (estimativa clássica de engenharia).
- **Decisões arquiteturais informadas**: escolha de tecnologia considera superfície de ataque.
- **Conversa estruturada** em vez de "acho que isso é seguro".
- **Compliance e auditoria**: registros documentam diligência.

> "All models are wrong. Some are useful."
> (George E. P. Box (citado em Threat Modeling Manifesto))

Threat models não são verdade absoluta; são ferramentas para conversa estruturada.

## Como aplicar

### 1) O que estamos construindo?: Diagramar

Use **data flow diagrams (DFD)** ou [C4](../architecture/c4-model.md) para mapear:

- **Componentes**: apps, serviços, bancos, filas.
- **Atores**: usuários, sistemas externos, atacantes potenciais.
- **Fluxos de dados**: quem envia o quê para quem.
- **Trust boundaries**: onde a confiança muda (internet ↔ DMZ ↔ rede interna ↔ banco).

```
[Cliente Web]
     │  (HTTPS, Trust Boundary 1)
     ▼
[API Gateway]
     │  (mTLS, Trust Boundary 2)
     ▼
[Orders Service]  ←──(SQL/TLS)──> [Database]
     │
     │  (HTTPS, Trust Boundary 3)
     ▼
[Stripe API]
```

As **trust boundaries** são fundamentais, é nelas que ataques têm mais chance de pousar.

### 2) O que pode dar errado?: STRIDE

[STRIDE](https://en.wikipedia.org/wiki/STRIDE_(security)) é o framework da Microsoft (Praerit Garg & Loren Kohnfelder, 1999). Seis categorias mnemônicas:

| Sigla | Significa | Viola | Exemplo |
|---|---|---|---|
| **S**poofing | Falsificação de identidade | Autenticação | Atacante se passa por outro usuário |
| **T**ampering | Alteração de dados | Integridade | Modifica payload em trânsito |
| **R**epudiation | Negação de ação | Não-repúdio | Usuário nega ter feito ação |
| **I**nformation Disclosure | Vazamento | Confidencialidade | Dados expostos sem autorização |
| **D**enial of Service | Negação de serviço | Disponibilidade | DDoS, exhaustion |
| **E**levation of Privilege | Escalada de privilégio | Autorização | Usuário comum vira admin |

**Aplicação prática:**

Para **cada componente** e **cada fluxo de dados**, percorra as 6 categorias:

#### Exemplo: endpoint POST /orders

| STRIDE | Ameaça | Mitigação |
|---|---|---|
| **S** | Atacante usa token roubado | JWT com TTL curto; MFA em login |
| **T** | Atacante altera preço no payload | Servidor recalcula preço; client não envia |
| **R** | Usuário nega ter feito o pedido | Audit log com timestamp, IP, hash do request |
| **I** | Endpoint retorna pedidos de outros | Authz por owner; filtro na query |
| **D** | Atacante faz milhares de requests | Rate limiting; idempotency key |
| **E** | Bug deixa user comum ter `role: admin` | Validação server-side; deny by default |

### Outras técnicas

#### Attack Trees

Estrutura hierárquica do objetivo do atacante:

```
Objetivo: roubar dados de um usuário
├── via login fraudulento
│   ├── credential stuffing
│   ├── phishing
│   └── brute force (sem rate limit)
├── via session hijacking
│   ├── XSS para roubar cookie
│   └── network sniffing (sem HTTPS)
└── via privilege escalation
    ├── IDOR (sem authz)
    └── SQL injection
```

Cada folha vira mitigação.

#### PASTA (Process for Attack Simulation and Threat Analysis)

Mais elaborado (7 estágios. Bom para sistemas críticos ou regulados. Ver [VerSprite) PASTA](https://versprite.com/blog/what-is-pasta-threat-modeling/).

#### MITRE ATT&CK

[MITRE ATT&CK](https://attack.mitre.org) catalogou táticas, técnicas e procedimentos (TTPs) que atacantes reais usam. Útil para threat modeling em ambientes que precisam de detecção (SOC), não só prevenção.

### 3) O que vamos fazer?: Mitigações

Para cada ameaça identificada, decida:

| Estratégia | Quando |
|---|---|
| **Mitigate** | Reduzir probabilidade ou impacto. Padrão. |
| **Eliminate** | Remover a causa raiz (ex.: não armazenar o dado sensível). |
| **Transfer** | Passar a responsabilidade (ex.: usar tokenização do PCI-DSS provider). |
| **Accept** | Aceitar conscientemente (risco baixo, custo de mitigação alto). Documente. |

Não confunda "aceitar" com "ignorar". Aceitar é decisão **explícita** com registro.

### 4) Fizemos um bom trabalho?: Validação

- **Revisão por pares**: outra pessoa olha o threat model.
- **Pentest direcionado**: confirma que mitigações funcionam.
- **Revisão periódica**: sistemas mudam; ameaças mudam.

### Integração no ciclo de desenvolvimento

#### Quando fazer

- **Início de projeto**: base do design.
- **Mudança arquitetural significativa**: novo microsserviço, nova integração externa.
- **Mudança no modelo de ameaça**: entrar em compliance, expandir para nova região.
- **Post-incident**: entender por que algo passou.

#### Quem participa

- **Devs / arquitetos**: conhecem o sistema.
- **Security**: fornece expertise em ameaças.
- **Produto**: entende requisitos e trade-offs.

Não é exercício solo de "o security review". É colaborativo.

#### Quanto tempo

- **Sistema novo significativo:** workshop de 2–4 horas em equipe.
- **Mudança em sistema existente:** 30 min a 1 hora focada.
- **Revisão periódica:** 1 hora trimestral.

Threat modeling **não precisa ser longo**: precisa ser **regular**.

### Saída: o que documentar

```markdown
# Threat Model: Orders Service v1.0

## Sistema
[Diagrama C4 / DFD]

## Atores e Trust Boundaries
- Usuário web (externo)
- API Gateway (DMZ)
- Orders Service (rede interna)
- Banco Postgres (rede privada)
- Stripe (externo confiável)

## Ameaças identificadas

### T01: Spoofing: Token roubado em XSS
- **Mitigação:** httpOnly cookies; CSP rigoroso.
- **Residual risk:** Aceito.

### T02: IDOR em GET /orders/:id
- **Mitigação:** Authz por owner na query.
- **Verificação:** Test E2E `orders-authz.spec.ts`.

### T03: SQL injection
- **Mitigação:** Prisma ORM + queries parametrizadas; sem string concat.

## Decisões deliberadas (riscos aceitos)
- DDoS volumétrico, delegado ao Cloudflare; sem proteção própria.

## Próxima revisão: 2025-Q2
```

### Ferramentas

- **[Microsoft Threat Modeling Tool](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool)**: gratuita: STRIDE-focada.
- **[OWASP Threat Dragon](https://owasp.org/www-project-threat-dragon/)**: open source, web-based.
- **[IriusRisk](https://www.iriusrisk.com)**: comercial, automatizado.
- **[PyTM](https://github.com/izar/pytm)**: pythonic threat models como código.
- **Excalidraw + checklist STRIDE**: começo simples e perfeitamente válido.

### Anti-padrões

#### Threat model "ritual"

Documento gerado para passar auditoria, sem genuína análise. Pior que ausência, gera **falsa segurança**.

#### Threat model isolado

Security faz sozinho, devs não veem nem usam. Não pega o conhecimento da equipe que mais conhece o sistema.

#### Demais ameaças, nenhuma ação

Lista de 200 ameaças sem priorização. Documento vira referência cemiterial.

#### Sem revisão após mudança

Sistema evoluiu; threat model não. Mitigações antigas não se aplicam mais; novas superfícies passam.

### Boas práticas

- **Comece pelo crítico.** Sistemas que tratam dados sensíveis primeiro.
- **Documento curto.** 1–2 páginas por sistema. Lista priorizada das top 10 ameaças.
- **Revisão como parte de ADR.** Mudanças arquiteturais significativas (ver [ADRs](../architecture/architecture-decision-records.md)) incluem nota sobre threat model.
- **Linkar mitigações a testes.** Quando possível, teste de segurança automatizado verifica a mitigação.

## Quando *não* usar

- **Scripts triviais.** Threat model não se paga.
- **POCs descartáveis.** Não cria valor.
- **Como substituto de pentest.** Threat model identifica; pentest valida. Os dois.

## Conceitos relacionados

- [OWASP Top 10](./owasp-top-10.md), categorias comuns que aparecem em threat models.
- [Princípios de Authn/Authz](./authn-vs-authz.md).
- [Secrets management](./secrets-management.md).
- [Arquitetura (ADRs](../architecture/architecture-decision-records.md)) frequentemente registra decisões pós-threat model.

## Referências

- **Site.** [Threat Modeling Manifesto](https://www.threatmodelingmanifesto.org). Síntese de princípios por especialistas.
- **Livro.** Adam Shostack, *Threat Modeling: Designing for Security* (Wiley, 2014). Referência canônica.
- **Livro.** Izar Tarandach & Matt Coles, *Threat Modeling: A Practical Guide for Development Teams* (O'Reilly, 2020). Foco em equipes ágeis.
- **Site.** [shostack.org](https://shostack.org). Material atualizado de Adam Shostack.
- **Documentação.** [OWASP Threat Modeling Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html).
- **Documentação.** [Microsoft: STRIDE](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats).
- **Site.** [MITRE ATT&CK](https://attack.mitre.org). Catálogo de TTPs.
- **Site.** [VerSprite: PASTA](https://versprite.com/blog/what-is-pasta-threat-modeling/).
- **Documentação.** [Microsoft Threat Modeling Tool](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool).
