" Tests for statusline mode-strings

"set noshowmode " This hides the normal mode line
set laststatus=2 " Enables the statusline

" Names for each mode (used for the statusbar)
let g:currentmode={
       \ 'n'  : '-- NORMAL --',
       \ 'v'  : '-- VISUAL --',
       \ 'V'  : '-- V-LINE --',
       \ '' : '-- V-BLOQ --',
       \ 'i'  : '-- INSERT --',
       \ 'ic' : '-- INSERT --',
       \ 'ix' : '-- INSERT --',
       \ 'R'  : '-- RPLACE --',
       \ 'Rv' : '-- VPLACE --',
       \ 'c'  : '-- PROMPT --',
       \ '!'  : '-- !SHELL --',
       \ 't'  : '-- TSHELL --',
       \ 'r'  : '-- PROMPT --',
       \ 'r?' : '-- ACCEPT --',
       \}

" Sets the statusline
set statusline=%{mode()}
"%{g:currentmode[mode()]}

" And unless you wanna go insane when going between modes I recommend this
set ttimeoutlen=0 " Which eliminates the annoying delay when switching modes (This is only for normal Vim)
