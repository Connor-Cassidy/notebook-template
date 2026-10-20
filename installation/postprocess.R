read_html <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

write_html <- function(path, html) {
  writeLines(enc2utf8(html), path, useBytes = TRUE)
}

capture_groups <- function(pattern, text) {
  match <- regexec(pattern, text, perl = TRUE)
  values <- regmatches(text, match)[[1L]]
  if (!length(values)) character() else values[-1L]
}

find_matching_div <- function(html, start) {
  remainder <- substring(html, start)
  matches <- gregexpr("</?div\\b[^>]*>", remainder, perl = TRUE)[[1L]]
  if (matches[[1L]] == -1L) {
    stop("Could not locate a generated bibliography block.")
  }

  lengths <- attr(matches, "match.length")
  tokens <- regmatches(remainder, list(matches))[[1L]]
  depth <- 0L

  for (index in seq_along(tokens)) {
    if (startsWith(tokens[[index]], "</div")) {
      depth <- depth - 1L
    } else {
      depth <- depth + 1L
    }

    if (depth == 0L) {
      return(start + matches[[index]] + lengths[[index]] - 2L)
    }
  }

  stop("The generated bibliography contains an unmatched <div>.")
}

remove_duplicate_full_bibliography <- function(html) {
  starts <- gregexpr('<div id="refs"', html, fixed = TRUE)[[1L]]
  if (starts[[1L]] == -1L) {
    return(html)
  }

  for (start in starts) {
    end <- find_matching_div(html, start)
    block <- substr(html, start, end)
    if (!grepl('id="ref-', block, fixed = TRUE)) {
      before <- if (start > 1L) substr(html, 1L, start - 1L) else ""
      after <- if (end < nchar(html)) substr(html, end + 1L, nchar(html)) else ""
      return(paste0(before, after))
    }
  }

  html
}

collect_citation_locations <- function(site_dir) {
  pages <- list.files(site_dir, pattern = "\\.html$", full.names = TRUE)
  pages <- pages[!basename(pages) %in% c("404.html", "bibliography.html")]
  locations <- list()

  for (page in pages) {
    lines <- readLines(page, warn = FALSE, encoding = "UTF-8")
    current_label <- "Preface"
    current_url <- paste0(basename(page), "#section-")

    for (line in lines) {
      chapter <- capture_groups(
        '<div id="([^"]+)" class="section level1[^"]*" number="([^"]+)"',
        line
      )
      if (length(chapter)) {
        current_url <- paste0(basename(page), "#", chapter[[1L]])
        current_label <- paste("Chapter", chapter[[2L]])
      }

      section <- capture_groups(
        '<div id="([^"]+)" class="section level[2-6][^"]*" number="([^"]+)"',
        line
      )
      if (length(section)) {
        current_url <- paste0(basename(page), "#", section[[1L]])
        current_label <- paste("Section", section[[2L]])
      }

      matches <- gregexpr('href="#ref-([^"]+)"', line, perl = TRUE)
      citations <- regmatches(line, matches)[[1L]]
      if (!length(citations)) {
        next
      }

      keys <- sub('"$', "", sub('^href="#ref-', "", citations))
      location <- paste(current_url, current_label, sep = "\t")
      for (key in keys) {
        locations[[key]] <- unique(c(locations[[key]], location))
      }
    }
  }

  locations
}

