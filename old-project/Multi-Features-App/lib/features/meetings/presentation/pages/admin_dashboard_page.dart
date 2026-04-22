import 'package:flutter/material.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../models/admin_room.dart';
import '../../services/admin_api_service.dart';
import '../../services/admin_auth_service.dart';
import '../../widgets/room_card.dart';
import '../../widgets/create_room_modal.dart';
import '../../widgets/edit_room_modal.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<AdminRoom> _rooms = [];
  List<AdminRoom> _filteredRooms = [];
  bool _isLoading = true;
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAndLoadRooms();
  }

  Future<void> _initializeAndLoadRooms() async {
    // Ensure we're authenticated (auto-login if needed)
    await AdminAuthService.getToken();
    _loadRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rooms = await AdminApiService.getRooms();
      setState(() {
        _rooms = rooms;
        _filterRooms();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorLoadingRooms}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterRooms() {
    if (_searchTerm.isEmpty) {
      _filteredRooms = _rooms;
    } else {
      _filteredRooms = _rooms.where((room) {
        final nameMatch = room.name.toLowerCase().contains(_searchTerm.toLowerCase());
        final descMatch = room.description?.toLowerCase().contains(_searchTerm.toLowerCase()) ?? false;
        return nameMatch || descMatch;
      }).toList();
    }
  }

  Future<void> _handleCreateRoom(String name, bool isActive, bool canRecord) async {
    try {
      final newRoom = await AdminApiService.createRoom(
        name: name,
        isActive: isActive,
        canRecord: canRecord,
      );
      setState(() {
        _rooms.insert(0, newRoom);
        _filterRooms();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.roomCreatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorCreatingRoom}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _handleUpdateRoom(AdminRoom room, String name, bool isActive, bool canRecord) async {
    try {
      final updatedRoom = await AdminApiService.updateRoom(
        roomId: room.id,
        name: name,
        isActive: isActive,
        canRecord: canRecord,
      );
      setState(() {
        final index = _rooms.indexWhere((r) => r.id == room.id);
        if (index != -1) {
          _rooms[index] = updatedRoom;
          _filterRooms();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.roomUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorUpdatingRoom}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _handleDeleteRoom(AdminRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteRoom),
        content: Text(AppLocalizations.of(context)!.areYouSureYouWantToDeleteRoom(room.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminApiService.deleteRoom(room.id);
        setState(() {
          _rooms.removeWhere((r) => r.id == room.id);
          _filterRooms();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.roomDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocalizations.of(context)!.errorDeletingRoom}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine grid columns based on screen width
          int crossAxisCount = 1;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 3;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 1;
          }

          return Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.dashboard,
                      color: Colors.blue.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.dashboard,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (MediaQuery.of(context).size.width > 600)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateRoomModal(
                              onCreate: _handleCreateRoom,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.createRoom),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateRoomModal(
                              onCreate: _handleCreateRoom,
                            ),
                          );
                        },
                        tooltip: AppLocalizations.of(context)!.createRoom,
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : CustomScrollView(
                          slivers: [
                            // Search and Stats
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(
                                  MediaQuery.of(context).size.width > 600 ? 24 : 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Stats Cards
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide = constraints.maxWidth > 600;
                                        return isWide
                                            ? Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildStatCard(
                                                      AppLocalizations.of(context)!.totalRooms,
                                                      '${_rooms.length}',
                                                      Colors.blue,
                                                      Icons.meeting_room,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: _buildStatCard(
                                                      AppLocalizations.of(context)!.activeRooms,
                                                      '${_rooms.where((r) => r.isActive).length}',
                                                      Colors.green,
                                                      Icons.check_circle,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  _buildStatCard(
                                                    AppLocalizations.of(context)!.totalRooms,
                                                    '${_rooms.length}',
                                                    Colors.blue,
                                                    Icons.meeting_room,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _buildStatCard(
                                                    AppLocalizations.of(context)!.activeRooms,
                                                    '${_rooms.where((r) => r.isActive).length}',
                                                    Colors.green,
                                                    Icons.check_circle,
                                                  ),
                                                ],
                                              );
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Search Bar
                                    TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(context)!.searchRooms,
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _searchTerm = value;
                                          _filterRooms();
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),

                            // Rooms Grid
                            if (_filteredRooms.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.meeting_room_outlined,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchTerm.isEmpty
                                            ? AppLocalizations.of(context)!.noRoomsFound
                                            : AppLocalizations.of(context)!.noRoomsMatchYourSearch,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (_searchTerm.isEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          AppLocalizations.of(context)!.createYourFirstRoomToGetStarted,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.75,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final room = _filteredRooms[index];
                                      return RoomCard(
                                        room: room,
                                        onEdit: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditRoomModal(
                                              room: room,
                                              onUpdate: (name, isActive, canRecord) =>
                                                  _handleUpdateRoom(room, name, isActive, canRecord),
                                            ),
                                          );
                                        },
                                        onDelete: () => _handleDeleteRoom(room),
                                      );
                                    },
                                    childCount: _filteredRooms.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getDarkerColor(Color color) {
    return Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getDarkerColor(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

