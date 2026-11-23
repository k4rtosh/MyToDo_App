/* Service worker: РѕС„Р»Р°Р№РЅ-РѕР±РѕР»РѕС‡РєР° РїСЂРёР»РѕР¶РµРЅРёСЏ В«Р—Р°РґР°С‡РёВ».
   РЎС‚СЂР°С‚РµРіРёСЏ: РЅР°РІРёРіР°С†РёСЏ вЂ” СЃРµС‚СЊ, РїСЂРё РѕС‚СЃСѓС‚СЃС‚РІРёРё СЃРµС‚Рё вЂ” РєСЌС€;
   РѕСЃС‚Р°Р»СЊРЅС‹Рµ GET вЂ” РєСЌС€, РїСЂРё РїСЂРѕРјР°С…Рµ вЂ” СЃРµС‚СЊ СЃ РґРѕРєР»Р°РґС‹РІР°РЅРёРµРј РІ РєСЌС€. */

const CACHE = 'todo-shell-v12';
const ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './favicon.ico',
  './icons/favicon.svg',
  './icons/favicon-16.png',
  './icons/favicon-32.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(ASSETS).catch(() => {}))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;

  // HTML-СЃС‚СЂР°РЅРёС†Р°: СЃРЅР°С‡Р°Р»Р° СЃРµС‚СЊ (С‡С‚РѕР±С‹ РѕР±РЅРѕРІР»РµРЅРёСЏ РїСЂРёРµР·Р¶Р°Р»Рё), РѕС„Р»Р°Р№РЅ вЂ” РєСЌС€
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then(res => {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put('./index.html', copy)).catch(() => {});
          return res;
        })
        .catch(() => caches.match('./index.html').then(hit => hit || caches.match('./')))
    );
    return;
  }

  event.respondWith(
    caches.match(req).then(hit => hit || fetch(req).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
      return res;
    }))
  );
});
