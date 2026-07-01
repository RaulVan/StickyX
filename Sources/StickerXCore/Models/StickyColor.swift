import Foundation

public enum StickyColor: String, CaseIterable, Codable, Identifiable, Sendable {
  case yellow
  case blue
  case green
  case gray
  case pink
  case purple

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .yellow: "黄色"
    case .blue: "蓝色"
    case .green: "绿色"
    case .gray: "灰色"
    case .pink: "粉红色"
    case .purple: "紫色"
    }
  }
}
