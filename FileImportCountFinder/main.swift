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
            //            print("filename==>" + s)
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
            return try NSAttributedString(data: self, options:[NSDocumentTypeDocumentAttribute:NSPlainTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        return nil
    }
}

class ImportFinder {
    
    var dirPath:String = ""
    
    func test() {
        let mypath = dirPath
        let fm = FileManager()
        let arr = fm.listFiles(path: mypath)
        var currentProcessingItemIndex = 0
        var countDict = Dictionary<String, Int>()
        msg(msg: "Dict==>")
        for item in arr {
            
            autoreleasepool {
                
                if item.absoluteString.hasSuffix(".h") {
                    
                    var tmpCount = 0
                    
                    var attStringSaySomething:NSAttributedString? = NSAttributedString.init(string: "#import \u{22}" + item.lastPathComponent + "\u{22}", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 16), NSForegroundColorAttributeName:NSColor.black])
                    
                    var searchQuery:String? = attStringSaySomething?.string //item.lastPathComponent //"#import \u{22}" + item.lastPathComponent + "\u{22}"
                    
                    for i in 0...arr.count-1 {
                        
                        autoreleasepool {
                            
                            // Read file content. Example in Swift
                            do {
                                // Read file content
                                var dataObj:Data? = try Data(contentsOf:arr[i])
                                var attibutedString = dataObj!.attributedString
                                var contentFromFile = attibutedString?.string
                                
                                // alternative: not case sensitive
                                let range = contentFromFile!.range(of: searchQuery!, options: .caseInsensitive)
                                if nil != range  {
                                    tmpCount = tmpCount + 1
                                    
//                                    print("\t \t" + arr[i].lastPathComponent)
                                }
                                
                                dataObj = nil
                                attibutedString = nil
                                contentFromFile = nil
                            }
                            catch let error as NSError {
                                msg(msg:"An error took place: \(error)")
                            }
                            
                        }
                    }
                    
                    countDict[searchQuery!] = tmpCount
//                    msg(msg: searchQuery! + " ====> " + String(countDict[searchQuery!]!))
                    
                    attStringSaySomething = nil
                    searchQuery = nil
                    
                    
                }
                let donePercentage = CGFloat((currentProcessingItemIndex+1)*100)/CGFloat(arr.count)
                msg(msg:String(format: "Work done ... %.2f%%", donePercentage))
                
                
                currentProcessingItemIndex += 1
            }
        }
        
        let sortedKeys = countDict.keysSortedByValue(isOrderedBefore: <) //sorting dictionary
//        dict.keysSortedByValue(>) //sorting
//        msg(msg: countDict.description)
        
        msg(msg:"Import count + sorted result")
        for item in sortedKeys {
            msg(msg: item + " ====> " + String(countDict[item]!))
        }
        
    }
    
    func input() -> String {
        let keyboard = FileHandle.standardInput
        let inputData = keyboard.availableData
        return NSString(data: inputData, encoding:String.Encoding.utf8.rawValue)! as String
    }
    
    func cleanFilePath(path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathWithoutEscapedWhitespaces = trimmedPath.replacingOccurrences(of:"\\ ", with: " ")
        return pathWithoutEscapedWhitespaces
    }
    
    func getDirPath(){
        
        msg(msg: "Enter project or search directory path:")
        var response:String? = CommandLine.arguments[1];
        if nil != response && 0 < (response?.characters.count)! {
            dirPath = cleanFilePath(path: response!)
        }else{
            msg(msg: "Invlaid input")
        }
    }
    
    func msg(msg:String) {
        print(msg)
//        DispatchQueue.main.async {
//            print(msg)
//        }
    }
}

let ifObj = ImportFinder()
ifObj.getDirPath()

let sema = DispatchSemaphore( value: 0)
DispatchQueue.global(qos: .background).async {
    
    ifObj.test()
    
    sema.signal();
}
sema.wait();

// Both operations completed


//DispatchQueue.global().async {
    //take dir path
    //    ifObj.getDirPath()
    

//}

//DispatchQueue.main.async(execute: {
//    
//    
////    sema.signal();
//    exit(EXIT_SUCCESS)
//})

//dispatchMain()
//sema.wait();
