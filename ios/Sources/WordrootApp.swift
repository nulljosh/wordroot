import SwiftUI

@main
struct WordrootApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

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
    let lang: String
    let ancestor: String
}

struct Entry {
    let word: String
    let groups: [DefGroup]
    let chain: [ChainLink]
}

enum Wiktionary {
    // Keep `langs` in sync with LANGS in web/index.html and pipeline/parse.py.
    static let langs: [String: String] = [
        "enm": "Middle English", "ang": "Old English", "gmw-pro": "Proto-West Germanic",
        "gem-pro": "Proto-Germanic", "ine-pro": "Proto-Indo-European", "la": "Latin",
        "la-med": "Medieval Latin", "NL.": "New Latin", "grc": "Ancient Greek",
        "gkm": "Byzantine Greek", "fro": "Old French", "fr": "French",
        "frm": "Middle French", "non": "Old Norse", "nl": "Dutch",
        "de": "German", "es": "Spanish", "it": "Italian", "itc-pro": "Proto-Italic",
        "ar": "Arabic", "sa": "Sanskrit",
    ]
    // Only the three ancestry relations — pipeline/parse.py also collects `cog` and `root`,
    // which are deliberately left out here: cognates are siblings, not links in a chain.
    static let rels = ["inh": "inherited", "der": "derived", "bor": "borrowed"]

    // Wikimedia's UA policy allows throttling or 403ing generic agents.
    static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("wordroot/1.0 (trommatic@icloud.com)", forHTTPHeaderField: "User-Agent")
        return r
    }

    static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func definitions(_ word: String) async throws -> [DefGroup] {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        guard let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)") else { return [] }
        let (data, resp) = try await URLSession.shared.data(for: request(url))
        // 404 just means the word has no entry — not a network failure.
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let en = root["en"] as? [[String: Any]] else { return [] }
        return en.compactMap { e in
            guard let pos = e["partOfSpeech"] as? String,
                  let defs = e["definitions"] as? [[String: Any]] else { return nil }
            let texts = defs.compactMap { $0["definition"] as? String }
                .map(stripTags)
                .filter { !$0.isEmpty }
                .prefix(4)
            return texts.isEmpty ? nil : DefGroup(pos: pos, defs: Array(texts))
        }
    }

    static func etymology(_ word: String) async throws -> [ChainLink] {
        var comps = URLComponents(string: "https://en.wiktionary.org/w/api.php")!
        comps.queryItems = [
            .init(name: "action", value: "parse"), .init(name: "page", value: word),
            .init(name: "prop", value: "wikitext"), .init(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(for: request(comps.url!))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parse = root["parse"] as? [String: Any],
              let wikitext = (parse["wikitext"] as? [String: Any])?["*"] as? String else { return [] }
        return try chain(fromWikitext: wikitext)
    }

    /// Pure: wikitext in, ancestry chain out. Split from `etymology` so it is testable offline.
    static func chain(fromWikitext wikitext: String) throws -> [ChainLink] {
        guard let secRange = wikitext.range(of: "===?Etymology[^=]*===?\\n", options: .regularExpression) else { return [] }
        let after = wikitext[secRange.upperBound...]
        let section = after.range(of: "\\n===?[^=]", options: .regularExpression)
            .map { String(after[..<$0.lowerBound]) } ?? String(after)
        let re = try NSRegularExpression(pattern: "\\{\\{(inh\\+?|der\\+?|bor\\+?)\\|[^|]*\\|([^|}]+)\\|([^|}]*)")
        let ns = section as NSString
        var chain: [ChainLink] = []
        for m in re.matches(in: section, range: NSRange(location: 0, length: ns.length)) {
            let relKey = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: "+", with: "")
            let langKey = ns.substring(with: m.range(at: 2))
            let ancestor = ns.substring(with: m.range(at: 3))
            guard let rel = rels[relKey], !ancestor.isEmpty else { continue }
            chain.append(ChainLink(rel: rel, lang: langs[langKey] ?? langKey, ancestor: ancestor))
            if chain.count >= 10 { break }
        }
        return chain
    }

    /// Throws only on transport failure, so the UI can tell "offline" from "no such word".
    static func entry(_ word: String) async throws -> Entry? {
        async let g = definitions(word)
        async let c = etymology(word)
        let (groups, chain) = try await (g, c)
        if groups.isEmpty && chain.isEmpty { return nil }
        return Entry(word: word, groups: groups, chain: chain)
    }
}

struct ContentView: View {
    @State private var query = ""
    @State private var entry: Entry?
    @State private var loading = false
    @State private var failed = false
    @State private var searchTask: Task<Void, Never>?

    static let wotd = ["water", "mother", "star", "night", "heart", "fire", "wind", "tooth", "name", "wolf",
                       "snow", "honey", "door", "ear", "foot", "knee", "sun", "moon", "salt", "seed",
                       "yoke", "new", "red", "three", "brother"]

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    loadingRow
                } else if let entry {
                    if query.isEmpty {
                        Section {} header: { Text("Word of the day: \(entry.word)") }
                    }
                    entrySections(entry)
                } else if failed {
                    // Reachable on launch with an empty query, so it cannot be gated on `query`.
                    Text("Couldn't reach Wiktionary. Check your connection.")
                        .foregroundStyle(.secondary)
                } else if !query.isEmpty {
                    Text("Nothing found.").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Look up a word")
            .navigationTitle(entry?.word.capitalized ?? "Wordroot")
            .onChange(of: query) { _, q in
                search(q.trimmingCharacters(in: .whitespaces).lowercased())
            }
            .task {
                let day = Int(Date().timeIntervalSince1970 / 86400)
                search(Self.wotd[day % Self.wotd.count])
            }
        }
    }

    private var loadingRow: some View {
        HStack { Spacer(); ProgressView(); Spacer() }
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
            Section("Origin") {
                ForEach(entry.chain) { link in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.ancestor).fontWeight(.semibold)
                        Text("\(link.rel) · \(link.lang)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // CC BY-SA 4.0 requires attribution; App Review flags uncredited third-party content.
        Section {
            Text("Definitions and etymologies from Wiktionary (CC BY-SA 4.0)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func search(_ word: String) {
        searchTask?.cancel()
        guard !word.isEmpty else { return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            loading = true
            // Not `try?`: it flattens Entry?? to Entry?, which would merge a transport
            // failure back into the "no such word" case this whole branch exists to separate.
            do {
                let result = try await Wiktionary.entry(word)
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
