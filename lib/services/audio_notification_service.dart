import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import web package conditionally or with web guard
import 'package:web/web.dart' as web;

/// Layanan Audio Feedback dan In-App / System Notification Rasantara
class AudioNotificationService {
  static final AudioNotificationService _instance = AudioNotificationService._internal();
  factory AudioNotificationService() => _instance;
  AudioNotificationService._internal();

  String? _orderReceivedWavDataUrl;
  String? _promoChimeWavDataUrl;

  /// Meminta izin notifikasi sistem / OS langsung ke Windows & HP
  static Future<void> requestSystemNotificationPermission() async {
    if (!kIsWeb) return;
    try {
      if (web.Notification.permission != 'granted') {
        await web.Notification.requestPermission().toDart;
      }
    } catch (_) {}
  }

  /// Menampilkan Notifikasi Sistem Asli ke Windows Action Center / HP Notification Drawer
  static void showSystemNotification({
    required String title,
    required String message,
  }) {
    if (!kIsWeb) return;
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

  /// Inisialisasi audio synth
  void _ensureAudioBuffers() {
    if (_orderReceivedWavDataUrl != null) return;
    try {
      _orderReceivedWavDataUrl = _createChimeDataUrl(523.25, 659.25); // C5 -> E5 ding-dong
      _promoChimeWavDataUrl = _createChimeDataUrl(659.25, 880.00); // E5 -> A5 high chime
    } catch (_) {}
  }

  /// Menghasilkan Data URL WAV PCM sintetis 16-bit 22050Hz tanpa ketergantungan file eksternal
  String _createChimeDataUrl(double freq1, double freq2) {
    const sampleRate = 22050;
    const duration1 = 0.22;
    const duration2 = 0.38;
    final totalSamples = ((duration1 + duration2) * sampleRate).toInt();
    final byteData = ByteData(44 + totalSamples * 2);

    // RIFF Header
    void writeString(int offset, String str) {
      for (int i = 0; i < str.length; i++) {
        byteData.setUint8(offset + i, str.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little); // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample
    writeString(36, 'data');
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    final samples1 = (duration1 * sampleRate).toInt();
    int byteOffset = 44;

    for (int i = 0; i < totalSamples; i++) {
      double t = i / sampleRate;
      double sample = 0.0;

      if (i < samples1) {
        // Tone 1 with exponential decay
        double env = exp(-4.0 * (i / samples1));
        sample = sin(2 * pi * freq1 * t) * env;
      } else {
        // Tone 2 with gentle decay
        int j = i - samples1;
        double env = exp(-3.0 * (j / (totalSamples - samples1)));
        sample = sin(2 * pi * freq2 * t) * env;
      }

      int pcm = (sample * 24000).clamp(-32768, 32767).toInt();
      byteData.setInt16(byteOffset, pcm, Endian.little);
      byteOffset += 2;
    }

    final base64String = base64Encode(byteData.buffer.asUint8List());
    return 'data:audio/wav;base64,$base64String';
  }

  /// Memutar suara bel / chime pesanan diterima
  Future<void> playOrderReceivedSound({bool enabled = true}) async {
    if (!enabled) return;
    try {
      if (kIsWeb) {
        _ensureAudioBuffers();
        if (_orderReceivedWavDataUrl != null) {
          final audio = web.HTMLAudioElement();
          audio.src = _orderReceivedWavDataUrl!;
          audio.volume = 0.85;
          audio.play();
        }
      } else {
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  /// Memutar notifikasi audio promo / event diskon
  Future<void> playEventPromoSound({bool enabled = true}) async {
    if (!enabled) return;
    try {
      if (kIsWeb) {
        _ensureAudioBuffers();
        if (_promoChimeWavDataUrl != null) {
          final audio = web.HTMLAudioElement();
          audio.src = _promoChimeWavDataUrl!;
          audio.volume = 0.75;
          audio.play();
        }
      } else {
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Memutar klik ringan (haptic / tap)
  Future<void> playTapSound({bool enabled = true, bool haptic = true}) async {
    if (haptic) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
    if (enabled) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Menampilkan In-App Floating Notification Banner
  static void showBanner(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active_rounded,
    Color color = const Color(0xFFEA580C),
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        duration: duration,
        content: InkWell(
          onTap: () {
            messenger.hideCurrentSnackBar();
            onTap?.call();
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFCBD5E1),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
