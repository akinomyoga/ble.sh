#!/bin/bash

keywords=('[[' 'time' '!' 'if' 'while' 'until' 'for' 'select' 'case'
          '{' 'then' 'elif' 'else' 'do' '}' 'done' 'fi' 'esac'
          'coproc' 'function')
builtins=('declare' 'readonly' 'typeset' 'local' 'export' 'alias'
          'eval')

for word in "${keywords[@]}" "${builtins[@]}"; do
  if (eval "$word () { :; }" 2>/dev/null); then
    ok+=("$word")
  else
    ng+=("$word")
  fi
done

echo "Can we define a function using 'NAME() { ... }' form with the NAME being keywords/builtins?"
echo "yes: ${ok[*]}"
echo "no: ${ng[*]}"

# 結論: builtin はできる。keyword はできない。当たり前といえば当たり前の結果である。
