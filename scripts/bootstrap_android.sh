#!/usr/bin/env bash
set -euo pipefail

# Experimental Android cross-build helper for AASDK.
# Fetches the Android NDK, builds a host protoc, cross-builds protobuf+abseil,
# and configures an Android build tree for AASDK. External deps like OpenSSL,
# Boost, and libusb are not yet staged; see docs/ANDROID.md for notes.

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
STAGE_DIR=${STAGE_DIR:-"${ROOT_DIR}/.android-stage"}
INSTALL_DIR=${INSTALL_DIR:-"${STAGE_DIR}/android-prefix"}
HOST_INSTALL_DIR=${HOST_INSTALL_DIR:-"${STAGE_DIR}/host-prefix"}
ABI=${ABI:-arm64-v8a}
API_LEVEL=${API_LEVEL:-24}

mkdir -p "${STAGE_DIR}" "${INSTALL_DIR}" "${HOST_INSTALL_DIR}"

# --- Android NDK ---
NDK_VERSION=${NDK_VERSION:-r26d}
NDK_BASENAME="android-ndk-${NDK_VERSION}"
NDK_ZIP="${NDK_BASENAME}-linux.zip"
NDK_URL="https://dl.google.com/android/repository/${NDK_ZIP}"
NDK_ROOT=${NDK_ROOT:-"${STAGE_DIR}/${NDK_BASENAME}"}

if [ ! -d "${NDK_ROOT}" ]; then
  echo "[ndk] downloading ${NDK_URL}" >&2
  curl -L "${NDK_URL}" -o "${STAGE_DIR}/${NDK_ZIP}"
  unzip -q "${STAGE_DIR}/${NDK_ZIP}" -d "${STAGE_DIR}"
fi
export ANDROID_NDK="${NDK_ROOT}"

TOOLCHAIN_FILE="${ROOT_DIR}/cmake_modules/Toolchain-android.cmake"

# --- Abseil ---
ABSL_VERSION=${ABSL_VERSION:-20240116.2}
ABSL_ARCHIVE="abseil-cpp-${ABSL_VERSION}.tar.gz"
ABSL_URL="https://github.com/abseil/abseil-cpp/archive/refs/tags/${ABSL_VERSION}.tar.gz"
ABSL_SRC="${STAGE_DIR}/abseil-cpp-${ABSL_VERSION}"
if [ ! -d "${ABSL_SRC}" ]; then
  echo "[abseil] downloading ${ABSL_URL}" >&2
  curl -fL "${ABSL_URL}" -o "${STAGE_DIR}/${ABSL_ARCHIVE}"
  tar -xzf "${STAGE_DIR}/${ABSL_ARCHIVE}" -C "${STAGE_DIR}"
fi
ABSL_BUILD="${ABSL_SRC}/build-android"
cmake -S "${ABSL_SRC}" -B "${ABSL_BUILD}" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DCMAKE_ANDROID_ARCH_ABI="${ABI}" \
  -DCMAKE_SYSTEM_VERSION="${API_LEVEL}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DBUILD_SHARED_LIBS=ON \
  -DABSL_PROPAGATE_CXX_STD=ON
cmake --build "${ABSL_BUILD}" --target install

# Host Abseil for protoc
ABSL_HOST_BUILD="${ABSL_SRC}/build-host"
cmake -S "${ABSL_SRC}" -B "${ABSL_HOST_BUILD}" -G Ninja \
  -DCMAKE_INSTALL_PREFIX="${HOST_INSTALL_DIR}" \
  -DBUILD_SHARED_LIBS=ON \
  -DABSL_PROPAGATE_CXX_STD=ON
cmake --build "${ABSL_HOST_BUILD}" --target install

# --- Protobuf (host protoc + Android libs) ---
PROTO_VERSION=${PROTO_VERSION:-28.2}
PROTO_ARCHIVE="v${PROTO_VERSION}.tar.gz"
PROTO_URL="https://github.com/protocolbuffers/protobuf/archive/refs/tags/${PROTO_ARCHIVE}"
PROTO_SRC="${STAGE_DIR}/protobuf-${PROTO_VERSION}"
if [ ! -d "${PROTO_SRC}" ]; then
  echo "[protobuf] downloading ${PROTO_URL}" >&2
  curl -L "${PROTO_URL}" -o "${STAGE_DIR}/${PROTO_ARCHIVE}"
  tar -xzf "${STAGE_DIR}/${PROTO_ARCHIVE}" -C "${STAGE_DIR}"
fi

# Host protoc
PROTO_HOST_BUILD="${PROTO_SRC}/build-host"
cmake -S "${PROTO_SRC}" -B "${PROTO_HOST_BUILD}" -G Ninja \
  -Dprotobuf_BUILD_TESTS=OFF \
  -Dprotobuf_WITH_ZLIB=OFF \
  -Dprotobuf_BUILD_SHARED_LIBS=ON \
  -Dprotobuf_ABSL_PROVIDER=package \
  -Dabsl_DIR="${HOST_INSTALL_DIR}/lib/cmake/absl"
cmake --build "${PROTO_HOST_BUILD}" --target protoc
PROTOC_BIN="${PROTO_HOST_BUILD}/protoc"

# Android libs
PROTO_ANDROID_BUILD="${PROTO_SRC}/build-android"
cmake -S "${PROTO_SRC}" -B "${PROTO_ANDROID_BUILD}" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DCMAKE_ANDROID_ARCH_ABI="${ABI}" \
  -DCMAKE_SYSTEM_VERSION="${API_LEVEL}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -Dprotobuf_BUILD_TESTS=OFF \
  -Dprotobuf_WITH_ZLIB=OFF \
  -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
  -DProtobuf_PROTOC_EXECUTABLE="${PROTOC_BIN}" \
  -Dprotobuf_ABSL_PROVIDER=package \
  -Dabsl_DIR="${INSTALL_DIR}/lib/cmake/absl"
cmake --build "${PROTO_ANDROID_BUILD}" --target install

# --- Configure AASDK for Android (build-only; still needs OpenSSL/Boost/libusb staged) ---
AASDK_BUILD="${STAGE_DIR}/aasdk-android"
cmake -S "${ROOT_DIR}" -B "${AASDK_BUILD}" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DCMAKE_ANDROID_ARCH_ABI="${ABI}" \
  -DCMAKE_SYSTEM_VERSION="${API_LEVEL}" \
  -DAASDK_ENABLE_TESTS=OFF \
  -DProtobuf_DIR="${INSTALL_DIR}/lib/cmake/protobuf" \
  -Dabsl_DIR="${INSTALL_DIR}/lib/cmake/absl" \
  -DProtobuf_PROTOC_EXECUTABLE="${PROTOC_BIN}"

cat <<EONOTE
[done] Android toolchain configured at ${AASDK_BUILD}
Next steps: cross-build OpenSSL, Boost (headers only + thread/filesystem/regex), and libusb for Android and pass their paths to CMake (OPENSSL_ROOT_DIR, BOOST_ROOT, LibUSB_ROOT).
EONOTE
