// Clé publique VAPID — publique par nature (elle sert uniquement à ce que
// le navigateur identifie le bon service d'envoi), pas besoin de la garder
// secrète ni de la mettre en variable d'environnement séparée. La clé
// PRIVÉE, elle, ne vit jamais ici — uniquement dans les secrets de l'Edge
// Function Supabase.
export const VAPID_PUBLIC_KEY = 'BLxtj0dyHvizSYgp7Lve_W6XBnubiJE6W-uPgnG1tAJoeM3yAZJQ2KJoORFLO-kRe5O2rmgtvrP3jpSpwsc9xYk';

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
}

export function isPushSupported() {
  return typeof window !== 'undefined' && 'serviceWorker' in navigator && 'PushManager' in window;
}

export async function subscribeToPush(supabase, userId) {
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    throw new Error('permission_denied');
  }

  const registration = await navigator.serviceWorker.ready;

  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
    });
  }

  const json = subscription.toJSON();

  const { error } = await supabase.from('push_subscriptions').upsert(
    {
      user_id: userId,
      endpoint: json.endpoint,
      p256dh: json.keys.p256dh,
      auth_key: json.keys.auth,
    },
    { onConflict: 'endpoint' }
  );

  if (error) throw error;
}

export async function unsubscribeFromPush(supabase) {
  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();

  if (subscription) {
    await supabase.from('push_subscriptions').delete().eq('endpoint', subscription.endpoint);
    await subscription.unsubscribe();
  }
}

export async function getCurrentPushSubscription() {
  if (!isPushSupported()) return null;
  const registration = await navigator.serviceWorker.ready;
  return registration.pushManager.getSubscription();
}

