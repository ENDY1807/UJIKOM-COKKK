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

  TableModel({
    required this.idMeja,
    required this.nomorMeja,
    required this.kapasitas,
    this.status = TableStatus.kosong,
  });

  TableModel copyWith({
    int? idMeja,
    String? nomorMeja,
    int? kapasitas,
    TableStatus? status,
  }) {
    return TableModel(
      idMeja: idMeja ?? this.idMeja,
      nomorMeja: nomorMeja ?? this.nomorMeja,
      kapasitas: kapasitas ?? this.kapasitas,
      status: status ?? this.status,
    );
  }

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      idMeja: map['id_meja'] is int
          ? map['id_meja'] as int
          : int.tryParse('${map['id_meja']}') ?? 0,
      nomorMeja: map['nomor_meja'] ?? '',
      kapasitas: map['kapasitas'] is int
          ? map['kapasitas'] as int
          : int.tryParse('${map['kapasitas']}') ?? 4,
      status: TableStatus.fromString(map['status_meja']?.toString() ?? 'Kosong'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idMeja > 0) 'id_meja': idMeja,
      'nomor_meja': nomorMeja,
      'kapasitas': kapasitas,
      'status_meja': status.label,
    };
  }
}
