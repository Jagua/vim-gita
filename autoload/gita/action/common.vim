let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')

function! s:compare(i1, i2) abort
  return a:i1[0] == a:i2[0] ? 0 : a:i1[0] > a:i2[0] ? 1 : -1
endfunction

function! s:find_mappings(action_holder) abort
  try
    redir => content
    silent execute 'map'
  finally
    redir END
  endtry
  let rhss = filter(
        \ map(values(a:action_holder.actions), 'v:val.mapping'),
        \ '!empty(v:val)'
        \)
  let rhsp = printf('\%%(%s\)', join(map(rhss, 'escape(v:val, "\\")'), '\|'))
  let rows = filter(split(content, '\r\?\n'), 'v:val =~# "@.*" . rhsp')
  let pattern = '\(...\)\(\S\+\)'
  let mappings = {}
  for row in rows
    let [mode, lhs] = matchlist(row, pattern)[1 : 2]
    let rhs = matchstr(row, rhsp)
    let mappings[rhs] = {
          \ 'mode': mode,
          \ 'lhs': lhs,
          \ 'rhs': rhs,
          \}
  endfor
  return mappings
endfunction

function! s:build_help(action_holder) abort
  let mappings = s:find_mappings(a:action_holder)
  let rows = []
  let longest1 = 0
  let longest2 = 0
  let longest3 = 0
  for [name, action] in items(a:action_holder.actions)
    let alias = action.alias
    let lhs = ''
    let rhs = action.mapping
    let mapping = get(mappings, action.mapping, {})
    if !empty(rhs) && !empty(mapping)
      let lhs = mapping.lhs
    endif
    call add(rows, [
          \ name,
          \ alias,
          \ action.description,
          \ rhs,
          \ lhs,
          \])
    let longest1 = len(alias) > longest1 ? len(alias) : longest1
    let longest2 = len(action.description) > longest2 ? len(action.description) : longest2
    let longest3 = len(rhs) > longest3 ? len(rhs) : longest3
  endfor

  let content = []
  let pattern = printf('%%-%ds : %%-%ds %%-%ds %%s', longest1, longest2, longest3)
  call add(content, printf(pattern, 'ACTION', 'DESCRIPTION', 'PLUG MAPPING', 'KEY MAPPING'))
  for [name, alias, description, rhs, lhs] in sort(rows, 's:compare')
    call add(content, printf(pattern, alias, description, rhs, lhs))
  endfor
  return content
endfunction

function! s:action_help(candidate, options) abort
  let action_holder = gita#action#get_holder()
  echo join(s:build_help(action_holder), "\n")
endfunction

function! s:action_choice(candidates, options) abort
  let action_holder = gita#action#get_holder()
  let g:gita#action#common#_aliases = join(keys(action_holder.aliases), "\n")
  call inputsave()
  try
    echohl Question
    redraw | echo
    let alias = input(
          \ 'action: ', '',
          \ 'custom,gita#action#common#_complete_alias'
          \)
    redraw | echo
  finally
    echohl None
    call inputrestore()
    silent! unlet! g:gita#action#common#_aliases
  endtry
  if empty(alias)
    return
  endif
  let action_name = action_holder.aliases[alias]
  call gita#action#do(action_name, a:candidates)
endfunction

function! s:action_close(candidate, options) abort
  let winnum = winnr()
  call s:Anchor.focus()
  execute printf('%dclose', winnum)
endfunction

function! s:action_redraw(candidate, options) abort
  if &filetype =~# '^gita-'
    let name = matchstr(&filetype, '^gita-\zs.*$')
    let name = substitute(name, '-', '_', 'g')
    call call(function(printf('gita#command#ui#%s#redraw', name)), [])
  endif
endfunction

function! gita#action#common#define(disable_mapping) abort
  call gita#action#define('common:help', function('s:action_help'), {
        \ 'alias': 'help',
        \ 'description': 'Show help',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('common:choice', function('s:action_choice'), {
        \ 'alias': 'choice',
        \ 'description': 'Select action to perform',
        \ 'options': {},
        \})
  call gita#action#define('common:close', function('s:action_close'), {
        \ 'alias': 'close',
        \ 'description': 'Close and focus an anchor',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('common:redraw', function('s:action_redraw'), {
        \ 'alias': 'redraw',
        \ 'description': 'Redraw the buffer',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait> ?     <Plug>(gita-help)
  nmap <buffer><nowait> <Tab> <Plug>(gita-choice)
  nmap <buffer><nowait> q     <Plug>(gita-close)
  nmap <buffer><nowait> <C-l> <Plug>(gita-redraw)
  vmap <buffer><nowait> <Tab> <Plug>(gita-choice)
endfunction


function! gita#action#common#_complete_alias(arglead, cmdline, cursorpos) abort
  return g:gita#action#common#_aliases
endfunction
