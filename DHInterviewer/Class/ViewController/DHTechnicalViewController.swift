//
//  DHTechnicalViewController.swift
//  DHInterviewer
//
//  Created by Darren720 on 6/24/16.
//  Copyright © 2016 D.H. All rights reserved.
//

import UIKit

class DHTechnicalViewController: UIViewController, DHRoomDelegate {
    
    @IBOutlet weak var msgTextView : UITextView?

    var localRoom : DHLocalRoom?
    
    @IBAction func testPressed(_ sender : UIButton) {
        if localRoom == nil {
            return
        }
        
        localRoom!.broadcastChatMessage("local", fromUser: "technical")
    }
    
    @IBAction func startPressed(_ sender : UIButton) {
        if localRoom != nil {
            return
        }
        
        localRoom = DHLocalRoom.init()
        localRoom!.delegate = self
        localRoom!.start("Darren Chat")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - DHRoomDelegate Methods
    func displayChatMessage(_ message: String!, fromUser userName: String!) {
        msgTextView?.text = msgTextView?.text.appendingFormat("%@ : %@\n", userName, message)
    }
    
    func roomTerminated(_ room: AnyObject!, reason string: String!) {
        NSLog("terminate \(room)")
    }
}
