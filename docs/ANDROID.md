# Experimental Android Cross-Compilation

This repository primarily targets Linux headunit deployments. The Android build flow below is an **experimental** starting point for producing native libraries (`.so`) with the Android NDK. It does **not** produce a complete APK; you still need an Android app wrapper (Java/Kotlin) that loads the native library via JNI and provides rendering, audio, and USB/Wi‑Fi handling.

## Prerequisites
- Android Studio with NDK installed (tested with r26+).
- CMake 3.22+ and Ninja (bundled with the NDK toolchains).
- Set one of the following environment variables to the NDK path:
  - `ANDROID_NDK` (preferred)
  - `ANDROID_NDK_HOME`
- A host build of `protoc` that matches the `protobuf` version vendored in this repo (or use the prebuilt `protoc` shipped with the NDK if compatible).

## Configure with the Android toolchain
An example command line for ARM64 (`arm64-v8a`) on API level 24:

```bash
cmake -S . -B build-android \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake_modules/Toolchain-android.cmake \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_SYSTEM_VERSION=24 \
  -DAASDK_ENABLE_TESTS=OFF
```

Key notes:
- The toolchain file reads `ANDROID_NDK`/`ANDROID_NDK_HOME` and fails early if neither is set.
- The default STL is `c++_static`; override with `-DCMAKE_ANDROID_STL_TYPE=c++_shared` if you want shared STL.
- Tests are disabled by default in the example because the test harness targets desktop environments.

## Build
```bash
cmake --build build-android
```
This produces Android-targeted static and shared libraries under `build-android/lib/`.

## Integrating into an Android app
1. Copy the resulting `.so` files into your app module’s `src/main/jniLibs/<abi>/` directory.
2. Add a JNI shim that exposes the required AASDK entry points to the Android runtime.
3. Implement Android-side USB or Wi‑Fi transport and forward the raw transport streams into the native library.
4. Provide rendering (e.g., `SurfaceView`/`TextureView`) and audio output plumbing on the Android side.

## Known gaps / next steps
- No JNI bridge or Android Java/Kotlin wrapper is included.
- Some desktop-oriented dependencies (e.g., libusb) may require Android-compatible replacements or wrappers.
- CI does not validate Android builds; treat this as a manual/experimental flow.
