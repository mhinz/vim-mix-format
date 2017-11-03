# vim-mix-format

Elixir 1.6 introduced a code formatter that can be called with `mix format`.
This plugin provides the integration into Vim 8 and Neovim.

`:MixFormat` will format the current file right away. If you want to always
format on saving, put `let g:mix_format_on_save = 1` in your vimrc.

The formatter is not perfect yet, so `:MixFormatDiff` will open a diff window
that can be used for previewing the changes or picking only those that seem
reasonable.

![demo](demo.gif)

`dp` pushes changes from the diff window to the source file. `q` closes the diff
window. `]c` and `[c` jump between the changes.

If you're not used to Vim's diff mode, [watch this
screencast](http://vimcasts.org/episodes/comparing-buffers-with-vimdiff).

## Installation

Use your [favorite plugin manager](https://github.com/mhinz/vim-galore#managing-plugins), e.g.
[vim-plug](https://github.com/junegunn/vim-plug):

    Plug 'mhinz/vim-mix-format'

## Feedback

If you like this plugin, star it! It helps me deciding which projects to spend
more time on.

Contact: [Twitter](https://twitter.com/_mhinz_)
