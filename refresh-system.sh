#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
apt-get -y update
for i in {0..5}
do apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" full-upgrade && \
 break || apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" install -f
done
