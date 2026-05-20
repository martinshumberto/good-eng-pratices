# Princípios de Segurança em Authn/Authz

> **TL;DR.** Authn (quem você é) e authz (o que você pode) são problemas diferentes com ataques diferentes. Aplique **least privilege**, **defense in depth**, **deny by default** e **separation of duties**. A implementação tática vive em [autenticação e autorização](../backend/authentication-authorization.md); este documento foca nos princípios.

## O quê

Este documento complementa o doc técnico de [autenticação e autorização](../backend/authentication-authorization.md), focando nos **princípios de segurança** que sustentam a implementação:

- **Por que** authn e authz são separados.
- **Que classe de ataques** cada um combate.
- **Princípios de design seguro** que se aplicam aos dois.
- **Onde** as duas falham historicamente.

A implementação prática (OAuth2, JWT, RBAC) está no doc técnico. Este documento é sobre **mentalidade**.

## Por quê

A maioria dos incidentes graves vem de **misturar** ou **subestimar** os dois:

- "Eu validei o login, então posso confiar no que o usuário pede" → **autorização ausente**. O que mais quebra na prática (A01 do OWASP).
- "Tem token, então é seguro" → **token sem validação de scope**.
- "É um endpoint interno" → **trust boundary errada**. Atacante que pula essa fronteira tem acesso pleno.

Tratá-los como **camadas independentes** com **princípios próprios** evita esses erros.

## Como aplicar

### Os ataques que cada um previne

#### Ataques contra autenticação

- **Brute force**: testar combinações de senha. Mitigação: rate limiting, lockout, MFA.
- **Credential stuffing**: usar senhas vazadas de outros serviços. Mitigação: senhas únicas (havibeenpwned), MFA.
- **Phishing**: enganar o usuário a entregar credenciais. Mitigação: WebAuthn/passkeys (sem senha para roubar), educação.
- **Session hijacking**: roubar cookie de sessão ativa. Mitigação: HTTPS obrigatório, cookies HttpOnly + Secure + SameSite, IP/UA pinning.
- **Token theft**: roubar JWT/access token. Mitigação: TTL curto, refresh rotation, escopo mínimo.

#### Ataques contra autorização

- **Insecure Direct Object Reference (IDOR)**: trocar ID no request para acessar dados de outro. Mitigação: sempre filtrar por owner.
- **Privilege escalation**: usuário comum vira admin (vertical) ou um usuário vira outro do mesmo nível (horizontal). Mitigação: deny by default, role checking explícito.
- **Forced browsing**: acessar URLs administrativas sem checagem. Mitigação: middleware de authz em todas as rotas.
- **JWT manipulation**: alterar payload do JWT (algoritmo none, weak secret). Mitigação: verificar assinatura sempre, never accept `alg: none`.
- **Confused deputy**: sistema executa ação privilegiada em nome do atacante. Mitigação: validação de identidade do solicitante a cada chamada.

### Princípios de design seguro

#### 1) Least Privilege

> "Every program and every user should operate with the least amount of privilege necessary."
> (Jerome Saltzer & Michael Schroeder, *"The Protection of Information in Computer Systems"* (1975))

Cada entidade (usuário, serviço, processo) deve ter apenas as permissões **estritamente necessárias** para fazer seu trabalho.

```ts
// ❌ App usa user com privilégio de DROP/CREATE
const db = new Pool({ user: 'postgres', password: '...' });

// ✅ App usa user limitado às tabelas que precisa
const db = new Pool({ user: 'orders_app', password: '...' });
// orders_app: GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO orders_app
//             (sem DDL, sem acesso a outras tabelas)
```

Aplicações na prática:

- **DB users**: um por serviço, permissões mínimas.
- **API keys**: escopos específicos (`read:orders`, não `*:*`).
- **Cloud IAM roles**: por workload, não compartilhadas.
- **Roles de usuários**: definidas por **necessidade**, não por "conveniência".

#### 2) Defense in Depth

