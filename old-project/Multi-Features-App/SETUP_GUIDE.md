# 🚀 Setup Guide - Almajd Academy Management App

## Quick Start

### 1. Install Flutter Dependencies
```bash
cd /Users/ahmedomar/Documents/technest/AlmajdAcademy/Multi-Features-App
flutter pub get
```

### 2. Run the Application
```bash
flutter run
```

### 3. Login with Test Credentials

Choose one of the following test accounts:

#### 🔑 Admin Account (Full Access)
- **Email:** `admin@almajd.com`
- **Password:** `admin123`
- **Access:** All modules (Meetings, Courses, Billing, Calendar)

#### 🔑 Teacher Account (Limited Access)
- **Email:** `teacher@almajd.com`
- **Password:** `teacher123`
- **Access:** Meetings, Courses, Calendar

#### 🔑 Student Account (Basic Access)
- **Email:** `student@almajd.com`
- **Password:** `student123`
- **Access:** Courses, Calendar

## 📱 App Structure Overview

### Current Features (Phase 1)
✅ **Login Page** - Secure authentication with role-based access
✅ **Dashboard** - Main module selector with 4 animated cards
✅ **Placeholder Pages** - For all 4 management modules
✅ **Modern UI** - Material 3 design with animations
✅ **Clean Architecture** - Scalable and maintainable code structure

### Module Placeholders
All modules show "Coming Soon" screens with planned features:

1. **Meeting Rooms Management** 📅
2. **Courses & Students Management** 🎓
3. **Billing Management** 💰
4. **Calendar & Reports Management** 📊

## 🏗️ Architecture Details

### Clean Architecture Layers

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│   (UI, Pages, BLoCs, Widgets)       │
├─────────────────────────────────────┤
│       Domain Layer                  │
│   (Entities, Use Cases, Repos)      │
├─────────────────────────────────────┤
│        Data Layer                   │
│   (Models, API, Local Storage)      │
└─────────────────────────────────────┘
```

### State Management (BLoC Pattern)

```dart
User Action → Event → BLoC → State → UI Update
```

**Example:**
```dart
// 1. User taps login button
onPressed: () {
  context.read<AuthBloc>().add(
    LoginEvent(email: email, password: password)
  );
}

// 2. BLoC processes event
// 3. BLoC emits new state (Loading → Authenticated)

// 4. UI listens and updates
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is Authenticated) {
      // Navigate to dashboard
    }
  }
)
```

## 🎨 UI/UX Highlights

### Design System
- **Typography:** Poppins font family
- **Colors:** Blue primary, Purple accent, with gradient overlays
- **Spacing:** Consistent 4dp grid system
- **Animations:** Smooth transitions with flutter_animate

### Key Widgets Created
1. `CustomTextField` - Styled text inputs
2. `CustomButton` - Gradient buttons with loading states
3. `DashboardCard` - Animated module selector cards
4. `LoadingOverlay` - Full-screen loading indicator

## 📂 Project Structure

```
Multi-Features-App/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── core/                              # Core functionality
│   │   ├── constants/
│   │   │   ├── app_colors.dart           # Color palette
│   │   │   ├── app_strings.dart          # Text constants
│   │   │   └── app_sizes.dart            # Spacing & sizes
│   │   ├── models/
│   │   │   ├── user_model.dart           # User entity
│   │   │   └── user_role.dart            # Role enum
│   │   ├── router/
│   │   │   └── app_router.dart           # Navigation config
│   │   ├── theme/
│   │   │   └── app_theme.dart            # Material 3 theme
│   │   └── utils/
│   │       └── api_service.dart          # HTTP client setup
│   ├── features/                          # Feature modules
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── repositories/
│   │   │   │       └── auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── repositories/
│   │   │   │       └── auth_repository.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── auth_bloc.dart
│   │   │       │   ├── auth_event.dart
│   │   │       │   └── auth_state.dart
│   │   │       └── pages/
│   │   │           └── login_page.dart
│   │   ├── dashboard/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── dashboard_page.dart
│   │   ├── meetings/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── meetings_page.dart
│   │   ├── courses/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── courses_page.dart
│   │   ├── billing/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── billing_page.dart
│   │   └── calendar/
│   │       └── presentation/
│   │           └── pages/
│   │               └── calendar_page.dart
│   └── common_widgets/                    # Reusable components
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── dashboard_card.dart
│       └── loading_overlay.dart
├── pubspec.yaml                           # Dependencies
├── analysis_options.yaml                  # Linter rules
├── README.md                              # Project documentation
└── SETUP_GUIDE.md                         # This file
```

## 🔧 Development Workflow

### Adding a New Feature

1. **Create Feature Structure**
   ```bash
   lib/features/new_feature/
   ├── data/
   ├── domain/
   └── presentation/
       ├── bloc/
       ├── pages/
       └── widgets/
   ```

2. **Implement Layers**
   - Data: API calls, models, repository implementation
   - Domain: Entities, use cases, repository interface
   - Presentation: UI, BLoC, widgets

3. **Add Navigation**
   Update `lib/core/router/app_router.dart`

4. **Add Constants**
   Update strings, colors if needed

### Running Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Code Formatting
```bash
flutter format lib/
```

## 🚀 Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🔄 Navigation Flow

```
Login Page (/)
    │
    ├─ [Admin Login] ──────┐
    ├─ [Teacher Login] ─────┤
    └─ [Student Login] ─────┤
                            │
                            ↓
                    Dashboard (/dashboard)
                            │
            ┌───────────────┼───────────────┬───────────────┐
            ↓               ↓               ↓               ↓
      Meetings      Courses & Students   Billing      Calendar & Reports
     (/meetings)       (/courses)      (/billing)      (/calendar)
   [Placeholder]     [Placeholder]   [Placeholder]    [Placeholder]
