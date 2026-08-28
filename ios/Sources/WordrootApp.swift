import Combine
import SwiftUI

@main
struct WordrootApp: App {
    @StateObject private var settings = Settings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                // Driving locale and layout direction from the in-app choice rather than from
                // the system means picking Arabic mirrors the whole interface even on a device
                // set to English — the picker would otherwise change only the words.
                .environment(\.locale, Locale(identifier: settings.uiLanguage))
                .environment(\.layoutDirection, settings.isRightToLeft ? .rightToLeft : .leftToRight)
        }
    }
}

// MARK: - Language settings

/// Interface and word language, persisted across launches.
///
/// Strings resolve through `Catalog` rather than `NSLocalizedString` so that the in-app picker
/// is authoritative: bundle localization can only follow the system language, and a reader who
/// wants a Spanish interface on an English device is exactly the case this app is adding.
final class Settings: ObservableObject {
    private static let uiKey = "wordroot.uiLanguage"
    private static let wordKey = "wordroot.wordLanguage"

    @Published var uiLanguage: String { didSet { UserDefaults.standard.set(uiLanguage, forKey: Self.uiKey) } }
    @Published var wordLanguage: String { didSet { UserDefaults.standard.set(wordLanguage, forKey: Self.wordKey) } }

    init() {
        let defaults = UserDefaults.standard
        let ui = Self.resolve(defaults.string(forKey: Self.uiKey)) ?? Self.systemLanguage()
        uiLanguage = ui
        let stored = defaults.string(forKey: Self.wordKey)
        wordLanguage = Catalog.wordLanguages.first { $0.code == stored }?.code
            ?? Self.defaultWordLanguage(for: ui)
    }

    var isRightToLeft: Bool {
        Catalog.uiLanguages.first { $0.code == uiLanguage }?.isRightToLeft ?? false
    }

    var word: WordLanguage {
        Catalog.wordLanguages.first { $0.code == wordLanguage } ?? Catalog.wordLanguages[0]
    }

    /// Translate `key`, substituting `{name}` placeholders.
    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        let table = Catalog.tables[uiLanguage] ?? Catalog.tables["en"]
        var s = table?[key] ?? Catalog.tables["en"]?[key] ?? key
        for (name, value) in vars { s = s.replacingOccurrences(of: "{\(name)}", with: value) }
        return s
    }

    /// Localized name for a language code out of a Wiktionary etymology template.
    /// Hand translations first, then the system's own CLDR data, then English, then the raw code.
    func languageName(_ code: String) -> String {
        if Catalog.tables["en"]?["lang.\(code)"] != nil { return t("lang.\(code)") }
        if let localized = Locale(identifier: uiLanguage).localizedString(forLanguageCode: code),
           localized != code {
            return localized
        }
        return Catalog.ancestorLanguages[code] ?? code
    }

    /// Match a stored or system tag to a shipped locale: exact, then progressively shorter,
    /// with every Chinese variant landing on the one script we ship.
    static func resolve(_ tag: String?) -> String? {
        guard var tag = tag?.replacingOccurrences(of: "_", with: "-"), !tag.isEmpty else { return nil }
        if tag.lowercased() == "zh" || tag.lowercased().hasPrefix("zh-") {
            return Catalog.uiLanguages.contains { $0.code == "zh-Hans" } ? "zh-Hans" : nil
        }
        while !tag.isEmpty {
            if let hit = Catalog.uiLanguages.first(where: { $0.code.caseInsensitiveCompare(tag) == .orderedSame }) {
                return hit.code
            }
            guard let cut = tag.lastIndex(of: "-") else { break }
            tag = String(tag[..<cut])
        }
        return nil
    }

    static func systemLanguage() -> String {
        Locale.preferredLanguages.lazy.compactMap { resolve($0) }.first ?? "en"
    }

    /// Look words up in the interface language when we have a dictionary for it.
    static func defaultWordLanguage(for ui: String) -> String {
        let base = ui.split(separator: "-").first.map(String.init) ?? ui  // zh-Hans -> zh
        return Catalog.wordLanguages.contains { $0.code == base } ? base : "en"
    }
}

// MARK: - Model

struct Def: Identifiable {
    let id: String
    let n: Int
    let text: String
}

struct DefGroup: Identifiable {
    let id = UUID()
    let pos: String
    let defs: [String]

    // ponytail: rows need ids unique across sections, not just within one —
    // on macOS a bare offset id makes every section render the first one's rows.
    var items: [Def] {
        defs.enumerated().map { Def(id: "\(id)-\($0.offset)", n: $0.offset + 1, text: $0.element) }
    }
}

struct ChainLink: Identifiable {
    let id = UUID()
    let rel: String
    let langCode: String
    let ancestor: String
}

struct Entry {
    let word: String
    let groups: [DefGroup]
    let chain: [ChainLink]
}

