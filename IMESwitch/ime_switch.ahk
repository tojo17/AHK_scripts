#Requires AutoHotkey v2.0
#SingleInstance Force

; https://github.com/k-ayaki/IMEv2.ahk
#Include ./IMEv2.ahk/IMEv2.ahk

locales := {
    ja: {
        trigger: "vkFF", ; henkan
        hkl: Number("0x04110411"),
        na_toggle_key: "{F7}",
        native: {
            conv_mode: 25,
            ime_status: 1
        },
        alphanumeric: {
            conv_mode: 25,
            ime_status: 0,
            switch_hotkey: "vk1A" ; IME OFF
        }
    },
    zh_cn: {
        trigger: "vkEB", ; muhenkan
        hkl: Number("0x08040804"),
        na_toggle_key: "^ ",
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

toggle_hotkey := "RAlt" ; toggle NATIVE/ALPHANUMERIC

; ; Show the current HKL in a tooltip
debug_status() {
    t_lang := Get_Keyboard_Layout()
    t_lang := Format("{:X}", t_lang)
    t_convmode := IME_GetConvMode()
    t_imestatus := IME_GET()
    ToolTip("Current IME: " t_lang " | Conversion Mode: " t_convmode " | Status: " t_imestatus)
    SetTimer(ToolTip, -5000)  ; Hide tooltip after 2 seconds
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
    ToolTip("No matching locale found")
    SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
    return
}

; return: 0 for ALPHANUMERIC, 1 for NATIVE, none for other
get_na() {
    l_config := get_locale_config()
    if (!l_config)
        return
    if (IME_GetConvMode() = l_config.alphanumeric.conv_mode
        && IME_GET() = l_config.alphanumeric.ime_status) {
        ; ToolTip("get_na: ALPHANUMERIC")
        return 0 ; ALPHANUMERIC
    } else if (IME_GetConvMode() = l_config.native.conv_mode
        && IME_GET() = l_config.native.ime_status) {
        ; ToolTip("get_na: NATIVE")
        return 1 ; NATIVE
    }
    ; If conv_mode or ime_status do not match, return none
    ; ToolTip("get_na: no match, conv_mode: " IME_GetConvMode() ", ime_status: " IME_GET())
}

; target : 0 for ALPHANUMERIC, 1 for NATIVE, if other or not provided, it will toggle
toggle_na(target := "") {
    l_config := get_locale_config()
    if (!l_config)
        return
    na_toggle_key := l_config.na_toggle_key
    if (target = 0) {
        na_config := l_config.alphanumeric
    } else if (target = 1) {
        na_config := l_config.native
    } else {
        ; Toggle between NATIVE and ALPHANUMERIC
        ; If error, toggle to NATIVE
        toggle_na(get_na() = 1 ? 0 : 1)
        return
    }
    ToolTip(target = 0 ? "en" : "native")
    ; Try 1: set conv_mode
    IME_SetConvMode(na_config.conv_mode)
    if get_na() = target {
        ; ToolTip("Switched using conv_mode")
        SetTimer(ToolTip, -2000)
        return
    }
    ; Try 2: set ime_status
    IME_SET(na_config.ime_status)
    if get_na() = target {
        ; ToolTip("Switched using ime_status")
        SetTimer(ToolTip, -2000)
        return
    }
    ; Try 3: use switch hotkey
    if (na_config.HasOwnProp("switch_hotkey")) {
        Send(na_config.switch_hotkey)
        if get_na() = target {
            ; ToolTip("Switched using switch_hotkey")
            SetTimer(ToolTip, -2000)
            return
        }
    }
    ; Try 4: use na_toggle_key
    Send(na_toggle_key)
    if get_na() = target {
        ; ToolTip("Switched using na_toggle_key")
        SetTimer(ToolTip, -2000)
        return
    }
    ToolTip("Failed to toggle NATIVE/ALPHANUMERIC")
    SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
}


; locale_pressed: "zh_cn", "ja", etc.
switch_lang(locale_pressed, *) {
    current_hkl := Get_Keyboard_Layout()
    if (current_hkl = locales.%locale_pressed%.hkl) {
        ; If pressed same locale, toggle between NATIVE and ALPHANUMERIC
        toggle_na()
    } else {
        ; If pressed different locale, switch to that locale
        set_keyboard_layout(locales.%locale_pressed%.hkl)
        ; Toggle to NATIVE
        if (get_na() != 1) {
            toggle_na(1)
        }
        ToolTip(locale_pressed)
    }
    ; debug_status()
    SetTimer(ToolTip, -2000) ; Hide tooltip after 2 seconds
}

; Hotkeys for switching locales
for locale, data in locales.OwnProps() {
    Hotkey(data.trigger,switch_lang.Bind(locale))
}
; Hotkey for toggling NATIVE/ALPHANUMERIC
Hotkey(toggle_hotkey, (*) => toggle_na())