add_bibliography_backlinks <- function(html, locations) {
  css <- paste0(
    "<style>",
    ".citation-backlinks{margin-top:.35em;font-size:.9em;}",
    ".citation-backlinks-label{font-weight:600;}",
    "</style>\n"
  )
  html <- sub("</head>", paste0(css, "</head>"), html, fixed = TRUE)

  for (key in names(locations)) {
    marker <- paste0('<div id="ref-', key, '" class="csl-entry">')
    start <- regexpr(marker, html, fixed = TRUE)[[1L]]
    if (start == -1L) {
      next
    }

    end <- find_matching_div(html, start)
    block <- substr(html, start, end)
    parts <- strsplit(locations[[key]], "\t", fixed = TRUE)
    links <- vapply(parts, function(location) {
      paste0('<a href="', location[[1L]], '">', location[[2L]], "</a>")
    }, character(1))
    backlinks <- paste0(
      '\n<div class="citation-backlinks"><span class="citation-backlinks-label">',
      "Cited in:</span> ",
      paste(links, collapse = ", "),
      "</div>"
    )
    block <- sub("</div>$", paste0(backlinks, "\n</div>"), block)

    before <- if (start > 1L) substr(html, 1L, start - 1L) else ""
    after <- if (end < nchar(html)) substr(html, end + 1L, nchar(html)) else ""
    html <- paste0(before, block, after)
  }

  html
}

link_cross_reference_prefixes <- function(html) {
  gsub(
    "(Chapter|Section|Figure|Table|Equation)\\s+<a([^>]*)>([^<]+)</a>",
    "<a\\2>\\1 \\3</a>",
    html,
    perl = TRUE
  )
}

extract_ids <- function(html) {
  matches <- gregexpr('\\bid="([^"]+)"', html, perl = TRUE)[[1L]]
  if (matches[[1L]] == -1L) {
    return(character())
  }

  values <- regmatches(html, list(matches))[[1L]]
  unique(sub('^id="([^"]+)"$', "\\1", values, perl = TRUE))
}

first_match <- function(pattern, text) {
  match <- regexpr(pattern, text, perl = TRUE)
  start <- match[[1L]]
  if (start == -1L) {
    return("")
  }

  length <- attr(match, "match.length")[[1L]]
  substr(text, start, start + length - 1L)
}

box_theorem_environments <- function(html) {
  kinds <- paste(
    c(
      "theorem", "definition", "lemma", "proposition", "corollary",
      "conjecture", "assumption", "example", "exercise", "remark"
    ),
    collapse = "|"
  )
  start_pattern <- paste0('<div class="(', kinds, ')">')
  starts <- gregexpr(start_pattern, html, perl = TRUE)[[1L]]
  if (starts[[1L]] == -1L) {
    return(html)
  }
  lengths <- attr(starts, "match.length")

  for (index in rev(seq_along(starts))) {
    start <- starts[[index]]
    start_tag <- substr(html, start, start + lengths[[index]] - 1L)
    groups <- regmatches(
      start_tag,
      regexec(start_pattern, start_tag, perl = TRUE)
    )[[1L]]
    kind <- groups[[2L]]
    end <- find_matching_div(html, start)
    block <- substr(html, start, end)
    header <- first_match(
      paste0(
        '(?s)<span id="[^"]+" class="', kind, '"[^>]*>',
        '<strong>.*?</strong></span>'
      ),
      block
    )
    title_tag <- first_match(
      '(?s)<span class="theorem-custom-title">.*?</span>\\s*<br\\s*/?>',
      block
    )
    title <- if (nzchar(title_tag)) {
      sub(
        '(?s)^<span class="theorem-custom-title">(.*?)</span>.*$',
        "\\1",
        title_tag,
        perl = TRUE
      )
    } else {
      ""
    }

    body <- substr(
      block,
      nchar(start_tag) + 1L,
      nchar(block) - nchar("</div>")
    )
    body <- sub(header, "", body, fixed = TRUE)
    if (nzchar(title_tag)) {
      body <- sub(title_tag, "", body, fixed = TRUE)
    }
    body <- gsub("<p>\\s*</p>", "", body, perl = TRUE)
    body <- trimws(body)

    title_html <- if (nzchar(title)) {
      paste0('<span class="theorem-box-title"> &mdash; ', title, "</span>")
    } else {
      ""
    }

    replacement <- paste0(
      '<div class="theorem-box ', kind, '">',
      '<div class="theorem-box-heading">', header, title_html, "</div>",
      '<div class="theorem-box-body">', body, "</div>",
      "</div>"
    )

    before <- if (start > 1L) substr(html, 1L, start - 1L) else ""
    after <- if (end < nchar(html)) substr(html, end + 1L, nchar(html)) else ""
    html <- paste0(before, replacement, after)
  }

  html
}

