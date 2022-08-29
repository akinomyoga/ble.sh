#!/bin/bash

function ble/util/msleep/.load-compiled-builtin/compile {
  local builtin_path=$1
  [[ -x $builtin_path && -s $builtin_path && $builtin_path -nt $_ble_base/lib/init-msleep.sh ]] && return 0

  local CC=cc
  ble/bin#has gcc && CC=gcc

  local include='#include' # '#' で始まる行はインストール時に消される
  "$CC" -O2 -s -shared -o "$builtin_path" -xc - << EOF || return 1
#%$ sed 's/^#include/$include/' lib/init-msleep.c
EOF
  [[ -x $builtin_path ]]
} &>/dev/null

function ble/util/msleep/.load-compiled-builtin {
  local basename=$_ble_edit_io_fname2
  local fname_buff=$basename.buff

  local builtin_path=$_ble_base_cache/init-msleep.$_ble_bash.$HOSTNAME.so
  local builtin_runpath=$_ble_base_run/$$.init-msleep.so
  ble/util/msleep/.load-compiled-builtin/compile "$builtin_path" &&
    ble/bin/cp "$builtin_path" "$builtin_runpath" || return 1

  enable -f "$builtin_runpath" msleep || return 1
  blehook unload!='enable -d ble/builtin/msleep &>/dev/null'
}
