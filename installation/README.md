# Local build tools

This folder contains the shared build scripts and ignored, project-local tools:

- `R/`: the local R installation;
- `library/`: the R package library containing Bookdown;
- `pandoc/`: the Pandoc executable;
- `site/`: the compiled, multi-page GitBook and its assets;
- `build/`: temporary conversion and validation files;
- `downloads/`: cached installers.

`compile.cmd` runs `compile.ps1`, which runs `setup.ps1` if any component is
missing. No system-wide R or Pandoc installation is needed. Installations stay
local to each notebook. Building never fetches or merges Git updates.

The root `notes.html` opens `installation/site/index.html` and preserves chapter
anchors. Each chapter has its own page with shared navigation and search.

The compiler discovers numbered chapter folders recursively under `notes/`,
orders them by name, and requires a matching `.tex` entry file in each folder.
Optional `NN-MM-description.tex` parts are ordered and combined into the same
chapter page. Their structural inputs are stripped during conversion.

Shared `notes/_shared/macros.tex` definitions load before notebook-specific
`notes/macros.tex` definitions. The compiler converts the LaTeX to temporary
Bookdown sources and builds the index from `main.tex` and `preface.tex`.
Successful builds remove their generated notebook source files.

Finishing steps preserve custom reference text, move reference prefixes into
links, add hover/focus previews for references and citations, and render theorem
environments as boxes with optional titles. A final Bibliography chapter contains
only cited works, with backlinks to their numbered sections. Unresolved labels
produce red `??` markers and informational messages rather than fatal errors.

Every run of `compile.cmd` overwrites `installation/compile.log` with that build's
complete output. Failed double-click builds pause and print the log path.

Notebook-owned Bookdown configuration is copied from the starter once. Update it
manually if a future starter setting is useful to an existing notebook.
