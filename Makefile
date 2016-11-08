# -*- mode: makefile-gmake -*-

all:
.PHONY: all dist

# check GNU Makefile
ifeq ($(.FEATURES),)
  $(error Sorry, please use a newer version of gmake (GNU Makefile).)
endif

# check gawk
GAWK := $(shell which gawk 2>/dev/null)
ifeq ($(GAWK),)
  GAWK := $(shell which awk 2>/dev/null)
  ifeq ($(GAWK),)
    $(error Sorry, gawk/awk could not be found. Please check your PATH environment variable.)
  endif
  ifeq ($(shell $(GAWK) --version | grep -Fi 'GNU Awk'),)
    $(error Sorry, gawk could not be found. Please install gawk (GNU Awk).)
  endif
endif

PP:=$(GAWK) -f ext/mwg_pp.awk

FULLVER:=0.1.5

outfiles+=out
out:
	mkdir -p $@

outfiles+=out/ble.sh
out/ble.sh: ble.pp ble-core.sh ble-decode.sh ble-getopt.sh ble-edit.sh ble-color.sh ble-syntax.sh
	$(PP) $< >/dev/null

outfiles+=out/term.sh
out/term.sh: term.sh
	cp -p $< $@
outfiles+=out/bind.sh
out/bind.sh: bind.sh
	cp -p $< $@
outfiles+=out/complete.sh
out/complete.sh: complete.sh
	cp -p $< $@

outfiles+=out/keymap
out/keymap:
	mkdir -p $@
outfiles+=out/keymap/emacs.sh
out/keymap/emacs.sh: keymap/emacs.sh
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
	dir="ble-$(FULLVER)" && \
{ for f in $(outfiles); do d="$$dir$${f#out}"; if [[ -d $$f ]]; then mkdir -p "$$d"; else cp "$$f" "$$d"; fi; done; } && \
tar caf "dist/$$dir.$$(date +'%Y%m%d').tar.xz" "$$dir" && rm -r "$$dir"

dist0:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble $(dist_excludes)

list-functions:
	awk '/^[[:space:]]*function[[:space:]]+/{sub(/^[[:space:]]*function[[:space:]]+/,"");sub(/[[:space:]]+\{.*$$/,"");print $$0}' ble.sh |sort
