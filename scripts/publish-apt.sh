#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${HOWDY_OUT_DIR:-${ROOT}/out}"
PAGES="${HOWDY_PAGES_DIR:-${ROOT}/pages}"
URI="${APT_REPO_URI:-https://jochemkuipers.github.io/howdy-next-apt}"
CODENAME="stable"

if [[ -z "${APT_SIGNING_KEY:-}" ]]; then
	echo "APT_SIGNING_KEY is required" >&2
	exit 1
fi
if [[ -z "${APT_SIGNING_KEY_PASSPHRASE:-}" ]]; then
	echo "APT_SIGNING_KEY_PASSPHRASE is required" >&2
	exit 1
fi

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
chmod 700 "${GNUPGHOME}"
printf '%s\n' "${APT_SIGNING_KEY}" | gpg --batch --import
PASSPHRASE_FILE="${GNUPGHOME}/pass"
printf '%s' "${APT_SIGNING_KEY_PASSPHRASE}" > "${PASSPHRASE_FILE}"
chmod 600 "${PASSPHRASE_FILE}"
cat > "${GNUPGHOME}/gpg.conf" <<EOF
batch
pinentry-mode loopback
passphrase-file ${PASSPHRASE_FILE}
EOF
cat > "${GNUPGHOME}/gpg-agent.conf" <<EOF
allow-loopback-pinentry
EOF

KEYID="$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr:/ {print $10; exit}')"
if [[ -z "${KEYID}" ]]; then
	echo "Failed to import APT signing key" >&2
	exit 1
fi
gpg --batch --armor --export "${KEYID}" > "${GNUPGHOME}/public.asc"

rm -rf "${PAGES}"
mkdir -p "${PAGES}/conf"
cat > "${PAGES}/conf/distributions" <<EOF
Origin: Howdy Next APT
Label: Howdy Next
Codename: ${CODENAME}
Architectures: amd64
Components: main
Description: Personal APT repository for Howdy Next
SignWith: ${KEYID}
EOF
cat > "${PAGES}/conf/options" <<EOF
verbose
EOF

shopt -s nullglob
debs=("${OUT}"/*.deb)
if (( ${#debs[@]} == 0 )); then
	echo "No .deb files in ${OUT}" >&2
	exit 1
fi

for deb in "${debs[@]}"; do
	reprepro -b "${PAGES}" includedeb "${CODENAME}" "${deb}"
done

cp -a "${GNUPGHOME}/public.asc" "${PAGES}/howdy-next-archive-keyring.asc"
gpg --batch --dearmor --output "${PAGES}/howdy-next-archive-keyring.gpg" "${GNUPGHOME}/public.asc"

{
	cat <<EOF
Types: deb
URIs: ${URI}
Suites: ${CODENAME}
Components: main
Architectures: amd64
EOF
	awk '
		BEGIN { print "Signed-By:" }
		{
			if ($0 == "") print " ."
			else print " " $0
		}
	' "${GNUPGHOME}/public.asc"
} > "${PAGES}/howdy-next.sources"

cat > "${PAGES}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Howdy Next APT repository</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 44rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    pre { background: #111; color: #eee; padding: 1rem; overflow-x: auto; }
    code { font-family: ui-monospace, monospace; }
  </style>
</head>
<body>
  <h1>Howdy Next APT repository</h1>
  <p>Unofficial personal packages of <a href="https://codeberg.org/nathawat/howdy-next">howdy-next</a> for Debian trixie, Debian sid, and PikaOS (amd64).</p>
  <h2>Install</h2>
  <pre><code>curl -fsSL ${URI}/howdy-next.sources \\
  | sudo tee /etc/apt/sources.list.d/howdy-next.sources
sudo apt update
sudo apt install howdy-next</code></pre>
  <p>See the <a href="https://github.com/JochemKuipers/howdy-next-apt">repository README</a> for camera setup, model download, and PAM notes.</p>
</body>
</html>
EOF

touch "${PAGES}/.nojekyll"

# Drop reprepro db from the published tree; dists/ and pool/ are enough.
rm -rf "${PAGES}/db" "${PAGES}/conf"

echo "APT repository written to ${PAGES}"
find "${PAGES}" -type f | sort
