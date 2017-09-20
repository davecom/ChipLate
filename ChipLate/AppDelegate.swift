//
//  AppDelegate.swift
//  ChipLate
//
//  Created by David Kopec on 1/15/17.
//  Copyright © 2017 David Kopec. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var chip8View: Chip8View!
    
    var chip8: Chip8?
    var emuTimer: Timer?
    
    let concurrentQueue = DispatchQueue(label: "queuename", attributes: .concurrent)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        window.aspectRatio = NSSize(width: 2, height: 1)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func openDocument(sender: AnyObject) {
        print("openDocument got called")
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                do {
                    let data: Data = try Data(contentsOf: openPanel.url!)
                    data.withUnsafeBytes({ (pointer: UnsafePointer<Byte>) in
                        let buffer = UnsafeBufferPointer(start: pointer, count: data.count)
                        let array = Array<Byte>(buffer)
                        self.chip8 = Chip8(rom: array)
                        self.chip8View.bitmapWidth = (self.chip8?.width)!
                        self.chip8View.bitmapHeight = (self.chip8?.height)!
                        // run at about 500 hertz
                        self.emuTimer = Timer.scheduledTimer(timeInterval: 1/500.0, target: self, selector: #selector(self.timerFired), userInfo: nil, repeats: true)
                    })
                    
                } catch {
                    print("error")
                }
            }
        }
    }
    
    @objc func timerFired() {
        // main loop
        self.chip8?.cycle()
        if (chip8?.needsRedraw)! {
            self.chip8View.bitmap = (self.chip8?.pixels)!
            self.chip8View.needsDisplay = true
        }
        if (self.chip8?.playSound)! {
            NSSound.beep()
        }
        if (self.chip8?.wait)! {
            emuTimer?.invalidate()
        }
    }

    var keys = ["1", "2", "3", "4", "q", "w", "e", "r", "a", "s", "d", "f", "z", "x", "c", "v"]
    //MARK: Called from Chip8View
    func keyDown(with event: NSEvent) {
        guard let pressed = event.characters else { return }
        print("key pressed")
        if let index = keys.index(of: pressed) {
            chip8?.keys[index] = true
            if (chip8?.wait)! {
                chip8?.lastKeyPressed = Byte(index)
                emuTimer = Timer.scheduledTimer(timeInterval: 1/60.0, target: self, selector: #selector(self.timerFired), userInfo: nil, repeats: true)
            }
        }
    }
    
    
    func keyUp(with event: NSEvent) {
        guard let pressed = event.characters else { return }
        if let index = keys.index(of: pressed) {
            chip8?.keys[index] = false
        }
    }
}

