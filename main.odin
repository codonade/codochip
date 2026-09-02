package main
import "core:fmt"
import "vendor:raylib"

main :: proc() {
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
