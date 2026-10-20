$ErrorActionPreference = "Stop"

$rVersion = "4.6.1"
$pandocVersion = "3.10.1"
$rDir = Join-Path $PSScriptRoot "R"
$libraryDir = Join-Path $PSScriptRoot "library"
$pandocDir = Join-Path $PSScriptRoot "pandoc\pandoc-$pandocVersion"
$downloadDir = Join-Path $PSScriptRoot "downloads"

New-Item -ItemType Directory -Force -Path $downloadDir, $libraryDir | Out-Null

$rScript = Join-Path $rDir "bin\Rscript.exe"
if (-not (Test-Path -LiteralPath $rScript)) {
    $rInstaller = Join-Path $downloadDir "R-$rVersion-win.exe"
    if (-not (Test-Path -LiteralPath $rInstaller)) {
        Write-Host "Downloading R $rVersion..."
        Invoke-WebRequest `
            -Uri "https://cloud.r-project.org/bin/windows/base/R-$rVersion-win.exe" `
            -OutFile $rInstaller
    }

    Write-Host "Installing R locally..."
    $install = Start-Process `
        -FilePath $rInstaller `
        -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/NOICONS", "/DIR=$rDir" `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($install.ExitCode -ne 0) {
        throw "The R installer exited with code $($install.ExitCode)."
    }
}

$pandocExe = Join-Path $pandocDir "pandoc.exe"
if (-not (Test-Path -LiteralPath $pandocExe)) {
    $pandocZip = Join-Path $downloadDir "pandoc-$pandocVersion-windows-x86_64.zip"
    if (-not (Test-Path -LiteralPath $pandocZip)) {
        Write-Host "Downloading Pandoc $pandocVersion..."
        Invoke-WebRequest `
            -Uri "https://github.com/jgm/pandoc/releases/download/$pandocVersion/pandoc-$pandocVersion-windows-x86_64.zip" `
            -OutFile $pandocZip
    }

    Write-Host "Unpacking Pandoc locally..."
    $pandocParent = Split-Path -Parent $pandocDir
    New-Item -ItemType Directory -Force -Path $pandocParent | Out-Null
    Expand-Archive -LiteralPath $pandocZip -DestinationPath $pandocParent -Force
}

$env:R_LIBS_USER = $libraryDir
$env:RSTUDIO_PANDOC = $pandocDir

Write-Host "Installing Bookdown and its required packages locally..."
& $rScript (Join-Path $PSScriptRoot "install-packages.R") $libraryDir
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Local installation is ready."
