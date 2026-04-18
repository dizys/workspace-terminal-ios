import Foundation
import Testing
@testable import PTYTransport

/// Wire-format reference: `ReconnectingPTYRequest` in
/// `.refs/coder/codersdk/workspacesdk/agentconn.go:196-200`:
///
/// ```go
/// type ReconnectingPTYRequest struct {
///     Data   string `json:"data,omitempty"`
///     Height uint16 `json:"height,omitempty"`
///     Width  uint16 `json:"width,omitempty"`
/// }
/// ```
@Suite("ClientFrame JSON encoding")
struct ClientFrameTests {
    @Test("input emits {data} only — no height/width keys")
    func inputDataOnly() throws {
        let frame = ClientFrame.input(Data("hi".utf8))
        #expect(try frame.jsonString() == #"{"data":"hi"}"#)
    }

    @Test("resize emits {height, width} sorted, no data key")
    func resizeHeightAndWidthOnly() throws {
        let frame = ClientFrame.resize(TerminalSize(rows: 40, cols: 120))
        // .sortedKeys → height before width
        #expect(try frame.jsonString() == #"{"height":40,"width":120}"#)
    }

    @Test("input handles UTF-8 multibyte glyphs without corruption")
    func multibyteUTF8() throws {
        let frame = ClientFrame.input(Data("héllo🌍".utf8))
        #expect(try frame.jsonString() == #"{"data":"héllo🌍"}"#)
    }

    @Test("input is lossy-but-non-throwing on invalid UTF-8 — keystroke hot path must not throw")
    func invalidUTF8Lossy() throws {
        let frame = ClientFrame.input(Data([0x68, 0xFF, 0x69])) // h \xff i
        let s = try frame.jsonString()
        #expect(s.contains(#""data":"#))
        #expect(s.contains("h"))
        #expect(s.contains("i"))
    }

    @Test("input + resize can be combined in a single frame (server tolerates)")
    func combinedDataAndResize() throws {
        let frame = ClientFrame(data: "x", height: 10, width: 20)
        // sorted: data, height, width
        #expect(try frame.jsonString() == #"{"data":"x","height":10,"width":20}"#)
    }

    @Test("empty input still emits a data key (server treats as no-op write)")
    func emptyInputEmitsEmptyData() throws {
        let frame = ClientFrame.input(Data())
        #expect(try frame.jsonString() == #"{"data":""}"#)
    }
}
