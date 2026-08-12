// Deliberately caches nothing. Its only job is to exist and have a fetch handler,
// which is what Chrome requires before it will offer "Install app" / add the site
// to the home screen as a proper standalone app.
//
// A caching service worker on a single-file site is a trap: every deploy would need
// cache-busting or people keep seeing the old page. Since the whole site is one HTML
// file served fresh from GitHub Pages, normal browser caching is the right behaviour.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => { /* fall through to the network */ });
