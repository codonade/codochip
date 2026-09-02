package main
import "core:fmt"
import "vendor:raylib"

Machine :: struct {
    // 16 8-bit general purpose registers.
    // VF shouldn't be used by any program as it is used as a flag by some instructions.
    v: [16]u8,
}

main :: proc() {
    machine := Machine {}

    // All CHIP-8 instructions are 2-bytes long.
    program := []u16 { 0x6E2F }
    for i := 0; i < len(program); i += 1 {
        instruction := program[i]
        code := instruction >> 12
        if code == 6 {
            x := (instruction << 4) >> 12
            kk := cast(u8)((instruction << 8) >> 8)
            machine.v[x] = kk
        }

        for r := 0; r < 16; r += 1 {
            fmt.printf("[V%X]: 0x%02X ", r, machine.v[r])
            if (r+1) % 4 == 0 do fmt.println()
        }
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
