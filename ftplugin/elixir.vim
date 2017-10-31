if exists('b:loaded_mix_format') || &compatible
  finish
endif

function! s:mix_format_file() abort
  let filename = expand('%:p')
  call system('mix format '. fnameescape(filename))
  edit
endfunction

function! s:mix_format_file_diff() abort
  diffthis
  let tempfile = tempname()
  execute 'silent write' fnameescape(tempfile)

  if +get(g:, 'mix_format_win_id') && win_gotoid(g:mix_format_win_id)
    %delete
  else
    vnew
    let g:mix_format_win_id = win_getid()
    set buftype=nofile nobuflisted bufhidden=wipe
    runtime syntax/elixir.vim
  endif

  call system('mix format '. shellescape(tempfile))
  execute 'silent read' fnameescape(tempfile)
  silent 0delete _
  silent! call delete(tempfile)
  diffthis

  nnoremap <buffer><silent> q :close<cr>
  augroup mix_format
    autocmd!
    autocmd BufWipeout <buffer> silent diffoff!
  augroup END
endfunction

command! -buffer -bar MixFormatFile     call <sid>mix_format_file()
command! -buffer -bar MixFormatFileDiff call <sid>mix_format_file_diff()

let b:loaded_mix_format = 1
