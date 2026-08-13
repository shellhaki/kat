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
    _dp_os="$(uname -s)"
    _dp_arch="$(uname -m)"

    case "$_dp_os" in
        Linux)   _dp_os="linux" ;;
        Darwin)  _dp_os="darwin" ;;
        *) die "unsupported operating system: $_dp_os (use install.ps1 on Windows)" ;;
    esac

    case "$_dp_arch" in
        x86_64|amd64)   _dp_arch="amd64" ;;
        aarch64|arm64)  _dp_arch="arm64" ;;
        *) die "unsupported architecture: $_dp_arch" ;;
    esac

    PLATFORM="${_dp_os}_${_dp_arch}"
}

download() {
    _dl_url="$1"
    _dl_dest="$2"
    if need curl; then
        curl -fsSL "$_dl_url" -o "$_dl_dest"
    elif need wget; then
        wget -qO "$_dl_dest" "$_dl_url"
    else
        die "either curl or wget is required"
    fi
}

fetch_stdout() {
    _fs_url="$1"
    if need curl; then
        curl -fsSL "$_fs_url"
    elif need wget; then
        wget -qO- "$_fs_url"
    else
        die "either curl or wget is required"
    fi
}

latest_version() {
    # buffer the whole response: piping curl directly into grep -m1 closes the
    # pipe early and makes curl exit 23
    _lv_response="$(fetch_stdout "https://api.github.com/repos/${REPO}/releases/latest")"
    printf '%s\n' "$_lv_response" \
        | grep '"tag_name"' \
        | head -n1 \
        | sed -E 's/.*"tag_name" *: *"([^"]+)".*/\1/'
}

verify_checksum() {
    # note: POSIX sh has no local scope, so these are _-prefixed to avoid
    # clobbering the caller's variables
    _vc_archive="$1"
    _vc_checksums="$2"
    _vc_name="$(basename "$_vc_archive")"

    _vc_expected="$(grep " $_vc_name\$" "$_vc_checksums" | awk '{print $1}' | head -n1)"
    [ -n "$_vc_expected" ] || { warn "no checksum entry for $_vc_name, skipping verification"; return 0; }

    if need sha256sum; then
        _vc_actual="$(sha256sum "$_vc_archive" | awk '{print $1}')"
    elif need shasum; then
        _vc_actual="$(shasum -a 256 "$_vc_archive" | awk '{print $1}')"
    else
        warn "no sha256 tool found, skipping verification"
        return 0
    fi

    [ "$_vc_expected" = "$_vc_actual" ] \
        || die "checksum mismatch for $_vc_name (expected $_vc_expected, got $_vc_actual)"
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
