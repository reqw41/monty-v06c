/* Browser UI; the sound is synthesized from original APU writes, not an audio file.
 * AudioWorklet keeps timers/LFSR running across musical loops. No third-party code.
 */
'use strict';
(async function startMontyPlayer() {
  const data=globalThis.MONTY_NES_MUSIC, $=id => document.getElementById(id);
  let selected=0,context=null,node=null,gain=null,analyser=null,playing=false,paused=false;
  const mask=() => [...document.querySelectorAll('[data-channel]')].map(c => c.checked);
  const time=seconds => `${Math.floor(seconds/60)}:${String(Math.floor(seconds%60)).padStart(2,'0')}`;
  const duration=track => track.kind==='sfx' ? (track.periodFrames*data.framePeriod).toFixed(2).replace('.',',')+' с' : time(track.periodFrames*data.framePeriod);
  const error=e => { $('error').textContent=String(e.message||e); $('status').textContent='Не удалось воспроизвести'; };
  function updateTrack() {
    $('title').textContent=data.tracks[selected].title; $('length').textContent=duration(data.tracks[selected]);
    document.querySelectorAll('.track').forEach((button,i) => { button.classList.toggle('selected',i===selected);button.setAttribute('aria-pressed',String(i===selected)); });
    $('loop').checked=data.tracks[selected].kind==='music';
  }
  async function setup() {
    if (context) return;
    if (!globalThis.AudioContext || !globalThis.AudioWorkletNode) throw Error('Нужен браузер с Web Audio и AudioWorklet (например, Chrome).');
    const ctx=new AudioContext();context=ctx;
    await ctx.resume();
    const code=`const api=(${MontyAPUFactory.toString()})();
      class MontyProcessor extends AudioWorkletProcessor {
        constructor(){super();this.player=null;this.notice=0;this.reported=false;
          this.port.onmessage=({data:m})=>{
            if(m.type==='load'){this.player=new api.EventPlayer(m.track,sampleRate,m.framePeriod,{mask:m.mask,loop:m.loop});this.reported=false;}
            if(m.type==='stop')this.player=null;
            if(m.type==='mask'&&this.player)this.player.mask=m.mask;
            if(m.type==='loop'&&this.player)this.player.loop=m.loop;
          };
        }
        process(inputs,outputs){const out=outputs[0][0];
          for(let i=0;i<out.length;i++)out[i]=this.player?this.player.sample():0;
          if(this.player){this.notice+=out.length;
            if(this.notice>=sampleRate/10){this.notice=0;this.port.postMessage({type:'position',frame:this.player.position});}
            if(this.player.ended&&!this.reported){this.reported=true;this.port.postMessage({type:'ended'});}
          }return true;
        }
      }registerProcessor('monty-music',MontyProcessor);`;
    const url=URL.createObjectURL(new Blob([code],{type:'text/javascript'}));
    try { await ctx.audioWorklet.addModule(url); } catch(e) { await ctx.close();context=null;throw e; } finally { URL.revokeObjectURL(url); }
    node=new AudioWorkletNode(ctx,'monty-music',{numberOfInputs:0,numberOfOutputs:1,outputChannelCount:[1]});
    gain=ctx.createGain();gain.gain.value=Number($('volume').value)/100;analyser=ctx.createAnalyser();analyser.fftSize=1024;
    node.connect(gain).connect(analyser).connect(ctx.destination);
    node.onprocessorerror=() => error(Error('Ошибка звукового процессора. Обновите страницу.'));
    node.port.onmessage=({data:m}) => {
      if(m.type==='position'){
        const period=data.tracks[selected].periodFrames, position=m.frame%period;
        $('progress').value=position/period;$('elapsed').textContent=time(position*data.framePeriod);
      } else if(m.type==='ended') stop();
    };
  }
  async function play() {
    $('error').textContent='';$('play').disabled=true;
    try {
      await setup();
      if(playing&&!paused){await context.suspend();paused=true;$('play').textContent='▶ Продолжить';$('status').textContent='Пауза';return;}
      if(!playing)node.port.postMessage({type:'load',track:data.tracks[selected],framePeriod:data.framePeriod,mask:mask(),loop:$('loop').checked});
      await context.resume();playing=true;paused=false;$('play').textContent='Ⅱ Пауза';$('status').textContent='Играет';
    } catch(e){error(e);} finally{$('play').disabled=false;}
  }
  async function stop() {
    playing=false;paused=false;
    if(node)node.port.postMessage({type:'stop'});
    if(context)await context.suspend();
    $('play').textContent='▶ Играть';$('status').textContent='Готов к воспроизведению';$('elapsed').textContent='0:00';$('progress').value=0;
  }
  data.tracks.forEach((track,i) => {
    const li=document.createElement('li'),button=document.createElement('button');button.className='track';
    button.innerHTML=`<span class="number">${String(i+1).padStart(2,'0')}</span><span><strong></strong><small>${track.kind==='music' ? 'Музыка · NES' : 'Эффект · '+(track.effect_kind==='noise'?'шум':'пульс')}</small></span><span class="duration">${duration(track)}</span>`;
    button.querySelector('strong').textContent=track.title;
    button.addEventListener('click',async()=>{try{const resume=playing&&!paused;await stop();selected=i;updateTrack();if(resume||track.kind==='sfx')await play();}catch(e){error(e);}});
    li.append(button);$(track.kind==='sfx'?'effects':'tracks').append(li);
  });
  $('play').addEventListener('click',play);$('stop').addEventListener('click',()=>stop().catch(error));
  $('volume').addEventListener('input',()=>{if(gain)gain.gain.setTargetAtTime(Number($('volume').value)/100,context.currentTime,.01);});
  $('loop').addEventListener('change',()=>{if(node)node.port.postMessage({type:'loop',loop:$('loop').checked});});
  document.querySelectorAll('[data-channel]').forEach(input=>input.addEventListener('change',()=>{if(node)node.port.postMessage({type:'mask',mask:mask()});}));
  $('wav').addEventListener('click',()=>{
    $('wav').disabled=true;$('wav').textContent='Готовлю WAV…';$('error').textContent='';
    const code=`const api=(${MontyAPUFactory.toString()})();onmessage=({data:m})=>{try{const r=api.render(m.track,44100,m.framePeriod,{mask:m.mask});const buffer=api.wav(r.samples,r.rate);postMessage({buffer},[buffer]);}catch(e){postMessage({error:String(e)});}};`;
    const workerUrl=URL.createObjectURL(new Blob([code],{type:'text/javascript'})),worker=new Worker(workerUrl),name=data.tracks[selected].id;
    const cleanup=()=>{worker.terminate();URL.revokeObjectURL(workerUrl);$('wav').disabled=false;$('wav').textContent='Скачать WAV ↓';};
    worker.onerror=e=>{error(e);cleanup();};
    worker.onmessage=({data:m})=>{if(m.error)error(Error(m.error));else{
      const url=URL.createObjectURL(new Blob([m.buffer],{type:'audio/wav'})),a=document.createElement('a');a.href=url;a.download=name+'.wav';a.click();setTimeout(()=>URL.revokeObjectURL(url),30000);
    }cleanup();};
    worker.postMessage({track:data.tracks[selected],framePeriod:data.framePeriod,mask:mask()});
  });
  const canvas=$('wave'),paint=canvas.getContext('2d'),samples=new Uint8Array(1024);
  function draw(){requestAnimationFrame(draw);paint.clearRect(0,0,canvas.width,canvas.height);paint.strokeStyle='#a5e4c4';paint.lineWidth=2;paint.beginPath();
    if(analyser&&playing&&!paused)analyser.getByteTimeDomainData(samples);else samples.fill(128);
    for(let i=0;i<samples.length;i++){const x=i/(samples.length-1)*canvas.width,y=samples[i]/255*canvas.height;if(i)paint.lineTo(x,y);else paint.moveTo(x,y);}paint.stroke();
  }
  updateTrack();draw();
})();
