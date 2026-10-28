; Переменные нативной сборки (из src/vec/vars.asm без того, что нужно только src/vec)
; --- переменные платформы ---------------------------------------------------------------------------------
pvars:
frames:		ds	2
isr_sp:		ds	2
nmi_pend:	ds	1
video_dirty:		ds	1
nt_age:		ds	1
video_enabled:	ds	1
video_edit:	ds	1
fire_frame:	ds	1
belt_frame:	ds	1
belt_shown:	ds	1
pal_load:	ds	1
fire_shown:	ds	1
 IFDEF NES_FULL
snake_frame:	ds	1
snake_shown:	ds	1
snake_tick:	ds	1
 ENDIF
kbmat:		ds	8
row_dirty:	ds	SCREEN_ROWS
drew_any:	ds	1
shown_colors:	ds	32
 IFNDEF NES_STYLE
used:		ds	16
 ENDIF
repl:		ds	16
cmap:		ds	16
pal:		ds	16
rr_r:		ds	1
rr_c:		ds	1
rr_t:		ds	1
spr_force:	ds	1
spx_ch:		ds	1
spx_a:		ds	2
sp_mpage:	ds	1
dr_ex:		ds	1
dr_skip:	ds	1
ex_n:		ds	1
ex_r:		ds	4*SPR_MAX
ex_any:		ds	1
crit_pend:	ds	1
cr_units:	ds	1
cr_read:	ds	2
np_sp:		ds	2
bk_c:		ds	1
nf_val:		ds	1
fire_next:		ds	1
spr_E:		ds	1
cr_ptr:		ds	2
cr_list:	ds	3*2*SPR_MAX+1
cr_r:		ds	1
cr_r1:		ds	1
cr_c0:		ds	1
cr_c1:		ds	1
sv_lo:		ds	1
sv_col:		ds	1
sp_k:		ds	1
st_rows:	ds	1
sv_zc:		ds	1
cl_n:		ds	1
tr_z0:		ds	1
tr_z2:		ds	1
tr_last:	ds	1
sm_off:		ds	1
sp_y:		ds	1
sp_x:		ds	1
sp_name:	ds	1
sp_ci:		ds	1
sp_line:	ds	1
 IFDEF STRICT
sn_latch:	ds	1
sn_chg:		ds	1
sn_per:		ds	8
sn_att:		ds	4
 ENDIF
obj_end:	ds	1
tile_phase:	ds	1
tile_i:		ds	1
tile_frames:	ds	1
tile_count:	ds	1
fl_source:	ds	2
tile_src:	ds	2
tile_dst:	ds	2
group_modes:	ds	32
enemy_turn:	ds	1
sprite_dirty:	ds	1
fire_ran:	ds	1
en_reuse:	ds	1
en_zero:	ds	1
en_stride:	ds	1
en_mask:	ds	1
band_candidate:	ds	1
band_pair_n:	ds	1
band_valid:	ds	1
band_ok:	ds	1
		ALIGN	8
band_order:	ds	SPR_MAX
 IFDEF NES_FULL
hud_dirty: ds 1
nf_room_row: ds 1
nf_room_col: ds 1
nf_visibility: ds 1
nf_flags: ds 1
nf_kind: ds 1
nf_enemy: ds 1
nf_snake_count: ds 1
nf_snake_offsets: ds 8		; four 2x2 snakes, VNT offsets
nf_left: ds 2
nf_bitbyte: ds 1
nf_bitcount: ds 1
nf_distance: ds 2
nf_dist_hi: ds 1
 ENDIF
pvars_end:
tabs_end:
; spr_rec, spr_new — на странице 6600, grp — в странице sprt (game.asm)

