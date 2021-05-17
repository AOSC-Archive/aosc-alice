#!/bin/bash -e

warn(){ echo -e "[\e[33mWARN\e[0m]: \e[1m$*\e[0m" >&2; }
err(){ echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m" >&2; }
info(){ echo -e "[\e[96mINFO\e[0m]: \e[1m$*\e[0m" >&2; }

_help_message() {
    printf "\
Usage:

	create-vm-image.sh TARBALL IMG_NAME IMG_SIZE

	- TARBALL: AOSC OS tarball from which to create VM disk image.
	- IMG_NAME: Output VM disk image file name.
	- IMG_SIZE: Size of VM disk image (defaults to "16G").

"
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    _help_message
    exit 0
fi

if [ -z "$1" ]; then
   err "Please specify a tarball!\n"
   _help_message
   exit 1
fi

if [ -z "$2" ]; then
   err "Please specify a file name for your VM disk image!\n"
   _help_message
   exit 1
fi

partition_gpt() {
    # Create an 128MiB partition for ESP.
    sgdisk -n1:0:131072 "$1"
    # Setting partition type to "EFI System."
    sgdisk -t1:ef00 "$1"
    # Creating a system root partition with the rest of available free space.
    sgdisk -N2 "$1"
}

mkfs_gpt() {
    mkfs.vfat "${LOOP_DEV}p1"
    mkfs.ext4 "${LOOP_DEV}p2"
}

bootloader_efi() {
    systemd-nspawn --bind "${LOOP_DEV}p1":"${LOOP_DEV}p1" --bind "${LOOP_DEV}p2":"${LOOP_DEV}p2" --bind "${LOOP_DEV}":"${LOOP_DEV}" -D "${TMP_MNT}" /usr/bin/bash -c "mkdir -p /efi && mount ${LOOP_DEV}p1 /efi && grub-install --target=x86_64-efi --bootloader-id=AOSC-GRUB --efi-directory=/efi --removable && grub-mkconfig -o /boot/grub/grub.cfg"
    sed -i "s|${LOOP_DEV}p2|/dev/sda2|g" "${TMP_MNT}/boot/grub/grub.cfg"
}

unmount() {
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
qemu-img create -f raw $2 ${3:-16G}
info '... Done'

info 'Creating partitions...'
partition_gpt $2
info '... Done'

info 'Mounting image to system...'
LOOP_DEV="$(losetup -f --show "$2")"
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
tar --numeric-owner -pxvf "$1" -C "${TMP_MNT}"
info '... Done'

info 'Running dracut...'
systemd-nspawn --bind "${LOOP_DEV}p1":"${LOOP_DEV}p1" --bind "${LOOP_DEV}p2":"${LOOP_DEV}p2" --bind "${LOOP_DEV}":"${LOOP_DEV}" -D "${TMP_MNT}" /usr/bin/update-initramfs
info '... Done'

info 'Writing bootloader...'
sed -i 's,\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$,\1 console=ttyS0\,115200",g' "${TMP_MNT}/etc/default/grub"
bootloader_efi
info '... Done'
