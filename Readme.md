# kat

This project is to replicate the behavior of the popular bash command `cat` in go

## Install

**Linux / macOS**

```sh
curl -fsSL https://raw.githubusercontent.com/shellhaki/kat/main/install.sh | sh
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/shellhaki/kat/main/install.ps1 | iex
```

Both installers resolve the latest GitHub release, verify the SHA256 checksum, and
install the binary (`~/.local/bin` on Linux/macOS, `%LOCALAPPDATA%\Programs\kat` on
Windows). Overrides:

| Variable | Default |
| --- | --- |
| `KAT_VERSION` | latest release |
| `KAT_INSTALL_DIR` | `~/.local/bin` (`/usr/local/bin` as root) / `%LOCALAPPDATA%\Programs\kat` |

```sh
KAT_VERSION=v1.0.0 KAT_INSTALL_DIR=/usr/local/bin sh install.sh
```

Prebuilt targets: `linux/amd64`, `linux/arm64`, `darwin/amd64`, `darwin/arm64`,
`windows/amd64`, `windows/arm64`.

## Usage

```sh
kat <fileName>
kat --version
```

## Development

```sh
make dev        # go run
make build      # ./bin/kat with version info baked in
make build-all  # cross-compile every release target into dist/
make install    # build and copy to ~/.local/bin
make clean
```

## Releasing

Releases are cut by [`.github/workflows/release.yml`](.github/workflows/release.yml)
on any `v*` tag:

```sh
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

The workflow cross-compiles all six targets, stamps `main.version` / `main.commit` /
`main.date` via `-ldflags`, packages `.tar.gz` (Unix) and `.zip` (Windows) archives
plus a `checksums.txt`, and publishes them to a GitHub release with generated notes.
