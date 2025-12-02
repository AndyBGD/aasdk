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

If you prefer an automated bootstrap that downloads the NDK, builds Abseil/Protobuf, and configures an Android build tree, run:

```bash
scripts/bootstrap_android.sh
```

The script stages artifacts in `.android-stage/` and emits the configured build directory location. It intentionally stops before building AASDK binaries until OpenSSL, Boost, and libusb are staged for Android (see notes below).

## Build
```bash
cmake --build build-android
```
This produces Android-targeted static and shared libraries under `build-android/lib/`.

## Bootstrapping Protobuf for Android (experimental)
The Android toolchain does not bundle `protoc` or target libraries, so you need to provide them manually:

1. **Host `protoc`**: download a matching Linux host binary (e.g., `protoc-28.2-linux-x86_64.zip`) and add its `bin/` directory to your `PATH`.
2. **Cross-compiled libraries**:
   - Clone the Protobuf sources (the release tarball omits `third_party/abseil-cpp`, which Protobuf’s CMake build expects) and initialize the Abseil submodule:
     ```bash
     git clone --depth 1 --branch v28.2 https://github.com/protocolbuffers/protobuf.git /workspace/protobuf-src
     (cd /workspace/protobuf-src && git submodule update --init third_party/abseil-cpp)
     ```
   - Configure with the Android toolchain and install to a staging prefix:
     ```bash
     export ANDROID_NDK=/workspace/android-ndk-r26d
     export PATH="$ANDROID_NDK/prebuilt/linux-x86_64/bin:$PATH"
     cmake -S /workspace/protobuf-src -B /workspace/protobuf-src/build-android \
       -G Ninja \
       -DCMAKE_TOOLCHAIN_FILE=/workspace/aasdk/cmake_modules/Toolchain-android.cmake \
       -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
       -DCMAKE_SYSTEM_VERSION=24 \
       -Dprotobuf_BUILD_TESTS=OFF \
       -Dprotobuf_BUILD_SHARED_LIBS=ON \
       -Dprotobuf_WITH_ZLIB=OFF \
       -Dprotobuf_ABSL_PROVIDER=module \
       -DCMAKE_INSTALL_PREFIX=/workspace/protobuf-android
     cmake --build /workspace/protobuf-src/build-android --target install
     ```
3. **Point AASDK at the staged artifacts** when configuring:
   ```bash
   cmake -S . -B build-android -G Ninja \
     -DCMAKE_TOOLCHAIN_FILE=cmake_modules/Toolchain-android.cmake \
     -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
     -DCMAKE_SYSTEM_VERSION=24 \
     -DProtobuf_PROTOC_EXECUTABLE=/workspace/protoc-28.2/bin/protoc \
     -DProtobuf_INCLUDE_DIR=/workspace/protobuf-android/include \
     -DProtobuf_LIBRARIES=/workspace/protobuf-android/lib/libprotobuf.so \
     -DAASDK_ENABLE_TESTS=OFF
   ```

> Tip: If you see an Abseil target such as `absl::if_constexpr` missing during the Protobuf configure step, double-check that the `third_party/abseil-cpp` submodule was initialized. The published release tarballs exclude it; cloning the git repo and updating submodules pulls in the expected CMake target definitions.

## Integrating into an Android app
1. Copy the resulting `.so` files into your app module’s `src/main/jniLibs/<abi>/` directory.
2. Add a JNI shim that exposes the required AASDK entry points to the Android runtime.
3. Implement Android-side USB or Wi‑Fi transport and forward the raw transport streams into the native library.
4. Provide rendering (e.g., `SurfaceView`/`TextureView`) and audio output plumbing on the Android side.

## Known gaps / next steps
- No JNI bridge or Android Java/Kotlin wrapper is included.
- Some desktop-oriented dependencies (e.g., libusb) may require Android-compatible replacements or wrappers.
- CI does not validate Android builds; treat this as a manual/experimental flow.
