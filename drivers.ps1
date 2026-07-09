<#
.SYNOPSIS
    Backup / Restore de drivers de Windows (equivalente a drivers.bat)
.DESCRIPTION
    Detecta la placa base del equipo, y permite exportar (respaldar) o
    importar (restaurar) los drivers usando cmdlets nativos (Windows 10/11) o
    PnPUtil / copia manual (Windows 7/8).
#>

# --- Consola en UTF-8 ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- Cambiar tamano de fuente de la consola (equivalente al truco P/Invoke) ---
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32Font {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFO_EX {
        public uint cbSize;
        public uint nFont;
        public short dwFontSizeX;
        public short dwFontSizeY;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }
}
'@ -ErrorAction SilentlyContinue

    $fontInfo = New-Object Win32Font+CONSOLE_FONT_INFO_EX
    $fontInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($fontInfo)
    $fontInfo.dwFontSizeY = 20
    $fontInfo.FaceName = "Consolas"
    $hOut = [Win32Font]::GetStdHandle(-11)
    [Win32Font]::SetCurrentConsoleFontEx($hOut, $false, [ref]$fontInfo) | Out-Null
} catch {
    # Si falla el cambio de fuente, continuar sin interrumpir el script
}

# --- AUTO-ELEVACION UAC (ADMINISTRADOR) ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[INFO] Solicitando permisos de Administrador..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Detectando version de Windows..."

# --- Detectar version de Windows ---
$winVerMajor = [System.Environment]::OSVersion.Version.Major

Write-Host "Version de Kernel detectada: $winVerMajor"
Write-Host "==================================================="

# --- LOGICA DE SALTO HIBRIDA ---
$metodoBackup = ""
$marca = ""
$modelo = ""

if ($winVerMajor -ge 10) {
    # --- METODO MODERNO (Windows 10/11) ---
    Write-Host "[INFO] Windows 10/11 detectado."
    Write-Host "Usando metodo moderno nativo (cmdlets de PowerShell)..."

    $baseBoard = Get-CimInstance Win32_BaseBoard
    $marca = $baseBoard.Manufacturer.Trim()
    $modelo = $baseBoard.Product.Trim()
    $metodoBackup = "NATUR"
} else {
    # --- METODO ANTIGUO (Windows 7/8) ---
    Write-Host "[INFO] Windows antiguo detectado (7/8)."
    Write-Host "Usando metodo clasico (WMIC + Copia Directa)..."

    $baseBoard = Get-WmiObject Win32_BaseBoard
    $marca = $baseBoard.Manufacturer
    $modelo = $baseBoard.Product
    $metodoBackup = "MANUAL"
}

# --- FILTRO INTELIGENTE PARA EQUIPOS CLONICOS ---
if ([string]::IsNullOrWhiteSpace($modelo)) { $modelo = "Desconocido" }
if ($modelo -eq "To be filled by O.E.M.") { $modelo = "Clonico_$(Get-Random)" }
if ($modelo -eq "Default string") { $modelo = "Clonico_$(Get-Random)" }

# --- Limpiar caracteres extranos, comas o espacios para las carpetas ---
$marca  = $marca  -replace '\\', '_' -replace ' ', '_' -replace ',', '_'
$modelo = $modelo -replace '\\', '_' -replace ' ', '_' -replace ',', '_'

# --- Definir la ruta de destino ---
$scriptDir = Split-Path -Parent $PSCommandPath
$destino = Join-Path $scriptDir "drivers\$marca\$modelo"

Write-Host ""
Write-Host "Detectado: $marca - $modelo"
Write-Host ""

function Restaurar-Drivers {
    Write-Host ""
    Write-Host "==================================================="
    Write-Host "  INICIANDO INSTALACION AUTOMATICA DE DRIVERS"
    Write-Host "==================================================="
    Write-Host "Buscando en: $destino"
    Write-Host "Por favor, espera..."
    Write-Host ""

    # Solución definitiva al error del Registro: Buscamos e instalamos mediante PnPUtil de forma segura e interactiva
    if (Test-Path $destino) {
        Get-ChildItem -Path $destino -Filter *.inf -Recurse | ForEach-Object {
            Write-Host "[INSTALANDO] $_.Name" -ForegroundColor Cyan
            pnputil /add-driver $_.FullName /install | Out-Null
        }
    } else {
        Write-Host "[ERROR] No se encontró la carpeta de origen de los drivers." -ForegroundColor Red
    }
}

function Exportar-Drivers {
    Write-Host ""
    Write-Host "Exportando drivers actuales del sistema... Por favor, espera."
    Write-Host ""

    if (-not (Test-Path $destino)) {
        New-Item -ItemType Directory -Path $destino -Force | Out-Null
    }

    if ($metodoBackup -eq "NATUR") {
        Export-WindowsDriver -Online -DestinationPath "$destino"
    } else {
        Write-Host "[INFO] Windows 7 no soporta la exportación en caliente."
        Write-Host "[INFO] Extrayendo el DriverStore completo (FileRepository) de forma nativa..."
        Write-Host ""
        Copy-Item -Path "C:\Windows\System32\DriverStore\FileRepository\*" -Destination $destino -Recurse -Force
    }
}

# --- Validacion de carpeta existente ---
if (-not (Test-Path $destino)) {
    Exportar-Drivers
} else {
    Write-Host "---------------------------------------------------"
    Write-Host "[AVISO] Este equipo ya existe en la base de datos."
    Write-Host "Ruta: $destino"
    Write-Host "---------------------------------------------------"
    Write-Host "Que accion deseas realizar?"
    Write-Host ""
    Write-Host " [1] RESTAURAR: Instalar los drivers de la base de datos en este equipo."
    Write-Host " [2] RESPALDAR: Volver a exportar y sobrescribir los drivers."
    Write-Host " [3] CANCELAR: Salir sin hacer cambios."
    Write-Host ""
    $opcion = Read-Host "Selecciona una opcion (1, 2 o 3)"

    switch ($opcion) {
        "1" { Restaurar-Drivers }
        "2" { Exportar-Drivers }
        "3" {
            Write-Host ""
            Write-Host "Operacion cancelada por el usuario."
            Read-Host "Presiona Enter para salir"
            exit
        }
        default {
            Write-Host "Opcion no valida."
            Read-Host "Presiona Enter para salir"
            exit
        }
    }
}

Write-Host ""
Write-Host "==================================================="
Write-Host "  [OK] Operacion procesada correctamente!"
Write-Host "==================================================="
Read-Host "Presiona Enter para salir"