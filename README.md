[ Languages: **English** | [日本語](README-ja_JP.md) (Japanese) ]

<h1 align="center"><ruby>ble.sh<rp> (</rp><rt>/blɛʃ/</rt><rp>)</rp></ruby> ―Bash Line Editor―</h1>
<p align="center">
[ <b>README</b> | <a href="https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A71-Introduction">Manual</a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/Q&A">Q&A</a> |
<a href="https://github.com/akinomyoga/blesh-contrib"><code>contrib</code></a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/Recipes">Recipes</a> ]
</p>

*Bash Line Editor* (`ble.sh`) is a command line editor written in pure Bash which replaces the default GNU Readline.

Current devel version is 0.4.
This script supports Bash 3.0 or higher although we recommend to use `ble.sh` with release versions of Bash 4.0 or higher.
Currently, only `UTF-8` encoding is supported for non-ASCII characters.
This script is provided under the [**BSD License**](LICENSE.md) (3-clause BSD license).

Disclaimer: The core part of the line editor is written in **pure Bash**, but
`ble.sh` relies on POSIX `stty` to set up TTY states before and after the execution of user commands.
It also uses other POSIX utilities for acceleration
in some part of initialization and cleanup code,
processing of large data in completions, paste of large data, etc.

Pronunciation: The easiest pronunciation of `ble.sh` that users use is /blɛʃ/, but you can actually pronounce it as you like.
I do not specify the canonical way of pronoucing `ble.sh`.
In fact, I personally read it verbosely as /biːɛliː dɑt ɛseɪtʃ/ in my head.

## Quick instructions

Installation requires the commands `git`, `make` (GNU make), and `gawk` (in addition to `bash` and POSIX standard utilities).
For detailed descriptions, see [Sec 1.1](#get-from-source) and [Sec 1.2](#get-from-tarball) for trial/installation,
[Sec 1.3](#set-up-bashrc) for the setup of your `~/.bashrc`.

```bash
# TRIAL without installation

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh
source ble.sh/out/ble.sh

# Quick INSTALL to BASHRC (If this doesn't work, please follow Sec 1.3)

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install PREFIX=~/.local
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc

# UPDATE (in a ble.sh session)

ble-update

# UPDATE (outside ble.sh sessions)

bash /path/to/ble.sh --update

# PACKAGE (for package maintainers)

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

You may also install `ble.sh` through package-management systems (currently only AUR):

- [AUR (Arch Linux)](https://github.com/akinomyoga/ble.sh/wiki/Manual-A1-Installation#user-content-AUR) `blesh-git` (devel), `blesh` (stable 0.3.3) maintained by [`@capezotte`](https://github.com/capezotte)

## Features

- **Syntax highlighting**: Highlight command lines input by users as in `fish` and `zsh-syntax-highlighting`.
  Unlike the simple highlighting in `zsh-syntax-highlighting`, `ble.sh` performs syntactic analysis
  to enable the correct highlighting of complex structures such as nested command substitutions, multiple here documents, etc.
  Highlighting colors and styles are [fully configurable](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A72-Graphics).
- **Enhanced completion**:
  Extend [completion](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion)
  by **syntax-aware completion**, completion with quotes and parameter expansions in prefix texts, **ambiguous candidate generation**, etc.
  Also, [**menu-complete**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion#user-content-sec-menu-complete)
  supports selection of candidates in menu (candidate list) by cursor keys, <kbd>TAB</kbd> and <kbd>S-TAB</kbd>.
  The feature [**auto-complete**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion#user-content-sec-auto-complete)
  supports the automatic suggestion of completed texts as in `fish` and `zsh-autosuggestions` (with Bash 4.0+).
  The feature [**menu-filter**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion#user-content-sec-menu-filter)
  integrates automatic filtering of candidates into menu completion (with Bash 4.0+).
  There are other functionalities such as
  [**dabbrev**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion#user-content-sec-dabbrev) and
  [**sabbrev**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion#user-content-sec-sabbrev) like
  [*zsh abbreviations*](https://unix.stackexchange.com/questions/6152/zsh-alias-expansion) or [`zsh-abbr`](https://github.com/olets/zsh-abbr).
- **Vim editing mode**: Enhance `readline`'s vi editing mode available with `set -o vi`.
  Vim editing mode supports various vim modes such as char/line/block visual/select mode, replace mode,
  command mode, operator pending mode as well as insert mode and normal mode.
  Vim editing mode supports various operators, text objects, registers, keyboard macros, marks, etc.
  It also provides `vim-surround` as an option.
- Other interesting features include
  [**status line**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A74-Editing#user-content-bleopt-prompt_status_line),
  [**history share**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A74-Editing#user-content-bleopt-history_share),
  [**right prompt**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A74-Editing#user-content-bleopt-prompt_rps1),
  [**transient prompt**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A74-Editing#user-content-bleopt-prompt_ps1_transient),
  [**xterm title**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A74-Editing#user-content-bleopt-prompt_xterm_title), etc.

Note: ble.sh does not provide specific settings of the prompt, aliases, functions, etc.
ble.sh provides a more fundamental infrastructure so that users can set up their own prompt, aliases, functions, etc.
Of course ble.sh can be used in combination with other Bash configurations such as `bash-it` and `oh-my-bash`.

> Demo (version 0.2)
>
> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/trial1.gif)

## History and roadmap

My little experiment has took place in one corner of my `bashrc` in the end of May, 2013 after I enjoyed some article on `zsh-syntax-highlighting`.
I initially thought something can be achieved by writing a few hundred of lines of codes
but soon realized that everything needs to be re-implemented for the authentic support of syntax highlighting in Bash.
I decided to make it as an independent script `ble.sh`.
The name stemmed from that of Zsh's line editor, *ZLE* (*Zsh Line Editor*), but suffixed with `.sh` for the implication of being written in shell script.
I'm occasinally asked about the pronunciation of `ble.sh`, but you can actually pronounce it as you like.
After the two-week experiment, I was satisfied with my conclusion that it is *possible* to implement a full-featured line editor in Bash that satisfies the actual daily uses.
The real efforts of improving the prototype implementation for the real uses was started in Feburuary, 2015.
I released the initial version in the next December. Until then, the basic part of the line editor was completed.
The implementation of vim mode has been started in September, 2017 and completed in the next March.
I started working on the enhancement of the completion in August, 2018 and released it in the next February.

- 2013-06 v0.0 -- prototype
- 2015-12 v0.1 -- Syntax highlighting [[v0.1.14](https://github.com/akinomyoga/ble.sh/releases/tag/v0.1.14)]
- 2018-03 v0.2 -- Vim mode [[v0.2.6](https://github.com/akinomyoga/ble.sh/releases/tag/v0.2.6)]
- 2019-02 v0.3 -- Enhanced completion [[v0.3.3](https://github.com/akinomyoga/ble.sh/releases/tag/v0.3.3)]
- 20xx-xx v0.4 (plan) -- programmable highlighting [`master`]
- 20xx-xx v0.5 (plan) -- TUI configuration
- 20xx-xx v0.6 (plan) -- error diagnostics?

# 1 Usage

## 1.1 Try `ble.sh` generated from source (version ble-0.4 devel)<sup><a id="get-from-source" href="#get-from-source">†</a></sup>

### Generate

To generate `ble.sh`, `gawk` (GNU awk) and `gmake` (GNU make) (in addition to Bash and POSIX standard utilities) is required.
The file `ble.sh` can be generated using the following commands.
If you have GNU make installed on `gmake`, please use `gmake` instead of `make`.
```bash
git clone --recursive https://github.com/akinomyoga/ble.sh.git
cd ble.sh
make
```

A script file `ble.sh` will be generated in the directory `ble.sh/out`.

### Try

Then, you can load `ble.sh` in the Bash session using the `source` command:
```bash
source out/ble.sh
```

### Install

To install `ble.sh` in a specified directory, use `make install`.

```bash
# INSTALL to ~/.local/share/blesh
make install

# INSTALL to a specified directory
make install INSDIR=/path/to/blesh

# PACKAGE (for package maintainers)
make install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

If either the make variables `DESTDIR` or `PREFIX` is supplied, `ble.sh` will be copied to `$DESTDIR/$PREFIX/share/blesh`.
Otherwise, if the make variables `INSDIR` is specified, it will be installed directly on `$INSDIR`.
Otherwise, if the environment variable `$XDG_DATA_HOME` is defined, the install location will be `$XDG_DATA_HOME/blesh`.
If none of these variables are specified, the default install location is `~/.local/share/blesh`.

To set up `.bashrc` see [Sec. 1.3](#set-up-bashrc).

## 1.2 Or, use a tar ball of `ble.sh` obtained from GitHub releases<sup><a id="get-from-tarball" href="#get-from-tarball">†</a></sup>

For download, trial and install, see the description at each release page.
The stable versions are significantly old compared to the devel version, so many features are unavailable.

- Devel [v0.4.0-devel2](https://github.com/akinomyoga/ble.sh/releases/tag/v0.4.0-devel2) (2020-12)
- Stable [v0.3.3](https://github.com/akinomyoga/ble.sh/releases/tag/v0.3.3) (2019-02 fork) Enhanced completions
- Stable [v0.2.6](https://github.com/akinomyoga/ble.sh/releases/tag/v0.2.6) (2018-03 fork) Vim mode
- Stable [v0.1.14](https://github.com/akinomyoga/ble.sh/releases/tag/v0.1.14) (2015-12 fork) Syntax highlighting

## 1.3 Set up `.bashrc`<sup><a id="set-up-bashrc" href="#set-up-bashrc">†</a></sup>

If you want to load `ble.sh` by default in interactive sessions of `bash`, usually one can just source `ble.sh` in `~/.bashrc`,
but more reliable way is to add the following codes to your `.bashrc` file:
```bash
# bashrc

# Add this lines at the top of .bashrc:
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# your bashrc settings come here...

# Add this line at the end of .bashrc:
[[ ${BLE_VERSION-} ]] && ble-attach
```

## 1.4 User settings `~/.blerc`

User settings can be placed in the init script `~/.blerc` (or `${XDG_CONFIG_HOME:-$HOME/.config}/blesh/init.sh` if `~/.blerc` is not available)
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

## 1.5 Update

You need Git (`git`), GNU awk (`gawk`) and GNU make (`make`).
For `ble-0.3+`, you can run `ble-update` in the session with `ble.sh` loaded:

```bash
$ ble-update
```

For `ble.0.4+`, you can also update it outside the `ble.sh` session using

```bash
$ bash /path/to/ble.sh --update
```

You can instead download the latest version by `git pull` and install it:

```bash
cd ble.sh   # <-- enter the git repository you already have
git pull
git submodule update --recursive --remote
make
make INSDIR="$HOME/.local/share/blesh" install
```

## 1.6 Uninstall

Basically you can simply delete the installed directory and the settings that user added.

- Close all the `ble.sh` sessions (the Bash interactive sessions with `ble.sh`)
- Remove the added lines in `.bashrc`.
- Remove `blerc` files (`~/.blerc` or `~/.config/blesh/init.sh`) if any.
- Remove the installed directory.
- Remove the cache directory `~/.cache/blesh` if any.
- Remove the temporary directory `/tmp/blesh` if any [ Only needed when your system does not automatically clears `/tmp` ].

# 2 Basic settings

Here some of the settings for `~/.blerc` are picked up.
You can find useful settings also in [Q\&A](https://github.com/akinomyoga/ble.sh/wiki/Q&A),
[Recipes](https://github.com/akinomyoga/ble.sh/wiki/Recipes)
and [`contrib` repository](https://github.com/akinomyoga/blesh-contrib).
The complete list of setting items can be found in the template [`blerc`](https://github.com/akinomyoga/ble.sh/blob/master/blerc).
For detailed explanations please refer to [Manual](https://github.com/akinomyoga/ble.sh/wiki).

## 2.1 Vim mode

For the vi/vim mode, check [the wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## 2.2 Disable features

One of frequently asked questions is the way to disable a specific feature that `ble.sh` adds.
Here the settings for disabling features are summarized.

```bash
# Disable syntax highlighting
bleopt highlight_syntax=

# Disable highlighting based on filenames
bleopt highlight_filename=

# Disable highlighting based on variable types
bleopt highlight_variable=

# Disable auto-complete (Note: auto-complete is enabled by default in bash-4.0+)
bleopt complete_auto_complete=
# Tip: you may instead specify the delay of auto-complete in millisecond
bleopt complete_auto_delay=300

# Disable auto-complete based on the command history
bleopt complete_auto_history=

# Disable ambiguous completion
bleopt complete_ambiguous=

# Disable menu-complete by TAB
bleopt complete_menu_complete=

# Disable menu filtering (Note: auto-complete is enabled by default in bash-4.0+)
bleopt complete_menu_filter=

# Disable EOF marker like "[ble: EOF]"
bleopt prompt_eol_mark=''
# Tip: you may instead specify another string:
bleopt prompt_eol_mark='⏎'

# Disable error exit marker like "[ble: exit %d]"
bleopt exec_errexit_mark=
# Tip: you may instead specify another string:
bleopt exec_errexit_mark=$'\e[91m[error %d]\e[m'
```

## 2.3 CJK Width

The option `char_width_mode` controls the width of the Unicode characters with `East_Asian_Width=A` (Ambiguous characters).
Currently four values `emacs`, `west`, `east`, and `auto` are supported. With the value `emacs`, the default width in emacs is used.
With `west` all the ambiguous characters have width 1 (Hankaku). With `east` all the ambiguous characters have width 2 (Zenkaku).
With `auto` the width mode `west` or `east` is automatically chosen based on the terminal behavior.
The default value is `auto`. Appropriate value should be chosen in accordance with your terminal behavior.
For example, the value can be changed to `west` as:

```bash
bleopt char_width_mode='west'
```

## 2.4 Input Encoding

The option `input_encoding` controls the encoding scheme used in the decode of input. Currently `UTF-8` and `C` are available. With the value `C`, byte values are directly interpreted as character codes. The default value is `UTF-8`. For example, the value can be changed to `C` as:

```bash
bleopt input_encoding='C'
```

## 2.5 Bell

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

## 2.6 Highlight Colors

The colors and attributes used in the syntax highlighting are controlled by `ble-face` function. The following code reproduces the default configuration:
```bash
# highlighting related to editing
ble-face -s region                    bg=60,fg=white
ble-face -s region_target             bg=153,fg=black
ble-face -s region_match              bg=55,fg=white
ble-face -s region_insert             fg=12,bg=252
ble-face -s disabled                  fg=242
ble-face -s overwrite_mode            fg=black,bg=51
ble-face -s auto_complete             fg=238,bg=254
ble-face -s menu_filter_fixed         bold
ble-face -s menu_filter_input         fg=16,bg=229
ble-face -s vbell                     reverse
ble-face -s vbell_erase               bg=252
ble-face -s vbell_flash               fg=green,reverse
ble-face -s prompt_status_line        fg=231,bg=240

# syntax highlighting
ble-face -s syntax_default            none
ble-face -s syntax_command            fg=brown
ble-face -s syntax_quoted             fg=green
ble-face -s syntax_quotation          fg=green,bold
ble-face -s syntax_escape             fg=magenta
ble-face -s syntax_expr               fg=26
ble-face -s syntax_error              bg=203,fg=231
ble-face -s syntax_varname            fg=202
ble-face -s syntax_delimiter          bold
ble-face -s syntax_param_expansion    fg=purple
ble-face -s syntax_history_expansion  bg=94,fg=231
ble-face -s syntax_function_name      fg=92,bold
ble-face -s syntax_comment            fg=242
ble-face -s syntax_glob               fg=198,bold
ble-face -s syntax_brace              fg=37,bold
ble-face -s syntax_tilde              fg=navy,bold
ble-face -s syntax_document           fg=94
ble-face -s syntax_document_begin     fg=94,bold
ble-face -s command_builtin_dot       fg=red,bold
ble-face -s command_builtin           fg=red
ble-face -s command_alias             fg=teal
ble-face -s command_function          fg=92
ble-face -s command_file              fg=green
ble-face -s command_keyword           fg=blue
ble-face -s command_jobs              fg=red
ble-face -s command_directory         fg=26,underline
ble-face -s filename_directory        underline,fg=26
ble-face -s filename_directory_sticky underline,fg=white,bg=26
ble-face -s filename_link             underline,fg=teal
ble-face -s filename_orphan           underline,fg=teal,bg=224
ble-face -s filename_executable       underline,fg=green
ble-face -s filename_setuid           underline,fg=black,bg=220
ble-face -s filename_setgid           underline,fg=black,bg=191
ble-face -s filename_other            underline
ble-face -s filename_socket           underline,fg=cyan,bg=black
ble-face -s filename_pipe             underline,fg=lime,bg=black
ble-face -s filename_character        underline,fg=white,bg=black
ble-face -s filename_block            underline,fg=yellow,bg=black
ble-face -s filename_warning          underline,fg=red
ble-face -s filename_url              underline,fg=blue
ble-face -s filename_ls_colors        underline
ble-face -s varname_array             fg=orange,bold
ble-face -s varname_empty             fg=31
ble-face -s varname_export            fg=200,bold
ble-face -s varname_expr              fg=92,bold
ble-face -s varname_hash              fg=70,bold
ble-face -s varname_number            fg=64
ble-face -s varname_readonly          fg=200
ble-face -s varname_transform         fg=29,bold
ble-face -s varname_unset             fg=124
```

The current list of faces can be obtained by the following command (`ble-face` without arguments):
```console
$ ble-face
```

The color codes can be checked in output of the function `ble-color-show` (defined in `ble.sh`):
```console
$ ble-color-show
```

## 2.7 Key Bindings

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

## 3.1 Use multiline mode

When the command line string contains a newline character, `ble.sh` enters the MULTILINE mode.

By typing <kbd>C-v C-j</kbd> or <kbd>C-q C-j</kbd>, you can insert a newline character in the command line string.
In the MULTILINE mode, <kbd>RET</kbd> (<kbd>C-m</kbd>) causes insertion of a new newline character.
In the MULTILINE mode, the command can be executed by typing <kbd>C-j</kbd>.

When the shell option `shopt -s cmdhist` is set (which is the default),
<kbd>RET</kbd> (<kbd>C-m</kbd>) inserts a newline if the current command line string is syntactically incomplete.

## 3.2 Use vim editing mode

If `set -o vi` is specified in `.bashrc` or `set editing-mode vi` is specified in `.inputrc`, the vim mode is enabled.
For details, please check [the wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## 3.3 Use `auto-complete`

The feature `auto-complete` is available in Bash 4.0 or later. `auto-complete` automatically suggests a possible completion on user input.
The suggested contents can be inserted by typing <kbd>S-RET</kbd>
(when the cursor is at the end of the command line, you can also use <kbd>right</kbd>, <kbd>C-f</kbd> or <kbd>end</kbd> to insert the suggestion).
If you want to insert only first word of the suggested contents, you can use <kbd>M-right</kbd> or <kbd>M-f</kbd>.
If you want to accept the suggestion and immediately run the command, you can use <kbd>C-RET</kbd> (if your terminal supports this special key combination).

## 3.4 Use `sabbrev` (static abbrev expansions)

By registering words to `sabbrev`, the words can be expanded to predefined strings.
When the cursor is just after a registered word, typing <kbd>SP</kbd> causes `sabbrev` expansion.
For example, with the following settings, when you type <kbd>SP</kbd> after the string `command L`, the command line will be expanded to `command | less`.

```bash
# blerc
ble-sabbrev L='| less'
```

The sabbrev names that starts from `\` are also recommended since it is unlikely to conflict with the real words that is a part of the executed command.

```bash
# blerc
ble-sabbrev '\L'='| less'
```


# 4 Contributors

I received many feedbacks from many people in GitHub Issues/PRs.
I thank all such people for supporting the project.
Among them, the following people have made particularly significant contributions.

- [`@cmplstofB`](https://github.com/cmplstofB) helped me implementing vim-mode by testing it and giving me a lot of suggestions.
- [`@dylankb`](https://github.com/dylankb) reported many issues for fzf-integration, initialization, etc.
- [`@rux616`](https://github.com/rux616) reported several issues and created a PR for fixing the default path of `.blerc`
- [`@timjrd`](https://github.com/timjrd) suggested and contributed to performance improvements in completion.
- [`@3ximus`](https://github.com/3ximus) reported many issues for a wide variety of problems.
