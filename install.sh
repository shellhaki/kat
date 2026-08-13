#!/bin/sh
# kat installer - Linux and macOS
#
#   curl -fsSL https://raw.githubusercontent.com/shellhaki/kat/main/install.sh | sh
#
# Environment overrides:
#   KAT_VERSION      version to install (default: latest release, e.g. v1.2.3)
#   KAT_INSTALL_DIR  install directory  (default: $HOME/.local/bin, or /usr/local/bin as root)

set -eu

REPO="shellhaki/kat"
BINARY="kat"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1; }

detect_platform() {
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)   os="linux" ;;
        Darwin)  os="darwin" ;;
        *) die "unsupported operating system: $os (use install.ps1 on Windows)" ;;
    esac

    case "$arch" in
        x86_64|amd64)   arch="amd64" ;;
        aarch64|arm64)  arch="arm64" ;;
        *) die "unsupported architecture: $arch" ;;
    esac

    PLATFORM="${os}_${arch}"
}

download() {
    url="$1"
    dest="$2"
    if need curl; then
        curl -fsSL "$url" -o "$dest"
    elif need wget; then
        wget -qO "$dest" "$url"
    else
        die "either curl or wget is required"
    fi
}

fetch_stdout() {
    url="$1"
    if need curl; then
        curl -fsSL "$url"
    elif need wget; then
        wget -qO- "$url"
    else
        die "either curl or wget is required"
    fi
}

latest_version() {
    fetch_stdout "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep -m1 '"tag_name"' \
        | sed -E 's/.*"tag_name" *: *"([^"]+)".*/\1/'
}

verify_checksum() {
    archive="$1"
    checksums="$2"
    name="$(basename "$archive")"

    expected="$(grep " $name\$" "$checksums" | awk '{print $1}' | head -n1)"
    [ -n "$expected" ] || { warn "no checksum entry for $name, skipping verification"; return 0; }

    if need sha256sum; then
        actual="$(sha256sum "$archive" | awk '{print $1}')"
    elif need shasum; then
        actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
    else
        warn "no sha256 tool found, skipping verification"
        return 0
    fi

    [ "$expected" = "$actual" ] || die "checksum mismatch for $name (expected $expected, got $actual)"
    info "checksum verified"
}

main() {
    detect_platform

    VERSION="${KAT_VERSION:-}"
    if [ -z "$VERSION" ]; then
        info "resolving latest release"
        VERSION="$(latest_version)"
        [ -n "$VERSION" ] || die "could not resolve the latest release of $REPO"
    fi
    case "$VERSION" in v*) ;; *) VERSION="v${VERSION}" ;; esac

    if [ -n "${KAT_INSTALL_DIR:-}" ]; then
        INSTALL_DIR="$KAT_INSTALL_DIR"
    elif [ "$(id -u)" -eq 0 ]; then
        INSTALL_DIR="/usr/local/bin"
    else
        INSTALL_DIR="$HOME/.local/bin"
    fi

    archive="${BINARY}_${VERSION}_${PLATFORM}.tar.gz"
    base_url="https://github.com/${REPO}/releases/download/${VERSION}"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT INT TERM

    info "downloading ${BINARY} ${VERSION} (${PLATFORM})"
    download "${base_url}/${archive}" "${tmp}/${archive}" \
        || die "download failed: ${base_url}/${archive}"

    if download "${base_url}/checksums.txt" "${tmp}/checksums.txt" 2>/dev/null; then
        verify_checksum "${tmp}/${archive}" "${tmp}/checksums.txt"
    else
        warn "checksums.txt unavailable, skipping verification"
    fi

    tar -xzf "${tmp}/${archive}" -C "$tmp"
    [ -f "${tmp}/${BINARY}" ] || die "archive did not contain ${BINARY}"

    mkdir -p "$INSTALL_DIR"
    install -m 0755 "${tmp}/${BINARY}" "${INSTALL_DIR}/${BINARY}" 2>/dev/null \
        || { cp "${tmp}/${BINARY}" "${INSTALL_DIR}/${BINARY}" && chmod 0755 "${INSTALL_DIR}/${BINARY}"; }

    info "installed ${BINARY} ${VERSION} to ${INSTALL_DIR}/${BINARY}"

    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *)
            warn "${INSTALL_DIR} is not on your PATH. Add this to your shell profile:"
            printf '\n    export PATH="%s:$PATH"\n\n' "$INSTALL_DIR"
            ;;
    esac
}

main "$@"
