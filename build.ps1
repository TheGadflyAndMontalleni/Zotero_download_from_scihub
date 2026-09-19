<#
    Build scihub-ua-fix.xpi from src/

    A Zotero plugin is just a zip archive with manifest.json at the ROOT
    (not inside a folder), so that is all this does.

    NOTE: we do NOT use [ZipFile]::CreateFromDirectory(). On Windows that
    writes entry names with BACKSLASHES (e.g. "content\icons\icon.svg"),
    while the ZIP spec requires forward slashes. Readers that follow the
    spec then cannot find the nested files at all. Entries are therefore
    added one by one with normalised names.

    Usage:  pwsh ./build.ps1
#>

$ErrorActionPreference = 'Stop'

$root    = $PSScriptRoot
$srcDir  = Join-Path $root 'src'
$outFile = Join-Path $root 'scihub-ua-fix.xpi'

if (-not (Test-Path (Join-Path $srcDir 'manifest.json'))) {
    throw "src/manifest.json not found - run this from the repository root."
}

# Validate the manifest before packaging
$manifest = Get-Content (Join-Path $srcDir 'manifest.json') -Raw | ConvertFrom-Json
Write-Host ("Building {0} v{1}" -f $manifest.name, $manifest.version)

if (Test-Path $outFile) { Remove-Item $outFile -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$srcFull = (Resolve-Path $srcDir).Path
$zip = [System.IO.Compression.ZipFile]::Open(
    $outFile,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    foreach ($f in (Get-ChildItem -Path $srcDir -Recurse -File | Sort-Object FullName)) {
        $rel = $f.FullName.Substring($srcFull.Length).TrimStart('\', '/')
        # ZIP entry names always use forward slashes, on every platform
        $entryName = $rel.Replace('\', '/')

        $entry = $zip.CreateEntry(
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        )
        $es = $entry.Open()
        try {
            $fs = [System.IO.File]::OpenRead($f.FullName)
            try { $fs.CopyTo($es) } finally { $fs.Dispose() }
        }
        finally { $es.Dispose() }
    }
}
finally { $zip.Dispose() }

# Verify the archive layout
$zip = [System.IO.Compression.ZipFile]::OpenRead($outFile)
try {
    Write-Host "Archive contents:"
    $names = @()
    foreach ($e in $zip.Entries) {
        $names += $e.FullName
        Write-Host ("  {0}  ({1} bytes)" -f $e.FullName, $e.Length)
    }

    if ($names -notcontains 'manifest.json') {
        throw "manifest.json is not at the archive root - Zotero will reject this plugin."
    }
    $bad = $names | Where-Object { $_ -like '*\*' }
    if ($bad) {
        throw ("Backslash in ZIP entry name(s): " + ($bad -join ', '))
    }
}
finally {
    $zip.Dispose()
}

Write-Host ("`nOK -> {0} ({1} bytes)" -f $outFile, (Get-Item $outFile).Length)
$hash = (Get-FileHash $outFile -Algorithm SHA256).Hash.ToLower()
Write-Host ("sha256:{0}" -f $hash)
