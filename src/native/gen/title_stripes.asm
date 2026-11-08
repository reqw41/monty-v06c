; Warm title row inks: colour, first offset (255-last row), row count.
title_stripe_tab:
 db 6,192,64
 db 7,186,6
 db 2,182,4
 db 4,153,29
 db 5,96,57
 db 0
; Screen patches: address, byte; ends with high byte 0.
 dw 0x89B6
 db 7
 dw 0x8AB7
 db 255
 dw 0x8BB6
 db 7
 dw 0x8BB7
 db 255
 dw 0x98B6
 db 112
 dw 0x98B7
 db 48
 dw 0xA9B6
 db 0
 dw 0xAAB7
 db 0
 dw 0xABB6
 db 192
 dw 0xABB7
 db 0
 dw 0xB8B6
 db 8
 dw 0xB8B7
 db 72
 dw 0
