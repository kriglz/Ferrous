/// A Life-like B/S rule, e.g. "B3/S23" for Conway's Life.
struct RuleSet {
    var birthMask: UInt32
    var surviveMask: UInt32

    init(birth: [Int], survive: [Int]) {
        birthMask = birth.reduce(0) { $0 | (1 << $1) }
        surviveMask = survive.reduce(0) { $0 | (1 << $1) }
    }

    init?(bsString: String) {
        let parts = bsString.uppercased().split(separator: "/")
        guard parts.count == 2 else { return nil }
        var birth: [Int] = []
        var survive: [Int] = []
        for part in parts {
            guard let tag = part.first else { return nil }
            let digits = part.dropFirst().compactMap { $0.wholeNumberValue }
            switch tag {
            case "B": birth = digits
            case "S": survive = digits
            default: return nil
            }
        }
        self.init(birth: birth, survive: survive)
    }

    var bsString: String {
        func digits(_ mask: UInt32) -> String {
            (0...8).filter { (mask >> $0) & 1 != 0 }.map(String.init).joined()
        }
        return "B\(digits(birthMask))/S\(digits(surviveMask))"
    }

    static let conway = RuleSet(birth: [3], survive: [2, 3])
    static let highLife = RuleSet(birth: [3, 6], survive: [2, 3])
    static let seeds = RuleSet(birth: [2], survive: [])
    static let dayAndNight = RuleSet(birth: [3, 6, 7, 8], survive: [3, 4, 6, 7, 8])
}
