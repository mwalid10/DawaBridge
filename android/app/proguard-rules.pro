# R8 is enabled for release builds (see build.gradle.kts). Flutter, Firebase
# and the Play Core split-install classes referenced by the Flutter engine
# need to survive shrinking.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core / deferred components — referenced by the engine but not bundled
# unless the app actually uses deferred components.
-dontwarn com.google.android.play.core.**

# Firebase Messaging keeps its service entry points via reflection.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
