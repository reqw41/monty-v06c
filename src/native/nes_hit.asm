; Столкновения с врагами как в NES ($A47D): пересечение прямоугольников из заголовков метаспрайтов.
;   Джо: левый 7305+nphys_box_left, правый 7305+nphys_box_right, верх 7304-7+nphys_box_top, низ 7304+17 (высота 24);
;   череп/паук (запись 7304+C: y, x; спрайт 16x16 с (x, y+1)): [1, 7, 15, 16] -> x+1..x+15, y+8..y+17;
;   змея (тайлы A0 A1/A2 A3, зеркально A5 A4/A7 A6; начало — левая верхняя клетка): [3, 9, 13, 16].
; Попадание (как CMP/BCS/BCC в NES): L < Джо.R, R >= Джо.L, T < Джо.B, B >= Джо.T (8-битные суммы).
; Исходник лежит в образе с F100 (нули после темы заставки), при старте переносится в NES_HIT_CODE
; (окно в бывшем загрузочном источнике, вырезано из пула сдвигов врагов вместе со вторым образом Джо).
 ORG 0xF100
 ASSERT nes_title_end <= $
nes_hit_source:
 DISP NES_HIT_CODE
hb_l: db 0
hb_r: db 0
hb_t: db 0
hb_b: db 0
; Прямоугольник Джо в hb_*.
nes_joe_box:
 ld a,(0x7305)
 ld b,a
 ld a,(nphys_box_left)
 add a,b
 ld (hb_l),a
 ld a,(nphys_box_right)
 add a,b
 ld (hb_r),a
 ld a,(0x7304)
 ld b,a
 ld a,(nphys_box_top)
 add a,b
 sub 7
 ld (hb_t),a
 ld a,b
 add a,17
 ld (hb_b),a
 ret
; D/E = левый/правый, B/C = верх/низ объекта; CY = попадание в Джо.
nes_box_hit:
 ld hl,hb_r
 ld a,d
 cp (hl)
 ret nc
 ld l,hb_l&255
 ld a,e
 cp (hl)
 jp c,nbh_miss
 ld l,hb_b&255
 ld a,b
 cp (hl)
 ret nc
 ld l,hb_t&255
 ld a,c
 cp (hl)
 ccf
 ret
nbh_miss:
 or a
 ret
; Движущийся враг: HL -> y (x следом); HL сохраняется. CY = попадание.
nes_enemy_hit:
 push hl
 push hl
 call nes_joe_box
 pop hl
 ld a,(hl)
 add a,8
 ld b,a
 add a,9
 ld c,a
 inc hl
 ld a,(hl)
 inc a
 ld d,a
 add a,14
 ld e,a
 call nes_box_hit
 pop hl
 ret
 ENT
nes_hit_source_mid:
 DISP NES_SNAKE_CODE
; Неподвижная змея. CY = попадание: (71B0) = её левая верхняя клетка. Иначе A = тайл под героем (0x7058),
; змеиный (A0..A7) заменён нулём — старой проверки по клетке под героем больше нет.
nes_snake_hit:
 ld a,(nf_snake_count)
 or a
 jp z,nsh_none
 ld hl,(nes_amulet_ticks)
 ld a,h
 or l
 jp nz,nsh_none
 call nes_joe_box
 ld a,(hb_t)
 sub 16
 add a,7
 and 0xF8                   ; первое кратное 8 начало змеи >= T-16 (низ змеи >= верх Джо)
 ld c,a
 ld e,4                     ; строк начал змеи: [T-16, B-10] — не больше 4
nsh_row:
 ld a,(hb_l)
 sub 13
 jp nc,nsh_x
 xor a
nsh_x:
 add a,7
 and 0xF8                   ; первое кратное 8 >= L-13 (правый край змеи >= левый Джо)
 ld b,a
 ld d,4                     ; столбцов: [L-13, R-4] — не больше 4
nsh_col:
 call nphys_read
 cp 0xA0
 jp z,nsh_test
 cp 0xA5
 jp nz,nsh_next
nsh_test:
 push bc
 push de
 ld a,b
 add a,3
 ld d,a
 add a,10
 ld e,a
 ld a,c
 add a,9
 ld b,a
 add a,7
 ld c,a
 call nes_box_hit
 pop de
 pop bc
 jp c,nsh_found
nsh_next:
 ld a,b
 add a,8
 ld b,a
 dec d
 jp nz,nsh_col
 ld a,c
 add a,8
 ld c,a
 dec e
 jp nz,nsh_row
nsh_none:
 ld a,(0x7058)
 cp 0xA0
 ccf
 ret nc                     ; < A0
 cp 0xA8
 ret nc                     ; >= A8 (CY = 0)
 xor a
 ret
nsh_found:
 ld a,c
 rrca
 rrca
 rrca
 and 31
 ld c,b
 ld b,a
 ld a,c
 rrca
 rrca
 rrca
 and 31
 ld c,a
 ld a,b
 call nf_row_addr
 ld (0x71B0),hl
 scf
 ret
 ENT
nes_hit_source_end:
 ASSERT NES_HIT_CODE+(nes_hit_source_mid-nes_hit_source) <= 0x38B1
 ASSERT NES_SNAKE_CODE+(nes_hit_source_end-nes_hit_source_mid) <= JOE_PICTURE2
 ASSERT $ <= 0xF200
 ASSERT (hb_l&0xFF00) == (hb_b&0xFF00)
