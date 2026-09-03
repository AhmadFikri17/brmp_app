/// Model untuk menyimpan state relay
class RelayModel {
  final String id;
  final String name;
  bool isOn;
  String status;

  RelayModel({
    required this.id,
    required this.name,
    this.isOn = false,
    this.status = 'OFF',
  });

  /// Update status relay dari pesan MQTT
  void updateStatus(String newStatus) {
    status = newStatus;
    isOn = newStatus.toUpperCase() == 'ON';
  }

  /// Copy dengan nilai baru
  RelayModel copyWith({
    String? id,
    String? name,
    bool? isOn,
    String? status,
  }) {
    return RelayModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isOn: isOn ?? this.isOn,
      status: status ?? this.status,
    );
  }
}