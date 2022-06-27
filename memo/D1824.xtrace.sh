#!/usr/bin/env bash

set -x

# PS4 の indirection level + は関数呼び出しで増えるのか?
# →増えない。純粋に eval などの数を数える物と考えるべきか。
PS4='+${#BASH_LINENO[@]} '
function f1 { echo "${FUNCNAME[*]}"; }
function f2 { echo "${FUNCNAME[*]}"; f1; }
function f3 { echo "${FUNCNAME[*]}"; f2; }
f3
