# -*- mode:makefile-gmake -*-

all: ble.sh
.PHONY: all dist

ble.sh: ble.pp ble-core.sh ble-decode.sh ble-getopt.sh ble-edit.sh ble-color.sh ble-syntax.sh
	mwg_pp.awk $< >/dev/null

dist:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble --exclude=./ble/backup --exclude=*~ --exclude=./ble/.git

listf:
	awk '/^[[:space:]]*function/{sub(/^[[:space:]]*function[[:space:]]*/,"");sub(/[[:space:]]*\{[[:space:]]*$$/,"");print $$0}' ble.sh |sort
