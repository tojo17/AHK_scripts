toggle = 0
#MaxThreadsPerHotkey 2

F8::
    Toggle := !Toggle
    While Toggle{
        Click
        sleep 30
    }
return