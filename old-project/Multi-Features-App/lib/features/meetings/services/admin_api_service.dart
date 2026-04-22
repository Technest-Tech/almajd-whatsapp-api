import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_room.dart';
import 'admin_auth_service.dart';

class AdminApiService {
  static const String _baseUrl = 'https://almajdmeet.org';

  // Get all rooms
  static Future<List<AdminRoom>> getRooms() async {
    try {
      print('📋 AdminAPI: Fetching all rooms');
      final token = await AdminAuthService.getToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📋 AdminAPI: Get rooms response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final roomsList = data['rooms'] as List<dynamic>;
        final rooms = roomsList
            .map((room) => AdminRoom.fromJson(room as Map<String, dynamic>))
            .toList();
        print('✅ AdminAPI: Fetched ${rooms.length} rooms');
        return rooms;
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        print('❌ AdminAPI: Get rooms failed - ${error['error']}');
        throw Exception(error['error'] ?? 'Failed to fetch rooms');
      }
    } catch (e) {
      print('❌ AdminAPI: Get rooms error: $e');
      throw Exception('Error fetching rooms: $e');
    }
  }

  // Create a new room
  static Future<AdminRoom> createRoom({
    required String name,
    bool isActive = true,
    bool canRecord = false,
  }) async {
    try {
      print('➕ AdminAPI: Creating room: $name');
      final token = await AdminAuthService.getToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'description': '',
          'hostApproval': false,
          'maxParticipants': 50,
          'isActive': isActive,
          'canRecord': canRecord,
        }),
      );

      print('➕ AdminAPI: Create room response status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final room = AdminRoom.fromJson(data);
        print('✅ AdminAPI: Room created successfully: ${room.id}');
        return room;
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        print('❌ AdminAPI: Create room failed - ${error['error']}');
        throw Exception(error['error'] ?? 'Failed to create room');
      }
    } catch (e) {
      print('❌ AdminAPI: Create room error: $e');
      throw Exception('Error creating room: $e');
    }
  }

  // Update an existing room
  static Future<AdminRoom> updateRoom({
    required String roomId,
    required String name,
    bool? isActive,
    bool? canRecord,
  }) async {
    try {
      print('✏️ AdminAPI: Updating room: $roomId');
      final token = await AdminAuthService.getToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final body = <String, dynamic>{
        'name': name,
      };

      if (isActive != null) {
        body['isActive'] = isActive;
      }
      if (canRecord != null) {
        body['canRecord'] = canRecord;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/admin/rooms/$roomId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      print('✏️ AdminAPI: Update room response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final room = AdminRoom.fromJson(data);
        print('✅ AdminAPI: Room updated successfully: ${room.id}');
        return room;
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        print('❌ AdminAPI: Update room failed - ${error['error']}');
        throw Exception(error['error'] ?? 'Failed to update room');
      }
    } catch (e) {
      print('❌ AdminAPI: Update room error: $e');
      throw Exception('Error updating room: $e');
    }
  }

  // Delete a room
  static Future<void> deleteRoom(String roomId) async {
    try {
      print('🗑️ AdminAPI: Deleting room: $roomId');
      final token = await AdminAuthService.getToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/admin/rooms/$roomId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('🗑️ AdminAPI: Delete room response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ AdminAPI: Room deleted successfully: $roomId');
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        print('❌ AdminAPI: Delete room failed - ${error['error']}');
        throw Exception(error['error'] ?? 'Failed to delete room');
      }
    } catch (e) {
      print('❌ AdminAPI: Delete room error: $e');
      throw Exception('Error deleting room: $e');
    }
  }
}

