# -*- mode: makefile-gmake -*-

all:
.PHONY: all

# git version
GIT_VERSION = $(shell LANG=C git --version)

# check GNU Make
ifeq ($(.FEATURES),)
  $(error Sorry, please use a newer version (3.81 or later) of gmake (GNU Make).)
endif
MAKE_VERSION := $(shell LANG=C $(MAKE) --version | head -1)

# check gawk
GAWK := $(shell which gawk 2>/dev/null || bash -c 'builtin type -P gawk' 2>/dev/null)
ifneq ($(GAWK),)
  GAWK_VERSION := $(shell LANG=C $(GAWK) --version 2>/dev/null | sed -n '1{/[Gg][Nn][Uu] [Aa][Ww][Kk]/p;}')
  ifeq ($(GAWK_VERSION),)
    $(error Sorry, gawk is found but does not seem to work. Please install a proper version of gawk (GNU Awk).)
  endif
else
  GAWK := $(shell which awk 2>/dev/null || bash -c 'builtin type -P awk' 2>/dev/null)
  ifeq ($(GAWK),)
    $(error Sorry, gawk/awk could not be found. Please check your PATH environment variable.)
  endif
  GAWK_VERSION := $(shell LANG=C $(GAWK) --version 2>/dev/null | sed -n '1{/[Gg][Nn][Uu] [Aa][Ww][Kk]/p;}')
  ifeq ($(GAWK_VERSION),)
    $(error Sorry, gawk could not be found. Please install gawk (GNU Awk).)
  endif
endif

MWGPP := $(GAWK) -f make/mwg_pp.awk

# Note (#D2058): we had used "cp -p xxx out/xxx" to copy files to the build
# directory, but some filesystem (ecryptfs) has a bug that the subsecond
# timestamps are truncated causing an issue: make every time copies all the
# files into the subdirectory `out`.  We give up using `cp -p` and instead copy
# the file with `cp` with the timestamps being the copy time.
CP := cp

#------------------------------------------------------------------------------
# ble.sh

FULLVER := 0.4.0-devel4

BLE_GIT_COMMIT_ID :=
BLE_GIT_BRANCH :=
ifneq ($(wildcard .git),)
  BLE_GIT_COMMIT_ID := $(shell git show -s --format=%h)
  BLE_GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
else ifneq ($(wildcard make/.git-archive-export.mk),)
  ifeq ($(shell grep '\$$Format:.*\$$' make/.git-archive-export.mk),)
    include make/.git-archive-export.mk
  endif
endif
ifeq ($(BLE_GIT_COMMIT_ID),)
  $(error Failed to determine the commit id of the current tree.  The .git directory is required to build ble.sh.)
endif

OUTDIR:=out

outdirs += $(OUTDIR)

outfiles+=$(OUTDIR)/ble.sh
-include $(OUTDIR)/ble.dep
# Note: ble.sh depends on lib/init-cmap.sh and lib/init-bind.sh
# because it contains the hash of these files for the cache.
$(OUTDIR)/ble.sh: ble.pp GNUmakefile lib/init-cmap.sh lib/init-bind.sh | $(OUTDIR)
	DEPENDENCIES_PHONY=1 DEPENDENCIES_OUTPUT="$(@:%.sh=%.dep)" DEPENDENCIES_TARGET="$@" \
	  FULLVER=$(FULLVER) \
	  BLE_GIT_COMMIT_ID="$(BLE_GIT_COMMIT_ID)" \
	  BLE_GIT_BRANCH="$(BLE_GIT_BRANCH)" \
	  BUILD_GIT_VERSION="$(GIT_VERSION)" \
	  BUILD_MAKE_VERSION="$(MAKE_VERSION)" \
	  BUILD_GAWK_VERSION="$(GAWK_VERSION)" \
	  $(MWGPP) $< >/dev/null
.DELETE_ON_ERROR: $(OUTDIR)/ble.sh

GENTABLE := bash make/canvas.c2w.generate-table.sh

src/canvas.c2w.sh:
	$(GENTABLE) c2w
src/canvas.c2w.musl.sh: make/canvas.c2w.wcwidth.cpp make/canvas.c2w.wcwidth-musl.cpp
	+make -C make canvas.c2w.wcwidth.exe
	make/canvas.c2w.wcwidth.exe table_musl2014 | $(GENTABLE) convert-custom-c2w _ble_util_c2w_musl > $@
src/canvas.emoji.sh:
	$(GENTABLE) emoji
src/canvas.GraphemeClusterBreak.sh:
	$(GENTABLE) GraphemeClusterBreak

