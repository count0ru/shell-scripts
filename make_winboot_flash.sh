USBDRIVE=$1
PATH_TO_ISO=$2

umount $USBDRIVE
mkfs.vfat $USBDRIVE
mkdir -p /tmp/iso
mkdir -p /tmp/usbflash
mount -o loop $PATH_TO_ISO /tmp/iso
mount $USBDRIVE /tmp/usbflash
cp -Rfv /tmp/iso/* /tmp/usbflash
USBPART=$(echo $USBDRIVE | tr -d '1234567890' )
grub-install --target=i386-pc --boot-directory="/mnt/usbflash/boot" $USBPART
parted $USBPART set 1 boot on

cat  /tmp/usbflash/boot/grub/grub.cfg <<EOF
menuentry 'Boot windows shet' {
     ntldr /bootmgr
 }
EOF

umount /tmp/usbflash && rm -rf /tmp/usbflash
umount /tmp/iso && rm -rf /tmp/iso






