#!/bin/bash

# 文法案1 (mwg_pp): 結局インデントできない

#%x TEST.r/%title%/hello world/
true
#%x EXPECT
#%x END
#%x EXPECT 0 BUG bash-3.1
#%x END

# 文法案2 (alias/heredoc): インデントできないし、境界が見にくい

ble/test 'hello world'
%TEST
true
%END
%EXPECT
aaaa
%END
%EXPECT 0 BUG bash-3.1
aaaa
%END

# 文法案3 (comment)
#   awk で適当に処理すれば良い。

#@TEST hello world
true
#@EXPECT
aaaa
#@EXPECT 0 BUG bash-3.1
aaaa
#@END
