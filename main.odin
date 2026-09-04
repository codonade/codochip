package main
import "core:fmt"
import "core:math/rand"
import "vendor:raylib"
import "core:os"

Machine :: struct {
    // 4KB memory. Programs start at 0x0200 because the first 512 bytes were where the interpreter
    // used to live. Programs targetting ETI 660 start at 0x0600.
    memory: [4_096]u8,

    // Psuedo-registers are registers that aren't accessible from CHIP-8 programs.
    // A 16-bit register used to store the address of the currently executing instruction.
    pc: u16,
    // An array to store the address the interpreter should return to when finished with a subroutine.
    stack: [16]u16,
    sp: u8,

    // The computers which originally used the CHIP-8 language had a 16-key hexacedimal keypad:
    // | ------------- |
    // | 1 | 2 | 3 | C |
    // | ------------- |
    // | 4 | 5 | 6 | D |
    // | ------------- |
    // | 7 | 8 | 9 | E |
    // | ------------- |
    // | A | 0 | B | F |
    // | ------------- |
    key: [16]bool,

    // 8-bit general purpose registers.
    // VF shouldn't be used by any program as it is used as a flag by some instructions.
    v: [16]u8,
    // 16-bit general purpose register.
    i: u16,

    // 64x32 monochromatic display.
    display: [64][32]u8,
}

machine_load_program :: proc(machine: ^Machine, program: []u8) {
    machine.pc = 0x200
    for i := 0; i < len(program); i += 1 {
        machine.memory[0x200 + i] = program[i]
    }
}

