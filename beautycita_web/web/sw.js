// BeautyCita custom service worker.
//
// Flutter web's bundled flutter_service_worker.js is now a self-
// unregistering stub (the PWA caching path was deprecated upstream),
// so the browser's Application > Storage panel shows 0 bytes of
// cached anything for the web app. This worker is what actually
// caches the app shell and runtime image fetches so refreshes are
// instant and the cache panel reflects real activity.
//
// Strategy:
//   * App shell (index, manifest, icons): pre-cached on install,
//     stale-while-revalidate at runtime.
//   * Flutter JS / WASM / fonts / canvaskit: cache-first runtime.
//   * Images on R2 + same-origin /img: cache-first runtime.
//   * Supabase, edge functions, Stripe: NEVER cached — always live.
//
// Versioned by VERSION; changing it busts both caches on next activate.

const VERSION = 'bc-2026-04-19-01';
const SHELL = `bc-shell-${VERSION}`;
const RUNTIME = `bc-runtime-${VERSION}`;

const SHELL_FILES = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/favicon.ico',
  '/apple-touch-icon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL).then((cache) =>
      // addAll fails atomic — use Promise.all so a single 404 doesn't kill the install
      Promise.all(SHELL_FILES.map((u) => cache.add(u).catch(() => {})))
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== SHELL && k !== RUNTIME)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try { url = new URL(req.url); } catch { return; }

  // Never touch live data
  if (
    url.pathname.startsWith('/supabase/') ||
    url.pathname.startsWith('/functions/') ||
    url.hostname.includes('stripe.com') ||
    url.hostname.includes('hcaptcha.com') ||
    url.hostname.includes('googleapis.com')
  ) {
    return;
  }

  const isImage = /\.(png|jpe?g|gif|webp|svg|ico)$/i.test(url.pathname);
  const isFontOrAsset = /\.(woff2?|ttf|otf)$/i.test(url.pathname) ||
    url.hostname.includes('gstatic.com') ||
    url.hostname.includes('fonts.googleapis.com');
  const isFlutterAsset = /\.(js|wasm|mjs)$/i.test(url.pathname) ||
    url.pathname.startsWith('/canvaskit/') ||
    url.pathname.startsWith('/assets/');
  const isR2 = url.hostname.includes('r2.dev');
  const isShell = SHELL_FILES.includes(url.pathname) ||
    url.pathname === '/' ||
    url.pathname.endsWith('.html') ||
    url.pathname.endsWith('.json');

  // Cache-first for static assets + images + R2 media
  if (isImage || isFontOrAsset || isFlutterAsset || isR2) {
    event.respondWith(
      caches.open(RUNTIME).then(async (cache) => {
        const cached = await cache.match(req);
        if (cached) return cached;
        try {
          const fresh = await fetch(req);
          if (fresh && fresh.ok && fresh.type !== 'opaqueredirect') {
            cache.put(req, fresh.clone()).catch(() => {});
          }
          return fresh;
        } catch (e) {
          return cached || Response.error();
        }
      })
    );
    return;
  }

  // Stale-while-revalidate for app shell HTML/JSON
  if (isShell) {
    event.respondWith(
      caches.open(SHELL).then(async (cache) => {
        const cached = await cache.match(req);
        const fetchPromise = fetch(req).then((fresh) => {
          if (fresh && fresh.ok) cache.put(req, fresh.clone()).catch(() => {});
          return fresh;
        }).catch(() => cached);
        return cached || fetchPromise;
      })
    );
  }
});
