//
//  main.swift
//  FileImportCountFinder
//
//  Created by Sandeep Negi on 29/05/17.
//  Copyright © 2017 Sandeep Negi. All rights reserved.
//

import Foundation
import AppKit

extension Dictionary {
    func sortedKeys(isOrderedBefore:(Key,Key) -> Bool) -> [Key] {
        return Array(self.keys).sorted(by: isOrderedBefore)
    }
    
    // Slower because of a lot of lookups, but probably takes less memory (this is equivalent to Pascals answer in an generic extension)
    func sortedKeysByValue(isOrderedBefore:(Value, Value) -> Bool) -> [Key] {
        return sortedKeys {
            isOrderedBefore(self[$0]!, self[$1]!)
        }
    }
    
    // Faster because of no lookups, may take more memory because of duplicating contents
    func keysSortedByValue(isOrderedBefore:(Value, Value) -> Bool) -> [Key] {
        return Array(self)
            .sorted() {
                let (_, lv) = $0
                let (_, rv) = $1
                return isOrderedBefore(lv, rv)
            }
            .map {
                let (k, _) = $0
                return k
        }
    }
}

extension FileManager {
    func listFiles(path: String) -> [URL] {
        let baseurl: URL = URL(fileURLWithPath: path)
        var urls = [URL]()
        enumerator(atPath: path)?.forEach({ (e) in
            guard let s = e as? String else { return }
            if includeFile(filename:s) /*&& !childOfIgnoreDir(dirName:s)*/ {
                let relativeURL = URL(fileURLWithPath: s, relativeTo: baseurl)
                let url = relativeURL.absoluteURL
                urls.append(url)
            }
        })
        return urls
    }
    
    func childOfIgnoreDir(dirName:String) -> Bool {
        let ignoreFolderList = ["Libs"]
        for item in ignoreFolderList {
            if dirName.range(of: item, options: .caseInsensitive) != nil {
                return true
            }
        }
        return false
    }
    
    func includeFile(filename:String) -> Bool {
        return filename.hasSuffix(".h") || filename.hasSuffix(".m")
    }
}

extension Data {
    var attributedString: NSAttributedString? {
        do {
            return try NSAttributedString(data: self, options: [ NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.plain, NSAttributedString.DocumentReadingOptionKey.characterEncoding: String.Encoding.utf8.rawValue ], documentAttributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        return nil
    }
}

class HeaderImportFinder {
    
    var dirPath:String = ""
    
    func search() {
        let mypath = dirPath
        let fm = FileManager()
        let arr = fm.listFiles(path: mypath)
        var currentProcessingItemIndex = 0
        var countDict = Dictionary<String, Int>()
        for item in arr {
            
            autoreleasepool {
                
                do {
                    // Read file content
                    var dataObj:Data? = try Data(contentsOf:item)
                    var attibutedString = dataObj!.attributedString
                    var contentFromFile = attibutedString?.string
                    
                    let count = arr.count - 1
                    for i in 0...count {
                        autoreleasepool {
                            
                            if arr[i].absoluteString.hasSuffix(".h") {
                                let searchQuery = "#import \u{22}" + arr[i].lastPathComponent + "\u{22}"
                                let isContain = contentFromFile?.contains(searchQuery)
                                if isContain! {
                                    let previousCount = countDict[searchQuery] ?? 0
                                    countDict[searchQuery] = 1 + previousCount
                                }
                            }
                        }
                    }
                    
                    dataObj = nil
                    attibutedString = nil
                    contentFromFile = nil
                }
                catch let error as NSError {
                    print("An error took place: \(error)")
                }
                
                
                let donePercentage = CGFloat((currentProcessingItemIndex+1)*100)/CGFloat(arr.count)
                print(String(format: "Work done ... %.2f%%", donePercentage))
                
                
                currentProcessingItemIndex += 1
            }
        }
        
        let sortedKeys = countDict.keysSortedByValue(isOrderedBefore: <) //sorting dictionary
        
        print("Import count + sorted result")
        for item in sortedKeys {
            print(item + " ====> " + String(countDict[item]!))
        }
        
    }
    
    func cleanFilePath(path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathWithoutEscapedWhitespaces = trimmedPath.replacingOccurrences(of:"\\ ", with: " ")
        return pathWithoutEscapedWhitespaces
    }
    
    func getDirPath(){
        let response:String? = CommandLine.arguments[1];
        if nil != response && 0 < (response?.count)! {
            dirPath = cleanFilePath(path: response!)
        }else{
            print("Invlaid path input")
        }
    }
    
}

let finderObj = HeaderImportFinder()
finderObj.getDirPath()

let sema = DispatchSemaphore( value: 0)
DispatchQueue.global(qos: .background).async {
    
    finderObj.search()
    
    sema.signal();
}
sema.wait();
