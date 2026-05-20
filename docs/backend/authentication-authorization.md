# Autenticação e Autorização

> **TL;DR.** **Authn** = quem você é. **Authz** = o que você pode fazer. Não os confunda. Use OAuth2/OIDC para autenticação federada, JWT para sessions stateless (cuidado com revogação), e modele autorização explicitamente (RBAC, ABAC ou policy-based).

## O quê

Dois conceitos quase-sempre-misturados:

- **Authentication (authn)**: *Você é quem diz ser?* Verifica a identidade.
- **Authorization (authz)**: *Você pode fazer isso?* Verifica permissões.

A confusão tem origem semântica: ambas começam com "auth" e frequentemente vivem no mesmo middleware. Mas são **dois problemas separados** com soluções separadas.

| | Authentication | Authorization |
|---|---|---|
| **Pergunta** | "Quem é você?" | "Você pode?" |
| **Quando** | Login, cada request | Antes de cada operação |
| **Resultado** | Identidade (user ID, claims) | Permite/nega |
| **Falha = HTTP** | 401 Unauthorized (rename: *Unauthenticated*) | 403 Forbidden |

## Por quê

Sistemas que misturam authn e authz acabam com lógica esparsa, brechas e códigos `if (user)` espalhados. Tratá-los como camadas separadas dá:

- **Pluggable identity.** Trocar provedor (Google, GitHub, IDP próprio) sem mexer em authz.
- **Authz testável.** "Esse user pode editar esse recurso?" é função pura testável.
- **Auditoria.** Logs de quem fez o quê dependem de identidade clara.
- **Compliance.** Frameworks como SOC 2, ISO 27001 exigem separação explícita.

## Como aplicar

### Autenticação

#### Senhas: armazenamento

