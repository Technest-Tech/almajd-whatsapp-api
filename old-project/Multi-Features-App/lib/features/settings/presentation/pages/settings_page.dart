import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/settings_remote_datasource.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../../../core/widgets/back_button_handler.dart';
import '../../../lessons/services/lesson_settings_service.dart';

/// Settings Management page with organized sections
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(
              title: const Text('الإعدادات'),
              elevation: 0,
            ),
            body: BlocProvider(
              create: (context) {
                final apiService = ApiService();
                final token = StorageService.getToken();
                token.then((t) {
                  if (t != null) {
                    apiService.setAuthToken(t);
                  }
                });
                final dataSource = SettingsRemoteDataSourceImpl(apiService);
                final bloc = SettingsBloc(dataSource);
                bloc.add(const LoadPaymentSettings());
                bloc.add(const LoadLessonSettings());
                return bloc;
              },
              child: BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, state) {
                  // Show snackbar on error
                  if (state is PaymentSettingsError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
                  }
                  
                  // Show success message on update
                  if (state is PaymentSettingsUpdated) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث إعدادات الدفع بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    });
                  }
                  
                  // Show error for lesson settings
                  if (state is LessonSettingsError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
                  }
                  
                  // Show success message for lesson settings update
                  if (state is LessonSettingsUpdated) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Clear cache so teachers get updated settings
                      LessonSettingsService.clearCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث إعدادات الدروس بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    });
                  }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Payment Settings Section
                      _buildPaymentSettingsSection(context, state),
                      
                      const SizedBox(height: 24),
                      
                      // Lesson Settings Section
                      _buildLessonSettingsSection(context, state),
                      
                      const SizedBox(height: 24),
                      
                      // Placeholder for future sections
                      _buildSectionPlaceholder(
                        context,
                        title: 'إعدادات النظام',
                        icon: Icons.settings_applications_rounded,
                        description: 'إعدادات النظام العامة',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildSectionPlaceholder(
                        context,
                        title: 'إعدادات المستخدمين',
                        icon: Icons.people_rounded,
                        description: 'إعدادات المستخدمين والصلاحيات',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildSectionPlaceholder(
                        context,
                        title: 'إعدادات الإشعارات',
                        icon: Icons.notifications_rounded,
                        description: 'إعدادات الإشعارات والتنبيهات',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildSectionPlaceholder(
                        context,
                        title: 'التقارير',
                        icon: Icons.assessment_rounded,
                        description: 'عرض التقارير والإحصائيات',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildSectionPlaceholder(
                        context,
                        title: 'إعدادات الأمان',
                        icon: Icons.security_rounded,
                        description: 'إعدادات الأمان والخصوصية',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSettingsSection(BuildContext context, SettingsState state) {
    bool paypalEnabled = false;
    bool anubpayEnabled = false;
    bool isLoading = false;

    if (state is SettingsLoaded) {
      paypalEnabled = state.paypalEnabled ?? false;
      anubpayEnabled = state.anubpayEnabled ?? false;
      isLoading = state.isLoadingPayment;
    } else if (state is PaymentSettingsLoaded) {
      paypalEnabled = state.paypalEnabled;
      anubpayEnabled = state.anubpayEnabled;
    } else if (state is PaymentSettingsUpdated) {
      paypalEnabled = state.paypalEnabled;
      anubpayEnabled = state.anubpayEnabled;
    } else if (state is PaymentSettingsLoading) {
      isLoading = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payment_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات الدفع',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'إدارة طرق الدفع المتاحة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Payment Methods
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      // PayPal Toggle
                      _buildPaymentToggle(
                        context,
                        title: 'PayPal',
                        description: 'الدفع الآمن عبر PayPal',
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: const Color(0xFF0070BA),
                        enabled: paypalEnabled,
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                                UpdatePaymentSettings(
                                  paypalEnabled: value,
                                  anubpayEnabled: anubpayEnabled,
                                ),
                              );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // AnubPay Toggle
                      _buildPaymentToggle(
                        context,
                        title: 'AnubPay',
                        description: 'الدفع عبر Credit Card & PayPal',
                        icon: Icons.credit_card_rounded,
                        iconColor: const Color(0xFF4CAF50),
                        enabled: anubpayEnabled,
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                                UpdatePaymentSettings(
                                  paypalEnabled: paypalEnabled,
                                  anubpayEnabled: value,
                                ),
                              );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentToggle(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled
            ? iconColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? iconColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: enabled ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: enabled ? iconColor : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonSettingsSection(BuildContext context, SettingsState state) {
    bool teachersCanEditLessons = false;
    bool teachersCanDeleteLessons = false;
    bool teachersCanAddPastLessons = false;
    bool isLoading = false;

    if (state is SettingsLoaded) {
      teachersCanEditLessons = state.teachersCanEditLessons ?? false;
      teachersCanDeleteLessons = state.teachersCanDeleteLessons ?? false;
      teachersCanAddPastLessons = state.teachersCanAddPastLessons ?? false;
      isLoading = state.isLoadingLesson;
    } else if (state is LessonSettingsLoaded) {
      teachersCanEditLessons = state.teachersCanEditLessons;
      teachersCanDeleteLessons = state.teachersCanDeleteLessons;
      teachersCanAddPastLessons = state.teachersCanAddPastLessons;
    } else if (state is LessonSettingsLoading) {
      isLoading = true;
    } else if (state is LessonSettingsUpdated) {
      teachersCanEditLessons = state.teachersCanEditLessons;
      teachersCanDeleteLessons = state.teachersCanDeleteLessons;
      teachersCanAddPastLessons = state.teachersCanAddPastLessons;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade600,
                  Colors.orange.shade400,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات الدروس للمعلمين',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'التحكم في صلاحيات المعلمين للدروس',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lesson Permissions
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      // Edit Lessons Toggle
                      _buildLessonToggle(
                        context,
                        title: 'السماح بتعديل الدروس',
                        description: 'السماح للمعلمين بتعديل الدروس',
                        icon: Icons.edit_rounded,
                        iconColor: Colors.blue,
                        enabled: teachersCanEditLessons,
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                                UpdateLessonSettings(
                                  teachersCanEditLessons: value,
                                  teachersCanDeleteLessons: teachersCanDeleteLessons,
                                  teachersCanAddPastLessons: teachersCanAddPastLessons,
                                ),
                              );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Delete Lessons Toggle
                      _buildLessonToggle(
                        context,
                        title: 'السماح بحذف الدروس',
                        description: 'السماح للمعلمين بحذف الدروس',
                        icon: Icons.delete_rounded,
                        iconColor: Colors.red,
                        enabled: teachersCanDeleteLessons,
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                                UpdateLessonSettings(
                                  teachersCanEditLessons: teachersCanEditLessons,
                                  teachersCanDeleteLessons: value,
                                  teachersCanAddPastLessons: teachersCanAddPastLessons,
                                ),
                              );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Add Past Lessons Toggle
                      _buildLessonToggle(
                        context,
                        title: 'السماح بإضافة دروس في أيام سابقة',
                        description: 'السماح للمعلمين بإضافة دروس في أيام سابقة (غير اليوم)',
                        icon: Icons.calendar_today_rounded,
                        iconColor: Colors.purple,
                        enabled: teachersCanAddPastLessons,
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                                UpdateLessonSettings(
                                  teachersCanEditLessons: teachersCanEditLessons,
                                  teachersCanDeleteLessons: teachersCanDeleteLessons,
                                  teachersCanAddPastLessons: value,
                                ),
                              );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonToggle(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled
            ? iconColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? iconColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: enabled ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: enabled ? iconColor : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPlaceholder(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
