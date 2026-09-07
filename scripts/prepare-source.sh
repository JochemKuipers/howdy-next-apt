#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/deps.versions"
PREFIX="${HOWDY_DEPS_PREFIX:-/opt/howdy-next-deps}"
DEBIAN_REVISION="${DEBIAN_REVISION:-1}"
WORK="${HOWDY_SRC_DIR:-${ROOT}/src/howdy-next}"
TAG="${UPSTREAM_TAG:-}"

if [[ -z "${TAG}" ]]; then
	echo "UPSTREAM_TAG is required" >&2
	exit 1
fi

VERSION="${TAG#v}"
COMMIT="${HOWDY_GIT_COMMIT:-}"
mkdir -p "$(dirname "${WORK}")"
rm -rf "${WORK}" "${ROOT}/src/howdy-next.tar.gz"

curl -fsSL -o "${ROOT}/src/howdy-next.tar.gz" \
	"https://codeberg.org/nathawat/howdy-next/archive/${TAG}.tar.gz"
mkdir -p "${ROOT}/src/extract"
rm -rf "${ROOT}/src/extract"
mkdir -p "${ROOT}/src/extract"
tar -xzf "${ROOT}/src/howdy-next.tar.gz" -C "${ROOT}/src/extract"
SRC_DIR="$(find "${ROOT}/src/extract" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [[ -z "${SRC_DIR}" ]]; then
	echo "Failed to extract howdy-next ${TAG}" >&2
	exit 1
fi
mv "${SRC_DIR}" "${WORK}"
rm -rf "${ROOT}/src/extract"

if [[ -z "${COMMIT}" ]] && command -v git >/dev/null; then
	COMMIT="$(git ls-remote https://codeberg.org/nathawat/howdy-next.git "refs/tags/${TAG}^{}" | awk '{print $1}')"
	if [[ -z "${COMMIT}" ]]; then
		COMMIT="$(git ls-remote https://codeberg.org/nathawat/howdy-next.git "refs/tags/${TAG}" | awk '{print $1}')"
	fi
fi

rm -rf "${WORK}/debian"
cp -a "${ROOT}/debian" "${WORK}/debian"

if [[ -f "${WORK}/debian/patches/series" ]]; then
	while IFS= read -r patch || [[ -n "${patch}" ]]; do
		[[ -z "${patch}" || "${patch}" == \#* ]] && continue
		echo "Applying ${patch}"
		patch -d "${WORK}" -p1 < "${WORK}/debian/patches/${patch}"
	done < "${WORK}/debian/patches/series"
fi

cat > "${WORK}/debian/build-env.mk" <<EOF
HOWDY_DEPS_PREFIX := ${PREFIX}
HOWDY_GIT_COMMIT := ${COMMIT}
EOF

DATE="$(date -R)"
cat > "${WORK}/debian/changelog" <<EOF
howdy-next (${VERSION}-${DEBIAN_REVISION}) stable; urgency=medium

  * Package Howdy Next ${VERSION} from upstream tag ${TAG}.

 -- Jochem Kuipers <JochemKuipers+howdy-next-apt@users.noreply.github.com>  ${DATE}
EOF

echo "Prepared ${WORK} for howdy-next ${VERSION} (commit ${COMMIT:-unknown})"
