import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/phone_otp_service.dart';
import '../theme/app_theme.dart';

/// Dialog Verifikasi Kode OTP Telepon / SMS berbasis Supabase Auth
class PhoneOtpDialog extends StatefulWidget {
  final String phoneNumber;
  final String title;
  final String? subtitle;
  final VoidCallback onVerified;

  const PhoneOtpDialog({
    super.key,
    required this.phoneNumber,
    this.title = 'Verifikasi Nomor Telepon',
    this.subtitle,
    required this.onVerified,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String phoneNumber,
    String title = 'Verifikasi Nomor Telepon',
    String? subtitle,
    required VoidCallback onVerified,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PhoneOtpDialog(
        phoneNumber: phoneNumber,
        title: title,
        subtitle: subtitle,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends State<PhoneOtpDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _resendCountdown = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
        setState(() => _resendCountdown = 0);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_resendCountdown > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await PhoneOtpService.instance.sendOtp(
        rawPhone: widget.phoneNumber,
      );
      _startCountdown();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mengirim ulang kode: $e';
        });
      }
    }
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode verifikasi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PhoneOtpService.instance.verifyOtp(
      rawPhone: widget.phoneNumber,
      inputCode: code,
    );

    if (!mounted) return;

    if (res.isValid) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop(true);
      widget.onVerified();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res.message;
      });
      _codeController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPhone = PhoneOtpService.formatDisplayPhone(widget.phoneNumber);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.surfaceCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle ?? 'Masukkan 6 digit kode yang dikirim ke $displayPhone',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Error notification
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6-Digit OTP Boxes
              _buildOtpBoxes(context),
              const SizedBox(height: 16),

              // Countdown / Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_resendCountdown > 0)
                    Text(
                      'Kirim ulang dalam $_resendCountdown detik',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isLoading ? null : _handleResend,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Kirim ulang kode',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.orangePrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: context.isDarkMode ? const Color(0xFF334155) : AppTheme.borderSubtle,
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleVerify,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.orangePrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verifikasi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBoxes(BuildContext context) {
    final text = _codeController.text;
    final borderColor = context.isDarkMode ? const Color(0xFF334155) : AppTheme.borderSubtle;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Invisible TextField capturing inputs
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _codeController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (val) {
                  setState(() {});
                  if (val.trim().length == 6) {
                    _handleVerify();
                  }
                },
              ),
            ),
          ),

          // 6 visible boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final isFilled = index < text.length;
              final isCurrent = index == text.length && _focusNode.hasFocus;
              final digit = isFilled ? text[index] : '';

              return Container(
                width: 44,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.orangePrimary.withValues(alpha: 0.05)
                      : (context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppTheme.orangePrimary
                        : (isFilled
                            ? borderColor.withValues(alpha: 0.8)
                            : borderColor),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Text(
                  digit,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
