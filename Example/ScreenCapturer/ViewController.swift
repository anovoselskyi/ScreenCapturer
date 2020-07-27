//
//  ViewController.swift
//  ScreenCapturer
//
//  Created by anovoselskyi on 07/27/2020.
//  Copyright (c) 2020 anovoselskyi. All rights reserved.
//

import UIKit
import ScreenCapturer
import MobileCoreServices

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let screenCapturer = ScreenCapturer()

    @IBAction func openPicker(_ sender: Any) {
        screenCapturer.isMicrophoneEnabled = true
        screenCapturer.startCapture()
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.mediaTypes = [kUTTypeMovie as String]
        present(picker, animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.screenCapturer.stopCapture { result in
                print(result)
            }
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) {
            self.screenCapturer.stopCapture { result in
                print(result)
            }
        }
    }
}
