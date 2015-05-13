let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vim_gita')

function! gita#utils#import(name) abort " {{{
  let cache_name = printf(
        \ '_vital_module_%s',
        \ substitute(a:name, '\.', '_', 'g'),
        \)
  if !has_key(s:, cache_name)
    let s:[cache_name] = s:V.import(a:name)
  endif
  return s:[cache_name]
endfunction " }}}

" echo
function! gita#utils#echo(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#utils#debug(...) abort " {{{
  if !get(g:, 'gita#debug', 0)
    return
  endif
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echo('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gita#utils#info(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echo('Title', join(args))
endfunction " }}}
function! gita#utils#warn(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echo('WarningMsg', join(args))
endfunction " }}}
function! gita#utils#error(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echo('Error', join(args))
endfunction " }}}

" echomsg
function! gita#utils#echomsg(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#utils#debugmsg(...) abort " {{{
  if !get(g:, 'gita#debug', 0)
    return
  endif
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echomsg('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gita#utils#infomsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echomsg('Title', join(args))
endfunction " }}}
function! gita#utils#warnmsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echomsg('WarningMsg', join(args))
endfunction " }}}
function! gita#utils#errormsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#util#echomsg('Error', join(args))
endfunction " }}}

" input
function! gita#utils#input(hl, msg, ...) abort " {{{
  execute 'echohl' a:hl
  try
    return input(a:msg, get(a:000, 0, ''))
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#utils#ask(message, ...) abort " {{{
  let result = gita#utils#input('Question', a:message, get(a:000, 0, ''))
  redraw
  return result
endfunction " }}}
function! gita#utils#asktf(message, ...) abort " {{{
  let result = gita#utils#ask(
        \ printf('%s [yes/no]: ', a:message),
        \ get(a:000, 0, ''))
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result == ''
      call gita#utils#warn('Canceled.')
      break
    endif
    call gita#utils#error('Invalid input.')
    let result = gita#utils#ask(printf('%s [yes/no]: ', a:message))
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction " }}}

" string
function! gita#utils#yank_string(content) abort " {{{
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction " }}}
function! gita#utils#ensure_string(x) abort " {{{
  let P = gita#utils#import('Prelude')
  return P.is_string(a:x) ? a:x : [a:x]
endfunction " }}}
function! gita#utils#smart_string(value) abort " {{{
  let P = gita#util#import('Prelude')
  if P.is_string(a:value)
    return a:value
  elseif P.is_numeric(a:value)
    return a:value ? string(a:value) : ''
  elseif P.is_list(a:value) || P.is_dict(a:value)
    return !empty(a:value) ? string(a:value) : ''
  else
    return string(a:value)
  endif
endfunction " }}}
function! gita#utils#format_string(format, format_map, data) abort " {{{
  " format rule:
  "   %{<left>|<right>}<key>
  "     '<left><value><right>' if <value> != ''
  "     ''                     if <value> == ''
  "   %{<left>}<key>
  "     '<left><value>'        if <value> != ''
  "     ''                     if <value> == ''
  "   %{|<right>}<key>
  "     '<value><right>'       if <value> != ''
  "     ''                     if <value> == ''
  if empty(a:data)
    return ''
  endif
  let pattern_base = '\v\%%%%(\{([^\}\|]*)%%(\|([^\}\|]*)|)\}|)%s'
  let str = copy(a:format)
  for [key, value] in items(a:format_map)
    let result = gita#utils#smart_string(get(a:data, value, ''))
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', result) : ''
    let str = substitute(str, pattern, repl, 'g')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction " }}}

" list
function! gita#utils#ensure_list(x) abort " {{{
  let P = gita#utils#import('Prelude')
  return P.is_list(a:x) ? a:x : [a:x]
endfunction " }}}

" status
function! gita#utils#get_virtual_status(path, ...) abort " {{{
  let abspath = fnamemodify(a:path, ':p')
  let status = extend({
        \ 'is_virtual': 1,
        \ 'index': '',
        \ 'worktree': '',
        \ 'path': abspath,
        \ 'record': printf('   %s', abspath),
        \ 'sign': '',
        \ 'is_conflict': 0,
        \ 'is_staged': 0,
        \ 'is_unstaged': 0,
        \ 'is_untracked': 0,
        \ 'is_ignored': 0,
        \}, get(a:000, 0, {}))
  return status
endfunction " }}}

" misc
function! gita#utils#doautocmd(name) abort " {{{
  let name = printf('vim-gita-%s', a:name)
  if 703 < v:version || (v:version == 703 && has('patch438'))
    silent execute 'doautocmd <nomodeline> User ' . name
  else
    silent execute 'doautocmd User ' . name
  endif
endfunction " }}}
function! gita#utils#open_gita_issue(url) abort " {{{
  let url = 'https://github.com/lambdalisue/vim-gita/issues'
  let F = gita#utils#import('System.File')
  if gita#utils#asktf('Do you want to open a gita issue page?')
    call gita#utils#info(printf(
          \ 'Open "%s" ...',
          \ url,
          \))
    call F.open(url)
  endif
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
