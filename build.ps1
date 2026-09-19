<#
    Build scihub-ua-fix.xpi from src/

    A Zotero plugin is just a zip archive with manifest.json at the ROOT
    (not inside a folder), so that is all this does.

    Usage:  pwsh ./build.ps1
#>

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$srcDir = Join-Path $root 'src'
$outFile = Join-Path $root 'scihub-ua-fix.xpi'

if (-not (Test-Path (Join-Path $srcDir 'manifest.json'))) {
    throw "src/manifest.json not found - run this from the repository root."
}

# Validate the manifest before packaging
$manifest = Get-Content (Join-Path $srcDir 'manifest.json') -Raw | ConvertFrom-Json
Write-Host ("Building {0} v{1}" -f $manifest.name, $manifest.version)

if (Test-Path $outFile) { Remove-Item $outFile -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $srcDir,
    $outFile,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false   # includeBaseDirectory = false  ->  manifest.json lands at the root
)

# Verify the archive layout
$zip = [System.IO.Compression.ZipFile]::OpenRead($outFile)
try {
    $names = $zip.Entries | ForEach-Object { $_.FullName }
    Write-Host "Archive contents:"
    $zip.Entries | ForEach-Object { Write-Host ("  {0}  ({1} bytes)" -f $_.FullName, $_.Length) }
    if ($names -notcontains 'manifest.json') {
        throw "manifest.json is not at the archive root - Zotero will reject this plugin."
    }
}
finally {
    $zip.Dispose()
}

Write-Host ("`nOK -> {0} ({1} bytes)" -f $outFile, (Get-Item $outFile).Length)
