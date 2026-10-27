-- Independent isolated MAME reference; original driver/CHR data remain unchanged.
-- A RAM mailbox calls one original sound step per frame, with NMI disabled.
local out=assert(os.getenv('NES_MUSIC_DIR'))
local entry=tonumber(assert(os.getenv('NES_MUSIC_ENTRY')))
local kind=os.getenv('NES_MUSIC_KIND') or 'music'
local effect=tonumber(os.getenv('NES_MUSIC_EFFECT') or '0')
local limit=tonumber(assert(os.getenv('NES_MUSIC_TICKS')))
local machine=manager.machine
local cpu=machine.devices[':maincpu'].spaces.program
local installed,initialised=false,false
local tick=-1
local file=assert(io.open(out..'/apu.tsv','w'));file:write('frame\taddress\tvalue\n')
_G.music_taps={cpu:install_write_tap(0x4000,0x4017,'music_apu',function(a,d,m)
 if tick>=0 and tick<limit and a~=0x4014 and a~=0x4016 then file:write(string.format('%d\t%d\t%d\n',tick,a,d)) end
end)}
local function put(address,code)
 for i,v in ipairs(code) do cpu:write_direct_u8(address+i-1,v) end
end
local function call(address)
 cpu:write_direct_u8(0xc584,address&255);cpu:write_direct_u8(0xc585,address>>8);cpu:write_u8(2,0)
end
emu.register_frame_done(function()
 if not installed then
  cpu:write_u8(0x2000,0);cpu:write_u8(0x2001,0)
  cpu:write_direct_u8(0xc594,0x40) -- RTI: a pending old NMI cannot re-enable itself
  -- Reuse the mailbox harness from the independently checked room exporter.
  put(0xc57f,{0xa5,2,0xd0,0xfc,0x20,0,0xe8,0xa9,1,0x85,2,0x4c,0x7f,0xc5})
  if kind=='music' then
   put(0xe800,{0x20,0x88,0x85,0x4c,entry&255,entry>>8})
  else
   local target=kind=='pulse' and 0x8600 or kind=='noise' and 0x85f7 or 0x860e
   put(0xe800,{0x20,0x88,0x85,0x20,0x3a,0x86,0x20,0xee,0x85,0xa9,1,0x8d,0xd4,7,0xa9,effect,0x4c,target&255,target>>8})
  end
  put(0xe860,{0xa9,0,0x8d,0xef,7,0x20,0xf6,0x83,0x4c,0x40,0xe8})
  put(0xe840,{0x20,0x2d,0x87,0x4c,0xc6,0x86})
  for address=0x7cf,0x7fc do cpu:write_u8(address,0) end
  cpu:write_u8(0,0);cpu:write_u8(0x7fd,255)
  call(0xe800);installed=true;return
 end
 if cpu:read_u8(2)~=1 then return end
 if initialised then tick=tick+1 else initialised=true;tick=0 end
 if tick>=limit then
  file:close();local marker=assert(io.open(out..'/complete.json','w'))
  marker:write(string.format('{"ticks":%d,"frame_period":%.12f}\n',tick,machine.screens[':screen'].frame_period));marker:close();machine:exit();return
 end
 if kind=='pole' and tick<64 then cpu:write_u8(0x16,64+tick*2) end
 call(kind=='pole' and tick==64 and 0xe860 or 0xe840)
end)
