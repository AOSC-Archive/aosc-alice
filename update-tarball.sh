#!/bin/bash
# $1: arch
# $2: variant

set -e

function cleanup {
  if [[ "x$TMPDIR" != 'x' ]]; then
    pushd "$TMPDIR"
    echo 'yes' | ${SUDO} ciel farewell
    rm -rf "${TMPDIR}"
    popd
  fi
  rm t.pl
}

SUDO=''
if [[ "x$(id --user)" != 'x0' ]]; then
  SUDO='sudo'
fi

if ! which ciel; then
  echo 'CIEL! needs to be present in $PATH'
  exit 1
fi

trap cleanup EXIT
VARIANT_FOLDER="$2"
if [[ "$1" == arm* && "$2" == 'base' ]]; then
    VARIANT_FOLDER='generic'
fi

cat << 'EOF' > t.pl
use strict;
my $regex = qr/aosc-os_%var%_\d{8}(?>_amd64)?\.tar\.(?>gz|xz)/mp;
my @matches = <STDIN> =~ /$regex/g;
foreach my $match (@matches) {print "$match\n"};
EOF

sed -i "s/%var%/$2/g" t.pl

TARBALL_NAME=$(curl -s "https://releases.aosc.io/os-$1/${VARIANT_FOLDER}/" | perl -n t.pl | sort | tail -n1)
if [[ "x${TARBALL_NAME}" == 'x' ]]; then
  echo 'Cannot find latest tarball'
  exit 1
fi
echo "Downloading ${TARBALL_NAME}..."
wget -c -q "https://repo.aosc.io/aosc-os/os-$1/${VARIANT_FOLDER}/${TARBALL_NAME}"

TMPDIR="$(mktemp -d -p $PWD)"
TARBALL_NAME="$(basename ${TARBALL_NAME})"
TARBALL_PATH="$(readlink -f ${TARBALL_NAME})"
pushd "${TMPDIR}"
${SUDO} ciel init
${SUDO} ciel load-os "${TARBALL_PATH}"
${SUDO} ciel add __release__
${SUDO} ciel shell -i __release__ -n 'export DEBIAN_FRONTEND=noninteractive; apt-get -y update && for i in {0..5}; do apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" full-upgrade && break || apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" install -f; done'
if [[ "$?" != '0' ]]; then
  echo '[!] Tarball refresh process failed. Bailing out.'
  exit 1
fi
${SUDO} ciel release "$2" 4
popd

rm -rf dist || true
mkdir -p dist
${SUDO} mv "${TMPDIR}/"*.tar* dist/
