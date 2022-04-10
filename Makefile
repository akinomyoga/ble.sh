# -*- mode: makefile-bsdmake -*-

all:
.PHONY: all install

.warning [1;31mThis is not GNU make. Plaese use GNU make (gmake).[m
.warning [1mTrying to redirect to gmake...[m

.ifdef INSDIR
assign_insdir := INSDIR="$(INSDIR)"
.endif

.ifdef INSDIR_DOC
assign_insdir_doc := INSDIR_DOC="$(INSDIR_DOC)"
.endif

.ifdef PREFIX
assign_prefix := PREFIX="$(PREFIX)"
.endif

.ifdef DESTDIR
assign_destdir := DESTDIR="$(DESTDIR)"
.endif

all:
	gmake -f GNUmakefile all
install:
	gmake -f GNUmakefile install $(assign_insdir) $(assign_insdir_doc) $(assign_prefix) $(assign_destdir)

