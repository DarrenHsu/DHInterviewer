//
//  DHSupervisorViewController.swift
//  DHInterviewer
//
//  Created by Darren720 on 6/24/16.
//  Copyright © 2016 D.H. All rights reserved.
//

import UIKit

class DHSupervisorViewController: UIViewController, DHSocketServerBrowserDelegate, DHRoomDelegate {
    
    @IBOutlet weak var msgTextView : UITextView?
    
    var remoteRoom : DHRemoteRoom?
    var serverBrowser : DHSocketServerBrowser?
    
    @IBAction func testPressed(sender : UIButton) {
        if remoteRoom == nil {
            return
        }
        
        remoteRoom!.broadcastChatMessage("local", fromUser: "supervisor")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        serverBrowser = DHSocketServerBrowser.init()
        serverBrowser?.delegate = self
        serverBrowser?.start()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - DHSocketServerBrowserDelegate Methods
    func serverBrowser(serverBrowser: DHSocketServerBrowser!, addService service: NSNetService!) {
        if remoteRoom != nil {
            return
        }
        
        remoteRoom = DHRemoteRoom.init(netService: service)
        remoteRoom?.delegate = self
        remoteRoom?.start()
        
        serverBrowser.stop()
    }
    
    func serverBrowser(serverBrowser: DHSocketServerBrowser!, removeService service: NSNetService!) {
        NSLog("removeservice \(service)")
    }
    
    // MARK: - DHRoomDelegate Methods
    func displayChatMessage(message: String!, fromUser userName: String!) {
        msgTextView?.text = msgTextView?.text.stringByAppendingFormat("%@ : %@\n", userName, message)
    }
    
    func roomTerminated(room: AnyObject!, reason string: String!) {
        NSLog("terminate \(room)")
    }
}
