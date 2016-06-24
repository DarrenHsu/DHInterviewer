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
    
    @IBAction func startPressed(sender : UIButton) {
        if localRoom != nil {
            return
        }
        
        localRoom = DHLocalRoom.init()
        localRoom!.delegate = self
        localRoom!.start("Darren 720")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - DHRoomDelegate Methods
    func displayChatMessage(message: String!, fromUser userName: String!) {
        msgTextView?.text = msgTextView?.text.stringByAppendingFormat("%@ %@\n", message, userName)
    }
    
    func roomTerminated(room: AnyObject!, reason string: String!) {
        NSLog("terminate \(room)")
    }
}
