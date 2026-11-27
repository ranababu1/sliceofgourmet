# Flutter and its plugins ship their own consumer rules; these cover the rest.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
# Play Core deferred components are referenced by the engine but unused here.
-dontwarn com.google.android.play.core.**
