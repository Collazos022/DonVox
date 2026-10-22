#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ==============================================================================
; DonVox v1.6.6 - Lector Ligero de Portapapeles y Texto Seleccionado
; - Compatible con Voces Nativas de Windows (SAPI5 + OneCore) y Microsoft Azure
; - Conexión Nativa a Azure Neural por WinHTTP WebSocket (Protocolo Sec-MS-GEC v2)
; - Adaptación automática al Tema de Windows 11 (Estilo Oscuro G-Helper)
; - Opción de Ejecución al Inicio de Windows (Registro HKCU\...\Run)
; - Detección automática del Idioma del Sistema (ES / EN / PT / FR)
; - Iconos vectoriales dinámicos integrados en el código (Azul/Verde/Amarillo/Gris)
; ==============================================================================

global AppName := "DonVox"
global AppVersion := "v1.6.6"
global VersionNum := "1.6.6"
global DonateUrl := "https://github.com/sponsors/Collazos022"
global RepoUrl := "https://github.com/Collazos022/DonVox"
global ConfigFile := A_ScriptDir "\DonVox.ini"
global TempMp3 := A_Temp "\donvox_azure_audio.mp3"

; Objetos y estado global
global SpVoice := ComObject("SAPI.SpVoice")
global VoiceList := []          ; Array de objetos {Name, Token}
global VoiceNames := []         ; Array de nombres para el DropDownList
global IsPaused := false
global LastSpokenText := ""
global IgnoreClipboardEvent := false
global ActiveHotkeys := []
global SettingsGui := ""
global StateIcons := {}
global ServerClockOffset := 0   ; Ajuste automático de reloj UTC con el servidor de Microsoft
global Lang := {}               ; Diccionario de textos según el idioma de Windows

; Voces de Microsoft Azure (Neural Online)
global AzureVoices := [
    "es-MX-JorgeNeural (México - Hombre)",
    "es-MX-DaliaNeural (México - Mujer)",
    "es-CO-GonzaloNeural (Colombia - Hombre)",
    "es-CO-SalomeNeural (Colombia - Mujer)",
    "es-ES-AlvaroNeural (España - Hombre)",
    "es-ES-ElviraNeural (España - Mujer)",
    "es-AR-TomasNeural (Argentina - Hombre)",
    "es-AR-ElenaNeural (Argentina - Mujer)",
    "es-US-AlonsoNeural (EE.UU. - Hombre)",
    "es-US-PalomaNeural (EE.UU. - Mujer)",
    "en-US-AndrewNeural (English US - Male)",
    "en-US-AvaNeural (English US - Female)"
]

; Configuración por defecto personalizada
global Cfg := {
    MasterEnabled: 1
  , AutoClipboard: 1
  , StartWithWin: 0    ; Ejecutar al inicio de Windows
  , UseAzure: 1        ; Activo en modo Microsoft Azure Neural por defecto
  , LocalVoiceIndex: 1
  , AzureVoiceIndex: 4 ; 4 = es-CO-SalomeNeural (Colombia - Mujer) por defecto
  , Rate: 1            ; Velocidad ligeramente por encima del centro
  , Volume: 70         ; Volumen al 70% por defecto
  , MinChars: 2        ; Ignorar textos más cortos que esto en portapapeles
  , HkReadSel: "+!c"   ; MAYUSCULAS + ALT + C
  , HkPause: "^!1"     ; CTRL + ALT + 1
  , HkStop: "^!2"      ; CTRL + ALT + 2
  , HkRepeat: "^!3"    ; CTRL + ALT + 3
  , HkToggle: "!|"     ; ALT + |
}

; Inicialización del sistema
InitSystemLanguage()
InitWin11ThemeSupport()
InitVectorIcons()
LoadVoices()
LoadConfig()
ApplyStartupRegistry()
ApplyVoiceSettings()
RegisterAllHotkeys()
SetupTrayMenu()
OnClipboardChange(OnClipboardUpdate)

; Mostrar notificación inicial discreta (o abrir ajustes si se pasa --show)
if (A_Args.Length > 0 && A_Args[1] = "--show")
    ShowSettingsGui()
else
    TrayTip(Lang.TrayStartupMsg, AppName " " AppVersion, 1)