# Note: the following line is a workaround for the missing
#   DEPENDENCIES_PHONY option for mwg_pp in older Makefile
ble-form.sh:

#------------------------------------------------------------------------------
# lib

outdirs += $(OUTDIR)/lib

# keymap
outfiles += $(OUTDIR)/lib/keymap.emacs.sh
outfiles += $(OUTDIR)/lib/keymap.vi.sh
outfiles += $(OUTDIR)/lib/keymap.vi_digraph.sh
outfiles += $(OUTDIR)/lib/keymap.vi_digraph.txt

# init
outfiles += $(OUTDIR)/lib/init-term.sh
outfiles += $(OUTDIR)/lib/init-bind.sh
outfiles += $(OUTDIR)/lib/init-cmap.sh
outfiles += $(OUTDIR)/lib/init-msys1.sh

# core
outfiles += $(OUTDIR)/lib/core-complete.sh
outfiles += $(OUTDIR)/lib/core-syntax.sh
outfiles += $(OUTDIR)/lib/core-test.sh
outfiles += $(OUTDIR)/lib/core-cmdspec.sh
outfiles += $(OUTDIR)/lib/core-debug.sh
outfiles += $(OUTDIR)/lib/core-edit.ignoreeof-messages.txt
outfiles += $(OUTDIR)/lib/core-decode.emacs-rlfunc.txt
outfiles += $(OUTDIR)/lib/core-decode.vi_imap-rlfunc.txt
outfiles += $(OUTDIR)/lib/core-decode.vi_nmap-rlfunc.txt

# vim
outfiles += $(OUTDIR)/lib/vim-surround.sh
outfiles += $(OUTDIR)/lib/vim-arpeggio.sh
outfiles += $(OUTDIR)/lib/vim-airline.sh

# test
outfiles += $(OUTDIR)/lib/test-bash.sh
outfiles += $(OUTDIR)/lib/test-main.sh
outfiles += $(OUTDIR)/lib/test-util.sh
outfiles += $(OUTDIR)/lib/test-canvas.sh
outfiles += $(OUTDIR)/lib/test-decode.sh
outfiles += $(OUTDIR)/lib/test-edit.sh
outfiles += $(OUTDIR)/lib/test-syntax.sh
outfiles += $(OUTDIR)/lib/test-complete.sh
outfiles += $(OUTDIR)/lib/test-keymap.vi.sh
outfiles += $(OUTDIR)/lib/util.bgproc.sh

$(OUTDIR)/lib/%.sh: lib/%.sh | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/%.txt: lib/%.txt | $(OUTDIR)/lib
	$(CP) $< $@
$(OUTDIR)/lib/core-syntax.sh: lib/core-syntax.sh lib/core-syntax-ctx.def | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-msys1.sh: lib/init-msys1.sh lib/init-msys1-helper.c | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/test-canvas.sh: lib/test-canvas.sh lib/test-canvas.GraphemeClusterTest.sh | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-cmap.sh: lib/init-cmap.sh | $(OUTDIR)/lib
	$(MWGPP) $< > $@
$(OUTDIR)/lib/init-bind.sh: lib/init-bind.sh | $(OUTDIR)/lib
	$(MWGPP) $< > $@

outfiles += $(OUTDIR)/lib/benchmark.ksh
$(OUTDIR)/lib/benchmark.ksh: lib/benchmark.ksh src/benchmark.sh
	$(MWGPP) $< > $@

#outfiles += $(OUTDIR)/lib/init-msleep.sh
#$(OUTDIR)/lib/init-msleep.sh: lib/init-msleep.sh lib/init-msleep.c | $(OUTDIR)/lib
#	$(MWGPP) $< > $@

# いつか削除する
removedfiles += \
  keymap/emacs.rlfunc.txt \
  keymap/emacs.sh \
  keymap/isearch.sh \
  keymap/vi.sh \
  keymap/vi_digraph.sh \
  keymap/vi_digraph.txt \
  keymap/vi_imap.rlfunc.txt \
  keymap/vi_nmap.rlfunc.txt \
  keymap/vi_test.sh \
  lib/keymap.vi_test.sh

#------------------------------------------------------------------------------
# licenses and documents

outdirs += $(OUTDIR)/licenses $(OUTDIR)/doc
outfiles-license += $(OUTDIR)/licenses/LICENSE.md
ifneq ($(USE_DOC),no)
  outfiles-doc += $(OUTDIR)/doc/README.md
  outfiles-doc += $(OUTDIR)/doc/README-ja_JP.md
  outfiles-doc += $(OUTDIR)/doc/CONTRIBUTING.md
  outfiles-doc += $(OUTDIR)/doc/ChangeLog.md
  outfiles-doc += $(OUTDIR)/doc/Release.md
