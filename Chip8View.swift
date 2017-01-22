//
//  Chip8View.swift
//  ChipLate
//
//  Created by David Kopec on 1/16/17.
//  Copyright © 2017 David Kopec. All rights reserved.
//

import Cocoa

class Chip8View: NSView {
    @IBOutlet weak var delegate: AppDelegate!
    
    var bitmap: [Byte] = []
    var bitmapWidth: Int = 0
    var bitmapHeight: Int = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // draw black background
        NSColor.black.setFill()
        NSRectFill(bounds)
        
        // draw pixels as white rectangles
        NSColor.white.setFill()
        let width = self.frame.size.width
        let height = self.frame.size.height
        let rectSize = CGSize(width: round(width / CGFloat(bitmapWidth)), height: round(height / CGFloat(bitmapHeight)))
        
        for x in 0..<bitmapWidth {
            for y in 0..<bitmapHeight {
                if bitmap[y * bitmapWidth + x] == 1 {
                    NSRectFill(NSRect(origin: CGPoint(x: CGFloat(x) * rectSize.width, y: CGFloat(y) * rectSize.height), size: rectSize))
                }
            }
        }
    }
    
    override var isFlipped: Bool { return true }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        delegate.keyDown(with: event)
    }
    
    
    override func keyUp(with event: NSEvent) {
        delegate.keyUp(with: event)
    }
    
}