; ==============================================================================
; 0A. DETECCIÓN AUTOMÁTICA DEL IDIOMA DEL SISTEMA (ES / EN / PT / FR)
; ==============================================================================
InitSystemLanguage() {
    global Lang, AppName, VersionNum
    langId := DllCall("GetUserDefaultUILanguage", "UShort") & 0x3FF
    ; 0x0A = Español, 0x09 = Inglés, 0x16 = Portugués, 0x0C = Francés
    Lang := {}
    if (langId == 0x09) {
        Lang.Code           := "EN"
        Lang.TrayStartupMsg := "Running in the background.`nDouble-click the tray icon to configure hotkeys and voices."
        Lang.WinTitle       := "Settings"
        Lang.SecGeneral     := "📋 General Behavior"
        Lang.ChkMaster      := "Enable speech reading (Master Switch)"
        Lang.ChkClipboard   := "Automatically read everything copied to clipboard (Ctrl + C)"
        Lang.ChkStartup     := "Run automatically when Windows starts"
        Lang.SecVoice       := "🎙 Voice Engine && Settings"
        Lang.ChkAzure       := "Use Microsoft Azure Neural (Blue Icon - Native Online)"
        Lang.LblLocalVoice  := "Windows Installed Voice (Green Icon - Local 0 ms):"
        Lang.LblAzureVoice  := "Microsoft Azure Voice (Blue Icon - Online):"
        Lang.LblRate        := "Speed:"
        Lang.LblVolume      := "Volume:"
        Lang.SecHotkeys     := "⌨ Global Keyboard Shortcuts (Click && press keys)"
        Lang.LblHkReadSel   := "Read selected text:"
        Lang.LblHkPause     := "Pause / Resume reading:"
        Lang.LblHkStop      := "Stop reading immediately:"
        Lang.LblHkRepeat    := "Repeat last reading:"
        Lang.LblHkToggle    := "Enable / Disable at will:"
        Lang.LblVersion     := "Version: " VersionNum
        Lang.BtnDonate      := "♡ Donate"
        Lang.BtnTest        := "Test Voice"
        Lang.BtnStop        := "Stop"
        Lang.BtnSave        := "Save && Close"
        Lang.MenuSettings   := "Settings && Shortcuts..."
        Lang.MenuMaster     := "System Active (Master Switch)"
        Lang.MenuAutoClip   := "Auto-Read Clipboard (Ctrl+C)"
        Lang.MenuAzure      := "Use Microsoft Azure Voice (Online)"
        Lang.MenuRepeat     := "Repeat last reading"
        Lang.MenuPause      := "Pause / Resume"
        Lang.MenuStop       := "Stop reading"
        Lang.MenuExit       := "Exit"
        Lang.StateDisabled  := "DISABLED (Gray)"
        Lang.StatePaused    := "PAUSED (Yellow)"
        Lang.StateAzure     := "Active Online - Azure (Blue)"
        Lang.StateLocal     := "Active Local - Windows (Green)"
        Lang.MsgDisabled    := "System DISABLED (Gray Icon)"
        Lang.MsgEnabled     := "System ENABLED"
        Lang.MsgFallback    := "No response from Azure Online, using local fallback voice."
        Lang.MsgLocalErr    := "Windows Voice Error: "
        Lang.MsgHkErr       := "Could not register shortcut ("
        Lang.TestPhrase     := "Hello! I am " AppName " Version " VersionNum ", this is a voice test."
    } else if (langId == 0x16) {
        Lang.Code           := "PT"
        Lang.TrayStartupMsg := "Executando em segundo plano.`nClique duas vezes no ícone para configurar atalhos e vozes."
        Lang.WinTitle       := "Configurações"
        Lang.SecGeneral     := "📋 Comportamento Geral"
        Lang.ChkMaster      := "Ativar leitura (Interruptor Mestre)"
        Lang.ChkClipboard   := "Ler automaticamente tudo o que for copiado (Ctrl + C)"
        Lang.ChkStartup     := "Executar automaticamente ao iniciar o Windows"
        Lang.SecVoice       := "🎙 Motor de Voz e Ajustes"
        Lang.ChkAzure       := "Usar Microsoft Azure Neural (Ícone Azul - Online Nativo)"
        Lang.LblLocalVoice  := "Voz instalada no Windows (Ícone Verde - Local 0 ms):"
        Lang.LblAzureVoice  := "Voz Microsoft Azure (Ícone Azul - Online):"
        Lang.LblRate        := "Velocidade:"
        Lang.LblVolume      := "Volume:"
        Lang.SecHotkeys     := "⌨ Atalhos de Teclado Globais (Clique e pressione as teclas)"
        Lang.LblHkReadSel   := "Ler texto selecionado:"
        Lang.LblHkPause     := "Pausar / Retomar leitura:"
        Lang.LblHkStop      := "Parar leitura imediatamente:"
        Lang.LblHkRepeat    := "Repetir última leitura:"
        Lang.LblHkToggle    := "Ativar / Desactivar a critério:"
        Lang.LblVersion     := "Versão: " VersionNum
        Lang.BtnDonate      := "♡ Doar"
        Lang.BtnTest        := "Testar Voz"
        Lang.BtnStop        := "Parar"
        Lang.BtnSave        := "Salvar e Fechar"
        Lang.MenuSettings   := "Configurações e Atalhos..."
        Lang.MenuMaster     := "Sistema Ativo (Interruptor Mestre)"
        Lang.MenuAutoClip   := "Ler Área de Transferência (Ctrl+C)"
        Lang.MenuAzure      := "Usar Voz Microsoft Azure (Online)"
        Lang.MenuRepeat     := "Repetir última leitura"
        Lang.MenuPause      := "Pausar / Retomar"
        Lang.MenuStop       := "Parar leitura"
        Lang.MenuExit       := "Sair"
        Lang.StateDisabled  := "DESATIVADO (Cinza)"
        Lang.StatePaused    := "EM PAUSA (Amarelo)"
        Lang.StateAzure     := "Ativo Online - Azure (Azul)"
        Lang.StateLocal     := "Ativo Local - Windows (Verde)"
        Lang.MsgDisabled    := "Sistema DESATIVADO (Ícone Cinza)"
        Lang.MsgEnabled     := "Sistema ATIVADO"
        Lang.MsgFallback    := "Sem conexão com Azure Online, usando voz local."
        Lang.MsgLocalErr    := "Erro na voz do Windows: "
        Lang.MsgHkErr       := "Não foi possível registrar o atalho ("
        Lang.TestPhrase     := "Olá! Eu sou o " AppName " Versão " VersionNum ", este é um teste de voz."
    } else if (langId == 0x0C) {
        Lang.Code           := "FR"
        Lang.TrayStartupMsg := "Exécution en arrière-plan.`nDouble-cliquez sur l’icône pour configurer les raccourcis et les voix."
        Lang.WinTitle       := "Paramètres"
        Lang.SecGeneral     := "📋 Comportement Général"
        Lang.ChkMaster      := "Activer la lecture (Interrupteur Principal)"
        Lang.ChkClipboard   := "Lire automatiquement le presse-papiers (Ctrl + C)"
        Lang.ChkStartup     := "Lancer automatiquement au démarrage de Windows"
        Lang.SecVoice       := "🎙 Moteur Vocal et Réglages"
        Lang.ChkAzure       := "Utiliser Microsoft Azure Neural (Icône Bleue - En ligne)"
        Lang.LblLocalVoice  := "Voix installée dans Windows (Icône Verte - Local 0 ms) :"
        Lang.LblAzureVoice  := "Voix Microsoft Azure (Icône Bleue - En ligne) :"
        Lang.LblRate        := "Vitesse :"
        Lang.LblVolume      := "Volume :"
        Lang.SecHotkeys     := "⌨ Raccourcis Clavier Globaux (Cliquez et appuyez)"
        Lang.LblHkReadSel   := "Lire le texte sélectionné :"
        Lang.LblHkPause     := "Pause / Reprendre la lecture :"
        Lang.LblHkStop      := "Arrêter la lecture immédiatement :"
        Lang.LblHkRepeat    := "Répéter la dernière lecture :"
        Lang.LblHkToggle    := "Activer / Désactiver à volonté :"
        Lang.LblVersion     := "Version : " VersionNum
        Lang.BtnDonate      := "♡ Soutenir"
        Lang.BtnTest        := "Tester la Voix"
        Lang.BtnStop        := "Arrêter"
        Lang.BtnSave        := "Enregistrer et Fermer"
        Lang.MenuSettings   := "Paramètres et Raccourcis..."
        Lang.MenuMaster     := "Système Actif (Interrupteur Principal)"
        Lang.MenuAutoClip   := "Lire le Presse-papiers (Ctrl+C)"
        Lang.MenuAzure      := "Utiliser la Voix Microsoft Azure (En ligne)"
        Lang.MenuRepeat     := "Répéter la dernière lecture"
        Lang.MenuPause      := "Pause / Reprendre"
        Lang.MenuStop       := "Arrêter la lecture"
        Lang.MenuExit       := "Quitter"
        Lang.StateDisabled  := "DÉSACTIVÉ (Gris)"
        Lang.StatePaused    := "EN PAUSE (Jaune)"
        Lang.StateAzure     := "Actif en Ligne - Azure (Bleu)"
        Lang.StateLocal     := "Actif Local - Windows (Vert)"
        Lang.MsgDisabled    := "Système DÉSACTIVÉ (Icône Grise)"
        Lang.MsgEnabled     := "Système ACTIVÉ"
        Lang.MsgFallback    := "Pas de connexion à Azure Online, voix locale utilisée."
        Lang.MsgLocalErr    := "Erreur voix Windows : "
        Lang.MsgHkErr       := "Impossible d’enregistrer le raccourci ("
        Lang.TestPhrase     := "Bonjour ! Je suis " AppName " Version " VersionNum ", ceci est un test vocal."
    } else {
        ; Español por defecto
        Lang.Code           := "ES"
        Lang.TrayStartupMsg := "Ejecutándose en segundo plano.`nDoble clic en el icono para configurar atajos y voces."
        Lang.WinTitle       := "Configuración"
        Lang.SecGeneral     := "📋 Comportamiento General"
        Lang.ChkMaster      := "Activar lectura (Interruptor Maestro)"
        Lang.ChkClipboard   := "Leer automáticamente todo lo que se copie al portapapeles (Ctrl + C)"
        Lang.ChkStartup     := "Ejecutar automáticamente al iniciar Windows"
        Lang.SecVoice       := "🎙 Motor de Voz y Ajustes"
        Lang.ChkAzure       := "Usar Microsoft Azure Neural (Icono Azul - Online)"
        Lang.LblLocalVoice  := "Voz instalada en Windows (Icono Verde - Local 0 ms):"
        Lang.LblAzureVoice  := "Voz Microsoft Azure (Icono Azul - Online):"
        Lang.LblRate        := "Velocidad:"
        Lang.LblVolume      := "Volumen:"
        Lang.SecHotkeys     := "⌨ Atajos de Teclado Globales (Haz clic y presiona tus teclas)"
        Lang.LblHkReadSel   := "Leer texto seleccionado:"
        Lang.LblHkPause     := "Pausar / Reanudar lectura:"
        Lang.LblHkStop      := "Detener lectura inmediatamente:"
        Lang.LblHkRepeat    := "Repetir última lectura:"
        Lang.LblHkToggle    := "Activar / Desactivar a discreción:"
        Lang.LblVersion     := "Versión: " VersionNum
        Lang.BtnDonate      := "♡ Donar"
        Lang.BtnTest        := "Probar Voz"
        Lang.BtnStop        := "Detener"
        Lang.BtnSave        := "Guardar y Cerrar"
        Lang.MenuSettings   := "Configuración y Atajos..."
        Lang.MenuMaster     := "Sistema Activo (Interruptor Maestro)"
        Lang.MenuAutoClip   := "Leer Portapapeles Automáticamente (Ctrl+C)"
        Lang.MenuAzure      := "Usar Voz Microsoft Azure (Online)"
        Lang.MenuRepeat     := "Repetir última lectura"
        Lang.MenuPause      := "Pausar / Reanudar"
        Lang.MenuStop       := "Detener lectura"
        Lang.MenuExit       := "Salir"
        Lang.StateDisabled  := "DESACTIVADO (Gris)"
        Lang.StatePaused    := "EN PAUSA (Amarillo)"
        Lang.StateAzure     := "Activo en Línea - Azure (Azul)"
        Lang.StateLocal     := "Activo Local - Windows (Verde)"
        Lang.MsgDisabled    := "Sistema DESACTIVADO (Icono Gris)"
        Lang.MsgEnabled     := "Sistema ACTIVADO"
        Lang.MsgFallback    := "Sin conexión con Azure Online, usando voz local de respaldo."
        Lang.MsgLocalErr    := "Error al usar la voz de Windows: "
        Lang.MsgHkErr       := "No se pudo registrar el atajo ("
        Lang.TestPhrase     := "¡Hola! soy " AppName " Versión " VersionNum ", esto es una prueba de voz."
    }
    global LastSpokenText := Lang.TestPhrase
}