endif

# Workaround for make-3.81 (#D2065)
#
# We want to do something like the following:
#
#   $(OUTDIR)/license/%.md: %.md | $(OUTDIR)/license
#   	$(CP) $< $@
#   $(OUTDIR)/doc/%.md: %.md | $(OUTDIR)/doc
#   	$(CP) $< $@
#
# However, because of a bug in make-3.81, this rule overrides all the other
# more detailed patterns such as $(OUTDIR)/doc/contrib/%.md.  As a result, even
# when we want to apply preprocessing to specific file patterns under
# $(OUTDIR)/doc/%, $(CP) is always is used to install the files.  To work
# around this problem in make-3.81, we need to manually filter the target files
# whose source files are at the top level in the source tree.
#
outfiles-doc-toplevel := \
  $(filter $(outfiles-doc),$(patsubst %,$(OUTDIR)/doc/%,$(wildcard *.md)))
$(outfiles-doc-toplevel): $(OUTDIR)/doc/%.md: %.md | $(OUTDIR)/doc
	$(CP) $< $@
outfiles-license-toplevel := \
  $(filter $(outfiles-license),$(patsubst %,$(OUTDIR)/licenses/%,$(wildcard *.md)))
$(outfiles-license-toplevel): $(OUTDIR)/licenses/%.md: %.md | $(OUTDIR)/licenses
	$(CP) $< $@

$(OUTDIR)/doc/%: docs/% | $(OUTDIR)/doc
	$(CP) $< $@

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

build: contrib/contrib.mk $(outfiles) $(outfiles-doc) $(outfiles-license)
.PHONY: build

all: build

#------------------------------------------------------------------------------
# target "install"

# Users can specify make variables INSDIR, INSDIR_LICENSE, and INSDIR_DOC to
# control the install locations.  Instead of INSDIR, users may specify DESTDIR
# and/or PREFIX to automatically set up these variables.

ifneq ($(INSDIR),)
  INSDIR_LICENSE := $(INSDIR)/licenses
  INSDIR_DOC     := $(INSDIR)/doc
else
  ifneq ($(DESTDIR),)
    DATADIR := $(abspath $(DESTDIR)/$(PREFIX)/share)
  else ifneq ($(PREFIX),)
    DATADIR := $(abspath $(PREFIX)/share)
  else ifneq ($(XDG_DATA_HOME),)
    DATADIR := $(abspath $(XDG_DATA_HOME))
  else
    DATADIR := $(abspath $(HOME)/.local/share)
  endif

  INSDIR         := $(DATADIR)/blesh
  INSDIR_LICENSE := $(DATADIR)/blesh/licenses
  INSDIR_DOC     := $(DATADIR)/doc/blesh
endif

ifneq ($(strip_comment),)
  opt_strip_comment := --strip-comment=$(strip_comment)
else
  opt_strip_comment :=
endif

insfiles         := $(outfiles:$(OUTDIR)/%=$(INSDIR)/%)
insfiles-license := $(outfiles-license:$(OUTDIR)/licenses/%=$(INSDIR_LICENSE)/%)
insfiles-doc     := $(outfiles-doc:$(OUTDIR)/doc/%=$(INSDIR_DOC)/%)

install-files := \
  $(insfiles) $(insfiles-license) $(insfiles-doc) \
  $(INSDIR)/cache.d $(INSDIR)/run
install: $(install-files)
uninstall:
	bash make_command.sh uninstall $(install-files)
.PHONY: install uninstall

$(insfiles): $(INSDIR)/%: $(OUTDIR)/%
	bash make_command.sh install $(opt_strip_comment) "$<" "$@"
$(insfiles-license): $(INSDIR_LICENSE)/%: $(OUTDIR)/licenses/%
	bash make_command.sh install "$<" "$@"
$(insfiles-doc): $(INSDIR_DOC)/%: $(OUTDIR)/doc/%
	bash make_command.sh install "$<" "$@"
$(INSDIR)/cache.d $(INSDIR)/run:
	mkdir -p $@ && chmod a+rwxt $@

clean:
	-rm -rf $(outfiles) $(outfiles-doc) $(outfiles-license) $(OUTDIR)/ble.dep
.PHONY: clean

dist: $(outfiles) $(outfiles-doc) $(outfiles-license)
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
