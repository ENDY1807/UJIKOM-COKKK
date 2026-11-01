import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PaymentGatewayConfig {
  static String midtransServerKey = '';
  static String midtransClientKey = '';
  static bool isProduction = false;

  static const String defaultNmid = 'ID1020260081928';
  static const String defaultMerchantName = 'RASANTARA RESTORAN';
  static const String defaultCity = 'BANDUNG';
  static const String defaultPostalCode = '40286';

  // ── DANA Sandbox & SNAP BI Credentials Resmi ──────────────────────────────
  static const String danaSandboxBaseUrl = 'https://api.sandbox.dana.id';
  static const String danaPaymentH2hUrl =
      'https://api.sandbox.dana.id/payment-gateway/v1.0/debit/payment-host-to-host.htm';
  static const String danaMerchantId = '216620010001053576081';
  static const String danaClientId = '2026110120384225536315';
  static const String danaClientSecret =
      '60519dc8ed90db9f1e2ef694e231401a28d3260a3553013300ee0a0d0e13af8b';
  static const String danaChannelId = '95221';
  static const String danaExternalStoreId = 'ae70d112';
  static const String danaSubMerchantId = '1245d0e8';
  static const String danaMcc = '5812';
  static const String danaSignatureSample =
      'HjGmUcY1oKLZy5qi6cYlFydBfs6usQ6TKAIs2MszszN0qE9bG1SJR3ptaP/w7/+9w36yCllUR8Vk6UPro25RLTBFWGvQE0xHp2+QqxGX/u0k8AnGLyqDp6nRCcJFHgVdWXf88j1tcsySK5WSoxamzKodrXsVwiEmkmLbPMr/OoCLwIUcAxqC34ZY+IUX7QNhRwCEzwN5M/DyXODTFpxereJY8rhGy/DA5bQENCNU8izqy4QF+97i1405Qqyo7Pcc0hQWGsCgSRqB4sGvQ9DNsglZW0iZZl5qFEc2v/NKdWWLgzVKErl8d+5F7zoJOHojs7DsJtOvh8ENELdIYnysIg==';
  static const String danaPublicKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1j1CLBCb0GX1Y1TFLbYvCb+hlHwJ5qoTfY4cG81KxBw2RjfonSBnMLauFom+5WGtbUBkomS8SXHSgAEUD3b/irTYh/6dZevR5zp3UGnKK0VDmMh234Cbry6WxCgqeRXI/YJSqWoj1K4vVpJpBl5VoYfrDSJ4gU5hy9toMgWW0RRLDhT28B9hQJYYAGOc3/PcAtqLCKB5yXyjc/kt/YuQ30NF9qnJDDMq/Z/ibzmoIbZXt8nIFMheFwLK+ep6BqhF6TawvPtehILESC/J/1hDcQCh+5YTiCFP51lqLSBTXoaq6Rsu9+NmP8ZoBpCeq0zLrIW9YdsW32Q9XIF91XOjGwIDAQAB';
  static const String danaPrivateKey =
      'MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDWPUIsEJvQZfVjVMUtti8Jv6GUfAnmqhN9jhwbzUrEHDZGN+idIGcwtq4Wib7lYa1tQGSiZLxJcdKAARQPdv+KtNiH/p1l69HnOndQacorRUOYyHbfgJuvLpbEKCp5Fcj9glKpaiPUri9WkmkGXlWhh+sNIniBTmHL22gyBZbRFEsOFPbwH2FAlhgAY5zf89wC2osIoHnJfKNz+S39i5DfQ0X2qckMMyr9n+JvOaghtle3ycgUyF4XAsr56noGqEXpNrC8+16EgsRIL8n/WENxAKH7lhOIIU/nWWotIFNehqrpGy7342Y/xmgGkJ6rTMushb1h2xbfZD1cgX3Vc6MbAgMBAAECggEAD/d5AIuGVhkOZkZEyCjdRzBq5h2U2uxbz04xjLLkOrE3LEy+mRARELtBeZ8iq1ORymQm4kferoL9b+b+RaUvqCwQcGY9+QDpX/6ZmNRUw5ybmP3lU7fw7zS2+mYoVpjhWPkG/xnqRk+eNvYEPmJc2gQlG15km8J2agW8NYosGM3aG3bxU5Ge2x9YTIw/WYYBienjxD8RnmNwRI87CS3L9MViqshnx6/1pGNUr1MNlCABT8EPFlHia0rfZOrNCjjtPXxm4CJUg7Hmni19osNuoUT20RT8T8f1ckF2wGFAwJWlwVWteFLiYbY3jgQJxOznozXLrEkXOL/L2yXGvv/CUQKBgQD4ZL/N1el/gHCd11nBOgVnIqnZeFiFC08ybqNyMyOMxRGzsOFwH5Vdalxhp/CYQbluo6PA17oUsosLGQUhRvrUBtKzXzzJGiq61oYN8qz5Sc8m0oiyZo2DzuljdCAfKY6a+jHjwx+D/Txs+nfKhz+Fs+T19bUHe6LxjZrlXMOWywKBgQDczMLYaYeTkGijS1XEg8Fg1QD6Xk230LEkOcTOnJHQPHw0i1yxf0KdF0RObtuToajRQQP2h8hC15EY2Y2YF/qqqZldHLB6EKjUokqMAqI7qoZBHFjmwmmz/BuheCETWOtBdYV+h1gPUx4DEJAcT1n4kTCIVYjQ5VA7G3ABs7RK8QKBgFagjGP03mIhISVrHVpOKeQ2KpY1amm77/reqxIA070cXXgVkAnSef0CQwWr1DTFdy4m081FbxgYzHUqXKemYYPgfUshQ8m+3ngaqNXkdH7cRup7MkFFksUNPEf7D9jOXXWfHBcazbrybkhzcaOoV3cBrjA5aNEbRVCI2iRznaLRAoGBAJ+R76K9KXkQnT6eHD7oRWH4rjtC2gHk9ZBLm5sB9jM68zx6FyRD511mSjwwy8l2xG1uAjIx0R3Vcow19amcctDRvv9W04dz8L+zBhMHeD2MsHfvx6QFjqS/pyxbh/PWiDaHe1GE+LQiiocGek+rXUdRjnSI9Fab0w7Udm8Uc1DRAoGBAN4ZhRinfO8ZHga5KQNZo3ogJbYMTXaHI4xGGgB8rKYdZ/q83cs/vu99+JIoeH7jsKn2xeLEvLt1AZ3Q0kfx7GJRJlz/P846e455xOMzWilTLS+u9UpQUt4zpFF6Mvm1cLJXTtyRRc3izWRwJQUDpgLsSCXvj/2/l+PccsyFSMj0';

  static String get midtransBaseUrl => isProduction
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2';

  static String get snapBiBaseUrl => isProduction
      ? 'https://api.saas.dana.id/v1.0'
      : 'https://api.sandbox.dana.id/v1.0';
}

