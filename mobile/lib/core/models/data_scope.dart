enum DataScopeType { company, station }

class DataScopeOption {
  const DataScopeOption({
    required this.keyName,
    required this.label,
    required this.type,
    this.description,
  });

  final String keyName;
  final String label;
  final DataScopeType type;
  final String? description;
}
