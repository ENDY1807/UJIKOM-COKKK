import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'database_service.dart';

class OrderProgressState {
  final int orderId;
  int currentStep; // 1: Diterima, 2: Dimasak, 3: Diantar, 4: Selesai
  final int durasiPenerimaanSec;
  final int durasiPembuatanSec;
  final int durasiPengantaranSec;
  int secondsInCurrentStep;
  String reasonNote;

  OrderProgressState({
    required this.orderId,
    required this.currentStep,
    required this.durasiPenerimaanSec,
    required this.durasiPembuatanSec,
    required this.durasiPengantaranSec,
    this.secondsInCurrentStep = 0,
    this.reasonNote = '',
  });

  int get currentStepTargetDurationSec {
    switch (currentStep) {
      case 1:
        return durasiPenerimaanSec;
      case 2:
        return durasiPembuatanSec;
      case 3:
        return durasiPengantaranSec;
      default:
        return 0;
    }
  }

  double get stepProgress {
    if (currentStep >= 4) return 1.0;
    final target = currentStepTargetDurationSec;
    if (target <= 0) return 1.0;
    return (secondsInCurrentStep / target).clamp(0.0, 1.0);
  }

  int get remainingSecondsInStep {
    if (currentStep >= 4) return 0;
    final rem = currentStepTargetDurationSec - secondsInCurrentStep;
    return rem > 0 ? rem : 0;
  }
}

/// Service simulasi perkembangan pesanan real-time dengan durasi dinamis & acak
/// (misal lama di pembuatan, lama di pengantaran, atau lama di konfirmasi penerimaan).
class OrderSimulationService extends ChangeNotifier {
  static final OrderSimulationService _instance =
      OrderSimulationService._internal();
  factory OrderSimulationService() => _instance;
  OrderSimulationService._internal();

  final Map<int, OrderProgressState> _states = {};
  Timer? _timer;
  DatabaseService? _db;

  void attachDatabase(DatabaseService db) {
    _db = db;
    _checkTimerNeed();
  }

  void _checkTimerNeed() {
    final hasActive = _states.values.any((s) => s.currentStep < 4);
    if (hasActive) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), _onTick);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _states.clear();
  }

  void _onTick(Timer timer) {
    if (_states.isEmpty) return;

    bool hasChanges = false;
    final keys = _states.keys.toList();

    for (final orderId in keys) {
      final state = _states[orderId];
      if (state == null) continue;

      if (state.currentStep >= 4) {
        continue;
      }

      state.secondsInCurrentStep++;
      hasChanges = true;

      // Cek apakah step ini sudah selesai
      if (state.secondsInCurrentStep >= state.currentStepTargetDurationSec) {
        state.secondsInCurrentStep = 0;
        state.currentStep++;

        // Update status di database & cloud
        if (_db != null) {
          if (state.currentStep == 2) {
            _db!.updateOrderStatus(orderId, OrderStatus.diproses);
          } else if (state.currentStep == 3) {
            _db!.updateOrderStatus(orderId, OrderStatus.diproses);
          } else if (state.currentStep >= 4) {
            _db!.updateOrderStatus(orderId, OrderStatus.selesai);
          }
        }
      }
    }

    if (hasChanges) {
      _checkTimerNeed();
      notifyListeners();
    }
  }

  /// Ambil atau inisialisasi state simulasi untuk pesanan tertentu dengan durasi acak
  OrderProgressState getOrCreateProgress(OrderModel order) {
    if (_states.containsKey(order.idOrder)) {
      final existing = _states[order.idOrder]!;
      // Sinkronkan jika di DB sudah selesai
      if (order.status == OrderStatus.selesai && existing.currentStep < 4) {
        existing.currentStep = 4;
        existing.secondsInCurrentStep = 0;
        _checkTimerNeed();
      }
      return existing;
    }

    final random = Random(order.idOrder + DateTime.now().minute);
    final pattern = random.nextInt(3);

    int durasiPenerimaan;
    int durasiPembuatan;
    int durasiPengantaran;
    String note;

    switch (pattern) {
      case 0:
        // Lama di pembuatan / koki memasak hidangan tradisional
        durasiPenerimaan = 8 + random.nextInt(6); // 8 - 13 detik
        durasiPembuatan = 28 + random.nextInt(25); // 28 - 52 detik (LAMA)
        durasiPengantaran = 10 + random.nextInt(8); // 10 - 17 detik
        note = 'Pembuatan hidangan membutuhkan waktu lebih lama untuk bumbu meresap.';
        break;
      case 1:
        // Lama di pengantaran / meja jauh / kurir di jalan
        durasiPenerimaan = 7 + random.nextInt(6); // 7 - 12 detik
        durasiPembuatan = 12 + random.nextInt(10); // 12 - 21 detik
        durasiPengantaran = 25 + random.nextInt(25); // 25 - 49 detik (LAMA)
        note = 'Pengantaran sedang dalam perjalanan dan memerlukan waktu ekstra.';
        break;
      default:
        // Lama di konfirmasi antrean kasir & dapur
        durasiPenerimaan = 20 + random.nextInt(18); // 20 - 37 detik (LAMA)
        durasiPembuatan = 14 + random.nextInt(12); // 14 - 25 detik
        durasiPengantaran = 10 + random.nextInt(8); // 10 - 17 detik
        note = 'Dapur dan kasir sedang mengonfirmasi urutan antrean bahan baku.';
        break;
    }

    int initialStep = 1;
    if (order.status == OrderStatus.diproses) {
      initialStep = 2;
    } else if (order.status == OrderStatus.selesai) {
      initialStep = 4;
    }

    final newState = OrderProgressState(
      orderId: order.idOrder,
      currentStep: initialStep,
      durasiPenerimaanSec: durasiPenerimaan,
      durasiPembuatanSec: durasiPembuatan,
      durasiPengantaranSec: durasiPengantaran,
      reasonNote: note,
    );

    _states[order.idOrder] = newState;
    _checkTimerNeed();
    return newState;
  }

  /// Percepat langsung ke langkah berikutnya (opsi demo/debug saat presentasi)
  void advanceStep(int orderId) {
    final state = _states[orderId];
    if (state == null) return;
    if (state.currentStep < 4) {
      state.currentStep++;
      state.secondsInCurrentStep = 0;
      if (_db != null) {
        if (state.currentStep == 2 || state.currentStep == 3) {
          _db!.updateOrderStatus(orderId, OrderStatus.diproses);
        } else if (state.currentStep >= 4) {
          _db!.updateOrderStatus(orderId, OrderStatus.selesai);
        }
      }
      notifyListeners();
    }
  }

  /// Reset kembali ke tahap awal
  void restartSimulation(int orderId) {
    _states.remove(orderId);
    if (_db != null) {
      _db!.updateOrderStatus(orderId, OrderStatus.menunggu);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
