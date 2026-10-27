-- Observe normal MAME gameplay. No ROM, game-RAM, pose, or OAM injection.
-- Inputs come from plan.input intervals and documented controller-only route guards.
-- Every tap observes memory; none changes ROM, RAM, PPU or OAM.
local out=assert(os.getenv('NES_LIVE_DIR'))
local plan=dofile(assert(os.getenv('NES_LIVE_PLAN')))
local cpu=manager.machine.devices[':maincpu'].spaces.program
local ppu=manager.machine.devices[':ppu'].spaces.videoram
local screen=manager.machine.screens[':screen']
local pad=manager.machine.ioport.ports[':ctrl1:joypad:JOYPAD'].fields
local frame,latest,presented,mask=0,nil,nil,0
local last_spawn_frame=-1
local samples={}
local previous_y=nil
local counts={timer=0,spawn=0}
local events=assert(io.open(out..'/events.tsv','w'))
events:write('frame\tevent\tpc\tvalue\ttimer_calls\n')
local function word(a) return cpu:read_u8(a)|(cpu:read_u8(a+1)<<8) end
local group_tables={joe={0xd738,12},snake={0xd77c,1},skull={0xd868,1},spider={0xd908,1},bat={0xd990,1}}
local known={}
for group,definition in pairs(group_tables) do
 known[group]={}
 for state=0,definition[2]-1 do
  local animation=word(definition[1]+state*2)
  known[group][state]={}
  for phase=0,cpu:read_u8(animation)-1 do known[group][state][word(animation+6+phase*2)]=phase end
 end
end
local function write(name,data)
 local f=assert(io.open(out..'/'..name,'wb'));f:write(data);f:close()
end
local function b(r,a) return r:byte(a+1) end
_G.nes_live_taps={
 cpu:install_write_tap(0x4014,0x4014,'nes_live_dma',function(address,data,mem_mask)
  latest={mask=mask,oam=cpu:read_range(data*256,data*256+255,8),ram=cpu:read_range(0,0x7ff,8),ppu=ppu:read_range(0,0x3fff,8)}
 end),
 -- Capture PPU after all NMI writes, not before the DMA (palette cycles).
 cpu:install_read_tap(0xc597,0xc597,'nes_live_nmi_end',function(address,data,mem_mask)
  if latest then latest.ppu=ppu:read_range(0,0x3fff,8) end
 end),
 cpu:install_write_tap(0x2001,0x2001,'nes_live_mask',function(address,data,mem_mask) mask=data end),
 cpu:install_write_tap(0x7c4,0x7c4,'nes_live_timer_calls',function(address,data,mem_mask)
  local old=cpu:read_u8(address)
  local pc=manager.machine.devices[':maincpu'].state['PC'].value
  if data~=old and data==((old-1)&255) and pc==0xbc30 then counts.timer=counts.timer+1
  elseif data~=old then events:write(string.format('%d\treset_C4\t%04X\t%d\t%d\n',frame,pc,data,counts.timer)) end
 end),
 cpu:install_read_tap(0xb1ff,0xb1ff,'nes_live_spawn_calls',function(address,data,mem_mask) if manager.machine.devices[':maincpu'].state['PC'].value==0xb1ff and last_spawn_frame~=frame then counts.spawn=counts.spawn+1;last_spawn_frame=frame;events:write(string.format('%d\tspawn\tB1FF\t0\t%d\n',frame,counts.timer)) end end)
}
local trace=assert(io.open(out..'/trace.tsv','w'))
trace:write('frame\tscene\troom\tfloor\tx\ty\tstate\tnext_phase\tdirection\tmeta\t0790\t079E\t07C4\t07C5\t07CA\ttimer_calls\tspawn_calls\tinput\n')
local index=assert(io.open(out..'/captures.tsv','w'))
index:write('frame\tbase\tmask\treasons\n')
local function actor_key(r,slot)
 if b(r,0x76+slot)==255 or b(r,0x7c+slot)==0 then return nil end
 local ptr=b(r,0x2e+slot)|(b(r,0x34+slot)<<8)
 local state=b(r,0x1c+slot)
 local group=nil;local phase=nil
 if slot==0 then
  for selected,frames in pairs(known.joe) do
   if frames[ptr]~=nil then group='joe';state=selected;phase=frames[ptr];break end
  end
 else
  for _,name in ipairs({'snake','skull','spider','bat'}) do
   local p=known[name][0][ptr]
   if p~=nil then group=name;phase=p;state=0;break end
  end
 end
 if phase==nil then return nil end
 return string.format('%s:%02X:%d:%d',group,state,phase,b(r,0x40+slot)==1 and 1 or 2)