add_theorem_box_styles <- function(html) {
  css <- paste0(
    "<style>",
    ".theorem-box{margin:1.25rem 0;border:1px solid #9fb5c8;",
    "border-left:4px solid #38678f;border-radius:6px;",
    "background:#fbfdff;overflow:hidden;}",
    ".theorem-box-heading{padding:.65rem .9rem;background:#eaf2f8;",
    "color:#21384c;font-weight:600;line-height:1.35;}",
    ".theorem-box-heading strong{font-weight:700;}",
    ".theorem-box-title{font-style:italic;font-weight:600;}",
    ".theorem-box-body{padding:.85rem .95rem;}",
    ".theorem-box-body>p:first-child{margin-top:0;}",
    ".theorem-box-body>p:last-child{margin-bottom:0;}",
    ".theorem-box.theorem,.theorem-box.lemma,.theorem-box.proposition,",
    ".theorem-box.corollary{border-left-color:#6b4c9a;}",
    ".theorem-box.theorem .theorem-box-heading,",
    ".theorem-box.lemma .theorem-box-heading,",
    ".theorem-box.proposition .theorem-box-heading,",
    ".theorem-box.corollary .theorem-box-heading{background:#f0ecf7;}",
    "</style>\n"
  )
  sub("</head>", paste0(css, "</head>"), html, fixed = TRUE)
}

collect_xref_previews <- function(site_dir) {
  pages <- list.files(site_dir, pattern = "\\.html$", full.names = TRUE)
  pages <- pages[basename(pages) != "404.html"]
  previews <- list()
  preview_classes <- paste(
    c(
      "theorem", "definition", "lemma", "proposition", "corollary",
      "conjecture", "assumption", "example", "exercise", "remark",
      "proof", "solution",
      "figure", "table", "csl-entry"
    ),
    collapse = "|"
  )

  for (page in pages) {
    html <- read_html(page)
    page_name <- basename(page)

    block_pattern <- paste0(
      '<div\\b[^>]*class="(?:[^"]*\\s)?(?:', preview_classes,
      ')(?:\\s[^"]*)?"[^>]*>'
    )
    block_starts <- gregexpr(block_pattern, html, perl = TRUE)[[1L]]
    if (block_starts[[1L]] != -1L) {
      for (start in block_starts) {
        end <- find_matching_div(html, start)
        block <- substr(html, start, end)
        for (id in extract_ids(block)) {
          previews[[paste0(page_name, "#", id)]] <- block
        }
      }
    }

    section_pattern <- paste0(
      '<div id="[^"]+" class="section level[1-6][^"]*"',
      '[^>]*>'
    )
    section_starts <- gregexpr(section_pattern, html, perl = TRUE)[[1L]]
    if (section_starts[[1L]] != -1L) {
      section_tags <- regmatches(html, list(section_starts))[[1L]]
      for (index in seq_along(section_starts)) {
        id <- sub(
          '^<div id="([^"]+)".*$',
          "\\1",
          section_tags[[index]],
          perl = TRUE
        )
        remainder_start <- section_starts[[index]] + nchar(section_tags[[index]])
        remainder <- substr(html, remainder_start, nchar(html))
        heading <- first_match("(?s)^\\s*<h[1-6]\\b[^>]*>.*?</h[1-6]>", remainder)
        after_heading <- if (nzchar(heading)) {
          substr(remainder, nchar(heading) + 1L, nchar(remainder))
        } else {
          remainder
        }
        paragraph <- first_match("(?s)^\\s*<p\\b[^>]*>.*?</p>", after_heading)
        preview <- paste0(heading, paragraph)
        if (nzchar(preview)) {
          previews[[paste0(page_name, "#", id)]] <- preview
        }
      }
    }
  }

  previews
}

