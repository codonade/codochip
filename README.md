# 🎮 Codochip

A [CHIP-8](https://en.wikipedia.org/wiki/CHIP-8) emulator built in [Odin.](https://odin-lang.org/)

- Works reasonably well with some ROMs, fails catastrophically with most of them.
- Lets you disassemble the currently running ROM and inspect what instruction it's executing.
- No sound. The `ST` register and its instructions are present, I just don't do anything with them.
- Error reporting is basically non-existent. If something goes wrong, you're on your own. Sorry.
- Sometimes sprites just... keep flashing on the screen. Mostly moving sprites.

## ⚠️ Disclaimer

I tried to implement everything from scratch without the use of AI, but there were a few topics that
I couldn't understand by myself or issues that I didn't know how to resolve, so I needed the help of
a friend...

## 🌐 References

- [Odin Overview](https://odin-lang.org/docs/overview/)
- [CHIP-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
- [CHIP-8 ROMs](https://github.com/kripod/chip8-roms)
- [Trip8](https://youtu.be/PlSjiGWFk4w?si=vO624ap90UEuX6hb)
