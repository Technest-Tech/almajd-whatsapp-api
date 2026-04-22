class ClientLimits {
  final String name;
  final String email;
  final int maxRooms;
  final int maxParticipants;
  final int currentRooms;

  ClientLimits({
    required this.name,
    required this.email,
    required this.maxRooms,
    required this.maxParticipants,
    required this.currentRooms,
  });

  factory ClientLimits.fromJson(Map<String, dynamic> json) {
    return ClientLimits(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      maxRooms: json['maxRooms'] as int? ?? 0,
      maxParticipants: json['maxParticipants'] as int? ?? 0,
      currentRooms: json['currentRooms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'maxRooms': maxRooms,
      'maxParticipants': maxParticipants,
      'currentRooms': currentRooms,
    };
  }
}
