# TensorFlow Lite (CPU): optional GPU delegate classes are referenced by the
# Java API but are not on the classpath when not using GPU — satisfy R8.
-dontwarn org.tensorflow.lite.gpu.**

# Keep TFLite runtime surface used via JNI / reflection from tflite_flutter.
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** {
    *;
}
