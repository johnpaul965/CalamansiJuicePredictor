# Calamansi Yield Mobile App

The Flutter app is now the main product experience. The former Streamlit web interface is no longer part of the application flow.

## What the app includes

- Polished mobile login and account creation
- Weight entry in kilograms or grams
- Automatic conversion to grams
- Three yield estimates from the shared prediction service
- Results shown in milliliters and liters
- Prediction history stored in Supabase
- Swipe-to-delete for personal history
- Administrator area for users and all prediction records
- Administrator model-insights screen with dataset and performance metrics
- Persistent sign-in on the device

## Project structure

- `lib/main.dart` — app startup, theme, and sign-in routing
- `lib/screens/` — login, prediction, history, and administrator screens
- `lib/services/` — database, sign-in, history, and prediction requests
- `lib/model_metrics.dart` — model comparison data displayed to administrators
- `supabase/functions/predict/` — shared prediction service

## Run the app

Open the `flutter_app` folder in Visual Studio Code, install the Flutter extension, connect an Android device or emulator, and run the project from the Flutter tools.

The Supabase connection and prediction service are already wired into the app. No separate Streamlit server is required.
