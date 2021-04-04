#!/bin/bash
# $1: arch
# $2: variant

set -eE

MIRROR='https://aosc-repo.freetls.fastly.net/debs/'
VARIANT="$2"
XZ_THREADS='4'

function cleanup {
  if [[ "x$TMPDIR" != 'x' ]]; then
    ${SUDO} rm -rf "${TMPDIR}"
  fi
}

function convert_script {
  mkdir -p "${TMPDIR}/recipes"
  perl "/usr/share/aoscbootstrap/recipes/convert.pl" '/usr/libexec/ciel-plugin/ciel-generate' "${TMPDIR}/recipes"
}

function compress_tarball {
  XZ_PARAM="-9 -e --lzma2=preset=9e,nice=273"
  DATE="$(TZ=UTC date +'%Y%m%d')"
  ARCH="$(chroot "$(pwd)/dist" -- /usr/bin/dpkg-architecture -qDEB_BUILD_ARCH | dos2unix)"
  TARBALL=aosc-os_${VARIANT}_"${DATE}"_"${ARCH}".tar.xz
  COMPRESSOR="xz $XZ_PARAM -T $XZ_THREADS"

  pushd "$(pwd)/dist"
  tar cf - * | $COMPRESSOR > "$TMPDIR/$TARBALL" || exit $?
  sha256sum "$TMPDIR/$TARBALL" > "$TMPDIR/$TARBALL".sha256sum || exit $?
  popd
}

SUDO=''
if [[ "x$(id --user)" != 'x0' ]]; then
  SUDO='sudo'
fi

[ "$(hostname)" == 'bakeneko.door.local' ] && MIRROR='https://cth-desktop-dorm.mad.wi.cth451.me/debs'
[ "$(hostname)" == 'Ry3950X' ] && MIRROR='http://localhost/debs/'

trap cleanup EXIT

TMPDIR="$(mktemp -d -p $PWD)"
pushd "${TMPDIR}"
convert_script
# bootstrap
${SUDO} "aoscbootstrap" stable "$(pwd)/dist" "$MIRROR" -a "$1" -c '/usr/share/aoscbootstrap/config/aosc-mainline.toml' -x -f "recipes/$VARIANT.lst"
if [[ "$?" != '0' ]]; then
  echo '[!] Tarball refresh process failed. Bailing out.'
  exit 1
fi
compress_tarball
popd

rm -rf dist || true
mkdir -p dist
${SUDO} mv "${TMPDIR}/"*.tar* dist/
