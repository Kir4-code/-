import Foundation
import UIKit

enum NotebookExport {

    static func export(_ notebook: Notebook, store: NotebookStore) throws -> URL {
        var imagesB64: [String: String] = [:]
        for item in notebook.items {
            if case .image(let img) = item {
                if let url = store.imageURL(fileName: img.fileName),
                   let data = try? Data(contentsOf: url) {
                    imagesB64[img.fileName] = data.base64EncodedString()
                }
            }
        }
        let envelope = Envelope(notebook: notebook, images: imagesB64)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(envelope)

        let safe = safeName(notebook.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).kletka")
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url)
        return url
    }

    static func importNotebook(from url: URL, store: NotebookStore) throws -> Notebook {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)

        var nb = envelope.notebook
        nb.id = UUID()
        nb.updated = Date()

        let dir = store.imagesDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, b64) in envelope.images {
            if let d = Data(base64Encoded: b64) {
                try? d.write(to: dir.appendingPathComponent(name))
            }
        }
        return nb
    }

    private struct Envelope: Codable {
        var notebook: Notebook
        var images: [String: String]
    }

    private static func safeName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let trimmed = s.components(separatedBy: bad).joined(separator: "_")
        return trimmed.isEmpty ? "notebook" : trimmed
    }
}
