import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/room_model.dart';
import '../../data/services/client_api_service.dart';
import '../../data/services/client_auth_service.dart';
import '../widgets/client_panel_layout.dart';
import '../widgets/room_card.dart';

class RoomsManagementPage extends StatefulWidget {
  const RoomsManagementPage({super.key});

  @override
  State<RoomsManagementPage> createState() => _RoomsManagementPageState();
}

class _RoomsManagementPageState extends State<RoomsManagementPage> {
  List<Room> _rooms = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _userEmail = '';
  Room? _editingRoom;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = ClientAuthService.currentUser;
      if (user != null) {
        _userEmail = user['email'] as String? ?? '';
      }

      final rooms = await ClientApiService.getRooms();
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الغرف: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الغرفة "${room.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ClientApiService.deleteRoom(room.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الغرفة بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadRooms();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حذف الغرفة: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  List<Room> get _filteredRooms {
    if (_searchQuery.isEmpty) return _rooms;
    return _rooms
        .where((room) =>
            room.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ClientPanelLayout(
      title: 'إدارة الغرف',
      subtitle: 'إنشاء وإدارة غرف المؤتمرات',
      currentRoute: currentRoute,
      userEmail: _userEmail,
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showCreateRoomDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إنشاء غرفة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceMd,
              vertical: AppSizes.spaceSm,
            ),
          ),
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(AppSizes.spaceLg),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث عن غرفة بالاسم...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),

                // Rooms List
                Expanded(
                  child: _filteredRooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty
                                    ? Icons.meeting_room_rounded
                                    : Icons.search_off_rounded,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'لا توجد غرف'
                                    : 'لا توجد نتائج',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.spaceSm),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'ابدأ بإنشاء غرفة جديدة'
                                    : 'لم يتم العثور على غرف تطابق "$_searchQuery"',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: AppSizes.spaceLg),
                                ElevatedButton.icon(
                                  onPressed: () => _showCreateRoomDialog(),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('إنشاء غرفة جديدة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spaceLg,
                          ),
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = _filteredRooms[index];
                            return RoomCard(
                              room: room,
                              onEdit: () => _showEditRoomDialog(room),
                              onDelete: () => _deleteRoom(room),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _showCreateRoomDialog() async {
    final result = await showDialog<Room>(
      context: context,
      builder: (context) => _CreateRoomDialog(userEmail: _userEmail),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الغرفة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRooms();
    }
  }

  Future<void> _showEditRoomDialog(Room room) async {
    final result = await showDialog<Room>(
      context: context,
      builder: (context) => _EditRoomDialog(room: room),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الغرفة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRooms();
    }
  }
}

// Simplified Create Room Dialog
class _CreateRoomDialog extends StatefulWidget {
  final String userEmail;

  const _CreateRoomDialog({required this.userEmail});

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customRoomLinkController = TextEditingController();
  bool _allowMultipleHosts = false;
  bool _canRecord = false;
  bool _requireWaitingRoom = false;
  bool _allowGuestUnmute = true;
  bool _enablePrivateChat = true;
  bool _passwordRequired = false;
  String _passwordFor = 'HOST_ONLY'; // 'HOST_ONLY' or 'HOST_AND_GUEST'
  bool _useCustomLink = false;
  bool _isLoading = false;
  bool _isCheckingLink = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    _customRoomLinkController.dispose();
    super.dispose();
  }
  
  Future<void> _checkCustomLinkAvailability() async {
    final link = _customRoomLinkController.text.trim();
    if (link.isEmpty) return;
    
    setState(() => _isCheckingLink = true);
    try {
      final isAvailable = await ClientApiService.checkRoomNameAvailability(
        '',
        customRoomLink: link,
      );
      
      if (mounted) {
        if (!isAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رابط الغرفة مستخدم بالفعل'),
              backgroundColor: AppColors.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رابط الغرفة متاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      // Link check failed, but continue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحقق من رابط الغرفة: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingLink = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Validate custom link if using it
      if (_useCustomLink && _customRoomLinkController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال رابط مخصص للغرفة'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // Validate password if required
      if (_passwordRequired && _passwordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال كلمة المرور'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      final room = await ClientApiService.createRoom(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        allowMultipleHosts: _allowMultipleHosts,
        canRecord: _canRecord,
        requireWaitingRoom: _requireWaitingRoom,
        allowGuestUnmute: _allowGuestUnmute,
        enablePrivateChat: _enablePrivateChat,
        password: _passwordRequired ? _passwordController.text.trim() : null,
        passwordRequired: _passwordRequired,
        passwordFor: _passwordRequired ? _passwordFor : null,
        customRoomLink: _useCustomLink && _customRoomLinkController.text.trim().isNotEmpty
            ? _customRoomLinkController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context, room);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إنشاء الغرفة: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء غرفة جديدة'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الغرفة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'اسم الغرفة مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceMd),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'وصف الغرفة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSizes.spaceMd),
                
                // Custom Room Link (only for almajd@admin.com)
                if (widget.userEmail == 'almajd@admin.com') ...[
                  CheckboxListTile(
                    title: const Text('استخدام رابط مخصص'),
                    value: _useCustomLink,
                    onChanged: (value) {
                      setState(() {
                        _useCustomLink = value ?? false;
                        if (!_useCustomLink) {
                          _customRoomLinkController.clear();
                        }
                      });
                    },
                  ),
                  if (_useCustomLink) ...[
                    TextFormField(
                      controller: _customRoomLinkController,
                      decoration: InputDecoration(
                        labelText: 'رابط الغرفة المخصص',
                        hintText: 'أحرف وأرقام فقط',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isCheckingLink
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: _checkCustomLinkAvailability,
                              ),
                      ),
                      onChanged: (value) {
                        // Validate format: only alphanumeric
                        if (value.isNotEmpty && !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يجب أن يحتوي رابط الغرفة على أحرف وأرقام فقط'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                      validator: (value) {
                        if (_useCustomLink && (value == null || value.trim().isEmpty)) {
                          return 'رابط الغرفة مطلوب';
                        }
                        if (value != null && value.isNotEmpty && !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                          return 'يجب أن يحتوي رابط الغرفة على أحرف وأرقام فقط';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                  ],
                ],
                
                // Waiting Room
                CheckboxListTile(
                  title: const Text('يتطلب غرفة الانتظار'),
                  value: _requireWaitingRoom,
                  onChanged: (value) =>
                      setState(() => _requireWaitingRoom = value ?? false),
                ),
                
                // Password Protection
                CheckboxListTile(
                  title: const Text('يتطلب كلمة مرور'),
                  value: _passwordRequired,
                  onChanged: (value) {
                    setState(() {
                      _passwordRequired = value ?? false;
                      if (!_passwordRequired) {
                        _passwordController.clear();
                      }
                    });
                  },
                ),
                if (_passwordRequired) ...[
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (_passwordRequired && (value == null || value.trim().isEmpty)) {
                        return 'كلمة المرور مطلوبة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.spaceSm),
                  const Text(
                    'كلمة المرور مطلوبة لـ:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioListTile<String>(
                    title: const Text('المضيف فقط'),
                    value: 'HOST_ONLY',
                    groupValue: _passwordFor,
                    onChanged: (value) => setState(() => _passwordFor = value ?? 'HOST_ONLY'),
                  ),
                  RadioListTile<String>(
                    title: const Text('المضيف والضيف'),
                    value: 'HOST_AND_GUEST',
                    groupValue: _passwordFor,
                    onChanged: (value) => setState(() => _passwordFor = value ?? 'HOST_AND_GUEST'),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                ],
                
                CheckboxListTile(
                  title: const Text('السماح بعدة مضيفين'),
                  value: _allowMultipleHosts,
                  onChanged: (value) =>
                      setState(() => _allowMultipleHosts = value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('تفعيل التسجيل'),
                  value: _canRecord,
                  onChanged: (value) =>
                      setState(() => _canRecord = value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('السماح للضيوف بإلغاء كتم الصوت'),
                  value: _allowGuestUnmute,
                  onChanged: (value) =>
                      setState(() => _allowGuestUnmute = value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('تفعيل الدردشة الخاصة'),
                  value: _enablePrivateChat,
                  onChanged: (value) =>
                      setState(() => _enablePrivateChat = value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إنشاء'),
        ),
      ],
    );
  }
}

// Simplified Edit Room Dialog
class _EditRoomDialog extends StatefulWidget {
  final Room room;

  const _EditRoomDialog({required this.room});

  @override
  State<_EditRoomDialog> createState() => _EditRoomDialogState();
}

class _EditRoomDialogState extends State<_EditRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _passwordController;
  bool _allowMultipleHosts = false;
  bool _canRecord = false;
  bool _requireWaitingRoom = false;
  bool _allowGuestUnmute = true;
  bool _enablePrivateChat = true;
  bool _passwordRequired = false;
  String _passwordFor = 'HOST_ONLY';
  bool _isLoading = false;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _descriptionController = TextEditingController(text: widget.room.description ?? '');
    _passwordController = TextEditingController();
    _loadRoomDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomDetails() async {
    try {
      final dio = await ClientAuthService.getDio();
      final response = await dio.get('/api/client/rooms/${widget.room.id}');
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final roomData = data['room'] as Map<String, dynamic>? ?? data;
        
        setState(() {
          _nameController.text = roomData['name'] as String? ?? widget.room.name;
          _descriptionController.text = roomData['description'] as String? ?? '';
          _allowMultipleHosts = roomData['allowMultipleHosts'] as bool? ?? false;
          _canRecord = roomData['canRecord'] as bool? ?? false;
          _requireWaitingRoom = roomData['requireWaitingRoom'] as bool? ?? false;
          _allowGuestUnmute = roomData['allowGuestUnmute'] as bool? ?? true;
          _enablePrivateChat = roomData['enablePrivateChat'] as bool? ?? true;
          _passwordRequired = roomData['passwordRequired'] as bool? ?? false;
          _passwordFor = roomData['passwordFor'] as String? ?? 'HOST_ONLY';
          _isLoadingDetails = false;
        });
      } else {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      // Continue with default values if fetch fails
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Note: If passwordRequired is true but password is empty, 
      // the backend will keep the existing password
      
      final room = await ClientApiService.updateRoom(
        roomId: widget.room.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        allowMultipleHosts: _allowMultipleHosts,
        canRecord: _canRecord,
        requireWaitingRoom: _requireWaitingRoom,
        allowGuestUnmute: _allowGuestUnmute,
        enablePrivateChat: _enablePrivateChat,
        password: _passwordRequired && _passwordController.text.trim().isNotEmpty
            ? _passwordController.text.trim()
            : null,
        passwordRequired: _passwordRequired,
        passwordFor: _passwordRequired ? _passwordFor : null,
      );

      if (mounted) {
        Navigator.pop(context, room);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الغرفة: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الغرفة'),
      content: SizedBox(
        width: 400,
        child: _isLoadingDetails
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الغرفة',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'اسم الغرفة مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'وصف الغرفة (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      
                      // Waiting Room
                      CheckboxListTile(
                        title: const Text('يتطلب غرفة الانتظار'),
                        value: _requireWaitingRoom,
                        onChanged: (value) =>
                            setState(() => _requireWaitingRoom = value ?? false),
                      ),
                      
                      // Password Protection
                      CheckboxListTile(
                        title: const Text('يتطلب كلمة مرور'),
                        value: _passwordRequired,
                        onChanged: (value) {
                          setState(() {
                            _passwordRequired = value ?? false;
                            if (!_passwordRequired) {
                              _passwordController.clear();
                            }
                          });
                        },
                      ),
                      if (_passwordRequired) ...[
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور (اتركه فارغاً للاحتفاظ بالكلمة الحالية)',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: AppSizes.spaceSm),
                        const Text(
                          'كلمة المرور مطلوبة لـ:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        RadioListTile<String>(
                          title: const Text('المضيف فقط'),
                          value: 'HOST_ONLY',
                          groupValue: _passwordFor,
                          onChanged: (value) => setState(() => _passwordFor = value ?? 'HOST_ONLY'),
                        ),
                        RadioListTile<String>(
                          title: const Text('المضيف والضيف'),
                          value: 'HOST_AND_GUEST',
                          groupValue: _passwordFor,
                          onChanged: (value) => setState(() => _passwordFor = value ?? 'HOST_AND_GUEST'),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                      ],
                      
                      CheckboxListTile(
                        title: const Text('السماح بعدة مضيفين'),
                        value: _allowMultipleHosts,
                        onChanged: (value) =>
                            setState(() => _allowMultipleHosts = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('تفعيل التسجيل'),
                        value: _canRecord,
                        onChanged: (value) =>
                            setState(() => _canRecord = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('السماح للضيوف بإلغاء كتم الصوت'),
                        value: _allowGuestUnmute,
                        onChanged: (value) =>
                            setState(() => _allowGuestUnmute = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('تفعيل الدردشة الخاصة'),
                        value: _enablePrivateChat,
                        onChanged: (value) =>
                            setState(() => _enablePrivateChat = value ?? false),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
