import AppKit
import XCTest
@testable import StickyX

final class StickyTextFormatterTests: XCTestCase {
  func testChecklistMarkersUseUniformAttributes() throws {
    let attributed = NSMutableAttributedString()
    attributed.append(NSAttributedString(
      string: "☐ First\n",
      attributes: [
        .font: NSFont.systemFont(ofSize: 28),
        .foregroundColor: NSColor.systemRed
      ]
    ))
    attributed.append(NSAttributedString(
      string: "☑ Second\n",
      attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
        .foregroundColor: NSColor.systemBlue
      ]
    ))
    attributed.append(NSAttributedString(
      string: "Plain ☐ body",
      attributes: [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.systemGreen
      ]
    ))

    let normalized = StickyTextFormatter.normalizedChecklistMarkers(in: attributed)
    let firstFont = try XCTUnwrap(normalized.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
    let secondLocation = ("☐ First\n" as NSString).length
    let secondFont = try XCTUnwrap(normalized.attribute(.font, at: secondLocation, effectiveRange: nil) as? NSFont)
    let firstColor = try XCTUnwrap(normalized.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
    let secondColor = try XCTUnwrap(normalized.attribute(.foregroundColor, at: secondLocation, effectiveRange: nil) as? NSColor)

    XCTAssertEqual(firstFont.fontName, secondFont.fontName)
    XCTAssertEqual(firstFont.pointSize, secondFont.pointSize, accuracy: 0.01)
    XCTAssertEqual(firstColor.usingColorSpace(.deviceRGB), secondColor.usingColorSpace(.deviceRGB))

    let bodyMarkerLocation = (normalized.string as NSString).range(of: "Plain ☐").location + 6
    let bodyFont = try XCTUnwrap(normalized.attribute(.font, at: bodyMarkerLocation, effectiveRange: nil) as? NSFont)
    XCTAssertEqual(bodyFont.pointSize, 12, accuracy: 0.01)
  }
}
