#!/bin/bash

shopt -s checkwinsize

function trapwinch {
  local size=${COLUMNS}x${LINES}
  echo "WINCH-START ($size)"
  for i in {0..100}; do
    sleep 0.01
    local new_size=${COLUMNS}x${LINES}
    if [[ $new_size != "$size" ]]; then
      echo "SIZE CHANGED i=$i ($size)"
      size=$new_size
    fi
  done
  echo WINCH-END
}

trap trapwinch WINCH
