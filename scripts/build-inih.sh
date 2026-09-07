#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/deps.versions"

PREFIX="${HOWDY_DEPS_PREFIX:-/opt/howdy-next-deps}"
SRC_ROOT="${HOWDY_DEPS_SRC:-${PREFIX}/src}"
JOBS="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

if pkg-config --exists "INIReader >= ${INIH_PKG_VERSION}"; then
	echo "INIReader $(pkg-config --modversion INIReader) already installed in ${PREFIX}"
	exit 0
fi

mkdir -p "${SRC_ROOT}" "${PREFIX}"
archive="${SRC_ROOT}/inih-${INIH_VERSION}.tar.gz"
if [[ ! -f "${archive}" ]]; then
	curl -fsSL -o "${archive}" \
		"https://github.com/benhoyt/inih/archive/refs/tags/${INIH_VERSION}.tar.gz"
fi

rm -rf "${SRC_ROOT}/inih-${INIH_VERSION}"
tar -xzf "${archive}" -C "${SRC_ROOT}"

meson setup "${SRC_ROOT}/inih-build" "${SRC_ROOT}/inih-${INIH_VERSION}" \
	--prefix="${PREFIX}" \
	--libdir=lib \
	--buildtype=release \
	--default-library=shared \
	-Ddistro_install=true \
	-Dwith_INIReader=true \
	-Dtests=false \
	-Dc_link_args=-Wl,-rpath,/usr/lib/howdy-next \
	-Dcpp_link_args=-Wl,-rpath,/usr/lib/howdy-next

meson compile -C "${SRC_ROOT}/inih-build" -j "${JOBS}"
meson install -C "${SRC_ROOT}/inih-build"
rm -rf "${SRC_ROOT}/inih-build" "${SRC_ROOT}/inih-${INIH_VERSION}"

if ! pkg-config --exists "INIReader >= ${INIH_PKG_VERSION}"; then
	echo "INIReader pkg-config INIReader>=${INIH_PKG_VERSION} is missing after install" >&2
	ls -la "${PREFIX}/lib" "${PREFIX}/lib/pkgconfig" >&2 || true
	exit 1
fi

echo "Installed INIReader $(pkg-config --modversion INIReader) to ${PREFIX}"
