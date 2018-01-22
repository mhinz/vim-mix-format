# vim-mix-format

Elixir 1.6 introduced the formatter: `mix format`. This plugin makes it easy to
run the formatter asynchronously from within Vim 8 and Neovim.

![demo](demo.gif)

## Installation

Use your [favorite plugin manager](https://github.com/mhinz/vim-galore#managing-plugins), e.g.
[vim-plug](https://github.com/junegunn/vim-plug):

    Plug 'mhinz/vim-mix-format'

## Commands

* To format the current file, use `:MixFormat`.

* The formatter is not perfect yet, so `:MixFormatDiff` will open a diff window
  that can be used for previewing the changes or picking only those that seem
  reasonable.

  `dp` pushes changes from the diff window to the source file. `q` closes the diff
  window. `]c` and `[c` jump between the changes.

  If you're not used to Vim's diff mode, [watch this
  screencast](http://vimcasts.org/episodes/comparing-buffers-with-vimdiff).

## Options

* Automatically format on saving.

  ```vim
  let g:mix_format_on_save = 1
  ```

* Set options for the formatter. See `mix help format` in the shell.

  ```vim
  let g:mix_format_options = '--check-equivalent'
  ```

* By default this plugin opens a window containing the stacktrace on errors.
  With this option enabled, there will be just a short message in the
  command-line bar. The stacktrace can still be looked up via `:messages`.

  ```vim
  let g:mix_format_silent_errors = 1
  ```

* If you're not using Elixir 1.6 in your project, but want to use the formatter
  anyway, you can specify the bin directory of an alternative Elixir installation:

  ```vim
  let g:mix_format_elixir_bin_path = '~/repo/elixir/bin'
  ```

## Customization

When using `:MixFormatDiff`, a new diff window will be opened and an user event
is emitted. It can be used to set different settings or switch back to the
source window:

```vim
autocmd User MixFormatDiff wincmd p
```

## Feedback

If you like this plugin, star it! It helps me deciding which projects to spend
more time on.