// TODO handle instruction errors!
machine_step :: proc(machine: ^Machine) {
    low_byte := machine.memory[machine.pc]
    kk := machine.memory[machine.pc + 1]
    instruction: u16 = auto_cast low_byte << 8 | auto_cast kk
    code := low_byte >> 4
    x := low_byte & 0x0F
    nnn: u16 = auto_cast x << 8 | auto_cast kk
    y := kk >> 4
    n := kk & 0x0F
    increment_pc := true

    // ~ Parameter-less Instructions
    if instruction == 0x00E0 {
        // - clear the display.
        fmt.println("CLEAR")
        for dx := 0; dx < 64; dx += 1 {
            for dy := 0; dy < 32; dy += 1 {
                machine.display[dx][dy] = 0
            }
        }
    } else if instruction == 0x00EE {
        // - return from a subroutine.
        fmt.println("RET")
        machine.pc = machine.stack[machine.sp]
        machine.sp -= 1
        increment_pc = false
    }

    // ~ Parameterized Instructions
    if code == 0x1 {
        // - jump to an address in memory.
        fmt.printfln("JMP 0x%03X", nnn)
        machine.pc = nnn
        increment_pc = false
    } else if code == 0x2 {
        // - call a subroutine present at an address in memory.
        fmt.printfln("CALL 0x%03X", nnn)
        machine.stack[machine.sp] = machine.pc
        machine.sp += 1
        machine.pc = nnn
        increment_pc = false
    } else if code == 0x3 {
        // - skip the next instruction if Vx holds a specific value.
        fmt.printfln("SE V%X, 0x%02X", x, kk)
        if (machine.v[x] == kk) do machine.pc += 2
    } else if code == 0x4 {
        // - skip the next instruction if Vx doesn't hold a specific value.
        fmt.printfln("SNE V%X, 0x%02X", x, kk)
        if (machine.v[x] != kk) do machine.pc += 2
    } else if code == 0x5 && n == 0x0 {
        // - skip the next instruction if Vx equals Vy.
        fmt.printfln("SE V%X, V%X", x, y)
        if (machine.v[x] == machine.v[y]) do machine.pc += 2
    } else if code == 0x6 {
        // - load a byte into a general purpose register.
        fmt.printfln("LOAD V%X, 0x%02X", x, kk)
        machine.v[x] = kk
    } else if code == 0x7 {
        // - adds a value to Vx.
        fmt.printfln("ADD V%X, 0x%02X", x, kk)
        machine.v[x] += kk
    } else if code == 0x8 && n == 0x1 {
        // - bitwise-or the values of Vx and Vy in Vx.
        fmt.printfln("OR V%X, V%X", x, y)
        machine.v[x] |= machine.v[y]
    } else if code == 0x8 && n == 0x2 {
        // - bitwise-and the values of Vx and Vy in Vx.
        fmt.printfln("AND V%X, V%X", x, y)
        machine.v[x] &= machine.v[y]
    } else if code == 0x8 && n == 0x3 {
        // - bitwise-xor the values of Vx and Vy in Vx.
        fmt.printfln("XOR V%X, V%X", x, y)
        machine.v[x] ~= machine.v[y]
    } else if code == 0x8 && n == 0x4 {
        // - add Vy to Vx and flag VF for carrying.
        fmt.printfln("ADD V%X, V%X", x, y)
        result: u16 = auto_cast machine.v[x] + auto_cast machine.v[y]
        machine.v[x] = auto_cast (result & 0x00FF)
        machine.v[0xF] = 1 if result > 255 else 0
    } else if code == 0x8 && n == 0x5 {
        // - subtract Vy from Vx and flag VF for NOT borrowing.
        fmt.printfln("SUB V%X, V%X", x, y)
        machine.v[0xF] = 1 if machine.v[x] > machine.v[y] else 0
        machine.v[x] -= machine.v[y]
    } else if code == 0x8 && n == 0x6 {
        // - shift the value of Vx to the right by 1 and store the least significant bit in VF.
        fmt.printfln("SHR V%X {V%X}", x, y)
        lsb := machine.v[x] & 1
        machine.v[x] >>= 1
        machine.v[0xF] = lsb
    } else if code == 0x8 && n == 0x7 {
        // - subtract Vx from Vy, store the result in Vx, and flag VF for NOT borrowing.
        fmt.printfln("SUBN V%X, V%X", x, y)
        machine.v[0xF] = 1 if machine.v[y] > machine.v[x] else 0
        machine.v[x] = machine.v[y] - machine.v[x]
    } else if code == 0x8 && n == 0xE {
        // - shift the value of Vx to the left by 1 and store the most significant bit in VF.
        fmt.printfln("SHL V%X {V%X}", x, y)
        msb := machine.v[x] & 0x80
        machine.v[x] <<= 1
        machine.v[0xF] = msb
    } else if code == 0x9 && n == 0x0 {
        // - skip the next instruction if Vx doesn't equal Vy.
        fmt.printfln("SNE V%X, V%X", x, y)
        if (machine.v[x] != machine.v[y]) do machine.pc += 2
    } else if code == 0xA {
        // - load 12 bits into I.
        fmt.printfln("LOAD I, 0x%03X", nnn)
        machine.i = nnn
    } else if code == 0xB {
        // - jump to a memory address offset by V0.
        fmt.printfln("JMP V0, 0x%03X", nnn)
        machine.pc = nnn + auto_cast machine.v[0]
        increment_pc = false
    } else if code == 0xC {
        // - generate a random byte and bitwise-and it with a byte in Vx.
        fmt.printfln("RND V%X, 0x%02X", x, kk)
        machine.v[x] = auto_cast rand.int_range(0, 256) & kk
    } else if code == 0xD {
        // - draw an n-bytes sprite from I at (Vx, Vy) and flag VF for collisions.
        // TODO we forgot to count for collisions!
        fmt.printfln("DRW V%X, V%X, %X", x, y, n)
        // Sprites can be up to 8x15 pixels.
        for sx: u8 = 0; sx < 8; sx += 1 {
            mask: u8 = 1 << sx
            for sy: u8 = 0; sy < n; sy += 1 {
                pixel := machine.memory[machine.i + auto_cast sy] & mask
                dx := machine.v[x] + sx; dy := machine.v[y] + sy
                machine.display[dx][dy] = pixel
            }
        }
    } else if code == 0xE && kk == 0x9E {
        // - skip the next instruction if the key with the value Vx is pressed.
        fmt.printfln("SKP V%X", x)
        if machine.key[machine.v[x]] do machine.pc += 2
    } else if code == 0xE && kk == 0xA1 {
        // - skip the next instruction if the key with the value Vx is not pressed.
        fmt.printfln("SKNP V%X", x)
        if !machine.key[machine.v[x]] do machine.pc += 2
    } else if code == 0xF && kk == 0x0A {
        // - store the value of the currently pressed key in Vx.
        fmt.printfln("LOAD V%X, K", x)
        for k: u8 = 0; k < 16; k += 1 do if machine.key[k] do machine.v[x] = k
    }

    if increment_pc do machine.pc += 2
    if machine.pc >= len(machine.memory) {
        fmt.eprintln("Program failed to establish an internal loop!")
        os.exit(1)
    }
}

