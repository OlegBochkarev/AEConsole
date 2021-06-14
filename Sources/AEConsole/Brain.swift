/**
 *  https://github.com/tadija/AEConsole
 *  Copyright © 2016-2020 Marko Tadić
 *  Licensed under the MIT license
 */

import UIKit
import AELog

internal final class Brain: NSObject {
    
    // MARK: - Outlets
    
    internal var console: View?
    
    // MARK: - Properties
    
    internal let settings: Settings

    internal var lines = [CustomStringConvertible]()
    internal var filteredLines = [CustomStringConvertible]()
    
    internal var contentWidth: CGFloat = 0.0
    
    private var logFolderPath: URL!
    private let logDateFormatter: DateFormatter = DateFormatter()
    
    internal var filterText: String? {
        didSet {
            isFilterActive = !isEmpty(filterText)
        }
    }
    
    internal var isFilterActive = false {
        didSet {
            updateFilter()
            updateInterfaceIfNeeded()
        }
    }

    // MARK: Init

    internal init(with settings: Settings) {
        self.settings = settings
        
        logDateFormatter.dateFormat = "dd_MM_yyyy_HH:mm:ss"
        logDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(string: documentsDirectory)!
        logFolderPath = docURL.appendingPathComponent("Logs")
        
        if !FileManager.default.fileExists(atPath: logFolderPath.absoluteString) {
            try? FileManager.default.createDirectory(atPath: logFolderPath.absoluteString,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
        }
    }
    
    // MARK: - API

    internal func configureConsole(in window: UIWindow?) {
        guard let window = window else { return }
        if console != nil {
            console?.removeFromSuperview()
            console = nil
        }
        console = createConsoleView(in: window)
        console?.tableView.dataSource = self
        console?.tableView.delegate = self
        console?.textField.delegate = self
    }
    
    internal func addLogLine(_ line: CustomStringConvertible) {
        calculateContentWidth(for: line)
        updateFilteredLines(with: line)
        lines.append(line)
        updateInterfaceIfNeeded()
    }
    
    internal func isEmpty(_ text: String?) -> Bool {
        guard let text = text else { return true }
        let characterSet = CharacterSet.whitespacesAndNewlines
        let isTextEmpty = text.trimmingCharacters(in: characterSet).isEmpty
        return isTextEmpty
    }
    
    // MARK: - Actions
    
    internal func clearLog() {
        lines.removeAll()
        filteredLines.removeAll()
        updateInterfaceIfNeeded()
    }
    
    internal func exportLogFile(completion: @escaping (() throws -> URL) -> Void) {
        DispatchQueue.global().async { [unowned self] in
            completion {
                try self.writeLogFile()
            }
        }
    }
    
    private func writeLogFile() throws -> URL {
        let stringLines = lines.map({ $0.description })
        let log = stringLines.joined(separator: "\n")

        if isEmpty(log) {
            aelog("Log is empty, nothing to export here.")
            throw NSError(domain: "net.tadija.AEConsole/Brain", code: 0, userInfo: nil)
        } else {
            do {
                let fileURL = logFileURL
                try log.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
                aelog("Log is exported")
                DispatchQueue.main.async {[weak self] in
                    self?.clearLog()
                }
                return fileURL
            } catch {
                aelog("Log exporting failed with error: \(error)")
                throw error
            }
        }
    }

    private var logFileURL: URL {
        let filename = "\(logDateFormatter.string(from: Date())).txt"
        let documentsURL = URL(fileURLWithPath: logFolderPath.absoluteString, isDirectory: true)
        let fileURL = documentsURL.appendingPathComponent(filename)
        return fileURL
    }
    
    func mach_task_self() -> task_t {
        return mach_task_self_
    }
      
    func getMegabytesUsed() -> Float? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            return infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { (machPtr: UnsafeMutablePointer<integer_t>) in
                return task_info(
                    mach_task_self(),
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    machPtr,
                    &count
                )
            }
        }
        guard kerr == KERN_SUCCESS else {
            return nil
        }
        return Float(info.resident_size) / (1024 * 1024)
    }
    
}

extension Brain {
    
    // MARK: - Helpers
    
    fileprivate func updateFilter() {
        if isFilterActive {
            applyFilter()
        } else {
            clearFilter()
        }
    }
    
    private func applyFilter() {
        guard let filter = filterText else { return }
        aelog("Filter Lines [\(isFilterActive)] - <\(filter)>")
        let filtered = lines.filter {
            $0.description.localizedCaseInsensitiveContains(filter)
        }
        filteredLines = filtered
    }
    
    private func clearFilter() {
        aelog("Filter Lines [\(isFilterActive)]")
        filteredLines.removeAll()
    }
    
    fileprivate func updateInterfaceIfNeeded() {
        if console?.isOnScreen == true {
            console?.updateUI()
        }
    }
    
    fileprivate func createConsoleView(in window: UIWindow) -> View {
        let view = View()
        
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isOnScreen = false
        window.addSubview(view)
        
        return view
    }
    
    fileprivate func calculateContentWidth(for line: CustomStringConvertible) {
        let calculatedLineWidth = getWidth(for: line)
        if calculatedLineWidth > contentWidth {
            contentWidth = calculatedLineWidth
        }
    }
    
    fileprivate func updateFilteredLines(with line: CustomStringConvertible) {
        if isFilterActive {
            guard let filter = filterText else { return }
            if line.description.contains(filter) {
                filteredLines.append(line)
            }
        }
    }
    
    private func getWidth(for line: CustomStringConvertible) -> CGFloat {
        let text = line.description
        let maxSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: settings.estimatedRowHeight
        )
        let options = NSStringDrawingOptions.usesLineFragmentOrigin
        let attributes = [NSAttributedString.Key.font : settings.consoleFont]
        let nsText = text as NSString
        let size = nsText.boundingRect(
            with: maxSize,
            options: options,
            attributes: attributes,
            context: nil
        )
        let width = size.width
        return width
    }
    
}

extension Brain: UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UITableViewDataSource
    
    internal func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        let rows = isFilterActive ? filteredLines : lines
        return rows.count
    }
    
    internal func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.identifier) as! Cell

        let rows = isFilterActive ? filteredLines : lines
        let logLine = rows[indexPath.row]
        cell.label.text = logLine.description

        return cell
    }

    // MARK: - UIScrollViewDelegate
    
    internal func scrollViewDidEndDragging(_ scrollView: UIScrollView,
                                           willDecelerate decelerate: Bool) {
        if !decelerate {
            console?.currentOffsetX = scrollView.contentOffset.x
        }
    }
    
    internal func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        console?.currentOffsetX = scrollView.contentOffset.x
    }
    
}

extension Brain: UITextFieldDelegate {
    
    // MARK: - UITextFieldDelegate
    
    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !isEmpty(textField.text) {
            filterText = textField.text
        }
        return true
    }
    
}
