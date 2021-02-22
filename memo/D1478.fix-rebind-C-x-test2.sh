#!/bin/bash

# unbind all "C-x ?"
for second in e g {A..Z} '\C-'{e,g,r,u,v,x,'?'} '!' '$' '(' ')' '*' '/' '@' '~'; do
  bind -r '\C-x'"$second"
done

# bash-4.2 以下で以下の様にすると vi で C-x を受信できなくなってしまう。
bind -x '"\C-x\C-x":echo XX'
bind -r '\C-x\C-x'
set -o vi
bind -x '"\C-x":echo X'
