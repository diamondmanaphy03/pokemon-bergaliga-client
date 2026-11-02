# fix-config-links.ps1
# Sustituye los "enlaces rotos" de Git (archivos de texto de menos de 200 bytes que contienen
# una ruta como ../../config/coil.json) por el archivo real.
#
# Ejecutar desde la raiz del cliente (la carpeta pokemon-bergaliga-client):
#   powershell -ExecutionPolicy Bypass -File .\fix-config-links.ps1

$root = (Get-Location).Path
$destDir = Join-Path $root 'play.pokemonshowdown.com\config'
$srcDir = Join-Path $root 'config'
$names = @('coil.json', 'colors.json', 'config-test.js')

if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force $destDir | Out-Null
}

function Test-Stub($path) {
    # Un "stub" es el archivo de texto que deja Git en Windows en lugar de un enlace simbolico
    if (-not (Test-Path $path -PathType Leaf)) { return $false }
    if ((Get-Item $path).Length -ge 200) { return $false }
    $text = Get-Content $path -Raw
    if (-not $text) { return $false }
    return ($text.Trim() -match '^\.\./')
}

foreach ($name in $names) {
    $dest = Join-Path $destDir $name
    $src = Join-Path $srcDir $name
    Write-Host ""
    Write-Host "== $name"

    if ((Test-Path $dest -PathType Leaf) -and -not (Test-Stub $dest)) {
        Write-Host "   OK: ya es un archivo real ($((Get-Item $dest).Length) bytes). No se toca."
        continue
    }

    if (Test-Path $dest -PathType Leaf) {
        Write-Host "   Es un enlace roto de Git (contiene: $((Get-Content $dest -Raw).Trim()))"
    } else {
        Write-Host "   No existe en la carpeta de destino."
    }

    # 1) Si existe el archivo real en la carpeta config de la raiz: enlace duro (o copia)
    if ((Test-Path $src -PathType Leaf) -and -not (Test-Stub $src)) {
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        try {
            New-Item -ItemType HardLink -Path $dest -Target $src -ErrorAction Stop | Out-Null
            Write-Host "   Enlazado a $src"
        } catch {
            Copy-Item $src $dest -Force
            Write-Host "   No se pudo enlazar; copiado desde $src (repite el script si ese archivo cambia)."
        }
        continue
    }

    # 2) Si no existe: descargar la version oficial como respaldo
    Write-Host "   No hay una version real en la carpeta config de la raiz. Descargando la oficial..."
    $url = "https://play.pokemonshowdown.com/config/$name"
    $tmp = "$dest.download"
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
        $content = Get-Content $tmp -Raw
        $valid = $true
        if (-not $content) {
            $valid = $false
        } elseif ($name -like '*.json') {
            try { $null = $content | ConvertFrom-Json } catch { $valid = $false }
        } elseif ($content.TrimStart().StartsWith('<')) {
            $valid = $false
        }
        if ($valid) {
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
            Move-Item $tmp $dest -Force
            Write-Host "   Descargado de $url"
        } else {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Host "   La respuesta de $url no parece valida. No se ha cambiado nada."
        }
    } catch {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Host "   No se pudo descargar ${url}: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Estado final:"
foreach ($name in $names) {
    $dest = Join-Path $destDir $name
    if (Test-Path $dest) {
        Write-Host ("   {0}: {1} bytes" -f $name, (Get-Item $dest).Length)
    } else {
        Write-Host "   ${name}: NO EXISTE"
    }
}
Write-Host ""
Write-Host "Ahora recarga el cliente con Ctrl+F5."
