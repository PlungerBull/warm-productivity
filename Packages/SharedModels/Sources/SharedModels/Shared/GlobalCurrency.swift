import Foundation
import SwiftData

@Model
public final class GlobalCurrency {
    @Attribute(.unique) public var code: String
    public var name: String
    public var symbol: String
    public var flag: String?

    public init(
        code: String,
        name: String,
        symbol: String,
        flag: String? = nil
    ) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.flag = flag
    }
}
