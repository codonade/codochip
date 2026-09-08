package main
import "core:fmt"
import str "core:strings"
import "core:math/rand"
import "vendor:raylib"
import "core:os"

panic :: proc(message: string) {
    fmt.eprintln(message)
    os.exit(1)
}

should_disassemble := false
disassemble :: proc(instruction: u16, format: string, args: ..any) {
    if !should_disassemble do return
    fmt.printf("(%04X) ", instruction)
    fmt.printfln(format, ..args)
}

FONT_SPRITES_ADDRESS :: 0x050
INTERPRETER_END_ADDRESS :: 0x200
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
    // 8-bit delay timer register.
    dt: u8,
    // 8-bit sound timer register.
    st: u8,

    // 64x32 monochromatic display.
    display: [64][32]bool,
}

machine_spin :: proc(machine: ^Machine, program: []u8) {
    // CHIP-8 programs must be granted access to a group of sprites representing the hexadecimal
    // digits 0 through F. They must be 4x5 pixels and can only be stored in the interpreter area of
    // the memory.
    machine.memory[FONT_SPRITES_ADDRESS + 0x000] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x001] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x002] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x003] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x004] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x005] = 0b00100000 //   *
    machine.memory[FONT_SPRITES_ADDRESS + 0x006] = 0b01100000 //  **
    machine.memory[FONT_SPRITES_ADDRESS + 0x007] = 0b00100000 //   *
    machine.memory[FONT_SPRITES_ADDRESS + 0x008] = 0b00100000 //   *
    machine.memory[FONT_SPRITES_ADDRESS + 0x009] = 0b01110000 //  ***
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x00A] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x00B] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x00C] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x00D] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x00E] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x00F] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x010] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x011] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x012] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x013] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x014] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x015] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x016] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x017] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x018] = 0b00010000 //    *
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x019] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x01A] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x01B] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x01C] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x01D] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x01E] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x01F] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x020] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x021] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x022] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x023] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x024] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x025] = 0b00100000 //   *
    machine.memory[FONT_SPRITES_ADDRESS + 0x026] = 0b01000000 //  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x027] = 0b01000000 //  *
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x028] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x029] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x02A] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x02B] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x02C] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x02D] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x02E] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x02F] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x030] = 0b00010000 //    *
    machine.memory[FONT_SPRITES_ADDRESS + 0x031] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x032] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x033] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x034] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x035] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x036] = 0b10010000 // *  *
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x037] = 0b11100000 // ***
    machine.memory[FONT_SPRITES_ADDRESS + 0x038] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x039] = 0b11100000 // ***
    machine.memory[FONT_SPRITES_ADDRESS + 0x03A] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x03B] = 0b11100000 // ***
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x03C] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x03D] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x03E] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x03F] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x040] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x041] = 0b11100000 // ***
    machine.memory[FONT_SPRITES_ADDRESS + 0x042] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x043] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x044] = 0b10010000 // *  *
    machine.memory[FONT_SPRITES_ADDRESS + 0x045] = 0b11100000 // ***
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x046] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x047] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x048] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x049] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x04A] = 0b11110000 // ****
    //////////////////////////////////////////
    machine.memory[FONT_SPRITES_ADDRESS + 0x04B] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x04C] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x04D] = 0b11110000 // ****
    machine.memory[FONT_SPRITES_ADDRESS + 0x04E] = 0b10000000 // *
    machine.memory[FONT_SPRITES_ADDRESS + 0x04F] = 0b10000000 // *

    // - load the program into memory.
    machine.pc = INTERPRETER_END_ADDRESS
    for i := 0; i < len(program); i += 1 {
        machine.memory[INTERPRETER_END_ADDRESS + auto_cast i] = program[i]
    }
}

