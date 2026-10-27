-- Headless independent reference. First capture a normal game, then execute
-- isolated original ROM routines on MAME's CPU, with NMI/rendering disabled.
local out=assert(os.getenv('NES_CAPTURE_DIR'))
local device=manager.machine.devices[':maincpu']
local cpu=device.spaces.program
local ppu=manager.machine.devices[':ppu'].spaces.videoram
local pad=manager.machine.ioport.ports[':ctrl1:joypad:JOYPAD'].fields
local trace=assert(io.open(out..'/timing.tsv','w'))
trace:write('frame\troom\tstage\tfire_lower\tfire_upper\tgame_frame\n')
local n=0
local baseline=nil
local idx,step,waiting,waited=0,1,false,0
local routines={0xbaff,0xbd6a,0xbe5e,0xbe8c,0x92b1,0xac9a,0xaceb,0xac54}
local function dump(name)
 local f=assert(io.open(out..'/'..name..'.ram','wb'));f:write(cpu:read_range(0,0x7ff,8));f:close()
 f=assert(io.open(out..'/'..name..'.ppu','wb'));f:write(ppu:read_range(0,0x3fff,8));f:close()
end
local function call(pc)
 cpu:write_direct_u8(0xc584,pc&255)
 cpu:write_direct_u8(0xc585,pc>>8)
 cpu:write_u8(2,0)
end
emu.register_frame_done(function()
 n=n+1
 if n<120 then
 trace:write(string.format('%d\t%d\t%d\t%d\t%d\t%d\n',n,cpu:read_u8(0x79b),cpu:read_u8(0x7f7),cpu:read_u8(0x638),cpu:read_u8(0x649),cpu:read_u8(0xa6)))
 pad['P1 Start']:set_value(n==30 and 1 or 0)
 if n==90 then dump('start');baseline=cpu:read_range(0,0x7ff,8) end
 return
 end
 if idx>=99 then
  local f=assert(io.open(out..'/capture-complete.json','w'));f:write('{"rooms":99,"normal_game_snapshots":1}\n');f:close()
  trace:close();manager.machine:exit();return
 end
 if waiting then
  local pc=device.state['PC'].value
  if pc~=0xc57f and pc~=0xc581 then
   waited=waited+1
   if waited>30 then print('CAPTURE ERROR PC',string.format('%04x',pc));trace:close();manager.machine:exit() end
   return
  end
  waiting=false;step=step+1
 end
 if step>8 then
  dump(string.format('room_%02d',idx))
  if idx%20==0 then print('CAPTURE ROOM',idx) end
  idx=idx+1;step=1
  return
 end
 if step==1 then
  cpu:write_u8(0x2000,0);cpu:write_u8(0x2001,0)
  if idx==0 then
   -- In-memory main-loop harness. No changes to the ROM file or asset routines.
   local wrapper={0xa5,2,0xd0,0xfc,0x20,0xff,0xba,0xa9,1,0x85,2,0x4c,0x7f,0xc5}
   for i,v in ipairs(wrapper) do cpu:write_direct_u8(0xc57e+i,v) end
   assert(cpu:read_u8(0xc57f)==0xa5,'MAME direct ROM write unavailable')
  end
  for i=0,0x7ff do cpu:write_u8(i,baseline:byte(i+1)) end
  cpu:write_u8(0x79b,idx);cpu:write_u8(0x79a,math.floor(math.sqrt(idx+1)))
  cpu:write_u8(0x799,0);cpu:write_u8(0x7c0,9);cpu:write_u8(0xf3,0);cpu:write_u8(0x7fd,255)
  for i=0xd3,0xd7 do cpu:write_u8(i,0) end
 end
 if step==3 then cpu:write_u8(5,cpu:read_u8(0x79c));cpu:write_u8(6,cpu:read_u8(0x79d)) end
 call(routines[step]);waiting=true;waited=0
end)
