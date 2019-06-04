//
//  ViewController.swift
//  ImageCropperSample
//
//  Created by cano on 2019/06/04.
//  Copyright © 2019 mycompany. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import NSObject_Rx
import RSKImageCropper

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.bind()
    }
    
    override func viewWillLayoutSubviews() {
        self.imageView.setRounded()
    }

    func bind() {
        self.button.rx.tap.asDriver().drive(onNext: { [unowned self] _ in
            var actions = [ActionSheetItem<UIImagePickerController.SourceType>(
                title: "ライブラリから選択",
                selectType: UIImagePickerController.SourceType.photoLibrary,
                style: .default)]
            
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                actions.insert(ActionSheetItem<UIImagePickerController.SourceType>(
                    title: "カメラを起動",
                    selectType: UIImagePickerController.SourceType.camera,
                    style: .default), at: 0)
            }
            self.showActionSheet(title: "画像選択", message: "選択してください。", actions: actions)
                .take(1)
                .subscribe({ [unowned self] event in
                if let sourceType = event.element {
                    switch sourceType {
                    case .camera:
                        self.launchPhotoPicker(.camera)
                    case .photoLibrary:
                        self.launchPhotoPicker(.photoLibrary)
                    case .savedPhotosAlbum:
                        break
                    @unknown default:
                        break
                    }
                }
            })
            .disposed(by: self.rx.disposeBag)
        }).disposed(by: rx.disposeBag)
        
    }
    
    // UIImagePickerControllerの起動と選択した画像の処理
    private func launchPhotoPicker(_ sourceType: UIImagePickerController.SourceType) {
        if !UIImagePickerController.isSourceTypeAvailable(sourceType) { return }
        let cameraPicker = UIImagePickerController()
        cameraPicker.sourceType = sourceType
        cameraPicker.delegate = self
        self.present(cameraPicker, animated: true, completion: nil)
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // 画像選択、カメラ撮影後
    func imagePickerController(_ imagePicker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]){
        
        guard let pickedImage = info[.originalImage] as? UIImage else { return }
        
        let imageCropVC : RSKImageCropViewController!
        imageCropVC = RSKImageCropViewController(image: pickedImage, cropMode: RSKImageCropMode.circle)
        imageCropVC.moveAndScaleLabel.text = "切り取り範囲を選択"
        imageCropVC.cancelButton.setTitle("キャンセル", for: .normal)
        imageCropVC.chooseButton.setTitle("完了", for: .normal)
        imageCropVC.delegate = self
        imagePicker.pushViewController(imageCropVC, animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: RSKImageCropViewControllerDelegate {
    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        
        if controller.cropMode == .circle {
            UIGraphicsBeginImageContext(croppedImage.size)
            let layerView = UIImageView(image: croppedImage)
            layerView.frame.size = croppedImage.size
            layerView.layer.cornerRadius = layerView.frame.size.width * 0.5
            layerView.clipsToBounds = true
            let context = UIGraphicsGetCurrentContext()!
            layerView.layer.render(in: context)
            let capturedImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            let pngData = capturedImage.pngData()!
            self.imageView.image = UIImage(data: pngData)!
        }
        dismiss(animated: true, completion: nil)
    }
}

// アクションシートの項目を指定する構造体
struct ActionSheetItem<Type> {
    let title: String
    let selectType: Type
    let style: UIAlertAction.Style
}

extension UIAlertController {
    // アクションシートに項目を追加し、Observable化
    func addAction<T>(actions: [ActionSheetItem<T>], cancelMessage: String, cancelAction: ((UIAlertAction) -> Void)?) -> Observable<T> {
        return Observable.create { [weak self] observer in
            actions.map { action in
                return UIAlertAction(title: action.title, style: action.style) { _ in
                    observer.onNext(action.selectType)
                    observer.onCompleted()
                }
                }.forEach { action in
                    self?.addAction(action)
            }
            
            self?.addAction(UIAlertAction(title: cancelMessage, style: .cancel) {
                cancelAction?($0)
                observer.onCompleted()
            })
            
            return Disposables.create {
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}

extension UIViewController {
    // Observable化したアクションシートの表示
    func showActionSheet<T>(title: String?, message: String?, cancelMessage: String = "キャンセル", actions: [ActionSheetItem<T>]) -> Observable<T> {
        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        return actionSheet.addAction(actions: actions, cancelMessage: cancelMessage, cancelAction: nil)
            .do(onSubscribed: { [weak self] in
                self?.present(actionSheet, animated: true, completion: nil)
            })
    }
}

extension UIView {
    func setRounded() {
        cornerRadius(radius: self.frame.height/2)
    }
    func cornerRadius(radius: CGFloat, MaskToBounds: Bool = true) {
        self.layer.cornerRadius = radius
        self.layer.masksToBounds = MaskToBounds
    }
}
