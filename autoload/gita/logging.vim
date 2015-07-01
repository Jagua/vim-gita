let s:save_cpo = &cpo
set cpo&vim

let s:L = gita#utils#import('System.Logging')

function! gita#logging#of(...) abort " {{{
  return call(s:L.of, a:000, s:L)
endfunction " }}}

" Configure
function! s:init() abort
  let logger = gita#logging#of()
  call logger.set_logfile(g:gita#logging#logfile)
  call logger.set_loglevel(g:gita#logging#loglevel)
endfunction
call s:init()

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker: