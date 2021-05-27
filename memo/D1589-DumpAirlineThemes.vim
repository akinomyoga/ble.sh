" -*- mode: vimrc -*-

function DumpAirlineTheme(name)
  execute "AirlineTheme " . a:name
  execute "let palette = g:airline#themes#" . a:name . "#palette"
  let lines = []
  for mode in keys(palette)
    for face in keys(palette[mode])
      let fg = palette[mode][face][0]
      let bg = palette[mode][face][1]
      let cfg = palette[mode][face][2]
      let cbg = palette[mode][face][3]
      " let style = palette[mode][face][4]
      call add(lines, 'face ' . mode . " " . face . " '" . fg . "' '" . bg . "' '" . cfg . "' '" . cbg . "'")
    endfor
  endfor
  call writefile(lines, "tmp/airline/" . a:name . ".bash")
endfunction

function DumpAirlineThemeAll()
  " vim-airline/vim-airline-themes
  let filelist = glob("~/.vim/plugged/vim-airline-themes/autoload/airline/themes/*.vim")
  for name in split(filelist, "\n")
    let name = fnamemodify(name, ":t:r")
    call DumpAirlineTheme(name)
  endfor

  " itchyny/landscape.vim
  call DumpAirlineTheme("landscape")
endfunction
