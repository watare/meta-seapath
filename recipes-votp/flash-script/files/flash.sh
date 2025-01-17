#!/bin/bash
# Copyright (C) 2020, RTE (http://www.rte-france.com)
# This program is distributed under the Apache 2 license.

usage()
{
    echo 'Flash an image on disk'
    echo 'usage: flash [-h] [-i] image -d disk'
    echo
    echo 'mandatory arguments:'
    echo '  -i,--image   image  the image wic or wic.gz image to flash'
    echo '  -d,--disk    disk   the disk to be flashed. Usualy /dev/sda'
    echo
    echo 'optional arguments:'
    echo '  -h, --help          show this help message and exit'
}


disk=
image=
options=$(getopt -o hi:d: --long image:,disk:,help -- "$@")

[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}

eval set -- "$options"
while true; do
    case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
    -i|--image)
        shift
        image="$1"
        ;;
    -d|--disk)
        shift
        disk="$1"
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ -z "${disk}" ] ; then
    echo "Error missing argument: disk"
    usage
    exit 1
fi

if [ -z "${image}" ] ; then
    echo "Error missing argument: image"
    usage
    exit 1
fi

if [ ! -b "${disk}" ] ; then
    echo "Error $disk is not a block device"
    usage
    exit 1
fi

if [ ! -f "${image}" ] ; then
    echo "Error $image is not a file"
    usage
    exit 1
fi

bmap="${image%.*}.bmap"
if [ -f "${bmap}" ] ; then
    command="bmaptool copy \"$image\" \"${disk}\""
else
    if echo "$image" | grep -qE "\.gz$"  ; then
        command="gzip -d -c \"$image\" | dd of=\"${disk}\" bs=32M"
    else
        command="dd if=\"$image\" of=\"${disk}\" bs=32M"
    fi
fi

if eval "$command" ; then
    sync
    echo "Flash $image on $disk: success"
else
    echo "Flash $image on $disk: failed"
    exit 1
fi

# If EFI image create boot entries
if command -v efibootmgr &> /dev/null ; then

    echo "EFI image."
    entry_num=$(efibootmgr | awk '/SEAPATH slot 0/{ gsub("Boot", ""); gsub("*", ""); print $1 }')
    if [ ! -z "$entry_num" ] ;  then
        echo "EFI entry SEAPATH slot 0 already exists. Remove it"
        command="efibootmgr -q -b $entry_num -B"
        if eval "$command" ; then
            echo "Entry SEAPATH slot 0 successfully removed"
        else
            echo "Error while removing entry SEAPATH slot 0"
            exit 1
        fi
    fi

    entry_num=$(efibootmgr | awk '/SEAPATH slot 1/{ gsub("Boot", ""); gsub("*", ""); print $1 }')
    if [ ! -z "$entry_num" ] ;  then
        echo "EFI entry SEAPATH slot 1 already exists. Remove it"
        command="efibootmgr -q -b $entry_num -B"
        if eval "$command" ; then
            echo "Entry SEAPATH slot 1 successfully removed"
        else
            echo "Error while removing entry SEAPATH slot 1"
            exit 1
        fi
    fi

    command="efibootmgr -q -c -d \"$disk\" -p 2 -L \"SEAPATH slot 1\" -l /EFI/BOOT/bootx64.efi"
    if eval "$command" ; then
        echo "Entry SEAPATH slot 1 successfully created"
    else
        echo "Error while creating entry SEAPATH slot 1"
        exit 1
    fi

    command="efibootmgr -q -c -d \"$disk\" -p 1 -L \"SEAPATH slot 0\" -l /EFI/BOOT/bootx64.efi"
    if eval "$command" ; then
        echo "Entry SEAPATH slot 0 successfully created"
    else
        echo "Error while creating entry SEAPATH slot 0"
        exit 1
    fi

    # Disable slot 1
    passive_boot=$(efibootmgr | awk '/SEAPATH slot 1/{ gsub("Boot", ""); gsub("*", ""); print $1 }')
    if efibootmgr -q -b "${passive_boot}" -A ; then
        echo "Entry ${passive_boot} sucessfully disabled"
    else
        echo "Error while disabling entry ${passive_boot}"  1>&2
        exit 1
    fi

    # Set top boot order priority for USB and PXE entries
    boot_order=$(efibootmgr | grep "BootOrder" | awk '{ print $2}')
    usb_entries=$(efibootmgr | awk '/USB HDD/{ gsub("Boot",""); gsub("*", ""); print $1 }')
    pxe_entries=$(efibootmgr | awk '/PCI LAN/{ gsub("Boot",""); gsub("*", ""); print $1 }')

    # Create top priority list and remove from original boot order
    top_priority=""
    for entry in $usb_entries $pxe_entries
    do
        top_priority+=$entry","
        boot_order=${boot_order/$entry/}
    done

    # Concatenate lists and remove commas if they are repeated or in last position
    boot_order=$(echo $top_priority$boot_order | tr -s "," | sed 's/,$//')

    # Change boot order
    if efibootmgr -q -o "$boot_order" ; then
        echo "Boot order successfully changed"
    else
        echo "Error while changing boot order"
        exit 1
    fi
fi

echo "You can reboot. Don't forget to remove your USB key."
