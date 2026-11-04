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
  " Once a session per repository, as saves are kept per branch: those of
  " branches deleted outside Vim go too
  let l:common = FugitiveCommonDir()
  if !empty(l:common) && !has_key(s:pruned, l:common)
    call fugitive_extras#comments#prune()
  endif
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

" Common git dirs pruned this session
let s:pruned = {}

" Deletes vim-review's saves of branches gone from the current repository:
" neither a local branch nor any remote's (origin/feature keeps
" feature's), nor anything else that names a commit (a tag, or the commit
" saves of a detached HEAD are under). A deleted branch's remote one goes on
" a fetch with --prune, or once GitHub deletes it after a merge.
function! fugitive_extras#comments#prune() abort
  let l:common = FugitiveCommonDir()
  if empty(l:common) || !exists('g:loaded_review')
    return
  endif
  let s:pruned[l:common] = 1
  " Where vim-review keeps its saves, as vim-draft says
  let l:root = roumail_draft#dir('vim-review')
  let l:refs = FugitiveExecute(['for-each-ref', '--format=%(refname)'], l:common)
  if l:refs.exit_status != 0
    return
  endif
  let l:names = {}
  for l:ref in l:refs.stdout
    let l:names[substitute(l:ref, '^refs/\%(heads\|tags\|remotes/[^/]\+\)/', '', '')] = 1
  endfor
  let l:dirs = {}
  for l:file in glob(l:root . '/**/*.txt', 1, 1)
    let l:dirs[fnamemodify(l:file, ':h')] = 1
  endfor
  let l:gone = []
  for l:dir in keys(l:dirs)
    let l:name = strpart(l:dir, len(l:root) + 1)
    if has_key(l:names, l:name) || FugitiveExecute(['rev-parse', '--verify', '--quiet',
          \ l:name . '^{commit}'], l:common).exit_status == 0
      continue
    endif
    " Its files only: feature/x's saves may be under feature's
    for l:file in glob(l:dir . '/*.txt', 1, 1) + glob(l:dir . '/*.txt.anchors', 1, 1)
      call delete(l:file)
    endfor
    while l:dir !=# l:root && delete(l:dir, 'd') == 0
      let l:dir = fnamemodify(l:dir, ':h')
    endwhile
    call add(l:gone, l:name)
  endfor
  if !empty(l:gone)
    echomsg 'fugitive-extras: removed the saved comments of deleted branches: '
          \ . join(sort(l:gone), ', ')
  endif
endfunction

function! fugitive_extras#comments#check() abort
  if exists('g:loaded_review')
    call review#check()
  endif
endfunction
