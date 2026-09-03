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
    instruction: u16 = auto_cast ((low_byte << 8) | kk)
    code := low_byte >> 4
    x := low_byte & 0x0F
    nnn: u16 = auto_cast ((x << 8) | kk)
    y := kk >> 4
    n := kk & 0x0F

    // ~ Parameter-less Instructions
    if instruction == 0x00EE {
        // - return from a subroutine.
        fmt.printfln("RET")
        machine.pc = machine.stack[machine.sp]
        machine.sp -= 1
    }

    // ~ Parameterized Instructions
    if code == 1 {
        // - jump to an address in memory.
        fmt.printfln("JMP 0x%03X", nnn)
        machine.pc = nnn
    } else if code == 2 {
        // - call a subroutine present at an address in memory.
        fmt.printfln("CALL 0x%03X", nnn)
        machine.stack[machine.sp] = machine.pc
        machine.sp += 1
        machine.pc = nnn
    } else if code == 3 {
        // - skip the next instruction if Vx holds a specific value.
        fmt.printfln("SE V%X, 0x%02X", x, kk)
        if (machine.v[x] == kk) do machine.pc += 2
    } else if code == 4 {
        // - skip the next instruction if Vx doesn't hold a specific value.
        fmt.printfln("SNE V%X, 0x%02X", x, kk)
        if (machine.v[x] != kk) do machine.pc += 2
    } else if code == 5 && n == 0 {
        // - skip the next instruction if Vx equals Vy.
        fmt.printfln("SE V%X, V%X", x, y)
        if (machine.v[x] == machine.v[y]) do machine.pc += 2
    } else if code == 6 {
        // - load a byte into a general purpose register.
        fmt.printfln("LOAD V%X, 0x%02X", x, kk)
        machine.v[x] = kk
    } else if code == 7 {
        // - adds a value to Vx.
        fmt.printfln("ADD V%X, 0x%02X", x, kk)
        machine.v[x] += kk
    } else if code == 8 && n == 4 {
        // - add Vy to Vx and flag VF for carrying.
        fmt.printfln("ADD V%X, V%X", x, y)
        result: u16 = auto_cast machine.v[x] + auto_cast machine.v[y]
        machine.v[x] = auto_cast (result & 0x00FF)
        machine.v[0xF] = 1 if result > 255 else 0
    } else if code == 8 && n == 5 {
        // - subtract Vy from Vx and flag VF for NOT borrowing.
        fmt.printfln("SUB V%X, V%X", x, y)
        machine.v[0xF] = 1 if machine.v[x] > machine.v[y] else 0
        machine.v[x] -= machine.v[y]
    } else if code == 8 && n == 7 {
        // - subtract Vx from Vy, store the result in Vx, and flag VF for NOT borrowing.
        fmt.printfln("SUBN V%X, V%X", x, y)
        machine.v[0xF] = 1 if machine.v[y] > machine.v[x] else 0
        machine.v[x] = machine.v[y] - machine.v[x]
    } else if code == 9 && n == 0 {
        // - skip the next instruction if Vx doesn't equal Vy.
        fmt.printfln("SNE V%X, V%X", x, y)
        if (machine.v[x] != machine.v[y]) do machine.pc += 2
    }

    machine.pc += 2
    if machine.pc >= len(machine.memory) {
        fmt.eprintln("Program failed to establish an internal loop!")
        os.exit(1)
    }
}

main :: proc() {
    program := []u8 { 0x61, 0x01, 0x62, 0xFF, 0x81, 0x27, 0x3F, 0x01, 0x10, 0x00 }
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

        // - execute instructions.
        accumulated_cycle_time += auto_cast dt
        for accumulated_cycle_time >= cycle_duration {
            machine_step(&machine)
            accumulated_cycle_time -= cycle_duration
        }

        // - execute renders.
        raylib.BeginDrawing()
        raylib.EndDrawing()
    }
}
