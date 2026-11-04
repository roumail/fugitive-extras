# fugitive-extras

Additions to [vim-fugitive](https://github.com/tpope/vim-fugitive): review a
branch the way a pull request shows it, keeping each review as a comparison,
stage hunks in a vertical diff, and leave review comments on the branch,
saved per branch.

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

Comments on a line or a range of a file, collected in their own quickfix
list titled `Review`, so they don't mix with grep or diff results, saved and
loaded back.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:[range]Comment [text]` | `<Plug>(fugitive-extras-comment)` (normal and visual), which leaves `:Comment ` on the command line to finish | Add a comment on the line or range; prompts unless `text` is given. Leaving the prompt with `<Esc>` keeps what you typed: `:Comment` or `:CommentDraft` on the same lines goes on from it. |
| `:[range]CommentDraft [text]` | `<Plug>(fugitive-extras-comment-draft)` (normal and visual) | Write the comment in a markdown buffer split below (`g:fugitive_extras_comment_height`, default 10), starting with `text` if given, else with what you left at the `:Comment` prompt on those lines, for longer or multi-line comments. A [vim-draft](https://github.com/roumail/vim-draft) draft: `:w` saves, closing the buffer (`:wq`, or `:q` after `:w`) adds the comment last saved, and an empty one or `:q!` before any `:w` drops it. |
| `:Comments` | | Open the `Review` list. In it, `c` opens the comment on the line in a draft, all of it, to read or change: saved and closed, it replaces the comment. Deleting one is up to a quickfix list's `dd`, as [qf-tools](https://github.com/roumail/qf-tools) binds it. |
| `:CommentsSave [file]` | | Write the comments in [vim-review](https://github.com/roumail/vim-review)'s format, their [anchors](#anchors) in `<file>.anchors` beside it, so the file reads as plain comments. Without `file`, each save is a new file named for the time (see below). |
| `:CommentsLoad [file]` | | Replace the `Review` list with the comments in the file, each moved to where its lines are now; without `file`, the latest save of the branch. `<Tab>` lists the saves, newest first, then files. |
| `:CommentsClear` | | Empty the `Review` list, as quitting Vim would. Saves are kept, so `:CommentsLoad` brings them back. |

- A comment goes on a file in the work tree or on the branch side of a diff;
  the merge-base side is refused, and so is a file outside a git work tree.
  Paths are relative to the repo root.
- Comments are on the branch a tab's comparison diffs (`:BranchDiff feature`),
  else on the checked-out branch, so two comparisons of different branches
  open at once keep their comments apart; comparisons of the same branch
  share them. A remote branch counts as its local one: `origin/feature` is
  `feature`.
- Saves without a file name are per branch and time,
  `fugitive-extras/comments/<branch>/<YYYYmmdd-HHMMSS>.txt` in the git dir
  (where vim-draft keeps plugins' files), so they are never committed and
  reviews of different branches stay apart.
- The saves of a deleted branch are deleted: those of a branch that is
  neither local nor any remote's, nor anything else naming a commit (a tag,
  or the commit of a detached HEAD). Once a merged branch's local one is
  deleted, its remote one goes once GitHub deletes it and you fetch with
  `--prune`. They are looked for the first time comments are used in a Vim
  session, and after every `:Git` command. Which were deleted is in
  `:messages`.
- Switching branches with `:Git checkout`, or commenting in a tab of another
  branch's comparison, while comments are unsaved warns. Nothing is cleared.

To take a comment you're typing to an editor, change `Comment` to
`CommentDraft` on the command line (`<C-b>` goes to its start) and press
Enter: the draft starts with your text. A command line left with `<Esc>` is
in the history, so `:<Up>` gets it back after you look something up.

### Anchors

While a file is open, its comments move with your edits, as quickfix entries
do. A save can be loaded after the file changed outside Vim, though (a `git
pull`, a rebase, an agent's edit), so each comment is saved with an anchor:
a line of JSON in `<file>.anchors` with its lines (up to 20) and the 2 on either side.

`:CommentsLoad` looks for those lines, ignoring indentation, and moves the
comment to them. Where they appear more than once, it takes the place with
the most matching lines around it, then the nearest to the saved line. A
comment whose lines are gone stays at its saved line, marked `W` in
`:Comments`, and keeps its anchor through later saves, so it is found again if
its lines come back.

## Keys

Apart from `c` in the `Review` list, no keys are bound; bind the `<Plug>`
mappings yourself, for example:

```vim
nmap <leader>cd <Plug>(fugitive-extras-diff-main)
nmap <leader>cl <Plug>(fugitive-extras-branch-commits)
nmap <leader>cc <Plug>(fugitive-extras-comment)
xmap <leader>cc <Plug>(fugitive-extras-comment)
```

## For other plugins

| Function | What it does |
| --- | --- |
| `fugitive_extras#comments#list()` | The review comments as `{path, start, end, body, orphaned?}`: `path` relative to the repo root, `start` and `end` the first and last line, the same for a single line; `orphaned` when its lines weren't found on load. |
| `fugitive_extras#comments#load([file])` | Replace the `Review` list with the comments in `file`, else the branch's latest save, as `:CommentsLoad`. |
| `fugitive_extras#comments#check()` | Warn when the unsaved comments are from another branch than now. |
| `fugitive_extras#main_ref()` | Main as a ref (`origin/main`, `main`, …) in the current buffer's repo, or `''`. |
| `fugitive_extras#compares#list([gitdir])` | The comparisons in the repo at `gitdir` (default: the current buffer's), newest first, as `{name, branch, base, head, files, time, tabs}`: `branch` is what it was
named for (`name` may add `#2`), `head` is `''` for the work tree, `tabs` the tab numbers still showing it. |

## Install

Requires vim-fugitive, [vim-draft](https://github.com/roumail/vim-draft) (the
buffer `:CommentDraft` writes in, and where saves are kept) and
[vim-review](https://github.com/roumail/vim-review) (the format comments are
saved in). With [vim-requires](https://github.com/roumail/vim-requires), Vim
shows `fugitive-extras: requires …` at startup when one isn't loaded.

```vim
Plug 'tpope/vim-fugitive'
Plug 'roumail/vim-draft'
Plug 'roumail/vim-review'
Plug 'roumail/vim-requires'  " optional: the startup warning
Plug 'roumail/fugitive-extras'
```

## Tests

```sh
vim -Nu NONE -i NONE -Es -S test/run.vim
```

They use vim-plug's copies of vim-fugitive, vim-draft and vim-review, unless
`$FUGITIVE`, `$VIM_DRAFT` or `$VIM_REVIEW` name other clones.
