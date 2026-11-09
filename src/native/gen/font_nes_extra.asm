; The five GAME OVER glyphs occupy permanent high RAM below sprite slot 5.
 ORG 0xFDD0
font_extra:
 db "G",254,230,224,238,230,254,254,0
 db "A",254,254,238,238,254,238,238,0
 db "M",198,238,254,254,214,198,198,0
 db "O",254,254,238,238,238,254,254,0
 db "R",254,238,238,254,248,238,238,0
 ASSERT $ <= 0xFE00
