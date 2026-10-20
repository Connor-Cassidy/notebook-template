read_utf8 <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

write_utf8 <- function(text, path) {
  writeLines(enc2utf8(text), path, useBytes = TRUE)
}

replace_matches <- function(text, pattern, replacement_function) {
  matches <- gregexpr(pattern, text, perl = TRUE)[[1L]]
  if (matches[[1L]] == -1L) {
    return(text)
  }

  values <- regmatches(text, list(matches))[[1L]]
  replacements <- vapply(values, replacement_function, character(1))
  regmatches(text, list(matches)) <- list(replacements)
  text
}

capture_tex_command <- function(text, command, fallback) {
  pattern <- paste0("\\\\", command, "\\{([^{}]*)\\}")
  match <- regexec(pattern, text, perl = TRUE)
  values <- regmatches(text, match)[[1L]]
  if (length(values) < 2L) fallback else values[[2L]]
}

yaml_quote <- function(text) {
  text <- gsub("\\\\&", "&", text, fixed = TRUE)
  text <- gsub('"', '\\"', text, fixed = TRUE)
  paste0('"', text, '"')
}

html_escape <- function(text) {
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub('"', "&quot;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  gsub(">", "&gt;", text, fixed = TRUE)
}

collect_label_types <- function(tex_files) {
  types <- list()
  heading_names <- c(
    chapter = "Chapter",
    section = "Section",
    subsection = "Section",
    subsubsection = "Section"
  )

  for (path in tex_files) {
    text <- read_utf8(path)

    for (command in names(heading_names)) {
      pattern <- paste0(
        "\\\\", command, "\\*?(?:\\s*\\[[^][]*\\])?\\s*\\{[^{}]*\\}\\s*",
        "\\\\label\\{([^{}]+)\\}"
      )
      matches <- gregexpr(pattern, text, perl = TRUE)[[1L]]
      if (matches[[1L]] != -1L) {
        values <- regmatches(text, list(matches))[[1L]]
        for (value in values) {
          label <- sub(".*\\\\label\\{([^{}]+)\\}.*", "\\1", value, perl = TRUE)
          types[[label]] <- heading_names[[command]]
        }
      }
    }

    environments <- c(
      equation = "Equation",
      align = "Equation",
      figure = "Figure",
      table = "Table",
      theorem = "Theorem",
      definition = "Definition",
      lemma = "Lemma",
      proposition = "Proposition",
      corollary = "Corollary",
      conjecture = "Conjecture",
      assumption = "Assumption",
      example = "Example",
      exercise = "Exercise",
      remark = "Remark"
    )
    for (environment in names(environments)) {
      pattern <- paste0(
        "(?s)\\\\begin\\{", environment, "\\*?\\}",
        ".*?\\\\label\\{([^{}]+)\\}.*?",
        "\\\\end\\{", environment, "\\*?\\}"
      )
      matches <- gregexpr(pattern, text, perl = TRUE)[[1L]]
      if (matches[[1L]] != -1L) {
        values <- regmatches(text, list(matches))[[1L]]
        for (value in values) {
          label <- sub(
            "(?s).*\\\\label\\{([^{}]+)\\}.*",
            "\\1",
            value,
            perl = TRUE
          )
          types[[label]] <- environments[[environment]]
        }
      }
    }

    all_label_matches <- gregexpr(
      "\\\\label\\{([^{}]+)\\}",
      text,
      perl = TRUE
    )[[1L]]
    if (all_label_matches[[1L]] != -1L) {
      values <- regmatches(text, list(all_label_matches))[[1L]]
      labels <- sub("^\\\\label\\{([^{}]+)\\}$", "\\1", values, perl = TRUE)
      for (label in labels) {
        if (is.null(types[[label]])) {
          types[[label]] <- switch(
            tolower(sub(":.*$", "", label)),
            chap = "Chapter",
            ch = "Chapter",
            sec = "Section",
            subsec = "Section",
            fig = "Figure",
            tab = "Table",
            tbl = "Table",
            eq = "Equation",
            "Section"
          )
        }
      }
    }
  }

  types
}

collect_label_targets <- function(tex_files, html_pages) {
  if (length(tex_files) != length(html_pages)) {
    stop("Label source files and target pages must have the same length.")
  }

  targets <- list()
  for (index in seq_along(tex_files)) {
    text <- read_utf8(tex_files[[index]])
    matches <- gregexpr("\\\\label\\{([^{}]+)\\}", text, perl = TRUE)[[1L]]
    if (matches[[1L]] == -1L) {
      next
    }

    values <- regmatches(text, list(matches))[[1L]]
    labels <- sub("^\\\\label\\{([^{}]+)\\}$", "\\1", values, perl = TRUE)
    for (label in labels) {
      targets[[label]] <- paste0(html_pages[[index]], "#", label)
    }
  }

  targets
}

infer_reference_type <- function(label, label_types) {
  known <- label_types[[label]]
  if (!is.null(known)) {
    return(known)
  }

  prefix <- tolower(sub(":.*$", "", label))
  switch(
    prefix,
    chap = "Chapter",
    ch = "Chapter",
    sec = "Section",
    fig = "Figure",
    tab = "Table",
    tbl = "Table",
    eq = "Equation",
    "Section"
  )
}

protect_references <- function(text, label_types, label_targets = list()) {
  replacements <- character()
  unresolved <- character()
  pattern <- paste0(
    "\\\\(Cref|cref|autoref|eqref|ref)",
    "(?:\\[([^][]*)\\])?\\{([^{}]+)\\}"
  )

  protected <- replace_matches(text, pattern, function(value) {
    groups <- regmatches(value, regexec(pattern, value, perl = TRUE))[[1L]]
    command <- groups[[2L]]
    custom_text <- trimws(groups[[3L]])
    label <- trimws(groups[[4L]])

    if (grepl(",", label, fixed = TRUE)) {
      stop(
        "Multiple labels in one \\", command, "{} call are not supported: ",
        value,
        ". Use one reference command per label."
      )
    }

    prefix <- switch(
      command,
      Cref = infer_reference_type(label, label_types),
      cref = tolower(infer_reference_type(label, label_types)),
      autoref = infer_reference_type(label, label_types),
      eqref = "Equation",
      ref = ""
    )

    if (is.null(label_types[[label]])) {
      unresolved <<- unique(c(unresolved, label))
      marker <- if (nzchar(custom_text)) {
        paste(custom_text, "??")
      } else if (nzchar(prefix)) {
        paste(prefix, "??")
      } else {
        "??"
      }
      replacement <- paste0(
        '<span class="unresolved-reference" title="Unresolved reference: ',
        html_escape(label),
        '">',
        marker,
        "</span>"
      )
    } else if (nzchar(custom_text)) {
      target <- label_targets[[label]]
      if (is.null(target)) {
        stop("No GitBook target page was found for label: ", label)
      }
      replacement <- paste0(
        '<a class="custom-cross-reference" href="',
        html_escape(target),
        '">',
        html_escape(custom_text),
        "</a>"
      )
    } else {
      replacement <- if (nzchar(prefix)) {
        paste(prefix, paste0("\\@ref(", label, ")"))
      } else {
        paste0("\\@ref(", label, ")")
      }
    }

    replacements <<- c(replacements, replacement)
    paste0("BOOKDOWNREFERENCE", length(replacements), "TOKEN")
  })

  list(
    text = protected,
    replacements = replacements,
    unresolved = unresolved
  )
}

restore_references <- function(markdown, replacements) {
  if (!length(replacements)) {
    return(markdown)
  }

  for (index in seq_along(replacements)) {
    markdown <- gsub(
      paste0("BOOKDOWNREFERENCE", index, "TOKEN"),
      replacements[[index]],
      markdown,
      fixed = TRUE
    )
  }
  markdown
}

protect_environment_titles <- function(text) {
  replacements <- character()
  environments <- paste(
    c(
      "theorem", "definition", "lemma", "proposition", "corollary",
      "conjecture", "assumption", "example", "exercise", "remark"
    ),
    collapse = "|"
  )
  pattern <- paste0(
    "\\\\begin\\{(", environments, ")\\}",
    "\\s*\\[([^][]+)\\]"
  )

  protected <- replace_matches(text, pattern, function(value) {
    groups <- regmatches(value, regexec(pattern, value, perl = TRUE))[[1L]]
    environment <- groups[[2L]]
    title <- trimws(groups[[3L]])
    replacements <<- c(replacements, title)
    paste0(
      "\\begin{", environment, "}\n",
      "BOOKDOWNENVIRONMENTTITLE", length(replacements), "TOKEN\n"
    )
  })

  list(text = protected, replacements = replacements)
}

restore_environment_titles <- function(markdown, replacements) {
  if (!length(replacements)) {
    return(markdown)
  }

  for (index in seq_along(replacements)) {
    marker <- paste0("BOOKDOWNENVIRONMENTTITLE", index, "TOKEN")
    title <- paste0(
      '<span class="theorem-custom-title">',
      html_escape(replacements[[index]]),
      "</span><br />"
    )
    markdown <- gsub(marker, title, markdown, fixed = TRUE)
  }

  markdown
}

expand_special_macros <- function(text) {
  text <- gsub(
    "\\\\inner\\[([^][]*)\\]\\[([^][]*)\\]",
    "\\\\left\\\\langle \\1, \\2\\\\right\\\\rangle",
    text,
    perl = TRUE
  )
  text <- gsub(
    "\\\\inner\\[([^][]*)\\]",
    "\\\\left\\\\langle \\1, \\\\cdot\\\\,\\\\right\\\\rangle",
    text,
    perl = TRUE
  )
  gsub(
    "\\\\inner(?![A-Za-z])",
    "\\\\left\\\\langle \\\\,\\\\cdot\\\\,, \\\\cdot\\\\,\\\\right\\\\rangle",
    text,
    perl = TRUE
  )
}

latex_heading_shift <- function(text) {
  headings <- c(
    chapter = 0L,
    section = 1L,
    subsection = 2L,
    subsubsection = 3L
  )

  for (command in names(headings)) {
    pattern <- paste0(
      "\\\\", command,
      "\\*?(?:\\s*\\[[^][]*\\])?\\s*\\{"
    )
    if (grepl(pattern, text, perl = TRUE)) {
      return(headings[[command]])
    }
  }

  0L
}

convert_tex_file <- function(
  source_path,
  output_path,
  pandoc_path,
  conversion_dir,
  label_types,
  macros = "",
  strip_inputs = FALSE,
  label_targets = list()
) {
  source <- expand_special_macros(read_utf8(source_path))
  environment_titles <- protect_environment_titles(source)
  source <- environment_titles$text
  heading_shift <- latex_heading_shift(source)
  if (strip_inputs) {
    source <- gsub(
      "\\\\(?:input|include)\\s*\\{[^{}]+\\}",
      "",
      source,
      perl = TRUE
    )
  }
  combined <- paste(macros, source, sep = "\n\n")
  protected <- protect_references(combined, label_types, label_targets)
  temporary_tex <- file.path(
    conversion_dir,
    paste0(basename(source_path), ".protected.tex")
  )
  write_utf8(protected$text, temporary_tex)

  pandoc_args <- c(
    "-f", "latex",
    "-t", "markdown",
    "--wrap=preserve"
  )
  if (heading_shift > 0L) {
    pandoc_args <- c(
      pandoc_args,
      paste0("--shift-heading-level-by=", heading_shift)
    )
  }
  pandoc_args <- c(
    pandoc_args,
    "-o", shQuote(output_path),
    shQuote(temporary_tex)
  )
  status <- system2(pandoc_path, pandoc_args)
  if (!identical(status, 0L)) {
    stop("Pandoc could not convert ", source_path, ".")
  }

  markdown <- read_utf8(output_path)
  markdown <- restore_references(markdown, protected$replacements)
  markdown <- restore_environment_titles(
    markdown,
    environment_titles$replacements
  )
  markdown <- gsub(
    "\\\\label\\{(eq:[^{}]+)\\}",
    "(\\\\#\\1)",
    markdown,
    perl = TRUE
  )
  write_utf8(markdown, output_path)
  protected$unresolved
}

read_project_macros <- function(notes_dir) {
  paths <- c(
    file.path(notes_dir, "_shared", "macros.tex"),
    file.path(notes_dir, "macros.tex")
  )
  paths <- paths[file.exists(paths)]
  paste(vapply(paths, read_utf8, character(1)), collapse = "\n\n")
}

convert_latex_project <- function(notes_dir, pandoc_path, conversion_dir) {
  chapter_dirs <- list.dirs(notes_dir, recursive = TRUE, full.names = TRUE)
  chapter_dirs <- chapter_dirs[
    grepl("^[0-9]{2}-", basename(chapter_dirs), perl = TRUE)
  ]
  chapter_dirs <- chapter_dirs[
    order(basename(chapter_dirs), chapter_dirs, method = "radix")
  ]

  if (!length(chapter_dirs)) {
    stop(
      "No chapter folders were found. ",
      "Chapter folder names must begin with two digits and a hyphen."
    )
  }

  part_sources <- lapply(seq_along(chapter_dirs), function(index) {
    chapter_number <- substr(basename(chapter_dirs[[index]]), 1L, 2L)
    pattern <- paste0(
      "^", chapter_number, "-[0-9]{2}-.+\\.[Tt][Ee][Xx]$"
    )
    sort(
      list.files(
        chapter_dirs[[index]],
        pattern = pattern,
        recursive = FALSE,
        full.names = TRUE
      ),
      method = "radix"
    )
  })
  chapter_sources <- file.path(
    chapter_dirs,
    paste0(basename(chapter_dirs), ".tex")
  )
  missing <- chapter_sources[!file.exists(chapter_sources)]
  if (length(missing)) {
    stop(
      "Each chapter folder must contain a matching .tex file. Missing: ",
      paste(basename(missing), collapse = ", ")
    )
  }

  main_path <- file.path(notes_dir, "main.tex")
  preface_path <- file.path(notes_dir, "preface.tex")
  if (!file.exists(main_path) || !file.exists(preface_path)) {
    stop("notes/main.tex and notes/preface.tex are required.")
  }
  macros <- read_project_macros(notes_dir)

  dir.create(conversion_dir, recursive = TRUE, showWarnings = FALSE)
  all_chapter_sources <- unlist(
    Map(c, as.list(chapter_sources), part_sources),
    use.names = FALSE
  )
  label_sources <- preface_path
  label_pages <- "index.html"
  for (index in seq_along(chapter_dirs)) {
    sources <- c(chapter_sources[[index]], part_sources[[index]])
    label_sources <- c(label_sources, sources)
    label_pages <- c(
      label_pages,
      rep(paste0(basename(chapter_dirs[[index]]), ".html"), length(sources))
    )
  }
  label_types <- collect_label_types(label_sources)
  label_targets <- collect_label_targets(label_sources, label_pages)
  generated_chapters <- file.path(
    chapter_dirs,
    paste0(basename(chapter_dirs), ".Rmd")
  )

  unresolved <- character()
  for (index in seq_along(chapter_sources)) {
    unresolved <- unique(c(unresolved, convert_tex_file(
      chapter_sources[[index]],
      generated_chapters[[index]],
      pandoc_path,
      conversion_dir,
      label_types,
      macros,
      strip_inputs = TRUE,
      label_targets = label_targets
    )))

    if (length(part_sources[[index]])) {
      converted_sections <- character()
      for (section_source in part_sources[[index]]) {
        section_output <- file.path(
          conversion_dir,
          paste0(basename(section_source), ".md")
        )
        unresolved <- unique(c(unresolved, convert_tex_file(
          section_source,
          section_output,
          pandoc_path,
          conversion_dir,
          label_types,
          macros,
          strip_inputs = TRUE,
          label_targets = label_targets
        )))
        converted_sections <- c(converted_sections, read_utf8(section_output))
      }

      combined_chapter <- paste(
        c(read_utf8(generated_chapters[[index]]), converted_sections),
        collapse = "\n\n"
      )
      write_utf8(combined_chapter, generated_chapters[[index]])
    }
  }

  generated_preface <- file.path(conversion_dir, "preface.md")
  unresolved <- unique(c(unresolved, convert_tex_file(
    preface_path,
    generated_preface,
    pandoc_path,
    conversion_dir,
    label_types,
    macros,
    label_targets = label_targets
  )))

  main <- read_utf8(main_path)
  title <- capture_tex_command(main, "title", "Notes")
  author <- capture_tex_command(main, "author", "Your name")
  index_path <- file.path(notes_dir, "index.Rmd")
  index <- paste(
    c(
      "---",
      paste("title:", yaml_quote(title)),
      paste("author:", yaml_quote(author)),
      'date: "`r format(Sys.Date(), \'%d %B %Y\')`"',
      'bibliography: "references.bib"',
      'biblio-style: "plainnat"',
      "link-citations: true",
      "site: bookdown::bookdown_site",
      "documentclass: book",
      "---",
      "",
      read_utf8(generated_preface),
      ""
    ),
    collapse = "\n"
  )
  write_utf8(index, index_path)

  notes_prefix_length <- nchar(
    normalizePath(notes_dir, winslash = "/", mustWork = TRUE)
  ) + 2L
  relative_chapters <- substring(
    normalizePath(generated_chapters, winslash = "/", mustWork = TRUE),
    notes_prefix_length
  )

  list(
    chapter_dirs = chapter_dirs,
    chapter_files = relative_chapters,
    generated_files = c(index_path, generated_chapters),
    unresolved_labels = unresolved,
    part_counts = lengths(part_sources),
    source_count = length(chapter_sources) + sum(lengths(part_sources))
  )
}
