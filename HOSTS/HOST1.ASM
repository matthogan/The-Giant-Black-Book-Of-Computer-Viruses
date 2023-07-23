;This is a basic 32-bit PE-style Windows-95 host.

.386
.model flat

;Define the needed external functions and constants here.

extrn           ExitProcess:PROC

.data                                   ;the data area
dummy           dd      ?               ;this needs some data or it won't work!

.code                                   ;executable code starts here

HOST:
        push    LARGE -1
        call    ExitProcess             ;this simply terminates the program

        end     HOST
