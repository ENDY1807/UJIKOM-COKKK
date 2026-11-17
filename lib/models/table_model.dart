enum TableStatus {
  kosong('Kosong'),
  terisi('Terisi'),
  reservasi('Reservasi');

  final String label;
  const TableStatus(this.label);

  static TableStatus fromString(String val) {
    return TableStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => TableStatus.kosong,
    );
  }
}

class TableModel {
  final int idMeja;
  final String nomorMeja;
  final int kapasitas;
  final TableStatus status;
  final String? qrCode;

  TableModel({
    required this.idMeja,
    required this.nomorMeja,
    required this.kapasitas,
    this.status = TableStatus.kosong,
    this.qrCode,
  });

  /// Payload QR Code resmi untuk meja ini yang dipindai oleh pelanggan
  String get qrPayload => (qrCode != null && qrCode!.isNotEmpty)
      ? qrCode!
      : 'https://rasantara.app/order?table=${Uri.encodeComponent(nomorMeja)}';

  TableModel copyWith({
    int? idMeja,
    String? nomorMeja,
    int? kapasitas,
    TableStatus? status,
    String? qrCode,
  }) {
    return TableModel(
      idMeja: idMeja ?? this.idMeja,
      nomorMeja: nomorMeja ?? this.nomorMeja,
      kapasitas: kapasitas ?? this.kapasitas,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
    );
  }

  factory TableModel.fromMap(Map<String, dynamic> map) {
    final noMeja = map['nomor_meja']?.toString() ?? '';
    return TableModel(
      idMeja: map['id_meja'] is int
          ? map['id_meja'] as int
          : int.tryParse('${map['id_meja']}') ?? 0,
      nomorMeja: noMeja,
      kapasitas: map['kapasitas'] is int
          ? map['kapasitas'] as int
          : int.tryParse('${map['kapasitas']}') ?? 4,
      status: TableStatus.fromString(map['status']?.toString() ?? map['status_meja']?.toString() ?? 'Kosong'),
      qrCode: map['qr_code']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idMeja > 0) 'id_meja': idMeja,
      'nomor_meja': nomorMeja,
      'kapasitas': kapasitas,
      'status_meja': status.label,
      'qr_code': qrPayload,
    };
  }
}
