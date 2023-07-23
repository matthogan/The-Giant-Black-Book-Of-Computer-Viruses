Module1          db 'KERNEL32.DLL',0
                 db 'WinExec',0
                 db 'FindFirstFileA',0
                 db 'FindNextFileA',0
                 db 'CreateFileA',0
                 db '_lclose',0
                 db 'SetFilePointer',0
                 db 'ReadFile',0
                 db 'WriteFile',0
                 db 'GetCurrentDirectoryA',0
                 db 'SetCurrentDirectoryA',0
                 db 'GetLocalTime',0
                 db 'FindClose',0
                 db 'GetModuleHandleA',0
                 db 'GetProcAddress',0
                 db 0
Module2          db 'USER32.DLL',0
                 db 'MessageBeep',0
                 db 'GetAsyncKeyState',0
                 db 0,0
