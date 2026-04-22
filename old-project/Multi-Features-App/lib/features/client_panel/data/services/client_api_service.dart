import 'package:dio/dio.dart';
import '../../../../core/constants/app_config.dart';
import '../models/room_model.dart';
import '../models/subscription_model.dart';
import '../models/client_limits_model.dart';
import 'client_auth_service.dart';

class ClientApiService {
  static const String _roomsEndpoint = '/api/client/rooms';
  static const String _subscriptionEndpoint = '/api/client/subscription';
  static const String _limitsEndpoint = '/api/client/limits';
  static const String _checkNameEndpoint = '/api/client/rooms/check-name';

  /// Get a single room by ID
  static Future<Room> getRoom(String roomId) async {
    try {
      final dio = await ClientAuthService.getDio();
      final response = await dio.get('$_roomsEndpoint/$roomId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // API returns { room: {...} } structure
        final roomData = data['room'] as Map<String, dynamic>? ?? data;
        
        // Ensure _count exists, if not create default
        if (!roomData.containsKey('_count')) {
          roomData['_count'] = {
            'participants': 0,
            'files': 0,
          };
        }
        
        return Room.fromJson(roomData);
      } else {
        throw Exception('فشل تحميل الغرفة');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل تحميل الغرفة');
      }
      throw Exception('خطأ في تحميل الغرفة: ${e.toString()}');
    }
  }

  /// Get all rooms
  static Future<List<Room>> getRooms() async {
    try {
      final dio = await ClientAuthService.getDio();
      final response = await dio.get(_roomsEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rooms = data['rooms'] as List<dynamic>? ?? [];
        return rooms.map((room) => Room.fromJson(room as Map<String, dynamic>)).toList();
      } else {
        throw Exception('فشل تحميل الغرف');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل تحميل الغرف');
      }
      throw Exception('خطأ في تحميل الغرف: ${e.toString()}');
    }
  }

  /// Create a new room
  static Future<Room> createRoom({
    required String name,
    String? description,
    bool hostApproval = false,
    bool allowMultipleHosts = false,
    bool canRecord = false,
    bool requireWaitingRoom = false,
    bool allowGuestUnmute = true,
    bool enablePrivateChat = true,
    String? password,
    bool passwordRequired = false,
    String? passwordFor,
    String? customRoomLink,
  }) async {
    try {
      final dio = await ClientAuthService.getDio();
      final requestData = <String, dynamic>{
        'name': name,
        if (description != null) 'description': description,
        'hostApproval': hostApproval,
        'allowMultipleHosts': allowMultipleHosts,
        'canRecord': canRecord,
        'requireWaitingRoom': requireWaitingRoom,
        'allowGuestUnmute': allowGuestUnmute,
        'enablePrivateChat': enablePrivateChat,
        'passwordRequired': passwordRequired,
        if (passwordRequired && password != null) 'password': password,
        if (passwordRequired && passwordFor != null) 'passwordFor': passwordFor,
        if (customRoomLink != null) 'customRoomLink': customRoomLink,
      };

      final response = await dio.post(_roomsEndpoint, data: requestData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        // API returns { room: {...} } structure
        final roomData = data['room'] as Map<String, dynamic>? ?? data;
        
        // Ensure _count exists, if not create default
        if (!roomData.containsKey('_count')) {
          roomData['_count'] = {
            'participants': 0,
            'files': 0,
          };
        }
        
        return Room.fromJson(roomData);
      } else {
        throw Exception('فشل إنشاء الغرفة');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل إنشاء الغرفة');
      }
      throw Exception('خطأ في إنشاء الغرفة: ${e.toString()}');
    }
  }

  /// Update a room
  static Future<Room> updateRoom({
    required String roomId,
    String? name,
    String? description,
    bool? hostApproval,
    bool? allowMultipleHosts,
    bool? canRecord,
    bool? requireWaitingRoom,
    bool? allowGuestUnmute,
    bool? enablePrivateChat,
    String? password,
    bool? passwordRequired,
    String? passwordFor,
  }) async {
    try {
      final dio = await ClientAuthService.getDio();
      final requestData = <String, dynamic>{};

      if (name != null) requestData['name'] = name;
      if (description != null) requestData['description'] = description;
      if (hostApproval != null) requestData['hostApproval'] = hostApproval;
      if (allowMultipleHosts != null) requestData['allowMultipleHosts'] = allowMultipleHosts;
      if (canRecord != null) requestData['canRecord'] = canRecord;
      if (requireWaitingRoom != null) requestData['requireWaitingRoom'] = requireWaitingRoom;
      if (allowGuestUnmute != null) requestData['allowGuestUnmute'] = allowGuestUnmute;
      if (enablePrivateChat != null) requestData['enablePrivateChat'] = enablePrivateChat;
      if (passwordRequired != null) {
        requestData['passwordRequired'] = passwordRequired;
        if (passwordRequired) {
          if (password != null && password.isNotEmpty) {
            requestData['password'] = password;
          }
          // Always send passwordFor when passwordRequired is true
          if (passwordFor != null) {
            requestData['passwordFor'] = passwordFor;
          }
        } else {
          // Set passwordFor to null when passwordRequired is false
          requestData['passwordFor'] = null;
        }
      } else if (passwordFor != null) {
        // If only passwordFor is provided without passwordRequired, handle it
        requestData['passwordFor'] = passwordFor;
      }

      final response = await dio.put('$_roomsEndpoint/$roomId', data: requestData);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // API might return { room: {...} } or just the room object
        final roomData = data['room'] as Map<String, dynamic>? ?? data;
        
        // Ensure _count exists, if not create default
        if (!roomData.containsKey('_count')) {
          roomData['_count'] = {
            'participants': 0,
            'files': 0,
          };
        }
        
        return Room.fromJson(roomData);
      } else {
        throw Exception('فشل تحديث الغرفة');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل تحديث الغرفة');
      }
      throw Exception('خطأ في تحديث الغرفة: ${e.toString()}');
    }
  }

  /// Delete a room
  static Future<void> deleteRoom(String roomId) async {
    try {
      final dio = await ClientAuthService.getDio();
      final response = await dio.delete('$_roomsEndpoint/$roomId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('فشل حذف الغرفة');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل حذف الغرفة');
      }
      throw Exception('خطأ في حذف الغرفة: ${e.toString()}');
    }
  }

  /// Check room name availability
  static Future<bool> checkRoomNameAvailability(String roomName, {String? customRoomLink}) async {
    try {
      final dio = await ClientAuthService.getDio();
      final requestData = <String, dynamic>{};
      
      if (customRoomLink != null) {
        requestData['customRoomLink'] = customRoomLink;
      } else {
        requestData['roomName'] = roomName;
      }

      final response = await dio.post(_checkNameEndpoint, data: requestData);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['available'] as bool? ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Get subscription information
  static Future<Subscription> getSubscription() async {
    try {
      final dio = await ClientAuthService.getDio();
      final response = await dio.get(_subscriptionEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return Subscription.fromJson(data);
      } else {
        throw Exception('فشل تحميل معلومات الاشتراك');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل تحميل معلومات الاشتراك');
      }
      throw Exception('خطأ في تحميل معلومات الاشتراك: ${e.toString()}');
    }
  }

  /// Get client limits
  static Future<ClientLimits> getLimits() async {
    try {
      final dio = await ClientAuthService.getDio();
      final response = await dio.get(_limitsEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return ClientLimits.fromJson(data);
      } else {
        throw Exception('فشل تحميل الحدود');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'فشل تحميل الحدود');
      }
      throw Exception('خطأ في تحميل الحدود: ${e.toString()}');
    }
  }
}
