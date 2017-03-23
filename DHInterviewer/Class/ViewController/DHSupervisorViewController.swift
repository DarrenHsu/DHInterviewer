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
    
    @IBAction func testPressed(_ sender : UIButton) {
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
    func serverBrowser(_ serverBrowser: DHSocketServerBrowser!, add service: NetService!) {
        if remoteRoom != nil {
            return
        }
        
        remoteRoom = DHRemoteRoom.init(netService: service)
        remoteRoom?.delegate = self
        remoteRoom?.start()
        
        serverBrowser.stop()
    }
    
    func serverBrowser(_ serverBrowser: DHSocketServerBrowser!, remove service: NetService!) {
        NSLog("removeservice \(service)")
    }
    
    // MARK: - DHRoomDelegate Methods
    func displayChatMessage(_ message: String!, fromUser userName: String!) {
        msgTextView?.text = msgTextView?.text.appendingFormat("%@ : %@\n", userName, message)
    }
    
    func roomTerminated(_ room: AnyObject!, reason string: String!) {
        NSLog("terminate \(room)")
    }
}
