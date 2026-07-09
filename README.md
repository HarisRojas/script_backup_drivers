# Gestor Avanzado de Drivers 💾

Este repositorio contiene una herramienta automatizada bidireccional diseñada para técnicos de soporte y administradores de sistemas. Permite la **exportación automatizada (respaldo)** y la **instalación automática (restauración)** de controladores (drivers) de forma totalmente nativa, organizando todo de forma inteligente en una base de datos local según la marca y modelo del hardware detectado.

El script está disponible en dos versiones con el mismo nombre para adaptarse a tus necesidades:
* `drivers.bat` (Versión clásica en Batch, optimizada y compatible con versiones anteriores).
* `drivers.ps1` (Versión moderna en PowerShell, con funciones nativas avanzadas).

---

## ✨ Características Principales

* **Doble Flujo Inteligente:** Si el equipo no existe en la base de datos, realiza un respaldo automático. Si ya existe, te ofrece un menú interactivo para **restaurar** los drivers en una reinstalación limpia o **sobrescribir/actualizar** el respaldo existente.
* **Detección de Hardware Nativa:** Consulta automáticamente el fabricante y modelo de la Placa Base (`BaseBoard`) para organizar los drivers en carpetas limpias (ej. `\drivers\ASUSTeK_COMPUTER_INC.\Prime_B450M-A`).
* **Filtro para Equipos Clónicos:** Detecta textos genéricos de fábrica como *"To be filled by O.E.M."* o *"Default string"* y les asigna un identificador aleatorio único para evitar colisiones de carpetas.
* **Auto-Elevación UAC:** El script detecta si cuenta con privilegios de Administrador; de no ser así, solicita de forma automática la elevación de permisos mediante la ventana flotante de Windows.
* **Soporte UTF-8 Completo:** Formateado correctamente para interpretar caracteres especiales, tildes y eñes sin romper la estética visual de la consola.
* **Ajuste Visual Automático:** Configura el tamaño de la ventana y de la fuente tipográfica a una visualización grande y clara (Consolas 20pt) para comodidad en trabajos de campo.
* **Inmunidad al Error 50 (Optimización de Arquitectura):** * **Respaldo:** Ambos scripts corrigen automáticamente la redirección de arquitectura (SysWOW64 / Sysnative) y usan cmdlets puros en PowerShell (`Export-WindowsDriver`), eliminando los cuelgues típicos de DISM al extraer drivers en caliente.
    * **Restauración:** Se implementa el uso universal de **PnPUtil**, la herramienta oficial de Windows para inyección en sistemas activos. Esto evita bloqueos en el Registro de configuraciones de Windows y asegura que la instalación funcione a la primera en cualquier edición (incluyendo Windows 10 Home 22H2 o Windows 11).

---

## 🛠️ Requisitos

* Sistema Operativo: Windows 7, 8, 10 u 11 (Cualquier edición, incluyendo soporte corregido para Windows 10 Home 22H2).
* Privilegios de Administrador (el script los solicitará automáticamente).

---

## 🚀 Modo de Uso

Clona este repositorio o descarga los archivos directamente en tu unidad de almacenamiento de herramientas (como un pendrive técnico).

### Opción A: Usando el script clásico (`drivers.bat`)
1. Haz doble clic sobre el archivo `drivers.bat`.
2. Concede los permisos de Administrador si la ventana de UAC lo solicita.

### Opción B: Usando el script moderno (`drivers.ps1`)
Si deseas utilizar la versión nativa de PowerShell, debido a las políticas de ejecución por defecto de Windows, se recomienda ejecutarlo invocando un bypass temporal desde la terminal:

```powershell
powershell -ExecutionPolicy Bypass -File "Ruta\Hacia\drivers.ps1"
