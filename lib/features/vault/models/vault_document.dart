class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.name,
    required this.member,
    required this.category,
    required this.encryptedFile,
    required this.addedAt,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final String member;
  final String category;
  final String encryptedFile;
  final DateTime addedAt;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'member': member,
        'category': category,
        'encryptedFile': encryptedFile,
        'addedAt': addedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory VaultDocument.fromJson(Map<String, dynamic> json) => VaultDocument(
        id: json['id'] as String,
        name: json['name'] as String,
        member: json['member'] as String,
        category: json['category'] as String,
        encryptedFile: json['encryptedFile'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        sizeBytes: json['sizeBytes'] as int,
      );
}
