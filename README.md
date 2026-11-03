# fugitive-extras

Additions to [vim-fugitive](https://github.com/tpope/vim-fugitive): review a
branch the way a pull request shows it, keeping each review as a comparison,
and stage hunks in a vertical diff. With
[vim-review](https://github.com/roumail/vim-review), its review comments go on
the branch and are saved per branch.

"Main" is the repo's default branch: `origin/HEAD`, else `origin/main`,
`origin/master`, `main` or `master`, resolved per repo when a command runs.
Diffs are against the **merge-base** of `HEAD` and main, so they show only
what this branch changes, not what landed on main since it forked. They
include uncommitted changes.

The `:Branch*` commands show the branch like a PR's tabs on GitHub: its
changed files as diffs, and its commits. They take a
branch, local or remote, to review it without checking it out:
`:BranchDiff origin/feature`.
Diffs are then from that branch's merge-base with main to its last commit.
`<Tab>` completes branches, most recent first. Run `:Git fetch` first to see
new remote branches.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:DiffThis` | `<Plug>(fugitive-extras-diff-this)` | `:Gvdiffsplit`: index on the left, working tree on the right. `dp` on a hunk in the working tree stages it, `do` in the index unstages it; `:w` the index buffer to keep it. |
| `:DiffThis!` | `<Plug>(fugitive-extras-diff-main)` | The current file at the merge-base on the left, working tree on the right: what the branch changes in it. |
| `:BranchDiff [branch]` | `<Plug>(fugitive-extras-branch-diff)` | One tab per changed file, each already a diff against the merge-base (`:Git difftool -y`), listed in `:Compares`. |
| `:BranchCommits [branch] [args]` | `<Plug>(fugitive-extras-branch-commits)` | Commits on the branch that main lacks (`:Git log base..branch`). `<CR>` on a commit opens it. Extra args go to `git log`, e.g. `:BranchCommits --stat` or `:BranchCommits -- %`. |
| `:DiffClose [name]` | `<Plug>(fugitive-extras-diff-close)` | Close the tabs of a `:BranchDiff` comparison: `name` (`<Tab>` completes names), else the one this tab is in. From one of its tabs, go back to the window `:BranchDiff` was run from. It stays in `:Compares`; a tab with unsaved changes stays open. Outside a comparison, close the `fugitive://` windows in this tab and `:diffoff!`. |
| `:Compares` | `<Plug>(fugitive-extras-compares)` | The comparisons `:BranchDiff` opened, newest first (see below). |


Reviewing a PR: check it out (`gh pr checkout`, or `:PRs` in
[gh-extras](https://github.com/roumail/gh-extras)), then `:BranchDiff` and
`:BranchCommits`.

## Comparisons

Each `:BranchDiff` is kept as a comparison, as in GitLens' Search & Compare:
named for the branch (the current branch's name without one), with the
merge-base it diffed against. Its tabs carry its name, so closing the files
that raise no questions leaves the ones that do, and other plugins can read
which ([For other plugins](#for-other-plugins)). A comparison stays listed until you remove it, even
with all its tabs closed, for the rest of the Vim session. Another
`:BranchDiff` of the same branch reuses a comparison of it with no tabs open;
while every one of them still has tabs, it starts a new one, `feature#2`,
`feature#3`, …, so you can keep different files of the same branch open in
each.

`:Compares` lists them in a window at the bottom: name, `base..head` (`work tree`
when uncommitted changes are in it), files, how many of its tabs are open,
and age.

| Key | Action |
| --- | --- |
| `<CR>` | Close the list and open all its files again, in new tabs, against the same merge-base. `:BranchDiff` again to diff against a new one. |
| `d` | Remove it from the list. Its tabs stay open. To close them too, run `:DiffClose <name>` before removing it. |
| `r` | Refresh. |
| `q` | Close (`:q` too: the list has its own window). |

## Review comments

With [vim-review](https://github.com/roumail/vim-review) installed, its review
comments (`:Comment`, `:Comments`, `:CommentsSave`, `:CommentsLoad`) work with
git:

- A comment goes on a file in the work tree or on the branch side of a diff;
  the merge-base side is refused. Paths are relative to the repo root.
- Comments are on the branch a tab's comparison diffs (`:BranchDiff feature`),
  else on the checked-out branch, so two comparisons of different branches
  open at once keep their comments apart; comparisons of the same branch
  share them. A remote branch counts as its local one: `origin/feature` is
  `feature`.
- Saves without a file name are per branch and time,
  `vim-review/<branch>/<YYYYmmdd-HHMMSS>.txt` in the git dir, so they
  are never committed and reviews of different branches stay apart.
  `:CommentsLoad` loads the latest of the branch, as above.
- Switching branches with `:Git checkout`, or commenting in a tab of another
  branch's comparison, while comments are unsaved warns. Nothing is cleared.

No keys are bound; bind the `<Plug>` mappings yourself, for example:

```vim
nmap <leader>cd <Plug>(fugitive-extras-diff-main)
nmap <leader>cl <Plug>(fugitive-extras-branch-commits)
```

## For other plugins

| Function | What it does |
| --- | --- |
| `fugitive_extras#main_ref()` | Main as a ref (`origin/main`, `main`, …) in the current buffer's repo, or `''`. |
| `fugitive_extras#compares#list([gitdir])` | The comparisons in the repo at `gitdir` (default: the current buffer's), newest first, as `{name, branch, base, head, files, time, tabs}`: `branch` is what it was
named for (`name` may add `#2`), `head` is `''` for the work tree, `tabs` the tab numbers still showing it. |

## Install

Requires vim-fugitive. With [vim-requires](https://github.com/roumail/vim-requires),
Vim shows `fugitive-extras: requires …` at startup when it isn't loaded.
Review comments need vim-review.

```vim
Plug 'tpope/vim-fugitive'
Plug 'roumail/vim-review'    " optional: review comments
Plug 'roumail/vim-requires'  " optional: the startup warning
Plug 'roumail/fugitive-extras'
```
