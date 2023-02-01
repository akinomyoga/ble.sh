# -*- mode: makefile-gmake -*-

all:
.PHONY: all

all: canvas.c2w.wcwidth.exe
canvas.c2w.wcwidth.exe: canvas.c2w.wcwidth.o canvas.c2w.wcwidth-musl.o canvas.c2w.wcwidth-konsole-u15.o
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $^
