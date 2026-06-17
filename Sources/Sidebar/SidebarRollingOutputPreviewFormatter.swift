import Foundation

struct SidebarRollingOutputPreviewFormatter {
    private enum EscapeState {
        case normal
        case escape
        case csi
        case osc
        case oscEscape
    }

    let maxCharacters: Int

    init(maxCharacters: Int = 512) {
        self.maxCharacters = max(1, maxCharacters)
    }

    func latestLine(from text: String) -> String? {
        let plainText = plainText(from: text)
        let lines = plainText.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines.reversed() {
            let trimmed = trimmingTrailingWhitespace(line)
            guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if trimmed.count <= maxCharacters {
                return trimmed
            }
            return String(trimmed.prefix(maxCharacters))
        }
        return nil
    }

    private func plainText(from text: String) -> String {
        var output = String.UnicodeScalarView()
        output.reserveCapacity(text.unicodeScalars.count)
        var state = EscapeState.normal

        for scalar in text.unicodeScalars {
            switch state {
            case .normal:
                if scalar.value == 0x1B {
                    state = .escape
                } else {
                    appendPlainScalar(scalar, to: &output)
                }
            case .escape:
                switch scalar {
                case "[":
                    state = .csi
                case "]":
                    state = .osc
                default:
                    state = .normal
                }
            case .csi:
                if (0x40...0x7E).contains(scalar.value) {
                    state = .normal
                }
            case .osc:
                if scalar.value == 0x07 {
                    state = .normal
                } else if scalar.value == 0x1B {
                    state = .oscEscape
                }
            case .oscEscape:
                state = scalar == "\\" ? .normal : .osc
            }
        }

        return String(output)
    }

    private func appendPlainScalar(
        _ scalar: UnicodeScalar,
        to output: inout String.UnicodeScalarView
    ) {
        switch scalar.value {
        case 0x0A, 0x0D:
            output.append("\n")
        case 0x09:
            output.append(" ")
        case 0x00..<0x20, 0x7F:
            return
        default:
            output.append(scalar)
        }
    }

    private func trimmingTrailingWhitespace(_ line: Substring) -> String {
        var text = String(line)
        while let last = text.last, last.isWhitespace {
            text.removeLast()
        }
        return text
    }
}
