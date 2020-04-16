[Languages: **English** | [日本語](README-ja_JP.md) (Japanese) ]
# ble.sh

*Bash Line Editor* (`ble.sh`) is a command line editor written in pure Bash scripts which replaces the default GNU Readline.
- **Syntax highlighting**: Highlight command lines input by users as in `fish` and `zsh-syntax-highlighting`.
  Unlike the simple highlighting in `zsh-syntax-highlighting`, `ble.sh` performs syntactic analysis to enable the correct highlighting of complex structures such as nested command substitutions, multiple here documents, etc.
- **Enhanced completion**:
  Support syntax-aware completion, completion with quotes and parameter expansions in prefix texts, ambiguous candidate generation, etc.
  Also **menu-complete** supports selection of candidates in menu (candidate list) by cursor keys, <kbd>TAB</kbd> and <kbd>S-TAB</kbd>.
  The feature **auto-complete** supports the automatic suggestion of completed texts as in `fish` and `zsh-autosuggestions` (with Bash 4.0+).
  The feature **menu-filter** integrates automatic filtering of candidates into menu completion (with Bash 4.0+).
  There are other functionalities such as **dabbrev** and **sabbrev** like `zsh-abbreviations`.
- **Vim editing mode**: Enhance `readline`'s vi editing mode available with `set -o vi`.
  Vim editing mode supports various vim modes such as char/line/block visual/select mode, replace mode, command mode, operator pending mode as well as insert mode and normal mode.
  Vim editing mode supports various operators, text objects, registers, keyboard macros, marks, etc.
  It also provides `vim-surround` as an option.

This script supports Bash 3.0 or later although we recommend to use `ble.sh` with Bash 4.0 or later.

Currently, only `UTF-8` encoding is supported for non-ASCII characters.

This script is provided under the [**BSD License**](LICENSE.md) (3-clause BSD license).

> Demo
>
> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/trial1.gif)

Note: ble.sh does not provide a specific settings for the prompt, aliases, functions, etc.
ble.sh provides a more fundamental infrastructure so that users can set up their own settings for prompts, aliases, etc.
Of course ble.sh can be used in combination with other Bash configurations such as `bash-it` and `oh-my-bash`.

# 1 Usage

## Generate `ble.sh` from source (version ble-0.4 devel)

To generate `ble.sh`, `gawk` (GNU awk) and `gmake` (GNU make) is required.
The file `ble.sh` can be generated using the following commands.
If you have GNU make installed on `gmake`, please use `gmake` instead of `make`.
```console
$ git clone --recursive https://github.com/akinomyoga/ble.sh.git
$ cd ble.sh
$ make
```
A script file `ble.sh` will be generated in the directory `ble.sh/out`. Then, load `ble.sh` using the `source` command:
```console
$ source out/ble.sh
```
If you want to install `ble.sh` in a specified directory, use the following command (if `INSDIR` is not specified, the default location `${XDG_DATA_HOME:-$HOME/.local/share}/blesh` is used):
```console
$ make INSDIR=/path/to/blesh install
```

## Or, download `ble.sh` (version ble-0.3 201902)

With `wget`:
```console
$ wget https://github.com/akinomyoga/ble.sh/releases/download/v0.3.2/ble-0.3.2.tar.xz
$ tar xJf ble-0.3.2.tar.xz
$ source ble-0.3.2/ble.sh
```
With `curl`:
```console
$ curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.3.2/ble-0.3.2.tar.xz
$ tar xJf ble-0.3.2.tar.xz
$ source ble-0.3.2/ble.sh
```

If you want to place `ble.sh` in a specific directory, just copy the directory:
```console
$ cp -r ble-0.3.2 /path/to/blesh
```

## Setup `.bashrc`

If you want to load `ble.sh` by default in interactive sessions of `bash`, add the following codes to your `.bashrc` file:
```bash
# bashrc

# Add this lines at the top of .bashrc:
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# your bashrc settings come here...

# Add this line at the end of .bashrc:
((_ble_bash)) && ble-attach
```

## Update

You need Git (`git`), GNU awk (`gawk`) and GNU make (`make`).
For `ble-0.3+`, run `ble-update` in the session with `ble.sh` loaded:

```bash
$ ble-update
```

You can instead download the latest version by `git pull` and install it:

```bash
cd ble.sh   # <-- enter the git repository you already have
git pull
git submodule update --recursive --remote
make
make INSDIR="$HOME/.local/share/blesh" install
```

## User settings `~/.blerc`

