[ Languages: **English** | [日本語](README-ja_JP.md) (Japanese) ]

<h1 align="center"><ruby>ble.sh<rp> (</rp><rt>/blɛʃ/</rt><rp>)</rp></ruby> ―Bash Line Editor―</h1>
<p align="center">
[ <b>README</b> | <a href="https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A71-Introduction">Manual</a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/Q&A">Q&A</a> |
<a href="https://github.com/akinomyoga/blesh-contrib"><code>contrib</code></a> |
<a href="https://github.com/akinomyoga/ble.sh/wiki/Recipes">Recipes</a> ]
</p>

*Bash Line Editor* (`ble.sh`) is a command line editor written in pure Bash which replaces the default GNU Readline.

The current devel version is 0.4.
This script supports Bash 3.0 or higher although we recommend using `ble.sh` with release versions of **Bash 4.0 or higher**.
Currently, only `UTF-8` encoding is supported for non-ASCII characters.
This script is provided under the [**BSD License**](LICENSE.md) (3-clause BSD license).

Disclaimer: The core part of the line editor is written in **pure Bash**, but
`ble.sh` relies on POSIX `stty` to set up TTY states before and after the execution of user commands.
It also uses other POSIX utilities for acceleration
in some parts of initialization and cleanup code,
processing of large data in completions, pasting large data, etc.

Pronunciation: The easiest pronunciation of `ble.sh` that users use is /blɛʃ/, but you can pronounce it as you like.
I do not specify the canonical way of pronouncing `ble.sh`.
In fact, I personally call it simply /biːɛliː/ or verbosely read it as /biːɛliː dɑt ɛseɪtʃ/ in my head.

## Quick instructions

