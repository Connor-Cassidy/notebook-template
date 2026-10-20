args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Expected the project root as the only argument.")
}

project_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
notes_dir <- file.path(project_root, "notes")
site_dir <- file.path(project_root, "installation", "site")
conversion_dir <- file.path(project_root, "installation", "build", "latex")
output_file <- file.path(project_root, "notes.html")
source_artifacts <- file.path(
  notes_dir,
  c(
    "notes.Rmd",
    "notes.knit.md",
    "reference-keys.txt",
    "bibliography.Rmd",
    "_bookdown.generated.yml",
    "index.Rmd"
  )
)

clean_source_artifacts <- function() {
  existing <- source_artifacts[file.exists(source_artifacts)]
  if (length(existing)) {
    unlink(existing, force = TRUE)
  }
}

if (dir.exists(site_dir)) {
  unlink(site_dir, recursive = TRUE, force = TRUE)
}
dir.create(site_dir, recursive = TRUE, showWarnings = FALSE)
if (dir.exists(conversion_dir)) {
  unlink(conversion_dir, recursive = TRUE, force = TRUE)
}

old_dir <- setwd(notes_dir)

source(
  file.path(project_root, "installation", "latex-to-bookdown.R"),
  local = TRUE
)
pandoc_path <- file.path(Sys.getenv("RSTUDIO_PANDOC"), "pandoc.exe")
conversion <- convert_latex_project(
  notes_dir,
  pandoc_path,
  conversion_dir
)
source_artifacts <- c(source_artifacts, conversion$generated_files)

generated_config <- "_bookdown.generated.yml"
config <- yaml::read_yaml("_bookdown.yml")
config$rmd_files <- c("index.Rmd", conversion$chapter_files)
yaml::write_yaml(config, generated_config)

message(
  "Converted ", length(conversion$chapter_dirs), " LaTeX chapter(s) from ",
  conversion$source_count, " source file(s): ",
  paste(
    paste0(
      basename(conversion$chapter_dirs),
      " [", conversion$part_counts, " part file(s)]"
    ),
    collapse = ", "
  )
)
if (length(conversion$unresolved_labels)) {
  message(
    "Unresolved reference(s) rendered as red ??: ",
    paste(conversion$unresolved_labels, collapse = ", ")
  )
}

render_site <- function(config_file) {
  bookdown::render_book(
    input = "index.Rmd",
    output_format = "bookdown::gitbook",
    output_dir = site_dir,
    clean = TRUE,
    quiet = FALSE,
    config_file = config_file
  )
}

render_site(generated_config)

html_files <- list.files(site_dir, pattern = "\\.html$", full.names = TRUE)
html <- paste(
  vapply(html_files, function(path) {
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }, character(1)),
  collapse = "\n"
)
key_matches <- regmatches(
  html,
  gregexpr('id="ref-[^"]+"', html, perl = TRUE)
)[[1L]]
citation_keys <- unique(sub('"$', "", sub('^id="ref-', "", key_matches)))

generated_bibliography <- "bibliography.Rmd"
bibliography_lines <- c(
  "# Bibliography {-}",
  "",
  if (length(citation_keys)) {
    c(
      '::: {.all-citations style="display:none;" aria-hidden="true"}',
      paste0("[@", paste(citation_keys, collapse = "; @"), "]"),
      ":::"
    )
  } else {
    "No works have been cited."
  }
)
writeLines(bibliography_lines, generated_bibliography, useBytes = TRUE)

config$rmd_files <- c(config$rmd_files, generated_bibliography)
yaml::write_yaml(config, generated_config)

unlink(site_dir, recursive = TRUE, force = TRUE)
dir.create(site_dir, recursive = TRUE, showWarnings = FALSE)
render_site(generated_config)

source(
  file.path(project_root, "installation", "postprocess.R"),
  local = TRUE
)
postprocess_book(site_dir)

site_index <- file.path(site_dir, "index.html")
if (!file.exists(site_index)) {
  stop("The GitBook build did not create installation/site/index.html.")
}

launcher <- file.path(project_root, "installation", "notes-launcher.html")
if (!file.copy(launcher, output_file, overwrite = TRUE)) {
  stop("Could not create the local notes.html entry point.")
}

setwd(old_dir)
clean_source_artifacts()
message(
  "Wrote ", normalizePath(output_file, winslash = "/", mustWork = TRUE),
  " -> ", normalizePath(site_index, winslash = "/", mustWork = TRUE)
)