// TODO handle instruction errors!
machine_step :: proc(machine: ^Machine) -> bool {
    low_byte := machine.memory[machine.pc]
    kk := machine.memory[machine.pc + 1]
    instruction: u16 = auto_cast low_byte << 8 | auto_cast kk
    code := low_byte >> 4
    x := low_byte & 0x0F
    nnn: u16 = auto_cast x << 8 | auto_cast kk
    y := kk >> 4
    n := kk & 0x0F
    increment_pc := true
    display_updated := false

    // ~ Calls and Jumps
    if code == 0x1 {
        // - jump to an address in memory.
        disassemble(instruction, "JMP :%03X", nnn)
        machine.pc = nnn
        increment_pc = false
    } else if code == 0xB {
        // - jump to a memory address offset by V0.
        disassemble(instruction, "JMP V0 <0x%02X>, :%03X", machine.v[0], nnn)
        machine.pc = nnn + auto_cast machine.v[0]
        increment_pc = false
    } else if code == 0x2 {
        // - call a subroutine present at an address in memory.
        disassemble(instruction, "CALL :%03X", nnn)
        machine.stack[machine.sp] = machine.pc
        machine.sp += 1
        machine.pc = nnn
        increment_pc = false
    } else if instruction == 0x00EE {
        // - return from a subroutine.
        disassemble(instruction, "RET")
        machine.sp -= 1
        machine.pc = machine.stack[machine.sp] + 2
        increment_pc = false

    // ~ Loading into Registers
    } else if code == 0x6 {
        // - load a byte into Vx.
        disassemble(instruction, "LOAD V%X, 0x%02X", x, kk)
        machine.v[x] = kk
    } else if code == 0x8 && n == 0 {
        // - load Vy into Vx.
        disassemble(instruction, "LOAD V%X, V%X <0x%02X>", x, y, machine.v[y])
        machine.v[x] = machine.v[y]
    } else if code == 0xA {
        // - load 12 bits into I.
        disassemble(instruction, "LOAD I, :%03X", nnn)
        machine.i = nnn
    } else if code == 0xF && kk == 0x29 {
        // - load the location of the sprite for the digit in Vx into I.
        disassemble(instruction, "LOAD I, F <#%X>", machine.v[x])
        machine.i = FONT_SPRITES_ADDRESS + auto_cast machine.v[x] * 5

    // ~ Timers
    } else if code == 0xF && kk == 0x15 {
        // - load the value of Vx into DT.
        disassemble(instruction, "LOAD DT, V%X <0x%02X>", x, machine.v[x])
        machine.dt = machine.v[x]
    } else if code == 0xF && kk == 0x07 {
        // - load the value of DT into Vx.
        disassemble(instruction, "LOAD V%X, DT <0x%02X>", x, machine.v[x])
        machine.v[x] = machine.dt
    } else if code == 0xF && kk == 0x18 {
        // - load the value of Vx into ST.
        disassemble(instruction, "LOAD ST, V%X <0x%02X>", x, machine.v[x])
        machine.st = machine.v[x]

    // ~ Memory Operations
    } else if code == 0xF && kk == 0x55 {
        // - store registers V0 through Vx in memory starting at I.
        disassemble(instruction, "LOAD [:%03X -> :%03X], [V0 -> V%X]", machine.i, machine.i + auto_cast x, x)
        for r: u8 = 0; r <= x; r += 1 do machine.memory[machine.i + auto_cast r] = machine.v[r]
    } else if code == 0xF && kk == 0x65 {
        // - read values from memory starting at I to registers V0 through Vx.
        disassemble(instruction, "LOAD [V0 -> V%X], [:%03X -> :%03X]", x, machine.i, machine.i + auto_cast x)
        for r: u8 = 0; r <= x; r += 1 do machine.v[r] = machine.memory[machine.i + auto_cast r]

    // ~ Addition and Subtraction
    } else if code == 0x7 {
        // - adds a byte to Vx.
        disassemble(instruction, "ADD V%X <0x%02X>, 0x%02X", x, machine.v[x], kk)
        machine.v[x] += kk
    } else if code == 0x8 && n == 0x4 {
        // - add Vy to Vx, flag VF if a carry occurred.
        disassemble(instruction, "ADD V%X <0x%02X>, V%X <0x%02X> @VF", x, machine.v[x], y, machine.v[y])
        result: u16 = auto_cast machine.v[x] + auto_cast machine.v[y]
        machine.v[x] = auto_cast (result & 0x00FF)
        machine.v[0xF] = 1 if result > 255 else 0
    } else if code == 0xF && kk == 0x1E {
        // - add a byte to I.
        disassemble(instruction, "ADD I <:%03X>, V%X", machine.i, x)
        machine.i += auto_cast machine.v[x]
    } else if code == 0x8 && n == 0x5 {
        // - subtract Vy from Vx, flag VF if borrowing isn't necessary.
        disassemble(instruction, "SUB V%X <0x%02X>, V%X <0x%02X> @VF", x, machine.v[x], y, machine.v[y])
        machine.v[0xF] = 1 if machine.v[x] > machine.v[y] else 0
        machine.v[x] -= machine.v[y]
    } else if code == 0x8 && n == 0x7 {
        // - subtract Vx from Vy, store the result in Vx, and flag VF if borrowing isn't necessary.
        disassemble(instruction, "SUBN V%X <0x%02X>, V%X <0x%02X> @VF", x, machine.v[x], y, machine.v[y])
        machine.v[0xF] = 1 if machine.v[y] > machine.v[x] else 0
        machine.v[x] = machine.v[y] - machine.v[x]

    // ~ Bit Operations
    } else if code == 0x8 && n == 0x1 {
        // - bitwise-or the values of Vx and Vy in Vx.
        disassemble(instruction, "OR V%X <0x%02X>, V%X <0x%02X>", x, machine.v[x], y, machine.v[y])
        machine.v[x] |= machine.v[y]
    } else if code == 0x8 && n == 0x2 {
        // - bitwise-and the values of Vx and Vy in Vx.
        disassemble(instruction, "AND V%X <0x%02X>, V%X <0x%02X>", x, machine.v[x], y, machine.v[y])
        machine.v[x] &= machine.v[y]
    } else if code == 0x8 && n == 0x3 {
        // - bitwise-xor the values of Vx and Vy in Vx.
        disassemble(instruction, "XOR V%X <0x%02X>, V%X <0x%02X>", x, machine.v[x], y, machine.v[y])
        machine.v[x] ~= machine.v[y]
    } else if code == 0x8 && n == 0x6 {
        // - shift the value of Vx to the right by 1 and store the least significant bit in VF.
        disassemble(instruction, "SHR V%X <0x%02X>, !! @VF", x, machine.v[x])
        lsb := machine.v[x] & 1
        machine.v[x] >>= 1
        machine.v[0xF] = lsb
    } else if code == 0x8 && n == 0xE {
        // - shift the value of Vx to the left by 1 and store the most significant bit in VF.
        disassemble(instruction, "SHL V%X <0x%02X>, !! @VF", x, machine.v[x])
        msb := machine.v[x] & 0x80
        machine.v[x] <<= 1
        machine.v[0xF] = 1 if msb > 0 else 0

    // ~ Conditionals
    } else if code == 0x3 {
        // - skip the next instruction if Vx holds a specific value.
        disassemble(instruction, "SE V%X <0x%02X>, 0x%02X", x, machine.v[x], kk)
        if (machine.v[x] == kk) do machine.pc += 2
    } else if code == 0x5 && n == 0x0 {
        // - skip the next instruction if Vx equals Vy.
        disassemble(instruction, "SE V%X <0x%02X>, V%X <0x%02X>", x, machine.v[x], y, machine.v[y])
        if (machine.v[x] == machine.v[y]) do machine.pc += 2
    } else if code == 0x4 {
        // - skip the next instruction if Vx doesn't hold a specific value.
        disassemble(instruction, "SNE V%X <0x%02X>, 0x%02X", x, machine.v[x], kk)
        if (machine.v[x] != kk) do machine.pc += 2
    } else if code == 0x9 && n == 0x0 {
        // - skip the next instruction if Vx doesn't equal Vy.
        disassemble(instruction, "SNE V%X <0x%02X>, V%X <0x%02X>", x, machine.v[x], y, machine.v[y])
        if (machine.v[x] != machine.v[y]) do machine.pc += 2

    // ~ Keyboard Input
    } else if code == 0xE && kk == 0x9E {
        // - skip the next instruction if the key in Vx is pressed.
        disassemble(instruction, "SKP V%X <K%X>", x, machine.v[x])
        if machine.key[machine.v[x]] do machine.pc += 2
    } else if code == 0xE && kk == 0xA1 {
        // - skip the next instruction if the key in Vx is not pressed.
        disassemble(instruction, "SKNP V%X <K%X>", x, machine.v[x])
        if !machine.key[machine.v[x]] do machine.pc += 2
    } else if code == 0xF && kk == 0x0A {
        // - wait until any key is pressed and store its value in Vx.
        disassemble(instruction, "WAIT V%X, K", x)
        any_key_pressed := false
        for k: u8 = 0; k < 16; k += 1 {
            if machine.key[k] {
                machine.v[x] = k
                any_key_pressed = true
                break
            }
        }
        if !any_key_pressed do return false

    // ~ Miscellaneous
    } else if code == 0xC {
        // - generate a random byte and bitwise-and it with Vx.
        disassemble(instruction, "RND V%X, 0x%02X", x, kk)
        machine.v[x] = auto_cast rand.int_range(0, 256) & kk
    } else if code == 0xF && kk == 0x33 {
        // - store the BCD representation of Vx in I, I + 1, and I + 2.
        disassemble(instruction, "BCD [:%03X -> :%03X], V%X <0x%02X>", machine.i, machine.i + 2, x, machine.v[x])
        v := machine.v[x]
        for d := 0; d < 3; d += 1 {
            machine.memory[machine.i + auto_cast d] = v % 10
            v /= 10
        }

    // ~ Drawing
    } else if instruction == 0x00E0 {
        // - clear the display.
        disassemble(instruction, "CLS")
        for dx := 0; dx < 64; dx += 1 {
            for dy := 0; dy < 32; dy += 1 {
                machine.display[dx][dy] = false
            }
        }
        display_updated = true
    } else if code == 0xD {
        // - draw an n-bytes sprite from I at (Vx, Vy).
        disassemble(instruction, "DRW V%X <0x%02X>, V%X <0x%02X>, %X", x, machine.v[x], y, machine.v[y], n)
        // Sprites can be up to 8x15 pixels. If they collided with another sprite, VF is switched on.
        machine.v[0xF] = 0
        for sx: u8 = 0; sx < 8; sx += 1 {
            mask: u8 = 0b10000000 >> sx
            for sy: u8 = 0; sy < n; sy += 1 {
                pixel := machine.memory[machine.i + auto_cast sy] & mask > 0
                dx := (machine.v[x] + sx) % 64; dy := (machine.v[y] + sy) % 32
                if machine.display[dx][dy] && pixel do machine.v[0xF] = 1
                machine.display[dx][dy] = machine.display[dx][dy] != pixel
            }
        }
        display_updated = true
    } else do panic(fmt.tprintf("Whoops! 0x%03X: 0x%04X", machine.pc, instruction))

    if increment_pc do machine.pc += 2
    if machine.pc >= len(machine.memory) - 1 do panic("Program Finished!")
    return display_updated
}

