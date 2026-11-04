" :BranchCommits: the commits on a branch that main lacks, as a vim-lists list

" Fields for the list, then the line shown, which git pads to columns
let s:format = '--format=%H%x1f%an%x1f%s%x1f%h  %<(18,trunc)%an  %<(15,trunc)%cr  %s%d'

" args: what picks the commits (--author=..., -- paths), split already
function! fugitive_extras#commits#show(branch, base, args) abort
  let l:worktree = FugitiveWorkTree()
  " Paths as given are relative to here; git runs in the work tree
  let l:args = map(copy(a:args), {_, a -> a !~# '^-'
        \ && (filereadable(a) || isdirectory(a)) ? fnamemodify(a, ':p') : a})
  let l:dashes = index(l:args, '--')
  call roumail_lists#open('fugitive-extras://commits/' . fnamemodify(l:worktree, ':t'), {
        \ 'fetch': function('s:fetch'), 'heading': function('s:heading'),
        \ 'rows': {commits -> map(copy(commits), {_, c -> {'item': c, 'lines': [c.line]}})},
        \ 'id': {c -> c.sha}, 'match': {c -> c.subject . ' ' . c.author . ' ' . c.sha[:6]},
        \ 'keys': [{'key': '<CR>', 'hint': 'commit', 'call': function('s:open')}]}, {
        \ 'fugitive_extras_dir': FugitiveGitDir(),
        \ 'fugitive_extras_branch': a:branch,
        \ 'fugitive_extras_name': a:branch ==# 'HEAD' ? FugitiveHead(7) : a:branch,
        \ 'fugitive_extras_main': fugitive_extras#main_ref(),
        \ 'fugitive_extras_base': a:base,
        \ 'fugitive_extras_options': l:dashes < 0 ? l:args
        \   : l:dashes == 0 ? [] : l:args[: l:dashes - 1],
        \ 'fugitive_extras_paths': l:dashes < 0 ? [] : l:args[l:dashes :],
        \ })
endfunction

function! s:fetch() abort
  " The format last, so an option given can't change the lines
  let l:result = FugitiveExecute(['log'] + b:fugitive_extras_options
        \ + ['--no-color', s:format, b:fugitive_extras_base . '..' . b:fugitive_extras_branch]
        \ + b:fugitive_extras_paths, b:fugitive_extras_dir)
  if l:result.exit_status != 0
    call fugitive_extras#error('git log: ' . join(filter(copy(l:result.stderr), '!empty(v:val)'), ' '))
    return v:null
  endif
  let l:commits = []
  for l:line in l:result.stdout
    let l:f = split(l:line, "\x1f", 1)
    " Lines an option adds (--stat) aren't commits
    if len(l:f) == 4
      call add(l:commits, {'sha': l:f[0], 'author': l:f[1], 'subject': l:f[2], 'line': l:f[3]})
    endif
  endfor
  return l:commits
endfunction

function! s:heading(commits) abort
  return ['Commits on ' . b:fugitive_extras_name . ' not on ' . b:fugitive_extras_main
        \ . ' (' . len(a:commits) . ')']
endfunction

" The commit in fugitive, in the window above
function! s:open() abort
  let l:commit = roumail_lists#item()
  if empty(l:commit)
    return
  endif
  let l:file = FugitiveFind(l:commit.sha, b:fugitive_extras_dir)
  if winnr('$') == 1
    aboveleft split
  else
    wincmd p
  endif
  execute 'edit' fnameescape(l:file)
endfunction
