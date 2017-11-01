if exists('b:loaded_mix_format') || &compatible
  finish
endif

function! s:on_exit(...) dict abort
  if +get(g:, 'mix_format_win_id') && win_gotoid(g:mix_format_win_id)
    %delete
  else
    rightbelow vnew
    let g:mix_format_win_id = win_getid()
    set buftype=nofile nobuflisted bufhidden=wipe
    runtime syntax/elixir.vim
  endif

  execute 'silent read' fnameescape(self.tempfile)
  silent! call delete(self.tempfile)
  silent 0delete _

  nnoremap <buffer><silent> q :close<cr>
  augroup mix_format
    autocmd!
    autocmd BufWipeout <buffer> silent diffoff!
  augroup END

  diffthis
  wincmd p
  diffthis
  diffupdate
endfunction

function! s:mix_format_file() abort
  let filename = expand('%:p')
  call system('mix format '. fnameescape(filename))
  edit
endfunction

function! s:mix_format_file_diff() abort
  let tempfile = tempname()
  execute 'silent write' fnameescape(tempfile)
  if has('win32') && &shell =~ 'cmd'
    let cmd = 'mix format '. shellescape(tempfile)
  else
    let cmd = ['sh', '-c', 'mix format '. shellescape(tempfile)]
  endif
  if has('nvim')
    silent! call jobstop(s:id)
    let s:id = jobstart(cmd, {'on_exit': function('s:on_exit'), 'tempfile': tempfile})
  else
    silent! call job_stop(s:id)
    let s:id = job_start(cmd, {'close_cb': function('s:on_exit', {'tempfile': tempfile})})
  endif
endfunction

command! -buffer -bar MixFormatFile     call <sid>mix_format_file()
command! -buffer -bar MixFormatFileDiff call <sid>mix_format_file_diff()

let b:loaded_mix_format = 1
