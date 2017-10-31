" if exists('g:loaded_mix_format') || &compatible
"   finish
" endif

function! s:mix_format_file() abort
  let filename = expand('%:p')
  call system('mix format '. fnameescape(filename))
  edit
endfunction

function! s:mix_format_file_diff() abort
  diffthis

  let tempfile = tempname()
  execute 'silent write' fnameescape(tempfile)

  let curwin = winnr()
  for win in range(1, winnr('$'))
    if getbufvar(winbufnr(win), 'mix_format_diff', 0)
      execute win 'wincmd w'
      %delete
    endif
  endfor
  if winnr() == curwin
    vnew
    let b:mix_format_diff = 1
  endif

  call system('mix format '. shellescape(tempfile))
  execute 'silent read' fnameescape(tempfile)

  if filewritable(tempfile)
    call delete(tempfile)
  endif

  runtime syntax/elixir.vim
  set buftype=nofile nobuflisted bufhidden=wipe
  silent 0delete _
  diffthis

  nnoremap <buffer><silent> q :close<cr>

  augroup mix_format
    autocmd!
    autocmd BufWipeout <buffer> silent diffoff!
  augroup END
endfunction

command! -buffer -bar MixFormatFile     call <sid>mix_format_file()
command! -buffer -bar MixFormatFileDiff call <sid>mix_format_file_diff()

let g:loaded_mix_format = 1
