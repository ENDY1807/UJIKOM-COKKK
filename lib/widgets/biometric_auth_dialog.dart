import 'package:flutter/material.dart';

class BiometricAuthDialog extends StatefulWidget {
  final String title;
  final String reason;
  final String? amountFormatted;

  const BiometricAuthDialog({
    super.key,
    this.title = 'Kunci Biometrik & PIN Transaksi',
    this.reason = 'Verifikasi sidik jari atau PIN keamanan untuk memproses transaksi',
    this.amountFormatted,
  });

  static Future<bool> authenticate({
    required BuildContext context,
    String title = 'Kunci Biometrik & PIN Transaksi',
    String reason = 'Verifikasi sidik jari atau PIN keamanan Anda',
    String? amountFormatted,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BiometricAuthDialog(
        title: title,
        reason: reason,
        amountFormatted: amountFormatted,
      ),
    );
    return result ?? false;
  }

  @override
  State<BiometricAuthDialog> createState() => _BiometricAuthDialogState();
}

class _BiometricAuthDialogState extends State<BiometricAuthDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _pinController = TextEditingController();
  bool _isAuthenticatingFingerprint = false;
  bool _usePinMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _simulateFingerprintScan() async {
    setState(() {
      _isAuthenticatingFingerprint = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() => _isAuthenticatingFingerprint = false);
    Navigator.of(context).pop(true);
  }

  void _verifyPin() {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _errorMessage = 'PIN transaksi harus berjumlah 6 digit');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                size: 28,
                color: Color(0xFFEA580C),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),

            // Reason
            Text(
              widget.reason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),

            if (widget.amountFormatted != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Pembayaran: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      widget.amountFormatted!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (!_usePinMode) ...[
              // Sensor Fingerprint Scanner
              ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: _isAuthenticatingFingerprint ? null : _simulateFingerprintScan,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFEDD5), Color(0xFFFFF7ED)],
                      ),
                      border: Border.all(
                        color: _isAuthenticatingFingerprint ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.18),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isAuthenticatingFingerprint
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF16A34A),
                              ),
                            )
                          : const Icon(
                              Icons.fingerprint_rounded,
                              size: 48,
                              color: Color(0xFFEA580C),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isAuthenticatingFingerprint ? 'Membaca sidik jari...' : 'Sentuh sensor sidik jari untuk verifikasi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isAuthenticatingFingerprint ? const Color(0xFF16A34A) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.pin_rounded, size: 16),
                label: const Text('Gunakan PIN 6-Digit Saja'),
                onPressed: () => setState(() => _usePinMode = true),
              ),
            ] else ...[
              // PIN Mode
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Masukkan PIN Transaksi (6-Digit)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFEA580C), width: 2),
                  ),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(_errorMessage!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() => _usePinMode = false),
                      child: const Text('Pakai Biometrik', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _verifyPin,
                      child: const Text('Verifikasi PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 4),

            // Cancel Button
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                minimumSize: const Size.fromHeight(36),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
