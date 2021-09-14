# -*- mode: makefile-gmake -*-

all:
.PHONY: all

all: canvas.c2w.wcwidth.exe
canvas.c2w.wcwidth.exe: canvas.c2w.wcwidth.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
