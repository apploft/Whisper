//
//  WhisperWindow.swift
//  Pods
//
//  Created by Abdul Moiz on 2017-05-31.
//
//

import UIKit

public class WindowFrameObserver: NSObject {
    static public let shared = WindowFrameObserver()
    
    private var isObserving: Bool = false
    private weak var window: UIWindow?
    
    public func startObserving() {
        if isObserving == false {
            isObserving = true
            
            NotificationCenter.default.addObserver(self, selector: #selector(stopObserving), name: NSNotification.Name.UIApplicationWillTerminate, object: nil)
            if let window = UIApplication.shared.delegate?.window {
                self.window = window
                window?.addObserver(self, forKeyPath: "frame", options: .new, context: nil)
            }
        }
    }
    
    @objc public func stopObserving() {
        guard isObserving else { return }
        
        isObserving = false
        self.window?.removeObserver(self, forKeyPath: "frame")
        NotificationCenter.default.removeObserver(self)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: Notifications.windowFrameChanged), object: nil)
    }
}
