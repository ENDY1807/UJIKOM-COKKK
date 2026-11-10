import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class OtpRecord {
  final String code;
  final DateTime expiresAt;
  int attemptsLeft;

  OtpRecord({
    required this.code,
    required this.expiresAt,
    this.attemptsLeft = 3,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class WhatsAppOtpService {
  WhatsAppOtpService._();
  static final WhatsAppOtpService instance = WhatsAppOtpService._();

  final Map<String, OtpRecord> _activeOtps = {};

  /// Normalisasi nomor HP ke format internasional WhatsApp (628xxx)
  static String normalizePhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+62')) {
      return cleaned.substring(1);
    } else if (cleaned.startsWith('62')) {
      return cleaned;
    } else if (cleaned.startsWith('0')) {
      return '62${cleaned.substring(1)}';
    }
    return cleaned;
  }

  /// Generate 6 digit angka acak kriptografis
  String _generateOtp() {
    final rnd = Random.secure();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  /// Mengirim kode OTP resmi via WhatsApp
  Future<String> sendOtp({
    required String rawPhone,
    String userName = 'Pelanggan',
    String purpose = 'Verifikasi Akun Rasantara',
  }) async {
    final phone = normalizePhoneNumber(rawPhone);
    final code = _generateOtp();
    final expiry = DateTime.now().add(const Duration(minutes: 5));

    _activeOtps[phone] = OtpRecord(code: code, expiresAt: expiry);

    final message = '''
Halo *$userName*,

Kode OTP Anda untuk *$purpose* adalah:
*${code.substring(0, 3)} ${code.substring(3)}*

Kode ini berlaku selama 5 menit. JANGAN PERNAH membagikan kode OTP ini kepada siapa pun termasuk pihak restoran atau staf Rasantara.

Salam hangat,
*Rasantara — Cita Rasa Kuliner Nusantara*
''';

    final encodedMessage = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
    }

    return code;
  }

  /// Memvalidasi kode OTP
  OtpVerificationResult verifyOtp({
    required String rawPhone,
    required String inputCode,
  }) {
    final phone = normalizePhoneNumber(rawPhone);
    final cleanInput = inputCode.replaceAll(' ', '').trim();

    if (!_activeOtps.containsKey(phone)) {
      return OtpVerificationResult(
        isValid: false,
        message: 'Kode OTP belum diminta atau nomor telepon tidak cocok.',
      );
    }

    final record = _activeOtps[phone]!;

    if (record.isExpired) {
      _activeOtps.remove(phone);
      return OtpVerificationResult(
        isValid: false,
        message: 'Kode OTP telah kedaluwarsa. Silakan minta kode baru.',
      );
    }

    if (record.attemptsLeft <= 0) {
      _activeOtps.remove(phone);
      return OtpVerificationResult(
        isValid: false,
        message: 'Batas percobaan habis. Silakan kirim ulang kode OTP baru.',
      );
    }

    if (record.code != cleanInput) {
      record.attemptsLeft -= 1;
      return OtpVerificationResult(
        isValid: false,
        message: 'Kode OTP salah. Sisa kesempatan: ${record.attemptsLeft}x.',
      );
    }

    // Sukses: bersihkan OTP dari memory
    _activeOtps.remove(phone);
    return OtpVerificationResult(
      isValid: true,
      message: 'Verifikasi nomor WhatsApp berhasil!',
    );
  }

  /// Ambil kode OTP aktif untuk debug / demo autofill
  String? peekOtp(String rawPhone) {
    final phone = normalizePhoneNumber(rawPhone);
    final rec = _activeOtps[phone];
    if (rec != null && !rec.isExpired) {
      return rec.code;
    }
    return null;
  }
}

class OtpVerificationResult {
  final bool isValid;
  final String message;

  OtpVerificationResult({required this.isValid, required this.message});
}

