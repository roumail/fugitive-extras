" dir is the git dir, so each work tree has its own comparisons
let s:compares = []

function! s:key(compare) abort
  return {'dir': a:compare.dir, 'name': a:compare.name}
endfunction

function! s:tabs(compare) abort
  return map(filter(gettabinfo(),
        \ {_, t -> get(t.variables, 'fugitive_extras_compare', {}) == s:key(a:compare)}), 'v:val.tabnr')
endfunction

" The name for a new comparison of branch: one of its comparisons with no tabs
" left, else branch, branch#2, ... whichever is free
function! s:name(dir, branch) abort
  let l:same = filter(copy(s:compares), 'v:val.dir ==# a:dir')
  for l:compare in l:same
    if l:compare.branch ==# a:branch && empty(s:tabs(l:compare))
      return l:compare.name
    endif
  endfor
  let l:taken = map(l:same, 'v:val.name')
  let l:name = a:branch
  let l:n = 2
  while index(l:taken, l:name) >= 0
    let l:name = a:branch . '#' . l:n
    let l:n += 1
  endwhile
  return l:name
endfunction

" Opens a new comparison of branch, or with a name, opens that one again
function! fugitive_extras#compares#open(dir, branch, base, head, ...) abort
  let l:name = a:0 ? a:1 : s:name(a:dir, a:branch)
  let l:win = win_getid()
  " Windows open before: the tabs with none of them are the new ones, wherever
  " fugitive put them
  let l:before = {}
  for l:tab in gettabinfo()
    for l:id in l:tab.windows
      let l:before[l:id] = 1
    endfor
  endfor
  " :Git in that repo, whichever buffer this is
  execute fugitive#Command(line('.'), -1, 0, 0, '', 'difftool -y ' . a:base . ' ' . a:head, a:dir)
  let l:new = []
  for l:tab in gettabinfo()
    if empty(filter(copy(l:tab.windows), 'has_key(l:before, v:val)'))
      call add(l:new, l:tab.tabnr)
    endif
  endfor
  let l:files = len(l:new)
  if !l:files
    echo 'fugitive-extras: no changes in ' . a:branch
    return
  endif
  let l:old = filter(copy(s:compares),
        \ 'v:val.dir ==# a:dir && v:val.name ==# l:name')
  if !empty(l:old) && l:old[0].base ==# a:base && l:old[0].head ==# a:head
    " The same diff again: its tabs still open stay in it
    call remove(s:compares, index(s:compares, l:old[0]))
  else
    call fugitive_extras#compares#remove(a:dir, l:name)
  endif
  let l:compare = {'dir': a:dir, 'name': l:name, 'branch': a:branch, 'base': a:base,
        \ 'head': a:head, 'files': l:files, 'time': localtime(), 'win': l:win}
  call add(s:compares, l:compare)
  for l:tab in l:new
    call settabvar(l:tab, 'fugitive_extras_compare', s:key(l:compare))
  endfor
endfunction

function! fugitive_extras#compares#list(...) abort
  let l:dir = a:0 ? a:1 : FugitiveGitDir()
  let l:list = []
  for l:compare in reverse(filter(copy(s:compares), 'v:val.dir ==# l:dir'))
    call add(l:list, extend(copy(l:compare), {'tabs': s:tabs(l:compare)}))
  endfor
  return l:list
endfunction

function! fugitive_extras#compares#remove(dir, name) abort
  for l:compare in filter(copy(s:compares),
        \ 'v:val.dir ==# a:dir && v:val.name ==# a:name')
    for l:tab in s:tabs(l:compare)
      call remove(gettabvar(l:tab, ''), 'fugitive_extras_compare')
    endfor
    call remove(s:compares, index(s:compares, l:compare))
  endfor
endfunction

function! s:find(key) abort
  return get(filter(copy(s:compares), 's:key(v:val) ==# a:key'), 0, {})
endfunction

" The comparison this tab is in, or {}
function! fugitive_extras#compares#current() abort
  return s:find(get(t:, 'fugitive_extras_compare', {}))
endfunction

