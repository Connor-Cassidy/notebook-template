$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "notes\main.tex"))) {
    throw "No notebook has been created here. In your private copy, copy the contents of starter\notes into notes first. See README.md."
}

$rScript = Join-Path $PSScriptRoot "R\bin\Rscript.exe"
$pandocDir = Join-Path $PSScriptRoot "pandoc\pandoc-3.10.1"
$libraryDir = Join-Path $PSScriptRoot "library"

if (-not (Test-Path -LiteralPath $rScript) -or
    -not (Test-Path -LiteralPath (Join-Path $pandocDir "pandoc.exe")) -or
    -not (Test-Path -LiteralPath (Join-Path $libraryDir "bookdown"))) {
    Write-Host "Local tools are incomplete; running the one-time setup..."
    & (Join-Path $PSScriptRoot "setup.ps1")
}

$env:R_LIBS_USER = $libraryDir
$env:RSTUDIO_PANDOC = $pandocDir

Write-Host "Compiling the notes..."
& $rScript (Join-Path $PSScriptRoot "render.R") $projectRoot
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
