import 'dart:js_interop';
import 'package:web/web.dart' as web;

void webRequestNotificationPermission() {
  try {
    if (web.Notification.permission != 'granted') {
      web.Notification.requestPermission().toDart;
    }
  } catch (_) {}
}

void webShowNotification(String title, String message) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(
        title,
        web.NotificationOptions(
          body: message,
          icon: 'icons/Icon-192.png',
        ),
      );
    } else if (web.Notification.permission != 'denied') {
      web.Notification.requestPermission().toDart.then((perm) {
        if (perm.toDart == 'granted') {
          web.Notification(
            title,
            web.NotificationOptions(
              body: message,
              icon: 'icons/Icon-192.png',
            ),
          );
        }
      });
    }
  } catch (_) {}
}

void webPlayAudio(String dataUrl, double volume) {
  try {
    final audio = web.HTMLAudioElement();
    audio.src = dataUrl;
    audio.volume = volume;
    audio.play();
  } catch (_) {}
}

