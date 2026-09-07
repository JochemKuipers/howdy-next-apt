# Howdy Next APT repository

Unofficial personal Debian packages of [Howdy Next](https://codeberg.org/nathawat/howdy-next) for **amd64**. GitHub Actions builds upstream Codeberg releases and publishes a GPG-signed APT repo on GitHub Pages.

This is not affiliated with upstream. Do not mix this package with a source install under `/usr` or `/usr/local`.

## Supported systems

One suite (`stable`) is built on **Debian trixie** and is intended for:

- Debian 13 (trixie)
- Debian sid/unstable
- PikaOS (Debian sid-based)

OpenCV 5, yyjson 0.12, and inih 61 are vendored because Debian trixie still ships OpenCV 4, yyjson 0.10, and an INIReader pkg-config version of 58.

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

This package ships OpenCV 5, which cannot load the upstream INT8 SFace
model. `download-models` fetches the FP32 zoo file. After upgrading from
3.4.0-4 or earlier, download models again and re-enroll; the embeddings
are not interchangeable.

When `howdy test` is reliable, add this **above** the `pam_unix` line in `/etc/pam.d/common-auth`:

```
auth  sufficient  pam_howdy.so
```

That covers sudo, polkit, SDDM, and login with the same flags. Do not also add it to `/etc/pam.d/sudo` or `/etc/pam.d/polkit-1`, or Howdy runs twice and the camera is exclusive. Skip `workaround=native` and `workaround=native-input` (sudo-rs and KDE polkit both break with those). Keep a password fallback and a recovery session. See [`pam_howdy(8)`](https://codeberg.org/nathawat/howdy-next/wiki/PAM-Integration).

Do not test polkit with `sudo pkexec`; that authenticates sudo first. Use `pkexec /usr/bin/true`.

On polkit 127 the helper hides the camera and inherits stderr onto its protocol socket. This package ships a systemd drop-in that opens the camera/`/dev/uinput` and sets `StandardError=journal`. See [Polkit 127 compatibility](https://codeberg.org/nathawat/howdy-next/wiki/Polkit-127-compatibility).

Lock screens need the setuid helper at `/usr/lib/howdy/howdy-auth-helper` (`4755 root:root`). `sudo howdy test` does not use that helper, so a working CLI does not prove PAM is configured. `/etc/howdy` is `0750 root:root`; `Permission denied` as a normal user is expected.

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
| `scripts/build-inih.sh` | Shared inih/INIReader 61 prefix |
| `scripts/ci-build.sh` | Debian trixie package build |
| `scripts/publish-apt.sh` | reprepro + InRelease + Pages tree |
| `.github/workflows/publish.yml` | Build, sign, and deploy |

## License

Packaging files in this repository are `GPL-3.0-or-later`. Howdy Next, OpenCV, yyjson, and bundled notices keep their upstream licenses.
