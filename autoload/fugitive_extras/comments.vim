function! fugitive_extras#comments#target() abort
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

" The branch comments are on: the one this tab's :BranchDiff compares, else
" the checked-out one. origin/feature is feature, so its comments are found
" again after checking it out.
function! fugitive_extras#comments#scope() abort
  let l:compare = fugitive_extras#compares#current()
  if empty(get(l:compare, 'head', '')) || l:compare.dir !=# FugitiveGitDir()
    return FugitiveHead(7)
  endif
  let l:ref = FugitiveExecute(['rev-parse', '--symbolic-full-name', l:compare.head])
  let l:full = get(l:ref.stdout, 0, '')
  return l:ref.exit_status == 0 && l:full =~# '^refs/\%(heads\|remotes/[^/]\+\)/'
        \ ? substitute(l:full, '^refs/\%(heads\|remotes/[^/]\+\)/', '', '')
        \ : l:compare.head
endfunction

function! fugitive_extras#comments#save_dir() abort
  " In the git dir shared by all work trees, so saves are never committed
  let l:common = FugitiveCommonDir()
  let l:head = fugitive_extras#comments#scope()
  return empty(l:common) || empty(l:head) ? ''
        \ : l:common . '/vim-review/' . l:head
endfunction

function! fugitive_extras#comments#check() abort
  if exists('g:loaded_review')
    call review#check()
  endif
endfunction
