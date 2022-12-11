# -*- mode: makefile-gmake -*-

all:
.PHONY: all

# check GNU Make
ifeq ($(.FEATURES),)
  $(error Sorry, please use a newer version (3.81 or later) of gmake (GNU Make).)
endif

# check gawk
GAWK := $(shell which gawk 2>/dev/null || type -p gawk 2>/dev/null)
ifneq ($(GAWK),)
  GAWK_VERSION := $(shell LANG=C $(GAWK) --version 2>/dev/null | sed -n '1{/[Gg][Nn][Uu] [Aa][Ww][Kk]/p;}')
  ifeq ($(GAWK_VERSION),)
    $(error Sorry, gawk is found but does not seem to work. Please install a proper version of gawk (GNU Awk).)
  endif
else
  GAWK := $(shell which awk 2>/dev/null || type -p awk 2>/dev/null)
  ifeq ($(GAWK),)
    $(error Sorry, gawk/awk could not be found. Please check your PATH environment variable.)
  endif
  GAWK_VERSION := $(shell LANG=C $(GAWK) --version 2>/dev/null | sed -n '1{/[Gg][Nn][Uu] [Aa][Ww][Kk]/p;}')
  ifeq ($(GAWK_VERSION),)
    $(error Sorry, gawk could not be found. Please install gawk (GNU Awk).)
  endif
endif

MWGPP:=$(GAWK) -f make/mwg_pp.awk

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
$(OUTDIR)/ble.sh: ble.pp GNUmakefile | .git $(OUTDIR)
	DEPENDENCIES_PHONY=1 DEPENDENCIES_OUTPUT="$(@:%.sh=%.dep)" DEPENDENCIES_TARGET="$@" \
	  FULLVER=$(FULLVER) \
	  BUILD_GIT_VERSION="$(shell LANG=C git --version)" \
	  BUILD_MAKE_VERSION="$(shell LANG=C $(MAKE) --version | head -1)" \
	  BUILD_GAWK_VERSION="$(GAWK_VERSION)" \
	  $(MWGPP) $< >/dev/null
.DELETE_ON_ERROR: $(OUTDIR)/ble.sh

src/canvas.c2w.sh:
	bash make_command.sh generate-c2w-table > $@
src/canvas.c2w.musl.sh: make/canvas.c2w.wcwidth-musl.c
	+make -C make canvas.c2w.wcwidth-musl.exe
	make/canvas.c2w.wcwidth-musl.exe | bash make_command.sh convert-custom-c2w-table _ble_util_c2w_musl > $@
src/canvas.emoji.sh:
	bash make_command.sh generate-emoji-table > $@

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
outfiles += $(OUTDIR)/lib/core-cmdspec.sh
outfiles += $(OUTDIR)/lib/core-debug.sh
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
outfiles += $(OUTDIR)/lib/test-decode.sh
outfiles += $(OUTDIR)/lib/test-edit.sh
outfiles += $(OUTDIR)/lib/test-syntax.sh
outfiles += $(OUTDIR)/lib/test-complete.sh
$(OUTDIR)/lib/%.sh: lib/%.sh | $(OUTDIR)/lib
	cp -p $< $@
$(OUTDIR)/lib/%.txt: lib/%.txt | $(OUTDIR)/lib
	cp -p $< $@
$(OUTDIR)/lib/core-syntax.sh: lib/core-syntax.sh lib/core-syntax-ctx.def | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-msys1.sh: lib/init-msys1.sh lib/init-msys1-helper.c | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/test-canvas.sh: lib/test-canvas.sh lib/test-canvas.GraphemeClusterTest.sh | $(OUTDIR)/lib
	$(MWGPP) $< > $@

outfiles += $(OUTDIR)/lib/benchmark.ksh
$(OUTDIR)/lib/benchmark.ksh: lib/benchmark.ksh src/benchmark.sh
	$(MWGPP) $< > $@

#outfiles += $(OUTDIR)/lib/init-msleep.sh
#$(OUTDIR)/lib/init-msleep.sh: lib/init-msleep.sh lib/init-msleep.c | $(OUTDIR)/lib
#	$(MWGPP) $< > $@

#------------------------------------------------------------------------------
# documents

outdirs += $(OUTDIR)/doc
outfiles-doc += $(OUTDIR)/doc/README.md
outfiles-doc += $(OUTDIR)/doc/README-ja_JP.md
outfiles-doc += $(OUTDIR)/doc/LICENSE.md
outfiles-doc += $(OUTDIR)/doc/CONTRIBUTING.md
outfiles-doc += $(OUTDIR)/doc/ChangeLog.md
outfiles-doc += $(OUTDIR)/doc/Release.md
$(OUTDIR)/doc/%: % | $(OUTDIR)/doc
	cp -p $< $@

$(OUTDIR)/doc/%: docs/% | $(OUTDIR)/doc
	cp -p $< $@

#------------------------------------------------------------------------------
# contrib

.PHONY: update-contrib
update-contrib contrib/contrib.mk:
	git submodule update --init --recursive

include contrib/contrib.mk

#------------------------------------------------------------------------------
# target "all"

$(outdirs):
	mkdir -p $@

build: contrib/contrib.mk $(outfiles) $(outfiles-doc)
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