end
emu.register_frame_done(function()
 frame=frame+1
 -- frame_done exposes the next vblank DMA; the bitmap displays the prior DMA.
 local visible=presented;presented=latest
 if frame==1 then
  for tag,palette in pairs(manager.machine.palettes) do
   local values={}
   for i=0,palette.entries-1 do values[#values+1]=tostring(palette:pen_color(i)) end
   write('palette.json','['..table.concat(values,',')..']\n')
   print('PALETTE',tag,palette.entries)
   break
  end
 end
 local keys={}
 for _,segment in ipairs(plan.input) do
  if frame>=segment[1] and frame<segment[2] then for _,key in ipairs(segment[3]) do keys[key]=true end end
 end
 local room=cpu:read_u8(0x79b);local hero_x=cpu:read_u8(0x10)
 if plan.safe_laser and room==10 and hero_x>=168 and hero_x<=180 and cpu:read_u8(0x794)~=0 then keys.Right=nil end
 if plan.sword and room==10 and hero_x>=130 and hero_x<=132 and cpu:read_u8(0x16)==87 then keys.A=true end
 if plan.pole and room==12 and hero_x>=56 and hero_x<=58 and cpu:read_u8(0x16)==87 then keys.A=true end
 local input={}
 for _,name in ipairs({'Start','Left','Right','Up','Down','A','B'}) do
  pad['P1 '..name]:set_value(keys[name] and 1 or 0)
  if keys[name] then input[#input+1]=name end
 end
 local ptr=cpu:read_u8(0x2e)|(cpu:read_u8(0x34)<<8)
 trace:write(string.format('%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\n',frame,cpu:read_u8(0x7c9),cpu:read_u8(0x79b),cpu:read_u8(0x79a),cpu:read_u8(0x10),cpu:read_u8(0x16),cpu:read_u8(0x1c),cpu:read_u8(0x58),cpu:read_u8(0x40),ptr,cpu:read_u8(0x790),cpu:read_u8(0x79e),cpu:read_u8(0x7c4),cpu:read_u8(0x7c5),cpu:read_u8(0x7ca),counts.timer,counts.spawn,table.concat(input,',')))
 if visible and b(visible.ram,0x7c9)==1 and (visible.mask&0x10)~=0 then
  local reasons={}
  for slot=0,5 do
   local key=actor_key(visible.ram,slot)
   if key then
    local s=samples[key] or {n=0,last=-10}
    if s.n<3 and frame-s.last>=2 then
     reasons[#reasons+1]=key;s.n=s.n+1;s.last=frame;samples[key]=s
    end
   end
  end
  local r=visible.ram;local state=b(r,0x1c);local y=b(r,0x16)
  if plan.flight and (state==3 or ((state==0 or state==1) and previous_y and y~=previous_y)) then reasons[#reasons+1]='flight' end
  previous_y=y
  if #reasons>0 then
   local base=string.format('frame_%05d',frame)
   write(base..'.ram',r);write(base..'.oam',visible.oam);write(base..'.ppu',visible.ppu);write(base..'.shadow',cpu:read_range(0x200,0x2ff,8))
   local err=screen:snapshot(out..'/'..base..'.png');assert(not err,tostring(err))
   local pixels,w,h=screen:pixels();write(base..'.pixels',pixels)
   index:write(string.format('%d\t%s\t%d\t%s\n',frame,base,visible.mask,table.concat(reasons,',')))
  end
 end
 if frame>=plan.frames then
  trace:close();index:close();events:close()
  write('complete.json',string.format('{"frames":%d,"timer_calls":%d,"spawn_calls":%d,"frame_period":%.12f}\n',frame,counts.timer,counts.spawn,screen.frame_period))
  manager.machine:exit()
 end
end)
