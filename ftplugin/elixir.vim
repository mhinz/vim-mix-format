" if exists('g:loaded_mix_format') || &compatible
"   finish
" endif

function! s:mix_format_file() abort
  let filename = expand('%:p')
  call system('mix format '. fnameescape(filename))
  edit
endfunction

function! s:mix_format_file_diff() abort
  let tempfile = tempname()
  execute 'silent write' fnameescape(tempfile)
  call system('mix format '. shellescape(tempfile))
  diffthis

  let curwin = winnr()

  for win in range(1, winnr('$'))
    if getbufvar(winbufnr(win), 'mix_format_diff', 0)
      execute win 'wincmd w'
      %delete
    endif
  endfor

  if winnr() == curwin
    vnew
  endif

  let b:mix_format_diff = 1

  execute 'silent read' fnameescape(tempfile)
  runtime syntax/elixir.vim
  set buftype=nofile nobuflisted bufhidden=wipe
  silent 0delete _
  diffthis

  nnoremap <buffer> q :close<cr>

  augroup MixFormat
    autocmd!
    autocmd BufWipeout,VimLeavePre <buffer>
          \  let filename = expand('<afile>')
          \| if filewritable(filename)
          \|   call delete(filename)
          \| endif
  augroup END
endfunction

command! -buffer -bar MixFormatFile     call <sid>mix_format_file()
command! -buffer -bar MixFormatFileDiff call <sid>mix_format_file_diff()

let g:loaded_mix_format = 1
