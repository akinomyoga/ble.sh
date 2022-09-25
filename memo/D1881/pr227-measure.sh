#!/usr/bin/env bash

if [[ ${EPOCHREALTIME-} ]]; then
  measure() {
    local beg=$EPOCHREALTIME
    eval "$1"
    local end=$EPOCHREALTIME
    echo "$(bc -l <<< "$end-$beg") $2"
  }
  
else
  cc -o epoch.tmp -x c - <<EOF
#include <sys/time.h>
#include <stdio.h>
int main() {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  printf("%ld.%06u\n", tv.tv_sec, tv.tv_usec);
}
EOF

  chmod +x epoch.tmp
  measure() {
    local beg=$(./epoch.tmp)
    eval "$1"
    local end=$(./epoch.tmp)
    echo "$(bc -l <<< "$end-$beg") $2"
  }

  trap 'rm -f epoch.tmp' EXIT
  trap 'rm -f epoch.tmp; trap - INT; kill -INT $$' INT
fi

{
  echo "# $BASH_VERSION ($MACHTYPE)"
  for i in {0..100}; do
    measure ":"
  done
  for i in {0..100}; do
    measure "sleep 0.001" 0.001
  done
  for i in {2..300}; do
    printf -v v '0.%03d' "$i"
    measure "sleep $v" "$v"
  done
}
