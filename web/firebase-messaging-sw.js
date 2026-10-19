/* Firebase options are injected by scripts/configure_firebase_web.js at build time. */
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

const firebaseConfig = null;
if (firebaseConfig && firebaseConfig.apiKey) {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    const topicId = payload.data?.topicId || '';
    return self.registration.showNotification(notification.title || 'HowBuddy', {
      body: notification.body || '',
      icon: 'icons/Icon-192.png',
      data: {topicId},
    });
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const topicId = event.notification.data?.topicId || '';
  const target = topicId
    ? `/?notificationTopic=${encodeURIComponent(topicId)}`
    : '/';
  event.waitUntil(self.clients.openWindow(target));
});