- **Nunca** armazene em texto claro.
- **Use hash adaptativo:** [bcrypt](https://en.wikipedia.org/wiki/Bcrypt), [scrypt](https://datatracker.ietf.org/doc/html/rfc7914), [Argon2id](https://datatracker.ietf.org/doc/html/rfc9106). **Não use MD5/SHA-1/SHA-256 puro.**
- **Cost factor** ajustável (bcrypt ≥ 12, Argon2 conforme [OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)).
- **Salt único por usuário**: bibliotecas já fazem por default.

```ts
import bcrypt from 'bcrypt';

// Hash no signup
const hash = await bcrypt.hash(password, 12);

// Verificação no login
const valid = await bcrypt.compare(password, user.passwordHash);
```

#### Rate limiting + lockout

Endpoints de login devem ser **rate limited** agressivamente, ver [rate limiting](./rate-limiting.md). Considere lockout temporário após N falhas, mas cuidado para não criar DoS via lockout intencional.

#### Multi-factor authentication (MFA)

Adicione segundo fator quando o risco justificar:

- **TOTP** (Time-based One-Time Password (Google Authenticator, Authy)) [RFC 6238](https://www.rfc-editor.org/rfc/rfc6238).
- **WebAuthn / Passkeys**: moderno, sem senha, baseado em chave pública.
- **SMS**: pior opção (SIM swap). Aceitável como step-up; ruim como único 2FA.

#### OAuth2 e OpenID Connect

- **OAuth2** ([RFC 6749](https://www.rfc-editor.org/rfc/rfc6749)), framework de **autorização delegada**. Permite que um app obtenha permissão para acessar recursos de outro em nome do usuário.
- **OpenID Connect (OIDC)**: camada de **autenticação** sobre OAuth2. Adiciona `id_token` (JWT) com claims de identidade.

OAuth2 sozinho **não é autenticação**. Para "Login com Google", você precisa de OIDC (que é OAuth2 + identity layer).

**Grants úteis:**

- **Authorization Code + PKCE**: para apps web e mobile. Padrão atual recomendado.
- **Client Credentials**: para máquinas (M2M).
- **Refresh Token**: para renovar access token sem novo login.

**Não use:**

- **Implicit Flow**: deprecated.
- **Password Grant** (ROPC), só em casos muito específicos (cliente first-party legacy).

#### Sessions vs tokens

| | Server-side sessions | JWT |
|---|---|---|
| **Estado** | No servidor (DB, Redis) | No próprio token |
| **Revogação** | Trivial (deleta a session) | Difícil (precisa de blacklist ou TTL curto) |
| **Scaling** | Precisa de session store compartilhada | Stateless, ideal para horizontal scaling |
| **Tamanho do cookie** | Pequeno (ID) | Grande (claims completos) |
| **Latência** | +1 lookup no store | Verificação local |

**JWT** brilha em sistemas distribuídos com microsserviços (não precisa de roundtrip ao auth service). **Sessions** brilham quando revogação imediata importa (banking, password change deve invalidar tudo).

### JWT: cuidados

Estrutura: `header.payload.signature`. Payload contém *claims* JSON.

```json
{
  "sub": "user_42",
  "iss": "auth.example.com",
  "aud": "api.example.com",
  "exp": 1734567890,
  "iat": 1734564290,
  "scope": "read:orders write:orders"
}
```

**Regras:**

- **Sempre verifique a assinatura.** Use algoritmos assimétricos (RS256, ES256) quando o consumidor for diferente do emissor.
- **Nunca aceite `alg: none`.** Vulnerabilidade clássica.
- **Sempre verifique `exp`, `iss`, `aud`.** Bibliotecas frequentemente exigem chamadas explícitas.
- **Não coloque dados sensíveis no payload**: JWT é assinado, **não encriptado**. Qualquer um lê o payload.
- **Claims compactos.** Use abreviações padrão (`sub`, `iss`, `aud`, `exp`).
- **Access tokens curtos** (5–15 min). **Refresh tokens longos** (dias/semanas), armazenados de forma segura.

#### Revogação: o calcanhar de Aquiles do JWT

JWT é stateless, não dá pra "deletar". Estratégias:

- **TTL curto + refresh.** Access token expira em 15min; ataque tem janela limitada.
- **Token blacklist** em Redis. Mas perde-se o "stateless".
- **Token versioning.** Adicione `token_version` ao user; invalide bumping a versão. Verificação requer lookup.

Se revogação imediata é crítica, considere **server-side sessions**.

### Autorização

#### Modelos comuns

##### RBAC: Role-Based Access Control

Usuários têm **roles**. Roles têm **permissions**. Permissions concedem acesso a operações.

```ts
// Roles: admin, manager, employee
// Permissions: orders:read, orders:write, orders:delete

const rolePermissions = {
  admin:    ['orders:read', 'orders:write', 'orders:delete', 'users:manage'],
  manager:  ['orders:read', 'orders:write'],
  employee: ['orders:read'],
};
```

Verificação:

```ts
function can(user: User, permission: string): boolean {
  return user.roles.some(role => rolePermissions[role]?.includes(permission));
}

if (!can(user, 'orders:delete')) return res.status(403).json({ /* ... */ });
```

**Vantagens:** simples, intuitivo, fácil de auditar.
**Limitação:** rígido. Não responde "este usuário pode editar **este recurso específico**?".

##### ABAC: Attribute-Based Access Control

Decisão baseada em **atributos** do usuário, do recurso e do contexto. Mais expressivo, mais complexo.

```
ALLOW se:
  user.organization_id == resource.organization_id
  AND user.role == 'manager'
  AND time_of_day in ['09:00', '18:00']
```

##### Policy-based (Open Policy Agent etc.)

Políticas declarativas externas ao código:

```rego
# OPA Rego
package authz

default allow = false

allow {
  input.user.role == "manager"
  input.resource.org == input.user.org
  input.action == "read"
}
```

**Vantagens:** auditável, separável do código.
**Quando vale:** sistemas com regras de negócio complexas, compliance que exige separação.

##### Relationship-Based (ReBAC / Zanzibar)

Modelo do Google ([Zanzibar paper, 2019](https://research.google/pubs/pub48190/)): permissões via **relacionamentos**. "Alice é editora do documento 42; o documento 42 está na pasta /shared; Alice herda permissão de leitura da pasta."

Ferramentas: [OpenFGA](https://openfga.dev), [SpiceDB](https://authzed.com/spicedb).

Útil para domínios com **muitos recursos hierárquicos** (Drive, GitHub, Notion).

#### Ownership e tenancy

Em sistemas multi-tenant, **sempre filtre por tenant**: não confie só em validation. Erros aqui são vazamentos cross-tenant.

```ts
// ❌ Vazamento potencial, se IDs vazam, qualquer um vê
async function getOrder(orderId: string) {
  return db.orders.findById(orderId);
}

// ✅ Sempre filtre por organization do user
async function getOrder(orderId: string, userOrgId: string) {
  const order = await db.orders.findOne({ id: orderId, organizationId: userOrgId });
  if (!order) throw new NotFoundError();
  return order;
}
```

Aplique no nível de **query**: não só no controller. Considere row-level security (RLS) do Postgres para fortalecer.

### Middleware típico

```ts
// Authn middleware: extrai e valida JWT
async function authnMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ code: 'unauthenticated' });

  try {
    const payload = await verifyJwt(token);
    req.user = await loadUser(payload.sub);
    next();
  } catch (err) {
    return res.status(401).json({ code: 'invalid_token' });
  }
}

// Authz middleware: verifica permissão específica
function requirePermission(permission: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!can(req.user, permission)) {
      return res.status(403).json({ code: 'forbidden' });
    }
    next();
  };
}

// Uso
app.delete('/orders/:id',
  authnMiddleware,
  requirePermission('orders:delete'),
  deleteOrderHandler,
);
```

### Cookies seguros

Para sessions baseadas em cookie:

```http
Set-Cookie: session=<token>;
            HttpOnly;          # JS não acessa
            Secure;            # Só sobre HTTPS
            SameSite=Lax;      # Mitiga CSRF
            Path=/;
            Max-Age=86400;
```

Para JWT em cliente JS, o trade-off é entre **`localStorage`** (XSS exposure) e **cookie HttpOnly** (precisa de CSRF protection). Cookie HttpOnly tende a ser mais seguro.

### Tokens de API (API keys)

Para autenticação máquina-a-máquina:

- **Gere com entropia suficiente** (32 bytes random).
- **Armazene como hash** (mesma técnica de senhas).
- **Mostre só uma vez** ao usuário.
- **Tenha prefixos identificáveis** (`sk_live_...`, `pk_test_...`), facilita rotação e detecção em logs.
- **Suporte rotação** sem downtime (overlap de validade).

### Auditoria

Logue:

- Tentativas de login (sucesso e falha).
- Mudanças de senha, MFA, dispositivos confiáveis.
- Mudanças de role/permission.
- Acessos a dados sensíveis.

Sem dados sensíveis no log (senhas, tokens, PII completo). Ver [structured logging](../observability/structured-logging.md).

## Quando *não* usar

- **Tudo o tempo todo, sim.** Não tem "quando não usar autenticação". Existe "quando público é OK".
- **Para endpoints genuinamente públicos.** Health checks, documentação, conteúdo open.
- **Autorização complexa em sistema simples.** Não force OPA num CRUD com 3 papéis, `if (user.role === 'admin')` resolve.

## Conceitos relacionados

- [Tratamento de erros](./error-handling.md), 401 vs 403.
- [Rate limiting](./rate-limiting.md), proteção contra brute force.
- [OWASP Top 10](../security/owasp-top-10.md): Broken Access Control é #1.
- [Validação de entrada](./input-validation.md), antes de authz, valide o input.

## Referências

- **Site.** [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html). Checklist autoritativa.
- **Site.** [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html).
- **Site.** [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). Argon2/bcrypt detalhado.
- **RFC.** [RFC 6749: OAuth 2.0](https://www.rfc-editor.org/rfc/rfc6749).
- **RFC.** [RFC 7519: JSON Web Tokens](https://www.rfc-editor.org/rfc/rfc7519).
- **RFC.** [RFC 8252: OAuth 2.0 for Native Apps](https://www.rfc-editor.org/rfc/rfc8252). PKCE para apps mobile.
- **Spec.** [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html).
- **Site.** [oauth.com](https://www.oauth.com): Aaron Parecki, excelente referência prática.
- **Paper.** Google, ["Zanzibar: Google's Consistent: Global Authorization System"](https://research.google/pubs/pub48190/) (USENIX, 2019). Modelo de ReBAC.
- **Documentação.** [WebAuthn](https://webauthn.guide). Tutorial moderno sobre autenticação sem senha.
- **Livro.** Justin Richer & Antonio Sanso, *OAuth 2 in Action* (Manning, 2017). Referência completa.
