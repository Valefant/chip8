import random
import strutils

const
  REG_SIZE = 16
  MEM_SIZE = 4096
  STACK_SIZE = 16
  INITIAL_LOCATION = 0x200
  SCREEN_WIDTH* = 64
  SCREEN_HEIGHT* = 32
  FONTS = [
    #[Hexadecimals constants are of type int.
      As I want to store the font as byte, a conversion is needed from int to byte.
      The implicit conversion into a smaller type of int to an unsigned int is not allowed.
      Solution: Explicit conversion of the first member of an array.
                This results in an implicit conversion for the rest of the data]#
    byte(0xF0), 0x90, 0x90, 0x90, 0xF0, # 0
    0x20, 0x60, 0x20, 0x20, 0x70,       # 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0,       # 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0,       # 3
    0x90, 0x90, 0xF0, 0x10, 0x10,       # 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0,       # 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0,       # 6
    0xF0, 0x10, 0x20, 0x40, 0x40,       # 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0,       # 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0,       # 9
    0xF0, 0x90, 0xF0, 0x90, 0x90,       # A
    0xE0, 0x90, 0xE0, 0x90, 0xE0,       # B
    0xF0, 0x80, 0x80, 0x80, 0xF0,       # C
    0xE0, 0x90, 0x90, 0x90, 0xE0,       # D
    0xF0, 0x80, 0xF0, 0x80, 0xF0,       # E
    0xF0, 0x80, 0xF0, 0x80, 0x80        # F  
  ]

var
  # 16 register (8-bit) referred to as Vx, where x is a hexadecimal digit ranging from 0 to F
  V: array[REG_SIZE, byte]
  # memory containing rom and other data
  memory: array[MEM_SIZE, byte]
  # 2d array containing the sprites to draw
  gfx*: array[SCREEN_HEIGHT, array[SCREEN_WIDTH, byte]]
  # store state of the key
  keys*: array[16, byte]
  # stack for storing the pc (in this case the point to resume) when calling a subroutine
  stack: array[STACK_SIZE, uint16]
  # index register
  I: uint16
  # program counter holding the address of the current instruction
  pc: uint16
  # stack pointer
  sp: byte
  delayTimer: byte
  soundTimer: byte
  # a flag which tells the renderer to update its content
  draw* = false

proc initialize*() =
  pc = INITIAL_LOCATION

  for i in 0..<80:
    memory[i] = FONTS[i]

  # set time as seed for the generator
  randomize()
   
proc loadRom*(rom: string) =
  echo "Loading ", rom
  var file = open(rom)
  # roms are loaded at address 0x200
  let byteCount = file.readBytes(memory, INITIAL_LOCATION, len(memory) - INITIAL_LOCATION)

  if byteCount < file.getFileSize():
    echo "Couldn't read everything from rom"
  else:
    echo "Rom was successfully loaded"

  # todo check if rom is too large

