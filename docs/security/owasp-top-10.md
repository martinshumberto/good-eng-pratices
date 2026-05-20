# OWASP Top 10

> **TL;DR.** Lista publicada pela OWASP a cada 3–4 anos das **10 categorias de risco** mais críticas em aplicações web. Não é checklist completo, é o **mínimo absoluto** a entender. A versão atual é a de **2021**.

## O quê

A **[Open Web Application Security Project (OWASP)](https://owasp.org)** é uma organização aberta dedicada a segurança de aplicações. Seu produto mais conhecido é o **OWASP Top 10**, lista priorizada das categorias de risco mais críticas, compiladas a partir de dados de centenas de organizações.

A versão atual ([Top 10, 2021](https://owasp.org/Top10/)):

1. **A01, Broken Access Control**
2. **A02, Cryptographic Failures**
3. **A03, Injection**
4. **A04, Insecure Design**
5. **A05, Security Misconfiguration**
6. **A06, Vulnerable and Outdated Components**
7. **A07, Identification and Authentication Failures**
8. **A08, Software and Data Integrity Failures**
9. **A09, Security Logging and Monitoring Failures**
10. **A10, Server-Side Request Forgery (SSRF)**

## Por quê

Sem um framework comum, conversas de segurança rapidamente caem em opinião. O OWASP Top 10 oferece:

- **Vocabulário compartilhado.** "Isso é A01" comunica mais que "isso é uma falha de autorização".
- **Priorização baseada em dados.** A lista vem de incidentes reais.
- **Ponto de partida para revisão.** Antes de criar checklist próprio, cubra esses 10.
- **Compliance.** SOC 2, PCI-DSS, ISO 27001 frequentemente referenciam.

**Importante:** Top 10 **não é** completo. É o piso, não o teto. Para cobertura ampla, ver [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/).

## Como aplicar

### A01: Broken Access Control

**O quê.** Usuário consegue acessar dados ou ações que não deveria. **#1 mais comum.** Frequentemente trivial.

**Exemplos:**

```
GET /api/users/42/orders   ← legítimo
GET /api/users/43/orders   ← IDOR, substitui ID, vê dados de outro
```

```ts
// ❌ Filtra só por ID, sem checar owner
async function getOrder(id: string) {
  return db.orders.findById(id);
}

// ✅ Filtra por owner + ID
async function getOrder(id: string, userId: string) {
  return db.orders.findOne({ id, userId });
}
```

**Mitigações:**

- **Deny by default.** Sem permissão explícita = negado.
- **Verifique authz em **toda** rota**: não só no controller, no nível da query.
- **Não confie em IDs do cliente.** Re-extraia owner do JWT/sessão.
- **Row-level security** no banco (PostgreSQL RLS) como defesa em profundidade.
- **Logs de tentativas de acesso negado.**

Ver [autenticação e autorização](../backend/authentication-authorization.md).

### A02: Cryptographic Failures

**O quê.** Dados sensíveis expostos por uso incorreto (ou falta) de criptografia. Renomeado de "Sensitive Data Exposure" (2017), o foco antes era no resultado; agora é na causa.

**Exemplos:**

- Senhas armazenadas com MD5/SHA-1 (sem salt, sem stretching).
- HTTPS desabilitado ou com TLS antigo (≤ 1.1).
- Dados sensíveis em logs.
- Chaves de criptografia em código-fonte.

**Mitigações:**

- **HTTPS em tudo.** TLS 1.2+ obrigatório; redirecione HTTP. Use [Mozilla SSL Config Generator](https://ssl-config.mozilla.org).
- **Hash de senhas com Argon2, scrypt, bcrypt.** Nunca MD5/SHA puro. Ver [Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
- **Criptografia simétrica:** AES-GCM-256.
- **Não invente criptografia.** Use bibliotecas estabelecidas, [libsodium](https://libsodium.org), `crypto` nativo.
- **Encryption-at-rest** para dados sensíveis (KMS).
- **HSTS** + Secure cookies.

### A03: Injection

**O quê.** Input do usuário é interpretado como código/comando, SQL injection, NoSQL injection, command injection, LDAP injection, XSS, XXE.

**Exemplos:**

```ts
// ❌ SQL injection
db.query(`SELECT * FROM users WHERE email = '${email}'`);
// email = "' OR '1'='1"
// SELECT * FROM users WHERE email = '' OR '1'='1' → vaza tudo

// ✅ Prepared statement
db.query('SELECT * FROM users WHERE email = $1', [email]);
```

```ts
// ❌ Command injection
exec(`convert ${userInput} output.jpg`);

// ✅ Use API segura, valide input
execFile('convert', [sanitizedPath, 'output.jpg']);
```

**Mitigações:**

- **Prepared statements / parameterized queries** sempre. ORM bem usado já protege.
- **Escape de output** quando renderizar HTML (frameworks como React fazem por default; cuidado com `dangerouslySetInnerHTML`).
- **Validação de input** com [parse don't validate](../backend/input-validation.md).
- **Princípio do least privilege** no DB, o app não deve usar usuário root.
- **CSP (Content Security Policy)** para mitigar XSS.

### A04: Insecure Design

**O quê.** Falhas que vêm da **arquitetura**, não de bugs de implementação. Categoria nova em 2021.

**Exemplos:**

- Sistema que aceita recuperação de senha enviando código por SMS sem rate limit → atacante força bruta.
- Endpoint que devolve quantos passos restam ("3 tentativas restantes") sem outras proteções → ajuda atacante.
- Sistema que não diferencia "usuário não existe" de "senha errada" → enumeração.

**Mitigações:**

- **[Threat modeling](./threat-modeling.md)** no design, pense em ataques antes de codar.
- **Princípios de design seguro:**
  - Least privilege.
  - Defense in depth (múltiplas camadas).
  - Fail securely (erro não vaza estado).
  - Separation of duties.
  - Economy of mechanism (simples = menos bug).
- **Revisão de design** em mudanças significativas.

### A05: Security Misconfiguration

**O quê.** Configurações inseguras ou padrão, em servidor, framework, container, cloud.

**Exemplos:**

- Bucket S3 público.
- Endpoint `/debug` ou `/admin` exposto.
- Stack traces em produção.
- Senhas default não trocadas.
- Headers de segurança ausentes (HSTS, CSP, X-Frame-Options).

**Mitigações:**

- **Hardening checklist** por componente. CIS Benchmarks ([cisecurity.org/cis-benchmarks](https://www.cisecurity.org/cis-benchmarks)).
- **Headers de segurança:** use [helmet](https://helmetjs.github.io) ou equivalente.
- **Scan de configuração**: [trivy](https://github.com/aquasecurity/trivy), [tfsec](https://github.com/aquasecurity/tfsec), [Checkov](https://github.com/bridgecrewio/checkov).
- **Princípio**: o que não precisa estar exposto, não exponha.

### A06: Vulnerable and Outdated Components

**O quê.** Você usa libraries com vulnerabilidades conhecidas. **Frequentemente o mais explorável.**

**Exemplos:**

- `npm audit` mostra HIGH/CRITICAL e ninguém atualizou.
- Imagem base do container desatualizada.
- Dependência transitiva com CVE crítico.

**Mitigações:**

- **Inventário de dependências**: SBOM (Software Bill of Materials).
- **Scanners automáticos no CI:** [Dependabot](https://docs.github.com/en/code-security/dependabot), [Snyk](https://snyk.io), [Trivy](https://github.com/aquasecurity/trivy), [Renovate](https://www.mend.io/renovate/).
- **Atualizações regulares**: não acumule. Pequenas, frequentes.
- **Lock files versionados** (package-lock.json, Cargo.lock).
- **Remova o que não usa.**

### A07: Identification and Authentication Failures

**O quê.** Falhas em autenticar usuários corretamente.

**Exemplos:**

- Senhas fracas permitidas.
- Sem rate limit em login → brute force.
- Tokens previsíveis ou sem expiração.
- Session fixation.
- "Lembre-se de mim" mal implementado.

**Mitigações:**

- **Senhas fortes** + verificar contra [haveibeenpwned API](https://haveibeenpwned.com/API/v3).
- **MFA** quando o risco justificar.
- **Rate limit** em endpoints sensíveis (login, signup, recuperação).
- **Tokens com TTL apropriado.**
- **Senha em hash adaptativo** (Argon2).
- **WebAuthn / passkeys** para autenticação moderna sem senha.

Ver [Auth Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html).

### A08: Software and Data Integrity Failures

**O quê.** Confiança em dados/código sem verificar integridade. Categoria nova em 2021, motivada por **supply chain attacks** (SolarWinds, log4shell).

**Exemplos:**

- Auto-update sem verificação de assinatura.
- CI/CD que executa código de PRs sem isolamento.
- Pipeline que injeta env vars sensíveis em logs.
- Dependências de fontes não-confiáveis sem verificação.

**Mitigações:**

- **Subresource Integrity (SRI)** para assets externos.
- **Sign images / artifacts** (cosign, sigstore).
- **Verificar checksums** em downloads.
- **Pinned dependencies** (versão exata em lock files).
- **Restrição em CI/CD**: secrets só onde precisa, sem expor em logs.
- **SLSA framework** ([slsa.dev](https://slsa.dev)) para supply chain security.

### A09: Security Logging and Monitoring Failures

**O quê.** Sem logs ou monitoramento adequado, ataques passam despercebidos.

**Exemplos:**

- Logins falhos não logados.
- Sem alerta para tentativas suspeitas (vários endpoints retornando 403).
- Logs guardados localmente (sumindo no scale).
- Sem audit log para ações sensíveis.

**Mitigações:**

- **Log eventos de segurança:** login (sucesso e falha), MFA setup, password change, role change, deletion.
- **Audit log imutável** para ações sensíveis.
- **Alertas em padrões anômalos**: picos de 403, login de localização nova.
- **Centralized logging** ver [structured logging](../observability/structured-logging.md).
- **Sem dados sensíveis em logs** (PII, tokens, senhas).
- **Retenção alinhada com compliance.**

### A10: Server-Side Request Forgery (SSRF)

**O quê.** Atacante força o servidor a fazer request para destino que ele escolhe, incluindo recursos internos.

**Exemplos:**

```
// App permite "buscar imagem por URL"
GET /preview?url=http://example.com/img.jpg   ← legítimo
GET /preview?url=http://169.254.169.254/latest/meta-data/   ← AWS metadata!
GET /preview?url=http://internal-db:5432       ← acessa rede interna
```

**Mitigações:**

- **Allowlist** de hosts/protocolos.
- **Validar URLs antes de fazer request.**
- **Não seguir redirects automaticamente** (ou validar destino do redirect).
- **Network segmentation**: frontends não devem ter acesso a redes internas sensíveis.
- **Bloquear acesso a IPs metadata** (169.254.169.254, AWS/GCP/Azure).
- **DNS rebinding protection.**

## Boas práticas gerais

### Princípios universais

- **Least privilege.** Cada componente tem só as permissões mínimas.
- **Defense in depth.** Camadas múltiplas. Quando uma falha, outra protege.
- **Fail securely.** Erro → estado seguro (não vaza dados, não abre acesso).
- **Don't trust input.** Validate everything at trust boundaries.
- **Secure defaults.** Configuração inicial é a mais restritiva.
- **Keep it simple.** Complexidade é inimiga de segurança.
- **Audit and review.** Logs + revisão regular.

### Onde investir esforço

| Prioridade | Foco |
|---|---|
| **Alto** | A01 (autorização), A03 (injection), A02 (cripto), A07 (auth) |
| **Médio** | A04 (design), A05 (config), A06 (deps), A08 (integridade) |
| **Contínuo** | A09 (logs), A10 (SSRF se aplicável) |

A01 e A03 sozinhos costumam responder por boa parte dos incidentes.

### Cultura de segurança

- **Threat modeling** integrado ao design.
- **Security review** em PRs significativos.
- **Pentest periódico** (interno e externo).
- **Bug bounty** se for B2C.
- **Treinamento**: Top 10 deveria ser conhecimento básico de todo dev.

## Quando *não* usar

OWASP Top 10 deve ser **mínimo**, não substituto de programa de segurança. Não use isoladamente quando:

- **Sistema é missão-crítica**: use ASVS (Application Security Verification Standard) que é mais completo.
- **Você precisa de compliance específico**: PCI-DSS, HIPAA, SOC 2 têm seus próprios requisitos.
- **Domínio é particular**: APIs, mobile, IoT têm OWASP Top 10 dedicados.

## Conceitos relacionados

- [Autenticação e autorização](../backend/authentication-authorization.md)
- [Validação de entrada](../backend/input-validation.md), combate injection.
- [Secrets management](./secrets-management.md)
- [Threat modeling](./threat-modeling.md)
- [Structured logging](../observability/structured-logging.md): A09.

## Referências

- **Site.** [OWASP Top 10 (2021)](https://owasp.org/Top10/). Versão atual.
- **Site.** [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org). Guias práticos por tópico.
- **Site.** [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/). Padrão mais completo de verificação.
- **Site.** [OWASP API Security Top 10](https://owasp.org/API-Security/). Para APIs.
- **Site.** [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/). Para mobile.
- **Livro.** Dafydd Stuttard & Marcus Pinto, *The Web Application Hacker's Handbook*, 2ª ed. (Wiley, 2011). Vulnerabilidades web em profundidade.
- **Livro.** Tanya Janca, *Alice and Bob Learn Application Security* (Wiley, 2020). Acessível para devs.
- **Site.** [PortSwigger Web Security Academy](https://portswigger.net/web-security). Tutoriais gratuitos práticos.
- **Documentação.** [Mozilla Developer: Web Security](https://developer.mozilla.org/en-US/docs/Web/Security).
