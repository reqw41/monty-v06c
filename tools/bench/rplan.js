// случайный план для lockstep: node rplan.js зерно тиков [телепорты]
let x = +process.argv[2] || 1; const N = +process.argv[3] || 3000, tp = process.argv[4] === 'tp';
const rnd = (n) => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x % n; };
const out = []; const rooms = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) rooms.push([r, c]);
let ri = 0;
for (let t = 200; t < N; t += 6 + rnd(25)) for (const k of ['left', 'right', 'up', 'down', 'space']) out.push(`${t}:${k}${rnd(3) === 0 ? '+' : '-'}`);
if (tp) for (let t = 300; t < N; t += 60) { const [r, c] = rooms[ri++ % rooms.length]; out.push(`${t}:s71A7=${r.toString(16)},71A8=${c.toString(16)},7079=9`); }
console.log(out.join(' '));
