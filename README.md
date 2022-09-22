# Djvu in swift

An library to simple decode and display `djvu` files in iOS, iPadOS, and MacOS

```swift
let djvuBook = Bundle.main.url(forResource: "book1", withExtension: "djvu")!
let djvu = try! Djvu(url: djvuBook)
debugPrint("pages in djvu: \(djvu.numberOfPages)")
let image: UIImage = try! djvu.getImage(page: 12, dpi: 320)
// or display djvu page in thumbnail
let image: UIImage = try! djvu.getImage(page: 12, dpi: 320, maxSideSize: 640)
```
