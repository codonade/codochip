package main
import "core:fmt"
import "vendor:raylib"

Machine :: struct {
    // 8-bit general purpose registers.
    // VF shouldn't be used by any program as it is used as a flag by some instructions.
    v: [16]u8,

    // Psuedo-registers are registers that aren't accessible from CHIP-8 programs.
    // A 16-bit register used to store the address of the currently executing instruction.
    pc: u16,
    // An array to store the address the interpreter should return to when finished with a subroutine.
    stack: [16]u16,
    sp: u8,
}

main :: proc() {
    machine := Machine {}

    // All CHIP-8 instructions are 2-bytes long.
    // TODO implement error handling!
    program := []u16 { 0x6A10, 0x2000 }
    for; auto_cast machine.pc < len(program); {
        instruction := program[machine.pc]
        if instruction == 0x00EE { // RET
            machine.pc = machine.stack[machine.sp]
            machine.sp -= 1
        }

        code := instruction >> 12
        if code == 1 { // 1nnn: JUMP nnn
            nnn := (instruction << 4) >> 4
            machine.pc = nnn
        }
        else if code == 2 { // 2nnn: CALL nnn
            nnn := (instruction << 4) >> 4
            machine.stack[machine.sp] = machine.pc
            machine.sp += 1
            machine.pc = nnn
        }
        else if code == 6 { // 6xkk: LD Vx, kk
            x := (instruction << 4) >> 12
            kk := cast(u8)((instruction << 8) >> 8)
            machine.v[x] = kk
        }

        for r := 0; r < 16; r += 1 {
            fmt.printf("[V%X]: 0x%02X ", r, machine.v[r])
            if (r+1) % 4 == 0 do fmt.println()
        }
        machine.pc += 1
    }

    raylib.SetTraceLogLevel(.ERROR)
    // CHIP-8 originally used a 64x32 display. To preserve its aspect ratio, we're going to each
    // CHIP-8 pixel to a 16x16 block of real pixels.
    raylib.InitWindow(1024, 512, "CHIP-8")
    defer raylib.CloseWindow()
    raylib.SetTargetFPS(60)

    for !raylib.WindowShouldClose() {
        raylib.BeginDrawing()
        raylib.EndDrawing()
    }
}
