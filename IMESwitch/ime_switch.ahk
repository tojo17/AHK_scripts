#Requires AutoHotkey v2.0
#SingleInstance Force

; https://github.com/k-ayaki/IMEv2.ahk
#Include ./IMEv2.ahk/IMEv2.ahk

; IME Switcher for AutoHotkey v2
; Press Muhenkan for zh_CN, Henkan for ja_JP
; Press same key again to toggle between NATIVE and ALPHANUMERIC modes
; In ja_JP, press Kana for F7, toggle JP/EN if no input, or convert to Katakana if input exists
; In zh_CN, press Kana to toggle CN/EN

; Required settings:
; - Set in Japanese IME
;   - Ctrl + F12 for IME ON
;   - Ctrl + Shift + F12 for IME OFF (Should be copied from the IME OFF key, or you cannot set this function for all)
;   - F7 for toggling IME ON/OFF
; - Set in Chinese IME
;   - Ctrl + Space for toggling CN/EN

logging := false ; Set to true to enable logging
flog(text) {
    if (logging) {
        ; ignore if write to file failed
        try {
            FileAppend(A_Now " " text "`n", "ime_switch.log")
        } 
    }
}

locales := {
    ja: {
        trigger: "SC079", ; henkan
        hkl: Number("0x04110411"),
        na_toggle_key: "{F7}",
        native: {
            conv_mode: 25,
            ime_status: 1,
            switch_hotkey: "^{F12}" ; Ctrl + F12
        },
        alphanumeric: {
            conv_mode: 25,
            ime_status: 0,
            switch_hotkey: "^+{F12}" ; Ctrl + Shift + F12
        }
    },
    zh_cn: {
        trigger: "SC07B", ; muhenkan
        hkl: Number("0x08040804"),
        na_toggle_key: "^ ", ; Ctrl + Space
        native: {
            conv_mode: 1,
            ime_status: 1
        },
        alphanumeric: {
            conv_mode: 0,
            ime_status: 0
        }
    }
}
kana_hotkey := "SC070" ; Kana key

debugging_tooltip := false ; Set to true to enable debugging tooltip
; Show the current HKL in a tooltip
debug_status() {
    t_lang := Get_Keyboard_Layout()
    t_lang := Format("{:X}", t_lang)
    t_convmode := IME_GetConvMode()
    t_imestatus := IME_GET()
    flog("[Debug] Current HKL: " t_lang ", ConvMode: " t_convmode ", IME Status: " t_imestatus)
    if (debugging_tooltip) {
        ToolTip("Current IME: " t_lang " | Conversion Mode: " t_convmode " | Status: " t_imestatus)
        SetTimer(ToolTip, -5000)  ; Hide tooltip after 5 seconds
    }
}

set_keyboard_layout(hkl, winTitle := "A") {
    hwnd := WinExist(winTitle)
    if (WinActive(winTitle)) {
        ptrSize := !A_PtrSize ? 4 : A_PtrSize
        cbSize := 4 + 4 + (ptrSize * 6) + 16
        stGTI := Buffer(cbSize, 0)
        NumPut("Uint", cbSize, stGTI.Ptr)   ;   DWORD   cbSize;
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "Ptr", stGTI)
            ? NumGet(stGTI, 8 + ptrSize, "UInt") : hwnd
    }
    ; WM_INPUTLANGCHANGEREQUEST = 0x50
    ok := DllCall("PostMessageW", "ptr", hwnd, "uint", 0x50, "ptr", 0, "ptr", hkl, "int")
    return ok != 0
}

; get current locale config
get_locale_config(){
    current_hkl := Get_Keyboard_Layout()
    for locale, data in locales.OwnProps() {
        if (current_hkl = data.hkl) {
            return data
        }
    }
    flog("[Error] No matching locale found for current HKL: " current_hkl)
    ToolTip("No matching locale found")
    SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
    return
}

; return: 0 for ALPHANUMERIC, 1 for NATIVE, 2 for unsure
; IME = 1 ?
;   Y: zh_CN_NATIVE/ja_NATIVE -> 1
;   N: zh_CN ?
;       Y: CONV_MODE = 1 ?
;           Y: zh_CN_NATIVE(UWP) -> 1
;           N: zh_CN_ALPHANUMERIC(UWP or not) -> 0
;       N: ja_ALPHANUMERIC(UWP or not)/ja_NATIVE(UWP) -> 2

get_na() {
    l_config := get_locale_config()
    if (!l_config) {
        flog("[Error] get_na: No locale config found")
        return
    }
    debug_status()
    conv_mode := IME_GetConvMode()
    ime_status := IME_GET()
    if (ime_status = l_config.native.ime_status) {
        flog("[Info] get_na: zh_CN_NATIVE/ja_NATIVE, conv_mode: " conv_mode ", ime_status: " ime_status)
        return 1 ; NATIVE
    } else {
        if (l_config.hkl = locales.zh_cn.hkl) {
            if (conv_mode = l_config.native.conv_mode) {
                flog("[Warn] get_na: zh_CN_NATIVE(UWP), conv_mode: " conv_mode ", ime_status: " ime_status)
                return 1 ; NATIVE
            } else {
                flog("[Info] get_na: zh_CN_ALPHANUMERIC(UWP or not), conv_mode: " conv_mode ", ime_status: " ime_status)
                return 0 ; ALPHANUMERIC
            }
        } else {
            flog("[Warn] get_na: ja_ALPHANUMERIC(UWP or not)/ja_NATIVE(UWP)/unknown, conv_mode: " conv_mode ", ime_status: " ime_status)
            ; unsure
            return 2
        }
    }
}

