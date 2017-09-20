//
//  Chip8.swift
//  ChipLate
//
//  The ChipLate License (MIT)
//
//  Copyright (c) 2017 David Kopec
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

// I'm late to the party learning about writing emulators. So, I've started with 
// this emulator of the simple CHIP-8.
// It's based on the excellent tutorial by Laurence Muller:
// http://www.multigesture.net/articles/how-to-write-an-emulator-chip-8-interpreter/
// And the documentation of the CHIP-8 system on Wikipedia:
// https://en.wikipedia.org/wiki/CHIP-8#Virtual_machine_description

import Foundation

typealias Byte = UInt8
typealias Word = UInt16

// I'm not making this particularly user configurable because I'm not interested
// in extending this beyond supporting the most basic original CHIP-8 designs
struct Chip8 {
    
    // Initialized registers & memory constructs
    // General Purpose Regisers - CHIP-8 has 16 of these registers
    private var v: [Byte] = [Byte](repeating: 0, count: 16)
    // Index Register
    private var i: Word = 0
    // Program Counter
    // starts at 0x200 because addresses below that are used for
    // special memory for the emulator itself - usually a font
    private var pc: Word = 0x200
    // Memory - the standard 4k on the original CHIP-8 machines
    private var ram: [Byte]
    // Stack - in real hardware this is typically limited to 
    // 12 or 16 PC addresses for jumps, but since we're on modern hardware,
    // ours can just be unlimited and expand/contract as needed
    private var stack: [Word] = [Word]()
    // Graphics buffer for the screen - typically 64 x 32
    let width: Int
    let height: Int
    var pixels: [Byte]
    // Timers - really simple registers that count down to 0 when timing needed
    private var delayTimer: Byte = 0
    private var soundTimer: Byte = 0
    // These hold the status of whether the keys are down - CHIP-8 has 16 keys
    var keys: [Bool] = [Bool](repeating: false, count: 16)
    
    var playSound: Bool {
        return soundTimer > 0
    }
    
    // for dealing with key press events
    var keyRegister: Byte = 16 // too high can't be, signal
    var lastKeyPressed: Byte = 16 // too high can't be, signal
    var _wait = false
    
    // know when graphics changed
    var needsRedraw = false
    
    var wait: Bool {
        return _wait
    }
    
    init(memorySize: Int = 4096, width: Int = 64, height: Int = 32, rom: [Byte]) {
        // initialize memory
        ram = [Byte](repeating: 0, count: memorySize)
        // initialize graphics
        self.width = width
        self.height = height
        pixels = [Byte](repeating: 0, count: width * height)
        
        // load the fontset into the first 80 bytes
        ram.replaceSubrange(0..<Chip8.FontSet.count, with: Chip8.FontSet)
        
        // copy program (rom) into ram starting at byte 512 by convention
        ram.replaceSubrange(512..<(512 + rom.count), with: rom)
    }
    
