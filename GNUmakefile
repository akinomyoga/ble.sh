# -*- mode: makefile-gmake -*-

all:
.PHONY: all install dist

# check GNU Make
ifeq ($(.FEATURES),)
  $(error Sorry, please use a newer version of gmake (GNU Make).)
endif

# check gawk
GAWK := $(shell which gawk 2>/dev/null || type -p gawk 2>/dev/null)
ifeq ($(GAWK),)
  GAWK := $(shell which awk 2>/dev/null || type -p awk 2>/dev/null)
  ifeq ($(GAWK),)
    $(error Sorry, gawk/awk could not be found. Please check your PATH environment variable.)
  endif
  ifeq ($(shell $(GAWK) --version | grep -Fi 'GNU Awk'),)
    $(error Sorry, gawk could not be found. Please install gawk (GNU Awk).)
  endif
endif

MWGPP:=$(GAWK) -f ext/mwg_pp.awk

FULLVER:=0.2.7

OUTDIR:=out

outdirs += $(OUTDIR)
outdirs += $(OUTDIR)/lib

outfiles+=$(OUTDIR)/ble.sh
$(OUTDIR)/ble.sh: ble.pp ble-core.sh ble-decode.sh ble-edit.sh ble-color.sh ble-syntax-lazy.sh ble-form.sh | $(OUTDIR)
	$(MWGPP) $< >/dev/null

outfiles+=$(OUTDIR)/term.sh
$(OUTDIR)/term.sh: term.sh | $(OUTDIR)
	cp -p $< $@
outfiles+=$(OUTDIR)/bind.sh
$(OUTDIR)/bind.sh: bind.sh | $(OUTDIR)
	cp -p $< $@
outfiles+=$(OUTDIR)/lib/core-complete.sh
$(OUTDIR)/lib/core-complete.sh: lib/core-complete.sh | $(OUTDIR)/lib
	cp -p $< $@
outfiles+=$(OUTDIR)/lib/core-syntax.sh
$(OUTDIR)/lib/core-syntax.sh: lib/core-syntax.sh | $(OUTDIR)/lib
	$(MWGPP) $< > $@
outfiles+=$(OUTDIR)/ignoreeof-messages.txt
$(OUTDIR)/ignoreeof-messages.txt: ignoreeof-messages.txt | $(OUTDIR)
	cp -p $< $@

outdirs += $(OUTDIR)/cmap
outfiles += $(OUTDIR)/cmap/default.sh
$(OUTDIR)/cmap/%.sh: cmap/%.sh | $(OUTDIR)/cmap
	cp -p $< $@

outdirs += $(OUTDIR)/keymap
outfiles += $(OUTDIR)/keymap/emacs.sh
outfiles += $(OUTDIR)/keymap/vi.sh $(OUTDIR)/keymap/vi_digraph.sh $(OUTDIR)/keymap/vi_digraph.txt $(OUTDIR)/keymap/vi_test.sh
$(OUTDIR)/keymap/%.sh: keymap/%.sh | $(OUTDIR)/keymap
	cp -p $< $@
$(OUTDIR)/keymap/%.txt: keymap/%.txt | $(OUTDIR)/keymap
	cp -p $< $@

outfiles += $(OUTDIR)/lib/vim-surround.sh
$(OUTDIR)/lib/%.sh: lib/%.sh | $(OUTDIR)/lib
	cp -p $< $@

$(outdirs):
	mkdir -p $@
all: $(outfiles)

DATA_HOME := $(XDG_DATA_HOME)
ifeq ($(DATA_HOME),)
  DATA_HOME := $(HOME)/.local/share
endif
INSDIR = $(DATA_HOME)/blesh
install: $(outfiles:$(OUTDIR)/%=$(INSDIR)/%) $(INSDIR)/cache.d $(INSDIR)/tmp
$(INSDIR)/%: $(OUTDIR)/%
	bash make_command.sh install "$<" "$@"
$(INSDIR)/cache.d $(INSDIR)/tmp:
	mkdir -p $@ && chmod a+rwxt $@

dist: $(outfiles)
	FULLVER=$(FULLVER) bash make_command.sh dist $^

dist_excludes= \
	--exclude=./ble/backup \
	--exclude=*~ \
	--exclude=./ble/.git \
	--exclude=./ble/out \
	--exclude=./ble/dist \
	--exclude=./ble/ble.sh
dist.date:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble $(dist_excludes)

list-functions:
	awk '/^[[:space:]]*function[[:space:]]+/{sub(/^[[:space:]]*function[[:space:]]+/,"");sub(/[[:space:]]+\{.*$$/,"");print $$0}' ble.sh |sort
