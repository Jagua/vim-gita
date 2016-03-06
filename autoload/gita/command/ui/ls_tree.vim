let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:candidate_offset = 0

function! s:get_candidate(index) abort
  let index = a:index - s:candidate_offset
  let candidates = gita#meta#get('candidates', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#command#ui#ls_tree#disable_default_mappings)
  if g:gita#command#ui#ls_tree#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#ls_tree#default_action_mapping
        \)
endfunction

function! s:extend_filename(git, commit, filename) abort
  let candidate = {}
  let candidate.relpath = a:filename
  let candidate.path = s:Git.get_absolute_path(
        \ a:git, s:Path.realpath(a:filename),
        \)
  let candidate.commit = a:commit
  return candidate
endfunction

function! s:get_header_string(git) abort
  let commit = gita#meta#get('commit', '')
  let candidates = gita#meta#get('candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files in <%s> (%d file%s) %s',
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction


function! gita#command#ui#ls_tree#BufReadCmd(options) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^ls-tree$', a:options, {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})
  let options['full-name'] = 1
  let options['name-only'] = 1
  let options['r'] = 1
  let options['quiet'] = 1
  let result = gita#command#ls_tree#call(options)
  let candidates = map(
        \ copy(result.content),
        \ 's:extend_filename(git, result.commit, v:val)'
        \)
  call gita#meta#set('content_type', 'ls-tree')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener',
        \]))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('candidates', candidates)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-tree
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#ui#ls_tree#redraw()
endfunction

function! gita#command#ui#ls_tree#bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \}, a:options)
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit)
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'ls-tree',
        \ 'extra_options': [
        \ ],
        \ 'commitish': commit,
        \ 'path': '',
        \})
endfunction

function! gita#command#ui#ls_tree#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let bufname = gita#command#ui#ls_tree#bufname(options)
  if empty(bufname)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#ls_tree#default_opener
        \ : options.opener
  if options.anchor && s:Anchor.is_available(opener)
    call s:Anchor.focus()
  endif
  try
    let g:gita#var = options
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': 'manipulation_panel',
          \})
  finally
    silent! unlet! g:gita#vars
  endtry
  call gita#util#select(options.selection)
endfunction

function! gita#command#ui#ls_tree#redraw(...) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^ls-tree$', get(a:000, 0, {}), {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})
  let prologue = [s:get_header_string(git)]
  let candidates = gita#meta#get_for('ls-tree', 'candidates', [])
  let contents = map(copy(candidates), 'v:val.relpath')
  let s:candidate_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents), {
        \ 'encoding': options.encoding,
        \ 'fileformat': options.fileformat,
        \ 'bad': options.bad,
        \})
endfunction

function! gita#command#ui#ls_tree#define_highlights() abort
  highlight default link GitaComment    Comment
endfunction

function! gita#command#ui#ls_tree#define_syntax() abort
  syntax match GitaComment    /\%^.*$/
endfunction


call gita#util#define_variables('command#ui#ls_tree', {
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})
