function! s:git(args) abort
  let l:result = FugitiveExecute(a:args)
  if l:result.exit_status != 0
    return v:null
  endif
  return filter(copy(l:result.stdout), '!empty(v:val)')
endfunction

function! fugitive_extras#error(msg) abort
  echohl ErrorMsg
  echomsg 'fugitive-extras: ' . a:msg
  echohl None
endfunction

" Whether the plugin with the autoload file autoload/{name}.vim is installed:
" the commands that use one check for it first
function! fugitive_extras#installed(name) abort
  return !empty(globpath(&runtimepath, 'autoload/' . a:name . '.vim', 1))
endfunction

" The same, saying what needs the plugin when it isn't installed
function! fugitive_extras#requires(what, plugin, name) abort
  if fugitive_extras#installed(a:name)
    return 1
  endif
  call fugitive_extras#error(a:what . ' needs ' . a:plugin . ', which is not installed')
  return 0
endfunction

function! fugitive_extras#main_ref() abort
  " The remote ref first: the local branch is often stale after a fetch or a
  " `gh pr checkout`
  let l:head = s:git(['symbolic-ref', '--short', 'refs/remotes/origin/HEAD'])
  if !empty(l:head)
    return l:head[0]
  endif
  for l:ref in ['refs/remotes/origin/main', 'refs/remotes/origin/master',
        \ 'refs/heads/main', 'refs/heads/master']
    if s:git(['show-ref', '--verify', '--quiet', l:ref]) isnot v:null
      return substitute(l:ref, '^refs/\%(remotes\|heads\)/', '', '')
    endif
  endfor
  return ''
endfunction

" The merge-base of branch (default HEAD) and main, or '' after saying why
function! fugitive_extras#base(branch) abort
  if empty(FugitiveGitDir())
    call fugitive_extras#error('not in a git repository')
    return ''
  endif
  let l:branch = empty(a:branch) ? 'HEAD' : a:branch
  if !s:is_commit(l:branch)
    call fugitive_extras#error('unknown branch ' . l:branch . ' (:Git fetch?)')
    return ''
  endif
  let l:main = fugitive_extras#main_ref()
  if empty(l:main)
    call fugitive_extras#error('no origin/HEAD, main or master found')
    return ''
  endif
  let l:base = s:git(['merge-base', l:branch, l:main])
  if empty(l:base)
    call fugitive_extras#error('no merge-base between ' . l:branch . ' and ' . l:main)
    return ''
  endif
  let s:bases[l:base[0]] = 1
  return l:base[0]
endfunction

" Merge-bases these commands have diffed against, to tell a diff's base side
let s:bases = {}

function! fugitive_extras#is_base(rev) abort
  return has_key(s:bases, matchstr(a:rev, '^\x\{40,}'))
endfunction

function! fugitive_extras#diff_this(bang) abort
  if !a:bang
    Gvdiffsplit
    return
  endif
  let l:base = fugitive_extras#base('')
  if !empty(l:base)
    execute 'Gvdiffsplit' l:base
  endif
endfunction

function! s:is_commit(rev) abort
  return s:git(['rev-parse', '--verify', '--quiet', a:rev . '^{commit}']) isnot v:null
endfunction

" The branch's commits since the merge-base; with worktree, the checked-out
" branch's work tree instead, uncommitted changes and all
function! fugitive_extras#branch_diff(branch, ...) abort
  let l:worktree = a:0 && a:1
  if l:worktree && !empty(a:branch)
    call fugitive_extras#error(':BranchDiff! is the work tree of the checked-out branch: no branch')
    return
  endif
  let l:base = fugitive_extras#base(a:branch)
  if empty(l:base)
    return
  endif
  " The checked-out branch by name, so the comparison stays on it after a
  " checkout and a refresh takes its new commits
  let l:head = !empty(a:branch) ? a:branch : l:worktree ? ''
        \ : !empty(FugitiveHead()) ? FugitiveHead() : s:git(['rev-parse', 'HEAD'])[0]
  call fugitive_extras#compares#open(FugitiveGitDir(),
        \ empty(a:branch) ? FugitiveHead(7) : a:branch, l:base, l:head)
endfunction

" A comparison again from a new merge-base, as :BranchDiff would open it now;
" another diff, both sides read again
function! fugitive_extras#diff_refresh() abort
  " Buffers changed outside Vim, as an agent leaves them, read again without
  " asking: not those with unsaved changes
  let l:autoread = &autoread
  set autoread
  try
    silent! checktime
  finally
    let &autoread = l:autoread
  endtry
  if has_key(t:, 'fugitive_extras_compare')
    call fugitive_extras#compares#refresh()
    return
  endif
  for l:win in range(1, winnr('$'))
    let l:buf = winbufnr(l:win)
    if bufname(l:buf) =~# '^fugitive://' && !getbufvar(l:buf, '&modified')
      call win_execute(win_getid(l:win), 'silent edit')
    endif
  endfor
  diffupdate
endfunction

function! fugitive_extras#branch_commits(args) abort
  if !fugitive_extras#requires(':BranchCommits', 'vim-lists', 'roumail_lists')
    return
  endif
  let l:first = matchstr(a:args, '^\S\+')
  let l:branch = 'HEAD'
  let l:rest = a:args
  if !empty(l:first) && l:first !~# '^-' && s:is_commit(l:first)
    let l:branch = l:first
    let l:rest = substitute(a:args, '^\S\+\s*', '', '')
  endif
  let l:base = fugitive_extras#base(l:branch)
  if empty(l:base)
    return
  endif
  try
    " % and # are this buffer's file, as on any command line
    let l:args = split(expandcmd(l:rest))
  catch
    call fugitive_extras#error(v:exception)
    return
  endtry
  call fugitive_extras#commits#show(l:branch, l:base, l:args)
endfunction

function! fugitive_extras#complete_branch(lead, cmdline, pos) abort
  let l:refs = s:git(['for-each-ref', '--sort=-committerdate',
        \ '--format=%(refname)', 'refs/heads', 'refs/remotes'])
  if l:refs is v:null
    return []
  endif
  " Skip origin/HEAD, an alias of the default branch
  call filter(l:refs, 'v:val !~# "^refs/remotes/[^/]\\+/HEAD$"')
  call map(l:refs, 'substitute(v:val, "^refs/\\%(heads\\|remotes\\)/", "", "")')
  return filter(l:refs, 'stridx(v:val, a:lead) == 0')
endfunction

function! fugitive_extras#complete_commits(lead, cmdline, pos) abort
  if strpart(a:cmdline, 0, a:pos) =~# '^\S\+\s\+\S*$'
    return fugitive_extras#complete_branch(a:lead, a:cmdline, a:pos)
  endif
  return getcompletion(a:lead, 'file')
endfunction

function! fugitive_extras#diff_close(name) abort
  if !empty(a:name) || has_key(t:, 'fugitive_extras_compare')
    call fugitive_extras#compares#close(a:name)
    return
  endif
  for l:win in reverse(range(1, winnr('$')))
    if bufname(winbufnr(l:win)) =~# '^fugitive://' && winnr('$') > 1
      execute l:win . 'close'
    endif
  endfor
  diffoff!
endfunction