# chip8 opcodes are 2 bytes long and stored in big-endian
proc emulateCycle*() =
  # most significant byte
  let msb = memory[pc]
  # least significant byte
  let lsb = memory[pc + 1]

  # 4-bit of a byte
  let nibble = msb shr 4 
  # converting msb to uint16 so we can shift 8 bits without losing them
  var instruction = (uint16(msb) shl 8) or lsb

  case nibble
  of 0x00:
    case lsb
    of 0xe0:
      for y in 0..<SCREEN_HEIGHT:
        for x in 0..<SCREEN_WIDTH:
          gfx[y][x] = 0
      draw = true
      pc += 0x02
    of 0xee:
      dec(sp)
      pc = stack[sp]
      pc += 0x02
    else:
      echo "Unknown instruction: ", instruction.toHex
      pc += 2
  of 0x01:
    pc = instruction and 0x0fff
  of 0x02:
    stack[sp] = pc
    inc(sp)
    pc = instruction and 0x0fff
  of 0x03:
    let vx = msb and 0x0f
    if V[vx] == lsb:
      pc += 0x04
    else:
      pc += 0x02
  of 0x04:
    let vx = msb and 0x0f
    if V[vx] != lsb:
      pc += 0x04
    else:
      pc += 0x02
  of 0x05:
    let vx = msb and 0x0f
    let vy = lsb shr 4
    if vx == vy:
      pc += 0x04
    else:
      pc += 0x02
  of 0x06:
    let vx = msb and 0x0f
    V[vx] = lsb
    pc += 0x02
  of 0x07:
    let vx = msb and 0x0f
    V[vx] += lsb
    pc += 0x02
  of 0x08:
    case lsb and 0x0f
    of 0x00:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      V[vx] = V[vy]
      pc += 0x02
    of 0x01:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      V[vx] = V[vx] or V[vy]
      pc += 0x02
    of 0x02:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      V[vx] = V[vx] and V[vy]
      pc += 0x02
    of 0x03:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      V[vx] = V[vx] xor V[vy]
      pc += 0x02
    of 0x04:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      V[vx] += V[vy]
      if V[vy] > (byte(0xff) - V[vx]):
        V[0x0f] = 1
      else:
        V[0x0f] = 0
      pc += 0x02
    of 0x05:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      if V[vy] > V[vx]:
        V[0xf] = 0
      else:
        V[0xf] = 1
      V[vx] -= V[vy]
      pc += 0x02
    of 0x06:
      let vx = msb and 0x0f
      V[0xf] = V[vx] and 0x1 
      V[vx] = V[vx] shr 1
      pc += 0x02
    of 0x07:
      let vx = msb and 0x0f
      let vy = lsb shr 4
      if V[vx] > V[vy]:
        V[0xf] = 0
      else:
        V[0xf] = 1
      V[vx] = V[vy] - V[vx]
    of 0x0e:
      let vx = msb and 0x0f
      V[0x0f] = V[vx] shr 7 
      V[vx] = V[vx] shl 1
      pc += 0x02
    else:
      discard
  of 0x09:
    let vx = msb and 0x0f
    let vy = lsb shr 4
    if V[vx] != V[vy]:
      pc += 0x04
    else:
      pc += 0x02
  of 0x0a:
    I = instruction and 0x0fff
    pc += 0x02
  of 0x0b:
    pc = (instruction and 0x0fff) + V[0x00]
  of 0x0c:
    let vx = msb and 0x0f
    V[vx] = byte(rand(255)) and lsb
    pc += 0x02
  of 0x0d:
    let vx = msb and 0x0f
    let vy = lsb shr 4
    let x = V[vx]
    let y = V[vy]
    let n = lsb and 0x0f 

    V[0x0f] = 0
    for offset in byte(0)..<n:
      let sprite = memory[I + offset]

      for i in byte(0)..<8:
        if (sprite and (byte(0x80) shr i)) != 0:
          if gfx[y + offset][x + i] == 1:
            V[0x0f] = 1
          gfx[y + offset][x + i] = gfx[y + offset][x + i] xor 1

    draw = true
    pc += 2
  of 0x0e:
    case lsb
    of 0x9e:
      let vx = msb and 0x0f
      if keys[V[vx]] != 0:
        pc += 0x04
      else:
        pc += 0x02
    of 0xa1:
      let vx = msb and 0x0f
      if keys[V[vx]] == 0:
        pc += 0x04
      else:
        pc += 0x02
    else:
      discard
  of 0x0f:
    case lsb
    of 0x07:
      let vx = msb and 0x0f
      V[vx] = delayTimer
      pc += 0x02
    of 0x0a:
      let vx = msb and 0x0f
      var keyPressed = false
      for i in byte(0)..<16:
        if keys[i] != 0:
          V[vx] = i
          keyPressed = true

      if not keyPressed:
        return

      pc += 0x02
    of 0x15:
      let vx = msb and 0x0f
      delayTimer = V[vx]
      pc += 0x02
    of 0x18:
      let vx = msb and 0x0f
      soundTimer = V[vx]
      pc += 0x02
    of 0x1e:
      let vx = msb and 0x0f
      if (I + V[vx]) > uint16(0xfff):
        V[0x0f] = 1
      else:
        V[0x0f] = 0

      I += V[vx]
      pc += 0x02
    of 0x29:
      let vx = msb and 0x0f
      I = V[vx] * 0x05
      pc += 0x02
    of 0x33:
      let vx = msb and 0x0f
      memory[I] = V[vx] div 100
      memory[I + 1] = (V[vx] div 10) mod 10
      memory[I + 2] = (V[vx] mod 100) mod 10
      pc += 0x02
    of 0x55:
      let vx = msb and 0x0f
      for i in byte(0)..vx:
        memory[I + i] = V[i]
      I += vx + 1
      pc += 0x02
    of 0x65:
      let vx = msb and 0x0f
      for i in byte(0)..vx:
        V[i] = memory[I + i]
      I += vx + 1
      pc += 0x02
    else:
      discard
  else:
    echo "Unknown instruction: ", instruction.toHex
    pc += 0x02
  
  if delayTimer > byte(0):
    dec(delayTimer)

  if soundTimer > byte(0):
    dec(soundTimer)
