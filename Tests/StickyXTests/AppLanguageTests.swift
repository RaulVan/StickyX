import XCTest
@testable import StickyX

final class AppLanguageTests: XCTestCase {
  func testSystemLanguageResolutionFallsBackToEnglish() {
    XCTAssertEqual(AppLanguage.resolvedSystemIdentifier(preferredLanguages: ["zh-Hans-US"]), "zh-Hans")
    XCTAssertEqual(AppLanguage.resolvedSystemIdentifier(preferredLanguages: ["en-US"]), "en")
    XCTAssertEqual(AppLanguage.resolvedSystemIdentifier(preferredLanguages: ["fr-FR"]), "en")
  }

  func testChecklistSummaryIsLocalized() {
    XCTAssertEqual(L10n.checklistSummary(checked: 5, total: 5, language: .zhHans), "5/5 已完成")
    XCTAssertEqual(L10n.checklistSummary(checked: 5, total: 5, language: .en), "5/5 completed")
  }

  func testLanguageNamesAreLocalized() {
    XCTAssertEqual(L10n.languageName(.system, language: .zhHans), "跟随系统")
    XCTAssertEqual(L10n.languageName(.system, language: .en), "Follow System")
    XCTAssertEqual(L10n.languageName(.zhHans, language: .en), "Chinese")
  }

  func testTagColorMenuTitleIsLocalized() {
    XCTAssertEqual(L10n.string(.tagColorMenu, language: .zhHans), "标签颜色")
    XCTAssertEqual(L10n.string(.tagColorMenu, language: .en), "Tag Color")
  }

  func testContextualEmptyStatesAreLocalized() {
    XCTAssertEqual(L10n.string(.noSearchResultsTitle, language: .zhHans), "未找到便笺")
    XCTAssertEqual(L10n.string(.emptyTrashStateTitle, language: .en), "Trash is Empty")
    XCTAssertEqual(L10n.emptyTagTitle("Work", language: .en), "No Notes in Work")
  }
}
