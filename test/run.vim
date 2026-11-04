" Headless tests, from the repository's root:
"   vim -Nu NONE -i NONE -Es -S test/run.vim
" Prints one line per test and exits non-zero when one fails; TEST=<pattern>
" in the environment runs the tests whose names match. The plugins it needs
" are vim-plug's copies, unless $FUGITIVE, $VIM_DRAFT, $VIM_LISTS or $VIM_REVIEW name
" others.
set nocompatible hidden
execute 'set runtimepath^=' . fnameescape(expand('<sfile>:p:h:h'))
" Only these plugins: Vim's own ones aren't all quiet in silent Ex mode
for [s:var, s:name, s:file] in [['FUGITIVE', 'vim-fugitive', 'fugitive.vim'],
      \ ['VIM_DRAFT', 'vim-draft', 'roumail_draft.vim'],
      \ ['VIM_LISTS', 'vim-lists', 'roumail_lists.vim'],
      \ ['VIM_REVIEW', 'vim-review', 'review.vim']]
  let s:dir = fnamemodify(empty(eval('$' . s:var)) ? expand('~/.vim/plugged/' . s:name)
        \ : eval('$' . s:var), ':p:s?/$??')
  execute 'set runtimepath^=' . fnameescape(s:dir)
  execute 'source' fnameescape(s:dir . '/plugin/' . s:file)
endfor
execute 'source' fnameescape(expand('<sfile>:p:h:h') . '/plugin/fugitive_extras.vim')

let s:tmp = resolve(tempname())
let s:repo = s:tmp . '/repo'
let g:roumail_draft_save_dir = s:tmp . '/saves'
let s:out = []

function! s:git(...) abort
  call system('git -C ' . shellescape(s:repo) . ' -c user.name=t -c user.email=t@t '
        \ . join(map(copy(a:000), 'shellescape(v:val)')))
  " git ran outside fugitive, which caches HEAD by its time to the second: a
  " checkout in the same second as an earlier test's read of the same path
  " would keep the old branch. 0 expires it without a FugitiveChanged event
  call FugitiveDidChange(0)
endfunction

function! s:reset() abort
  silent! %bwipeout!
  CommentsClear
  call delete(s:tmp, 'rf')
  call mkdir(s:repo, 'p')
  call s:git('init', '-q', '-b', 'main')
  call writefile(['one', 'two', 'three'], s:repo . '/a.txt')
  call s:git('add', 'a.txt')
  call s:git('commit', '-q', '-m', 'init')
  execute 'cd' fnameescape(s:repo)
endfunction

function! s:saves(branch) abort
  return glob(s:repo . '/.git/fugitive-extras/comments/' . a:branch . '/*', 1, 1)
endfunction