To use `ble.sh`, Bash 3.0+ and POSIX standard utilities are required.
<!-- In macOS, you might additionally need to install `gawk`, `nawk`, or `mawk` since macOS `/usr/bin/awk` (awk-32 and later) seems to have a problem with some multibyte charsets. -->
There are two ways to get `ble.sh`: to download and build `ble.sh` using `git`, or to download the nightly build using `curl` or `wget`.
For the detailed descriptions, see [Sec 1.1](#get-from-source) and [Sec 1.2](#get-from-tarball) for trial/installation,
and [Sec 1.3](#set-up-bashrc) for the setup of your `~/.bashrc`.

> [!NOTE]
> If you want to **use fzf with `ble.sh`**, you need to check [Sec
> 2.8](#fzf-integration).

<details open><summary><b>Download and generate <code>ble.sh</code> using <code>git</code></b></summary>

This requires the commands `git`, `make` (GNU make), and `gawk` (GNU awk).
In the following, please replace `make` with `gmake` if your system provides GNU make as `gmake` (such as in BSD).

```bash
# TRIAL without installation

git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
make -C ble.sh
source ble.sh/out/ble.sh

# Quick INSTALL to BASHRC (If this doesn't work, please follow Sec 1.3)

git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install PREFIX=~/.local
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
```

The build process integrates multiple Bash script files into a single Bash script `ble.sh` with pre-processing,
places other module files in appropriate places, and strips code comments for a shorter initialization time.

Note: This does not involve any C/C++/Fortran compilations and generating binaries, so C/C++/Fortran compilers are not needed.
Some people seem to believe that one always needs to use `make` with C/C++/Fortran compilers to generate binaries.
They complain about `ble.sh`'s make process, but it comes from the lack of knowledge on the general principle of `make`.
You may find C/C++ programs in the repository, but they are used to update the Unicode character table from the Unicode database when a new Unicode standard appears.
The generated table is included in the repository:
[`canvas.GraphemeClusterBreak.sh`](https://github.com/akinomyoga/ble.sh/blob/master/src/canvas.GraphemeClusterBreak.sh),
[`canvas.c2w.musl.sh`](https://github.com/akinomyoga/ble.sh/blob/master/src/canvas.c2w.musl.sh),
[`canvas.c2w.sh`](https://github.com/akinomyoga/ble.sh/blob/master/src/canvas.c2w.sh),
and [`canvas.emoji.sh`](https://github.com/akinomyoga/ble.sh/blob/master/src/canvas.emoji.sh),
so there is no need to run these C/C++ programs in the build process.
Another C file is used as an adapter in an old system MSYS1,
which is used with an old compiler toolchain in Windows, but it will never be used in Unix-like systems.
Each file used in the build process is explained in [`make/README.md`](make/README.md).
</details>

<details><summary><b>Download the nightly build with <code>curl</code></b></summary>

This requires the commands `curl`, `tar` (with the support for the `J` flag), and `xz` (XZ Utils).

```bash
# TRIAL without installation

curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
source ble-nightly/ble.sh

# Quick INSTALL to BASHRC (If this doesn't work, please follow Sec 1.3)

curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
bash ble-nightly/ble.sh --install ~/.local/share
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
```

After the installation, the directory `ble-nightly` can be removed.
</details>

<details><summary><b>Download the nightly build with <code>wget</code></b></summary>

This requires the commands `wget`, `tar` (with the support for the `J` flag), and `xz` (XZ Utils).

```bash
# TRIAL without installation

wget -O - https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
source ble-nightly/ble.sh

# Quick INSTALL to BASHRC (If this doesn't work, please follow Sec 1.3)

wget -O - https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
bash ble-nightly/ble.sh --install ~/.local/share
echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
```

After the installation, the directory `ble-nightly` can be removed.
</details>

<details open><summary><b>Install a package using a package manager</b> (currently only a few packages)</summary>

This only requires the corresponding package manager.

- [AUR (Arch Linux)](https://github.com/akinomyoga/ble.sh/wiki/Manual-A1-Installation#user-content-AUR) `blesh-git` (devel), `blesh` (stable 0.3.4)
- [NixOS (nixpkgs)](https://github.com/akinomyoga/ble.sh/wiki/Manual-A1-Installation#user-content-nixpkgs) `blesh` (devel)
- [Guix](https://packages.guix.gnu.org/packages/blesh) `blesh` (devel)
</details>

<details open><summary><b>Update an existing copy of <code>ble.sh</code></b></summary>

```bash
# UPDATE (in a ble.sh session)

ble-update

# UPDATE (outside ble.sh sessions)

bash /path/to/ble.sh --update
```
</details>

<details><summary><b>Create a package of <code>ble.sh</code></b></summary>

Since `ble.sh` is just a set of shell scripts and do not contain any binary (i.e., "`noarch`"), 
you may just download the pre-built tarball from release pages and put the extracted contents in e.g. `/tmp/blesh-package/usr/local`.
Nevertheless, if you need to build the package from the source, please use the following commands.
Note that the git repository (`.git`) is required for the build.

```bash
# BUILD & PACKAGE (for package maintainers)

git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install DESTDIR=/tmp/blesh-package PREFIX=/usr/local
```

When you would like to tell `ble.sh` the way to update the package for `ble-update`,
you can place `_package.bash` at `${prefix}/share/blesh/lib/_package.bash`.
The file `_package.bash` is supposed to define a shell variable and a shell function
as illustrated in the following example (please replace `XXX` with the package management system):

```bash
# ${prefix}/share/blesh/lib/_package.bash

_ble_base_package_type=XXX

function ble/base/package:XXX/update {
  update-the-package-in-a-proper-way
  return 0
}
```

When the shell function returns exit status 0, it means that the update has been successfully done, and the reload of `ble.sh` will be automatically happen.
When the shell function returns exit status 6, the timestamp of `ble.sh` is checked, and the reload of `ble.sh` only happens when `ble.sh` is actually update.
When the shell function returns exit status 125, the default `ble.sh` update procedure is attempted.
Otherwise, the updating procedure is canceled, where any message explaining situation should be output by the shell function.
An example `_package.bash` for `AUR` can be found [here](https://aur.archlinux.org/cgit/aur.git/tree/blesh-update.sh?h=blesh-git).
</details>

## Features

- **Syntax highlighting**: Highlight command lines input by users as in `fish` and `zsh-syntax-highlighting`.
  Unlike the simple highlighting in `zsh-syntax-highlighting`, `ble.sh` performs syntactic analysis
  to enable the correct highlighting of complex structures such as nested command substitutions, multiple here documents, etc.
  Highlighting colors and styles are [fully configurable](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A72-Graphics).
- **Enhanced completion**:
  Extend [completion](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion)
  by **syntax-aware completion**, completion with quotes and parameter expansions in prefix texts, **ambiguous candidate generation**, etc.
  Also, [**menu-complete**](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A77-Completion#user-content-sec-menu-complete)
  supports the selection of candidates in the menu (candidate list) by cursor keys, <kbd>TAB</kbd>, and <kbd>S-TAB</kbd>.
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
Of course ble.sh can be used in combination with other Bash configurations such as [`bash-it`](https://github.com/Bash-it/bash-it) and [`oh-my-bash`](https://github.com/ohmybash/oh-my-bash).

> Demo (version 0.2)
>
> ![ble.sh demo gif](https://github.com/akinomyoga/ble.sh/wiki/images/trial1.gif)

## History and roadmap

My little experiment took place in one corner of my `bashrc` at the end of May 2013 after I enjoyed an article on `zsh-syntax-highlighting`.
I initially thought something could be achieved by writing a few hundred lines of code
but soon realized that everything needs to be re-implemented for the authentic support of syntax highlighting in Bash.
I decided to make it as an independent script `ble.sh`.
The name stemmed from that of Zsh's line editor, *ZLE* (*Zsh Line Editor*), but suffixed with `.sh` for the implication of being written in a shell script.
I'm occasionally asked about the pronunciation of `ble.sh`, but you can pronounce it as you like.
After the two-week experiment, I was satisfied with my conclusion that it is *possible* to implement a full-featured line editor in Bash that satisfies the actual daily uses.
The real efforts to improve the prototype implementation for real uses started in February 2015.
I released the initial version in the next December. Until then, the basic part of the line editor was completed.
The implementation of vim mode was started in September 2017 and completed in the next March.
I started working on the enhancement of the completion in August 2018 and released it in the next February.

- 2013-06 v0.0 -- prototype
- 2015-12 v0.1 -- Syntax highlighting [[v0.1.15](https://github.com/akinomyoga/ble.sh/releases/tag/v0.1.15)]
- 2018-03 v0.2 -- Vim mode [[v0.2.7](https://github.com/akinomyoga/ble.sh/releases/tag/v0.2.7)]
- 2019-02 v0.3 -- Enhanced completion [[v0.3.4](https://github.com/akinomyoga/ble.sh/releases/tag/v0.3.4)]
- 20xx-xx v0.4 (plan) -- programmable highlighting [[nightly build](https://github.com/akinomyoga/ble.sh/releases/tag/nightly)]
- 20xx-xx v0.5 (plan) -- TUI configuration
- 20xx-xx v0.6 (plan) -- error diagnostics?

## Limitations

There are some limitations due to the way `ble.sh` is implemented.
Also, some user configurations or other Bash frameworks may conflict with ble.sh.
For example,

- `ble.sh` does not set `PIPESTATUS` for the previous command line by default because it adds extra execution costs.
  Instead, the array `BLE_PIPESTATUS` contains the values of `PIPESTATUS` of the previous command line.
  If you need to access the values directly through the variable `PIPESTATUS`, please use the option `bleopt exec_restore_pipestatus=1`.
- `ble.sh` assumes that common variable names and environment variables (such as `LC_*`) are not used for the global readonly variables.
  In Bash, global readonly variables take effect in any scope including the local scope of the function, which means that we cannot even define a local variable that has the same name as a global readonly variable.
  This is not the problem specific to `ble.sh`, but any Bash framework may suffer from the global readonly variables.
  It is generally not recommended to define global readonly variables in Bash except for the security reasoning
  (Refs. [[1]](https://lists.gnu.org/archive/html/bug-bash/2019-03/threads.html#00150), [[2]](https://lists.gnu.org/archive/html/bug-bash/2020-04/threads.html#00200), [[3]](https://mywiki.wooledge.org/BashProgramming?highlight=%28%22readonly%22%20flag,%20or%20an%20%22integer%22%20flag,%20but%20these%20are%20mostly%20useless,%20and%20serious%20scripts%20shouldn%27t%20be%20using%20them%29#Variables)).
  Also, `ble.sh` overrides the builtin `readonly` with a shell function to prevent it from making global variables readonly.
  It allows only uppercase global variables and `_*` to become readonly except `_ble_*`, `__ble_*`, and some special uppercase variables.
- `ble.sh` overrides Bash's built-in commands (`trap`, `readonly`, `bind`, `history`, `read`, and `exit`) with shell functions to adjust the behavior of each built-in command and prevent them from interfering with `ble.sh`.
  If the user or another framework directly calls the original builtins through `builtin BUILTIN`, or if the user or another framework replaces the shell functions, the behavior is undefined.
- The shell and terminal settings for the line editor and the command execution
  are different.  `ble.sh` adjusts them for the line editor and try to restore
  the settigns for the command execution.  However, there are settings that
  cannot be restored or are intentionally not restored for various reasons.
  Some of them are summarlized on [a wiki
  page](https://github.com/akinomyoga/ble.sh/wiki/Internals#internal-and-external).

# 1 Usage

## 1.1 Try `ble.sh` generated from source (version ble-0.4 devel)<sup><a id="get-from-source" href="#get-from-source">†</a></sup>

### Generate

To generate `ble.sh`, `gawk` (GNU awk) and `gmake` (GNU make) (in addition to Bash and POSIX standard utilities) are required.
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

The comment lines and blank lines in the script files are stripped in the installation process.
If you would like to keep these lines in the script files, please specify the argument `strip_comment=no` to `make`.

To set up `.bashrc` see [Sec. 1.3](#set-up-bashrc).

## 1.2 Or, use a tar ball of `ble.sh` obtained from GitHub releases<sup><a id="get-from-tarball" href="#get-from-tarball">†</a></sup>

For download, trial and install, see the description at each release page.
The stable versions are significantly old compared to the devel version, so many features are unavailable.

- Devel [v0.4.0-devel3](https://github.com/akinomyoga/ble.sh/releases/tag/v0.4.0-devel3) (2020-12), [nightly build](https://github.com/akinomyoga/ble.sh/releases/tag/nightly)
- Stable [v0.3.4](https://github.com/akinomyoga/ble.sh/releases/tag/v0.3.4) (2019-02 fork) Enhanced completions
- Stable [v0.2.7](https://github.com/akinomyoga/ble.sh/releases/tag/v0.2.7) (2018-03 fork) Vim mode
- Stable [v0.1.15](https://github.com/akinomyoga/ble.sh/releases/tag/v0.1.15) (2015-12 fork) Syntax highlighting

## 1.3 Set up `.bashrc`<sup><a id="set-up-bashrc" href="#set-up-bashrc">†</a></sup>

If you want to load `ble.sh` in interactive sessions of `bash` by default, usually one can just source `ble.sh` in `~/.bashrc`,
but a more reliable way is to add the following codes to your `.bashrc` file:

```bash
# bashrc

# Add this lines at the top of .bashrc:
[[ $- == *i* ]] && source /path/to/blesh/ble.sh --noattach

# your bashrc settings come here...

# Add this line at the end of .bashrc:
[[ ${BLE_VERSION-} ]] && ble-attach
```

Basically, when `source /path/to/ble.sh` and `ble-attach` are performed,
standard streams (`stdin`, `stdout`, and `stderr`) should not be redirected but should be connected to the controlling TTY of the current session.
Also, please avoid calling `source /path/to/ble.sh` in shell functions.
The detailed conditions where the above *more reliable setup* is needed are explained in [an answer in Discussion #254](https://github.com/akinomyoga/ble.sh/discussions/254#discussioncomment-4284757).

## 1.4 User settings `~/.blerc`

User settings can be placed in the init script `~/.blerc` (or `${XDG_CONFIG_HOME:-$HOME/.config}/blesh/init.sh` if `~/.blerc` is not available)
whose template is available as the file [`blerc.template`](https://github.com/akinomyoga/ble.sh/blob/master/blerc.template) in the repository.
The init script is a Bash script that is sourced during the load of `ble.sh`, so any shell commands can be used in `~/.blerc`.
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

Basically you can simply delete the installed directory and the settings that the user added.

- Close all the `ble.sh` sessions (the Bash interactive sessions with `ble.sh`)
- Remove related user data. If you would like to keep them, you can skip these steps.
  - Remove the added lines in `.bashrc`.
  - Remove `blerc` files (`~/.blerc` or `~/.config/blesh/init.sh`) if any.
  - Remove the state directory `~/.local/state/blesh` if any.
- Remove the directory where `ble.sh` is installed.  When you use `out/ble.sh`
  inside the working tree of the git repository, the installed directory is the
  directory of the repository.  When you use `ble.sh` installed by `make
  install`, the installed directory is `<PREFIX>/share/blesh` where `<PREFIX>`
  (default: `~/.local`) is the prefix specified to `make install` in the
  installation stage.  When you use the version extracted from a tarball, the
  directory created by extracting the tarball is the installed directory.
- Remove the cache directory `~/.cache/blesh` if any.
- Remove the temporary directory `/tmp/blesh` if any [ Only needed when your system does not automatically clear `/tmp` ].

# 2 Basic settings

Here, some of the settings for `~/.blerc` are picked up.
You can find useful settings also in [Q\&A](https://github.com/akinomyoga/ble.sh/wiki/Q&A),
[Recipes](https://github.com/akinomyoga/ble.sh/wiki/Recipes),
and [`contrib` repository](https://github.com/akinomyoga/blesh-contrib).
The complete list of setting items can be found in the file [`blerc.template`](https://github.com/akinomyoga/ble.sh/blob/master/blerc.template).
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

# Disable elapsed-time marker like "[ble: elapsed 1.203s (CPU 0.4%)]"
bleopt exec_elapsed_mark=
# Tip: you may instead specify another string
bleopt exec_elapsed_mark=$'\e[94m[%ss (%s %%)]\e[m'
# Tip: you may instead change the threshold of showing the mark
bleopt exec_elapsed_enabled='sys+usr>=10*60*1000' # e.g. ten minutes for total CPU usage

# Disable exit marker like "[ble: exit]"
bleopt exec_exit_mark=

# Disable some other markers like "[ble: ...]"
bleopt edit_marker=
bleopt edit_marker_error=
```

## 2.3 CJK Width

The option `char_width_mode` controls the width of the Unicode characters with `East_Asian_Width=A` (Ambiguous characters).
Currently, four values `emacs`, `west`, `east`, and `auto` are supported. With the value `emacs`, the default width in emacs is used.
With `west`, all the ambiguous characters have width 1 (Hankaku). With `east`, all the ambiguous characters have width 2 (Zenkaku).
With `auto`, the width mode `west` or `east` is automatically chosen based on the terminal behavior.
The default value is `auto`. The appropriate value should be chosen in accordance with your terminal behavior.
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

The options `edit_abell` and `edit_vbell` control the behavior of the edit function `bell`. If `edit_abell` is a non-empty string, the audible bell is enabled, i.e. ASCII Control Character `BEL` (0x07) will be written to `stderr`. If `edit_vbell` is a non-empty string, the visual bell is enabled. By default, the audible bell is enabled while the visual bell is disabled.

The option `vbell_default_message` specifies the message shown as the visual bell. The default value is `' Wuff, -- Wuff!! '`. The option `vbell_duration` specifies the display duration of the visual-bell message. The unit is a millisecond. The default value is `2000`.

For example, the visual bell can be enabled as:
```
bleopt edit_vbell=1 vbell_default_message=' BEL ' vbell_duration=3000
```

For another instance, the audible bell is disabled as:
```
bleopt edit_abell=
```

## 2.6 Highlight Colors

The colors and attributes used in the syntax highlighting are controlled by the function `ble-face`. The following code reproduces the default configuration:
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
ble-face -s argument_option           fg=teal
ble-face -s argument_error            fg=black,bg=225

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

The details on the key representation, such as <kbd>C-x h</kbd> in the above example,
are described in [Manual §3.1](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A73-Key-Binding#user-content-sec-kspecs).
The representations of <kbd>Space</kbd>, <kbd>Tab</kbd>, <kbd>Enter</kbd>, <kbd>Backspace</kbd>, <kbd>Escape</kbd>, etc. are described
in [Manual §3.1.1](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A73-Key-Binding#user-content-sec-kspecs-ret):
The space is represented as <kbd>SP</kbd>,
the tab key is represented as <kbd>C-i</kbd> or <kbd>TAB</kbd> depending on the terminal,
the enter/return key is represented as <kbd>C-m</kbd> or <kbd>RET</kbd> depending on the terminal,
and the backspace key is represented as <kbd>C-?</kbd>, <kbd>DEL</kbd>, <kbd>C-h</kbd>, or <kbd>BS</kbd> depending on the terminal.
The representations of modified special keys such as <kbd>Ctrl+Return</kbd> and <kbd>Shift+Return</kbd> are described
in [Manual §3.6.4](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A73-Key-Binding#user-content-sec-modifyOtherKeys-manual):
If your terminal does not support `modifyOtherKeys`, you need to manually configure the escape sequences of modified special keys.


For another example, if you want to invoke a command on typing <kbd>M-c</kbd>, you can write it as follows:

```bash
ble-bind -c 'M-c' 'my-command'
```

Or, if you want to invoke a edit function (designed for Bash `bind -x`) on typing <kbd>C-r</kbd>, you can write it as follows:

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

If you want to run multiple widgets with a key, you can define your own widget by creating a function of the name `ble/widget/YOUR_WIDGET_NAME`
as illustrated in the following example.
It is highly recommended to prefix the widget name with `YOUR_NAME/`, `my/`, `blerc/`, `dotfiles/`, etc.
in order not to conflict with the names of the existing standard widgets.

```bash
# Example of calling multiple widgets with the key C-t
function ble/widget/my/example1 {
  ble/widget/beginning-of-logical-line
  ble/widget/insert-string 'echo $('
  ble/widget/end-of-logical-line
  ble/widget/insert-string ')'
}
ble-bind -f C-t my/example1
```

## 2.8 fzf integration<sup><a id="fzf-integration" href="#fzf-integration">†</a></sup>

If you would like to use `fzf` in combination with `ble.sh`, you need to configure `fzf` using [the `contrib/fzf` integration](https://github.com/akinomyoga/blesh-contrib#pencil-fzf-integration).
Please follow the instructions in the link for the detailed description.

```bash
# blerc

# Note: If you want to combine fzf-completion with bash_completion, you need to
# load bash_completion earilier than fzf-completion.  This is required
# regardless of whether to use ble.sh or not.
source /etc/profile.d/bash_completion.sh

ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
```

The option `-d` of `ble-import` delays the initialization.  In thise way, the
fzf settings are loaded in background after the prompt is shown.  See
[`ble-import` - Manual §8](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A78-Miscellaneous#user-content-fn-ble-import)
for details.  If you would like to additionally configure the fzf settings
after loading them, there are four options.  The easiest way is to drop the
`-d` option (Option 1 below).  As another option, you may also delay the
additional settings with `ble-import -d` [2] or `ble/util/idle.push` [3].  Or,
you can hook into the loading of the fzf settings by `ble-import -C` [4].

```bash
# [1] Drop -d
ble-import integration/fzf-completion
ble-import integration/fzf-key-bindings
<settings>

# [2] Use ble-import -d for additional settings
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
ble-import -d '<filename containing the settings>'

# [3] Use "ble/util/idle.push" for additional settings
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
ble/util/idle.push '<settings>'

# [4] Use "ble-import -C" for additional settings
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
ble-import -C '<settings>' integration/fzf-key-bindings
```

# 3 Tips

## 3.1 Use multiline mode

When the command line string contains a newline character, `ble.sh` enters the MULTILINE mode.

By typing <kbd>C-v C-j</kbd> or <kbd>C-q C-j</kbd>, you can insert a newline character in the command line string.
In the MULTILINE mode, <kbd>RET</kbd> (<kbd>C-m</kbd>) causes the insertion of a new newline character.
In the MULTILINE mode, the command can be executed by typing <kbd>C-j</kbd>.

When the shell option `shopt -s cmdhist` is set (which is the default),
<kbd>RET</kbd> (<kbd>C-m</kbd>) inserts a newline if the current command line string is syntactically incomplete.

## 3.2 Use vim editing mode

If `set -o vi` is specified in `.bashrc` or `set editing-mode vi` is specified in `.inputrc`, the vim mode is enabled.
For details, please check [the wiki page](https://github.com/akinomyoga/ble.sh/wiki/Vi-(Vim)-editing-mode).

## 3.3 Use `auto-complete`

The feature `auto-complete` is available in Bash 4.0 or later. `auto-complete` automatically suggests a possible completion on user input.
The suggested contents can be inserted by typing <kbd>S-RET</kbd>
(when the cursor is at the end of the command line, you can also use <kbd>right</kbd>, <kbd>C-f</kbd>, or <kbd>end</kbd> to insert the suggestion).
If you want to insert only the first word of the suggested contents, you can use <kbd>M-right</kbd> or <kbd>M-f</kbd>.
If you want to accept the suggestion and immediately run the command, you can use <kbd>C-RET</kbd>
(if your terminal does not support special key combinations like <kbd>C-RET</kbd>, please check
[Manual §3.6.4](https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A73-Key-Binding#user-content-sec-modifyOtherKeys-manual)).

## 3.4 Use `sabbrev` (static abbrev expansions)

By registering words to `sabbrev`, the words can be expanded to predefined strings.
When the cursor is just after a registered word, typing <kbd>SP</kbd> causes the `sabbrev` expansion.
For example, with the following settings, when you type <kbd>SP</kbd> after the string `command L`, the command line will be expanded to `command | less`.

```bash
# blerc
ble-sabbrev L='| less'
```

The sabbrev names that start with `\` plus alphabetical letters are also recommended since it is unlikely to conflict with real words that are a part of the executed command.

```bash
# blerc
ble-sabbrev '\L'='| less'
```

The sabbrevs starting with `~` can be expanded also by <kbd>/</kbd>.  This can be used to approximate Zsh's named directories.
For example, with the following settings, typing `~mybin/` expands it to e.g. `/home/user/bin/` (where we assumed `HOME=/home/user`).

```bash
# blerc

ble-sabbrev "~mybin=$HOME/bin"
```

# 4 Contributors

I received many feedbacks from many people in GitHub Issues/PRs.
I thank all such people for supporting the project.
Among them, the following people have made particularly significant contributions.

- [`@cmplstofB`](https://github.com/cmplstofB) helped me implement vim-mode by testing it and giving me a lot of suggestions.
- [`@dylankb`](https://github.com/dylankb) reported many issues with the fzf integration, initialization, etc.
- [`@rux616`](https://github.com/rux616) reported several issues and created a PR for fixing the default path of `.blerc`
- [`@timjrd`](https://github.com/timjrd) suggested and contributed to performance improvements in completion.
- [`@3ximus`](https://github.com/3ximus) reported many issues for a wide variety of problems.
- [`@SuperSandro2000`](https://github.com/SuperSandro2000) reported many issues related to NixOS and others
