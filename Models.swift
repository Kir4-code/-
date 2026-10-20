import Foundation
import CoreGraphics
import UIKit

// MARK: - Цвета

enum InkColor: String, Codable, CaseIterable, Identifiable {
    case ink, blue, red, green, violet, orange
    var id: String { rawValue }

    var lightHex: String {
        switch self {
        case .ink:    return "#1b2233"
        case .blue:   return "#2250d8"
        case .red:    return "#d63a30"
        case .green:  return "#17894f"
        case .violet: return "#7340d1"
        case .orange: return "#e46f0a"
        }
    }
    var darkHex: String {
        switch self {
        case .ink:    return "#e8ecf5"
        case .blue:   return "#7da3ff"
        case .red:    return "#ff7b70"
        case .green:  return "#4fd592"
        case .violet: return "#b894ff"
        case .orange: return "#ffa44c"
        }
    }
}

enum HighlighterColor: String, Codable, CaseIterable, Identifiable {
    case yellow, green, pink, blue, orange
    var id: String { rawValue }
    var hex: String {
        switch self {
        case .yellow: return "#ffd426"
        case .green:  return "#4ddc8a"
        case .pink:   return "#ff78b5"
        case .blue:   return "#4cc4ff"
        case .orange: return "#ff9a3d"
        }
    }
}

enum StickerColor: String, Codable, CaseIterable, Identifiable {
    case yellow, pink, mint, sky, lilac, peach
    var id: String { rawValue }
    var hex: String {
        switch self {
        case .yellow: return "#ffe680"
        case .pink:   return "#ffc2d9"
        case .mint:   return "#b8efd0"
        case .sky:    return "#bfe3ff"
        case .lilac:  return "#dccbff"
        case .peach:  return "#ffd2b0"
        }
    }
}

enum CoverColor: String, Codable, CaseIterable, Identifiable {
    case blue, red, green, orange, violet, teal, graphite
    var id: String { rawValue }
    var hex: String {
        switch self {
        case .blue:     return "#2f5bd8"
        case .red:      return "#cf3a3a"
        case .green:    return "#1f8f5f"
        case .orange:   return "#e6791a"
        case .violet:   return "#7446c9"
        case .teal:     return "#168aa0"
        case .graphite: return "#3b4252"
        }
    }
}

// MARK: - Инструменты

enum ToolKind: String, Codable, CaseIterable, Identifiable {
    case pen, pencil, highlighter, eraser, line, dash, sticker, image, hand
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen:         return "Ручка"
        case .pencil:      return "Карандаш"
        case .highlighter: return "Маркер"
        case .eraser:      return "Ластик"
        case .line:        return "Линия"
        case .dash:        return "Пунктир"
        case .sticker:     return "Стикер"
        case .image:       return "Фото"
        case .hand:        return "Двигать"
        }
    }

    var isDrawing: Bool {
        switch self {
        case .pen, .pencil, .highlighter: return true
        default: return false
        }
    }
}

// MARK: - Штрих

