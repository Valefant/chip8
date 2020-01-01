import chip8
import os
import sdl2/sdl
import strformat

proc shutdown(window: Window) =
  sdl.destroyWindow(window)
  sdl.quit()
  quit 0 

if paramCount() <= 0:
  quit "Usage: chip8 <rom>"

let rom = paramStr(1)
initialize()
loadRom(rom)

if sdl.init(sdl.INIT_VIDEO) != 0:
  quit &"Error initializing the video system: {sdl.getError()}"

const keyMap = [
  sdl.K_1,
  sdl.K_2,
  sdl.K_3,
  sdl.K_4,
  sdl.K_q,
  sdl.K_w,
  sdl.K_e,
  sdl.K_r,
  sdl.K_a,
  sdl.K_s,
  sdl.K_d,
  sdl.K_f,
  sdl.K_z,
  sdl.K_x,
  sdl.K_c,
  sdl.K_v,
]
const SCALE = 8
let window = sdl.createWindow(
  "chip8",
  sdl.WINDOWPOS_UNDEFINED,
  sdl.WINDOWPOS_UNDEFINED,
  SCREEN_WIDTH * SCALE,
  SCREEN_HEIGHT * SCALE,
  0
)

if isNil(window):
  quit "Error creating window: {sdl.getError()}"

let renderer = sdl.createRenderer(window, -1, 0)
var e: sdl.Event
let fps = (1000 div 100).uint32

while true:
  while sdl.pollEvent(addr(e)) > 0:
    if e.kind == sdl.QUIT:
      shutdown(window)
    elif e.kind == sdl.KEYDOWN:
      for i in 0..<16:
        if e.key.keysym.sym == keyMap[i]:
          keys[i] = 1
    elif e.kind == sdl.KEYUP:
      for i in 0..<16:
        if e.key.keysym.sym == keyMap[i]:
          keys[i] = 0

  emulateCycle()

  if draw:
    discard renderer.setRenderDrawColor(0, 0, 0, 0)
    discard renderer.renderClear()
    discard renderer.setRenderDrawColor(255, 255, 255, 0)
    for y in 0..<SCREEN_HEIGHT:
      for x in 0..<SCREEN_WIDTH:
        if gfx[y][x] == 1:
          var rect = sdl.Rect(x: x * SCALE, y: y * SCALE, w: SCALE, h: SCALE)
          discard renderer.renderFillRect(addr(rect))
    renderer.renderPresent()
    draw = false

    sdl.delay(fps)

shutdown(window)
