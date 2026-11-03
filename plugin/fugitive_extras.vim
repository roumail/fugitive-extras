if exists('g:loaded_fugitive_extras')
  finish
endif
let g:loaded_fugitive_extras = 1

" roumail/vim-requires is optional
try
  call roumail_requires#check('fugitive-extras', {
        \ 'tpope/vim-fugitive': 'g:loaded_fugitive',
        \ })
catch /^Vim\%((\a\+)\)\=:E117:/
endtry

" Index | working tree: dp/do move hunks, :w in the index buffer stages.
" With !, the file at the merge-base with main | working tree (what the PR
" changes).
command! -bang DiffThis call fugitive_extras#diff_this(<bang>0)
" The commands below take an optional branch (default HEAD), e.g.
" origin/feature, to review it without checking it out.
" One tab per changed file, each a diff against the merge-base with main
command! -nargs=? -complete=customlist,fugitive_extras#complete_branch
      \ BranchDiff call fugitive_extras#branch_diff(<q-args>)
" Commits on the branch that main doesn't have; further args go to git log
command! -nargs=* -complete=customlist,fugitive_extras#complete_commits
      \ BranchCommits call fugitive_extras#branch_commits(<q-args>)
" Close the :BranchDiff comparison (name, else this tab's), which stays in
" :Compares; outside one, the fugitive side of the diff in this tab
command! -nargs=? -complete=customlist,fugitive_extras#compares#complete
      \ DiffClose call fugitive_extras#diff_close(<q-args>)
" The :BranchDiff comparisons of this session; <CR> reopens one, d removes
command! Compares call fugitive_extras#compares#show()

nnoremap <Plug>(fugitive-extras-diff-this) <Cmd>DiffThis<CR>
nnoremap <Plug>(fugitive-extras-diff-main) <Cmd>DiffThis!<CR>
nnoremap <Plug>(fugitive-extras-branch-diff) <Cmd>BranchDiff<CR>
nnoremap <Plug>(fugitive-extras-branch-commits) <Cmd>BranchCommits<CR>
nnoremap <Plug>(fugitive-extras-diff-close) <Cmd>DiffClose<CR>
nnoremap <Plug>(fugitive-extras-compares) <Cmd>Compares<CR>

" vim-review's comments go on the branch side of a diff and are saved per
" branch: the one this tab compares, else the checked-out one. Lambdas, not
" function('Fugitive...'): fugitive may load after this.
let g:review_provider = {
      \ 'root': {-> FugitiveWorkTree()},
      \ 'target': function('fugitive_extras#comments#target'),
      \ 'save_dir': function('fugitive_extras#comments#save_dir'),
      \ 'scope': function('fugitive_extras#comments#scope'),
      \ }

augroup fugitive_extras
  autocmd!
  " Warn after a :Git checkout that left unsaved comments from another branch
  autocmd User FugitiveChanged call fugitive_extras#comments#check()
  " A :Git branch -d or fetch --prune may have deleted a branch with saves
  autocmd User FugitiveChanged if !empty(FugitiveCommonDir())
        \ | call fugitive_extras#comments#prune(FugitiveCommonDir()) | endif
augroup END