main :: proc() {
    program := []u8 {
        0xC1, 0xFF, 0x10, 0x00,
    }
    machine := Machine {}
    machine_load_program(&machine, program)

    raylib.SetTraceLogLevel(.ERROR)
    // CHIP-8 originally used a 64x32 display. To preserve its aspect ratio, we're going to each
    // CHIP-8 pixel to a 16x16 block of real pixels.
    raylib.InitWindow(1024, 512, "CHIP-8")
    defer raylib.CloseWindow()
    raylib.SetTargetFPS(60)

    // Different games rely on different clock rates, so 600 is probablly the safest middle ground.
    cycle_duration := 1.0 / 600.0
    accumulated_cycle_time := 0.0

    for !raylib.WindowShouldClose() {
        dt := raylib.GetFrameTime()

        // - gather keyboard input.
        for k: u8 = 0; k < 16; k += 1 do machine.key[k] = false
        machine.key[0x1] = raylib.IsKeyDown(.ONE)
        machine.key[0x2] = raylib.IsKeyDown(.TWO)
        machine.key[0x3] = raylib.IsKeyDown(.THREE)
        machine.key[0xC] = raylib.IsKeyDown(.FOUR)
        machine.key[0x4] = raylib.IsKeyDown(.Q)
        machine.key[0x5] = raylib.IsKeyDown(.W)
        machine.key[0x6] = raylib.IsKeyDown(.E)
        machine.key[0xD] = raylib.IsKeyDown(.R)
        machine.key[0x7] = raylib.IsKeyDown(.A)
        machine.key[0x8] = raylib.IsKeyDown(.S)
        machine.key[0x9] = raylib.IsKeyDown(.D)
        machine.key[0xE] = raylib.IsKeyDown(.F)
        machine.key[0xA] = raylib.IsKeyDown(.Z)
        machine.key[0x0] = raylib.IsKeyDown(.X)
        machine.key[0xB] = raylib.IsKeyDown(.C)
        machine.key[0xF] = raylib.IsKeyDown(.V)

        // - execute instructions.
        accumulated_cycle_time += auto_cast dt
        for accumulated_cycle_time >= cycle_duration {
            machine_step(&machine)
            accumulated_cycle_time -= cycle_duration
        }

        // - render the display.
        // TODO something is seriously messed up with how rendering works!
        raylib.BeginDrawing()
        for dx := 0; dx < 64; dx += 1 {
            for dy := 0; dy < 32; dy += 1 {
                if machine.display[dx][dy] == 0 do continue
                for rx := dx * 16; rx < dx * 16 + 16; rx += 1 {
                    for ry := dy * 16; ry < dy * 16 + 16; ry += 1 {
                        raylib.DrawPixel(auto_cast rx, auto_cast ry, raylib.RED)
                    }
                }
            }
        }
        raylib.EndDrawing()
    }
}
