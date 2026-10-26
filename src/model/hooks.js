// Подмены процедур игры JS-моделью: адрес (hex) -> подмена; процедуры из модулей src/model/*.js
'use strict';
const { hooks } = require('./core');
module.exports = Object.assign({}, ...['./room', './vdp', './vram'].map((p) => hooks(require(p))));
