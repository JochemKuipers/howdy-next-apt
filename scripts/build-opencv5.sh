#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/deps.versions"

PREFIX="${HOWDY_DEPS_PREFIX:-/opt/howdy-next-deps}"
SRC_ROOT="${HOWDY_DEPS_SRC:-${PREFIX}/src}"
JOBS="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
# Bump when CMake flags change so restored CI caches rebuild instead of
# skipping because opencv5.pc already exists.
OPENCV_BUILD_ID="${OPENCV_VERSION}-no-opencl-1"
STAMP="${PREFIX}/.howdy-opencv-build-id"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

if pkg-config --exists "opencv5 >= ${OPENCV_VERSION}" \
	&& [[ -f "${STAMP}" ]] \
	&& [[ "$(cat "${STAMP}")" == "${OPENCV_BUILD_ID}" ]]; then
	echo "OpenCV $(pkg-config --modversion opencv5) already installed in ${PREFIX}"
	exit 0
fi

mkdir -p "${SRC_ROOT}" "${PREFIX}"
archive="${SRC_ROOT}/opencv-${OPENCV_VERSION}.tar.gz"
if [[ ! -f "${archive}" ]]; then
	curl -fsSL -o "${archive}" \
		"https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz"
fi

rm -rf "${SRC_ROOT}/opencv-${OPENCV_VERSION}"
tar -xzf "${archive}" -C "${SRC_ROOT}"

# opencv_world in 5.0.0 does not link vendored DNN MLAS objects, so ship
# split shared libraries instead (libopencv_dnn.so includes MLAS).
cmake -S "${SRC_ROOT}/opencv-${OPENCV_VERSION}" -B "${SRC_ROOT}/opencv-build" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="${PREFIX}" \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_INSTALL_RPATH=/usr/lib/howdy-next \
	-DCMAKE_BUILD_RPATH="${PREFIX}/lib" \
	-DCMAKE_CXX_STANDARD=17 \
	-DBUILD_SHARED_LIBS=ON \
	-DBUILD_opencv_world=OFF \
	-DBUILD_TESTS=OFF \
	-DBUILD_PERF_TESTS=OFF \
	-DBUILD_EXAMPLES=OFF \
	-DBUILD_DOCS=OFF \
	-DBUILD_opencv_apps=OFF \
	-DBUILD_opencv_python2=OFF \
	-DBUILD_opencv_python3=OFF \
	-DBUILD_JAVA=OFF \
	-DBUILD_LIST=core,imgproc,imgcodecs,videoio,highgui,dnn,objdetect \
	-DWITH_QT=OFF \
	-DWITH_GTK=ON \
	-DWITH_FFMPEG=ON \
	-DWITH_GSTREAMER=OFF \
	-DWITH_V4L=ON \
	-DWITH_CUDA=OFF \
	-DWITH_OPENCL=OFF \
	-DWITH_1394=OFF \
	-DWITH_VTK=OFF \
	-DOPENCV_GENERATE_PKGCONFIG=ON

cmake --build "${SRC_ROOT}/opencv-build" --parallel "${JOBS}"
cmake --install "${SRC_ROOT}/opencv-build"
rm -rf "${SRC_ROOT}/opencv-build" "${SRC_ROOT}/opencv-${OPENCV_VERSION}"

if ! pkg-config --exists "opencv5 >= ${OPENCV_VERSION}"; then
	echo "OpenCV pkg-config opencv5>=${OPENCV_VERSION} is missing after install" >&2
	ls -la "${PREFIX}/lib" "${PREFIX}/lib/pkgconfig" >&2 || true
	exit 1
fi

printf '%s\n' "${OPENCV_BUILD_ID}" > "${STAMP}"
echo "Installed OpenCV $(pkg-config --modversion opencv5) to ${PREFIX}"
