# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-test

ble/test/start-section 'main' 16

# ble/util/{put,print}
(
  ble/test ble/util/put a     stdout=a
  ble/test ble/util/print a   stdout=a
  ble/test 'ble/util/put "a b"'   stdout='a b'
  ble/test 'ble/util/print "a b"' stdout='a b'
  ble/test 'ble/util/put "a b"; ble/util/put "c d"' \
           stdout='a bc d'
  ble/test 'ble/util/print "a b"; ble/util/print "c d"' \
           stdout='a b' \
           stdout='c d'
)

# ble/bin#has
(
  function ble/test/dummy-1 { true; }
  function ble/test/dummy-2 { true; }
  function ble/test/dummy-3 { true; }
  ble/test ble/bin#has ble/test/dummy-1
  ble/test ble/bin#has ble/test/dummy-{1..3}
  ble/test ble/bin#has ble/test/dummy-0 exit=1
  ble/test ble/bin#has ble/test/dummy-{0..2} exit=1
)

# ble/util/readlink
(
  ble/test/chdir

  mkdir -p ab/cd/ef
  touch ab/cd/ef/file.txt
  ln -s ef/file.txt ab/cd/link1
  ln -s ab link.d
  ln -s link.d/cd/link1 f.txt
  ble/test '
    ble/util/readlink f.txt
    [[ $ret != /* ]] && ret=${PWD%/}/$ret' \
    ret="${PWD%/}/ab/cd/ef/file.txt"

  ble/test/rmdir
)

# ble/base/create-*-directory
(
  ble/test '[[ -d $_ble_base ]]'
  ble/test '[[ -d $_ble_base_run ]]'
  ble/test '[[ -d $_ble_base_cache ]]'
)

(
  qnl="\$'\n'"
  value=$'\nxxx is a function\nhello\nyyy is a function\n'
  pattern=$'\n+([][{}:[:alnum:]]) is a function\n'
  shopt -s extglob
  ble/test '[[ ${value//$pattern/'"$qnl"'} == '"$qnl"'hello'"$qnl"' ]]'
  shopt -u extglob
  ble/test '[[ ${value//$pattern/'"$qnl"'} != '"$qnl"'hello'"$qnl"' ]]'
)

# ble-reload
# ble-update
# ble-attach
# ble-detach

ble/test/end-section
