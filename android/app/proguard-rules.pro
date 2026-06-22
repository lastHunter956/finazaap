# MediaPipe
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protocol Buffers
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Auto Value (referenced by MediaPipe)
-keep class com.google.auto.value.** { *; }
-dontwarn com.google.auto.value.**