// MARK: - Wiktionary

enum Wiktionary {
    /// Every lookup runs against the English Wiktionary whatever the interface language is: it
    /// carries entries for thousands of languages under one consistent set of etymology
    /// templates, whereas each other edition uses its own incompatible markup. The word
    /// language selects which `==Language==` section of the page to read.
    static let host = "https://en.wiktionary.org"

    // Only the three ancestry relations — pipeline/parse.py also collects `cog` and `root`,
    // which are deliberately left out here: cognates are siblings, not links in a chain.
    static let rels = ["inh": "rel.inherited", "der": "rel.derived", "bor": "rel.borrowed"]

    // Wikimedia's UA policy allows throttling or 403ing generic agents.
    static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("wordroot/1.0 (trommatic@icloud.com)", forHTTPHeaderField: "User-Agent")
        return r
    }

    static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func definitions(_ word: String, language: String) async throws -> [DefGroup] {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        guard let url = URL(string: "\(host)/api/rest_v1/page/definition/\(encoded)") else { return [] }
        let (data, resp) = try await URLSession.shared.data(for: request(url))
        // 404 just means the word has no entry — not a network failure.
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              // Keyed by the language of each section on the page, so "chat" carries both an
              // `en` and an `fr` entry. Taking only the requested one is what makes the picker
              // mean anything; a page with no section in that language is a miss, not English.
              let entries = root[language] as? [[String: Any]] else { return [] }
        return entries.compactMap { e in
            guard let pos = e["partOfSpeech"] as? String,
                  let defs = e["definitions"] as? [[String: Any]] else { return nil }
            let texts = defs.compactMap { $0["definition"] as? String }
                .map(stripTags)
                .filter { !$0.isEmpty }
                .prefix(4)
            return texts.isEmpty ? nil : DefGroup(pos: pos, defs: Array(texts))
        }
    }

    static func etymology(_ word: String, section: String) async throws -> [ChainLink] {
        var comps = URLComponents(string: "\(host)/w/api.php")!
        comps.queryItems = [
            .init(name: "action", value: "parse"), .init(name: "page", value: word),
            .init(name: "prop", value: "wikitext"), .init(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(for: request(comps.url!))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parse = root["parse"] as? [String: Any],
              let wikitext = (parse["wikitext"] as? [String: Any])?["*"] as? String else { return [] }
        return try chain(fromWikitext: wikitext, section: section)
    }

    /// Body of the `==Name==` language section, or nil. Stops at the next level-2 heading.
    static func languageSection(_ wikitext: String, named name: String) -> Substring? {
        let pattern = "(?m)^==\\s*\(NSRegularExpression.escapedPattern(for: name))\\s*==\\s*$"
        guard let heading = wikitext.range(of: pattern, options: .regularExpression) else { return nil }
        let after = wikitext[heading.upperBound...]
        guard let next = after.range(of: "(?m)^==[^=]", options: .regularExpression) else { return after }
        return after[..<next.lowerBound]
    }

    /// Pure: wikitext in, ancestry chain out. Split from `etymology` so it is testable offline.
    static func chain(fromWikitext wikitext: String, section name: String) throws -> [ChainLink] {
        // Without this scoping the first ===Etymology=== on the page wins, which for a word
        // spelled the same in several languages ("chat") is somebody else's history.
        guard let section = languageSection(wikitext, named: name) else { return [] }
        guard let secRange = section.range(of: "===?Etymology[^=]*===?\\n", options: .regularExpression) else { return [] }
        let after = section[secRange.upperBound...]
        let body = after.range(of: "\\n===?[^=]", options: .regularExpression)
            .map { String(after[..<$0.lowerBound]) } ?? String(after)
        let re = try NSRegularExpression(pattern: "\\{\\{(inh\\+?|der\\+?|bor\\+?)\\|[^|]*\\|([^|}]+)\\|([^|}]*)")
        let ns = body as NSString
        var chain: [ChainLink] = []
        for m in re.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
            let relKey = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: "+", with: "")
            let langKey = ns.substring(with: m.range(at: 2))
            let ancestor = ns.substring(with: m.range(at: 3))
            guard let rel = rels[relKey], !ancestor.isEmpty else { continue }
            chain.append(ChainLink(rel: rel, langCode: langKey, ancestor: ancestor))
            if chain.count >= 10 { break }
        }
        return chain
    }

    /// Throws only on transport failure, so the UI can tell "offline" from "no such word".
    static func entry(_ word: String, language: WordLanguage) async throws -> Entry? {
        async let g = definitions(word, language: language.code)
        async let c = etymology(word, section: language.section)
        let (groups, chain) = try await (g, c)
        if groups.isEmpty && chain.isEmpty { return nil }
        return Entry(word: word, groups: groups, chain: chain)
    }
}

