#!/bin/bash
# $1: arch
# $2: variant

set -e

AOSC_RECIPE_URL='https://github.com/AOSC-Dev/aoscbootstrap'
SCRIPT_DIR=''
MIRROR='https://aosc-repo.freetls.fastly.net/debs/'

function cleanup {
  if [[ "x$TMPDIR" != 'x' ]]; then
    pushd "$TMPDIR"
    echo 'yes' | ${SUDO} ciel farewell
    rm -rf "${TMPDIR}"
    popd
  fi
}

function download_absp {
  echo 'Downloading AOSCBootstrap...'
  [ -d 'aoscbootstrap' ] && rm -rf 'aoscbootstrap'
  git clone --depth=5 "${AOSC_RECIPE_URL}" 'aoscbootstrap'
  SCRIPT_DIR="$(pwd)/aoscbootstrap/"
}

function convert_script {
  perl "${SCRIPT_DIR}/recipes/convert.pl" '/usr/libexec/ciel-plugin/ciel-generate' "${SCRIPT_DIR}/recipes"
}

SUDO=''
if [[ "x$(id --user)" != 'x0' ]]; then
  SUDO='sudo'
fi

if ! which ciel; then
  echo 'CIEL! needs to be present in $PATH'
  exit 1
fi

download_absp && convert_script
[ "$(hostname)" == 'bakeneko.door.local' ] && MIRROR='http://192.168.1.99/debs/'

trap cleanup EXIT

TMPDIR="$(mktemp -d -p $PWD)"
pushd "${TMPDIR}"
${SUDO} ciel init
# bootstrap
${SUDO} "${SCRIPT_DIR}/aoscbootstrap.pl" --arch="$1" --include-file="${SCRIPT_DIR}/recipes/$2.lst" stable "$(pwd)/.ciel/container/dist/" "$MIRROR"
if [[ "$?" != '0' ]]; then
  echo '[!] Tarball refresh process failed. Bailing out.'
  exit 1
fi
${SUDO} ciel add ciel--release--
${SUDO} ciel release "$2" 4
popd

rm -rf dist || true
mkdir -p dist
${SUDO} mv "${TMPDIR}/"*.tar* dist/
