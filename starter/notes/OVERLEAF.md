# Editing in Overleaf

Upload the complete contents of `notes/`, including `_shared/`, to an Overleaf
project and select `main.tex` as the main document. Overleaf produces the PDF;
the parent repository's `compile.cmd` produces the local GitBook. The `.tex`
files are the canonical sources.

## Adding a chapter

1. Create a folder beginning with two digits and a hyphen, such as `02-new-topic`.
2. Create the matching entry file `02-new-topic/02-new-topic.tex`.
3. Begin it with `\chapter{...}` and a unique `\label{...}`.
4. Add `\input{02-new-topic/02-new-topic}` to `main.tex` for the PDF.

The local compiler discovers numbered chapter folders automatically. A split
chapter keeps its permanent matching entry file and includes an `NN-00` part
containing the chapter heading and ordered inputs for later `NN-MM-description.tex`
section files. See the starter's `01-example` chapter. Keep structural inputs in
the chapter files, not in your macro definitions.

## Shared support and customisation

Keep the shared inputs in `main.tex` before the local `macros.tex` and `setup.tex`
overrides. Shared procedure updates arrive through `git merge upstream/main` in
the parent repository. Upload the resulting complete `notes/` folder to Overleaf.
No public-repository access is required to compile those uploaded files.

## Portable LaTeX

The converter supports ordinary headings, prose, mathematics, figures, labels,
`\ref`, `\Cref`, `\cref`, `\autoref`, `\eqref`, `\citet`, and `\citep`.
Use one label per reference command. `\Cref[custom text]{label}` displays custom
linked text in both outputs. Unresolved references render as red `??` markers
in the GitBook without failing compilation.

Ordinary `\newcommand` and `\renewcommand` definitions in the shared and local
macro files are expanded before rendering. `\inner` is handled explicitly;
other package-specific commands may need converter support. Write figure paths
relative to `notes/` so Overleaf and Bookdown can both resolve them.
