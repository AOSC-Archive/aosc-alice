#!/bin/bash
# $1: arch
# $2: variant

set -e

AOSC_RECIPE_URL='https://cdn.jsdelivr.net/gh/AOSC-Dev/scriptlets@5865163/aoscbootstrap/aoscbootstrap.pl'

function cleanup {
  if [[ "x$TMPDIR" != 'x' ]]; then
    pushd "$TMPDIR"
    echo 'yes' | ${SUDO} ciel farewell
    rm -rf "${TMPDIR}"
    popd
  fi
}

function download_absp {
  echo 'Downloading AOSCBootstrap script...'
  wget "$AOSC_RECIPE_URL" -O 'aoscbootstrap'
  ${SUDO} mv 'aoscbootstrap' '/usr/local/bin/aoscbootstrap'
  ${SUDO} chmod a+x '/usr/local/bin/aoscbootstrap'
}

SUDO=''
if [[ "x$(id --user)" != 'x0' ]]; then
  SUDO='sudo'
fi

if ! which ciel; then
  echo 'CIEL! needs to be present in $PATH'
  exit 1
fi

if ! which aoscbootstrap; then
  download_absp
fi

trap cleanup EXIT

TMPDIR="$(mktemp -d -p $PWD)"
pushd "${TMPDIR}"
${SUDO} ciel init
# bootstrap
${SUDO} aoscbootstrap --arch="$1" stable .ciel/container/dist/ 'https://aosc-repo.freetls.fastly.net/debs/'
${SUDO} ciel generate "$2"
if [[ "$?" != '0' ]]; then
  echo '[!] Tarball refresh process failed. Bailing out.'
  exit 1
fi
${SUDO} ciel release "$2" 4
popd

rm -rf dist || true
mkdir -p dist
${SUDO} mv "${TMPDIR}/"*.tar* dist/
