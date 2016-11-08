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

FULLVER:=0.2.alpha

OUTDIR:=out
outfiles+=$(OUTDIR) $(OUTDIR)/keymap $(OUTDIR)/cmap
$(OUTDIR) $(OUTDIR)/keymap $(OUTDIR)/cmap:
	mkdir -p $@

outfiles+=$(OUTDIR)/ble.sh
$(OUTDIR)/ble.sh: ble.pp ble-core.sh ble-decode.sh ble-edit.sh ble-color.sh ble-syntax.sh | $(OUTDIR)
	$(PP) $< >/dev/null

outfiles+=$(OUTDIR)/term.sh
$(OUTDIR)/term.sh: term.sh | $(OUTDIR)
	cp -p $< $@
outfiles+=$(OUTDIR)/bind.sh
$(OUTDIR)/bind.sh: bind.sh | $(OUTDIR)
	cp -p $< $@
outfiles+=$(OUTDIR)/complete.sh
$(OUTDIR)/complete.sh: complete.sh | $(OUTDIR)
	cp -p $< $@
outfiles+=$(OUTDIR)/ignoreeof-messages.txt
$(OUTDIR)/ignoreeof-messages.txt: ignoreeof-messages.txt | $(OUTDIR)
	cp -p $< $@

outfiles+=$(OUTDIR)/keymap/emacs.sh
$(OUTDIR)/keymap/emacs.sh: keymap/emacs.sh | $(OUTDIR)/keymap
	cp -p $< $@

outfiles+=$(OUTDIR)/cmap/default.sh
$(OUTDIR)/cmap/default.sh: cmap/default.sh | $(OUTDIR)/cmap
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

dist.date:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble $(dist_excludes)

list-functions:
	awk '/^[[:space:]]*function[[:space:]]+/{sub(/^[[:space:]]*function[[:space:]]+/,"");sub(/[[:space:]]+\{.*$$/,"");print $$0}' ble.sh |sort
