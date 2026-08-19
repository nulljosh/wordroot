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

    func testTracesWaterBackToProtoIndoEuropean() throws {
        let chain = try Wiktionary.chain(fromWikitext: waterWikitext)
        XCTAssertEqual(chain.map(\.ancestor), ["water", "wæter", "*watar", "*watōr", "*wódr̥"])
        XCTAssertEqual(chain.last?.lang, "Proto-Indo-European")
        XCTAssertEqual(chain.last?.rel, "derived")
    }

    func testStopsAtTheNextSectionHeading() throws {
        // The IPA template sits past ===Pronunciation===; nothing from there may leak in.
        let chain = try Wiktionary.chain(fromWikitext: waterWikitext)
        XCTAssertFalse(chain.contains { $0.ancestor.contains("ˈwɔːtə") })
    }

    func testUnknownLanguageCodeFallsBackToTheRawCode() throws {
        let chain = try Wiktionary.chain(fromWikitext: "===Etymology===\nFrom {{bor|en|xyz|foo}}.\n")
        XCTAssertEqual(chain.first?.lang, "xyz")
    }

    func testNoEtymologySectionYieldsNothing() throws {
        XCTAssertTrue(try Wiktionary.chain(fromWikitext: "==English==\n\n===Noun===\nA thing.").isEmpty)
    }
}
