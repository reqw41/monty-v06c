; Переменные нативной сборки (из src/vec/vars.asm без того, что нужно только src/vec)
; --- переменные платформы ---------------------------------------------------------------------------------
pvars:
frames:		ds	2
isr_sp:		ds	2
nmi_pend:	ds	1
vdirty:		ds	1
nt_age:		ds	1
vregs:		ds	8
pal_load:	ds	1
tile_hi:	ds	1
kbmat:		ds	8
row_dirty:	ds	24
drew_any:	ds	1
dc_m:		ds	1
col_shown:	ds	32
used:		ds	16
repl:		ds	16
cmap:		ds	16
pal:		ds	16
rr_r:		ds	1
rr_c:		ds	1
rr_nt:		ds	2
rr_t:		ds	1
rr_m:		ds	6
rr_p:		ds	1
rr_np:		ds	1
rr_y:		ds	1
spr_force:	ds	1
spx_ch:		ds	1
spx_a:		ds	2
sp_mpage:	ds	1
dr_ex:		ds	1
dr_skip:	ds	1
ex_n:		ds	1
ex_r:		ds	4*SPR_MAX
		IFNDEF	NATIVE
		ENDIF
		IFNDEF	NATIVE
svr:		ds	4*SPR_MAX
		ENDIF
pm_bot:		ds	1
		IFNDEF	NATIVE
rst:		ds	6*SPR_MAX
		ENDIF
		IFNDEF	NATIVE
pps:		ds	6*SPR_MAX
		ENDIF
		IFNDEF	NATIVE
pps2:		ds	2*SPR_MAX
		ENDIF
		IFNDEF	NATIVE
ppd:		ds	11*SPR_MAX
		ENDIF
rs_h:		ds	2
rs_n:		ds	1
pu_lo:		ds	1
ex_any:		ds	1
crit_pend:	ds	1
np_sp:		ds	2
bk_c:		ds	1
nf_val:		ds	1
disp_n:		ds	1
dp_done:	ds	1
bk_new:		ds	1
spr_E:		ds	1
sp_sp:		ds	1
		IFNDEF	NATIVE
gact:		ds	SPR_MAX
		ENDIF
		IFNDEF	NATIVE
gs:		ds	SPR_MAX
		ENDIF
		IFNDEF	NATIVE
ge:		ds	SPR_MAX
		ENDIF
		IFNDEF	NATIVE
gd:		ds	SPR_MAX
		ENDIF
pp_h:		ds	2
pp_m:		ds	2
cr_ptr:		ds	2
cr_list:	ds	3*2*SPR_MAX+1
cr_r:		ds	1
cr_r1:		ds	1
cr_c0:		ds	1
cr_c1:		ds	1
sv_lo:		ds	1
sv_col:		ds	1
sp_k:		ds	1
sp_cbits:	ds	1
st_rows:	ds	1
st_kind:	ds	1
sv_zc:		ds	1
cl_n:		ds	1
se_y:		ds	1
se_r1:		ds	1
tr_z0:		ds	1
tr_z2:		ds	1
tr_last:	ds	1
sm_off:		ds	1
sp_y:		ds	1
sp_x:		ds	1
sp_name:	ds	1
sp_ci:		ds	1
sp_line:	ds	1
sn_latch:	ds	1
sn_chg:		ds	1
sn_per:		ds	8
sn_att:		ds	4
pvars_end:
dc_sp:		ds	2
tabs_end:
; spr_rec, spr_new — на странице 6600, grp — в странице sprt (game.asm)

