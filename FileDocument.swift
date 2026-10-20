import SwiftUI
import UniformTypeIdentifiers

struct KletkaDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    var url: URL?

    init(url: URL?) { self.url = url }

    init(configuration: ReadConfiguration) throws {
        self.url = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url else {
            return FileWrapper(regularFileWithContents: Data())
        }
        return try FileWrapper(url: url, options: .immediate)
    }
}
