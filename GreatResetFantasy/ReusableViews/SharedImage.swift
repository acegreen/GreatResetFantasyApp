import SwiftUI
import UIKit
import CoreTransferable
import UniformTypeIdentifiers

struct SharedImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shared in
            shared.image.pngData() ?? Data()
        }
    }
}
