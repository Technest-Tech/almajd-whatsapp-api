class AdminRoom {
  final String id;
  final String name;
  final String? description;
  final bool hostApproval;
  final int maxParticipants;
  final bool isActive;
  final bool canRecord;
  final String createdAt;
  final String hostLink;
  final String guestLink;
  final List<AdminParticipant> participants;

  AdminRoom({
    required this.id,
    required this.name,
    this.description,
    required this.hostApproval,
    required this.maxParticipants,
    required this.isActive,
    required this.canRecord,
    required this.createdAt,
    required this.hostLink,
    required this.guestLink,
    required this.participants,
  });

  factory AdminRoom.fromJson(Map<String, dynamic> json) {
    return AdminRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      hostApproval: json['hostApproval'] as bool? ?? false,
      maxParticipants: json['maxParticipants'] as int? ?? 50,
      isActive: json['isActive'] as bool? ?? true,
      canRecord: json['canRecord'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      hostLink: json['hostLink'] as String,
      guestLink: json['guestLink'] as String,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => AdminParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'hostApproval': hostApproval,
      'maxParticipants': maxParticipants,
      'isActive': isActive,
      'canRecord': canRecord,
      'createdAt': createdAt,
      'hostLink': hostLink,
      'guestLink': guestLink,
      'participants': participants.map((p) => p.toJson()).toList(),
    };
  }

  AdminRoom copyWith({
    String? id,
    String? name,
    String? description,
    bool? hostApproval,
    int? maxParticipants,
    bool? isActive,
    bool? canRecord,
    String? createdAt,
    String? hostLink,
    String? guestLink,
    List<AdminParticipant>? participants,
  }) {
    return AdminRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hostApproval: hostApproval ?? this.hostApproval,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      isActive: isActive ?? this.isActive,
      canRecord: canRecord ?? this.canRecord,
      createdAt: createdAt ?? this.createdAt,
      hostLink: hostLink ?? this.hostLink,
      guestLink: guestLink ?? this.guestLink,
      participants: participants ?? this.participants,
    );
  }
}

class AdminParticipant {
  final String id;
  final String name;
  final String type; // 'HOST' or 'GUEST'

  AdminParticipant({
    required this.id,
    required this.name,
    required this.type,
  });

  factory AdminParticipant.fromJson(Map<String, dynamic> json) {
    return AdminParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
    };
  }
}

