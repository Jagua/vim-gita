let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prelude = s:V.import('Prelude')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:WORKTREE = '@@'  " @@ is not valid commit thus

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  return s:Dict.pick(a:options, [
        \ 'unified',
        \ 'minimal',
        \ 'patience',
        \ 'histogram',
        \ 'diff-algorithm',
        \ 'submodule',
        \ 'word-diff-regex',
        \ 'no-renames',
        \ 'full-index',
        \ 'binary',
        \ 'abbrev',
        \ 'B',
        \ 'M',
        \ 'C',
        \ 'find-copies-harder',
        \ 'irreversible-delete',
        \ 'l',
        \ 'diff-filter',
        \ 'S',
        \ 'G',
        \ 'pickaxe-all',
        \ 'O',
        \ 'R',
        \ 'relative',
        \ 'text',
        \ 'ignore-space-at-eol',
        \ 'ignore-space-change',
        \ 'ignore-all-space',
        \ 'ignore-blank-lines',
        \ 'inter-hunk-context',
        \ 'function-context',
        \ 'ignore-submodules',
        \ 'src-prefix',
        \ 'dst-prefix',
        \ 'no-prefix',
        \ 'numstat',
        \ 'no-index',
        \ 'cached',
        \])
endfunction
function! s:get_diff_content(git, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['R'] = get(a:options, 'reverse', 0)
  let options['no-color'] = 1
  let options['commit'] = a:commit
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'diff', options)
  if result.status && !get(options, 'no-index') && !get(options, 'exit-code')
    " NOTE:
    " --no-index force --exit-code option.
    " --exit-code mean that the program exits with 1 if there were differences
    " and 0 means no differences
    call s:GitProcess.throw(result.stdout)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#diff#call(...) abort
  let options = gita#option#cascade('^diff$', get(a:000, 0, {}), {
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \ 'filenames': [],
        \})
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'gita#variable#get_valid_filename(v:val)'
          \)
  endif
  if !empty(options.filename)
    call insert(
          \ filenames,
          \ gita#variable#get_valid_filename(options.filename)
          \)
    " remove duplicate filenames
    let filenames = uniq(filenames)
  endif
  let content = s:get_diff_content(git, commit, filenames, options)
  let result = {
        \ 'commit': commit,
        \ 'filename': empty(filenames) ? '' : filenames[0],
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita diff',
          \ 'description': 'Show changes between commits, commit and working tree, etc',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<path>',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--unified', '-U',
          \ 'generate diffs with <N> lines of context', {
          \   'pattern': '^\d\+$',
          \})
    call s:parser.add_argument(
          \ '--minimal',
          \ 'spend extra time to make sure the smallest possible diff is produced', {
          \   'conflicts': ['patience', 'histogram', 'diff-algorithm'],
          \})
    call s:parser.add_argument(
          \ '--patience',
          \ 'generate a diff using the "patience diff" algorithm', {
          \   'conflicts': ['minimal', 'histogram', 'diff-algorithm'],
          \})
    call s:parser.add_argument(
          \ '--histogram',
          \ 'generate a diff using the "histogram diff" algorithm', {
          \   'conflicts': ['minimal', 'patience', 'diff-algorithm'],
          \})
    call s:parser.add_argument(
          \ '--diff-algorithm', [
          \   'choices a diff algorighm. the variants are as follows:',
          \   '- myres     the basic greedy diff algorithm',
          \   '- minimal   spend extra time to make sure the smallest possible diff is produced',
          \   '- patience  use "patience diff" algorithm',
          \   '- histogram this algorithm extends the patience algorithm to "support low-occurrence common elements"',
          \ ], {
          \   'choices': ['default', 'myres', 'minimal', 'patience', 'histogram'],
          \   'conflicts': ['minimal', 'patience', 'histogram'],
          \ }
          \)
    call s:parser.add_argument(
          \ '--submodule', [
          \   'specify how differences in submodules are shown.',
          \   '- log       lists the commits in the range like git-submodule summary does',
          \   '- short     shows the name of the commits at the beginning and end of the range',
          \ ], {
          \   'on_default': 'log',
          \   'choices': ['log', 'short'],
          \   'conflicts': ['ignore-submodules'],
          \ }
          \)
    call s:parser.add_argument(
          \ '--ignore-submodules', [
          \   'ignore changes to submodules in the diff generation',
          \   '- none       consider the submodule modified when it either contains untracked or modified files or its HEAD differs',
          \   '- untracked  submodules are not considered dirty when they only contain untracked content',
          \   '- dirty      ignores all changes to the work tree of submodules',
          \   '- all        hides all changes to submodules',
          \ ], {
          \   'on_default': 'all',
          \   'choices': ['none', 'untracked', 'dirty', 'all'],
          \   'conflicts': ['submodule'],
          \ }
          \)
    "call s:parser.add_argument(
    "      \ '--word-diff',
    "      \ 'WIP: show a word diff', {
    "      \   'on_default': 'plain',
    "      \   'choices': ['color', 'plain', 'porcelain', 'none'],
    "      \   'conflicts': ['--color-words'],
    "      \})
    "call s:parser.add_argument(
    "      \ '--word-diff-regex',
    "      \ 'use regex to decide what a word is instead of considering runs of non-whitespace to be a word', {
    "      \   'type': s:ArgumentParser.types.value,
    "      \})
    "call s:parser.add_argument(
    "      \ '--color-words',
    "      \ 'WIP: equivalent to --word-diff=color plus (if aregex was specified)', {
    "      \   'type': s:ArgumentParser.types.value,
    "      \})
    call s:parser.add_argument(
          \ '--no-renames',
          \ 'turn off rename detection',
          \)
    call s:parser.add_argument(
          \ '--check',
          \ 'warn if changes introduce whitespace errors.',
          \)
    call s:parser.add_argument(
          \ '--full-index',
          \ 'instead of the first handful of characters, show the full pre- and post-image blob object names on the "index" line',
          \)
    call s:parser.add_argument(
          \ '--binary',
          \ 'in addition to --full-index, output a binary diff that can be applied with git-apply',
          \)
    call s:parser.add_argument(
          \ '-B',
          \ 'break complete rewrite changes into pairs of delete and create.', {
          \   'pattern': '^\d\+\(/\d\+\)\?$',
          \})
    call s:parser.add_argument(
          \ '--find-renames', '-M',
          \ 'detect renames. if <n> is specified, it is a threshold on the similarity index', {
          \   'on_default': '50%',
          \   'pattern': '^\d\+%\?$',
          \})
    call s:parser.add_argument(
          \ '--find-copies', '-C',
          \ 'detect copies as well as renames. it has the same meaning as for -M<n>', {
          \   'on_default': '50%',
          \   'pattern': '^\d\+%\?$',
          \})
    call s:parser.add_argument(
          \ '--find-copies-harder',
          \ 'try harder to find copies. this is a very expensive operation for large projects',
          \)
    call s:parser.add_argument(
          \ '--irreversible-delete', '-D',
          \ 'omit the preimage for deletes, i.e. print only the header but not the diff between the preivmage and /dev/null.',
          \)
    call s:parser.add_argument(
          \ '-S',
          \ 'look for differences that change the number of occurrences of the specified string in a file', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '-G',
          \ 'look for differences whose patch text contains added/removed lines that match regex', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--pickaxe-all',
          \ 'when -S or -G finds a change, show all the changes in that changeset, not just the files', {
          \   'superordinates': ['S', 'G'],
          \})
    call s:parser.add_argument(
          \ '--pickaxe-regex',
          \ 'treat the string given to -S as an extended POSIX regular expression to match', {
          \   'superordinates': ['S'],
          \})
    call s:parser.add_argument(
          \ '--reverse', '-R',
          \ 'swap two inputs; that is, show differences from index or on-disk file to tree contents',
          \)
    call s:parser.add_argument(
          \ '--relative',
          \ 'make path relative to the specified path', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--text', '-a',
          \ 'treat all files as text',
          \)
    call s:parser.add_argument(
          \ '--ignore-space-at-eol',
          \ 'ignore changes in whitespace at EOL',
          \)
    call s:parser.add_argument(
          \ '--ignore-space-change', '-b',
          \ 'ignore changes in amount of whitespace',
          \)
    call s:parser.add_argument(
          \ '--ignore-all-space', '-w',
          \ 'ignore whitespace when comparing lines',
          \)
    call s:parser.add_argument(
          \ '--ignore-blank-lines',
          \ 'ignore changes whose lines are all blank',
          \)
    call s:parser.add_argument(
          \ '--inter-hunk-context',
          \ 'show the context between diff hunks, up to the specified number of lines', {
          \   'pattern': '^\d\+$',
          \})
    call s:parser.add_argument(
          \ '--function-context', '-W',
          \ 'show whole surarounding functions of changes',
          \)
    call s:parser.add_argument(
          \ '--src-prefix',
          \ 'show the given source prefix instead of "a/"', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--dst-prefix',
          \ 'show the given destination prefix instead of "a/"', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--no-prefix',
          \ 'do not show any source or destination prefix',
          \)
    call s:parser.add_argument(
          \ '--repository',
          \ 'show a diff of the repository instead of a file content',
          \)
    call s:parser.add_argument(
          \ '--selection',
          \ 'a line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'compare with a content in the index',
          \)
    call s:parser.add_argument(
          \ '--ui',
          \ 'show a buffer instead of echo the result. imply --quiet', {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \   'superordinates': ['ui'],
          \})
    call s:parser.add_argument(
          \ '--split', '-s', [
          \   'open two buffer to compare by vimdiff rather than to open a single diff file.',
          \   'see ":help &diffopt" if you would like to control default split direction',
          \], {
          \   'superordinates': ['ui'],
          \})
    call s:parser.add_argument(
          \ '--patch',
          \ 'diff a content in PATCH mode. most of options will be disabled', {
          \   'superordinates': ['ui'],
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit which you want to diff.',
          \   'if nothing is specified, it diff a content between an index and working tree or HEAD when --cached is specified.',
          \   'if <commit> is specified, it diff a content between the named <commit> and working tree or an index.',
          \   'if <commit1>..<commit2> is specified, it diff a content between the named <commit1> and <commit2>',
          \   'if <commit1>...<commit2> is specified, it diff a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    " TODO: Add more arguments
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'repository')
        let a:options.filename = ''
        unlet a:options.repository
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#diff#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#diff#default_options),
        \ options,
        \)
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#diff#open(options)
  else
    call gita#command#diff#call(options)
  endif
endfunction
function! gita#command#diff#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#diff', {
      \ 'default_options': {},
      \})
