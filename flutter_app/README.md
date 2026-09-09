# Calamansi Yield - Flutter Mobile App

This is the new Flutter mobile app for the Calamansi Juice Yield Predictor. It replaces the old Streamlit web app with a proper mobile interface.

## What changed

- **New Flutter mobile interface** instead of the Streamlit web app
- **All 3 models run at once** - when you enter weight, Simple Linear Regression, Multiple Linear Regression, and Polynomial Regression all run and show their results side by side
- **Simple login** - just username and password (at least 4 characters), no complex password rules
- **Cloud database** - data is stored in Supabase instead of a local SQLite file
- **Prediction service** - the model formulas run on a cloud server, so the app stays lightweight

## How to run in Visual Studio Code

### Prerequisites

1. Install the **Flutter SDK** from https://flutter.dev
2. Install the **Flutter extension** in VS Code
3. Install **Android Studio** (for the Android SDK and emulator) or connect a real Android phone with USB debugging enabled

### Steps

1. Open the `flutter_app` folder in VS Code
2. Open the terminal (Terminal > New Terminal)
3. Run:
   ```
   flutter pub get
   ```
4. Press F5 or run:
   ```
   flutter run
   ```
5. Select your Android device or emulator when prompted

### Login

- **Admin account:** username `admin`, password `admin123`
- **User account:** tap "Create a user account" on the login screen and pick any username and a password of at least 4 characters

### What each screen does

**User screens:**
- **Predict** - Enter weight in kg or g, tap "Run all 3 models", see each model's predicted juice in ml and L
- **History** - See your past predictions, long-press any item to delete it

**Admin screens:**
- **Users** - See all registered users, toggle roles between user/admin, delete users
- **Predictions** - See all predictions from all users

## Project structure

```
flutter_app/
  lib/
    main.dart              - App entry point and theme
    config.dart            - Supabase URL and API key
    models.dart            - AppUser and PredictionResult data classes
    services/
      auth_service.dart    - Login, register, session restore
      prediction_service.dart - Calls the cloud prediction function
      history_service.dart  - Fetches and deletes prediction history
    screens/
      login_screen.dart    - Login and register screen
      home_screen.dart     - User prediction screen with results
      history_screen.dart   - User's prediction history
      admin_screen.dart    - Admin dashboard (users + predictions)
  android/                 - Android platform files
  pubspec.yaml             - Flutter dependencies
```
