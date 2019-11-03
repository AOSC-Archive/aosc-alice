#!/bin/bash -e

warn(){ echo -e "[\e[33mWARN\e[0m]: \e[1m$*\e[0m" >&2; }
err(){ echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m" >&2; }
info(){ echo -e "[\e[96mINFO\e[0m]: \e[1m$*\e[0m" >&2; }

function partition_gpt() {
    sgdisk -n1:0:131072 empty.img
    sgdisk -t1:ef00 empty.img
    sgdisk -N2 empty.img
}

function mkfs_gpt() {
    mkfs.vfat "${LOOP_DEV}p1"
    mkfs.ext4 "${LOOP_DEV}p2"
}

function bootloader_efi() {
    systemd-nspawn --bind "${LOOP_DEV}p1":"${LOOP_DEV}p1" --bind "${LOOP_DEV}p2":"${LOOP_DEV}p2" --bind "${LOOP_DEV}":"${LOOP_DEV}" -D "${TMP_MNT}" /usr/bin/bash -c "mount ${LOOP_DEV}p1 /efi && grub-install --target=x86_64-efi --bootloader-id=AOSC-GRUB --efi-directory=/efi --removable && grub-mkconfig -o /boot/grub/grub.cfg"
    sed -i "s|${LOOP_DEV}p2|/dev/sda2|g" "${TMP_MNT}/boot/grub/grub.cfg"
}

function unmount() {
    # info 'Shutting down container (if any)...'
    # machinectl terminate 'tmp-container' || true
    info 'Unmounting filesystems...'
    [[ -d "${TMP_MNT}" ]] && umount "${TMP_MNT}" && rm -rf "${TMP_MNT}"
    sync
    sleep 1
    [[ ! -z "${LOOP_DEV}" ]] && losetup -d "${LOOP_DEV}"
    info '... Done'
}

info 'Creating a blank image...'
qemu-img create -f raw empty.img 10G
info '... Done'

info 'Creating partitions...'
partition_gpt
info '... Done'

info 'Mounting image to system...'
LOOP_DEV="$(losetup -f --show 'empty.img')"
partprobe "${LOOP_DEV}"

info 'Formatting the partitions...'
mkfs_gpt
info '... Done'

trap 'warn "Interrupt signal received!"; unmount' SIGHUP SIGINT SIGQUIT SIGTERM
trap 'unmount' EXIT
TMP_MNT="$(mktemp -d)"

info 'Mounting rootfs...'
mount -t ext4 "${LOOP_DEV}p2" "${TMP_MNT}"
info '... Done'

info 'Decompressing tarball...'
tar xf "$1" -C "${TMP_MNT}"
info '... Done'

info 'Running dracut...'
systemd-nspawn --bind "${LOOP_DEV}p1":"${LOOP_DEV}p1" --bind "${LOOP_DEV}p2":"${LOOP_DEV}p2" --bind "${LOOP_DEV}":"${LOOP_DEV}" -D "${TMP_MNT}" /usr/bin/bash /var/ab/triggered/dracut
info '... Done'

info 'Writing bootloader...'
sed -i 's,\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$,\1 console=ttyS0\,115200",g' "${TMP_MNT}/etc/default/grub"
bootloader_efi
info '... Done'