write_xref_preview_asset <- function(site_dir, previews) {
  script_source <- file.path(dirname(site_dir), "xref-preview.js")
  if (!file.exists(script_source)) {
    stop("The cross-reference preview script is missing: ", script_source)
  }

  preview_json <- jsonlite::toJSON(
    previews,
    auto_unbox = TRUE,
    null = "null",
    pretty = FALSE
  )
  generated_script <- c(
    paste0("window.BOOKDOWN_XREF_PREVIEWS = ", preview_json, ";"),
    readLines(script_source, warn = FALSE, encoding = "UTF-8")
  )
  writeLines(
    enc2utf8(generated_script),
    file.path(site_dir, "xref-previews.js"),
    useBytes = TRUE
  )
}

add_xref_preview_assets <- function(html) {
  css <- paste0(
    "<style>",
    ".xref-preview-popover{position:fixed;display:none;z-index:10000;",
    "box-sizing:border-box;width:min(36rem,calc(100vw - 24px));max-height:55vh;",
    "overflow:auto;padding:1rem 1.1rem;background:#fff;color:#222;",
    "border:1px solid #c9c9c9;border-radius:6px;",
    "box-shadow:0 8px 28px rgba(0,0,0,.24);font-size:.94rem;line-height:1.45;}",
    ".xref-preview-popover.is-visible{display:block;}",
    ".xref-preview-popover h1,.xref-preview-popover h2,",
    ".xref-preview-popover h3,.xref-preview-popover h4{margin:.1rem 0 .65rem;",
    "font-size:1.08rem;line-height:1.3;}",
    ".xref-preview-popover p:last-child{margin-bottom:0;}",
    ".xref-preview-popover .anchor-section{display:none;}",
    ".xref-preview-popover .citation-backlinks{margin-top:.7rem;}",
    ".xref-preview-link:focus{outline:2px solid #4183c4;outline-offset:2px;}",
    "@media(max-width:600px){.xref-preview-popover{max-height:45vh;}}",
    "</style>\n"
  )
  html <- sub("</head>", paste0(css, "</head>"), html, fixed = TRUE)
  sub(
    "</body>",
    '<script src="xref-previews.js"></script>\n</body>',
    html,
    fixed = TRUE
  )
}

postprocess_book <- function(site_dir) {
  locations <- collect_citation_locations(site_dir)
  bibliography_path <- file.path(site_dir, "bibliography.html")

  if (!file.exists(bibliography_path)) {
    stop("The generated bibliography chapter is missing.")
  }

  bibliography <- read_html(bibliography_path)
  bibliography <- remove_duplicate_full_bibliography(bibliography)
  bibliography <- sub("<h3>References</h3>\\s*", "", bibliography, perl = TRUE)
  bibliography <- add_bibliography_backlinks(bibliography, locations)
  write_html(bibliography_path, bibliography)

  pages <- list.files(site_dir, pattern = "\\.html$", full.names = TRUE)
  for (page in pages) {
    html <- read_html(page)
    html <- link_cross_reference_prefixes(html)
    html <- box_theorem_environments(html)
    html <- add_theorem_box_styles(html)
    html <- sub(
      "</head>",
      paste0(
        "<style>",
        ".unresolved-reference{color:#c00000;font-weight:600;}",
        "</style>\n</head>"
      ),
      html,
      fixed = TRUE
    )
    write_html(page, html)
  }

  previews <- collect_xref_previews(site_dir)
  write_xref_preview_asset(site_dir, previews)

  for (page in pages) {
    html <- read_html(page)
    html <- add_xref_preview_assets(html)
    write_html(page, html)
  }

  invisible(site_dir)
}