```

## 📝 Code Examples

### Making API Calls (When Backend is Ready)
```dart
final apiService = ApiService();

// GET request
final response = await apiService.get('/users');

// POST request
final response = await apiService.post('/login', data: {
  'email': email,
  'password': password,
});
```

### Using BLoC
```dart
// Dispatch event
context.read<AuthBloc>().add(LoginEvent(...));

// Listen to state changes
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthLoading) return LoadingWidget();
    if (state is Authenticated) return DashboardWidget();
    return LoginWidget();
  },
)
```

### Navigation
```dart
// Navigate to a route
context.push('/dashboard');

// Navigate and replace
context.go('/dashboard');

// Go back
context.pop();
```

## 🎯 Next Steps for Development

### Phase 2: Meeting Rooms Module
- [ ] Design meeting room model
- [ ] Implement booking system
- [ ] Create room availability calendar
- [ ] Add notifications

### Phase 3: Courses Module
- [ ] Course CRUD operations
- [ ] Lesson management
- [ ] Student enrollment
- [ ] Teacher assignments
- [ ] Grade tracking

### Phase 4: Billing Module
- [ ] Invoice generation
- [ ] Payment tracking
- [ ] Financial reports
- [ ] Payment integration

### Phase 5: Calendar Module
- [ ] Event calendar
- [ ] Timetable view
- [ ] Certificate generation
- [ ] Academic reports

## 🐛 Troubleshooting

### Common Issues

**Issue:** Dependencies not installing
```bash
flutter clean
flutter pub get
```

**Issue:** Build errors
```bash
flutter clean
flutter pub get
flutter run
```

**Issue:** Simulator not showing
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [BLoC Pattern Guide](https://bloclibrary.dev)
- [Material 3 Design](https://m3.material.io)
- [GoRouter Documentation](https://pub.dev/packages/go_router)

## ✅ Checklist for Production

Before deploying to production, ensure:

- [ ] Replace mock authentication with real API
- [ ] Implement proper error handling
- [ ] Add proper logging
- [ ] Implement analytics
- [ ] Add crash reporting
- [ ] Optimize images and assets
- [ ] Test on multiple devices
- [ ] Test offline scenarios
- [ ] Implement proper security measures
- [ ] Add API encryption
- [ ] Review and update permissions
- [ ] Create proper app icons
- [ ] Generate splash screens
- [ ] Update version numbers
- [ ] Test release builds

---

**Need Help?** Contact the development team for support.

**Happy Coding! 🎉**




