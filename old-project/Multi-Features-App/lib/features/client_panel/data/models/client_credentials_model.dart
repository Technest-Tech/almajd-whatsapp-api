class ClientCredentials {
  final String email;
  final String password;

  ClientCredentials({
    required this.email,
    required this.password,
  });

  factory ClientCredentials.fromJson(Map<String, dynamic> json) {
    return ClientCredentials(
      email: json['email'] ?? 'almajd@admin.com',
      password: json['password'] ?? 'almajd123',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}
