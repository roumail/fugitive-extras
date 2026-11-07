if exists('g:loaded_fugitive_extras')
  finish
endif
let g:loaded_fugitive_extras = 1

" Index | working tree: dp/do move hunks, :w in the index buffer stages.
" With !, the file at the merge-base with main | working tree (what the PR
" changes).
command! -bang DiffThis call fugitive_extras#diff_this(<bang>0)
" The commands below take an optional branch (default HEAD), e.g.
" origin/feature, to review it without checking it out.
" One tab per file the branch's commits change, each a diff against the
" merge-base with main; with !, the work tree's changes, uncommitted too
command! -bang -nargs=? -complete=customlist,fugitive_extras#complete_branch
      \ BranchDiff call fugitive_extras#branch_diff(<q-args>, <bang>0)
" This tab's comparison again from a new merge-base, back on this file;
" another diff, both sides read again
command! DiffRefresh call fugitive_extras#diff_refresh()
" Commits on the branch that main doesn't have, a vim-lists list; further
" args pick which (git log's --author=..., -- paths)
command! -nargs=* -complete=customlist,fugitive_extras#complete_commits
      \ BranchCommits call fugitive_extras#branch_commits(<q-args>)
" Close the :BranchDiff comparison (name, else this tab's), which stays in
" :Compares; outside one, the fugitive side of the diff in this tab
command! -nargs=? -complete=customlist,fugitive_extras#compares#complete
      \ DiffClose call fugitive_extras#diff_close(<q-args>)
" The :BranchDiff comparisons of this session; <CR> reopens one, dd removes
command! Compares call fugitive_extras#compares#show()

nnoremap <Plug>(fugitive-extras-diff-this) <Cmd>DiffThis<CR>
nnoremap <Plug>(fugitive-extras-diff-main) <Cmd>DiffThis!<CR>
nnoremap <Plug>(fugitive-extras-branch-diff) <Cmd>BranchDiff<CR>
nnoremap <Plug>(fugitive-extras-branch-diff-worktree) <Cmd>BranchDiff!<CR>
nnoremap <Plug>(fugitive-extras-diff-refresh) <Cmd>DiffRefresh<CR>
nnoremap <Plug>(fugitive-extras-branch-commits) <Cmd>BranchCommits<CR>
nnoremap <Plug>(fugitive-extras-diff-close) <Cmd>DiffClose<CR>
nnoremap <Plug>(fugitive-extras-compares) <Cmd>Compares<CR>

" Comments go on the branch side of a diff and are saved per branch: the one
" this tab compares, else the checked-out one.
" Comment on the line or range; prompts unless the comment is given
command! -range -nargs=* Comment call fugitive_extras#comments#add(<line1>, <line2>, <q-args>)
" The same, written in a buffer (:w saves, closing it adds the comment)
command! -range -nargs=* CommentDraft call fugitive_extras#comments#edit(<line1>, <line2>, <q-args>)
" Open the 'Review' list
command! Comments call fugitive_extras#comments#open()
" Write the comments to a file (default: a new timestamped save) and load
" them back (default: the latest save)
command! -nargs=? -complete=file CommentsSave call fugitive_extras#comments#save(<q-args>)
command! -nargs=? -complete=customlist,fugitive_extras#comments#complete_load
      \ CommentsLoad call fugitive_extras#comments#load(<q-args>)
" Empty the 'Review' list; saves are kept
command! CommentsClear call fugitive_extras#comments#clear()

" They leave :Comment on the command line to finish; turning it into
" :CommentDraft takes the text to an editor
nnoremap <Plug>(fugitive-extras-comment) :<C-u>Comment<Space>
xnoremap <Plug>(fugitive-extras-comment) :Comment<Space>
nnoremap <Plug>(fugitive-extras-comment-draft) <Cmd>CommentDraft<CR>
xnoremap <Plug>(fugitive-extras-comment-draft) :CommentDraft<CR>

augroup fugitive_extras
  autocmd!
  " Warn after a :Git checkout that left unsaved comments from another branch
  autocmd User FugitiveChanged call fugitive_extras#comments#check()
  " A :Git branch -d or fetch --prune may have deleted a branch with saves
  autocmd User FugitiveChanged call fugitive_extras#comments#prune()
  " c changes a comment in the 'Review' list's window
  autocmd FileType qf nnoremap <buffer> <silent> c
        \ <Cmd>call fugitive_extras#comments#change(line('.'), 'c')<CR>
augroup END
