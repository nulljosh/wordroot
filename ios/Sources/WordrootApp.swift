import SwiftUI

@main
struct WordrootApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct DefGroup: Identifiable {
    let id = UUID()
    let pos: String
    let defs: [String]
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
    static let langs: [String: String] = [
        "enm": "Middle English", "ang": "Old English", "gmw-pro": "Proto-West Germanic",
        "gem-pro": "Proto-Germanic", "ine-pro": "Proto-Indo-European", "la": "Latin",
        "la-med": "Medieval Latin", "grc": "Ancient Greek", "fro": "Old French",
        "fr": "French", "frm": "Middle French", "non": "Old Norse", "nl": "Dutch",
        "de": "German", "es": "Spanish", "it": "Italian", "itc-pro": "Proto-Italic",
        "ar": "Arabic", "sa": "Sanskrit",
    ]
    static let rels = ["inh": "inherited", "der": "derived", "bor": "borrowed"]

    static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func definitions(_ word: String) async throws -> [DefGroup] {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        guard let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)") else { return [] }
        let (data, resp) = try await URLSession.shared.data(from: url)
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
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parse = root["parse"] as? [String: Any],
              let wikitext = (parse["wikitext"] as? [String: Any])?["*"] as? String else { return [] }
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

    static func entry(_ word: String) async -> Entry? {
        async let g = try? definitions(word)
        async let c = try? etymology(word)
        let (groups, chain) = await (g ?? [], c ?? [])
        if groups.isEmpty && chain.isEmpty { return nil }
        return Entry(word: word, groups: groups, chain: chain)
    }
}

struct ContentView: View {
    @State private var query = ""
    @State private var entry: Entry?
    @State private var loading = false
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
                ForEach(Array(group.defs.enumerated()), id: \.offset) { i, def in
                    Text("\(i + 1). \(def)")
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
    }

    private func search(_ word: String) {
        searchTask?.cancel()
        guard !word.isEmpty else { return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            loading = true
            let result = await Wiktionary.entry(word)
            guard !Task.isCancelled else { return }
            entry = result
            loading = false
        }
    }
}
