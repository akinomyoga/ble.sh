#!/bin/bash

function list-functions {
  git cat-file -p "$1" |
    sed -nE 's/^[[:blank:]]*function ([^[:blank:]]*)[[:blank:]]*\{?/\1/p' | uniq
}

list-functions 1410c72b:src/util.sh > a.tmp
list-functions @:src/util.sh > b.tmp
colored diff -bwu a.tmp b.tmp
rm a.tmp b.tmp
