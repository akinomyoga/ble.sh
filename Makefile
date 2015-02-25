# -*- mode:makefile-gmake -*-

all:
.PHONY: all dist

outfiles+=out
out:
	mkdir -p $@

outfiles+=out/ble.sh
out/ble.sh: ble.pp ble-core.sh ble-decode.sh ble-getopt.sh ble-edit.sh ble-color.sh ble-syntax.sh
	mwg_pp.awk $< >/dev/null

outfiles+=out/term.sh
out/term.sh: term.sh
	cp -p $< $@

outfiles+=out/cmap
out/cmap:
	mkdir -p $@

outfiles+=out/cmap/default.sh
out/cmap/default.sh: cmap/default.sh
	cp -p $< $@

all: $(outfiles)

dist_excludes= \
	--exclude=./ble/backup \
	--exclude=*~ \
	--exclude=./ble/.git \
	--exclude=./ble/out \
	--exclude=./ble/dist \
	--exclude=./ble/ble.sh

dist:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble $(dist_excludes)

listf:
	awk '/^[[:space:]]*function/{sub(/^[[:space:]]*function[[:space:]]*/,"");sub(/[[:space:]]*\{[[:space:]]*$$/,"");print $$0}' ble.sh |sort
