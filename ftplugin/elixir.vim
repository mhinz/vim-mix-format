if exists('b:loaded_mix_format')
      \ || &filetype != ('elixir' || 'eelixir')
      \ || &compatible
  finish
endif

" Is 'cwd' key for job_start() options available?
let s:has_cwd = has('nvim') || has('patch-8.0.902')

if !exists('g:mix_format_env_cmd')
  " Workaround for https://github.com/mhinz/vim-mix-format/issues/15
  let g:mix_format_env_cmd = executable('env') ? ['env', '-u', 'MIX_ENV'] : []
endif

function! s:msg(show, msg) abort
  if a:show
    echomsg 'MixFormat: '. a:msg
  endif
endfunction

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
  let source_win_id = win_getid()
  call win_gotoid(self.win_id)

  if !s:has_cwd
    call s:msg(self.verbose, 'Changing to: '. self.origdir)
    execute 'cd' fnameescape(self.origdir)
  endif

  if filereadable(self.undofile)
    execute 'silent rundo' self.undofile
    call s:msg(self.verbose, 'Deleting undo file: '. self.undofile)
    call delete(self.undofile)
  endif

  if a:exitval && get(g:, 'mix_format_silent_errors')
    for line in self.stdout
      echomsg line
    endfor
    redraw | echohl ErrorMsg | echo 'Formatting failed. Check :messages.' | echohl NONE
    return
  end

  let old_efm = &errorformat
  let &errorformat  = '%-Gmix format failed%.%#'
  let &errorformat .= ',** (%.%#) %f:%l: %m'
  lgetexpr self.stdout
  let &errorformat = old_efm
  lwindow
  if &buftype == 'quickfix'
    let w:quickfix_title = s:build_cmd(fnamemodify(self.origfile, ':.'))
  endif

  if a:exitval
    redraw | echohl ErrorMsg | echo 'Formatting failed.' | echohl NONE
    return
  endif

  if self.diffmode
    call system(printf('diff %s %s', self.origfile, self.difffile))
    if !v:shell_error
      echomsg 'No formatting issues found.'
      if +get(g:, 'mix_format_diff_win_id')
        let winnr = win_id2win(g:mix_format_diff_win_id)
        if winnr
          execute winnr 'close'
        endif
      endif
      return
    endif
  else
    let [sol, ur] = [&startofline, &undoreload]
    let [&startofline, &undoreload] = [0, 10000]
    mkview
    try
      silent edit!
    finally
      let [&startofline, &undoreload] = [sol, ur]
      loadview
    endtry
    call win_gotoid(source_win_id)
    return
  end

  diffthis

  if +get(g:, 'mix_format_diff_win_id') && win_gotoid(g:mix_format_diff_win_id)
    %delete
  else
    rightbelow vnew
    let g:mix_format_diff_win_id = win_getid()
    set buftype=nofile nobuflisted bufhidden=wipe
    runtime syntax/elixir.vim
  endif

  execute 'silent read' fnameescape(self.difffile)
  call s:msg(self.verbose, 'Deleting diff file: '. self.difffile)
  silent! call delete(self.difffile)
  silent 0delete _
  diffthis
  normal! ]c

  nnoremap <buffer><silent> q :close<cr>
  augroup mix_format_diff
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
    return 'cmd /c '. cmd
  endif
  return g:mix_format_env_cmd + ['sh', '-c', cmd]
endfunction

function! s:build_cmd(filename) abort
  let elixir_bin_path = get(g:, 'mix_format_elixir_bin_path')
  let options = get(g:, 'mix_format_options', '--check-equivalent')

  let [shellslash, &shellslash] = [&shellslash, 0]
  let dot_formatter = findfile('.formatter.exs', expand('%:p:h').';')
  if !empty(dot_formatter)
    let options .= ' --dot-formatter '. shellescape(fnamemodify(dot_formatter, ':p'))
  endif
  let filename = shellescape(a:filename)
  let &shellslash = shellslash

  if empty(elixir_bin_path)
    return printf('mix format %s %s', options, filename)
  endif

  return printf('%s %s %s %s',
        \ elixir_bin_path .'/elixir',
        \ elixir_bin_path .'/mix format',
        \ options,
        \ filename)
endfunction

function! s:mix_format(diffmode) abort
  if &modified
    redraw | echohl WarningMsg | echo 'Unsaved buffer. Quitting.' | echohl NONE
    return
  endif

  let origdir = getcwd()

  let mixfile = findfile('mix.exs', expand('%:p:h').';')
  if empty(mixfile)
    call s:msg(&verbose, 'No mix project found.')
  else
    let mixroot = fnamemodify(mixfile, ':h')
    if !s:has_cwd
      call s:msg(&verbose, 'Changing to: '. mixroot)
      execute 'cd' fnameescape(mixroot)
    endif
  endif

  let origfile = expand('%:p')

  if a:diffmode
    let difffile = tempname()
    call s:msg(&verbose, 'Creating diff file: '. difffile)
    execute 'silent write' fnameescape(difffile)
  else
    let difffile = origfile
  endif
  let cmd = s:get_cmd_from_file(difffile)

  let undofile = tempname()
  call s:msg(&verbose, 'Creating undo file: '. undofile)
  execute 'silent wundo!' undofile

  let options = {
        \ 'cmd':       type(cmd) == type([]) ? join(cmd) : cmd,
        \ 'diffmode':  a:diffmode,
        \ 'origdir':   origdir,
        \ 'origfile':  origfile,
        \ 'difffile':  difffile,
        \ 'undofile':  undofile,
        \ 'win_id':    win_getid(),
        \ 'verbose':   &verbose,
        \ 'stdout':    [],
        \ 'stdoutbuf': [],
        \ }

  if s:has_cwd && exists('mixroot')
    let options.cwd = mixroot
  endif

  call s:msg(&verbose, type(cmd) == type([]) ? string(cmd) : cmd)

  if has('nvim')
    silent! call jobstop(s:id)
    let s:id = jobstart(cmd, extend(options, {
          \ 'on_stdout': function('s:on_stdout_nvim'),
          \ 'on_stderr': function('s:on_stdout_nvim'),
          \ 'on_exit':   function('s:on_exit'),
          \ 'detach':    !has('nvim-0.3.6'),
          \ }))
  else
    silent! call job_stop(s:id)
    let s:id = job_start(cmd, extend({
          \ 'in_io':   'null',
          \ 'err_io':  'out',
          \ 'out_cb':  function('s:on_stdout_vim', options),
          \ 'exit_cb': function('s:on_exit', options),
          \ }, has_key(options, 'cwd') ? {'cwd': options.cwd} : {}))
  endif
endfunction

command! -buffer -bar MixFormat     call <sid>mix_format(0+'diffmode')
command! -buffer -bar MixFormatDiff call <sid>mix_format(1+'diffmode')

if get(g:, 'mix_format_on_save')
  augroup mix_format
    autocmd BufWritePre <buffer> noautocmd silent update | call s:mix_format(0+'diffmode')
  augroup END
endif

let b:loaded_mix_format = 1