    mutating func cycle() {
        // we look at the opcode in terms of its nibbles (4 bit pieces)
        // opcode is 16 bits made up of next two bytes in memory
        let first2 = ram[pc]
        let last2 = ram[pc + 1]
        let first = (first2 & 0xF0) >> 4
        let second = first2 & 0xF
        let third = (last2 & 0xF0) >> 4
        let fourth = last2 & 0xF
        let opcode: Word = Word(first2) << 8 | Word(last2)
        
        //for debug
        printHex(opcode)
        //printHex(first)
        //printHex(second)
        //printHex(third)
        //printHex(fourth)
        
        
        // deal with key pressed issues
        _wait = false
        
        if keyRegister < 16 {
            v[keyRegister] = lastKeyPressed
            keyRegister = 16
        }
        
        // don't need redraw unless draw opcode is called
        needsRedraw = false
        
        switch (first, second, third, fourth) {
        case (0x0, 0x0, 0xE, 0x0): // display clear
            pixels = [Byte](repeating: 0, count: width * height)
            pc += 2 // increment program counter
        case (0x0, 0x0, 0xE, 0xE): // return from subroutine
            pc = stack.removeLast()
            pc += 2 // increment program counter
        case (0x0, let n1, let n2, let n3): // call program
            pc = concatNibbles(n1, n2, n3) // go to program start
            // clear registers
            delayTimer = 0
            soundTimer = 0
            v = [Byte](repeating: 0, count: 16)
            i = 0
            // clear screen
            pixels = [Byte](repeating: 0, count: width * height)
        case (0x1, let n1, let n2, let n3): // jump to address
            pc = concatNibbles(n1, n2, n3)
        case (0x2, let n1, let n2, let n3): // call subroutine
            stack.append(pc) // copy pc onto the stack
            pc = concatNibbles(n1, n2, n3) // goto subroutine
        case (0x3, let x, _, _): // conditional skip v[x] equal last2
            pc = v[x] == last2 ? pc + 4 : pc + 2
        case (0x4, let x, _, _): // conditional skip v[x] not equal last2
            pc = v[x] != last2 ? pc + 4 : pc + 2
        case (0x5, let x, let y, _): // conditional skip v[x] equal v[y]
            pc = v[x] == v[y] ? pc + 4 : pc + 2
        case (0x6, let x, _, _): // set v[x] to last2
            v[x] = last2
            pc += 2
        case (0x7, let x, _, _): // add last2 to v[x]
            v[x] = v[x] &+ last2
            pc += 2
        case (0x8, let x, let y, 0x0): // set v[x] to v[y]
            v[x] = v[y]
            pc += 2
        case (0x8, let x, let y, 0x1): // set v[x] to v[x] | v[y]
            v[x] |= v[y]
            pc += 2
        case (0x8, let x, let y, 0x2): // set v[x] to v[x] & v[y]
            v[x] &= v[y]
            pc += 2
        case (0x8, let x, let y, 0x3): // set v[x] to v[x] ^ v[y]
            v[x] ^= v[y]
            pc += 2
        case (0x8, let x, let y, 0x4): // add with carry flag
            var overflow: Bool
            (v[x], overflow) = v[x].addingReportingOverflow(v[y])
            v[0xF] = overflow ? 1 : 0
            pc += 2
        case (0x8, let x, let y, 0x5): // subtract with borrow flag
            var overflow: Bool
            (v[x], overflow) = v[x].subtractingReportingOverflow(v[y])
            v[0xF] = overflow ? 0 : 1
            pc += 2
        case (0x8, let x, _, 0x6): // v[x] >> 1 v[f] = least significant bit
            v[0xF] = v[x] & 0x1
            v[x] = v[x] >> 1
            pc += 2
        case (0x8, let x, let y, 0x7): // subtract with borrow flag
            var overflow: Bool
            (v[x], overflow) = v[y].subtractingReportingOverflow(v[x])
            v[0xF] = overflow ? 0 : 1
            pc += 2
        case (0x8, let x, _, 0xE): // v[x] << 1 v[f] = most significant bit
            v[0xF] = v[x] & 0b10000000
            v[x] = v[x] << 1
            pc += 2
        case (0x9, let x, let y, 0x0): // conditional skip if v[x] != v[y]
            pc = v[x] != v[y] ? pc + 4 : pc + 2
        case (0xA, let n1, let n2, let n3): // set i to address n1n2n3
            i = concatNibbles(n1, n2, n3)
            pc += 2
        case (0xB, let n1, let n2, let n3): // jump to n1n2n3 + v[0]
            pc = concatNibbles(n1, n2, n3) + Word(v[0])
        case (0xC, let x, _, _): // v[x] = random number (0-255) & last2
            v[x] = last2 & Byte(arc4random_uniform(255))
            pc += 2
        case (0xD, let x, let y, let n): // draw(vx, vy, n)
            let flipped = draw(x: v[x], y: v[y], height: n)
            if flipped {
                v[0xF] = 1
            } else {
                v[0xF] = 0
            }
            needsRedraw = true
            pc += 2
        case (0xE, let x, 0x9, 0xE): // conditional skip if keys(v[x])
            pc = keys[v[x]] ? pc + 4 : pc + 2
        case (0xE, let x, 0xA, 0x1): // conditional skip if not keys(v[x])
            pc = !keys[v[x]] ? pc + 4 : pc + 2
        case (0xF, let x, 0x0, 0x7): // set v[x] to delayTimer
            v[x] = delayTimer
            pc += 2
        case (0xF, let x, 0x0, 0xA): // wait until next key then store in v[x]
            _wait = true
            keyRegister = x
            pc += 2
        case (0xF, let x, 0x1, 0x5): // set delayTimer to v[x]
            delayTimer = v[x]
            pc += 2
        case (0xF, let x, 0x1, 0x8): // set soundTimer to v[x]
            soundTimer = v[x]
            pc += 2
        case (0xF, let x, 0x1, 0xE): // add vx to i
            i += Word(v[x])
            pc += 2
        case (0xF, let x, 0x2, 0x9): // set i to location of character v[x]
            i = Word(v[x] * Byte(5)) // built-in fontset is 5 bytes apart
            pc += 2
        case (0xF, let x, 0x3, 0x3): // store BCD at v[x] in i,i+1,i+2
            ram[i] = v[x] / 100 // 100s digit
            ram[i+1] = (v[x] % 100) / 10 // 10s digit
            ram[i+2] = (v[x] % 100) % 10 // 1s digit
            pc += 2
        case (0xF, let x, 0x5, 0x5): // reg dump v0 to vx starting at i
            for r in 0...Word(x) {
                ram[i + r] = v[r]
            }
            pc += 2
        case (0xF, let x, 0x6, 0x5): // store i through i+r in v0 through vr
            for r in 0...Word(x) {
                v[r] = ram[i + r]
            }
            pc += 2
        default: print("Unknown opcode!")
        }
        
        // decrement timers
        if delayTimer > 0 { delayTimer -= 1 }
        if soundTimer > 0 {
            if soundTimer == 1 {
                // play a beep - maybe set a flag here that's checked for
            }
            soundTimer -= 1
        }
        
    }
    
