#!/usr/bin/env bash

contexts=('echo $((%s))' 'echo $[%s]' '((%s))' 'b[%s]=' ': ${b[%s]}' 'b=([%s]=)' ': ${v:%s}' ': "${v:%s}"')
quote_types=('\10' "'10'" "\$'10'" '"10"' '$"10"' 'a[\10]' 'a["10"]' '`echo 10`')

function test-quote-error {
  local cmd
  printf -v cmd "$1" "$2"
  [[ ! $(eval "$cmd" 2>&1 1>/dev/null) ]]
}

function sub:test-compact {
  local v=1

  local t q cmd vec
  for t in "${contexts[@]}"; do
    vec=
    for q in "${quote_types[@]}"; do
      if test-quote-error "$t" "$q"; then
        vec+=o
      else
        vec+=x
      fi
    done
    printf -v cmd "$t" expr
    printf "%-20s: %s\n" "$cmd" "$vec"
  done
}

function sub:summarize-compact {
  printf '%-20s: 4.3     4.4     5.1     5.2     dev\n'
  paste \
    -d ' ' \
    <(bash-4.3 "$0" test-compact) \
    <(bash-4.4 "$0" test-compact | sed 's/.* \([ox]\{1,\}\)$/\1/') \
    <(bash-5.1 "$0" test-compact | sed 's/.* \([ox]\{1,\}\)$/\1/') \
    <(bash-5.2 "$0" test-compact | sed 's/.* \([ox]\{1,\}\)$/\1/') \
    <(bash-dev "$0" test-compact | sed 's/.* \([ox]\{1,\}\)$/\1/')
}

function sub:perform-test {
  local v=1

  local t q cmd vec
  for t in "${contexts[@]}"; do
    for q in "${quote_types[@]}"; do
      printf -v cmd "$t" "$q"
      if test-quote-error "$t" "$q"; then
        vec=o
      else
        vec=x
      fi
      printf "%-20s: %s\n" "$cmd" "$vec"
    done
  done
}

function main {
  printf '%-20s: 4.3 4.4 5.1 5.2 dev\n' COMMAND
  paste \
    -d ' ' \
    <(bash-4.3 "$0" perform-test | sed 's/.$/ & /') \
    <(bash-4.4 "$0" perform-test | sed 's/.*\([ox]\)$/ \1 /') \
    <(bash-5.1 "$0" perform-test | sed 's/.*\([ox]\)$/ \1 /') \
    <(bash-5.2 "$0" perform-test | sed 's/.*\([ox]\)$/ \1 /') \
    <(bash-dev "$0" perform-test | sed 's/.*\([ox]\)$/ \1/')
}

function sub:test-markdown {
  local v=1

  local t q cmd vec
  for t in "${contexts[@]}"; do
    for q in "${quote_types[@]}"; do
      printf -v cmd "$t" "$q"
      if test-quote-error "$t" "$q"; then
        vec='&#x2705;'
      else
        vec='&#x2B1C;'
      fi
      printf "| %-20s | %s\n" "<code>$cmd</code>" "$vec"
    done
  done
}
function sub:summarize-markdown {
  printf '| COMMAND | 3.0..4.3 | 4.4..5.0 | 5.1 | 5.2..dev |\n'
  printf '|:----------------------|:--------:|:--------:|:--------:|:--------:|\n'
  paste \
    -d '|' \
    <(bash-4.3 "$0" test-markdown) \
    <(bash-4.4 "$0" test-markdown | sed 's/.* \([^[:space:]]\{1,\}\)$/ \1 /') \
    <(bash-5.1 "$0" test-markdown | sed 's/.* \([^[:space:]]\{1,\}\)$/ \1 /') \
    <(bash-5.2 "$0" test-markdown | sed 's/.* \([^[:space:]]\{1,\}\)$/ \1 |/')
}

if declare -f "sub:$1" >/dev/null; then
  "sub:$@"
else
  main
fi
