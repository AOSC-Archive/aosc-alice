#!/bin/bash
# $1: arch
# $2: variant

set -e

AOSC_RECIPE_URL='https://cdn.jsdelivr.net/gh/AOSC-Dev/scriptlets@master/debootstrap/aosc'

function cleanup {
  if [[ "x$TMPDIR" != 'x' ]]; then
    pushd "$TMPDIR"
    echo 'yes' | ${SUDO} ciel farewell
    rm -rf "${TMPDIR}"
    popd
  fi
}

function patch_debootstrap {
  echo 'Patching debootstrap...'
  wget "$AOSC_RECIPE_URL" -O 'aosc'
  ${SUDO} mv 'aosc' '/usr/share/debootstrap/scripts/aosc'
}

SUDO=''
if [[ "x$(id --user)" != 'x0' ]]; then
  SUDO='sudo'
fi

if ! which ciel; then
  echo 'CIEL! needs to be present in $PATH'
  exit 1
fi

if ! which debootstrap; then
  echo 'debootstrap needs to be present in $PATH'
  exit 1
fi

trap cleanup EXIT

[ -f '/usr/share/debootstrap/scripts/aosc' ] || patch_debootstrap

TMPDIR="$(mktemp -d -p $PWD)"
pushd "${TMPDIR}"
${SUDO} ciel init
# bootstrap
${SUDO} debootstrap --arch="$1" stable .ciel/container/dist/ 'https://cf-repo.aosc.io/debs/' aosc
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