// MARK: - UI

struct ContentView: View {
    @EnvironmentObject private var settings: Settings
    @State private var query = ""
    @State private var entry: Entry?
    @State private var loading = false
    @State private var failed = false
    @State private var showingSettings = false
    @State private var searchTask: Task<Void, Never>?

    /// Today's word in the current word language, or nil if we ship no list for it —
    /// better than offering an English word that has no entry in the selected language.
    private var wordOfTheDay: String? {
        guard let list = Catalog.wordsOfTheDay[settings.wordLanguage], !list.isEmpty else { return nil }
        return list[Int(Date().timeIntervalSince1970 / 86400) % list.count]
    }

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let entry {
                    if query.isEmpty {
                        Section {} header: { Text(settings.t("ui.wotdWord", ["word": entry.word])) }
                    }
                    entrySections(entry)
                } else if failed {
                    // Reachable on launch with an empty query, so it cannot be gated on `query`.
                    Text(settings.t("ui.offline")).foregroundStyle(.secondary)
                } else if !query.isEmpty {
                    Text(settings.t("ui.nothingFound")).foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: Text(settings.t("ui.searchPlaceholder")))
            .navigationTitle(entry?.word.capitalized ?? "Wordroot")
            .toolbar {
                Button {
                    showingSettings = true
                } label: {
                    Label(settings.t("ui.settings"), systemImage: "globe")
                }
            }
            .sheet(isPresented: $showingSettings) {
                LanguageSettingsView()
                    .environmentObject(settings)
                    .environment(\.locale, Locale(identifier: settings.uiLanguage))
                    .environment(\.layoutDirection, settings.isRightToLeft ? .rightToLeft : .leftToRight)
            }
            .onChange(of: query) { _, q in
                search(q.trimmingCharacters(in: .whitespaces).lowercased())
            }
            // Switching either language invalidates what is on screen: a word only exists in
            // one language, and the chain's labels are rendered in the interface language.
            .onChange(of: settings.wordLanguage) { _, _ in
                query = ""
                entry = nil
                if let w = wordOfTheDay { search(w) }
            }
            .task {
                if let w = wordOfTheDay { search(w) }
            }
        }
    }

    @ViewBuilder
    private func entrySections(_ entry: Entry) -> some View {
        ForEach(entry.groups) { group in
            Section(group.pos) {
                ForEach(group.items) { def in
                    Text("\(def.n). \(def.text)")
                }
            }
        }
        if !entry.chain.isEmpty {
            Section(settings.t("ui.origin")) {
                ForEach(entry.chain) { link in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.ancestor).fontWeight(.semibold)
                        // Ancestor first, relation and language beneath: a single run-on line
                        // cannot be reordered per language, and word order differs across the
                        // twelve locales.
                        Text(verbatim: "\(settings.t(link.rel)) · \(settings.languageName(link.langCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // CC BY-SA 4.0 requires attribution; App Review flags uncredited third-party content.
        Section {
            Text(settings.t("ui.attribution"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func search(_ word: String) {
        searchTask?.cancel()
        guard !word.isEmpty else { return }
        let language = settings.word
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            loading = true
            // Not `try?`: it flattens Entry?? to Entry?, which would merge a transport
            // failure back into the "no such word" case this whole branch exists to separate.
            do {
                let result = try await Wiktionary.entry(word, language: language)
                guard !Task.isCancelled else { return }
                entry = result
                failed = false
            } catch {
                guard !Task.isCancelled else { return }
                entry = nil
                failed = true
            }
            loading = false
        }
    }
}

struct LanguageSettingsView: View {
    @EnvironmentObject private var settings: Settings
    @Environment(\.dismiss) private var dismiss

    /// Word languages sorted by their name in the reader's own language.
    private var wordLanguages: [WordLanguage] {
        Catalog.wordLanguages.sorted {
            settings.languageName($0.code)
                .localizedCaseInsensitiveCompare(settings.languageName($1.code)) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.t("ui.interfaceLanguage")) {
                    Picker(settings.t("ui.interfaceLanguage"), selection: $settings.uiLanguage) {
                        ForEach(Catalog.uiLanguages) { language in
                            // The endonym, so a reader can find their language without already
                            // being able to read the current one.
                            Text(language.endonym).tag(language.code)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }
                Section(settings.t("ui.wordLanguage")) {
                    Picker(settings.t("ui.wordLanguage"), selection: $settings.wordLanguage) {
                        ForEach(wordLanguages) { language in
                            Text(settings.languageName(language.code)).tag(language.code)
                        }
                    }
                    .labelsHidden()
                }
            }
            .navigationTitle(settings.t("ui.settings"))
            .toolbar {
                Button(settings.t("ui.done")) { dismiss() }
            }
        }
    }
}