; ==============================================================================
; 0B. SOPORTE DE TEMA WINDOWS 11 (ADAPTACIÓN EN GROUPBOX Y BARRA DE TÍTULO)
; ==============================================================================
IsWin11DarkMode() {
    try {
        return (RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1) == 0)
    }
    return false
}

InitWin11ThemeSupport() {
    try {
        uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        if !uxtheme
            uxtheme := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
        if uxtheme {
            fnSetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
            fnFlushMenuThemes     := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
            if fnSetPreferredAppMode
                DllCall(fnSetPreferredAppMode, "Int", 1) ; AllowDark en menús
            if fnFlushMenuThemes
                DllCall(fnFlushMenuThemes)
        }
    }
}

ApplyGroupBoxTheme(guiObj, groupBoxes) {
    isDark := IsWin11DarkMode()

    ; Barra de título y bordes redondeados de Windows 11
    darkFlag := Buffer(4, 0)
    NumPut("Int", isDark ? 1 : 0, darkFlag, 0)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 20, "Ptr", darkFlag, "Int", 4)

    cornerFlag := Buffer(4, 0)
    NumPut("Int", 2, cornerFlag, 0)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 33, "Ptr", cornerFlag, "Int", 4)

    ; Desactivar el estilo clásico forzado en los GroupBox para que respeten el color del tema de Windows 11
    for gb in groupBoxes {
        try DllCall("uxtheme\SetWindowTheme", "Ptr", gb.Hwnd, "WStr", "", "WStr", "")
    }
}

; ==============================================================================
; 0C. DIBUJO VECTORIAL DEL LOGO EN MEMORIA (ESTILO SVG CON GDI+)
; ==============================================================================
InitVectorIcons() {
    global StateIcons
    DllCall("LoadLibrary", "Str", "gdiplus")
    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)
    pToken := 0
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)

    StateIcons := {
        Blue:   CreateWaveBubbleIcon(0xFF0B6288), ; Azul (Azure Online)
        Green:  CreateWaveBubbleIcon(0xFF15803D), ; Verde (Activo Local)
        Yellow: CreateWaveBubbleIcon(0xFFD97706), ; Amarillo/Ámbar (En Pausa)
        Gray:   CreateWaveBubbleIcon(0xFF6B7280)  ; Gris (Desactivado)
    }

    DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
}

CreateWaveBubbleIcon(argbColor) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", 64, "Int", 64, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
    G := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &G)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", G, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", G, "Int", 4)

    pBrushBg := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argbColor, "Ptr*", &pBrushBg)

    pPath := 0
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pPath)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", 2,  "Float", 2,  "Float", 24, "Float", 24, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", 38, "Float", 2,  "Float", 24, "Float", 24, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", 38, "Float", 30, "Float", 24, "Float", 24, "Float", 0,   "Float", 90)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pPath, "Float", 18, "Float", 54, "Float", 3, "Float", 62)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pPath, "Float", 3,  "Float", 62, "Float", 6, "Float", 49)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", 2,  "Float", 30, "Float", 20, "Float", 22, "Float", 115, "Float", 65)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", pPath)

    DllCall("gdiplus\GdipFillPath", "Ptr", G, "Ptr", pBrushBg, "Ptr", pPath)
    DllCall("gdiplus\GdipDeletePath", "Ptr", pPath)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrushBg)

    pBrushWhite := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &pBrushWhite)

    bars := [
        [8.5,  24, 4.2, 10],
        [15.8, 14, 4.2, 29],
        [23.2,  6, 4.2, 44],
        [30.5, 24, 4.2, 10],
        [37.8, 17, 4.2, 24],
        [45.2, 23, 4.2, 13],
        [52.5, 26, 4.2,  5]
    ]

    for b in bars {
        DllCall("gdiplus\GdipFillRectangle", "Ptr", G, "Ptr", pBrushWhite, "Float", b[1], "Float", b[2], "Float", b[3], "Float", b[4])
    }

    DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrushWhite)

    hIcon := 0
    DllCall("gdiplus\GdipCreateHICONFromBitmap", "Ptr", pBitmap, "Ptr*", &hIcon)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", G)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    return hIcon
}

; ==============================================================================
; 1. CARGA DE VOCES (SAPI 5 + WINDOWS ONECORE)
; ==============================================================================
LoadVoices() {
    global VoiceList, VoiceNames, SpVoice, Cfg
    VoiceList := []
    VoiceNames := []
    seen := Map()

    try {
        catOneCore := ComObject("SAPI.SpObjectTokenCategory")
        catOneCore.SetId("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices", false)
        tokens := catOneCore.EnumerateTokens()
        Loop tokens.Count {
            token := tokens.Item(A_Index - 1)
            desc := token.GetDescription()
            if !seen.Has(desc) {
                seen[desc] := true
                VoiceList.Push({Name: desc " [OneCore]", Token: token})
                VoiceNames.Push(desc " [OneCore]")
            }
        }
    }

    try {
        tokensSapi := SpVoice.GetVoices()
        Loop tokensSapi.Count {
            token := tokensSapi.Item(A_Index - 1)
            desc := token.GetDescription()
            if !seen.Has(desc) {
                seen[desc] := true
                VoiceList.Push({Name: desc " [SAPI5]", Token: token})
                VoiceNames.Push(desc " [SAPI5]")
            }
        }
    }

    foundSabina := false
    for idx, item in VoiceList {
        if InStr(item.Name, "Sabina Desktop") {
            Cfg.LocalVoiceIndex := idx
            foundSabina := true
            break
        }
    }
    if !foundSabina {
        for idx, item in VoiceList {
            if InStr(item.Name, "Sabina") || InStr(item.Name, "Spanish") || InStr(item.Name, "Español") || InStr(item.Name, "Helena") || InStr(item.Name, "Laura") {
                Cfg.LocalVoiceIndex := idx
                break
            }
        }
    }
}

; ==============================================================================
; 2. GESTIÓN DE CONFIGURACIÓN (DonVox.ini) E INICIO CON WINDOWS
; ==============================================================================
LoadConfig() {
    global Cfg, ConfigFile, VoiceList, AzureVoices, AppName
    ; Verificar si ya está registrado en el inicio de Windows
    try {
        RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", AppName)
        Cfg.StartWithWin := 1
    } catch {
        Cfg.StartWithWin := 0
    }

    if !FileExist(ConfigFile) {
        SaveConfig()
        return
    }
    Cfg.MasterEnabled   := Integer(IniRead(ConfigFile, "General", "MasterEnabled", Cfg.MasterEnabled))
    Cfg.AutoClipboard   := Integer(IniRead(ConfigFile, "General", "AutoClipboard", Cfg.AutoClipboard))
    Cfg.StartWithWin    := Integer(IniRead(ConfigFile, "General", "StartWithWin", Cfg.StartWithWin))
    Cfg.UseAzure        := Integer(IniRead(ConfigFile, "General", "UseAzure", Cfg.UseAzure))
    Cfg.LocalVoiceIndex := Integer(IniRead(ConfigFile, "Voice", "LocalVoiceIndex", Cfg.LocalVoiceIndex))
    Cfg.AzureVoiceIndex := Integer(IniRead(ConfigFile, "Voice", "AzureVoiceIndex", Cfg.AzureVoiceIndex))
    Cfg.Rate            := Integer(IniRead(ConfigFile, "Voice", "Rate", Cfg.Rate))
    Cfg.Volume          := Integer(IniRead(ConfigFile, "Voice", "Volume", Cfg.Volume))
    Cfg.MinChars        := Integer(IniRead(ConfigFile, "General", "MinChars", Cfg.MinChars))

    Cfg.HkReadSel       := IniRead(ConfigFile, "Hotkeys", "HkReadSel", Cfg.HkReadSel)
    Cfg.HkPause         := IniRead(ConfigFile, "Hotkeys", "HkPause", Cfg.HkPause)
    Cfg.HkStop          := IniRead(ConfigFile, "Hotkeys", "HkStop", Cfg.HkStop)
    Cfg.HkRepeat        := IniRead(ConfigFile, "Hotkeys", "HkRepeat", Cfg.HkRepeat)
    Cfg.HkToggle        := IniRead(ConfigFile, "Hotkeys", "HkToggle", Cfg.HkToggle)

    if (Cfg.LocalVoiceIndex < 1 || Cfg.LocalVoiceIndex > VoiceList.Length)
        Cfg.LocalVoiceIndex := 1
    if (Cfg.AzureVoiceIndex < 1 || Cfg.AzureVoiceIndex > AzureVoices.Length)
        Cfg.AzureVoiceIndex := 4
}

