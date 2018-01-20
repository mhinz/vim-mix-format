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
    if get(g:, 'mix_format_silent_errors')
      for line in self.stdout
        echomsg line
      endfor
      echohl ErrorMsg | echo 'Formatting failed. Check :messages.' | echohl NONE
    else
      execute len(self.stdout) > 14 ? 14 : len(self.stdout) 'new'
      set buftype=nofile
      put =join(self.stdout, \"\n\")
      1delete
      echohl ErrorMsg | echo 'Formatting failed.' | echohl NONE
    endif
    return
  endif

  if self.diffmode
    call system(printf('diff %s %s', self.origfile, self.difffile))
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
  else
    let sol = &startofline
    let &startofline = 0
    silent edit!
    let &startofline = sol
    return
  end

  diffthis
  set foldmethod=manual

  if +get(g:, 'mix_format_win_id') && win_gotoid(g:mix_format_win_id)
    %delete
  else
    rightbelow vnew
    let g:mix_format_win_id = win_getid()
    set buftype=nofile nobuflisted bufhidden=wipe
    runtime syntax/elixir.vim
  endif

  execute 'silent read' fnameescape(self.difffile)
  silent! call delete(self.difffile)
  silent 0delete _
  diffthis
  set foldmethod=manual
  normal! ]c

  nnoremap <buffer><silent> q :close<cr>
  augroup mix_format
    autocmd!
    autocmd BufWipeout <buffer> silent diffoff!
  augroup END

  if exists('#User#MixFormatDiff')
    doautocmd <nomodeline> User MixFormatDiff
  endif
endfunction

function! s:get_cmd_from_file(filename) abort
  let cmd = s:build_cmd(a:filename)
  if has('win32') && &shell =~ 'cmd'
    return cmd
  endif
  return ['sh', '-c', cmd]
endfunction

function! s:build_cmd(filename) abort
  let elixir_bin_path = get(g:, 'mix_format_elixir_bin_path')
  let options = get(g:, 'mix_format_options', '--check-equivalent')

  if empty(elixir_bin_path)
    return printf('mix format %s %s',
          \ options,
          \ shellescape(a:filename))
  endif

  return printf('%s %s %s %s',
        \ elixir_bin_path .'/elixir',
        \ elixir_bin_path .'/mix format',
        \ options,
        \ shellescape(a:filename))
endfunction

function! s:mix_format(diffmode) abort
  let origfile = expand('%:p')
  if a:diffmode
    let difffile = tempname()
    execute 'silent write' fnameescape(difffile)
  else
    let difffile = origfile
  endif
  let cmd = s:get_cmd_from_file(difffile)

  let options = {
        \ 'cmd':       type(cmd) == type([]) ? join(cmd) : cmd,
        \ 'diffmode':  a:diffmode,
        \ 'origfile':  origfile,
        \ 'difffile':  difffile,
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

command! -buffer -bar MixFormat     call <sid>mix_format(0+'diffmode')
command! -buffer -bar MixFormatDiff call <sid>mix_format(1+'diffmode')

if get(g:, 'mix_format_on_save')
  autocmd BufWritePre *.{ex,exs} noautocmd update | call s:mix_format(0+'diffmode')
endif

let b:loaded_mix_format = 1
