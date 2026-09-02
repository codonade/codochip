package main
import "core:fmt"
import "vendor:raylib"
import "core:os"

Machine :: struct {
    // 4KB memory. Programs start at 0x0200 because the first 512 bytes were where the interpreter
    // used to live. Programs targetting ETI 660 start at 0x0600.
    memory: [4_096]u8,

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
    instruction: u16 = auto_cast((low_byte << 8) | kk)
    code := low_byte >> 4
    x := low_byte & 0x0F
    nnn: u16 = auto_cast((x << 8) | kk)
    y := kk >> 4
    n := kk & 0x0F

    // ~ Parameter-less Instructions
    if instruction == 0x00EE {
        // - return from a subroutine.
        machine.pc = machine.stack[machine.sp]
        machine.sp -= 1
    }

    // ~ Parameterized Instructions
    if code == 1 {
        // - jump to an address in memory.
        machine.pc = nnn
    } else if code == 2 {
        // - call a subroutine present at an address in memory.
        machine.stack[machine.sp] = machine.pc
        machine.sp += 1
        machine.pc = nnn
    } else if code == 6 {
        // - load a byte into a general purpose register.
        machine.v[x] = kk
    }

    machine.pc += 2
    // - error if the problem fails to establish a loop internally.
    if machine.pc >= len(machine.memory) do os.exit(1)
}

main :: proc() {
    program := []u8 { 0x10, 0x00 }
    machine := Machine {}
    machine_load_program(&machine, program)

    raylib.SetTraceLogLevel(.ERROR)
    // CHIP-8 originally used a 64x32 display. To preserve its aspect ratio, we're going to each
    // CHIP-8 pixel to a 16x16 block of real pixels.
    raylib.InitWindow(1024, 512, "CHIP-8")
    defer raylib.CloseWindow()
    raylib.SetTargetFPS(60)

    accumulated_time := 0.0
    cycle_duration := 1.0 / 1200.0

    for !raylib.WindowShouldClose() {
        dt := raylib.GetFrameTime()
        accumulated_time += cast(f64) dt
        for accumulated_time >= cycle_duration {
            machine_step(&machine)
            accumulated_time -= cycle_duration
        }

        raylib.BeginDrawing()
        raylib.EndDrawing()
    }
}
