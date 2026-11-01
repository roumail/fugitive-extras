function! s:target() abort
  if empty(FugitiveWorkTree())
    " vim-review's default applies
    return {}
  endif
  let l:path = FugitivePath(@%, '')
  if empty(l:path) || l:path =~# '^/'
    return {'error': 'not a file in the git work tree'}
  endif
  if @% =~# '^fugitive://' && fugitive_extras#is_base(FugitiveParse(@%)[0])
    return {'error': 'comment on the branch side of the diff, not the merge-base'}
  endif
  return {'path': l:path}
endfunction

function! s:save_dir() abort
  " In the git dir shared by all work trees, so saves are never committed
  let l:common = FugitiveCommonDir()
  let l:head = FugitiveHead(7)
  return empty(l:common) || empty(l:head) ? ''
        \ : l:common . '/vim-review/' . l:head
endfunction

function! fugitive_extras#comments#init() abort
  call review#use({
        \ 'root': function('FugitiveWorkTree'),
        \ 'target': function('s:target'),
        \ 'save_dir': function('s:save_dir'),
        \ 'scope': function('FugitiveHead', [7]),
        \ })
endfunction

function! fugitive_extras#comments#check() abort
  if exists('g:loaded_review')
    call review#check()
  endif
endfunction