; target : 0 for ALPHANUMERIC, 1 for NATIVE, if other or not provided, it will toggle
toggle_na(target := "") {
    flog("[Info] toggle_na: target: " target)
    l_config := get_locale_config()
    if (!l_config) {
        flog("[Error] toggle_na: No locale config found")
        return
    }
    na_toggle_key := l_config.na_toggle_key
    current_na := get_na()
    if (target = 0) {
        na_config := l_config.alphanumeric
    } else if (target = 1) {
        na_config := l_config.native
    } else {
        ; Toggle between NATIVE and ALPHANUMERIC
        flog("[Info] toggle_na: current_na: " current_na)
        if (current_na = 0) {
            flog("[Info] toggle_na: Switching to NATIVE")
            toggle_na(1) ; Switch to NATIVE
        } else if (current_na = 1) {
            flog("[Info] toggle_na: Switching to ALPHANUMERIC")
            toggle_na(0) ; Switch to ALPHANUMERIC
        } else {
            ; If unsure, use toggle hotkey
            flog("[Info] toggle_na: Unsure, using toggle hotkey: " na_toggle_key)
            Send(na_toggle_key)
        }
        return
    }
    ; Start switching process
    if (current_na = 2) {
        ; If unsure, use switch hotkey
        ; Must be ja
        if (na_config.HasOwnProp("switch_hotkey")) {
            flog("[Info] toggle_na: Unsure current NA mode, using switch hotkey: " na_config.switch_hotkey)
            Send(na_config.switch_hotkey)
            if get_na() = target {
                ; not UWP, ja A->N
                flog("[Info] toggle_na: Switched using switch_hotkey, not UWP, ja A->N")
                ToolTip("ja")
                SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
                return
            } else {
                flog("[Info] toggle_na: Swicthed, but unsure if successful, UWP, ja")
                ; skip tooltip
                return
            }
        } else {
            flog("[Error] toggle_na: No switch_hotkey defined for locale: " l_config.hkl)
            ToolTip("No switch_hotkey defined for this locale")
            SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
            return
        }
    } else {
        flog("[Info] toggle_na: Current NA mode is known, try set ime_status & conv_mode")
        IME_SET(na_config.ime_status)
        IME_SetConvMode(na_config.conv_mode)
        new_na := get_na()
        if (new_na = target) {
            ; zh_CN switch success
            flog("[Info] toggle_na: Switched to target using ime_status and conv_mode, zh_CN")
            ToolTip(target = 1 ? "zh_cn" : "en")
            SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
            return
        } else if (new_na = 2) {
            ; ja switch success
            flog("[Info] toggle_na: Switched to target using ime_status and conv_mode, ja")
            ToolTip(target = 1 ? "ja" : "en")
            SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
            return
        } else {
            flog("[Error] toggle_na: Failed to switch to target using ime_status and conv_mode, current NA: " new_na)
            flog("[Warn] toggle_na: Fallback using toggle hotkey: " na_toggle_key)
            Send(na_toggle_key)
            return
        }
    }
}


; locale_pressed: "zh_cn", "ja", etc.
switch_lang(locale_pressed, *) {
    flog("[Info] switch_lang: locale_pressed: " locale_pressed)
    current_hkl := Get_Keyboard_Layout()
    flog("[Info] switch_lang: current_hkl: " current_hkl)
    if (current_hkl = locales.%locale_pressed%.hkl) {
        ; If pressed same locale, toggle between NATIVE and ALPHANUMERIC
        flog("[Info] switch_lang: Same locale pressed, toggling NATIVE/ALPHANUMERIC")
        toggle_na()
    } else {
        ; If pressed different locale, switch to that locale
        flog("[Info] switch_lang: Switching to locale: " locale_pressed)
        set_keyboard_layout(locales.%locale_pressed%.hkl)
        ; Wait for the layout to be set
        Sleep(100)
        ; Toggle to NATIVE
        if (get_na() != 1) {
            flog("[Info] switch_lang: Toggling to NATIVE after switching locale")
            toggle_na(1)
        }
        ToolTip(locale_pressed)
        SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
    }
    debug_status()
}

; Send toggle hotkey for kana key
kana(){
    flog("[Info] kana: Kana key pressed")
    l_config := get_locale_config()
    if (!l_config) {
        flog("[Error] get_na: No locale config found")
        return
    }
    Send(l_config.na_toggle_key)
    flog("[Info] kana: Sent toggle hotkey: " l_config.na_toggle_key)
}

; Hotkeys for switching locales
for locale, data in locales.OwnProps() {
    Hotkey(data.trigger,switch_lang.Bind(locale))
}
; Hotkey for kana
Hotkey(kana_hotkey, (*) => kana())

; q::debug_status()
