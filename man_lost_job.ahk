; SendMode Play
SetKeyDelay, 100, 50
; buy 3
^3::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Right}{Down}{Enter}{Enter}
    ; Go to buy
    Sleep 500
    Send {Down}{Enter}
    Sleep 500
    Send {Down 2}{Enter 4}
    Sleep 500
    ; Select using the money
    Send {Down}{Enter 4}
    Sleep 500
    Send {Enter 2}
    Sleep 500
    ; Select buy
    Send {Enter}
    Sleep 500
    Send {Enter}{Down 2}{Enter}
    Sleep 500
    Send {Up 11}{Enter}{Esc 2}

return

; buy 2
^2::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Right}{Down}{Enter}{Enter}
    ; Go to buy
    Sleep 500
    Send {Down}{Enter}
    Sleep 500
    Send {Down 2}{Enter 4}
    Sleep 500
    ; Select using the money
    Send {Down}{Enter 4}
    Sleep 500
    Send {Enter 2}
    Sleep 500
    ; Select buy
    Send {Enter}
    Sleep 500
    Send {Enter}{Down}{Enter}
    Sleep 500
    Send {Up 11}{Enter}{Esc 2}

return

; buy 1
^1::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Right}{Down}{Enter}{Enter}
    ; Go to buy
    Sleep 500
    Send {Down}{Enter}
    Sleep 500
    Send {Down 2}{Enter 4}
    Sleep 500
    ; Select using the money
    Send {Down}{Enter 4}
    Sleep 500
    Send {Enter 2}
    Sleep 500
    ; Select buy
    Send {Enter}
    Sleep 500
    Send {Enter}{Enter}
    Sleep 500
    Send {Up 11}{Enter}{Esc 2}

return

; sell
^q::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Right}{Down}{Enter}{Enter}
    ; Go to buy
    Sleep 500
    Send {Down}{Enter}
    Sleep 500
    Send {Down 2}{Enter 4}
    Sleep 500
    ; Select using the money
    Send {Down}{Enter 4}
    Sleep 500
    Send {Enter 2}
    Sleep 500
    ; Select sell
    Send {Down}{Enter}
    ; Sleep 500
    ; Send {Enter}
return

; catch bug
^0::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}{Up 5}{Left}
    ; Select net
    Send {Right}{Down 2}{Enter}{Enter}
return

; go live
^5::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Right}{Down}{Enter}{Enter}
    ; Go to live
    Sleep 500
    Send {Down 3}{Enter 4}

    Sleep 500
    Send {Enter}

; go stock
^e::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}
    ; Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Enter}{Enter}
    ; Send {Right}{Down}{Enter}{Enter}
    ; Go to live
    Sleep 500
    Send {Enter 10}
    Sleep 500
    Send {Enter 2}
    Sleep 500
    Send {Up 2}{Enter 3}

return

; repeat using
^r::
    ; Menu
    Send {Esc}{Enter}
    ; Important items, reset to top left
    Send {Right 3}{Enter}
    ; Send {Right 3}{Enter}{Up 5}{Left}
    ; Select phone
    Send {Enter 2}
    Sleep 2500
    Send {Enter 4}


return