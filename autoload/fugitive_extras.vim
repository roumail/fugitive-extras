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

function! s:base(branch) abort
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
  let l:base = s:base('')
  if !empty(l:base)
    execute 'Gvdiffsplit' l:base
  endif
endfunction

function! s:is_commit(rev) abort
  return s:git(['rev-parse', '--verify', '--quiet', a:rev . '^{commit}']) isnot v:null
endfunction

function! fugitive_extras#branch_diff(branch) abort
  let l:base = s:base(a:branch)
  if !empty(l:base)
    call fugitive_extras#compares#open(FugitiveGitDir(),
          \ empty(a:branch) ? FugitiveHead(7) : a:branch, l:base, a:branch)
  endif
endfunction

function! fugitive_extras#branch_commits(args) abort
  let l:first = matchstr(a:args, '^\S\+')
  let l:branch = 'HEAD'
  let l:rest = a:args
  if !empty(l:first) && l:first !~# '^-' && s:is_commit(l:first)
    let l:branch = l:first
    let l:rest = substitute(a:args, '^\S\+\s*', '', '')
  endif
  let l:base = s:base(l:branch)
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
