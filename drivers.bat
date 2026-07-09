@echo off
:: Cambiar la página de códigos de la consola a UTF-8
chcp 65001 >nul

:: --- TRUCO PARA CAMBIAR EL TAMAÑO DE LA FUENTE AUTOMÁTICAMENTE ---
powershell -NoProfile -Command "$h=(Get-Process -Id $PID).MainWindowHandle; if($h -eq 0){$h=(Get-Process -Name explorer).MainWindowHandle}; $cc=Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Win32 { [DllImport(\"user32.dll\")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName); [DllImport(\"kernel32.dll\", SetLastError = true)] public static extern IntPtr GetStdHandle(int nStdHandle); [DllImport(\"kernel32.dll\", SetLastError = true)] public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx); [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct CONSOLE_FONT_INFO_EX { public uint cbSize; public uint nFont; public short dwFontSizeX; public short dwFontSizeY; public int FontFamily; public int FontWeight; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FaceName; } }' -PassThru; $f=New-Object Win32+CONSOLE_FONT_INFO_EX; $f.cbSize=[System.Runtime.InteropServices.Marshal]::SizeOf($f); $f.dwFontSizeY=20; $f.FaceName='Consolas'; $hOut=[Win32]::GetStdHandle(-11); [Win32]::SetCurrentConsoleFontEx($hOut, $false, [ref]$f)" >nul 2>&1

:: --- AUTO-ELEVACIÓN UAC (ADMINISTRADOR) ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Solicitando permisos de Administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Detectando versión de Windows...

:: Detectar la versión de Windows analizando el comando 'ver'
set "WIN_VER_MAJOR="
for /f "tokens=4-5 delims=. " %%a in ('ver') do (
    set "WIN_VER_MAJOR=%%a"
)

:: Corrección por si 'ver' devuelve texto extra antes del número
if "%WIN_VER_MAJOR%"=="Version" (
    for /f "tokens=5-6 delims=. " %%a in ('ver') do set "WIN_VER_MAJOR=%%a"
)

echo Versión de Kernel detectada: %WIN_VER_MAJOR%
echo ===================================================

:: --- LÓGICA DE SALTO HÍBRIDA ---
if %WIN_VER_MAJOR% GEQ 10 goto :metodo_moderno
goto :metodo_antiguo


:metodo_moderno
echo [INFO] Windows 10/11 detectado.
echo Usando método moderno (PowerShell + DISM)...
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_BaseBoard).Manufacturer.Trim()"`) do set "MARCA=%%a"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_BaseBoard).Product.Trim()"`) do set "MODELO=%%a"
set "METODO_BACKUP=DISM"
goto :procesar_datos


:metodo_antiguo
echo [INFO] Windows antiguo detectado (7/8).
echo Usando método clásico (WMIC + Copia Directa)...
for /f "tokens=2 delims==" %%a in ('wmic baseboard get manufacturer /value 2^>nul') do set "MARCA=%%a"
for /f "tokens=2 delims==" %%a in ('wmic baseboard get product /value 2^>nul') do set "MODELO=%%a"
set "METODO_BACKUP=MANUAL"
goto :procesar_datos


:procesar_datos
:: --- FILTRO INTELIGENTE PARA EQUIPOS CLÓNICOS ---
if "%MODELO%"=="" set "MODELO=Desconocido"
if "%MODELO%"=="To be filled by O.E.M." set "MODELO=Clonico_%RANDOM%"
if "%MODELO%"=="Default string" set "MODELO=Clonico_%RANDOM%"

:: Limpiar posibles caracteres extraños, comas o espacios para las carpetas
set "MARCA=%MARCA:\=_%"
set "MODELO=%MODELO:\=_%"
set "MARCA=%MARCA: =_%"
set "MODELO=%MODELO: =_%"
set "MARCA=%MARCA:,=_%"
set "MODELO=%MODELO:,=_%"

:: Definir la ruta de destino
set "DESTINO=%~dp0drivers\%MARCA%\%MODELO%"

echo.
echo Detectado: %MARCA% - %MODELO%
echo.

:: Validación de carpeta existente
if not exist "%DESTINO%" goto :exportar_drivers

echo ---------------------------------------------------
echo [AVISO] Este equipo ya existe en la base de datos.
echo Ruta: %DESTINO%
echo ---------------------------------------------------
echo ¿Qué acción deseas realizar?
echo.
echo  [1] RESTAURAR: Instalar los drivers de la base de datos en este equipo.
echo  [2] RESPALDAR: Volver a exportar y sobrescribir los drivers.
echo  [3] CANCELAR: Salir sin hacer cambios.
echo.
set /p OPCION="Selecciona una opción (1, 2 o 3): "

if "%OPCION%"=="1" goto :restaurar_drivers
if "%OPCION%"=="2" goto :exportar_drivers
if "%OPCION%"=="3" (
    echo.
    echo Operación cancelada por el usuario.
    pause
    exit /b
)
:: Por si el usuario presiona otra tecla inválida:
echo Opción no válida.
	pause 
	exit /b


:restaurar_drivers
echo.
echo ===================================================
echo   INICIANDO INSTALACIÓN AUTOMÁTICA DE DRIVERS
echo ===================================================
echo Buscando en: %DESTINO%
echo Por favor, espera...
echo.

:: SOLUCIÓN DEFINITIVA AL ERROR 50 EN RESTAURACIÓN:
:: Usamos PnPUtil de manera universal. Evita el bloqueo del registro y de imagen offline de DISM.
pnputil /add-driver "%DESTINO%\*.inf" /subdirs /install
goto :finalizar


:exportar_drivers
echo.
echo Exportando drivers actuales del sistema... Por favor, espera.
echo.
if not exist "%DESTINO%" mkdir "%DESTINO%"

if "%METODO_BACKUP%"=="DISM" goto :exportar_dism
goto :exportar_manual


:exportar_dism
:: SOLUCIÓN AL ERROR 50 EN RESPALDO (Redirección SysWOW64):
:: Si la consola se abrió en modo 32 bits dentro de un Windows de 64 bits, forzamos el uso de la carpeta Sysnative
if exist "%SystemRoot%\Sysnative\dism.exe" (
    "%SystemRoot%\Sysnative\dism.exe" /online /export-driver /destination:"%DESTINO%"
) else (
    dism /online /export-driver /destination:"%DESTINO%"
)
goto :finalizar


:exportar_manual
echo [INFO] Windows 7 no soporta DISM /Export-Driver en caliente.
echo [INFO] Extrayendo el DriverStore completo (FileRepository) de forma nativa... [cite: 14]
echo.
xcopy "C:\Windows\System32\DriverStore\FileRepository" "%DESTINO%" /s /e /h /i /c /y
goto :finalizar


:finalizar
echo.
echo ===================================================
echo   [OK] ¡Operación procesada correctamente!
echo ===================================================
pause
exit /b