SaveConfig() {
    global Cfg, ConfigFile
    IniWrite(Cfg.MasterEnabled,   ConfigFile, "General", "MasterEnabled")
    IniWrite(Cfg.AutoClipboard,   ConfigFile, "General", "AutoClipboard")
    IniWrite(Cfg.StartWithWin,    ConfigFile, "General", "StartWithWin")
    IniWrite(Cfg.UseAzure,        ConfigFile, "General", "UseAzure")
    IniWrite(Cfg.MinChars,        ConfigFile, "General", "MinChars")

    IniWrite(Cfg.LocalVoiceIndex, ConfigFile, "Voice", "LocalVoiceIndex")
    IniWrite(Cfg.AzureVoiceIndex, ConfigFile, "Voice", "AzureVoiceIndex")
    IniWrite(Cfg.Rate,            ConfigFile, "Voice", "Rate")
    IniWrite(Cfg.Volume,          ConfigFile, "Voice", "Volume")

    IniWrite(Cfg.HkReadSel,       ConfigFile, "Hotkeys", "HkReadSel")
    IniWrite(Cfg.HkPause,         ConfigFile, "Hotkeys", "HkPause")
    IniWrite(Cfg.HkStop,          ConfigFile, "Hotkeys", "HkStop")
    IniWrite(Cfg.HkRepeat,        ConfigFile, "Hotkeys", "HkRepeat")
    IniWrite(Cfg.HkToggle,        ConfigFile, "Hotkeys", "HkToggle")
}

ApplyStartupRegistry() {
    global Cfg, AppName
    runKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    try {
        if Cfg.StartWithWin {
            cmd := A_IsCompiled ? ('"' A_ScriptFullPath '"') : ('"' A_AhkPath '" "' A_ScriptFullPath '"')
            RegWrite(cmd, "REG_SZ", runKey, AppName)
        } else {
            try RegDelete(runKey, AppName)
        }
    }
}

ApplyVoiceSettings() {
    global SpVoice, VoiceList, Cfg
    try {
        if (VoiceList.Length >= Cfg.LocalVoiceIndex && Cfg.LocalVoiceIndex > 0)
            SpVoice.Voice := VoiceList[Cfg.LocalVoiceIndex].Token
        SpVoice.Rate := Cfg.Rate
        SpVoice.Volume := Cfg.Volume
    }
}

; ==============================================================================
; 3. MOTOR DE LECTURA (LOCAL WINDOWS Y CONEXIÓN NATIVA AZURE WEBSOCKET V2)
; ==============================================================================
SpeakText(text) {
    global SpVoice, Cfg, IsPaused, LastSpokenText
    text := Trim(text, " `t`r`n")
    if (StrLen(text) == 0)
        return

    LastSpokenText := text
    StopReading()

    if (Cfg.UseAzure) {
        SpeakAzureNative(text)
    } else {
        SpeakLocal(text)
    }
    UpdateTrayMenuState()
}

SpeakLocal(text) {
    global SpVoice, IsPaused, AppName, AppVersion, Lang
    try {
        if IsPaused {
            SpVoice.Resume()
            IsPaused := false
        }
        SpVoice.Speak(text, 3)
    } catch as err {
        TrayTip(Lang.MsgLocalErr . err.Message, AppName " " AppVersion, 2)
    }
}

SpeakAzureNative(text) {
    global Cfg, AzureVoices, TempMp3, IsPaused, AppName, AppVersion, Lang
    voiceEntry := AzureVoices[Cfg.AzureVoiceIndex]
    voiceCode := StrSplit(voiceEntry, " ")[1]

    ratePct := Cfg.Rate * 8
    rateStr := (ratePct >= 0 ? "+" : "") ratePct "%"

    MciSend("close donvox_audio")
    try FileDelete(TempMp3)

    ok := DownloadAzureMp3(text, voiceCode, rateStr, TempMp3, true)
    if (ok && FileExist(TempMp3)) {
        MciPlay(TempMp3)
        IsPaused := false
    } else {
        TrayTip(Lang.MsgFallback, AppName " " AppVersion, 2)
        SpeakLocal(text)
    }
}

