class AppUser {
  final String id;
  final String displayName;
  final String email;

  const AppUser(
      {required this.id, required this.displayName, required this.email});

  String get firstName {
    final parts = displayName.trim().split(' ');
    return parts.isEmpty ? displayName : parts.first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
      };
}
