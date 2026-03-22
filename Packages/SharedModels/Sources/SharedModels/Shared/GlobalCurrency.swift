import Foundation
import SwiftData

@Model
public final class GlobalCurrency {
    @Attribute(.unique) public var code: String
    public var name: String
    public var symbol: String
    public var flag: String?
    public var decimalPlaces: Int

    public init(
        code: String,
        name: String,
        symbol: String,
        flag: String? = nil,
        decimalPlaces: Int = 2
    ) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.flag = flag
        self.decimalPlaces = decimalPlaces
    }
}
