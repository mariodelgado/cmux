import Foundation

enum ParsedPaneTextSanitizer {
    struct Result: Sendable, Equatable {
        let text: String
        let links: [ParsedPaneLink]
        let inlineImages: [ParsedInlineImage]
        let hasANSISequences: Bool
        let hasKittyGraphics: Bool
    }

    static func sanitize(_ rawText: String) -> Result {
        guard !rawText.isEmpty else {
            return Result(
                text: "",
                links: [],
                inlineImages: [],
                hasANSISequences: false,
                hasKittyGraphics: false
            )
        }

        let scalars = Array(rawText.unicodeScalars)
        var index = 0
        var output = String()
        output.reserveCapacity(rawText.count)
        var links: [ParsedPaneLink] = []
        var inlineImages: [ParsedInlineImage] = []
        var sawANSI = false
        var sawKitty = false

        while index < scalars.count {
            let scalar = scalars[index]
            if scalar.value == 0x1B {
                sawANSI = true
                guard index + 1 < scalars.count else {
                    index += 1
                    continue
                }
                let next = scalars[index + 1]
                switch next {
                case "[":
                    index = consumeCSI(in: scalars, from: index + 2)
                case "]":
                    let consumed = consumeOSC(in: scalars, from: index + 2, linkCount: links.count)
                    if let link = consumed.link {
                        links.append(link)
                    }
                    index = consumed.nextIndex
                case "_":
                    sawKitty = true
                    let consumed = consumeAPC(in: scalars, from: index + 2, imageCount: inlineImages.count)
                    if let image = consumed.image {
                        inlineImages.append(image)
                    }
                    index = consumed.nextIndex
                default:
                    index += 2
                }
                continue
            }

            if scalar.value == 0x00 || (scalar.value < 0x20 && scalar != "\n" && scalar != "\t" && scalar != "\r") {
                sawANSI = true
                index += 1
                continue
            }

            if scalar == "\r" {
                output.unicodeScalars.append("\n")
            } else {
                output.unicodeScalars.append(scalar)
            }
            index += 1
        }

        return Result(
            text: output,
            links: links,
            inlineImages: inlineImages,
            hasANSISequences: sawANSI,
            hasKittyGraphics: sawKitty
        )
    }

    private static func consumeCSI(in scalars: [UnicodeScalar], from start: Int) -> Int {
        var index = start
        while index < scalars.count {
            let value = scalars[index].value
            index += 1
            if value >= 0x40 && value <= 0x7E {
                break
            }
        }
        return index
    }

    private static func consumeOSC(
        in scalars: [UnicodeScalar],
        from start: Int,
        linkCount: Int
    ) -> (nextIndex: Int, link: ParsedPaneLink?) {
        var index = start
        var sequence = String()
        while index < scalars.count {
            if scalars[index].value == 0x07 {
                index += 1
                break
            }
            if scalars[index].value == 0x1B, index + 1 < scalars.count, scalars[index + 1] == "\\" {
                index += 2
                break
            }
            sequence.unicodeScalars.append(scalars[index])
            index += 1
        }

        guard sequence.hasPrefix("8;") else {
            return (index, nil)
        }
        let pieces = sequence.split(separator: ";", maxSplits: 2, omittingEmptySubsequences: false)
        guard pieces.count == 3 else { return (index, nil) }
        let rawURL = String(pieces[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty, let url = URL(string: rawURL) else {
            return (index, nil)
        }
        return (
            index,
            ParsedPaneLink(
                id: "osc8-\(linkCount)-\(rawURL.hashValue)",
                label: rawURL,
                url: url
            )
        )
    }

    private static func consumeAPC(
        in scalars: [UnicodeScalar],
        from start: Int,
        imageCount: Int
    ) -> (nextIndex: Int, image: ParsedInlineImage?) {
        var index = start
        var sequence = String()
        while index < scalars.count {
            if scalars[index].value == 0x1B, index + 1 < scalars.count, scalars[index + 1] == "\\" {
                index += 2
                break
            }
            sequence.unicodeScalars.append(scalars[index])
            index += 1
        }

        guard sequence.hasPrefix("G") else { return (index, nil) }
        let body = String(sequence.dropFirst())
        guard let comma = body.firstIndex(of: ",") else { return (index, nil) }
        let params = String(body[..<comma])
        let encoded = String(body[body.index(after: comma)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard encoded.count <= 2_800_000, let data = Data(base64Encoded: encoded), !data.isEmpty else {
            return (index, nil)
        }
        let format = params
            .split(separator: ",")
            .first { $0.hasPrefix("f=") }
            .map { String($0.dropFirst(2)) }
        return (
            index,
            ParsedInlineImage(
                id: "kitty-\(imageCount)-\(data.count)",
                data: data,
                format: format
            )
        )
    }
}
