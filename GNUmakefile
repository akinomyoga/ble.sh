# -*- mode: makefile-gmake -*-

all:
.PHONY: all

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

#------------------------------------------------------------------------------
# ble.sh

FULLVER:=0.4.0-devel3

OUTDIR:=out

outdirs += $(OUTDIR)

# Note: the following line is a workaround for the missing
#   DEPENDENCIES_PHONY option for mwg_pp in older Makefile
ble-form.sh:

outfiles+=$(OUTDIR)/ble.sh
-include $(OUTDIR)/ble.dep
$(OUTDIR)/ble.sh: ble.pp GNUmakefile | $(OUTDIR)
	DEPENDENCIES_PHONY=1 DEPENDENCIES_OUTPUT=$(@:%.sh=%.dep) DEPENDENCIES_TARGET=$@ FULLVER=$(FULLVER) \
	  $(MWGPP) $< >/dev/null

#------------------------------------------------------------------------------
# keymap

outdirs += $(OUTDIR)/keymap
outfiles += $(OUTDIR)/keymap/emacs.sh
outfiles += $(OUTDIR)/keymap/vi.sh $(OUTDIR)/keymap/vi_digraph.sh $(OUTDIR)/keymap/vi_digraph.txt $(OUTDIR)/keymap/vi_test.sh
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
outfiles += $(OUTDIR)/lib/core-decode.emacs-rlfunc.txt
outfiles += $(OUTDIR)/lib/core-decode.vi_imap-rlfunc.txt
outfiles += $(OUTDIR)/lib/core-decode.vi_nmap-rlfunc.txt
outfiles += $(OUTDIR)/lib/vim-surround.sh
outfiles += $(OUTDIR)/lib/vim-arpeggio.sh
outfiles += $(OUTDIR)/lib/vim-airline.sh
outfiles += $(OUTDIR)/lib/test-main.sh
outfiles += $(OUTDIR)/lib/test-util.sh
outfiles += $(OUTDIR)/lib/test-canvas.sh
$(OUTDIR)/lib/%.sh: lib/%.sh | $(OUTDIR)/lib
	cp -p $< $@
$(OUTDIR)/lib/%.txt: lib/%.txt | $(OUTDIR)/lib
	cp -p $< $@
$(OUTDIR)/lib/core-syntax.sh: lib/core-syntax.sh lib/core-syntax-ctx.def | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-msys1.sh: lib/init-msys1.sh lib/init-msys1-helper.c | $(OUTDIR)/lib
	$(MWGPP) $< > $@

#outfiles += $(OUTDIR)/lib/init-msleep.sh
#$(OUTDIR)/lib/init-msleep.sh: lib/init-msleep.sh lib/init-msleep.c | $(OUTDIR)/lib
#	$(MWGPP) $< > $@

#------------------------------------------------------------------------------
# documents

outdirs += $(OUTDIR)/doc
outfiles-doc += $(OUTDIR)/doc/README.md
outfiles-doc += $(OUTDIR)/doc/README-ja_JP.md
outfiles-doc += $(OUTDIR)/doc/CONTRIBUTING.md
outfiles-doc += $(OUTDIR)/doc/LICENSE.md
$(OUTDIR)/doc/%: % | $(OUTDIR)/doc
	cp -p $< $@

#------------------------------------------------------------------------------
# contrib

.PHONY: update-contrib
update-contrib:
	git submodule update --init --recursive
contrib/.git:
	git submodule update --init --recursive
outdirs += $(OUTDIR)/contrib $(OUTDIR)/contrib/airline
contrib-files = $(wildcard contrib/*.bash contrib/airline/*.bash)
outfiles += $(contrib-files:contrib/%=$(OUTDIR)/contrib/%)
$(OUTDIR)/contrib/%.bash: contrib/%.bash | contrib/.git $(OUTDIR)/contrib $(OUTDIR)/contrib/airline
	cp -p $< $@

#------------------------------------------------------------------------------
# target "all"

$(outdirs):
	mkdir -p $@

build: contrib/.git $(outfiles) $(outfiles-doc)
.PHONY: build

all: build

#------------------------------------------------------------------------------
# target "install"

ifneq ($(INSDIR),)
  ifeq ($(INSDIR_DOC),)
    INSDIR_DOC := $(INSDIR)/doc
  endif
else
  ifneq ($(filter-out %/,$(DESTDIR)),)
    DESTDIR := $(DESTDIR)/
  endif

  ifneq ($(DESTDIR)$(PREFIX),)
    DATA_HOME := $(DESTDIR)$(PREFIX)/share
  else ifneq ($(XDG_DATA_HOME),)
    DATA_HOME := $(XDG_DATA_HOME)
  else
    DATA_HOME := $(HOME)/.local/share
  endif

  INSDIR = $(DATA_HOME)/blesh
  INSDIR_DOC = $(DATA_HOME)/doc/blesh
endif

install: \
  $(outfiles:$(OUTDIR)/%=$(INSDIR)/%) \
  $(outfiles-doc:$(OUTDIR)/doc/%=$(INSDIR_DOC)/%) \
  $(INSDIR)/cache.d $(INSDIR)/run
$(INSDIR)/%: $(OUTDIR)/%
	bash make_command.sh install "$<" "$@"
$(INSDIR_DOC)/%: $(OUTDIR)/doc/%
	bash make_command.sh install "$<" "$@"
$(INSDIR)/cache.d $(INSDIR)/run:
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

#------------------------------------------------------------------------------

define DeclareMakeCommand
$1: $2
	bash make_command.sh $1
.PHONY: $1
endef

$(eval $(call DeclareMakeCommand,ignoreeof-messages,))
$(eval $(call DeclareMakeCommand,scan,))
$(eval $(call DeclareMakeCommand,check,build))
$(eval $(call DeclareMakeCommand,check-all,build))
$(eval $(call DeclareMakeCommand,list-functions,))
