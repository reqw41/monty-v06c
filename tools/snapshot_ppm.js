#!/usr/bin/env node
// Экран снимка openMSX тем же рендером модели: node tools/snapshot_ppm.js <name> -> build/shots/<name>_omsx.ppm
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const n = process.argv[2] || 'game16';
const m = new MSX1().loadSnap(n);
fs.writeFileSync(`${MSX1.ROOT}/build/shots/${n}_omsx.ppm`, m.ppm());