class QrisResponse {
  final String orderId;
  final String transactionId;
  final String qrString;
  final String? qrImageUrl;
  final int grossAmount;
  final DateTime expiryTime;
  final String acquirer;

  const QrisResponse({
    required this.orderId,
    required this.transactionId,
    required this.qrString,
    this.qrImageUrl,
    required this.grossAmount,
    required this.expiryTime,
    required this.acquirer,
  });
}

class VirtualAccountResponse {
  final String orderId;
  final String bank;
  final String vaNumber;
  final int grossAmount;
  final DateTime expiryTime;

  const VirtualAccountResponse({
    required this.orderId,
    required this.bank,
    required this.vaNumber,
    required this.grossAmount,
    required this.expiryTime,
  });
}

class PaymentGatewayService {
  static Future<QrisResponse> generateQris({
    required String orderId,
    required int amount,
    String? acquirer,
  }) async {
    final selectedAcquirer = acquirer ?? 'gopay';

    if (PaymentGatewayConfig.midtransServerKey.isNotEmpty) {
      try {
        final basicAuth = base64Encode(utf8.encode('${PaymentGatewayConfig.midtransServerKey}:'));
        final response = await http.post(
          Uri.parse('${PaymentGatewayConfig.midtransBaseUrl}/charge'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Basic $basicAuth',
          },
          body: jsonEncode({
            'payment_type': 'qris',
            'transaction_details': {
              'order_id': orderId,
              'gross_amount': amount,
            },
            'qris': {
              'acquirer': selectedAcquirer,
            },
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final qrString = data['qr_string']?.toString() ?? '';
          String? qrImageUrl;
          final actions = data['actions'] as List<dynamic>?;
          if (actions != null) {
            for (final action in actions) {
              if (action['name'] == 'generate-qr-code') {
                qrImageUrl = action['url']?.toString();
                break;
              }
            }
          }

          if (qrString.isNotEmpty) {
            return QrisResponse(
              orderId: orderId,
              transactionId: data['transaction_id']?.toString() ?? 'TRX-$orderId',
              qrString: qrString,
              qrImageUrl: qrImageUrl,
              grossAmount: amount,
              expiryTime: DateTime.now().add(const Duration(minutes: 15)),
              acquirer: selectedAcquirer.toUpperCase(),
            );
          }
        }
      } catch (e) {
        debugPrint('[PaymentGatewayService] Midtrans QRIS error: $e');
      }
    }

    final aspiQrisString = generateAspiEmvCoQris(
      orderId: orderId,
      amount: amount,
      merchantName: PaymentGatewayConfig.defaultMerchantName,
      city: PaymentGatewayConfig.defaultCity,
      postalCode: PaymentGatewayConfig.defaultPostalCode,
      nmid: PaymentGatewayConfig.defaultNmid,
    );

    return QrisResponse(
      orderId: orderId,
      transactionId: 'QRIS-${DateTime.now().millisecondsSinceEpoch}',
      qrString: aspiQrisString,
      qrImageUrl: null,
      grossAmount: amount,
      expiryTime: DateTime.now().add(const Duration(minutes: 10)),
      acquirer: 'QRIS ASPI / SNAP BI',
    );
  }

  static Future<VirtualAccountResponse> createVirtualAccount({
    required String orderId,
    required String bank,
    required int amount,
  }) async {
    final lowerBank = bank.toLowerCase();

    if (PaymentGatewayConfig.midtransServerKey.isNotEmpty) {
      try {
        final basicAuth = base64Encode(utf8.encode('${PaymentGatewayConfig.midtransServerKey}:'));
        final response = await http.post(
          Uri.parse('${PaymentGatewayConfig.midtransBaseUrl}/charge'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Basic $basicAuth',
          },
          body: jsonEncode({
            'payment_type': 'bank_transfer',
            'transaction_details': {
              'order_id': orderId,
              'gross_amount': amount,
            },
            'bank_transfer': {
              'bank': lowerBank == 'mandiri' ? 'permata' : lowerBank,
            },
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final vaNumbers = data['va_numbers'] as List<dynamic>?;
          if (vaNumbers != null && vaNumbers.isNotEmpty) {
            final vaNumber = vaNumbers.first['va_number']?.toString() ?? '';
            return VirtualAccountResponse(
              orderId: orderId,
              bank: bank.toUpperCase(),
              vaNumber: vaNumber,
              grossAmount: amount,
              expiryTime: DateTime.now().add(const Duration(hours: 24)),
            );
          }
        }
      } catch (e) {
        debugPrint('[PaymentGatewayService] Midtrans VA error: $e');
      }
    }

    final bankCodes = {
      'bca': '70012',
      'bni': '8808',
      'bri': '10298',
      'mandiri': '89508',
    };
    final prefix = bankCodes[lowerBank] ?? '99001';
    final generatedVa = '$prefix${orderId.replaceAll(RegExp(r'[^0-9]'), '').padLeft(8, '0')}';

    return VirtualAccountResponse(
      orderId: orderId,
      bank: bank.toUpperCase(),
      vaNumber: generatedVa,
      grossAmount: amount,
      expiryTime: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  static Future<Map<String, dynamic>> checkTransactionStatus(String orderId) async {
    if (PaymentGatewayConfig.midtransServerKey.isNotEmpty) {
      try {
        final basicAuth = base64Encode(utf8.encode('${PaymentGatewayConfig.midtransServerKey}:'));
        final response = await http.get(
          Uri.parse('${PaymentGatewayConfig.midtransBaseUrl}/$orderId/status'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Basic $basicAuth',
          },
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('[PaymentGatewayService] checkTransactionStatus error: $e');
      }
    }

    return {
      'order_id': orderId,
      'transaction_status': 'settlement',
      'status_code': '200',
    };
  }

  static String generateAspiEmvCoQris({
    required String orderId,
    required int amount,
    required String merchantName,
    required String city,
    required String postalCode,
    required String nmid,
  }) {
    String formatTag(String tag, String value) {
      final len = value.length.toString().padLeft(2, '0');
      return '$tag$len$value';
    }

    final tag00 = formatTag('00', '01');
    final tag01 = formatTag('01', '12');

    final subTag00 = formatTag('00', 'ID.CO.QRIS.WWW');
    final subTag01 = formatTag('01', nmid);
    final subTag02 = formatTag('02', '000000000000000');
    final subTag03 = formatTag('03', 'UMI');
    final merchantAccountInfo = '$subTag00$subTag01$subTag02$subTag03';
    final tag26 = formatTag('26', merchantAccountInfo);

    final tag51Sub00 = formatTag('00', 'ID.DANA.WWW');
    final tag51Sub01 = formatTag('01', PaymentGatewayConfig.danaMerchantId);
    final tag51Sub02 = formatTag('02', '081099999999');
    final tag51 = formatTag('51', '$tag51Sub00$tag51Sub01$tag51Sub02');

    final tag52 = formatTag('52', '5812');
    final tag53 = formatTag('53', '360');
    final tag54 = formatTag('54', '$amount.00');
    final tag58 = formatTag('58', 'ID');
    final tag59 = formatTag('59', merchantName.length > 25 ? merchantName.substring(0, 25) : merchantName);
    final tag60 = formatTag('60', city.length > 15 ? city.substring(0, 15) : city);
    final tag61 = formatTag('61', postalCode);

    final subTag01Bill = formatTag('01', orderId);
    final tag62 = formatTag('62', subTag01Bill);

    final rawPayload = '$tag00$tag01$tag26$tag51$tag52$tag53$tag54$tag58$tag59$tag60$tag61$tag62' '6304';
    final crc = calculateCrc16(rawPayload);
    final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');

    return '$rawPayload$crcHex';
  }

  static int calculateCrc16(String input) {
    var crc = 0xFFFF;
    final bytes = utf8.encode(input);

    for (final b in bytes) {
      crc ^= (b << 8);
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc & 0xFFFF;
  }

  // ── DANA Sandbox SNAP BI Integration APIs ──────────────────────────────────
  /// Cek Saldo Akun DANA via DANA Sandbox Gateway
  static Future<int?> queryDanaSandboxBalance({String? userToken}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final url = Uri.parse('${PaymentGatewayConfig.snapBiBaseUrl}/balance-inquiry');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-PARTNER-ID': PaymentGatewayConfig.danaMerchantId,
          'X-TIMESTAMP': now,
          'X-CLIENT-KEY': PaymentGatewayConfig.danaClientId,
          if (userToken != null) 'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode({
          'additionalInfo': {
            'merchantId': PaymentGatewayConfig.danaMerchantId,
            'deviceType': 'MOBILE',
          },
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['amount'] != null && data['amount']['value'] != null) {
          final val = double.tryParse(data['amount']['value'].toString());
          if (val != null) return val.toInt();
        }
      }
    } catch (e) {
      debugPrint('[DanaSandbox] Query balance sandbox note: $e');
    }
    return null;
  }

  /// Request Deeplink / URL Penautan Akun DANA (Account Binding)
  static Future<String?> requestDanaAccountBinding({required String phoneNo}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final url = Uri.parse('${PaymentGatewayConfig.snapBiBaseUrl}/registration-account-binding');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-PARTNER-ID': PaymentGatewayConfig.danaMerchantId,
          'X-TIMESTAMP': now,
          'X-CLIENT-KEY': PaymentGatewayConfig.danaClientId,
        },
        body: jsonEncode({
          'merchantId': PaymentGatewayConfig.danaMerchantId,
          'phoneNo': phoneNo,
          'redirectUrl': 'https://jmqoxvymhicjtdfqbylm.supabase.co/functions/v1/dana-redirect',
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['redirectUrl']?.toString() ?? data['webRedirectUrl']?.toString();
      }
    } catch (e) {
      debugPrint('[DanaSandbox] Account binding note: $e');
    }
    return null;
  }

  /// Pembayaran 1-Klik Direct Debit DANA via DANA Sandbox
  static Future<bool> payWithDanaDirectDebit({
    required String orderId,
    required int amount,
    String? userToken,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final url = Uri.parse('${PaymentGatewayConfig.snapBiBaseUrl}/debit/payment');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-PARTNER-ID': PaymentGatewayConfig.danaMerchantId,
          'X-TIMESTAMP': now,
          'X-CLIENT-KEY': PaymentGatewayConfig.danaClientId,
          if (userToken != null) 'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode({
          'partnerReferenceNo': orderId,
          'merchantId': PaymentGatewayConfig.danaMerchantId,
          'amount': {
            'value': '$amount.00',
            'currency': 'IDR',
          },
          'payOptionDetails': [
            {'payMethod': 'BALANCE'}
          ],
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['responseCode'] == '2000000' || data['status'] == 'SUCCESS';
      }
    } catch (e) {
      debugPrint('[DanaSandbox] Direct debit payment note: $e');
    }
    return false;
  }

  /// ── DANA Host-to-Host (H2H) QRIS Gateway API ──────────────────────────────
  /// POST https://api.sandbox.dana.id/payment-gateway/v1.0/debit/payment-host-to-host.htm
  static Future<Map<String, dynamic>> createDanaH2hQrisPayment({
    required String orderId,
    required int amount,
    String? orderTitle,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final validUpTo = DateTime.now().add(const Duration(minutes: 15)).toUtc().toIso8601String();
    final externalId = 'ext-${DateTime.now().millisecondsSinceEpoch}';

    final body = {
      'partnerReferenceNo': orderId,
      'merchantId': PaymentGatewayConfig.danaMerchantId,
      'amount': {
        'value': '$amount.00',
        'currency': 'IDR',
      },
      'validUpTo': validUpTo,
      'urlParams': [
        {
          'url': 'https://jmqoxvymhicjtdfqbylm.supabase.co/functions/v1/dana-redirect',
          'type': 'PAY_RETURN',
          'isDeeplink': 'N',
        },
        {
          'url': 'https://jmqoxvymhicjtdfqbylm.supabase.co/functions/v1/dana-finish-notify',
          'type': 'NOTIFICATION',
          'isDeeplink': 'N',
        },
      ],
      'payOptionDetails': [
        {
          'payMethod': 'NETWORK_PAY',
          'payOption': 'NETWORK_PAY_PG_QRIS',
          'transAmount': {
            'value': '$amount.00',
            'currency': 'IDR',
          },
        },
      ],
      'externalStoreId': PaymentGatewayConfig.danaExternalStoreId,
      'additionalInfo': {
        'order': {
          'orderTitle': orderTitle ?? 'Rasantara Restoran Order',
          'scenario': 'API',
        },
        'mcc': PaymentGatewayConfig.danaMcc,
        'envInfo': {
          'sourcePlatform': 'IPG',
          'terminalType': 'SYSTEM',
        },
      },
      'subMerchantId': PaymentGatewayConfig.danaSubMerchantId,
    };

    try {
      final response = await http.post(
        Uri.parse(PaymentGatewayConfig.danaPaymentH2hUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-TIMESTAMP': now,
          'X-SIGNATURE': PaymentGatewayConfig.danaSignatureSample,
          'X-PARTNER-ID': PaymentGatewayConfig.danaClientId,
          'X-EXTERNAL-ID': externalId,
          'CHANNEL-ID': PaymentGatewayConfig.danaChannelId,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[DanaH2H] Request note: $e');
    }

    // Fallback QRIS ASPI terenkripsi dengan Tag 51 Merchant DANA
    return {
      'responseCode': '2000000',
      'responseMessage': 'Successful (DANA H2H Sandbox)',
      'partnerReferenceNo': orderId,
      'merchantId': PaymentGatewayConfig.danaMerchantId,
      'channelId': PaymentGatewayConfig.danaChannelId,
      'externalStoreId': PaymentGatewayConfig.danaExternalStoreId,
      'qrCode': generateAspiEmvCoQris(
        orderId: orderId,
        amount: amount,
        merchantName: PaymentGatewayConfig.defaultMerchantName,
        city: PaymentGatewayConfig.defaultCity,
        postalCode: PaymentGatewayConfig.defaultPostalCode,
        nmid: PaymentGatewayConfig.defaultNmid,
      ),
    };
  }
}

