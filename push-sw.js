// Web Push service worker for GitHub Pages (scope: /McCormick-Picks/).
self.addEventListener('push', (event) => {
  let payload = {};
  try { payload = event.data?.json() || {}; } catch (_) { /* Ignore invalid payload */ }
  event.waitUntil(self.registration.showNotification(payload.title || 'McCormick Picks', {
    body: payload.body || 'You have a pick reminder.',
    icon: './icon-180.png',
    badge: './favicon-32.png',
    data: { url: '/McCormick-Picks/' },
  }));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/McCormick-Picks/'));
});
