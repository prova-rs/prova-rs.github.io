/**
 * Keeps the favicon on the same verdict as the page.
 *
 * favicon.svg already switches itself on `prefers-color-scheme`, which covers
 * readers whose OS preference the site is following. But Docusaurus' toggle is
 * a user override on top of that, so a light-OS reader who flips the docs to
 * dark would otherwise get a green tab icon over a red page.
 *
 * This is a client module rather than a React component because the favicon
 * link is rendered by SiteMetadataDefaults, which lives under <ThemeProvider>
 * while @theme/Root sits above it — `useColorMode` is out of reach. So we work
 * at the DOM level: watch `data-theme` for the reader's choice, and watch
 * <head> because react-helmet re-renders the link on hydration and on every
 * route change, restoring the declared href each time. Both observers funnel
 * into sync(), which no-ops when the href is already right, so the two never
 * chase each other.
 */

const DECLARED = 'favicon.svg';
const STATES = {light: 'favicon-pass.svg', dark: 'favicon-fail.svg'} as const;

// The href Docusaurus declared, kept so every swap derives from the same base
// and repeated toggles can't compound (favicon-pass-pass.svg and friends).
let declaredHref: string | null = null;

function sync(): void {
  const link = document.querySelector<HTMLLinkElement>('link[rel="icon"]');
  if (!link) {
    return;
  }

  const href = link.getAttribute('href');
  if (href?.includes(DECLARED)) {
    declaredHref = href;
  }
  if (!declaredHref) {
    return;
  }

  const dark = document.documentElement.getAttribute('data-theme') === 'dark';
  const next = declaredHref.replace(DECLARED, dark ? STATES.dark : STATES.light);
  if (href !== next) {
    link.setAttribute('href', next);
  }
}

export function onRouteDidUpdate(): void {
  sync();
}

if (typeof document !== 'undefined') {
  sync();

  new MutationObserver(sync).observe(document.documentElement, {
    attributeFilter: ['data-theme'],
  });

  new MutationObserver(sync).observe(document.head, {
    childList: true,
    subtree: true,
    attributeFilter: ['href'],
  });
}
