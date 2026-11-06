#!/usr/bin/env bash

awk 'function hsv(h,s,v,   c,x,m,r,g,b,hp) {
  c = v*s; hp = (h%360)/60
  x = c * (1 - (hp%2 > 1 ? hp%2-1 : 1-hp%2))
  if (hp < 1)      { r=c; g=x; b=0 }
  else if (hp < 2) { r=x; g=c; b=0 }
  else if (hp < 3) { r=0; g=c; b=x }
  else if (hp < 4) { r=0; g=x; b=c }
  else if (hp < 5) { r=x; g=0; b=c }
  else             { r=c; g=0; b=x }
  m = v-c
  R = int((r+m)*255 + 0.5); G = int((g+m)*255 + 0.5); B = int((b+m)*255 + 0.5)
}
BEGIN {
  for (h = 0; h < 360; h += 15) {
    hsv(h, 1, 1)
    printf "\033[48;2;%d;%d;%dm      \033[0m  #%02x%02x%02x\n", R, G, B, R, G, B
  }
}'


awk 'BEGIN {
  for (v = 0; v <= 255; v += 51)
    printf "\033[48;2;%d;%d;%dm      \033[0m  #%02x%02x%02x\n", v, v, v, v, v, v
}'