Múltiplas camadas de segurança. Quando uma falha, outra protege.

```
Camada 1: WAF/CDN bloqueia padrões maliciosos
Camada 2: Authn middleware valida JWT
Camada 3: Authz middleware verifica permissão
Camada 4: Query no DB filtra por owner
Camada 5: Row Level Security no Postgres
Camada 6: Audit log registra acesso
```

Cada camada não confia nas outras. Falha de uma → as demais continuam protegendo.

```ts
// ❌ Confia que authz no controller é suficiente
async function getOrder(orderId: string) {
  return db.orders.findById(orderId);   // sem checagem
}

// ✅ Defense in depth, também filtra na query
async function getOrder(orderId: string, userId: string) {
  return db.orders.findOne({ id: orderId, userId });
}
```

#### 3) Deny by Default

Sem permissão explícita = sem acesso.

```ts
// ❌ Allow by default
function canAccess(user, resource) {
  if (resource.isPublic) return false;       // exceção
  if (user.isBlocked) return false;          // exceção
  return true;                                // padrão: permitido
}

// ✅ Deny by default
function canAccess(user, resource) {
  if (user.roles.includes('admin')) return true;
  if (resource.ownerId === user.id) return true;
  if (resource.isPublic) return true;
  return false;                               // padrão: negado
}
```

Aplicação:

- **Firewall:** drop por default, allow rules específicas.
- **API:** rota não-registrada = 404.
- **Permissions:** novo recurso = sem acesso até decisão explícita.

#### 4) Separation of Duties

Operações críticas requerem **múltiplos atores** ou **múltiplas verificações**.

Exemplos:

- **Deploy em produção** requer aprovação de outra pessoa (code review + deploy approval).
- **Transferência financeira grande** requer dupla aprovação.
- **Mudança de role para admin** requer outro admin existente.
- **Cliente não pode aprovar próprio pedido.**

Em sistemas autênticos, modele essas regras explicitamente, não como prática informal.

#### 5) Fail Securely

Quando algo dá errado, o sistema deve **defaultar para o estado seguro**.

```ts
// ❌ Permite acesso em caso de erro
try {
  return await checkPermission(user, resource);
} catch {
  return true;   // erro → libera
}

// ✅ Nega em caso de erro
try {
  return await checkPermission(user, resource);
} catch {
  return false;  // erro → bloqueia
}
```

Aplicação:

- **Erro no IAM provider** → todos os requests pendentes → negar (não cachear "allowed").
- **Erro na verificação de assinatura** → rejeitar.
- **Timeout em authz service** → negar (ou retry com circuit breaker).

#### 6) Trust Boundaries Explícitas

Identifique onde a confiança **muda**:

```
[Internet] ──── (boundary 1) ────> [API Gateway]
                                         │
                                  (boundary 2)
                                         │
                                  [Microservices internos]
                                         │
                                  (boundary 3)
                                         │
                                  [Database]
```

Em cada boundary:

- **Valide tudo.** Não confie no que vem do lado anterior.
- **Re-autorize.** Microsserviço interno não confia que o gateway validou.
- **Logue cruzamento.** Auditoria depende.

> "Never trust user input."
> (Princípio universal)

#### 7) Don't Trust the Client

Cliente é controlado pelo usuário. Tudo que vem dele pode ter sido manipulado:

```ts
// ❌ Confia no role enviado pelo cliente
const role = req.body.role;
if (role === 'admin') allowAccess();

// ✅ Role vem do JWT verificado / sessão server-side
const user = await loadUser(req.session.userId);
if (user.role === 'admin') allowAccess();
```

Cliente envia "intenção". Servidor valida.

### Onde os dois falham historicamente

#### Authn fail: credentials weakness

- **Senhas guardadas com MD5.**
- **Sem rate limit**: brute force viável.
- **Sem MFA em conta crítica.**
- **Token sem expiração.**
- **Recuperação de senha por SMS.**

#### Authz fail: implicit trust

