# Selective Documentation Backup Script
# Vylučuje externí SW dle .gitignore

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupRoot = "backup_docs_$timestamp"
New-Item -ItemType Directory -Path $backupRoot -Force

# Definice vyloučených cest (regex)
$excludePatterns = @(
    "\\\.venv\\",
    "\\node_modules\\",
    "\\\.git\\",
    "\\target\\",
    "\\\.svelte-kit\\",
    "\\\.package\\",
    "\\build\\",
    "\\docs\\spec-kit\\",
    "\\sandbox\\portable_bench\\ffmpeg\\",
    "\\sandbox\\portable_bench\\wheels\\",
    "\\sandbox\\portable_bench\\venv-system\\",
    "\\sandbox\\portable_bench\\python-embed\\",
    "\\tools\\graphviz\\",
    "\\site-packages\\"
)

# Vyhledání všech .md souborů
$mdFiles = Get-ChildItem -Path . -Recurse -Filter *.md

foreach ($file in $mdFiles) {
    $isExcluded = $false
    foreach ($pattern in $excludePatterns) {
        if ($file.FullName -match [regex]::Escape($pattern).Replace("\\\\", "\\")) {
            $isExcluded = $true
            break
        }
    }

    # Speciální kontrola pro dynamické vzory (bez escape pokud chceme regex, ale zde spíše substring)
    foreach ($pattern in $excludePatterns) {
        if ($file.FullName.Contains($pattern.Replace("\\", [System.IO.Path]::DirectorySeparatorChar))) {
            $isExcluded = $true
            break
        }
    }

    if (-not $isExcluded) {
        $relativePath = Resolve-Path -Path $file.FullName -Relative
        # Odstranění .\ na začátku
        $relativePath = $relativePath -replace "^\.\\", ""
        
        $destPath = Join-Path -Path $backupRoot -ChildPath $relativePath
        $destDir = Split-Path -Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force
        }
        
        Copy-Item -Path $file.FullName -Destination $destPath
        Write-Host "Backed up: $relativePath"
    }
}

Write-Host "`nBackup completed in: $backupRoot" -ForegroundColor Green