struct Stroke: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: ToolKind
    var colorHex: String
    var width: CGFloat
    var points: [CGPoint]
    var pressures: [CGFloat]
    var createdAt: Date = Date()

    private enum CodingKeys: String, CodingKey {
        case id, kind, colorHex, width, points, pressures, createdAt
    }

    init(kind: ToolKind, colorHex: String, width: CGFloat, points: [CGPoint], pressures: [CGFloat]) {
        self.kind = kind
        self.colorHex = colorHex
        self.width = width
        self.points = points
        self.pressures = pressures
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(ToolKind.self, forKey: .kind)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        width = try c.decode(CGFloat.self, forKey: .width)
        let raw = try c.decode([CGPointCodable].self, forKey: .points)
        points = raw.map { $0.point }
        pressures = try c.decode([CGFloat].self, forKey: .pressures)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(width, forKey: .width)
        try c.encode(points.map { CGPointCodable(point: $0) }, forKey: .points)
        try c.encode(pressures, forKey: .pressures)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

struct CGPointCodable: Codable {
    let x: CGFloat
    let y: CGFloat
    init(point: CGPoint) { self.x = point.x; self.y = point.y }
    var point: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Линия

struct LineShape: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var dashed: Bool
    var colorHex: String
    var width: CGFloat
    var start: CGPoint
    var end: CGPoint

    private enum CodingKeys: String, CodingKey { case id, dashed, colorHex, width, start, end }

    init(dashed: Bool, colorHex: String, width: CGFloat, start: CGPoint, end: CGPoint) {
        self.dashed = dashed
        self.colorHex = colorHex
        self.width = width
        self.start = start
        self.end = end
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        dashed = try c.decode(Bool.self, forKey: .dashed)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        width = try c.decode(CGFloat.self, forKey: .width)
        start = try c.decode(CGPointCodable.self, forKey: .start).point
        end = try c.decode(CGPointCodable.self, forKey: .end).point
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(dashed, forKey: .dashed)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(width, forKey: .width)
        try c.encode(CGPointCodable(point: start), forKey: .start)
        try c.encode(CGPointCodable(point: end), forKey: .end)
    }
}

// MARK: - Стикер

struct Sticker: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var color: StickerColor
    var frame: CGRect
    var text: String
}

// MARK: - Вставка картинок

struct ImageItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var frame: CGRect
    var fileName: String
}

// MARK: - Элемент холста

enum CanvasItem: Codable, Identifiable, Equatable {
    case stroke(Stroke)
    case line(LineShape)
    case sticker(Sticker)
    case image(ImageItem)

    var id: UUID {
        switch self {
        case .stroke(let s):  return s.id
        case .line(let l):    return l.id
        case .sticker(let k): return k.id
        case .image(let i):   return i.id
        }
    }
}

// MARK: - Тетрадь

struct Notebook: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var cover: CoverColor
    var items: [CanvasItem]
    var viewX: CGFloat = 0
    var viewY: CGFloat = 0
    var viewScale: CGFloat = 1
    var updated: Date = Date()
    var coverImageFileName: String? = nil

    static func new(name: String, cover: CoverColor) -> Notebook {
        Notebook(name: name, cover: cover, items: [])
    }
}

// MARK: - Настройки инструментов

struct ToolPreferences: Codable, Equatable {
    var selectedTool: ToolKind = .pen

    var penColor: InkColor = .ink
    var penSize: Int = 1

    var pencilColor: InkColor = .ink
    var pencilSize: Int = 1

    var highlighterColor: HighlighterColor = .yellow
    var highlighterSize: Int = 1

    var eraserSize: Int = 1

    var lineColor: InkColor = .ink
    var lineSize: Int = 1

    var dashColor: InkColor = .ink
    var dashSize: Int = 1

    var stickerColor: StickerColor = .yellow

    var fingerDraws: Bool = true
    var snapToGrid: Bool = true
    var snapAxis: Bool = true
    var straightenOnHold: Bool = true
}

// MARK: - Размеры

enum ToolSizes {
    static func inkWidth(for tool: ToolKind, sizeIndex: Int) -> CGFloat {
        let idx = max(0, min(3, sizeIndex))
        switch tool {
        case .pen:         return [1.6, 2.6, 4.0, 6.5][idx]
        case .pencil:      return [1.2, 2.0, 3.0, 4.5][idx]
        case .highlighter: return [12.0, 18.0, 26.0, 36.0][idx]
        case .line, .dash: return [1.6, 2.6, 4.0, 6.5][idx]
        default:           return 2.0
        }
    }

    static func eraserRadius(sizeIndex: Int) -> CGFloat {
        let idx = max(0, min(3, sizeIndex))
        return [10.0, 18.0, 30.0, 46.0][idx]
    }
}

// MARK: - Перевод из хекса

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b: CGFloat
        if s.count == 6 {
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
