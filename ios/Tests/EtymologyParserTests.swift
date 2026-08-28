import XCTest
@testable import Wordroot

// The etymology parser is the only nontrivial logic in the app and the one piece a
// Wiktionary markup change can silently break. Fixture in, chain out — no network.
final class EtymologyParserTests: XCTestCase {
    private let waterWikitext = """
    ==English==

    ===Etymology===
    From {{inh|en|enm|water}}, from {{inh|en|ang|wæter}}, from {{inh|en|gmw-pro|*watar}},
    from {{inh|en|gem-pro|*watōr}}, from {{der|en|ine-pro|*wódr̥}}.

    ===Pronunciation===
    * {{IPA|en|/ˈwɔːtə/}}
    """

    // One page, two languages, two unrelated histories. Reading the first ===Etymology===
    // on the page rather than the selected language's returns somebody else's ancestry.
    private let chatWikitext = """
    ==English==

    ===Etymology===
    From {{inh|en|enm|chat}}, from {{der|en|ang|ceatian}}.

    ===Noun===
    Informal talk.

    ==French==

    ===Etymology===
    From {{inh|fr|fro|chat}}, from {{inh|fro|la|cattus}}.

    ===Noun===
    Cat.
    """

    func testTracesWaterBackToProtoIndoEuropean() throws {
        let chain = try Wiktionary.chain(fromWikitext: waterWikitext, section: "English")
        XCTAssertEqual(chain.map(\.ancestor), ["water", "wæter", "*watar", "*watōr", "*wódr̥"])
        XCTAssertEqual(chain.last?.langCode, "ine-pro")
        XCTAssertEqual(chain.last?.rel, "rel.derived")
    }

    func testStopsAtTheNextSectionHeading() throws {
        // The IPA template sits past ===Pronunciation===; nothing from there may leak in.
        let chain = try Wiktionary.chain(fromWikitext: waterWikitext, section: "English")
        XCTAssertFalse(chain.contains { $0.ancestor.contains("ˈwɔːtə") })
    }

    func testReadsTheEtymologyOfTheRequestedLanguage() throws {
        let english = try Wiktionary.chain(fromWikitext: chatWikitext, section: "English")
        XCTAssertEqual(english.map(\.ancestor), ["chat", "ceatian"])
        let french = try Wiktionary.chain(fromWikitext: chatWikitext, section: "French")
        XCTAssertEqual(french.map(\.ancestor), ["chat", "cattus"])
    }

    func testDoesNotRunPastTheEndOfItsLanguageSection() throws {
        let english = try Wiktionary.chain(fromWikitext: chatWikitext, section: "English")
        XCTAssertFalse(english.contains { $0.ancestor == "cattus" }, "French ancestry leaked in")
    }

    func testLanguageWithNoSectionOnThePageYieldsNothing() throws {
        XCTAssertTrue(try Wiktionary.chain(fromWikitext: chatWikitext, section: "Japanese").isEmpty)
    }

    func testUnknownLanguageCodeIsKeptVerbatim() throws {
        let chain = try Wiktionary.chain(
            fromWikitext: "==English==\n\n===Etymology===\nFrom {{bor|en|xyz|foo}}.\n",
            section: "English")
        XCTAssertEqual(chain.first?.langCode, "xyz")
    }

    func testNoEtymologySectionYieldsNothing() throws {
        XCTAssertTrue(try Wiktionary.chain(
            fromWikitext: "==English==\n\n===Noun===\nA thing.", section: "English").isEmpty)
    }
}

// Language negotiation decides what every reader sees on first launch, so it is worth
// pinning down; `Settings` resolves against the generated catalog, with no I/O.
final class LanguageNegotiationTests: XCTestCase {
    func testMatchesShippedLocalesExactly() {
        XCTAssertEqual(Settings.resolve("fr"), "fr")
        XCTAssertEqual(Settings.resolve("ar"), "ar")
    }

    func testFallsBackFromARegionalTagToItsBaseLanguage() {
        XCTAssertEqual(Settings.resolve("pt-BR"), "pt")
        XCTAssertEqual(Settings.resolve("de_AT"), "de")
    }

    func testEveryChineseVariantLandsOnTheScriptWeShip() {
        for tag in ["zh", "zh-CN", "zh-Hans", "zh-Hant-TW"] {
            XCTAssertEqual(Settings.resolve(tag), "zh-Hans", tag)
        }
    }

    func testUnshippedLanguageDoesNotMatch() {
        XCTAssertNil(Settings.resolve("sw-KE"))
        XCTAssertNil(Settings.resolve(""))
        XCTAssertNil(Settings.resolve(nil))
    }

    func testWordLanguageDefaultsToTheInterfaceLanguageWhereADictionaryExists() {
        XCTAssertEqual(Settings.defaultWordLanguage(for: "fr"), "fr")
        XCTAssertEqual(Settings.defaultWordLanguage(for: "zh-Hans"), "zh")
        XCTAssertEqual(Settings.defaultWordLanguage(for: "en"), "en")
    }
}

// The catalog is generated, so these guard the generator's output rather than hand-written
// data: a surface that renders a key with no translation would fall back to English silently.
final class CatalogTests: XCTestCase {
    func testEveryLocaleTranslatesEveryKey() {
        let english = Catalog.tables["en"]!
        for language in Catalog.uiLanguages {
            let table = Catalog.tables[language.code]
            XCTAssertNotNil(table, "no table for \(language.code)")
            for key in english.keys {
                XCTAssertNotNil(table?[key], "\(language.code) is missing \(key)")
            }
        }
    }

    func testArabicIsTheOnlyRightToLeftLocale() {
        XCTAssertEqual(Catalog.uiLanguages.filter(\.isRightToLeft).map(\.code), ["ar"])
    }

    func testEveryWordOfTheDayListBelongsToAWordLanguage() {
        let codes = Set(Catalog.wordLanguages.map(\.code))
        for code in Catalog.wordsOfTheDay.keys {
            XCTAssertTrue(codes.contains(code), "\(code) has a word list but is not selectable")
        }
    }
}
