args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Expected the local R library path as the only argument.")
}

library_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
.libPaths(c(library_dir, .libPaths()))

required <- "bookdown"
missing <- required[!vapply(
  required,
  requireNamespace,
  quietly = TRUE,
  FUN.VALUE = logical(1)
)]

if (length(missing)) {
  install.packages(
    missing,
    lib = library_dir,
    repos = "https://cloud.r-project.org",
    dependencies = c("Depends", "Imports", "LinkingTo"),
    type = "binary"
  )
}

if (!requireNamespace("bookdown", quietly = TRUE)) {
  stop("Bookdown was not installed successfully.")
}

message("bookdown ", as.character(utils::packageVersion("bookdown")), " is ready.")
