import Foundation
import SwiftTUI

// ponytail: hits the same live /api/word endpoint the web/iOS app calls — wordroot's
// logic is a Cloudflare Function, not a local Swift model, so there's nothing to port.
// `wordroot-tui <word>` fetches once and renders a card, same static-render shape as
// nimble-tui/cadence-tui.

struct Definition: Decodable { let pos: String; let definitions: [String] }
struct Ancestor: Decodable { let relation: String; let langCode: String; let ancestor: String }
struct WordResult: Decodable {
    let word: String
    let language: String
    let definitions: [Definition]
    let etymology: [Ancestor]
}

let args = CommandLine.arguments.dropFirst()
guard let word = args.first else {
    print("usage: wordroot-tui <word>")
    exit(1)
}

func fetchWord(_ word: String) async -> WordResult? {
    guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let url = URL(string: "https://wordroot.heyitsmejosh.com/api/word/\(encoded)") else { return nil }
    return try? await JSONDecoder().decode(WordResult.self, from: URLSession.shared.data(from: url).0)
}

struct WordCard: View {
    let word: String
    let result: WordResult?

    var body: some View {
        VStack(alignment: .leading) {
            Text(word).bold()
            if let result {
                ForEach(result.definitions.prefix(3)) { d in
                    Text("\(d.pos): \(d.definitions.first ?? "")")
                }
                Text("from " + result.etymology.map { $0.ancestor }.joined(separator: " ← "))
            } else {
                Text("Could not reach wordroot.heyitsmejosh.com")
            }
        }
        .padding()
        .border()
    }
}

extension Definition: Identifiable { var id: String { pos } }

let semaphore = DispatchSemaphore(value: 0)
var result: WordResult?
Task {
    result = await fetchWord(word)
    semaphore.signal()
}
semaphore.wait()

Application(rootView: WordCard(word: word, result: result)).start()
