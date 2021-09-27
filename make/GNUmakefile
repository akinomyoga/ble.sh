# -*- mode: makefile-gmake -*-

all:
.PHONY: all

all: canvas.c2w.wcwidth.exe
canvas.c2w.wcwidth.exe: canvas.c2w.wcwidth.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

all: canvas.c2w.wcwidth-musl.exe
canvas.c2w.wcwidth-musl.exe: canvas.c2w.wcwidth-musl.c
	$(CC) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
