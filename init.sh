#!/bin/bash

CONFIGFS=/sys/kernel/config/usb_gadget
GADGET=$CONFIGFS/mygadget
baseImg=img1

help () {
	echo available options are init, start and stop
}

init () {
	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

	echo "-> Creating backup"
	mkdir -p "$SCRIPT_DIR"/backup
	cp "$SCRIPT_DIR"/gadget.service "$SCRIPT_DIR"/backup/
	cp "$SCRIPT_DIR"/init.sh "$SCRIPT_DIR"/backup/

	echo "-> Creating files for mass storage function of usb gadget"
	mkdir /storage
	fallocate -l 1G /storage/$baseImg
	mkfs.vfat -F 32 -n "RPi0 Storage" /storage/$baseImg

	echo "-> Copying init script"
	cp "$SCRIPT_DIR"/init.sh /usr/local/bin/gadget.sh

	echo "-> Enabling systemd service"
	systemctl enable "$SCRIPT_DIR"/gadget.service
}

start () {
	LANGUAGE=0x409 # English

	echo "Creating gadget"
	mkdir -p $GADGET
	cd $GADGET || exit 1

	echo "Configuring device identifiers"
	echo 0x1d6b > idVendor  # Linux Foundation
	echo 0x0104 > idProduct # Multifunction Composite Gadget
	echo 0x0100 > bcdDevice # v1.0.0
	echo 0x0200 > bcdUSB    # USB 2.0

	mkdir -p strings/$LANGUAGE
	echo "001" > strings/$LANGUAGE/serialnumber
	echo "Plasny" > strings/$LANGUAGE/manufacturer
	echo "USB Multitool" > strings/$LANGUAGE/product

	echo "Creating serial function"
	mkdir -p functions/acm.usb0

	echo "Creating mass storage function"
	mkdir -p functions/mass_storage.usb0
	echo 1 > functions/mass_storage.usb0/stall
	echo 0 > functions/mass_storage.usb0/lun.0/cdrom
	echo 0 > functions/mass_storage.usb0/lun.0/ro
	echo 0 > functions/mass_storage.usb0/lun.0/nofua
	echo "/storage/$baseImg" > functions/mass_storage.usb0/lun.0/file

	echo "Creating gadget configuration"
	mkdir -p configs/c.1/strings/$LANGUAGE
	echo 500 > configs/c.1/MaxPower
	echo "Config 1" > configs/c.1/strings/$LANGUAGE/configuration

	echo "Symlinking functions to gadget configuration"
	ln -s functions/acm.usb0 configs/c.1/
	ln -s functions/mass_storage.usb0 configs/c.1/

	echo "Attaching gadget"
	ls /sys/class/udc/ > UDC

	echo "Gadget started corectly"
}

stop () {
	echo "Dettaching gadget"
	echo "" > UDC

	echo "Removing configfs entries"
	find $GADGET/configs/* -type l -exec rm {} \;
	find $GADGET/configs/*/strings/* -maxdepth 0 -type d -exec rmdir {} \;
	find $GADGET/functions/* -maxdepth 0 -type d -exec rmdir {} \;
	find $GADGET/strings/* -maxdepth 0 -type d -exec rmdir {} \;
	find $GADGET/configs/* -maxdepth 0 -type d -exec rmdir {} \;
	rmdir $GADGET

	echo "Gadget stopped corectly"
}

if [ "$(id -u)" -ne 0 ]; then
	echo "You need to be root to run this script"
	exit 1
fi

if [ "$(ps --no-headers -o comm 1)" != "systemd" ]; then
	echo "You need to use systemd as a init service"
	exit 1
fi

case "$1" in
	init) init;;
	start) start;;
	stop) stop;;
	*) help;; 
esac

