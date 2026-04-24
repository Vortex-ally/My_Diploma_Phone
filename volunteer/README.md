# Volunteer App

A Flutter application for volunteer management and coordination.

## Project Structure

- `lib/` - Main application source code
  - `screens/` - App screens
  - `services/` - API and authentication services
  - `models/` - Data models
  - `providers/` - State management
  - `widgets/` - Reusable UI components
  - `constants/` - App constants and configuration
- `test/` - Test files and utilities
- `android/` - Android platform code
- `ios/` - iOS platform code
- `web/` - Web platform code

## Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Configure API endpoint:
   - Edit `lib/constants/api_config.dart`
   - Set `baseUrl` to your Django server URL

3. Run the app:
```bash
flutter run
```

## Test Data Generation

### Flutter/Dart Script

Location: `test/create_test_users.dart`

A Dart script for testing API integration from the Flutter app.

**Usage:**
```bash
cd volunteer

dart run test/create_test_users.dart

# With custom parameters
dart run test/create_test_users.dart --count 10 --roles volunteer,organiser --url http://localhost:8000
```

**Features:**
- Tests API authentication
- Fetches existing users and projects
- Creates test projects via API
- Applies to projects as volunteer
- Tests all main API endpoints

### Django/Python Scripts (Recommended)

For creating test users with specific roles, use the Django management commands from the backend:

```bash
cd /home/ruslan/Desktop/Diploma/Diploma_web/volunteer

# Create test users
python manage.py create_test_users --count 10

# Create test projects
python manage.py create_test_projects --count 15
```

See [Django Test Data Documentation](../Diploma_web/README_TEST_DATA.md) for details.

## API Configuration

The app connects to a Django backend REST API.

**Default API URL:** `http://192.168.0.105:8000`

**Key Endpoints:**
- `POST /api/auth/login/` - User login
- `GET /api/projects/` - List all projects
- `GET /api/projects/{id}/` - Project details
- `POST /api/projects/{id}/apply/` - Apply to project
- `GET /api/applications/` - My applications
- `GET /api/users/` - List all users (admin only)

## Testing

### Integration Tests

The `test/create_test_users.dart` script verifies:
- API connectivity
- Authentication flow
- Data fetching
- Project creation
- Application submission

### Widget Tests

Run Flutter widget tests:
```bash
flutter test
```

## Development

### Adding New Features

1. Create new screens in `lib/screens/`
2. Add services in `lib/services/`
3. Create models in `lib/models/`
4. Update `lib/constants/api_config.dart` for new endpoints
5. Add tests in `test/`

### API Service Pattern

All API calls go through `ApiService` (singleton) in `lib/services/api_service.dart`:

```dart
final api = ApiService();
final projects = await api.getProjects();
```

## Roles

The app supports three user roles:

1. **Volunteer** - Can browse and apply to projects
2. **Organiser** - Can create and manage projects
3. **Admin** - Full access, user management

## Backend

This Flutter app connects to a Django REST API backend located at:
`/home/ruslan/Desktop/Diploma/Diploma_web/volunteer/`

See the backend README for setup and test data generation instructions.

