//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction

class MainViewController: NSSplitViewController {
    var filesystemViewController: FilesystemViewController!
    var fileViewController: FileViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        filesystemViewController = splitViewItems[0].viewController as! FilesystemViewController
        filesystemViewController.selection = { path in
            self.fileViewController.loadExample(path)
        }
        fileViewController = splitViewItems[1].viewController as! FileViewController
        fileViewController.configuration = Configuration()
    }
    
}
