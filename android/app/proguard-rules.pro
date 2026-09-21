# tflite_flutter's GpuDelegate wrapper references GPU-delegate classes that
# aren't bundled — the app only ever runs the on-device face-match model on
# CPU (see SPEC.md), so these are safe to not warn about.
-dontwarn org.tensorflow.lite.gpu.**

# TFLite's interpreter loads some classes via reflection; keep them all so
# R8 doesn't strip anything the interpreter needs at runtime.
-keep class org.tensorflow.lite.** { *; }
