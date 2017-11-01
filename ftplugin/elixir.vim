if exists('b:loaded_mix_format') || &compatible
  finish
endif

function! s:on_stdout_nvim(_job, data, _event) dict abort
  if empty(a:data[-1])
    " Second-last item is the last complete line in a:data.
    let self.stdout += self.stdoutbuf + a:data[:-2]
    let self.stdoutbuf = []
  else
    if empty(self.stdoutbuf)
      " Last item in a:data is an incomplete line. Put into buffer.
      let self.stdoutbuf = [remove(a:data, -1)]
      let self.stdout += a:data
    else
      " Last item in a:data is an incomplete line. Append to buffer.
      let self.stdoutbuf = self.stdoutbuf[:-2]
            \ + [self.stdoutbuf[-1] . get(a:data, 0, '')]
            \ + a:data[1:]
    endif
  endif
endfunction

function! s:on_stdout_vim(_job, data) dict abort
  let self.stdout += [a:data]
endfunction

function! s:on_exit(_job, exitval, ...) dict abort
  if a:exitval
    echohl ErrorMsg
    echomsg 'Failed: '. self.cmd
    echohl NONE
    for line in self.stdout
      echomsg line
    endfor
    return
  endif

  call system(printf('diff %s %s', self.origfile, self.tempfile))
  if !v:shell_error
    echomsg 'No formatting issues found.'
    if +get(g:, 'mix_format_win_id')
      let winnr = win_id2win(g:mix_format_win_id)
      if winnr
        execute winnr 'close'
      endif
    endif
    return
  endif

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
  call system('mix format '. shellescape(filename))
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

  let options = {
        \ 'cmd':       type(cmd) == type([]) ? join(cmd) : cmd,
        \ 'origfile':  expand('%:p'),
        \ 'tempfile':  tempfile,
        \ 'stdout':    [],
        \ 'stdoutbuf': [],
        \ }

  if has('nvim')
    silent! call jobstop(s:id)
    let s:id = jobstart(cmd, extend(options, {
          \ 'on_stdout': function('s:on_stdout_nvim'),
          \ 'on_stderr': function('s:on_stdout_nvim'),
          \ 'on_exit':   function('s:on_exit'),
          \ }))
  else
    silent! call job_stop(s:id)
    let s:id = job_start(cmd, {
          \ 'in_io':   'null',
          \ 'err_io':  'out',
          \ 'out_cb':  function('s:on_stdout_vim', options),
          \ 'exit_cb': function('s:on_exit', options),
          \ })
  endif
endfunction

command! -buffer -bar MixFormatFile     call <sid>mix_format_file()
command! -buffer -bar MixFormatFileDiff call <sid>mix_format_file_diff()

let b:loaded_mix_format = 1
