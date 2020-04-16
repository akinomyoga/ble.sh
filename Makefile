# -*- mode: makefile-gmake -*-

all:
.PHONY: all

# check GNU Makefile
ifeq ($(.FEATURES),)
  $(error Sorry, please use a newer version of gmake (GNU Makefile).)
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

#------------------------------------------------------------------------------
# ble.sh

FULLVER:=0.4.0-devel2

OUTDIR:=out

outdirs += $(OUTDIR)

# Note: the following line is a workaround for the missing
#   DEPENDENCIES_PHONY option for mwg_pp in older Makefile
ble-form.sh:

outfiles+=$(OUTDIR)/ble.sh
-include $(OUTDIR)/ble.dep
$(OUTDIR)/ble.sh: ble.pp Makefile | $(OUTDIR)
	DEPENDENCIES_PHONY=1 DEPENDENCIES_OUTPUT=$(@:%.sh=%.dep) DEPENDENCIES_TARGET=$@ FULLVER=$(FULLVER) \
	  $(MWGPP) $< >/dev/null

#------------------------------------------------------------------------------
# keymap

outdirs += $(OUTDIR)/keymap
outfiles += $(OUTDIR)/keymap/emacs.sh
outfiles += $(OUTDIR)/keymap/vi.sh $(OUTDIR)/keymap/vi_digraph.sh $(OUTDIR)/keymap/vi_digraph.txt $(OUTDIR)/keymap/vi_test.sh
outfiles += $(OUTDIR)/keymap/emacs.rlfunc.txt
outfiles += $(OUTDIR)/keymap/vi_imap.rlfunc.txt
outfiles += $(OUTDIR)/keymap/vi_nmap.rlfunc.txt
$(OUTDIR)/keymap/%.sh: keymap/%.sh | $(OUTDIR)/keymap
	cp -p $< $@
$(OUTDIR)/keymap/%.txt: keymap/%.txt | $(OUTDIR)/keymap
	cp -p $< $@

#------------------------------------------------------------------------------
# lib

outdirs += $(OUTDIR)/lib
outfiles += $(OUTDIR)/lib/init-term.sh
outfiles += $(OUTDIR)/lib/init-bind.sh
outfiles += $(OUTDIR)/lib/init-cmap.sh
outfiles += $(OUTDIR)/lib/init-msys1.sh
outfiles += $(OUTDIR)/lib/core-complete.sh
outfiles += $(OUTDIR)/lib/core-syntax.sh
outfiles += $(OUTDIR)/lib/core-test.sh
outfiles += $(OUTDIR)/lib/core-edit.ignoreeof-messages.txt
outfiles += $(OUTDIR)/lib/vim-surround.sh
outfiles += $(OUTDIR)/lib/vim-arpeggio.sh
$(OUTDIR)/lib/%.sh: lib/%.sh | $(OUTDIR)/lib
	cp -p $< $@
$(OUTDIR)/lib/%.txt: lib/%.txt | $(OUTDIR)/lib
	cp -p $< $@
$(OUTDIR)/lib/core-syntax.sh: lib/core-syntax.sh lib/core-syntax-ctx.def | $(OUTDIR)/lib
	$(MWGPP) $< > $@

#------------------------------------------------------------------------------
# contrib

.PHONY: update-contrib
update-contrib:
	git submodule update --init --recursive
contrib/.git:
	git submodule update --init --recursive
outdirs += $(OUTDIR)/contrib
contrib-files = $(wildcard contrib/*.bash)
outfiles += $(contrib-files:contrib/%=$(OUTDIR)/contrib/%)
$(OUTDIR)/contrib/%.bash: contrib/%.bash | contrib/.git $(OUTDIR)/contrib
	cp -p $< $@

#------------------------------------------------------------------------------
# target "all"

$(outdirs):
	mkdir -p $@

all: contrib/.git $(outfiles)

#------------------------------------------------------------------------------
# target "install"

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
.PHONY: install

clean:
	-rm -rf $(outfiles) $(OUTDIR)/ble.dep
.PHONY: clean

dist: $(outfiles)
	FULLVER=$(FULLVER) bash make_command.sh dist $^
.PHONY: dist

dist_excludes= \
	--exclude=./ble/backup \
	--exclude=*~ \
	--exclude=./ble/.git \
	--exclude=./ble/out \
	--exclude=./ble/dist \
	--exclude=./ble/ble.sh
dist.date:
	cd .. && tar cavf "$$(date +ble.%Y%m%d.tar.xz)" ./ble $(dist_excludes)
.PHONY: dist.date

list-functions:
	awk '/^[[:space:]]*function[[:space:]]+/{sub(/^[[:space:]]*function[[:space:]]+/,"");sub(/[[:space:]]+\{.*$$/,"");print $$0}' out/ble.sh | sort
.PHONY: list-functions

ignoreeof-messages:
	bash make_command.sh ignoreeof-messages
.PHONY: ignoreeof-messages

check:
	bash make_command.sh check
.PHONY: check
