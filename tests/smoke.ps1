param(
    [string]$ToolsRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "installation")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$ToolsRoot = [IO.Path]::GetFullPath($ToolsRoot)
$rScript = Join-Path $ToolsRoot "R\bin\Rscript.exe"
$pandocDir = Join-Path $ToolsRoot "pandoc\pandoc-3.10.1"
if (-not (Test-Path -LiteralPath $rScript) -or
    -not (Test-Path -LiteralPath (Join-Path $pandocDir "pandoc.exe"))) {
    throw "Install the local tools with installation\setup.ps1, or pass -ToolsRoot pointing to an existing installation folder."
}

$fixtureRoot = Join-Path $projectRoot (".local\smoke-" + [guid]::NewGuid().ToString("N"))
$fixtureNotes = Join-Path $fixtureRoot "notes"
$fixtureInstallation = Join-Path $fixtureRoot "installation"
New-Item -ItemType Directory -Force -Path $fixtureNotes, $fixtureInstallation | Out-Null
Copy-Item -Path (Join-Path $projectRoot "starter\notes\*") -Destination $fixtureNotes -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot "notes\_shared") -Destination $fixtureNotes -Recurse
foreach ($name in @("render.R", "latex-to-bookdown.R", "postprocess.R", "xref-preview.js", "notes-launcher.html")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "installation\$name") -Destination $fixtureInstallation
}

$env:R_LIBS_USER = Join-Path $ToolsRoot "library"
$env:RSTUDIO_PANDOC = $pandocDir

function Build-Fixture([string]$LogName) {
    $log = Join-Path $fixtureRoot $LogName
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $rScript (Join-Path $fixtureInstallation "render.R") $fixtureRoot *> $log
    $status = $LASTEXITCODE
    $ErrorActionPreference = $oldPreference
    if ($status -ne 0) {
        Get-Content -LiteralPath $log | Write-Host
        throw "Starter build failed; see $log"
    }
}

function Assert-Contains([string]$Text, [string]$Value, [string]$Description) {
    if (-not $Text.Contains($Value)) { throw "Missing $Description ($Value) in $fixtureRoot" }
}

Build-Fixture "starter-build.log"
$site = Join-Path $fixtureInstallation "site"
foreach ($name in @("index.html", "01-example.html", "bibliography.html", "xref-previews.js")) {
    if (-not (Test-Path -LiteralPath (Join-Path $site $name))) { throw "Missing generated $name" }
}
$chapter = Get-Content -LiteralPath (Join-Path $site "01-example.html") -Raw -Encoding UTF8
$bibliography = Get-Content -LiteralPath (Join-Path $site "bibliography.html") -Raw -Encoding UTF8
$previews = Get-Content -LiteralPath (Join-Path $site "xref-previews.js") -Raw -Encoding UTF8
Assert-Contains $chapter '\mathbb{R}' "shared macro expansion"
Assert-Contains $chapter '\(7\)' "notebook-specific macro expansion"
Assert-Contains $chapter 'class="theorem-box' "theorem box"
Assert-Contains $chapter 'A demonstration' "custom theorem title/reference"
Assert-Contains $chapter 'class="unresolved-reference"' "unfinished reference marker"
Assert-Contains $bibliography 'citation-backlinks' "bibliography backlinks"
Assert-Contains $bibliography 'An Invented Reference' "cited starter reference"
Assert-Contains $previews '01-example.html#defn:example' "reference preview target"
Assert-Contains $previews 'bibliography.html#ref-example-notebook' "citation preview target"
if (Get-ChildItem -LiteralPath $fixtureNotes -Filter *.Rmd -Recurse) {
    throw "Temporary Rmd files were not cleaned up."
}

Add-Content -LiteralPath (Join-Path $fixtureNotes "macros.tex") -Value '\renewcommand{\R}{\mathbb{Q}}' -Encoding UTF8
Build-Fixture "override-build.log"
$chapter = Get-Content -LiteralPath (Join-Path $site "01-example.html") -Raw -Encoding UTF8
Assert-Contains $chapter '\mathbb{Q}' "local override of the shared macro"
Write-Host "PASS: starter build, rendered features, shared/local macros, and cleanup."
Write-Host "Validation artifacts: $fixtureRoot"
