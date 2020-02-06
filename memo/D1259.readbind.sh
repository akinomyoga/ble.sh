# -*- mode: sh; mode: sh-bash -*-

q=\'
{
  for map in vi-insert vi-command emacs; do
    echo __CLEAR__
    echo KEYMAP="$map"
    echo __BIND0__
    "$BASH" --norc -i -c "bind -m $map -p" | sed '/^#/d;s/"\\M-/"\\e/'
    echo __BINDX__
    builtin bind -m "$map" -X
    echo __BINDS__
    builtin bind -m "$map" -s
    echo __BINDP__
    builtin bind -m "$map" -p
    echo __PRINT__
  done
} | LC_ALL= LC_CTYPE=C awk -v q="$q" '
  function keymap_register(key, val, type) {
    if (!haskey[key]) {
      keys[nkey++] = key;
      haskey[key] = 1;
    }
    keymap[key] = val;
    keymap_type[key] = type;
  }
  function keymap_clear(_, i, key) {
    for(i = 0; i < nkey; i++) {
      key = keys[i];
      delete keymap[key];
      delete keymap_type[key];
      delete keymap0[key];
      haskey[key] = 0;
    }
    nkey = 0;
  }
  function keymap_print(_, i, key, type, value, text, line) {
    for (i = 0; i < nkey; i++) {
      key = keys[i];
      type = keymap_type[key];
      value = keymap[key];
      if (type == "" && value == keymap0[key]) continue;

      text = key ": " value;
      gsub(/'$q'/, q "\\" q q, text);

      line = "bind";
      if (KEYMAP != "") line = line " -m " KEYMAP;
      if (type == "x") line = line " -x";
      line = line " " q text q;
      print line;
    }
  }

  /^__BIND0__$/ { mode = 0; next; }
  /^__BINDX__$/ { mode = 1; next; }
  /^__BINDS__$/ { mode = 2; next; }
  /^__BINDP__$/ { mode = 3; next; }
  /^__CLEAR__$/ { keymap_clear(); next; }
  /^__PRINT__$/ { keymap_print(); next; }
  sub(/^KEYMAP=/, "") { KEYMAP = $0; }

  /ble-decode\/.hook / { next; }

  match($0, /^"(\\.|[^"])+": /) {
    key = substr($0, 1, RLENGTH - 2);
    val = substr($0, 1 + RLENGTH);
    gsub(/\\M-/, "\\e", key);
    if (mode) {
      type = mode == 1 ? "x" : mode == 2 ? "s" : "";
      keymap_register(key, val, type);
    } else {
      keymap0[key] = val;
    }
  }
'
