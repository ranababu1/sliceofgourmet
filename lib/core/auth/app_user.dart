class AppUser {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  String get firstName {
    final parts = displayName.trim().split(' ');
    return parts.isEmpty ? displayName : parts.first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
      };
}
