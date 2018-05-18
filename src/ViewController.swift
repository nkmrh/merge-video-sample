import UIKit
import Photos

class ViewController: UIViewController {

    func saveVideoToPhotos(fileURL: URL) {
        let saveVideoToPhotos = {
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL) }) { [weak self] saved, error in
                let success = saved && (error == nil)
                let title = success ? "Success" : "Error"
                let message = success ? "Video saved" : "Failed to save video"
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
        }

        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    saveVideoToPhotos()
                }
            }
        } else {
            saveVideoToPhotos()
        }
    }

    @IBAction func mergeAction(_ sender: UIButton) {
        let urls = Bundle.main.urls(forResourcesWithExtension: "mov", subdirectory: "videos") ?? []
        VideoMerger.merge(urls: urls) { [weak self] fileURL, error in
            if let fileURL = fileURL {
                self?.saveVideoToPhotos(fileURL: fileURL)
            }
        }
    }
}