// program := []u8 {
//     0x60, 0x01, 0xF0, 0x29, 0xD1, 0x25,
// }

usage :: proc() {
    panic("USAGE: codochip (--disassemble) ./rom.ch8")
}

main :: proc() {
    // - parse command line arguments.
    if len(os.args) < 2 || len(os.args) > 3 do usage()
    file_path := ""
    for i := 0; i < 2; i += 1 {
        arg := os.args[i + 1]
        if str.starts_with(arg, "-") {
            if arg == "-d" || arg == "--disassemble" do should_disassemble = true
            else do usage()
        } else do file_path = arg
    }

    // - spin up the machine.
    program, error := os.read_entire_file(file_path, context.allocator)
    if error != os.ERROR_NONE do panic("Couldn't read ROM!")
    machine := Machine {}
    machine_spin(&machine, program)

    raylib.SetTraceLogLevel(.ERROR)
    // CHIP-8 originally used a 64x32 display. To preserve its aspect ratio, we're going to each
    // CHIP-8 pixel to a 16x16 block of real pixels.
    raylib.InitWindow(1024, 512, "CHIP-8")
    defer raylib.CloseWindow()
    raylib.SetTargetFPS(60)

    // Different games rely on different clock rates, so 600 is probablly the safest middle ground.
    cycle_duration := 1.0 / 600.0
    accumulated_cycle_time := 0.0

    // CHIP-8 timers tick 60 times a second.
    tick_duration := 1.0 / 60.0
    accumulated_timer_time := 0.0

    for !raylib.WindowShouldClose() {
        fd := raylib.GetFrameTime()

        // - get keyboard input.
        // There was no concept of continuous key holding in the CHIP-8 computers.
        // TODO sometimes a press gets registered twice.
        for k: u8 = 0; k < 16; k += 1 do machine.key[k] = false
        machine.key[0x1] = raylib.IsKeyPressed(.ONE)
        machine.key[0x2] = raylib.IsKeyPressed(.TWO)
        machine.key[0x3] = raylib.IsKeyPressed(.THREE)
        machine.key[0xC] = raylib.IsKeyPressed(.FOUR)
        machine.key[0x4] = raylib.IsKeyPressed(.Q)
        machine.key[0x5] = raylib.IsKeyPressed(.W)
        machine.key[0x6] = raylib.IsKeyPressed(.E)
        machine.key[0xD] = raylib.IsKeyPressed(.R)
        machine.key[0x7] = raylib.IsKeyPressed(.A)
        machine.key[0x8] = raylib.IsKeyPressed(.S)
        machine.key[0x9] = raylib.IsKeyPressed(.D)
        machine.key[0xE] = raylib.IsKeyPressed(.F)
        machine.key[0xA] = raylib.IsKeyPressed(.Z)
        machine.key[0x0] = raylib.IsKeyPressed(.X)
        machine.key[0xB] = raylib.IsKeyPressed(.C)
        machine.key[0xF] = raylib.IsKeyPressed(.V)

        // - execute instructions.
        // HMMM I really don't understand why everything keeps flashing on the screen?
        raylib.BeginDrawing()
        accumulated_cycle_time += auto_cast fd
        for accumulated_cycle_time >= cycle_duration {
            if machine_step(&machine) {
                raylib.ClearBackground(raylib.BLACK)
                for dx := 0; dx < 64; dx += 1 {
                    for dy := 0; dy < 32; dy += 1 {
                        if !machine.display[dx][dy] do continue
                        raylib.DrawRectangle(
                            auto_cast dx * 16,
                            auto_cast dy * 16,
                            16, 16, raylib.RED)
                    }
                }
            }
            accumulated_cycle_time -= cycle_duration
        }
        raylib.EndDrawing()

        // - tick timers.
        accumulated_timer_time += auto_cast fd
        for accumulated_timer_time >= tick_duration {
            if machine.dt > 0 do machine.dt -= 1
            if machine.st > 0 {
                machine.st -= 1
                fmt.println("TODO beeeeep!")
            }
            accumulated_timer_time -= tick_duration
        }
    }
}
