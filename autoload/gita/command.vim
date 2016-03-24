let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:ArgumentParser = s:V.import('ArgumentParser')


function! s:normalize(name) abort
  return substitute(a:name, '-', '_', 'g')
endfunction

function! s:complete_action(arglead, cmdline, cursorpos, ...) abort
let candidates = filter([
      \ 'add',
      \ 'apply',
      \ 'blame',
      \ 'branch',
      \ 'browse',
      \ 'chaperone',
      \ 'checkout',
      \ 'commit',
      \ 'diff',
      \ 'diff-ls',
      \ 'grep',
      \ 'ls-files',
      \ 'ls-tree',
      \ 'merge',
      \ 'patch',
      \ 'rebase',
      \ 'reset',
      \ 'rm',
      \ 'show',
      \ 'status',
      \ 'init',
      \ 'pull',
      \ 'push',
      \ 'stash',
      \ 'remote',
      \ 'tag',
      \ 'log',
      \], 'v:val =~# ''^'' . a:arglead')
  return candidates
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita',
          \ 'description': [
          \   'A git manipulation command',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'action', [
          \   'A name of a gita action (followings). If a non gita action is specified, git command will be called directly.',
          \   '',
          \   'add       : Add file contents to the index',
          \   'apply     : Apply a patch to files and/or to the index',
          \   'blame     : Show what revision and author last modified each line of a file',
          \   'branch    : List, create, or delete branches',
          \   'browse    : Browse a URL of the remote content',
          \   'chaperone : Compare differences and help to solve conflictions',
          \   'checkout  : Switch branches or restore working tree files',
          \   'commit    : Record changes to the repository',
          \   'diff      : Show changes between commits, commit and working tree, etc',
          \   'diff-ls   : Show a list of changed files between commits',
          \   'grep      : Print lines matching patterns',
          \   'ls-files  : Show information about files in the index and the working tree',
          \   'ls-tree   : List the contents of a tree object',
          \   'merge     : Join two or more development histories together',
          \   'patch     : Partially add/reset changes to/from index',
          \   'rebase    : Forward-port local commits to the update upstream head',
          \   'reset     : Reset current HEAD to the specified state',
          \   'rm        : Remove files from the working tree and from the index',
          \   'show      : Show a content of a commit or a file',
          \   'status    : Show and manipulate s status of the repository',
          \   '',
          \   'Note that each sub-commands also have -h/--help option',
          \ ], {
          \   'required': 1,
          \   'terminal': 1,
          \   'complete': function('s:complete_action'),
          \})
    " TODO: Write available actions
  endif
  return s:parser
endfunction

function! gita#command#execute(git, args, options) abort
  let options = extend({
        \ 'quiet': 0,
        \ 'fail_silently': 0,
        \}, a:options)
  let args = filter(copy(a:args), '!empty(v:val)')
  let result = s:GitProcess.execute(a:git, args, s:Dict.omit(options, [
        \ 'quiet', 'fail_silently'
        \]))
  if !options.fail_silently && !result.success
    call s:GitProcess.throw(result)
  elseif !options.quiet
    call s:Prompt.debug('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if !empty(options)
    let args  = join(options.__unknown__)
    let name  = get(options, 'action', '')
    try
      if a:bang !=# '!'
        try
          let fname = printf('gita#command#%s#command', s:normalize(name))
          return call(fname, [a:bang, a:range, args])
        catch /^Vim\%((\a\+)\)\=:E117/
          " fail silently
        endtry
      endif
      call gita#execute(
            \ gita#core#get(),
            \ s:ArgumentParser.splitargs(a:args),
            \)
      call gita#util#doautocmd('User', 'GitaStatusModified')
    catch /^\%(vital: Git[:.]\|vim-gita:\)/
      call gita#util#handle_exception()
    endtry
  endif
endfunction

function! gita#command#complete(arglead, cmdline, cursorpos) abort
  let bang    = a:cmdline =~# '\v^Gita!' ? '!' : ''
  let cmdline = substitute(a:cmdline, '\C^Gita!\?\s', '', '')
  let cmdline = substitute(cmdline, '[^ ]\+$', '', '')

  let parser  = s:get_parser()
  let options = parser.parse(bang, [0, 0], cmdline)
  if !empty(options)
    let name = get(options, 'action', '')
    try
      if bang !=# '!'
        try
          let fname = printf('gita#command#%s#complete', s:normalize(name))
          return call(fname, [a:arglead, cmdline, a:cursorpos])
        catch /^Vim\%((\a\+)\)\=:E117/
          " fail silently
        endtry
      endif
      " complete filename
      return gita#complete#filename(a:arglead, cmdline, a:cursorpos)
    catch /^\%(vital: Git[:.]\|vim-gita:\)/
      " fail silently
      call s:Prompt.debug(v:exception)
      call s:Prompt.debug(v:throwpoint)
      return []
    endtry
  endif
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
