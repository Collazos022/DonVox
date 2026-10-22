# DonVox 🔊

> **Lector Ligero de Portapapeles y Texto Seleccionado para Windows**  
> *Inspirado en la practicidad de SodelsCot, reinventado en AutoHotkey v2 con conexión nativa a Microsoft Azure Neural TTS y voces locales SAPI5 / OneCore.*

[![Versión](https://img.shields.io/badge/Versión-v1.6.6-0080C0.svg)](DonVox.ahk)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0+-334455.svg?logo=autohotkey&logoColor=white)](https://www.autohotkey.com/)
[![Plataforma](https://img.shields.io/badge/Plataforma-Windows%2010%20%7C%2011-0078D6.svg?logo=windows&logoColor=white)](https://microsoft.com)
[![Licencia](https://img.shields.io/badge/Licencia-MIT-green.svg)](LICENSE)
[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-♡%20Donar-EA4AAA.svg?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Collazos022)

---

## 🌟 Características Destacadas

- ⚡ **Ultra ligero y eficiente:** Consume apenas entre **2 y 5 MB de memoria RAM**, ejecutándose en segundo plano en la bandeja del sistema (*systray*).
- 🎙️ **Conexión Nativa a Microsoft Azure Neural TTS:**
  - Sintetiza voz hiperrealista (Edge Read Aloud) utilizando **WinHTTP WebSockets nativos** y el protocolo criptográfico `Sec-MS-GEC v2` (CS64 + SHA-256 modificado).
  - **Cero dependencias externas:** No requiere Python, ni Node.js, ni librerías pesadas en disco.
- 💻 **Soporte de Voces Locales sin latencia (0 ms):**
  - Reconoce automáticamente motores **SAPI 5** y voces modernas de **Windows 10/11 OneCore** sin necesidad de modificar el registro de Windows.
  - *Modo Fallback resiliente:* Si se interrumpe la conexión a internet, conmuta al instante a la voz local configurada.
- 📋 **Lectura Inteligente:**
  - **Monitor de Portapapeles:** Lee automáticamente cualquier texto copiado (`Ctrl + C`).
  - **Lectura de Selección Global:** Atajo personalizable (`Shift + Alt + C` por defecto) para capturar y leer cualquier bloque de texto seleccionado en cualquier programa (navegadores, PDFs, editores de código, procesadores de texto, etc.).
- 🎨 **Diseño Moderno & Windows 11 Fluent (Estilo G-Helper):**
  - Adaptación automática al tema del sistema (Modo Oscuro `#191919` sin recuadros pesados, botones nativos con bordes redondeados y barra de título oscura vía DWM).
  - **Icono vectorial dinámico en la bandeja (GDI+):** El isotipo (burbuja de diálogo con forma de onda de 7 barras) se dibuja en memoria y cambia de color en tiempo real según el estado:
    - 🔵 **Azul (`#0B6288`):** Activo en Línea (Azure Neural)
    - 🟢 **Verde (`#15803D`):** Activo Local (Windows SAPI5/OneCore)
    - 🟡 **Amarillo (`#D97706`):** Pausado
    - ⚪ **Gris (`#6B7280`):** Desactivado (Interruptor Maestro apagado)
- 🌐 **Detección Automática de Idioma:** Interfaz y mensajes disponibles en **Español**, **Inglés**, **Portugués** y **Francés**, ajustándose al idioma nativo de Windows.
- 🚀 **Inicio Automático:** Casilla configurable para ejecutarse al arrancar Windows (`HKCU\...\Run`).

---

## ⌨️ Atajos de Teclado Globales por Defecto

Todos los atajos se pueden personalizar desde la ventana de configuración:

| Acción | Atajo por Defecto | Descripción |
| :--- | :---: | :--- |
| **Leer Selección** | <kbd>Shift</kbd> + <kbd>Alt</kbd> + <kbd>C</kbd> | Copia y lee el texto marcado en cualquier ventana |
| **Pausar / Reanudar** | <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>1</kbd> | Alterna la pausa de la reproducción actual |
| **Detener Lectura** | <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>2</kbd> | Detiene de inmediato el audio en reproducción |
| **Repetir Lectura** | <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>3</kbd> | Vuelve a leer el último texto reproducido |
| **Interruptor Maestro** | <kbd>Alt</kbd> + <kbd>\|</kbd> | Enciende / apaga el sistema de lectura global |

---

## 🚀 Requisitos e Instalación

### Requisitos
- Windows 10 o Windows 11 (64-bit recomendado).
- [AutoHotkey v2.0+](https://www.autohotkey.com/) instalado en el sistema.

### Instalación Rápida
1. Clona este repositorio o descarga el código fuente en archivo ZIP:
   ```bash
   git clone https://github.com/Collazos022/DonVox.git
   ```
2. Haz doble clic sobre `DonVox.ahk` para iniciar el programa.
3. DonVox aparecerá en la bandeja del sistema (*systray*).

---

## ⚙️ Configuración y Uso

1. **Abrir la ventana de configuración:** Haz doble clic sobre el icono de DonVox en la bandeja del sistema o haz clic derecho y selecciona **Configuración y Atajos...**
2. **Seleccionar tu voz favorita:**
   - **Microsoft Azure:** Elige entre voces neuronales de alta calidad de Colombia, México, España, Argentina, EE.UU., etc. (por ejemplo: `es-CO-SalomeNeural`).
   - **Voz Local:** Selecciona cualquier voz instalada en tu equipo (ejemplo: `Microsoft Sabina Desktop`).
3. **Ajustar velocidad y volumen:** Utiliza los deslizadores deslizantes y pulsa **Probar Voz** para validar la configuración.
4. **Guardar cambios:** Haz clic en **Guardar y Cerrar**. La configuración se preservará en el archivo `DonVox.ini`.

---

## 📂 Estructura del Proyecto

```text
DonVox/
│
├── DonVox.ahk        # Código fuente principal de la aplicación (AutoHotkey v2)
├── DonVox.ini        # Archivo de configuración local del usuario
├── logo.svg          # Logotipo vectorial oficial (Burbuja + Espectrograma de 7 barras)
├── LICENSE           # Licencia de código abierto MIT
└── README.md         # Documentación y guía de usuario
```

---

## 💖 Donaciones y Apoyo

Si **DonVox** te resulta útil para tu estudio, trabajo o productividad diaria, puedes apoyar el desarrollo continuo y mantenimiento del proyecto:

[![Sponsor](https://img.shields.io/badge/Sponsor%20en%20GitHub-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Collazos022)

---

## 📄 Licencia

Este proyecto está distribuido bajo la licencia [MIT](LICENSE). Puedes usarlo, modificarlo y distribuirlo libremente.
