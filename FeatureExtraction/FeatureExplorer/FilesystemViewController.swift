//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa

class FilesystemViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    @IBOutlet weak var outlineView: NSOutlineView!

    var selection: (String -> ())?
    var rootPath: String = "/"

    private var fileManager: NSFileManager = NSFileManager()
    private var subpaths = [String: [String]]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let defaults = NSUserDefaults.standardUserDefaults()
        if let path = defaults.valueForKey("rootPath") as? String {
            rootPath = path
        } else {
            rootPath = NSHomeDirectory()
        }

        outlineView.target = self
        outlineView.doubleAction = "doubleClick:"
    }

    @IBAction func openDocument(sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = NSURL(fileURLWithPath: rootPath)

        if openPanel.runModal() == NSFileHandlingPanelOKButton {
            rootPath = (openPanel.directoryURL?.path)!
            outlineView.reloadData()

            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setValue(rootPath, forKey: "rootPath")
            defaults.synchronize()
        }
    }

    @IBAction func doubleClick(sender: AnyObject?) {
        let row = outlineView.clickedRow
        guard let path = outlineView.itemAtRow(row) as? String else {
            return
        }

        rootPath = path
        outlineView.reloadData()
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        guard let path = item as? String else {
            return itemsAtPath(rootPath).count
        }

        let items = itemsAtPath(path)
        return items.count
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        guard let path = item as? String else {
            return itemsAtPath(rootPath)[index]
        }

        let items = itemsAtPath(path)
        return items[index]
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        guard let path = item as? String else {
            return true
        }

        return isDirectory(path)
    }

    func outlineView(outlineView: NSOutlineView, persistentObjectForItem item: AnyObject?) -> AnyObject? {
        return item
    }


    // MARK: - NSOutlineViewDelegate

    func outlineView(outlineView: NSOutlineView, didAddRowView rowView: NSTableRowView, forRow row: Int) {
        guard let path = outlineView.itemAtRow(row) as? String else {
            return
        }

        if let nameView = rowView.viewAtColumn(0) as? NSTableCellView {
            nameView.textField?.stringValue = fileManager.displayNameAtPath(path)
        }
        if let kindView = rowView.viewAtColumn(1) as? NSTableCellView {
            if !(path as NSString).pathExtension.isEmpty {
                kindView.textField?.stringValue = (path as NSString).pathExtension
            } else if isDirectory(path) {
                kindView.textField?.stringValue = "Folder"
            } else {
                kindView.textField?.stringValue = ""
            }
        }
    }

    func outlineViewSelectionDidChange(notification: NSNotification) {
        let row = outlineView.selectedRow
        if let path = outlineView.itemAtRow(row) as? String {
            selection?(path)
        }
    }
    
    // MARK: -

    func itemsAtPath(path: String) -> [String] {
        if let paths = subpaths[path] {
            return paths
        }

        var names = try! fileManager.contentsOfDirectoryAtPath(path).filter{ !$0.hasPrefix(".") }
        names.sortInPlace(compareStrings)

        let paths = names.map{ (path as NSString).stringByAppendingPathComponent($0) }
        subpaths[path] = paths
        return paths
    }

    let charSet = NSCharacterSet(charactersInString: ".-_ ")
    func compareStrings(s1: String, s2: String) -> Bool {
        let components1 = s1.componentsSeparatedByCharactersInSet(charSet)
        let components2 = s2.componentsSeparatedByCharactersInSet(charSet)
        return components1.lexicographicalCompare(components2, isOrderedBefore: compareStringComponents)
    }

    func compareStringComponents(s1: String, s2: String) -> Bool {
        if let n1 = Int(s1), n2 = Int(s2) {
            return n1 < n2
        }
        return s1 < s2
    }

    func isDirectory(path: String) -> Bool {
        var dir: ObjCBool = false
        return fileManager.fileExistsAtPath(path, isDirectory: &dir) && dir
    }
}
