import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'web_audio_helper.dart';

/// Layanan Audio Feedback dan In-App / System Notification Rasantara
class AudioNotificationService {
  static final AudioNotificationService _instance = AudioNotificationService._internal();
  factory AudioNotificationService() => _instance;
  AudioNotificationService._internal();

  String? _orderReceivedWavDataUrl;
  String? _promoChimeWavDataUrl;

  /// Meminta izin notifikasi sistem / OS langsung ke Windows & HP
  static Future<void> requestSystemNotificationPermission() async {
    // Dinonaktifkan
  }

  /// Menampilkan Notifikasi Sistem Asli ke Windows Action Center / HP Notification Drawer
  static void showSystemNotification({
    required String title,
    required String message,
  }) {
    // Dinonaktifkan - Notifikasi sistem dihilangkan
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
          webPlayAudio(_orderReceivedWavDataUrl!, 0.85);
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
          webPlayAudio(_promoChimeWavDataUrl!, 0.75);
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

  /// Menampilkan In-App Floating Notification Banner (Dinonaktifkan)
  static void showBanner(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active_rounded,
    Color color = const Color(0xFFEA580C),
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dinonaktifkan - Sistem notifikasi banner dihilangkan
  }
}
