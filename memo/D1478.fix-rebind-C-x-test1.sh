#!/bin/bash

# unbind all "C-x ?"
for second in e g {A..Z} '\C-'{e,g,r,u,v,x,'?'} '!' '$' '(' ')' '*' '/' '@' '~'; do
  bind -r '\C-x'"$second"
done

bind -x '"\C-x\C-x":echo XX'
bind -r '\C-x\C-x'

bind -x '"\C-x":echo X'
bind -x '"\C-b":echo B'
