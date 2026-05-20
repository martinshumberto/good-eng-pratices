# Acessibilidade (a11y)

> **TL;DR.** Acessibilidade não é "feature extra", é **qualidade básica**. Use **HTML semântico** primeiro. Use **ARIA** só quando HTML semântico não basta. Teste com teclado (sem mouse) e com leitor de tela. WCAG 2.1 nível AA é o padrão prático mínimo.

## O quê

**Acessibilidade** (frequentemente abreviada como **a11y**: "a" + 11 letras + "y") é a prática de construir interfaces que pessoas com deficiências possam **usar plenamente**:

- **Visual:** cegos (leitor de tela), baixa visão, daltônicos.
- **Motor:** dificuldade de manuseio fino (não usa mouse, usa apenas teclado).
- **Auditivo:** surdos, deficientes auditivos.
- **Cognitivo:** dislexia, autismo, TDAH, interfaces previsíveis e claras.

O padrão referência é **WCAG** ([Web Content Accessibility Guidelines](https://www.w3.org/WAI/standards-guidelines/wcag/)), publicado pelo W3C. Versão atual: **WCAG 2.2** (Oct 2023). WCAG 3.0 está em desenvolvimento.

Três níveis de conformidade: **A** (mínimo), **AA** (padrão prático), **AAA** (mais rigoroso, raramente atingível em escala).

## Por quê

Razões para investir em a11y:

- **Ética.** ~15% da população mundial tem alguma deficiência (OMS). Excluí-los é discriminação.
- **Legal.** ADA (EUA), AODA (Canadá), Lei Brasileira de Inclusão (Brasil, 2015), EAA (UE). Multas + processos.
- **SEO.** Boa a11y = HTML semântico = melhor para buscadores.
- **Usabilidade para todos.** Captions ajudam quem está no metrô. Contraste alto ajuda em sol forte. Tab order claro ajuda power users.
- **Tamanho de mercado.** Excluir 15% dos usuários é decisão econômica ruim.

> "The power of the Web is in its universality. Access by everyone regardless of disability is an essential aspect."
> (Tim Berners-Lee)

## Como aplicar

### Princípios: POUR

WCAG organiza em 4 princípios:

| Princípio | O que significa |
|---|---|
| **Perceivable** | Conteúdo precisa ser perceptível (alt em imagens, captions em vídeos, contraste suficiente) |
| **Operable** | Pode ser usado (teclado, sem timeouts curtos, sem conteúdo que cause epilepsia) |
| **Understandable** | Pode ser entendido (linguagem clara, comportamento previsível) |
| **Robust** | Funciona com tecnologia atual e futura (HTML válido, ARIA correto) |

### Comece com HTML semântico

A maior parte da a11y vem **de graça** com HTML correto.

```html
<!-- ❌ -->
<div class="button" onclick="submit()">Enviar</div>

<!-- ✅ -->
<button type="submit">Enviar</button>
```

`<button>` traz nativamente:

- Foco via teclado.
- Trigger via Enter/Space.
- Anunciado como "button" pelo leitor de tela.
- Estilos default (outline de foco).
- Estado disabled.

#### Elementos semânticos importantes

| Use | Em vez de |
|---|---|
| `<button>` | `<div onclick>` |
| `<a href>` | `<span onclick>` para navegação |
| `<nav>`, `<main>`, `<header>`, `<footer>`, `<aside>` | `<div class="nav">` |
| `<h1>`–`<h6>` (hierárquicos, sem pular níveis) | `<div class="title">` |
| `<ul>`/`<ol>` + `<li>` | `<div>`s soltos |
| `<label>` associada a `<input>` | placeholder como label |
| `<table>` com `<th>`, `<thead>`, `<tbody>` | `<div>` grid para dados tabulares |

#### Forms: semântica importa muito

```html
<!-- ✅ -->
<label for="email">E-mail</label>
<input id="email" type="email" required aria-describedby="email-help" />
<span id="email-help">Usaremos para te enviar atualizações.</span>

<!-- E em erro: -->
<input id="email" type="email" aria-invalid="true" aria-describedby="email-error" />
<span id="email-error" role="alert">E-mail inválido</span>
```

Leitor de tela anuncia: "E-mail, edit text, required. Usaremos para te enviar atualizações."

### Imagens: `alt` adequado

```html
<!-- Decorativa (puramente visual) -->
<img src="pattern.png" alt="" role="presentation" />

<!-- Conteúdo -->
<img src="chart.png" alt="Vendas crescendo 23% em Q3 2024" />

<!-- Funcional (link/botão) -->
<a href="/cart">
  <img src="cart-icon.svg" alt="Carrinho de compras (3 itens)" />
</a>
```

**Não escreva:** "imagem de", "foto de", leitor já anuncia que é imagem.

**Texto longo** (gráficos): use `<figure>` + `<figcaption>` ou descreva no contexto.

### Contraste

WCAG AA exige:

- **Texto normal:** contraste ≥ 4.5:1.
- **Texto grande** (≥ 18pt ou 14pt bold): ≥ 3:1.
- **UI elements** (botões, ícones críticos): ≥ 3:1.

Ferramentas:

- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/).
- DevTools (Chrome, Firefox) mostra contraste no inspector.
- [Stark](https://www.getstark.co), plugin Figma/Sketch.

**Não dependa só de cor.** Daltônicos não distinguem vermelho/verde. Acompanhe cor com **forma, ícone, texto**:

```html
<!-- ❌ Só cor -->
<p style="color: red">Erro</p>
<p style="color: green">OK</p>

<!-- ✅ Cor + texto + ícone -->
<p style="color: red">❌ Erro: ...</p>
<p style="color: green">✓ OK</p>
```

### Foco e navegação por teclado

**Tudo interativo é alcançável pelo teclado.** Sem mouse:

- `Tab` / `Shift+Tab`: navegar.
- `Enter` / `Space`: ativar.
- `Esc`: fechar modal.
- `Setas`: navegar dentro de menus, carrosseis.

#### Outline de foco

**Nunca remova** `outline` sem substituir por algo visível:

```css
/* ❌ */
*:focus { outline: none; }

/* ✅ Substitua por algo visual */
*:focus {
  outline: 2px solid #007acc;
  outline-offset: 2px;
}

/* ✅ Use :focus-visible para mostrar só em navegação por teclado */
*:focus-visible {
  outline: 2px solid #007acc;
}
```

#### Tab order

A ordem natural do DOM define o tab order. Evite `tabindex` positivo:

```html
<!-- ❌ tabindex positivo bagunça ordem -->
<input tabindex="1" /> <input tabindex="3" /> <input tabindex="2" />

<!-- ✅ ordem natural do DOM -->
<input /> <input /> <input />
```

Use `tabindex="0"` para tornar elementos não-interativos focáveis (raro). `tabindex="-1"` para removê-los do tab.

#### Skip link

Permita pular cabeçalho repetitivo:

```html
<a href="#main" class="skip-link">Pular para o conteúdo principal</a>
<nav>...</nav>
<main id="main">...</main>
```

```css
.skip-link {
  position: absolute;
  top: -100px;
}
.skip-link:focus {
  top: 0;
}
```

#### Focus trap em modais

Quando modal abre:

- Foco vai para o primeiro elemento focável dentro.
- Tab cicla **dentro** do modal.
- Esc fecha.
- Foco volta para o trigger ao fechar.

Use [focus-trap](https://github.com/focus-trap/focus-trap) ou componente de UI library madura.

### ARIA: quando HTML não basta

[ARIA](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA) (Accessible Rich Internet Applications) adiciona semântica a elementos genéricos.

**Primeira regra do ARIA:** *não use ARIA se HTML faz o trabalho.*

```html
<!-- ❌ ARIA desnecessário, <button> já é button -->
<button role="button">Clique</button>

<!-- ❌ Pior: simula <button> em <div> -->
<div role="button" tabindex="0" aria-pressed="false" onclick="..." onkeypress="...">Clique</div>

<!-- ✅ Use o elemento certo -->
<button>Clique</button>
```

#### Quando ARIA brilha

Para padrões que HTML não cobre (tabs, accordions, autocomplete, alerts dinâmicos):

```html
<!-- Live region: anuncia mudanças dinâmicas -->
<div role="status" aria-live="polite">3 itens carregados</div>

<!-- Tabs -->
<div role="tablist">
  <button role="tab" aria-selected="true"  aria-controls="panel-1">Aba 1</button>
  <button role="tab" aria-selected="false" aria-controls="panel-2">Aba 2</button>
</div>
<div role="tabpanel" id="panel-1">Conteúdo 1</div>
<div role="tabpanel" id="panel-2" hidden>Conteúdo 2</div>

<!-- Toast notification -->
<div role="alert">Pedido confirmado!</div>
```

#### Padrões ARIA documentados

[ARIA Authoring Practices Guide (APG)](https://www.w3.org/WAI/ARIA/apg/) cobre padrões comuns: combobox, datepicker, treeview, etc. Use **antes** de inventar do zero.

### Componentes acessíveis prontos

Não escreva combobox/modal/datepicker do zero, use libraries auditadas:

| Library | Notas |
|---|---|
| **[Radix UI](https://www.radix-ui.com)** | Unstyled, acessibilidade profissional. Padrão emergente para React. |
| **[Headless UI](https://headlessui.com)** | Vercel, unstyled, simpler API. |
| **[Reach UI](https://reach.tech/)** | Mais antiga, manutenção limitada. |
| **[Ariakit](https://ariakit.org)** | Mais granular, foco em primitives. |
| **[React Aria](https://react-spectrum.adobe.com/react-aria/)** | Adobe, robusto, com hooks. |

Use hooks + styled-components/Tailwind para visual. A11y vem grátis.

### Conteúdo dinâmico

#### Loading states

Anuncie progresso:

```html
<div role="status" aria-live="polite">
  {isLoading && <span>Carregando...</span>}
  {data && <span>3 itens carregados</span>}
</div>
```

#### Erros

```html
<input aria-invalid="true" aria-describedby="err-1" />
<span id="err-1" role="alert">E-mail inválido</span>
```

`role="alert"` faz o leitor de tela anunciar imediatamente.

#### Conteúdo carregado por JS

```tsx
function PostList() {
  const { data, isLoading } = useQuery(/* ... */);

  return (
    <section aria-busy={isLoading}>
      {isLoading && <p role="status">Carregando posts...</p>}
      {data?.map(post => <article key={post.id}>{/* ... */}</article>)}
    </section>
  );
}
```

### Mobile / Touch

- **Áreas de toque** ≥ 44×44 pixels (Apple HIG) ou 48×48 (Material Design).
- **Espaçamento** entre elementos clicáveis.
- **Gestos têm alternativa** (swipe deve ter botão equivalente).

### Animações e movimento

WCAG 2.1 §2.3.3: respeite `prefers-reduced-motion`:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

Pessoas com sensibilidade vestibular ou TDAH sofrem com excesso de animação.

### Testes: manual + automatizado

#### Automatizado

- **[axe-core](https://github.com/dequelabs/axe-core)**: engine líder de a11y testing.
- **[eslint-plugin-jsx-a11y](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y)**: pega problemas básicos em build time.
- **[Lighthouse](https://developer.chrome.com/docs/lighthouse/accessibility/)**: auditoria no DevTools.
- **[pa11y](https://pa11y.org)**: CLI para auditoria automatizada.
- **[axe DevTools](https://www.deque.com/axe/devtools/)**: extensão de browser, mais detalhada.

Em CI:

```yaml
- name: Run a11y tests
  run: npx playwright test --grep "@a11y"
```

```ts
// Playwright + axe
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage has no a11y violations', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

**Importante:** automatizado pega **~30-40% dos problemas**. Manual é crítico.

#### Manual

**Use o teclado.** Navegue pelo site sem mouse. Tudo funciona? Tab order faz sentido? Foco visível?

**Use leitor de tela.**

- **VoiceOver** (macOS, Cmd+F5).
- **NVDA** (Windows, gratuito).
- **JAWS** (Windows, comercial).
- **TalkBack** (Android).
- **VoiceOver** (iOS).

Comece com VoiceOver no Mac, atalho `Cmd+F5`. Demora ~30 min para entender; revela problemas que ferramentas não pegam.

#### Verifique cor

- Mude para grayscale (DevTools → Rendering → Emulate vision deficiencies).
- Teste com daltonismo simulado.
- Verifique contraste em todos os estados (hover, focused, disabled).

### Compliance e auditoria

Para projetos sérios:

- **Audit anual** por consultoria especializada.
- **VPAT** (Voluntary Product Accessibility Template), declaração de conformidade.
- **EN 301 549**: padrão europeu (referência o WCAG).
- **Integre com testes E2E.**

### Anti-padrões

- **Placeholder como label**: desaparece quando digita, problemático para leitores.
- **`<div onclick>`**: sem teclado, sem semântica.
- **Ícone sem `aria-label`**: leitor não sabe o que é.
- **Disable do outline sem substituto.**
- **`autocomplete="off"` em campos de senha**: quebra password manager.
- **Modal sem focus trap.**
- **Carrossel sem controle de pausa.**
- **Conteúdo importante só em hover.**

## Quando *não* usar (ARIA)

Resumido: **prefira sempre HTML semântico**. ARIA é último recurso. Quando usar ARIA, valide com leitor de tela real, ARIA errado é pior que ARIA ausente.

## Conceitos relacionados

- [Design de componentes](./component-design.md), componentes acessíveis por design.
- [Performance e Web Vitals](./performance-web-vitals.md): UX impactada por ambos.
- [Documentação](../collaboration/documentation.md), docs também precisam ser acessíveis.

## Referências

- **Spec.** [WCAG 2.2](https://www.w3.org/TR/WCAG22/). Padrão atual.
- **Spec.** [ARIA 1.2](https://www.w3.org/TR/wai-aria-1.2/).
- **Site.** [W3C: WAI](https://www.w3.org/WAI/). Hub de acessibilidade.
- **Site.** [ARIA Authoring Practices Guide (APG)](https://www.w3.org/WAI/ARIA/apg/). Padrões ARIA com exemplos.
- **Site.** [WebAIM](https://webaim.org). Recursos práticos.
- **Site.** [a11yproject.com](https://www.a11yproject.com). Checklists, padrões, comunidade.
- **Site.** [MDN: Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility).
- **Livro.** Heydon Pickering, *Inclusive Components* (Smashing Magazine, 2019). [inclusive-components.design](https://inclusive-components.design).
- **Documentação.** [Radix UI Primitives](https://www.radix-ui.com/primitives). Componentes acessíveis.
- **Documentação.** [axe-core](https://github.com/dequelabs/axe-core).
- **Artigo.** Adrian Roselli, [adrianroselli.com](https://adrianroselli.com). Blog técnico profundo sobre a11y.
