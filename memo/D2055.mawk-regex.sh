#!/usr/bin/env bash

test-mawk-version() {
  local v=$1
  local r=$(echo yes | ~/opt/mawk/"$v"/bin/mawk '/^('\''[^'\'']*'\''|\$'\''([^\\'\'']|\\.)*'\''|\$?"([^\\"]|\\.)*"|\\.|[^[:space:]"'\''`;&|()])*/')
  echo "$v: ${r:-no}"
}

test-mawk-version 1.3.3-20080909
test-mawk-version 1.3.3-20090705
test-mawk-version 1.3.3-20090710
test-mawk-version 1.3.3-20090721
test-mawk-version 1.3.4-20100419
test-mawk-version 1.3.4-20101210
test-mawk-version 1.3.4-20230404

function test-regex-matching {
  local mawk=$1
  echo "==============================================================================="
  echo "mawk-path = $mawk"
  echo

  # echo yes | "$mawk" '/'\''[^'\'']*'\''|\$'\''([^\\'\'']|\\.)*'\''|\$?"([^\\"]|\\.)*"|\\.|[^[:space:]"'\''`;&|()]/'
  # echo yes | "$mawk" '/\$'\''([^\\'\'']|\\.)*'\''|\$?"([^\\"]|\\.)*"|\\.|[^[:space:]"'\''`;&|()]/'
  # echo yes | "$mawk" '/\$?"([^\\"]|\\.)*"|\\.|[^[:space:]"'\''`;&|()]/'
  # echo yes | "$mawk" '/\\.|[^[:space:]"'\''`;&|()]/'
  # echo yes | "$mawk" '/[^[:space:]"'\''`;&|()]/'
  # echo yes | "$mawk" '/[^[:space:]()]/'
  echo yes | "$mawk" '{if (/[[:space:]()]/) print "no"; else print "yes";}'           # 文法エラー
  echo '(' | "$mawk" '{if (/[()[:space:]]/) print "yes"; else print "no";}'           # 駄目
  echo '(' | "$mawk" '{if (/[()]/) print "yes"; else print "no";}'                    # OK
  echo ' ' | "$mawk" '{if (/[[:space:]]/) print "yes"; else print "no";}'             # 駄目
  echo ' ' | "$mawk" '{if (/[ 	]/) print "yes"; else print "no";}'                   # OK
  echo 'a b c' | "$mawk" '{gsub(/[[:space:]]/, ""); print "[" $0 "] expect:[abc]";}'  # 駄目
  echo 'a b c' | "$mawk" '{gsub(/[^[:space:]]/, ""); print "[" $0 "] expect:[  ]";}'  # 駄目
  echo 'a b c' | "$mawk" '{gsub(/[[:alpha:]]/, ""); print "[" $0 "] expect:[  ]";}'   # 駄目
  echo 'a b c' | "$mawk" '{gsub(/[^[:alpha:]]/, ""); print "[" $0 "] expect:[abc]";}' # 駄目
  echo 'a b c' | "$mawk" '{gsub(/[[=a=]]/, ""); print "[" $0 "] expect:[ b c]";}'     # 駄目
}

#test-regex-matching ~/opt/mawk/1.3.3-20080909/bin/mawk
test-regex-matching ~/opt/mawk/1.3.3-20090705/bin/mawk
test-regex-matching ~/opt/mawk/1.3.3-20090710/bin/mawk
