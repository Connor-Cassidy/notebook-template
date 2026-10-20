# Notebook template

A reusable Windows workflow for writing LaTeX notes, compiling them in Overleaf,
and building a local Bookdown GitBook. Keep one private repository per notebook
and merge improvements from this public repository when you choose.

This repository contains the procedure and an invented starter, not a personal
notebook. It has no open-source licence.

## Start a private notebook

Create a new **private, empty** GitHub repository, without a README or licence.
Then run these commands in PowerShell, replacing the project name and private URL:

```powershell
git clone https://github.com/Connor-Cassidy/notebook-template.git my-project-notes
Set-Location my-project-notes
git remote rename origin upstream
git remote set-url --push upstream DISABLED
git remote add origin https://github.com/YOUR-USER/YOUR-PRIVATE-NOTEBOOK.git
Copy-Item -Path .\starter\notes\* -Destination .\notes -Recurse
git add notes
git commit -m "Start private notebook"
git push -u origin main
```

Use a separate private repository rather than GitHub's Fork button: forks of
public repositories are public. Clone with its history rather than using GitHub's
Use this template button, so future Git merges have a common ancestor.

Edit `notes/main.tex` to set the title, author, and chapter inputs. Replace the
starter prose and bibliography with your own. Double-click `compile.cmd` to build,
then open `notes.html`. The first build installs R, Pandoc, and Bookdown locally.
After installation, building does not require a GitHub connection or fetch updates.

Do the one-time starter copy only for a new notebook. Copying it again could
overwrite your writing.

## Take procedure updates

Commit or stash your notebook changes first, then run:

```powershell
git fetch upstream
git merge upstream/main
.\compile.cmd
```

Inspect and test the merge, then push to your private `origin` when ready.
Resolve merge conflicts normally, or use `git merge --abort` before committing
the merge. A completed merge can be undone with `git revert -m 1 MERGE_COMMIT`.
Compilation never merges, commits, or pushes changes automatically.

## Shared files and notebook-owned files

| Location | Purpose |
| --- | --- |
| `installation/`, `compile.cmd`, `notes.html` | Shared build procedure and local launcher |
| `notes/_shared/` | Shared LaTeX packages, macros, and theorem formatting |
| `starter/notes/` | Reference starter; changes here do not overwrite an existing notebook |
| Other files under `notes/` | Your private notebook, configuration, bibliography, and overrides |

Load shared support first and local overrides afterwards, as shown in the starter
`main.tex`. Put personal macros in `notes/macros.tex` and formatting in
`notes/setup.tex`; use `\renewcommand` when overriding an existing macro.
The local compiler loads shared macros followed by your local macros in the same
order as LaTeX. Other notebook configuration files are owned by the notebook;
changes to their starter examples are adopted manually.

Future procedure changes belong in shared paths or `starter/`. Do not add real
notebook sources at the public repository's notebook-owned paths. Downloaded
tools, generated pages, logs, and intermediate files are ignored by Git.

Upload the complete contents of `notes/`, including `_shared/`, to Overleaf and
select `main.tex`. See the starter's `OVERLEAF.md` for writing conventions and
`installation/README.md` for compiler details.

## Improve the procedure

Use a separate checkout of this public repository for shared development. Private
notebook checkouts disable pushing to `upstream` to reduce accidental publication.
Do not push notebook branches or their history to this public repository.

Run the smoke test after the local tools have been installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

The test builds an isolated copy of the invented starter, checks the rendered
features, and verifies a local macro can override a shared default. A separate
checkout can reuse an existing local tool installation with `-ToolsRoot PATH`.
