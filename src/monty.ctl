@ $0000 org
@ $0000 start
@ $0000 label=START
c $0000 RST 0 OS7: стек 73B9, далее BOOT
b $0006
c $0008
b $000B
c $0010
b $0013
c $0018
b $001B
c $0020
b $0023
c $0028
b $002B
c $0030
b $0033
@ $0038 label=IRQ
c $0038 IM1 MSX: на обработчик прерывания прослойки (у Coleco здесь NMI 0066 от VDP)
b $003B
@ $0066 label=NMI
c $0066 NMI OS7 — туда же
b $0069
@ $006E label=BOOT
c $006E BOOT OS7: сигнатура 55AA в 8000 -> старт картриджа по (800A), иначе заставка BIOS. В картридже 4C4C, но прослойка идёт в 8025 сама (2000)
b $0098
c $00A3
b $00AA
c $00AB
b $00FC
c $023B
b $0240
c $0FEE
b $1001
c $1002
b $103E
c $105A
b $10BB
c $1105
b $113B
c $1319
b $143B
c $159D
b $178E
c $1790
b $1890
c $1891
b $1979
c $1B1D
b $1B76
c $1BA3
b $1BFF
c $1C27
b $1C56
c $1C66
b $1C72
c $1C82
b $1CB6
c $1CCA
b $1CE5
c $1D01
b $1D22
c $1D3E
b $1D66
c $1D6C
b $1DE5
c $1E07
b $1F12
c $1F4E
b $1F5D
c $1F61 Таблица переходов BIOS OS7 ColecoVision (имена — по общедоступному списку точек входа OS7, PLAY_SONGS? не проверено; DECODER 1F79 перенаправлен Muffie на опрос клавиатуры MSX 2011)
@ $1F61 label=PLAY_SONGS
@ $1F64 label=ACTIVATEP
@ $1F67 label=PUTOBJP
@ $1F6A label=REFLECT_VERTICAL
@ $1F6D label=REFLECT_HORIZONTAL
@ $1F70 label=ROTATE_90
@ $1F73 label=ENLARGE
@ $1F76 label=CONTROLLER_SCAN
@ $1F79 label=DECODER
@ $1F7C label=GAME_OPT
@ $1F7F label=LOAD_ASCII
@ $1F82 label=FILL_VRAM
@ $1F85 label=MODE_1
@ $1F88 label=UPDATE_SPINNER
@ $1F8B label=INIT_TABLEP
@ $1F8E label=GET_VRAMP
@ $1F91 label=PUT_VRAMP
@ $1F94 label=INIT_SPR_ORDERP
@ $1F97 label=WR_SPR_NM_TBLP
@ $1F9A label=INIT_TIMERP
@ $1F9D label=FREE_SIGNALP
@ $1FA0 label=REQUEST_SIGNALP
@ $1FA3 label=TEST_SIGNALP
@ $1FA6 label=WRITE_REGISTERP
@ $1FA9 label=WRITE_VRAMP
@ $1FAC label=READ_VRAMP
@ $1FAF label=INIT_WRITERP
@ $1FB2 label=SOUND_INITP
@ $1FB5 label=PLAY_ITP
@ $1FB8 label=INIT_TABLE
@ $1FBB label=GET_VRAM
@ $1FBE label=PUT_VRAM
@ $1FC1 label=INIT_SPR_ORDER
@ $1FC4 label=WR_SPR_NM_TBL
@ $1FC7 label=INIT_TIMER
@ $1FCA label=FREE_SIGNAL
@ $1FCD label=REQUEST_SIGNAL
@ $1FD0 label=TEST_SIGNAL
@ $1FD3 label=TIME_MGR
@ $1FD6 label=TURN_OFF_SOUND
@ $1FD9 label=WRITE_REGISTER
@ $1FDC label=READ_REGISTER
@ $1FDF label=WRITE_VRAM
@ $1FE2 label=READ_VRAM
@ $1FE5 label=INIT_WRITER
@ $1FE8 label=WRITER
@ $1FEB label=POLLER
@ $1FEE label=SOUND_INIT
@ $1FF1 label=PLAY_IT
@ $1FF4 label=SOUND_MAN
@ $1FF7 label=ACTIVATE
@ $1FFA label=PUTOBJ
@ $1FFD label=RAND_GEN
@ $2000 label=MSX_ENTRY
c $2000 Вход из ПЗУ (66A8) после копирования 400A-65B8 -> 0000: A8 := DF (ОЗУ в страницах 0,1,3; картридж в 2) и переход к старту картриджа Coleco
b $20F7
@ $2011 label=MSX_DECODER
c $2011 DECODER OS7 (1F79) для MSX: опрос матрицы клавиатуры (AA/A9) вместо пульта Coleco
@ $20C6 label=MSX_IRQ
c $20C6 Обработчик прерывания кадра MSX (вместо NMI VDP у Coleco)
c $20FB
b $21E9
c $21F2
b $2205
c $2209
b $22C6
@ $8000 label=CART
b $8000 Заголовок картриджа ColecoVision (игра 8000-BFFF, 16 КБ)
B $8000,2 сигнатура: у Coleco AA55 (заставка BIOS) или 55AA (без неё), здесь 4C4C
W $8002,8,2 указатели в ОЗУ Coleco: таблица спрайтов 7300, порядок спрайтов 72E0, буфер 7210, карта контроллеров 7005
W $800A,2 старт игры 8025
c $800C Векторы RST 08-30 и прерывания картриджа (800C...8024)
c $800C
b $800D
c $800F
b $8010
c $8012
b $8013
c $8015
b $8016
c $8018
b $8019
c $801B
b $801C
c $801D
b $8020
c $8021
b $8024
@ $8025 label=GAME_START
c $8025
b $810A
c $8116
b $816D
c $816F
b $8179
c $817B
b $820B
c $8227
b $8293
c $8308
b $831A
c $8352
b $837D
c $8392
b $83FC
c $8406
b $841E
c $88D1
b $8913
c $8929
b $8CB6
c $8CC2
b $9207
c $9208
b $9363
c $9369
b $9378
c $A067
b $A20A
c $A21A
b $A496
c $A4B5
b $A4C5
c $A4CE
b $A8A1
c $A8B7
b $A92E
c $A92F
b $A9AD
c $A9B3
b $AA88
c $AA96
b $AB0C
c $AB21
b $ABB3
c $ABED
b $AD0B
c $AE00
b $AE2D
c $AE2E
b $AE38
c $AE3A
b $AE94
c $AEA7
b $AFFF
i $10000
