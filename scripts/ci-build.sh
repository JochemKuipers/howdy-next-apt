#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${HOWDY_DEPS_PREFIX:-/opt/howdy-next-deps}"
OUT="${HOWDY_OUT_DIR:-${ROOT}/out}"

apt-get update
apt-get install -y --no-install-recommends \
	build-essential ca-certificates curl git cmake ninja-build \
	pkgconf gettext debhelper dpkg-dev fakeroot jq xz-utils \
	libpam0g-dev libevdev-dev libinih-dev libacl1-dev \
	libcurl4-openssl-dev libssl-dev libgtk-3-dev \
	libavcodec-dev libavformat-dev libswscale-dev libavutil-dev \
	libjpeg-dev libpng-dev libtiff-dev libwebp-dev libv4l-dev \
	zlib1g-dev python3 ccache binutils

if [[ -n "${CCACHE_DIR:-}" ]]; then
	mkdir -p "${CCACHE_DIR}"
	export CMAKE_CXX_COMPILER_LAUNCHER=ccache
	export CMAKE_C_COMPILER_LAUNCHER=ccache
fi

export HOWDY_DEPS_PREFIX="${PREFIX}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

bash "${ROOT}/scripts/build-opencv5.sh"
bash "${ROOT}/scripts/build-yyjson.sh"

if [[ -z "${UPSTREAM_TAG:-}" ]]; then
	UPSTREAM_TAG="$(
		curl -fsSL 'https://codeberg.org/api/v1/repos/nathawat/howdy-next/releases?limit=20' \
			| jq -r '[.[] | select(.prerelease==false and .draft==false)][0].tag_name'
	)"
fi
if [[ -z "${UPSTREAM_TAG}" || "${UPSTREAM_TAG}" == "null" ]]; then
	echo "Could not determine upstream howdy-next tag" >&2
	exit 1
fi
export UPSTREAM_TAG
echo "Building howdy-next ${UPSTREAM_TAG}"

mkdir -p "${ROOT}/src" "${OUT}"
bash "${ROOT}/scripts/prepare-source.sh"

SRC="${HOWDY_SRC_DIR:-${ROOT}/src/howdy-next}"
(
	cd "${SRC}"
	dpkg-buildpackage -us -uc -b --no-sign -j"$(nproc)"
)

mkdir -p "${OUT}"
find "${ROOT}/src" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.ddeb' -o -name '*.buildinfo' -o -name '*.changes' \) -exec cp -a {} "${OUT}/" \;

ls -la "${OUT}"
if ! compgen -G "${OUT}/howdy-next_*.deb" >/dev/null; then
	echo "No howdy-next .deb produced" >&2
	exit 1
fi

VERSION="${UPSTREAM_TAG#v}"
printf '%s\n' "${UPSTREAM_TAG}" > "${OUT}/upstream-tag.txt"
printf '%s\n' "${VERSION}" > "${OUT}/version.txt"
echo "Built howdy-next ${VERSION}"
