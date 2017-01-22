# ChipLate
A simple CHIP-8 Emulator for macOS written in Swift.

![ChipLateTicTacToe](https://raw.githubusercontent.com/davecom/ChipLate/master/chiplatettt.png)

## Usage
This macOS CHIP-8 emulator runs ROMs for the original CHIP-8 platform. It implements keyboard input, with the 16 CHIP-8 keys mapped 1, 2, 3, 4, q, w, e, r, a, s, d, f, z, x, c, v. It implements the CHIP-8's basic black and white graphics with some simple Core Graphics rectangle filles. And it implements the CHIP-8's ability to make a simple beep with the system beep. ROM files can be loaded using the File->Open menu item.

## Resources
I used two main resources in developing this emulator:
- [An excellent tutorial by Laurence Muller](http://www.multigesture.net/articles/how-to-write-an-emulator-chip-8-interpreter/)
- [The CHIP-8 Wikipedia page](https://en.wikipedia.org/wiki/CHIP-8), which describes all of the opcodes

## Correctness & Source Code Notes
It runs PONG, MAZE, and most of the ROMs I've tried correctly. I have noticed a few minor issues in some ROMs but haven't had the time/interest to fix them. I wrote the main code in a few hours over a couple nights and it is not particularly elegant. It could use some sprucing up, but the main implementation of the virtual machine, `Chip8.swift`, is well commented.

## License
Released under the MIT License (see `LICENSE`).
