# Running Calamansi Yield outside Bolt

The project includes two ways to run the app.

## Browser version

The `web/` folder is a standalone browser version. It uses the same deployed prediction service and asks the user only for batch weight in grams.

Open `web/index.html` through any static web host. No Bolt runtime is required.

## Flutter web and Android APK

The `flutter_app/` folder is the full Flutter application. It already contains the Android project and now includes web platform support.

On a computer with Flutter installed:

```text
cd flutter_app
flutter pub get
flutter run -d chrome
flutter build web --release
flutter build apk --release
```

The browser build is created in `flutter_app/build/web/`. The Android release APK is created in `flutter_app/build/app/outputs/flutter-apk/app-release.apk`.

The app's prediction flow is unchanged: a user signs in, enters grams or kilograms, and the three already-trained models run together. Dataset management and retraining remain admin-only features.
