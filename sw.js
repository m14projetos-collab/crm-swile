// Swile 2.0 · service worker: guarda a "casca" do app para abrir rápido e sem sinal.
// Dados (Supabase), Receita (BrasilAPI) e IA nunca passam pelo cache: vão sempre direto à rede.
const CACHE = "swile20-shell-v1";
const SHELL = ["./", "./index.html", "./manifest.webmanifest", "./icons/icon-192.png", "./icons/icon-512.png", "./icons/apple-touch-icon.png"];
const CDN_HOSTS = ["cdn.tailwindcss.com", "cdn.jsdelivr.net", "fonts.googleapis.com", "fonts.gstatic.com"];

self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(SHELL); }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (keys) {
    return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

function withTimeout(p, ms) {
  return new Promise(function (resolve, reject) {
    const t = setTimeout(function () { reject(new Error("timeout")); }, ms);
    p.then(function (r) { clearTimeout(t); resolve(r); }, function (err) { clearTimeout(t); reject(err); });
  });
}

self.addEventListener("fetch", function (e) {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;

  // Página do app: sempre tenta a versão nova; sem rede (ou rede muito lenta), abre a última guardada
  if (req.mode === "navigate" || (sameOrigin && /\/(index\.html)?$/.test(url.pathname))) {
    e.respondWith(withTimeout(fetch(req), 6000).then(function (res) {
      if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then(function (c) { c.put("./index.html", copy); }); }
      return res;
    }).catch(function () {
      return caches.match("./index.html").then(function (r) { return r || caches.match("./"); });
    }));
    return;
  }

  // Ícones e manifesto: cache primeiro
  if (sameOrigin && /\/(icons\/|manifest\.webmanifest$)/.test(url.pathname)) {
    e.respondWith(caches.match(req).then(function (r) { return r || fetch(req); }));
    return;
  }

  // Bibliotecas e fontes (versões fixas): usa a guardada e atualiza em segundo plano
  if (CDN_HOSTS.indexOf(url.hostname) >= 0) {
    e.respondWith(caches.open(CACHE).then(function (c) {
      return c.match(req).then(function (hit) {
        const net = fetch(req).then(function (res) { if (res && (res.ok || res.type === "opaque")) c.put(req, res.clone()); return res; });
        if (hit) { net.catch(function () { /* sem rede: fica a guardada */ }); return hit; }
        return net;
      });
    }));
  }
  // Todo o resto (Supabase, BrasilAPI, Gemini, SQLs) segue direto para a rede
});