function! s:test_save_and_load_back_where_the_lines_are() abort
  edit a.txt
  2Comment check this
  CommentsSave
  let l:saves = s:saves('main')
  call assert_equal(2, len(l:saves))
  call assert_match('/\d\{8}-\d\{6}\.txt$', l:saves[0])
  call assert_equal(['a.txt:2: check this'], readfile(l:saves[0]))
  call assert_equal(l:saves[0] . '.anchors', l:saves[1])

  CommentsClear
  call assert_equal([], fugitive_extras#comments#list())
  call writefile(['zero', 'one', 'two', 'three'], s:repo . '/a.txt')
  edit!
  CommentsLoad
  call assert_equal([{'path': 'a.txt', 'start': 3, 'end': 3, 'body': 'check this'}],
        \ fugitive_extras#comments#list())
endfunction

function! s:test_load_agent_comments() abort
  call writefile(['a.txt:1-2: from the agent', "\tsecond line"], s:tmp . '/agent.txt')
  edit a.txt
  execute 'CommentsLoad' fnameescape(s:tmp . '/agent.txt')
  call assert_equal([{'path': 'a.txt', 'start': 1, 'end': 2, 'body': "from the agent\nsecond line"}],
        \ fugitive_extras#comments#list())
endfunction

function! s:test_comments_outside_a_repository() abort
  for l:dir in ['notes', 'talks']
    call mkdir(s:tmp . '/' . l:dir)
    call writefile(['first', 'second'], s:tmp . '/' . l:dir . '/b.txt')
  endfor
  execute 'cd' fnameescape(s:tmp . '/notes')
  edit b.txt
  2Comment in notes
  CommentsSave
  CommentsClear
  CommentsLoad
  call assert_equal([{'path': 'b.txt', 'start': 2, 'end': 2, 'body': 'in notes'}],
        \ fugitive_extras#comments#list())
  " A file outside the current directory
  execute 'edit' fnameescape(s:tmp . '/talks/b.txt')
  call assert_equal("\nfugitive-extras: not a file under " . fnamemodify(s:tmp . '/notes', ':~'),
        \ execute('Comment elsewhere'))
  " Another directory's saves are its own
  CommentsClear
  execute 'cd' fnameescape(s:tmp . '/talks')
  call assert_equal("\nfugitive-extras: no saved comments", execute('CommentsLoad'))
endfunction

function! s:test_comments_per_branch() abort
  edit a.txt
  1Comment on main
  silent Git checkout -q -b feature
  call assert_equal("\nfugitive-extras: unsaved review comments from main (:CommentsSave)\nReview comments: 2",
        \ execute('2Comment on feature'))
  call fugitive_extras#comments#clear()
  2Comment on feature
  CommentsSave
  " Saved, so they leave the list with their branch
  call assert_match("\nfugitive-extras: saved review comments of feature left the list (:CommentsLoad on feature)$",
        \ execute('Git checkout -q main'))
  call assert_equal([], fugitive_extras#comments#list())
  1Comment on main
  CommentsSave
  CommentsClear
  CommentsLoad
  call assert_equal([{'path': 'a.txt', 'start': 1, 'end': 1, 'body': 'on main'}],
        \ fugitive_extras#comments#list())
  silent Git checkout -q feature
  call assert_equal([], fugitive_extras#comments#list())
  CommentsLoad
  call assert_equal([{'path': 'a.txt', 'start': 2, 'end': 2, 'body': 'on feature'}],
        \ fugitive_extras#comments#list())
endfunction

function! s:test_comment_changed_after_save_stays() abort
  edit a.txt
  silent Git checkout -q -b feature
  2Comment first
  CommentsSave
  Comments
  execute "normal c"
  call setline(1, 'changed')
  write
  quit
  call assert_match("\nfugitive-extras: unsaved review comments from feature (:CommentsSave)$",
        \ execute('Git checkout -q main'))
  call assert_equal([{'path': 'a.txt', 'start': 2, 'end': 2, 'body': 'changed'}],
        \ fugitive_extras#comments#list())
endfunction

function! s:test_deleted_branch_saves_go() abort
  edit a.txt
  silent Git checkout -q -b feature
  1Comment on feature
  CommentsSave
  call assert_equal(2, len(s:saves('feature')))
  silent Git checkout -q main
  silent Git branch -q -D feature
  call assert_equal([], s:saves('feature'))
  call assert_false(isdirectory(s:repo . '/.git/fugitive-extras/comments/feature'))
endfunction

function! s:test_compares_list() abort
  call s:git('checkout', '-q', '-b', 'feature')
  call writefile(['one', 'TWO', 'three'], s:repo . '/a.txt')
  call s:git('commit', '-q', '-am', 'change')
  let l:base = trim(system('git -C ' . shellescape(s:repo) . ' rev-parse main'))
  let l:head = trim(system('git -C ' . shellescape(s:repo) . ' rev-parse feature'))
  call fugitive_extras#compares#open(FugitiveGitDir(), 'feature', l:base, l:head)
  call assert_equal(2, tabpagenr('$'), 'one tab for the changed file')
  tabfirst
  Compares
  call assert_equal('fugitive-extras://compares/repo', bufname())
  call assert_equal('Comparisons (1)  <CR> open  dd remove  / filter  r refresh  q close',
        \ getline(1))
  call assert_match('^feature \+' . l:base[:6] . '\.\.' . l:head[:6] . '\x* \+1 files \+1 open',
        \ getline(2))
  call assert_equal(2, line('.'))
  call assert_equal('feature', roumail_lists#item().name)
  normal dd
  call assert_equal(['Comparisons (0)  <CR> open  dd remove  / filter  r refresh  q close'],
        \ getline(1, '$'))
  call assert_equal([], fugitive_extras#compares#list())
  normal q
  call assert_false(bufexists('fugitive-extras://compares/repo'))
  silent! tabonly!
endfunction

function! s:test_branch_commits_list() abort
  call s:git('checkout', '-q', '-b', 'feature')
  call writefile(['one', 'TWO', 'three'], s:repo . '/a.txt')
  call s:git('commit', '-q', '-am', 'change a')
  call writefile(['b'], s:repo . '/b.txt')
  call s:git('add', 'b.txt')
  call s:git('commit', '-q', '-m', 'add b')
  " main is local here, with no origin
  edit a.txt
  BranchCommits
  call assert_equal('fugitive-extras://commits/repo', bufname())
  call assert_equal('Commits on feature not on main (2)  <CR> commit  / filter  r refresh  q close',
        \ getline(1))
  call assert_match('^\x\{7,}  t \+\S.* ago \+add b (HEAD -> feature)$', getline(2))
  call assert_match('  change a$', getline(3))
  call assert_equal(2, line('.'))
  call assert_equal('add b', roumail_lists#item().subject)
  " <CR>: the commit in fugitive, in the window above
  let l:sha = roumail_lists#item().sha
  execute "normal \<CR>"
  call assert_match('^fugitive://.*' . l:sha . '$', bufname())
  wincmd p
  " / filters on the subject
  call feedkeys("/chg\<CR>", 'x')
  call assert_equal(2, line('$'))
  call assert_match('change a$', getline(2))
  normal q
  " Paths: only the commits that change this file
  edit a.txt
  BranchCommits -- %
  call assert_equal(2, line('$'))
  call assert_match('change a$', getline(2))
  normal q
  " An option picking commits
  BranchCommits --grep=add
  call assert_equal(2, line('$'))
  call assert_match('add b', getline(2))
  " One that adds lines leaves each commit one line
  normal q
  BranchCommits --stat
  call assert_equal(3, line('$'))
  normal q
  silent! only
endfunction

let s:prefix = expand('<SID>') . 'test_'

let s:failed = 0
let s:names = []
for s:line in split(execute('function'), "\n")
  if stridx(s:line, 'function ' . s:prefix) == 0
    call add(s:names, matchstr(s:line, '^function \zs[^(]\+'))
  endif
endfor
for s:name in s:names
  let s:label = matchstr(s:name, 'test_\zs\w\+')
  if !empty($TEST) && s:label !~# $TEST
    continue
  endif
  call s:reset()
  let v:errors = []
  try
    call call(s:name, [])
  catch
    call add(v:errors, v:exception . ' @ ' . v:throwpoint)
  endtry
  if empty(v:errors)
    call add(s:out, 'ok   ' . s:label)
  else
    let s:failed += 1
    call add(s:out, 'FAIL ' . s:label)
    call extend(s:out, map(copy(v:errors), '"     " . v:val'))
  endif
endfor
call add(s:out, s:failed ? s:failed . ' failed' : 'all passed')
call writefile(s:out, '/dev/stdout')
cd /
call delete(s:tmp, 'rf')
execute 'cquit' (s:failed ? 1 : 0)
