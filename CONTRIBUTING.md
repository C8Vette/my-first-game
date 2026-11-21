# Working together on my-first-game

This is how the two of us make changes without stepping on each other.
The short version: **nobody edits `main` directly.** Every change goes on
its own branch and comes back through a pull request (PR) the other person
can glance at before it lands.

---

## The golden rules

1. **Never commit straight to `main`.** Always work on a branch.
2. **Edit the files on disk, not in Studio** while Rojo is connected, or
   the next sync overwrites your Studio edits.
3. **Run the formatter and linter before you push** (see below). Keeps our
   diffs clean and catches mistakes.

---

## One-time setup (each of us, once per computer)

```powershell
# 1. Get the code
git clone https://github.com/C8Vette/my-first-game.git
cd my-first-game

# 2. Install the tools pinned in rokit.toml (Rojo, Selene, StyLua, etc.)
rokit install

# 3. Install the Rojo plugin into Studio (then restart Studio)
rojo plugin install

# 4. Sign in to GitHub so you can push and open PRs
gh auth login
```

> If a fresh terminal says `rojo` or `gh` isn't found, close and reopen it
> once — the installers add them to your PATH, but already-open terminals
> don't pick that up until restarted.

---

## Repo owner setup (C8Vette does this once)

These can only be done by the repo owner:

1. **Add the other person as a collaborator:** repo on github.com →
   **Settings** → **Collaborators** → **Add people** → enter their GitHub
   username → send invite. They accept via the emailed link.
2. **Protect `main`:** repo → **Settings** → **Rules** → **Rulesets** →
   **New branch ruleset**. Name it `protect-main`, set **Enforcement** to
   **Active**, target the `main` branch, and tick **Require a pull request
   before merging**. Save. Now nobody can push to `main` by accident.

---

## The workflow (every change)

```powershell
# 1. Start from an up-to-date main
git switch main
git pull

# 2. Make a branch for your change (see naming below)
git switch -c ethan/mining-sound-fix

# 3. ...edit code, test in Studio with Rojo connected...

# 4. Format and lint before committing
stylua src
selene src

# 5. Stage and commit
git add -A
git commit -m "Fix mining sound not playing on first hit"

# 6. Push your branch to GitHub
git push -u origin ethan/mining-sound-fix

# 7. Open a pull request
gh pr create --fill        # uses your commit messages to fill it in
# or:  gh pr create --web  # opens the PR form in your browser
```

Then the **other person reviews it** on github.com (or with `gh pr view --web`),
and whoever's happy clicks **Merge**. After it merges:

```powershell
# 8. Go back to main, pull the merged change, delete the old branch
git switch main
git pull
git branch -d ethan/mining-sound-fix
```

---

## Branch naming

Use `yourname/short-description`, lowercase, dashes for spaces:

- `ethan/add-asteroid-health-bar`
- `alex/frost-zone-balance`

The `yourname/` prefix makes it obvious whose branch is whose.

---

## When Git says there's a conflict

This happens when you both changed the same lines. It's normal and fixable:

```powershell
git switch main
git pull
git switch your-branch
git merge main
```

Git marks the clashing spots in the files with `<<<<<<<`, `=======`, and
`>>>>>>>`. Open those files, decide what the final version should be, delete
the marker lines, then:

```powershell
git add -A
git commit
git push
```

If a conflict ever feels scary, stop and ask — it's always recoverable.

---

## Quick reference

| I want to... | Command |
|---|---|
| Start a new change | `git switch main && git pull && git switch -c name/thing` |
| See what I changed | `git status` and `git diff` |
| Format + lint | `stylua src` then `selene src` |
| Save my work | `git add -A && git commit -m "..."` |
| Share it | `git push -u origin name/thing` |
| Open a PR | `gh pr create --fill` |
| Review the other PR | `gh pr list` then `gh pr view <number> --web` |
