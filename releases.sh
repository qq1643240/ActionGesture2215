#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

PACKAGE="$(awk -F': *' '/^Package:/{print $2; exit}' control)"
NAME="$(awk -F': *' '/^Name:/{print $2; exit}' control)"
VERSION="$(awk -F': *' '/^Version:/{print $2; exit}' control)"
RELEASE_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/actiongesture-release.XXXXXX")"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

trap 'rm -rf "${RELEASE_TEMP}"' EXIT

build_package() {
    local scheme="$1"
    local package_arch="$2"
    local output_arch="$3"

    echo -e "${BLUE}==>${NC} Building ${NAME} ${VERSION} (${scheme:-rootful})..."
    make clean
    if [[ -n "${scheme}" ]]; then
        make package SCHEME="${scheme}" FINALPACKAGE=1 RELEASE=1
    else
        make package FINALPACKAGE=1 RELEASE=1
    fi

    local source_package="packages/${PACKAGE}_${VERSION}_${package_arch}.deb"
    if [[ ! -f "${source_package}" ]]; then
        echo "Missing release package: ${source_package}" >&2
        exit 1
    fi
    cp "${source_package}" \
        "${RELEASE_TEMP}/${NAME}_${VERSION}-${output_arch}.deb"
}

build_package "" "iphoneos-arm" "arm"
build_package "roothide" "iphoneos-arm64e" "arm64e"
build_package "rootless" "iphoneos-arm64" "arm64"

rm -rf packages
mkdir -p packages
cp "${RELEASE_TEMP}"/*.deb packages/

echo -e "${GREEN}==>${NC} Release build complete:"
ls -lh packages/*.deb
shasum -a 256 packages/*.deb
