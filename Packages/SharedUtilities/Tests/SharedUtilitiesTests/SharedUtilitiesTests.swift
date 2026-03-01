import Testing
@testable import SharedUtilities

@Test func commandParserExists() async throws {
    let parser = CommandParser()
    let result = parser.parse("test")
    #expect(result.title == "test")
}
