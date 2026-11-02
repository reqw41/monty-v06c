// Сколько готовых сдвигов врагов помещается в пул: перехват nes_ps_alloc. node tools/bench/ps-alloc.js build/<каталог>
process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.argv[2]||'build/quick';const s=symbols(B);const m=E.mk(B+'/monty.bin');
const req=[];let pend=null,retpc=0;
m.onInstr=pc=>{
 if(pc===s.nes_ps_alloc){pend={size:m.cpu.regs[7]};const sp=m.cpu.sp;retpc=m.rd(sp)|m.rd(sp+1)<<8;}
 else if(pend&&pc===retpc){pend.ok=!!(m.rd(s.np_best)|m.rd(s.np_best+1));pend.at=(m.rd(s.np_begin)|m.rd(s.np_begin+1)<<8).toString(16);req.push(pend);pend=null;}
};
for(let f=0;f<400;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const ok=req.filter(r=>r.ok),bad=req.filter(r=>!r.ok);
console.log(B,'запросов',req.length,'успешно',ok.length,'байт',ok.reduce((a,r)=>a+r.size,0),'| не влезло',bad.length,'байт',bad.reduce((a,r)=>a+r.size,0));
console.log('размеры не влезших',bad.map(r=>r.size).join(','));
// свободное в страницах
let a=s.nes_ps_pages,free=0,ranges=[];while(a<s.nes_ps_pages_end){const b=m.rd(a)|m.rd(a+1)<<8,e=m.rd(a+2)|m.rd(a+3)<<8;if(e>b){free+=e-b;ranges.push(b.toString(16)+'+'+(e-b));}a+=4;}
console.log('осталось свободно в пуле',free,ranges.join(' '));
