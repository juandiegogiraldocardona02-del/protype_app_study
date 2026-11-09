$ErrorActionPreference = 'Continue'

$projectRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $env:LOCALAPPDATA 'StudyPlanner\app'
$logPath = Join-Path $env:LOCALAPPDATA 'StudyPlanner\launcher.log'
$buildDir = Join-Path $projectRoot 'build\windows\x64\runner\Debug'
$buildExe = Join-Path $buildDir 'study_planner.exe'
$appExe = Join-Path $appRoot 'study_planner.exe'

New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null

function Show-Failure([string]$message) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "$message`r`n`r`nRevisa el registro:`r`n$logPath",
            'Study Planner',
            'OK',
            'Error'
        ) | Out-Null
    } catch {
        Write-Host $message
    }
}

try {
    "[$(Get-Date -Format o)] Iniciando Study Planner" | Out-File -FilePath $logPath -Append -Encoding utf8

    $flutterBin = Join-Path $env:USERPROFILE 'flutter\bin'
    if (Test-Path (Join-Path $flutterBin 'flutter.bat')) {
        $env:Path = "$flutterBin;$env:Path"
    }
    $llvmBin = 'C:\Program Files\LLVM\bin'
    if (Test-Path $llvmBin) {
        $env:Path = "$llvmBin;$env:Path"
        $env:LIBCLANG_PATH = $llvmBin
    }

    $cargokitTemp = Join-Path $env:TEMP 'opencode\cargokit-temp'
    New-Item -ItemType Directory -Path $cargokitTemp -Force | Out-Null
    $env:STUDY_PLANNER_CARGOKIT_TEMP_DIR = $cargokitTemp

    Get-Process -Name 'study_planner' -ErrorAction SilentlyContinue | Stop-Process -Force

    Write-Host 'Compilando la última versión...'
    $buildLog = Join-Path $env:LOCALAPPDATA 'StudyPlanner\flutter_build.log'
    & flutter build windows --debug *> $buildLog
    if ($LASTEXITCODE -ne 0) {
        throw "La compilación falló con código $LASTEXITCODE."
    }
    Get-Content $buildLog -Raw | Out-Host

    if (-not (Test-Path $buildExe)) {
        throw "No se encontró el ejecutable compilado: $buildExe"
    }

    Write-Host 'Actualizando la copia local...'
    New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
    & robocopy $buildDir $appRoot /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "No se pudo actualizar la copia local (robocopy $LASTEXITCODE)."
    }

    Write-Host 'Abriendo Study Planner...'
    Start-Process -FilePath $appExe -WorkingDirectory $appRoot
    "[$(Get-Date -Format o)] Abierto: $appExe" | Out-File -FilePath $logPath -Append -Encoding utf8
} catch {
    $message = "No se pudo abrir Study Planner: $($_.Exception.Message)"
    "[$(Get-Date -Format o)] ERROR: $($_.Exception.Message)" | Out-File -FilePath $logPath -Append -Encoding utf8
    Show-Failure $message
    exit 1
}
