#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/deps.versions"

PREFIX="${HOWDY_DEPS_PREFIX:-/opt/howdy-next-deps}"
SRC_ROOT="${HOWDY_DEPS_SRC:-${PREFIX}/src}"
JOBS="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

if pkg-config --exists "yyjson >= ${YYJSON_VERSION}"; then
	echo "yyjson $(pkg-config --modversion yyjson) already installed in ${PREFIX}"
	exit 0
fi

mkdir -p "${SRC_ROOT}" "${PREFIX}"
archive="${SRC_ROOT}/yyjson-${YYJSON_VERSION}.tar.gz"
if [[ ! -f "${archive}" ]]; then
	curl -fsSL -o "${archive}" \
		"https://github.com/ibireme/yyjson/archive/refs/tags/${YYJSON_VERSION}.tar.gz"
fi

rm -rf "${SRC_ROOT}/yyjson-${YYJSON_VERSION}"
tar -xzf "${archive}" -C "${SRC_ROOT}"

cmake -S "${SRC_ROOT}/yyjson-${YYJSON_VERSION}" -B "${SRC_ROOT}/yyjson-build" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="${PREFIX}" \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DBUILD_SHARED_LIBS=OFF \
	-DYYJSON_BUILD_TESTS=OFF \
	-DYYJSON_BUILD_FUZZER=OFF \
	-DYYJSON_BUILD_MISC=OFF \
	-DYYJSON_BUILD_DOC=OFF

cmake --build "${SRC_ROOT}/yyjson-build" --parallel "${JOBS}"
cmake --install "${SRC_ROOT}/yyjson-build"
rm -rf "${SRC_ROOT}/yyjson-build" "${SRC_ROOT}/yyjson-${YYJSON_VERSION}"

if ! pkg-config --exists "yyjson >= ${YYJSON_VERSION}"; then
	echo "yyjson pkg-config yyjson>=${YYJSON_VERSION} is missing after install" >&2
	ls -la "${PREFIX}/lib" "${PREFIX}/lib/pkgconfig" >&2 || true
	exit 1
fi

echo "Installed yyjson $(pkg-config --modversion yyjson) to ${PREFIX}"
