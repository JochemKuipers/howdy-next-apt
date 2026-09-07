# Howdy Next APT repository

Unofficial personal Debian packages of [Howdy Next](https://codeberg.org/nathawat/howdy-next) for **amd64**. GitHub Actions builds upstream Codeberg releases and publishes a GPG-signed APT repo on GitHub Pages.

This is not affiliated with upstream. Do not mix this package with a source install under `/usr` or `/usr/local`.

## Supported systems

One suite (`stable`) is built on **Debian trixie** and is intended for:

- Debian 13 (trixie)
- Debian sid/unstable
- PikaOS (Debian sid-based)

OpenCV 5 is vendored inside the package because Debian main still ships OpenCV 4. yyjson 0.12 is linked in for trixie, which only has 0.10.

## Install

```sh
curl -fsSL https://jochemkuipers.github.io/howdy-next-apt/howdy-next.sources \
  | sudo tee /etc/apt/sources.list.d/howdy-next.sources
sudo apt update
sudo apt install howdy-next
```

The `.sources` file embeds the repository signing key (`Signed-By`). Fingerprint:

`68B1 888D D30B BD43 3AE4 1E66 9389 229D 6DB5 F402`

## After install

Howdy is weaker than a password. Similar faces or photos may fool it. Never use it as the sole authentication method. This package **does not** enable PAM automatically.

1. Identify a stable camera path, preferably under `/dev/v4l/by-id/` or `/dev/v4l/by-path/`.
2. `sudo howdy config` and set `[video] device_path`.
3. `sudo howdy download-models`
4. `sudo howdy add`
5. `sudo howdy test`

When `howdy test` is reliable, add `pam_howdy.so` to the PAM service you want. See [`pam_howdy(8)`](https://codeberg.org/nathawat/howdy-next/wiki/PAM-Integration) and keep a password fallback.

Lock screens need the setuid helper at `/usr/libexec/howdy/howdy-auth-helper`. The package installs it `4755 root:root`.

## Updates

```sh
sudo apt update
sudo apt install --only-upgrade howdy-next
```

CI rebuilds weekly from the latest Codeberg release, and on pushes to this packaging repo. You can also run the **Publish APT repository** workflow and optionally pin an upstream tag.

## Layout

| Path | Role |
| --- | --- |
| `debian/` | Debian packaging overlaid onto the upstream tarball |
| `scripts/build-opencv5.sh` | Minimal OpenCV 5 shared libraries (core, dnn, videoio, …) |
| `scripts/build-yyjson.sh` | Static yyjson 0.12 prefix |
| `scripts/ci-build.sh` | Debian trixie package build |
| `scripts/publish-apt.sh` | reprepro + InRelease + Pages tree |
| `.github/workflows/publish.yml` | Build, sign, and deploy |

## License

Packaging files in this repository are `GPL-3.0-or-later`. Howdy Next, OpenCV, yyjson, and bundled notices keep their upstream licenses.
