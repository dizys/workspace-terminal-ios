import Testing
@testable import PTYTransport

@Suite("PTYTransport smoke")
struct PTYTransportTests {
    @Test("TerminalSize stores rows and cols")
    func terminalSize() {
        let size = TerminalSize(rows: 24, cols: 80)
        #expect(size.rows == 24)
        #expect(size.cols == 80)
    }
}
