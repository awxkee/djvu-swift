//
//  Djvu.swift
//  
//
//  Created by Radzivon Bartoshyk on 22/09/2022.
//

import Foundation
#if canImport(libdjvu)
import libdjvu
#endif
#if !os(macOS)
import UIKit.UIImage
import UIKit.UIColor
/// Alias for `UIImage`.
public typealias PlatformImage = UIImage
#else
import AppKit.NSImage
/// Alias for `NSImage`.
public typealias PlatformImage = NSImage
#endif

public class Djvu {

    private let parser: DjvuParser

    public init(url: URL) throws {
        parser = try DjvuParser(path: url.path)
    }

    public func getImage(page: Int, dpi: Int) throws -> PlatformImage {
        return try parser.image(forPage: UInt(page), dpi: UInt(dpi))
    }

    public func getImage(page: Int, dpi: Int, maxSideSize: Int) throws -> PlatformImage {
        return try parser.image(forPage: UInt(page), dpi: UInt(dpi), maxSideSize: UInt(maxSideSize))
    }

    public func getPageText(page: Int) throws -> String {
        return try parser.getPageText(UInt(page))
    }

    public func dump() throws -> String {
        return try parser.getDocumentDump()
    }

    public func close() {
        parser.close()
    }

    public var numberOfPages: Int {
        Int(parser.numberOfPages)
    }

}