    // width is always 8
    // returns bool indicating whether a pixel was flipped
    private mutating func draw(x: Byte, y: Byte, height: Byte) -> Bool {
        let width:Byte = 8
        var flipped: Bool = false
        
        for rowNum in 0..<height {
            let bitString: Byte = ram[i + Word(rowNum)]
            for colNum in 0..<width {
                let pixelNum = Int((Int(x) + Int(colNum)) + ((Int(y) + Int(rowNum)) * Int(self.width)))
                let newPixel: Byte = (bitString & (0b10000000 >> colNum)) > 0 ? 1 : 0
                if pixelNum >= pixels.count { continue } // ignore pixels outside of screen
                if newPixel == 0 && pixels[pixelNum] == 1 {
                    flipped = true
                }
                pixels[pixelNum] = pixels[pixelNum] ^ newPixel
            }
        }
        
        return flipped
    }
    
    // The font set, hardcoded
    private static let FontSet: [Byte] = [
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80  // F
    ]

}

//MARK: Utility Functions

func printHex<I: BinaryInteger & CVarArg>(_ value: I) {
    print(String(format:"%X", value as CVarArg))
}

// smash some bytes together
func concatBytes(_ bytes: Byte...) -> Word {
    return bytes.reduce(0x0) { (last, next) -> UInt16 in
        return last << 8 | Word(next)
    }
}

// smash some nibbles together
func concatNibbles(_ bytes: Byte...) -> Word {
    return bytes.reduce(0x0) { (last, next) -> UInt16 in
        return last << 4 | Word(next)
    }
}

// for easy indexing by registers into ram or nibbles into registers
extension Array {
    subscript(place: Word) -> Element {
        get {
            return self[Int(place)]
        }
        set {
            self[Int(place)] = newValue
        }
    }
    
    subscript(place: Byte) -> Element {
        get {
            return self[Int(place)]
        }
        set {
            self[Int(place)] = newValue
        }
    }
}