DownloadAzureMp3(text, voiceCode, rateStr, outMp3Path, allowClockRetry := true) {
    global ServerClockOffset
    static TrustedToken := "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    static ChromVer := "143.0.3650.75"
    static ChromMajor := "143"

    localFileTime := 0
    DllCall("GetSystemTimeAsFileTime", "Int64*", &localFileTime)
    adjFileTime := localFileTime + ServerClockOffset
    secSince1601 := adjFileTime // 10000000
    secRounded := secSince1601 - Mod(secSince1601, 300)
    ticks := secRounded * 10000000
    secMsGec := GenSecMsGecV2(ticks)
    connId := GenHexId(false)
    muid := GenHexId(true)

    wsPath := "/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=" TrustedToken
            . "&ConnectionId=" connId
            . "&Sec-MS-GEC=" secMsGec
            . "&Sec-MS-GEC-Version=2-" ChromVer

    userAgent := "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/" ChromMajor ".0.0.0 Safari/537.36 Edg/" ChromMajor ".0.0.0"
    headers := "Pragma: no-cache`r`n"
             . "Cache-Control: no-cache`r`n"
             . "Origin: chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold`r`n"
             . "Accept-Encoding: gzip, deflate, br, zstd`r`n"
             . "Accept-Language: en-US,en;q=0.9`r`n"
             . "Cookie: muid=" muid ";`r`n"

    hSession := 0, hConnect := 0, hRequest := 0, hWs := 0
    success := false
    needClockRetry := false

    try {
        hSession := DllCall("winhttp\WinHttpOpen", "WStr", userAgent, "UInt", 1, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
        if !hSession
            return false

        hConnect := DllCall("winhttp\WinHttpConnect", "Ptr", hSession, "WStr", "speech.platform.bing.com", "UShort", 443, "UInt", 0, "Ptr")
        if !hConnect
            return false

        hRequest := DllCall("winhttp\WinHttpOpenRequest", "Ptr", hConnect, "WStr", "GET", "WStr", wsPath, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x00800000, "Ptr")
        if !hRequest
            return false

        if !DllCall("winhttp\WinHttpSetOption", "Ptr", hRequest, "UInt", 114, "Ptr", 0, "UInt", 0)
            return false

        if !DllCall("winhttp\WinHttpSendRequest", "Ptr", hRequest, "WStr", headers, "UInt", -1, "Ptr", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
            return false

        if !DllCall("winhttp\WinHttpReceiveResponse", "Ptr", hRequest, "Ptr", 0)
            return false

        hWs := DllCall("winhttp\WinHttpWebSocketCompleteUpgrade", "Ptr", hRequest, "UPtr", 0, "Ptr")
        if !hWs {
            if (allowClockRetry && SyncClockFromResponse(hRequest, localFileTime))
                needClockRetry := true
            return false
        }

        DllCall("winhttp\WinHttpCloseHandle", "Ptr", hRequest)
        hRequest := 0

        tsStr := "Wed Oct 21 2026 00:00:00 GMT+0000 (Coordinated Universal Time)"

        cfgMsg := "X-Timestamp:" tsStr "`r`n"
                . "Content-Type:application/json; charset=utf-8`r`n"
                . "Path:speech.config`r`n`r`n"
                . '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"true","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}`r`n'
        WsSendText(hWs, cfgMsg)

        safeText := EscapeXml(RegExReplace(text, "[\x00-\x08\x0B\x0C\x0E-\x1F]", " "))
        reqId := GenHexId(false)
        ssmlMsg := "X-RequestId:" reqId "`r`n"
                 . "Content-Type:application/ssml+xml`r`n"
                 . "X-Timestamp:" tsStr "Z`r`n"
                 . "Path:ssml`r`n`r`n"
                 . "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>"
                 . "<voice name='" voiceCode "'>"
                 . "<prosody pitch='+0Hz' rate='" rateStr "' volume='+0%'>" safeText "</prosody>"
                 . "</voice></speak>"
        WsSendText(hWs, ssmlMsg)

        mp3File := FileOpen(outMp3Path, "w")
        rxBuf := Buffer(65536)
        inBinaryMsg := false
        isAudioMsg := false
        totalAudioBytes := 0

        Loop {
            bytesRead := 0
            bufType := 0
            err := DllCall("winhttp\WinHttpWebSocketReceive", "Ptr", hWs, "Ptr", rxBuf, "UInt", rxBuf.Size, "UInt*", &bytesRead, "Int*", &bufType, "UInt")
            if (err != 0)
                break

            if (bufType == 0 || bufType == 1) {
                if (!inBinaryMsg) {
                    if (bytesRead >= 2) {
                        hdrLen := (NumGet(rxBuf, 0, "UChar") << 8) | NumGet(rxBuf, 1, "UChar")
                        if (bytesRead >= 2 + hdrLen) {
                            hdrTxt := StrGet(rxBuf.Ptr + 2, hdrLen, "UTF-8")
                            isAudioMsg := InStr(hdrTxt, "Path:audio") > 0
                            audioOffset := 2 + hdrLen
                            audioLen := bytesRead - audioOffset
                            if (isAudioMsg && audioLen > 0) {
                                mp3File.RawWrite(rxBuf.Ptr + audioOffset, audioLen)
                                totalAudioBytes += audioLen
                            }
                        }
                    }
                    inBinaryMsg := (bufType == 1)
                } else {
                    if (isAudioMsg && bytesRead > 0) {
                        mp3File.RawWrite(rxBuf.Ptr, bytesRead)
                        totalAudioBytes += bytesRead
                    }
                    if (bufType == 0)
                        inBinaryMsg := false
                }
            } else if (bufType == 2 || bufType == 3) {
                txtMsg := StrGet(rxBuf.Ptr, bytesRead, "UTF-8")
                if InStr(txtMsg, "Path:turn.end") {
                    success := (totalAudioBytes > 0)
                    break
                }
            } else if (bufType == 4) {
                break
            }
        }
        mp3File.Close()
    } finally {
        if hWs
            DllCall("winhttp\WinHttpCloseHandle", "Ptr", hWs)
        if hRequest
            DllCall("winhttp\WinHttpCloseHandle", "Ptr", hRequest)
        if hConnect
            DllCall("winhttp\WinHttpCloseHandle", "Ptr", hConnect)
        if hSession
            DllCall("winhttp\WinHttpCloseHandle", "Ptr", hSession)
    }

    if (needClockRetry)
        return DownloadAzureMp3(text, voiceCode, rateStr, outMp3Path, false)

    return success
}

; ==============================================================================
; 3B. ALGORITMO CRIPTOGRÁFICO SEC-MS-GEC V2 (CS64 + SHA256 MODIFICADO)
; ==============================================================================
Rol16(v) {
    v := v & 0xFFFFFFFF
    return ((v << 16) | (v >> 16)) & 0xFFFFFFFF
}

Sigma0(v) {
    v := v & 0xFFFFFFFF
    return ((v >> 7) ^ (v << 25) ^ (v >> 18) ^ (v << 14) ^ (v >> 3)) & 0xFFFFFFFF
}

Sigma1(v) {
    v := v & 0xFFFFFFFF
    return ((v >> 17) ^ (v << 15) ^ (v >> 19) ^ (v << 13) ^ (v >> 10)) & 0xFFFFFFFF
}

RotR(v, n) {
    v := v & 0xFFFFFFFF
    return ((v >> n) | (v << (32 - n))) & 0xFFFFFFFF
}

Sha256Rounds(state, words, firstRound := 0) {
    static RC := [
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2
    ]
    a := state[1], b := state[2], c := state[3], d := state[4]
    e := state[5], f := state[6], g := state[7], h := state[8]

    idx := firstRound
    while (idx < 64) {
        k := (firstRound == 14 && idx == 14) ? 0xC9DC06A7 : RC[idx + 1]
        S1 := RotR(e, 6) ^ RotR(e, 11) ^ RotR(e, 25)
        ch := g ^ (e & (f ^ g))
        t1 := (h + S1 + ch + k + words[idx + 1]) & 0xFFFFFFFF
        S0 := RotR(a, 2) ^ RotR(a, 13) ^ RotR(a, 22)
        maj := (a & b) | (c & (a | b))
        t2 := (S0 + maj) & 0xFFFFFFFF

        h := g
        g := f
        f := e
        e := (d + t1) & 0xFFFFFFFF
        d := c
        c := b
        b := a
        a := (t1 + t2) & 0xFFFFFFFF
        idx += 1
    }
    return [a, b, c, d, e, f, g, h]
}

ExpandSchedule(words, firstWord := 16) {
    idx := firstWord
    while (idx < 64) {
        x := words[idx - 2 + 1]
        y := words[idx - 15 + 1]
        s1 := Sigma1(x)
        s0 := Sigma0(y)
        val := (s1 + words[idx - 7 + 1] + s0 + words[idx - 16 + 1]) & 0xFFFFFFFF
        words.Push(val)
        idx += 1
    }
}

Sha256Init(dataBuf) {
    static INIT := [0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19]
    static ST   := [0xFD9FBEA2, 0x91243CE7, 0xBE499094, 0xCD2E1E0A, 0x6C006F49, 0x04BD35AB, 0xFEB0A7E4, 0x03EFFBD2]
    static SCHED := [0xEB24BF9E, 0x1558691F, 0xA0C09EE2, 0x0CFA32BA, 0xA622EE8C, 0xD1DD9491, 0xC0DD25A0, 0xF9E70AB6, 0xF0C31573, 0x7058CE4E, 0x7188E606, 0x00E5AB33, 0xD258B060, 0x72766564]

    words := []
    Loop 14
        words.Push(0)
    w14 := (NumGet(dataBuf, 0, "UChar") << 16) | (NumGet(dataBuf, 1, "UChar") << 8) | NumGet(dataBuf, 2, "UChar")
    w15 := (NumGet(dataBuf, 3, "UChar") << 24) | (NumGet(dataBuf, 4, "UChar") << 16) | (NumGet(dataBuf, 5, "UChar") << 8) | NumGet(dataBuf, 6, "UChar")
    words.Push(w14 & 0xFFFFFFFF)
    words.Push(w15 & 0xFFFFFFFF)

    idx := 16
    while (idx < 30) {
        val := SCHED[idx - 16 + 1]
        if (idx - 2 >= 14) {
            s1 := Sigma1(words[idx - 2 + 1])
            val += (idx == 16) ? (s1 ^ 0x000B92C0) : s1
        }
        if (idx - 7 >= 14) {
            val += words[idx - 7 + 1]
        }
        if (idx - 15 >= 14) {
            s0 := Sigma0(words[idx - 15 + 1])
            val += (idx == 29) ? (s0 ^ 0x059C0B80) : s0
        }
        words.Push(val & 0xFFFFFFFF)
        idx += 1
    }
    w30 := (Sigma1(words[28 + 1]) + words[23 + 1] + Sigma0(words[15 + 1]) + words[14 + 1] + 0xC9DC06A7 - 0x9BDC06A7) & 0xFFFFFFFF
    words.Push(w30)
    ExpandSchedule(words, 31)
    working := Sha256Rounds(ST, words, 14)
    out := []
    Loop 8
        out.Push((INIT[A_Index] + working[A_Index]) & 0xFFFFFFFF)
    return out
}

ReadBE32(buf, offset) {
    return ((NumGet(buf, offset, "UChar") << 24) | (NumGet(buf, offset + 1, "UChar") << 16) | (NumGet(buf, offset + 2, "UChar") << 8) | NumGet(buf, offset + 3, "UChar")) & 0xFFFFFFFF
}

Sha256CustomDigest(dataBuf, dataLen) {
    totalLen := 57 + dataLen
    remLen := dataLen - 7
    padZeros := Mod(55 - Mod(totalLen, 64) + 64, 64)
    paddedLen := remLen + 1 + padZeros + 8
    padded := Buffer(paddedLen, 0)
    Loop remLen
        NumPut("UChar", NumGet(dataBuf, 6 + A_Index, "UChar"), padded, A_Index - 1)
    NumPut("UChar", 0x80, padded, remLen)
    bitLen := totalLen * 8
    NumPut("UChar", (bitLen >> 56) & 0xFF, padded, paddedLen - 8)
    NumPut("UChar", (bitLen >> 48) & 0xFF, padded, paddedLen - 7)
    NumPut("UChar", (bitLen >> 40) & 0xFF, padded, paddedLen - 6)
    NumPut("UChar", (bitLen >> 32) & 0xFF, padded, paddedLen - 5)
    NumPut("UChar", (bitLen >> 24) & 0xFF, padded, paddedLen - 4)
    NumPut("UChar", (bitLen >> 16) & 0xFF, padded, paddedLen - 3)
    NumPut("UChar", (bitLen >> 8)  & 0xFF, padded, paddedLen - 2)
    NumPut("UChar",  bitLen        & 0xFF, padded, paddedLen - 1)

    state := Sha256Init(dataBuf)
    offset := 0
    while (offset < paddedLen) {
        words := []
        Loop 16
            words.Push(ReadBE32(padded, offset + (A_Index - 1) * 4))
        ExpandSchedule(words, 16)
        working := Sha256Rounds(state, words, 0)
        Loop 8
            state[A_Index] := (state[A_Index] + working[A_Index]) & 0xFFFFFFFF
        offset += 64
    }
    digest := Buffer(32, 0)
    Loop 8 {
        v := state[A_Index]
        off := (A_Index - 1) * 4
        NumPut("UChar", (v >> 24) & 0xFF, digest, off)
        NumPut("UChar", (v >> 16) & 0xFF, digest, off + 1)
        NumPut("UChar", (v >> 8)  & 0xFF, digest, off + 2)
        NumPut("UChar",  v        & 0xFF, digest, off + 3)
    }
    return digest
}

Cs64Digest(dataBuf, dataLen, digestBuf) {
    static COEFF := [
        [0xE82E91B1, 0xB32700D0], [0x44DE24C6, 0x88DFF51D], [0x3BEB65BC, 0x29514038], [0xC89C5933, 0xB328CBDF],
        [0x8D1EC211, 0xD405B4D5], [0x314EF5D5, 0x26E55F3C], [0xE92491B1, 0x607801C6], [0xF0A5B9D5, 0x82B2C1FB],
        [0x06064CF3, 0xFA51A3DA], [0xDA79FA60, 0x207CC464], [0xBED20560, 0x3C3C74F3], [0x89F9C9F8, 0xD2D14B61],
        [0x35FA38C6, 0xBB04A2C1], [0xCB49E3C6, 0xC5626167]
    ]
    keyA := NumGet(digestBuf, 0, "UInt") | 1
    keyB := NumGet(digestBuf, 4, "UInt") | 1
    fac0 := (keyA * 0x82893933) & 0xFFFFFFFF
    fac1 := (keyB * 0x82893933) & 0xFFFFFFFF

    terms := []
    offsets := []
    Loop 14 {
        idx0 := A_Index - 1
        c := COEFF[A_Index][1]
        o := COEFF[A_Index][2]
        f := (Mod(idx0, 2) == 0) ? fac0 : fac1
        terms.Push((c * f) & 0xFFFFFFFF)
        offsets.Push(o & 0xFFFFFFFF)
    }

    rawLen := 1 + dataLen
    padLen := Mod((4 - Mod(rawLen, 4)), 4)
    totBytes := rawLen + padLen
    if (Mod(totBytes // 4, 2) == 1)
        totBytes += 4
    wBuf := Buffer(totBytes, 0)
    Loop dataLen
        NumPut("UChar", NumGet(dataBuf, A_Index - 1, "UChar"), wBuf, A_Index)

    numWords := totBytes // 4
    Loop numWords {
        idx0 := A_Index - 1
        w := NumGet(wBuf, idx0 * 4, "UInt")
        k := (Mod(idx0, 2) == 0) ? keyA : keyB
        m := (Mod(idx0, 2) == 0) ? 0xEF0569FB : 0xC31713DB
        term := (w * k) & 0xFFFFFFFF
        off  := (Rol16(w) * m) & 0xFFFFFFFF
        if (idx0 == 0) {
            term := (term + ((0xF2F90B1A * fac0) & 0xFFFFFFFF)) & 0xFFFFFFFF
            off  := (off + 0x0B1A0000) & 0xFFFFFFFF
        }
        terms.Push(term)
        offsets.Push(off)
    }

    swapAcc := 0, swapLast := 0, state := 0, acc := 0
    idx := 1
    while (idx <= terms.Length) {
        x := terms[idx]
        y := terms[idx + 1]
        ox := offsets[idx]
        oy := offsets[idx + 1]

        t := Rol16((ox + x) & 0xFFFFFFFF)
        q := (t * 0x76F50F34) & 0xFFFFFFFF
        swapAcc := (swapAcc + ((Rol16(q) * 0xC3EFEA97 + q) & 0xFFFFFFFF)) & 0xFFFFFFFF

        t := Rol16((oy + y) & 0xFFFFFFFF)
        q := (t * 0x1881CE3C) & 0xFFFFFFFF
        swapLast := (Rol16(q) * 0x35BD1EC9 + q) & 0xFFFFFFFF
        swapAcc := (swapAcc + swapLast) & 0xFFFFFFFF

        state := (state * keyA + x) & 0xFFFFFFFF
        state := (Rol16(state) * 0xCF98B111) & 0xFFFFFFFF
        state := (Rol16(state) * 0x87085B9F) & 0xFFFFFFFF
        state := (Rol16(state) * 0x12CEB96D) & 0xFFFFFFFF
        state := (Rol16(state) * 0x257E1D83) & 0xFFFFFFFF
        acc := (acc + state) & 0xFFFFFFFF

        t := (state * keyB + y) & 0xFFFFFFFF
        t := (Rol16(t) * 0xA27416F5) & 0xFFFFFFFF
        t := (Rol16(t) * 0xD38396FF) & 0xFFFFFFFF
        state := (Rol16((Rol16(t) * 0x7C932B89) & 0xFFFFFFFF) * 0xBFA49F69) & 0xFFFFFFFF
        acc := (acc + state) & 0xFFFFFFFF

        idx += 2
    }

    w0 := (swapLast ^ state) & 0xFFFFFFFF
    w1 := (swapAcc ^ acc) & 0xFFFFFFFF
    csBuf := Buffer(8, 0)
    NumPut("UInt", w0, csBuf, 0)
    NumPut("UInt", w1, csBuf, 4)
    csHex := ""
    Loop 8
        csHex .= Format("{:02X}", NumGet(csBuf, A_Index - 1, "UChar"))
    return csHex
}

GenSecMsGecV2(ticks) {
    static TrustedToken := "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    str := String(ticks) . TrustedToken
    bufSize := StrPut(str, "UTF-8")
    dataBuf := Buffer(bufSize, 0)
    StrPut(str, dataBuf, "UTF-8")
    dataLen := bufSize - 1

    digestBuf := Sha256CustomDigest(dataBuf, dataLen)
    shaHex := ""
    Loop 32
        shaHex .= Format("{:02X}", NumGet(digestBuf, A_Index - 1, "UChar"))
    csHex := Cs64Digest(dataBuf, dataLen, digestBuf)
    return csHex "-" shaHex
}

SyncClockFromResponse(hRequest, localFileTime) {
    global ServerClockOffset
    dateBuf := Buffer(256, 0)
    byteLen := 256
    if DllCall("winhttp\WinHttpQueryHeaders", "Ptr", hRequest, "UInt", 9, "Ptr", 0, "Ptr", dateBuf, "UInt*", &byteLen, "Ptr", 0) {
        sysTime := Buffer(16, 0)
        if DllCall("winhttp\WinHttpTimeToSystemTime", "Ptr", dateBuf, "Ptr", sysTime) {
            srvFileTime := 0
            if DllCall("kernel32\SystemTimeToFileTime", "Ptr", sysTime, "Int64*", &srvFileTime) {
                ServerClockOffset := srvFileTime - localFileTime
                return true
            }
        }
    }
    return false
}

WsSendText(hWs, str) {
    bufSize := StrPut(str, "UTF-8")
    buf := Buffer(bufSize, 0)
    StrPut(str, buf, "UTF-8")
    utf8Len := bufSize - 1
    return DllCall("winhttp\WinHttpWebSocketSend", "Ptr", hWs, "Int", 2, "Ptr", buf, "UInt", utf8Len, "UInt")
}

GenHexId(upper := false) {
    id := ""
    fmt := upper ? "{:X}" : "{:x}"
    Loop 32
        id .= Format(fmt, Random(0, 15))
    return id
}

EscapeXml(s) {
    s := StrReplace(s, "&", "&amp;")
    s := StrReplace(s, "<", "&lt;")
    s := StrReplace(s, ">", "&gt;")
    s := StrReplace(s, '"', "&quot;")
    s := StrReplace(s, "'", "&apos;")
    return s
}

MciSend(cmd) {
    buf := Buffer(512, 0)
    DllCall("winmm.dll\mciSendStringW", "WStr", cmd, "Ptr", buf, "UInt", 256, "Ptr", 0)
    return StrGet(buf, "UTF-16")
}

MciPlay(filePath) {
    global Cfg
    MciSend("close donvox_audio")
    MciSend('open "' filePath '" type mpegvideo alias donvox_audio')
    MciSend("setaudio donvox_audio volume to " (Cfg.Volume * 10))
    MciSend("play donvox_audio")
}

; ==============================================================================
; 4. ACCIONES DE CONTROL (ATAJOS Y BANDEJA)
; ==============================================================================
ActionReadSelection(*) {
    global IgnoreClipboardEvent
    savedClip := ClipboardAll()
    IgnoreClipboardEvent := true
    A_Clipboard := ""
    Send("^c")
    if ClipWait(0.4) {
        selectedText := A_Clipboard
        A_Clipboard := savedClip
        SetTimer(() => (IgnoreClipboardEvent := false), -250)
        SpeakText(selectedText)
    } else {
        A_Clipboard := savedClip
        IgnoreClipboardEvent := false
        if (A_Clipboard != "")
            SpeakText(A_Clipboard)
    }
}

ActionPauseResume(*) {
    global SpVoice, Cfg, IsPaused
    if (Cfg.UseAzure) {
        status := MciSend("status donvox_audio mode")
        if InStr(status, "playing") {
            MciSend("pause donvox_audio")
            IsPaused := true
        } else if InStr(status, "paused") {
            MciSend("resume donvox_audio")
            IsPaused := false
        }
    } else {
        try {
            if !IsPaused {
                SpVoice.Pause()
                IsPaused := true
            } else {
                SpVoice.Resume()
                IsPaused := false
            }
        }
    }
    UpdateTrayMenuState()
}

StopReading(*) {
    global SpVoice, IsPaused
    MciSend("close donvox_audio")
    try {
        if IsPaused {
            SpVoice.Resume()
            IsPaused := false
        }
        SpVoice.Speak("", 3)
    }
    IsPaused := false
    UpdateTrayMenuState()
}

ActionRepeat(*) {
    global LastSpokenText
    if (LastSpokenText != "")
        SpeakText(LastSpokenText)
    else if (A_Clipboard != "")
        SpeakText(A_Clipboard)
}

ActionToggleMaster(*) {
    global Cfg, AppName, AppVersion, Lang
    Cfg.MasterEnabled := !Cfg.MasterEnabled
    SaveConfig()
    if !Cfg.MasterEnabled {
        StopReading()
        SoundBeep(400, 120)
        TrayTip(Lang.MsgDisabled, AppName " " AppVersion, 1)
    } else {
        UpdateTrayMenuState()
        SoundBeep(800, 120)
        TrayTip(Lang.MsgEnabled, AppName " " AppVersion, 1)
    }
}

; ==============================================================================
; 5. MONITOR DEL PORTAPAPELES
; ==============================================================================
OnClipboardUpdate(DataType) {
    global Cfg, IgnoreClipboardEvent
    if (DataType != 1 || IgnoreClipboardEvent)
        return
    if (!Cfg.MasterEnabled || !Cfg.AutoClipboard)
        return

    clipText := Trim(A_Clipboard, " `t`r`n")
    if (StrLen(clipText) < Cfg.MinChars)
        return

    SpeakText(clipText)
}

; ==============================================================================
; 6. REGISTRO DINÁMICO DE ATAJOS DE TECLADO
; ==============================================================================
RegisterAllHotkeys() {
    global Cfg, ActiveHotkeys
    for hk in ActiveHotkeys {
        try Hotkey(hk, "Off")
    }
    ActiveHotkeys := []

    BindKey(Cfg.HkReadSel, ActionReadSelection)
    BindKey(Cfg.HkPause,   ActionPauseResume)
    BindKey(Cfg.HkStop,    StopReading)
    BindKey(Cfg.HkRepeat,  ActionRepeat)
    BindKey(Cfg.HkToggle,  ActionToggleMaster)
}

BindKey(hkStr, callback) {
    global ActiveHotkeys, AppName, AppVersion, Lang
    hkStr := Trim(hkStr)
    if (hkStr == "" || hkStr == "None")
        return
    try {
        Hotkey(hkStr, callback, "On")
        ActiveHotkeys.Push(hkStr)
    } catch as err {
        TrayTip(Lang.MsgHkErr . hkStr "): " err.Message, AppName " " AppVersion, 2)
    }
}

; ==============================================================================
; 7. MENÚ EN LA BANDEJA DEL SISTEMA E ICONOS DINÁMICOS
; ==============================================================================
SetupTrayMenu() {
    global AppName, AppVersion, Lang
    tray := A_TrayMenu
    tray.Delete()

    tray.Add(AppName " " AppVersion " - " Lang.MenuSettings, ShowSettingsGui)
    tray.Default := AppName " " AppVersion " - " Lang.MenuSettings
    tray.Add()
    tray.Add(Lang.MenuMaster, (*) => ActionToggleMaster())
    tray.Add(Lang.MenuAutoClip, ToggleAutoClipboard)
    tray.Add(Lang.MenuAzure, ToggleAzureMode)
    tray.Add()
    tray.Add(Lang.MenuRepeat, ActionRepeat)
    tray.Add(Lang.MenuPause, ActionPauseResume)
    tray.Add(Lang.MenuStop, StopReading)
    tray.Add()
    tray.Add(Lang.MenuExit, (*) => ExitApp())

    UpdateTrayMenuState()
}

ToggleAutoClipboard(*) {
    global Cfg
    Cfg.AutoClipboard := !Cfg.AutoClipboard
    SaveConfig()
    UpdateTrayMenuState()
}

ToggleAzureMode(*) {
    global Cfg
    Cfg.UseAzure := !Cfg.UseAzure
    SaveConfig()
    UpdateTrayMenuState()
}

UpdateTrayMenuState() {
    global Cfg, AppName, AppVersion, IsPaused, StateIcons, Lang
    tray := A_TrayMenu
    if Cfg.MasterEnabled
        tray.Check(Lang.MenuMaster)
    else
        tray.Uncheck(Lang.MenuMaster)

    if Cfg.AutoClipboard
        tray.Check(Lang.MenuAutoClip)
    else
        tray.Uncheck(Lang.MenuAutoClip)

    if Cfg.UseAzure
        tray.Check(Lang.MenuAzure)
    else
        tray.Uncheck(Lang.MenuAzure)

    if !Cfg.MasterEnabled {
        TraySetIcon("HICON:*" StateIcons.Gray)
        stateTxt := Lang.StateDisabled
    } else if IsPaused {
        TraySetIcon("HICON:*" StateIcons.Yellow)
        stateTxt := Lang.StatePaused
    } else if Cfg.UseAzure {
        TraySetIcon("HICON:*" StateIcons.Blue)
        stateTxt := Lang.StateAzure
    } else {
        TraySetIcon("HICON:*" StateIcons.Green)
        stateTxt := Lang.StateLocal
    }

    A_IconTip := AppName " " AppVersion " [" stateTxt "]"
}

; ==============================================================================
; 8. VENTANA GRÁFICA DE CONFIGURACIÓN (ADAPTACIÓN EN GROUPBOX + MULTI-IDIOMA)
; ==============================================================================
ShowSettingsGui(*) {
    global SettingsGui, Cfg, VoiceNames, AzureVoices, StateIcons, AppName, AppVersion, VersionNum, Lang, DonateUrl, RepoUrl
    if IsObject(SettingsGui) {
        try {
            SettingsGui.Show()
            return
        }
    }

    isDark   := IsWin11DarkMode()
    lblColor := isDark ? "cFFFFFF" : "c000000" ; Blanco puro para títulos y texto principal
    txtColor := isDark ? "cCCCCCC" : "c333333" ; Gris suave para subtítulos y etiquetas
    bgColor  := isDark ? "191919" : "F3F3F3"  ; Fondo grafito G-Helper

    ; -DPIScale y fuente tamaño 8 (s8) para coincidir 1:1 con el diseño de referencia (w512 h681)
    SettingsGui := Gui("+OwnDialogs -DPIScale", AppName " " AppVersion " - " Lang.WinTitle)
    SettingsGui.BackColor := bgColor
    pt := 8

    ; DWM: Barra de título moderna y esquinas redondeadas
    darkFlag := Buffer(4, 0)
    NumPut("Int", isDark ? 1 : 0, darkFlag, 0)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", SettingsGui.Hwnd, "Int", 20, "Ptr", darkFlag, "Int", 4)
    cornerFlag := Buffer(4, 0)
    NumPut("Int", 2, cornerFlag, 0)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", SettingsGui.Hwnd, "Int", 33, "Ptr", cornerFlag, "Int", 4)

    ; Configurar fondo oscuro para esquinas redondeadas de botones nativos (WM_CTLCOLORBTN = 0x0135)
    InitDarkButtonSupport(isDark)

    ; =================== 1. SECCIÓN: COMPORTAMIENTO GENERAL ===================
    SettingsGui.SetFont("s" pt " Bold " lblColor, "Segoe UI")
    hdrGeneral := SettingsGui.Add("Text", "x24 y16 w465 h22 +0x200", Lang.SecGeneral)
    hdrGeneral.SetFont("s" pt " Bold " lblColor, "Segoe UI")

    SettingsGui.SetFont("s" pt " norm " lblColor, "Segoe UI")
    chkMaster  := SettingsGui.Add("CheckBox", "x32 y48 w456 h20 -Wrap " lblColor " Checked" Cfg.MasterEnabled, Lang.ChkMaster)
    chkClip    := SettingsGui.Add("CheckBox", "x32 y72 w456 h20 -Wrap " lblColor " Checked" Cfg.AutoClipboard, Lang.ChkClipboard)
    chkStartup := SettingsGui.Add("CheckBox", "x32 y96 w456 h20 -Wrap " lblColor " Checked" Cfg.StartWithWin, Lang.ChkStartup)

    ; =================== 2. SECCIÓN: MOTOR DE VOZ Y AJUSTES ===================
    SettingsGui.SetFont("s" pt " Bold " lblColor, "Segoe UI")
    hdrVoice := SettingsGui.Add("Text", "x24 y144 w465 h22 +0x200", Lang.SecVoice)
    hdrVoice.SetFont("s" pt " Bold " lblColor, "Segoe UI")

    SettingsGui.SetFont("s" pt " norm " txtColor, "Segoe UI")
    SettingsGui.Add("Text", "x32 y176 w440 h22 +0x200 " txtColor, Lang.LblLocalVoice)
    ddlLocal := SettingsGui.Add("DropDownList", "x32 y200 w456 Choose" Cfg.LocalVoiceIndex, VoiceNames)

    SettingsGui.SetFont("s" pt " norm " lblColor, "Segoe UI")
    chkAzure := SettingsGui.Add("CheckBox", "x32 y240 w456 h22 -Wrap " lblColor " Checked" Cfg.UseAzure, Lang.ChkAzure)
    ddlAzure := SettingsGui.Add("DropDownList", "x32 y264 w456 Choose" Cfg.AzureVoiceIndex, AzureVoices)

    SettingsGui.SetFont("s" pt " norm " txtColor, "Segoe UI")
    SettingsGui.Add("Text", "x32 y304 w71 h20 " txtColor, Lang.LblRate)
    sldRate  := SettingsGui.Add("Slider", "x104 y304 w156 h41 Range-10-10 ToolTip", Cfg.Rate)

    SettingsGui.Add("Text", "x272 y304 w69 h20 " txtColor, Lang.LblVolume)
    sldVol   := SettingsGui.Add("Slider", "x336 y304 w156 h41 Range0-100 ToolTip", Cfg.Volume)

    ; =================== 3. SECCIÓN: ATAJOS DE TECLADO GLOBALES ===================
    SettingsGui.SetFont("s" pt " Bold " lblColor, "Segoe UI")
    hdrHotkeys := SettingsGui.Add("Text", "x24 y376 w465 h22", Lang.SecHotkeys)
    hdrHotkeys.SetFont("s" pt " Bold " lblColor, "Segoe UI")

    SettingsGui.SetFont("s" pt " norm " txtColor, "Segoe UI")

    SettingsGui.Add("Text", "x32 y408 w225 h22 +0x200", Lang.LblHkReadSel)
    hkSel := SettingsGui.Add("Hotkey", "x264 y408 w224 h24", Cfg.HkReadSel)

    SettingsGui.Add("Text", "x32 y448 w225 h22", Lang.LblHkPause)
    hkPau := SettingsGui.Add("Hotkey", "x264 y448 w225 h24", Cfg.HkPause)

    SettingsGui.Add("Text", "x32 y488 w225 h22", Lang.LblHkStop)
    hkStp := SettingsGui.Add("Hotkey", "x264 y488 w225 h24", Cfg.HkStop)

    SettingsGui.Add("Text", "x32 y528 w225 h22", Lang.LblHkRepeat)
    hkRep := SettingsGui.Add("Hotkey", "x264 y528 w225 h24", Cfg.HkRepeat)

    SettingsGui.Add("Text", "x32 y568 w225 h22", Lang.LblHkToggle)
    hkTog := SettingsGui.Add("Hotkey", "x264 y568 w225 h24", Cfg.HkToggle)

    ; =================== 4. VERSIÓN Y BOTONES REALES REDONDEADOS ===================
    verColor := isDark ? "c60CDFF" : "c0080C0"
    lblVer := SettingsGui.Add("Text", "x32 y608 w163 h20 " verColor, Lang.LblVersion)
    lblVer.SetFont("underline")
    lblVer.OnEvent("Click", (*) => Run(RepoUrl))

    SettingsGui.SetFont("s" pt " norm " lblColor, "Segoe UI")
    btnDonate := SettingsGui.Add("Button", "x24 y640 w75 h23", Lang.BtnDonate)
    btnTest   := SettingsGui.Add("Button", "x112 y640 w105 h23", Lang.BtnTest)
    btnStop   := SettingsGui.Add("Button", "x232 y640 w90 h23", Lang.BtnStop)
    btnSave   := SettingsGui.Add("Button", "x336 y640 w155 h23", Lang.BtnSave)

    ; Aplicar temas oscuros a casillas, listas de selección y botones redondeados nativos
    if isDark {
        for chk in [chkMaster, chkClip, chkStartup, chkAzure] {
            try DllCall("uxtheme\SetWindowTheme", "Ptr", chk.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        }
        for ddl in [ddlLocal, ddlAzure] {
            try DllCall("uxtheme\SetWindowTheme", "Ptr", ddl.Hwnd, "WStr", "DarkMode_CFD", "Ptr", 0)
        }
        for btn in [btnDonate, btnTest, btnStop, btnSave] {
            try DllCall("uxtheme\SetWindowTheme", "Ptr", btn.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        }
    }

    btnDonate.OnEvent("Click", (ctrl, *) => (
        ClearBtnDefaultFocus(ctrl, SettingsGui),
        Run(DonateUrl)
    ))

    btnStop.OnEvent("Click", (ctrl, *) => (
        ClearBtnDefaultFocus(ctrl, SettingsGui),
        StopReading()
    ))

    btnTest.OnEvent("Click", (ctrl, *) => (
        ClearBtnDefaultFocus(ctrl, SettingsGui),
        Cfg.UseAzure := chkAzure.Value,
        Cfg.LocalVoiceIndex := ddlLocal.Value,
        Cfg.AzureVoiceIndex := ddlAzure.Value,
        Cfg.Rate := sldRate.Value,
        Cfg.Volume := sldVol.Value,
        ApplyVoiceSettings(),
        SpeakText(Lang.TestPhrase)
    ))

    btnSave.OnEvent("Click", (*) => (
        Cfg.MasterEnabled   := chkMaster.Value,
        Cfg.AutoClipboard   := chkClip.Value,
        Cfg.StartWithWin    := chkStartup.Value,
        Cfg.UseAzure        := chkAzure.Value,
        Cfg.LocalVoiceIndex := ddlLocal.Value,
        Cfg.AzureVoiceIndex := ddlAzure.Value,
        Cfg.Rate            := sldRate.Value,
        Cfg.Volume          := sldVol.Value,
        Cfg.HkReadSel       := hkSel.Value,
        Cfg.HkPause         := hkPau.Value,
        Cfg.HkStop          := hkStp.Value,
        Cfg.HkRepeat        := hkRep.Value,
        Cfg.HkToggle        := hkTog.Value,
        ApplyStartupRegistry(),
        ApplyVoiceSettings(),
        RegisterAllHotkeys(),
        SaveConfig(),
        UpdateTrayMenuState(),
        SettingsGui.Destroy(),
        SettingsGui := ""
    ))

    SettingsGui.OnEvent("Close", (*) => (SettingsGui.Destroy(), SettingsGui := ""))
    SettingsGui.Show("w512 h681")
}

; ==============================================================================
; 9. SOPORTE DE BOTONES NATIVOS REDONDEADOS EN MODO OSCURO (DarkMode_Explorer)
; ==============================================================================
global GhDarkBtnBrush := 0

InitDarkButtonSupport(isDark) {
    global GhDarkBtnBrush
    if !GhDarkBtnBrush
        GhDarkBtnBrush := DllCall("CreateSolidBrush", "UInt", 0x191919, "Ptr")
    static registered := false
    if !registered {
        OnMessage(0x0135, OnWmCtlColorBtn) ; WM_CTLCOLORBTN
        registered := true
    }
}

OnWmCtlColorBtn(wParam, lParam, msg, hwnd) {
    global GhDarkBtnBrush
    if IsWin11DarkMode() && GhDarkBtnBrush
        return GhDarkBtnBrush
}

ClearBtnDefaultFocus(btnCtrl, guiObj) {
    try ControlSetStyle("-0x1", btnCtrl.Hwnd) ; Quitar BS_DEFPUSHBUTTON para evitar borde blanco
    try DllCall("SetFocus", "Ptr", guiObj.Hwnd)
}