- **Endpoint admin sem checagem.**
- **Filtro de query confiando em campo do request.**
- **API interna sem authz** ("é interna").
- **Token reutilizado entre tenants.**
- **Cache de permissão muito longo**: revogação atrasa.

A pesquisa de OWASP mostra que **broken access control é a #1 categoria de vulnerabilidade** em aplicações web, frequentemente trivial de explorar quando existe.

### Padrões de implementação seguros

#### Authn em middleware central

Garantir que **toda rota** passa pelo middleware de autenticação. Configure o framework para que a rota desprotegida seja **exceção explícita**, não regra.

```ts
app.use(authnMiddleware);                          // tudo protegido por default

app.get('/health',  unprotected, healthHandler);   // marcar exceção explicitamente
app.get('/orders', listOrders);                    // protegido por default
```

#### Authz contextual

Não basta "tem permissão `orders:read`", precisa ser para **este** order.

```ts
// ❌ Verifica permissão global
if (user.can('orders:read')) return getOrder(orderId);

// ✅ Verifica permissão + ownership/contexto
const order = await getOrder(orderId);
if (!user.canAccessOrder(order)) throw new ForbiddenError();
return order;
```

#### Audit log para tudo sensível

```ts
async function changeUserRole(adminId: string, targetUserId: string, newRole: Role) {
  // ... fazer mudança ...

  await auditLog.write({
    actor:     adminId,
    action:    'role_changed',
    target:    targetUserId,
    metadata:  { newRole },
    timestamp: new Date(),
    ip:        req.ip,
  });
}
```

Sem audit log, ataques são difíceis de detectar e investigar.

### Cuidados específicos

#### "Just check the role" não basta

Role-based ignora contexto. Cliente A é admin do seu próprio tenant, não admin global.

#### Permissões em cache têm TTL

Revogação imediata raramente é possível com cache longo. TTL curto (segundos a poucos minutos) ou invalidation explícita.

#### MFA na mudança de credenciais

Mudar senha, MFA, email ou role deve exigir **re-autenticação forte**: não basta sessão antiga.

#### Sessões antigas devem invalidar em ações sensíveis

Mudar senha → invalidar todas as outras sessões do usuário. Sem isso, atacante mantém acesso após senha rotacionada.

## Quando *não* usar

Esses princípios são **universais**. A pergunta correta não é "quando não usar?" e sim "qual o nível de rigor?":

- **Sistemas internos baixo risco:** princípios continuam, rigor menor (sem MFA, talvez).
- **Sistemas com PII / financeiro / saúde:** rigor máximo + compliance específico.
- **APIs públicas:** assuma ataque constante.

## Conceitos relacionados

- [Autenticação e autorização (implementação)](../backend/authentication-authorization.md)
- [OWASP Top 10](./owasp-top-10.md): A01 (Broken Access Control), A07 (Auth Failures).
- [Threat modeling](./threat-modeling.md), descobrir essas falhas antes de codar.
- [Secrets management](./secrets-management.md).

## Referências

- **Paper.** Jerome Saltzer & Michael Schroeder, ["The Protection of Information in Computer Systems"](https://www.cs.virginia.edu/~evans/cs551/saltzer/) (Proceedings of the IEEE, 1975). Origem do "least privilege" e outros princípios canônicos.
- **Site.** [OWASP Access Control Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Access_Control_Cheat_Sheet.html).
- **Site.** [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html).
- **Site.** [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html).
- **Livro.** Adam Shostack, *Threat Modeling: Designing for Security* (Wiley, 2014). Como pensar em ataques durante design.
- **Livro.** Tanya Janca, *Alice and Bob Learn Application Security* (Wiley, 2020). Princípios acessíveis para desenvolvedores.
- **Artigo.** Google, ["BeyondCorp: A New Approach to Enterprise Security"](https://www.beyondcorp.com). Zero trust aplicado.
- **NIST.** [SP 800-63: Digital Identity Guidelines](https://pages.nist.gov/800-63-3/). Referência autoritativa sobre authn moderna.