User settings can be placed in the init script `~/.blerc` (or `~/.config/blesh/init.sh` if `~/.blerc` is not available)
whose template is available as the file [`blerc`](https://github.com/akinomyoga/ble.sh/blob/master/blerc) in the repository.
The init script is a Bash script which will be sourced during the load of `ble.sh`, so any shell commands can be used in `~/.blerc`.
If you want to change the default path of the init script, you can add the option `--rcfile INITFILE` to `source ble.sh` as the following example:

```bash
# in bashrc

# Example 1: ~/.blerc will be used by default
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# Example 2: /path/to/your/blerc will be used
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach --rcfile /path/to/your/blerc
```

# 2 Basic settings

Here some of the settings for `~/.blerc` are picked up.
For more settings please check the template [`blerc`](https://github.com/akinomyoga/ble.sh/blob/master/blerc).
For detailed explanations please refer to [Manual](https://github.com/akinomyoga/ble.sh/wiki).

## Vim mode

For the vi/vim mode, check [the Wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## Configure `auto-complete`

The feature `auto-complete` is available for Bash 4.0+ and enabled by default.
If you want to turn off `auto-complete`, please put the following line in your `~/.blerc`.

```bash
bleopt complete_auto_complete=
```

Instead of completely turning off `auto-complete`, you can set a delay for `auto-complete`.

```bash
# Set the delay of the auto-complete to 300 milliseconds
bleopt complete_auto_delay=300
```

`auto-complete` candidates based on the bash command history can be turned off by the following line.

```bash
bleopt complete_auto_history=
```

## CJK Width

The option `char_width_mode` controls the width of the Unicode characters with `East_Asian_Width=A` (Ambiguous characters).
Currently four values `emacs`, `west`, `east`, and `auto` are supported. With the value `emacs`, the default width in emacs is used.
With `west` all the ambiguous characters have width 1 (Hankaku). With `east` all the ambiguous characters have width 2 (Zenkaku).
With `auto` the width mode `west` or `east` is automatically chosen based on the terminal behavior.
The default value is `auto`. Appropriate value should be chosen in accordance with your terminal behavior.
For example, the value can be changed to `west` as:

```bash
bleopt char_width_mode='west'
```

## Input Encoding

The option `input_encoding` controls the encoding scheme used in the decode of input. Currently `UTF-8` and `C` are available. With the value `C`, byte values are directly interpreted as character codes. The default value is `UTF-8`. For example, the value can be changed to `C` as:

```bash
bleopt input_encoding='C'
```

## Bell

The options `edit_abell` and `edit_vbell` control the behavior of the edit function `bell`. If `edit_abell` is a non-empty string, audible bell is enabled, i.e. ASCII Control Character `BEL` (0x07) will be written to `stderr`. If `edit_vbell` is a non-empty string, visual bell is enabled. By default, the audible bell is enabled while the visual bell is disabled.

The option `vbell_default_message` specifies the message shown as the visual bell. The default value is `' Wuff, -- Wuff!! '`. The option `vbell_duration` specifies the display duration of the visual-bell message. The unit is millisecond. The default value is `2000`.

For example, the visual bell can be enabled as:
```
bleopt edit_vbell=1 vbell_default_message=' BEL ' vbell_duration=3000
```

For another instance, the audible bell is disabled as:
```
bleopt edit_abell=
```

## Highlight Colors

The colors and attributes used in the syntax highlighting are controlled by `ble-color-setface` function. The following code reproduces the default configuration:
```bash
# highlighting related to editing
ble-color-setface region                    bg=60,fg=white
ble-color-setface region_target             bg=153,fg=black
ble-color-setface region_match              bg=55,fg=white
ble-color-setface region_insert             fg=12,bg=252
ble-color-setface disabled                  fg=242
ble-color-setface overwrite_mode            fg=black,bg=51
ble-color-setface auto_complete             fg=238,bg=254
ble-color-setface menu_filter_fixed         bold
ble-color-setface menu_filter_input         fg=16,bg=229
ble-color-setface vbell                     reverse
ble-color-setface vbell_erase               bg=252
ble-color-setface vbell_flash               fg=green,reverse

# syntax highlighting
ble-color-setface syntax_default            none
ble-color-setface syntax_command            fg=brown
ble-color-setface syntax_quoted             fg=green
ble-color-setface syntax_quotation          fg=green,bold
ble-color-setface syntax_expr               fg=26
ble-color-setface syntax_error              bg=203,fg=231
ble-color-setface syntax_varname            fg=202
ble-color-setface syntax_delimiter          bold
ble-color-setface syntax_param_expansion    fg=purple
ble-color-setface syntax_history_expansion  bg=94,fg=231
ble-color-setface syntax_function_name      fg=92,bold
ble-color-setface syntax_comment            fg=242
ble-color-setface syntax_glob               fg=198,bold
ble-color-setface syntax_brace              fg=37,bold
ble-color-setface syntax_tilde              fg=navy,bold
ble-color-setface syntax_document           fg=94
ble-color-setface syntax_document_begin     fg=94,bold
ble-color-setface command_builtin_dot       fg=red,bold
ble-color-setface command_builtin           fg=red
ble-color-setface command_alias             fg=teal
ble-color-setface command_function          fg=92
ble-color-setface command_file              fg=green
ble-color-setface command_keyword           fg=blue
ble-color-setface command_jobs              fg=red
ble-color-setface command_directory         fg=26,underline
ble-color-setface filename_directory        underline,fg=26
ble-color-setface filename_directory_sticky underline,fg=white,bg=26
ble-color-setface filename_link             underline,fg=teal
ble-color-setface filename_orphan           underline,fg=teal,bg=224
ble-color-setface filename_executable       underline,fg=green
ble-color-setface filename_setuid           underline,fg=black,bg=220
ble-color-setface filename_setgid           underline,fg=black,bg=191
ble-color-setface filename_other            underline
ble-color-setface filename_socket           underline,fg=cyan,bg=black
ble-color-setface filename_pipe             underline,fg=lime,bg=black
ble-color-setface filename_character        underline,fg=white,bg=black
ble-color-setface filename_block            underline,fg=yellow,bg=black
ble-color-setface filename_warning          underline,fg=red
ble-color-setface filename_url              underline,fg=blue
ble-color-setface filename_ls_colors        underline
ble-color-setface varname_array             fg=orange,bold
ble-color-setface varname_empty             fg=31
ble-color-setface varname_export            fg=200,bold
ble-color-setface varname_expr              fg=92,bold
ble-color-setface varname_hash              fg=70,bold
ble-color-setface varname_number            fg=64
ble-color-setface varname_readonly          fg=200
ble-color-setface varname_transform         fg=29,bold
ble-color-setface varname_unset             fg=124
```

The current list of faces can be obtained by the following command (`ble-color-setface` without arguments):
```console
$ ble-color-setface
```

The color codes can be checked in output of the function `ble-color-show` (defined in `ble.sh`):
```console
$ ble-color-show
```

## Key Bindings

Key bindings can be controlled with the shell function, `ble-bind`.
For example, with the following setting, "Hello, world!" will be inserted on typing <kbd>C-x h</kbd>
```bash
ble-bind -f 'C-x h' 'insert-string "Hello, world!"'
```

For another example, if you want to invoke a command on typing <kbd>M-c</kbd>, you can write as follows:

```bash
ble-bind -c 'M-c' 'my-command'
```

Or, if you want to invoke a edit function (designed for Bash `bind -x`) on typing <kbd>C-r</kbd>, you can write as follows:

```bash
ble-bind -x 'C-r' 'my-edit-function'
```

The existing key bindings are shown by the following command:
```console
$ ble-bind -P
```

The list of widgets is shown by the following command:
```console
$ ble-bind -L
```

# 3 Tips

## Use multiline mode

When the command line string contains a newline character, `ble.sh` enters the MULTILINE mode.

By typing <kbd>C-v RET</kbd> or <kbd>C-q RET</kbd>, you can insert a newline character in the command line string.
In the MULTILINE mode, <kbd>RET</kbd> (<kbd>C-m</kbd>) causes insertion of a new newline character.
In the MULTILINE mode, the command can be executed by typing <kbd>C-j</kbd>.

When the shell option `shopt -s cmdhist` is set (which is the default),
<kbd>RET</kbd> (<kbd>C-m</kbd>) inserts a newline if the current command line string is syntactically incomplete.

## Use vim editing mode

If `set -o vi` is specified in `.bashrc` or `set editing-mode vi` is specified in `.inputrc`, the vim mode is enabled.
For details, please check the [Wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## Use `auto-complete`

The feature `auto-complete` is available in Bash 4.0 or later. `auto-complete` automatically suggests a possible completion on user input.
The suggested contents can be inserted by typing <kbd>S-RET</kbd>
(when the cursor is at the end of the command line, you can also use <kbd>right</kbd>, <kbd>C-f</kbd> or <kbd>end</kbd> to insert the suggestion).
If you want to insert only first word of the suggested contents, you can use <kbd>M-right</kbd> or <kbd>M-f</kbd>.
If you want to accept the suggestion and immediately run the command, you can use <kbd>C-RET</kbd> (if your terminal supports this special key combination).

## Use `sabbrev` (static abbrev expansions)

By registering words to `sabbrev`, the words can be expanded to predefined strings.
When the cursor is just after a registered word, typing <kbd>SP</kbd> causes `sabbrev` expansion.
For example, with the following settings, when you type <kbd>SP</kbd> after the command line `command L`, the command line will be expanded to `command | less`.

```bash
# blerc
ble-sabbrev L='| less'
```

# 4 Special thanks

- @cmplstofB for testing vim-mode and giving me a lot of suggestions
