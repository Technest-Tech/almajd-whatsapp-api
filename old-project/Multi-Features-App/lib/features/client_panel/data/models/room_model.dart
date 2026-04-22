class Room {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final String hostLink;
  final String guestLink;
  final String? observerLink;
  final int maxParticipants;
  final DateTime createdAt;
  final RoomCount count;

  Room({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.hostLink,
    required this.guestLink,
    this.observerLink,
    required this.maxParticipants,
    required this.createdAt,
    required this.count,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    // Handle null values safely
    final countData = json['_count'] as Map<String, dynamic>?;
    final count = countData != null 
        ? RoomCount.fromJson(countData)
        : RoomCount(participants: 0, files: 0);
    
    return Room(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      hostLink: json['hostLink'] as String? ?? '',
      guestLink: json['guestLink'] as String? ?? '',
      observerLink: json['observerLink'] as String?,
      maxParticipants: json['maxParticipants'] as int? ?? 50,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      count: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
      'hostLink': hostLink,
      'guestLink': guestLink,
      'observerLink': observerLink,
      'maxParticipants': maxParticipants,
      'createdAt': createdAt.toIso8601String(),
      '_count': count.toJson(),
    };
  }
}

class RoomCount {
  final int participants;
  final int files;

  RoomCount({
    required this.participants,
    required this.files,
  });

  factory RoomCount.fromJson(Map<String, dynamic> json) {
    return RoomCount(
      participants: json['participants'] as int? ?? 0,
      files: json['files'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants,
      'files': files,
    };
  }
}
