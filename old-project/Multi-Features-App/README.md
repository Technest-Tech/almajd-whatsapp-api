# Almajd Academy - Multi-Features Management App

A modern, scalable Flutter mobile management application built with Clean Architecture and best practices.

## 🚀 Features

### ✅ Phase 1 (Current)
- **Authentication System** with role-based access (Admin, Teacher, Student)
- **Dashboard** with 4 main management modules
- **Modern UI/UX** with Material 3 design
- **Animated Transitions** and smooth user experience
- **Modular Architecture** ready for scaling

### 📱 Management Modules

1. **Meeting Rooms Management**
   - Room booking and scheduling (Coming Soon)
   - Availability management (Coming Soon)

2. **Courses & Students Management**
   - Course creation and management (Coming Soon)
   - Student enrollment and tracking (Coming Soon)
   - Teacher assignments (Coming Soon)

3. **Billing Management**
   - Invoice generation (Coming Soon)
   - Payment tracking (Coming Soon)

4. **Calendar & Reports Management**
   - Event calendar (Coming Soon)
   - Certifications (Coming Soon)
   - Academic reports (Coming Soon)

## 🏗️ Architecture

The app follows **Clean Architecture** principles with a clear separation of concerns:

```
lib/
├── core/                    # Core functionality
│   ├── constants/          # App constants (colors, strings, sizes)
│   ├── models/             # Core data models
│   ├── router/             # Navigation configuration
│   ├── theme/              # App theming
│   └── utils/              # Utilities (API service, etc.)
├── features/               # Feature modules
│   ├── auth/              # Authentication
│   │   ├── data/          # Data layer
│   │   ├── domain/        # Domain layer
│   │   └── presentation/  # UI layer
│   ├── dashboard/         # Main dashboard
│   ├── meetings/          # Meeting rooms module
│   ├── courses/           # Courses module
│   ├── billing/           # Billing module
│   └── calendar/          # Calendar module
└── common_widgets/        # Reusable UI components
```

## 🛠️ Tech Stack

- **Flutter** - Latest stable version
- **State Management** - flutter_bloc (BLoC pattern)
- **Navigation** - go_router
- **UI/UX** - Material 3 with flutter_animate
- **Fonts** - Google Fonts (Poppins)
- **HTTP Client** - Dio (ready for API integration)
- **Code Quality** - flutter_lints

## 🎨 Design Principles

- **Material 3** design system
- **Gradient backgrounds** and modern aesthetics
- **Smooth animations** and transitions
- **Consistent spacing** and typography
- **Responsive layouts** for all screen sizes
- **Professional color palette** with proper hierarchy

## 🔐 Test Credentials

### Admin Access
- Email: `admin@almajd.com`
- Password: `admin123`
- Access: All modules
  
### Teacher Access
- Email: `teacher@almajd.com`
- Password: `teacher123`
- Access: Meetings, Courses, Calendar

### Student Access
- Email: `student@almajd.com`
- Password: `student123`
- Access: Courses, Calendar

## 📦 Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Multi-Features-App
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 🔧 Development Setup

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code with Flutter extensions
- Android SDK / Xcode (for iOS)

### Project Setup
```bash
# Get dependencies
flutter pub get

# Run code generation (if needed)
flutter pub run build_runner build

# Run the app in debug mode
flutter run

# Run the app in release mode
flutter run --release
```

## 📱 Building for Production

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## 📝 Code Style

The project follows Flutter's official style guide and uses `flutter_lints` for code analysis.

```bash
# Analyze code
flutter analyze

# Format code
flutter format lib/
```

## 🔄 State Management

The app uses **BLoC pattern** for state management:

- **Events**: User actions and external triggers
- **States**: UI states based on business logic
- **BLoC**: Business logic component that processes events and emits states

Example:
```dart
context.read<AuthBloc>().add(LoginEvent(email: email, password: password));
```

## 🌐 API Integration (Ready)

The app includes a pre-configured `ApiService` using Dio for future backend integration:

```dart
final apiService = ApiService();
await apiService.get('/endpoint');
await apiService.post('/endpoint', data: {...});
```

## 🎯 Next Steps

1. **Backend Integration**: Connect to actual API endpoints
2. **Implement Module Features**: Build out each management module
3. **Add Real-time Features**: Using WebSockets or Firebase
4. **Implement Notifications**: Push notifications for updates
5. **Add Offline Support**: Local database with sync
6. **iOS Deployment**: Prepare for App Store submission

## 👨‍💻 Development Guidelines

### Adding a New Feature Module

1. Create folder structure in `features/`
2. Implement data layer (repositories, models)
3. Implement domain layer (use cases, entities)
4. Implement presentation layer (pages, widgets, BLoC)
5. Add routes in `app_router.dart`
6. Update dashboard if needed

### Creating Reusable Widgets

Place common widgets in `common_widgets/` directory.

## 📄 License

This project is proprietary software for Almajd Academy.

## 🤝 Contributing

This is a private project. For contributions, please contact the project maintainers.

---

**Built with ❤️ using Flutter**