function! fugitive_extras#compares#close(name) abort
  let l:compare = empty(a:name) ? fugitive_extras#compares#current()
        \ : s:find({'dir': FugitiveGitDir(), 'name': a:name})
  if empty(l:compare)
    call fugitive_extras#error('no comparison ' . a:name . ' in :Compares')
    return
  endif
  let l:tabs = s:tabs(l:compare)
  if empty(l:tabs)
    echo 'fugitive-extras: no tabs of ' . l:compare.name . ' open'
    return
  endif
  let l:from = index(l:tabs, tabpagenr()) >= 0
  if len(l:tabs) == tabpagenr('$')
    " Vim keeps one tab: an empty one
    $tabnew
  endif
  let l:left = 0
  for l:tab in reverse(l:tabs)
    try
      execute l:tab . 'tabclose'
    catch
      " A file changed and not written
      let l:left += 1
    endtry
  endfor
  if l:from
    call win_gotoid(l:compare.win)
  endif
  if l:left
    call fugitive_extras#error(l:left . ' tab(s) of ' . l:compare.name
          \ . ' left open: unsaved changes')
  endif
endfunction

function! fugitive_extras#compares#complete(lead, cmdline, pos) abort
  return filter(map(fugitive_extras#compares#list(), 'v:val.name'),
        \ 'stridx(v:val, a:lead) == 0')
endfunction


function! s:render() abort
  let b:fugitive_extras_compares = fugitive_extras#compares#list(b:fugitive_extras_dir)
  let l:lines = ['Comparisons (' . len(b:fugitive_extras_compares) . ')  <CR> open  d remove  r refresh  q close']
  for l:c in b:fugitive_extras_compares
    let l:seconds = localtime() - l:c.time
    call add(l:lines, printf('%-30.30s %s..%-24.24s %3d files %3d open  %s', l:c.name,
          \ l:c.base[:6], empty(l:c.head) ? 'work tree' : l:c.head, l:c.files, len(l:c.tabs),
          \ l:seconds < 60 ? l:seconds . 's'
          \ : l:seconds < 3600 ? (l:seconds / 60) . 'm'
          \ : (l:seconds / 3600) . 'h'))
  endfor
  setlocal modifiable
  silent %delete _
  call setline(1, l:lines)
  setlocal nomodifiable nomodified
  execute 'resize' min([line('$'), 15])
  call cursor(2, 1)
endfunction

function! fugitive_extras#compares#show() abort
  let l:dir = FugitiveGitDir()
  let l:worktree = FugitiveWorkTree()
  if empty(l:worktree)
    call fugitive_extras#error('not in a git work tree')
    return
  endif
  let l:name = 'fugitive-extras://compares/' . fnamemodify(l:worktree, ':t')
  " A window of its own, so q and :q close only the list, never a window of yours
  let l:winnr = bufwinnr('^' . l:name . '$')
  if l:winnr > 0
    execute l:winnr . 'wincmd w'
  else
    execute 'silent botright split' fnameescape(l:name)
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile nowrap nobuflisted winfixheight
  nnoremap <buffer><silent> q <Cmd>call <SID>close()<CR>
  let b:fugitive_extras_dir = l:dir
  nnoremap <buffer><silent> <CR> <Cmd>call <SID>open()<CR>
  nnoremap <buffer><silent> d <Cmd>call <SID>remove()<CR>
  nnoremap <buffer><silent> r <Cmd>call <SID>render()<CR>
  call s:render()
endfunction

function! s:selected() abort
  return get(b:fugitive_extras_compares, line('.') - 2, {})
endfunction

function! s:open() abort
  let l:compare = s:selected()
  if empty(l:compare)
    return
  endif
  let l:dir = b:fugitive_extras_dir
  call s:close()
  call fugitive_extras#compares#open(l:dir, l:compare.branch, l:compare.base,
        \ l:compare.head, l:compare.name)
endfunction

function! s:remove() abort
  let l:compare = s:selected()
  if !empty(l:compare)
    call fugitive_extras#compares#remove(b:fugitive_extras_dir, l:compare.name)
    call s:render()
  endif
endfunction

function! s:close() abort
  if winnr('$') > 1
    close
  else
    enew
  endif
endfunction
