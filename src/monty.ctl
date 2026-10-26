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
b $8084 Встроенные параметры AE00 (за CALL 8081): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $8084,2
B $8086,2
W $8088,2
B $808A,2
W $808C,2
B $808E,2
W $8090,2
B $8092,2
W $8094,2
B $8096,2
W $8098,2
B $809A,2
W $809C,2
B $809E,2
W $80A0,2
B $80A2,2
W $80A4,2
B $80A6,2
W $80A8,2
B $80AA,2
W $80AC,2
B $80AE,2
W $80B0,2
B $80B2,2
W $80B4,2
B $80B6,2
W $80B8,2
B $80BA,2
W $80BC,2
B $80BE,2
W $80C0,2
B $80C2,2
W $80C4,2
B $80C6,2
W $80C8,2
B $80CA,2
W $80CC,2
B $80CE,2
W $80D0,2
B $80D2,2
W $80D4,2
B $80D6,2
W $80D8,2
B $80DA,2
W $80DC,2
B $80DE,2
W $80E0,2
B $80E2,2
W $80E4,2
B $80E6,2
W $80E8,2
B $80EA,2
W $80EC,2
B $80EE,2
W $80F0,2
B $80F2,2
W $80F4,2
B $80F6,2
W $80F8,2
B $80FA,2
W $80FC,2
B $80FE,2
W $8100,2
B $8102,2
W $8104,2
B $8106,2
W $8108,2
B $810A,2
W $810C,2
B $810E,2
W $8110,2
B $8112,2
B $8114,2
c $8116
b $813D Встроенные параметры AE00 (за CALL 813A): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $813D,2
B $813F,2
W $8141,2
B $8143,2
W $8145,2
B $8147,2
W $8149,2
B $814B,2
B $814D,2
c $814F
c $817C
b $81E8 Встроенные параметры AE00 (за CALL 81E5): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $81E8,2
B $81EA,2
W $81EC,2
B $81EE,2
W $81F0,2
B $81F2,2
W $81F4,2
B $81F6,2
B $81F8,2
c $81FA
b $8209 Встроенные параметры AE00 (за CALL 8206): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $8209,2
B $820B,2
W $820D,2
B $820F,2
W $8211,2
B $8213,2
W $8215,2
B $8217,2
W $8219,2
B $821B,2
W $821D,2
B $821F,2
W $8221,2
B $8223,2
B $8225,2
c $8227
b $8236 Встроенные параметры AE00 (за CALL 8233): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $8236,2
B $8238,2
W $823A,2
B $823C,2
W $823E,2
B $8240,2
W $8242,2
B $8244,2
W $8246,2
B $8248,2
W $824A,2
B $824C,2
W $824E,2
B $8250,2
B $8252,2
c $8254
b $8265 Встроенные параметры AE00 (за CALL 8262): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $8265,2
B $8267,2
W $8269,2
B $826B,2
W $826D,2
B $826F,2
W $8271,2
B $8273,2
W $8275,2
B $8277,2
B $8279,2
c $827B
b $8293
c $8308
b $830D Встроенные параметры AE00 (за CALL 830A): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $830D,2
B $830F,2
B $8311,2
c $8313
b $831A
c $8352
b $837D
c $8392
b $83A4 Встроенные параметры AE00 (за CALL 83A1): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $83A4,2
B $83A6,2
W $83A8,2
B $83AA,2
W $83AC,2
B $83AE,2
W $83B0,2
B $83B2,2
W $83B4,2
B $83B6,2
W $83B8,2
B $83BA,2
W $83BC,2
B $83BE,2
W $83C0,2
B $83C2,2
W $83C4,2
B $83C6,2
W $83C8,2
B $83CA,2
W $83CC,2
B $83CE,2
W $83D0,2
B $83D2,2
W $83D4,2
B $83D6,2
W $83D8,2
B $83DA,2
W $83DC,2
B $83DE,2
W $83E0,2
B $83E2,2
W $83E4,2
B $83E6,2
W $83E8,2
B $83EA,2
W $83EC,2
B $83EE,2
W $83F0,2
B $83F2,2
W $83F4,2
B $83F6,2
W $83F8,2
B $83FA,2
W $83FC,2
B $83FE,2
W $8400,2
B $8402,2
W $8404,2
B $8406,2
B $8408,2
c $840A
b $841E
c $88D1
b $8913
c $8929
@ $8AC9 label=LANDING
b $8CB6
c $8CC2
b $8EF5 Встроенные параметры AE00 (за CALL 8EF2): записи [адрес источника, элемент, число] для PUT_VRAM, конец — старший байт 0
W $8EF5,2
B $8EF7,2
W $8EF9,2
B $8EFB,2
W $8EFD,2
B $8EFF,2
B $8F01,2
c $8F03
@ $8F13 label=ROOM_DOWN
@ $8F04 label=ROOM_UP
@ $8EB0 label=FLOOR_PALETTE
@ $8E7E label=SAVE_RESPAWN
@ $8DFA label=ROOM_STEP_X
b $9363
c $9369
b $9378
@ $9444 label=ROOM_TS
b $9444 Номер набора тайлов по коду записи комнаты (K & 3F, 33 байта), см. tools/roomdec.py
@ $9477 label=ROOM_TAB
w $9477 Начала описаний комнат 0..98 (+ конец); описание i — от слова i до слова i+1
W $9477,200,2
@ $9541 label=ROOM_DATA
b $9541 Описания 99 комнат (потоки записей: код K и 0..3 параметра; формат — tools/roomdec.py)
b $9FC0
@ $9FD1 label=TILESETS
b $9FD1 Наборы тайлов для записей комнат: T(0) — ширина/признак, T(1..) — номера тайлов
@ $A067 label=DRAW_ROOM
c $A067 Рисует комнату: очистка (A1DF), номер (A4B5) -> 7015, поток описания (A4CE), объекты, инвентарь (A548). Повтор на Python: tools/roomdec.py, сверено со всеми 297 комнатами
@ $A1DF label=CLEAR_ROOM
b $A20A
@ $A21A label=ROOM_RECT
c $A21A Примитивы записей комнаты (таблица A20A): прямоугольник; A27C треугольник, A2F0 столбец, A318 полоса, A30E столбец с шапкой, A340 узор
@ $A405 label=ROOM_ENEMY
@ $A3AB label=ROOM_DOOR
@ $A36A label=ROOM_ITEM
@ $A496 label=ENEMY_Y
b $A496 Враги (A405): Y по младшей тетраде p1, затем X по старшей (A4A5)
@ $A4B5 label=ROOM_INDEX
c $A4B5 A := ROW_BASE[ряд 71A7] + столбец 71A8
@ $A4C5 label=ROW_BASE
b $A4C5 Номер первой комнаты ряда минус столбец: комната = [ряд] + столбец (A4B5)
@ $A4CE label=ROOM_PTRS
c $A4CE 7190/7192 := начало и конец описания A (71A5 := A)
@ $A548 label=DRAW_INVENTORY
@ $A514 label=OBJ_TAKEN
b $A8A1
c $A8B7
b $A92E
c $A92F
b $A9AD
c $A9B3
b $AA88
c $AA96
@ $AB0C label=MIRROR_PAIRS
b $AB0C Пары тайлов для зеркалирования (исходный, зеркальный), конец FF
@ $AB29 label=MIRROR_ROOM
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
@ $AEA7 label=PUT_BLOCK
c $AEA7 B строк по C тайлов из HL в таблицу имён с клетки DE; 7000 бит 2 — шаг строки 32 (иначе C), бит 3 — HL+1 на строку, бит 4 — чтение
b $AFFF
i $10000
