#!/bin/bash
# Compile un binaire katago redistribuable, sans aucune dépendance hors système.
#
# Le binaire de Homebrew est lié à 84 dylibs. Ce n'est pas l'entraînement
# distribué qui les tire — il est désactivé par défaut — mais le backend Metal
# lui-même : en 1.18, Metal est « hybride MPSGraph + CoreML », et son composant
# CoreML dépend de protobuf et d'une trentaine de modules Abseil, sans option
# pour le désactiver. On les compile donc en statique dans un préfixe local.
#
# Durée : une vingtaine de minutes à froid, quelques secondes ensuite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENDOR="$ROOT/vendor"
PREFIX="$VENDOR/prefix"

KATAGO_VERSION="${KATAGO_VERSION:-v1.18.2}"
ABSEIL_VERSION="${ABSEIL_VERSION:-20260817.0}"
PROTOBUF_VERSION="${PROTOBUF_VERSION:-v36.1}"
LIBZIP_VERSION="${LIBZIP_VERSION:-v1.11.4}"

# /usr/bin/swiftc se retrouve associé au SDK des Command Line Tools, plus récent
# que lui, et refuse alors de compiler. On impose la toolchain Xcode et son SDK.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SDK="${MOYO_SDK:-$(ls -d "$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX"*.sdk 2>/dev/null | grep -v 'MacOSX.sdk' | sort -V | tail -1)}"
TOOLCHAIN="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"
[ -d "$SDK" ] || { echo "SDK macOS introuvable sous $DEVELOPER_DIR" >&2; exit 1; }

command -v cmake >/dev/null || { echo "cmake manquant (brew install cmake)" >&2; exit 1; }
command -v ninja >/dev/null || { echo "ninja manquant (brew install ninja)" >&2; exit 1; }
command -v pkg-config >/dev/null || { echo "pkg-config manquant (brew install pkgconf)" >&2; exit 1; }

mkdir -p "$VENDOR"
COMMON=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        -DCMAKE_CXX_STANDARD=17 -DCMAKE_OSX_ARCHITECTURES=arm64
        -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_PREFIX_PATH="$PREFIX")

clone() { # dépôt, tag, destination
  [ -d "$3" ] || git clone --quiet --depth 1 --branch "$2" "$1" "$3"
}

if [ ! -f "$PREFIX/lib/libabsl_base.a" ]; then
  echo "==> Abseil $ABSEIL_VERSION (statique)"
  clone https://github.com/abseil/abseil-cpp.git "$ABSEIL_VERSION" "$VENDOR/abseil-cpp"
  cmake -S "$VENDOR/abseil-cpp" -B "$VENDOR/abseil-cpp/build" "${COMMON[@]}" \
      -DABSL_ENABLE_INSTALL=ON -DABSL_PROPAGATE_CXX_STD=ON -DABSL_BUILD_TESTING=OFF >/dev/null
  cmake --build "$VENDOR/abseil-cpp/build" -j >/dev/null
  cmake --install "$VENDOR/abseil-cpp/build" >/dev/null
fi

if [ ! -f "$PREFIX/lib/libprotobuf.a" ]; then
  echo "==> protobuf $PROTOBUF_VERSION (statique)"
  clone https://github.com/protocolbuffers/protobuf.git "$PROTOBUF_VERSION" "$VENDOR/protobuf"
  cmake -S "$VENDOR/protobuf" -B "$VENDOR/protobuf/build" "${COMMON[@]}" \
      -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_ABSL_PROVIDER=package \
      -Dprotobuf_BUILD_SHARED_LIBS=OFF >/dev/null
  cmake --build "$VENDOR/protobuf/build" -j >/dev/null
  cmake --install "$VENDOR/protobuf/build" >/dev/null
fi

if [ ! -f "$PREFIX/lib/libzip.a" ]; then
  echo "==> libzip $LIBZIP_VERSION (statique)"
  clone https://github.com/nih-at/libzip.git "$LIBZIP_VERSION" "$VENDOR/libzip"
  cmake -S "$VENDOR/libzip" -B "$VENDOR/libzip/build" "${COMMON[@]}" \
      -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_OPENSSL=OFF \
      -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF \
      -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF >/dev/null
  cmake --build "$VENDOR/libzip/build" -j >/dev/null
  cmake --install "$VENDOR/libzip/build" >/dev/null
fi

echo "==> KataGo $KATAGO_VERSION (Metal)"
clone https://github.com/lightvector/KataGo.git "$KATAGO_VERSION" "$VENDOR/katago-src"
CPP="$VENDOR/katago-src/cpp"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" cmake -S "$CPP" -B "$CPP/build" -G Ninja \
    -DUSE_BACKEND=METAL -DBUILD_DISTRIBUTED=0 -DNO_GIT_REVISION=1 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_Swift_COMPILER="$TOOLCHAIN/swiftc" -DCMAKE_CXX_COMPILER="$TOOLCHAIN/clang++" >/dev/null
cmake --build "$CPP/build" -j >/dev/null

BINARY="$CPP/build/katago"
echo "==> Vérification de l'autonomie du binaire"
STRAYS="$(otool -L "$BINARY" | tail -n +2 | grep -v "^	/usr/lib/\|^	/System/Library/" || true)"
if [ -n "$STRAYS" ]; then
  echo "ÉCHEC : il reste des dépendances hors système." >&2
  echo "$STRAYS" >&2
  exit 1
fi
echo "==> $BINARY ($(du -m "$BINARY" | cut -f1) Mo, aucune dépendance hors système)"
