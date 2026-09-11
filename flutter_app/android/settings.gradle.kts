pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").let { file ->
            if (file.exists()) {
                properties.load(file.inputStream())
            }
        }
        properties.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")
            ?: System.getenv("FLUTTER_HOME")
            ?: throw org.gradle.api.GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
}

include(":app")

