import Foundation

enum ZodiacSign: String, CaseIterable {
  case aries = "Ari"
  case taurus = "Tau"
  case gemini = "Gem"
  case cancer = "Can"
  case leo = "Leo"
  case virgo = "Vir"
  case libra = "Lib"
  case scorpio = "Sco"
  case sagittarius = "Sag"
  case capricorn = "Cap"
  case aquarius = "Aqu"
  case pisces = "Pis"

  var name: String {
    switch self {
    case .aries: return "Aries"
    case .taurus: return "Taurus"
    case .gemini: return "Gemini"
    case .cancer: return "Cancer"
    case .leo: return "Leo"
    case .virgo: return "Virgo"
    case .libra: return "Libra"
    case .scorpio: return "Scorpio"
    case .sagittarius: return "Sagittarius"
    case .capricorn: return "Capricorn"
    case .aquarius: return "Aquarius"
    case .pisces: return "Pisces"
    }
  }

  var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

struct ZodiacPosition {
  let sign: ZodiacSign
  let degrees: Int
  let minutes: Double

  var longitude: Double {
    Double(sign.index * 30 + degrees) + minutes / 60.0
  }

  var displayText: String {
    let wholeMinutes = Int(minutes.rounded())
    if wholeMinutes >= 60 {
      return "\(degrees + 1)°00′ \(sign.name)"
    }
    return String(format: "%d°%02d′ %@", degrees, wholeMinutes, sign.name)
  }
}

struct ChartBody: Identifiable {
  let key: String
  let name: String
  let position: ZodiacPosition
  let latitude: Double
  let velocity: Double
  let distanceAU: Double
  let house: Int?

  var id: String { key }
  var isRetrograde: Bool { velocity < 0 }

  var latitudeText: String {
    let direction = latitude < 0 ? "S" : "N"
    return String(format: "%.2f° %@", abs(latitude), direction)
  }

  var velocityText: String { String(format: "%+.3f°/day", velocity) }
}

struct HouseCusp: Identifiable {
  let number: Int
  let key: String
  let position: ZodiacPosition
  var id: Int { number }

  var name: String {
    switch number {
    case 1: return "Ascendant"
    case 4: return "Nadir"
    case 7: return "Descendant"
    case 10: return "Midheaven"
    default: return "House \(number)"
    }
  }
}

enum AspectKind: String {
  case conjunction = "Con"
  case opposition = "Opp"
  case square = "Squ"
  case trine = "Tri"
  case sextile = "Sex"

  var name: String {
    switch self {
    case .conjunction: return "Conjunction"
    case .opposition: return "Opposition"
    case .square: return "Square"
    case .trine: return "Trine"
    case .sextile: return "Sextile"
    }
  }
}

struct ChartAspect: Identifiable {
  let rank: Int
  let firstBody: String
  let secondBody: String
  let kind: AspectKind
  let orbDegrees: Double
  let power: Double
  var id: Int { rank }
}

struct ChartMetadata {
  let engineVersion: String
  let chartName: String
  let sourceMode: AstrologSourceMode
  let moment: AstrologMoment
  let place: AstrologPlace
  let houseSystem: String
  let engineTitle: String
  let engineSubtitle: String

  var heading: String { "\(engineTitle) · \(engineSubtitle)" }
}

struct ChartResult {
  let metadata: ChartMetadata
  let bodies: [ChartBody]
  let houses: [HouseCusp]
  let aspects: [ChartAspect]
  let rawReport: String
  let rawPositions: String

  func body(_ key: String) -> ChartBody? {
    bodies.first { $0.key == key }
  }

  func house(_ number: Int) -> HouseCusp? {
    houses.first { $0.number == number }
  }
}

enum ChartResultError: LocalizedError {
  case missingHeader
  case malformedPosition(String)
  case incompleteResult(bodyCount: Int, houseCount: Int)

  var errorDescription: String? {
    switch self {
    case .missingHeader:
      return "Astrolog returned chart data without the expected version header."
    case .malformedPosition(let line):
      return "Astrolog returned an unreadable position row: \(line)"
    case .incompleteResult(let bodies, let houses):
      return "Astrolog returned an incomplete chart (\(bodies) bodies and \(houses) houses)."
    }
  }
}

enum ChartResultParser {
  private static let houseNumbers: [String: Int] = [
    "Asce": 1, "2nd": 2, "3rd": 3, "Nadi": 4, "5th": 5, "6th": 6,
    "Desc": 7, "8th": 8, "9th": 9, "Midh": 10, "11th": 11, "12th": 12,
  ]

  private static let bodyNames: [String: String] = [
    "Sun": "Sun", "Moon": "Moon", "Merc": "Mercury", "Venu": "Venus",
    "Mars": "Mars", "Jupi": "Jupiter", "Satu": "Saturn", "Uran": "Uranus",
    "Nept": "Neptune", "Plut": "Pluto", "Nort": "North Node",
  ]

  static func parse(
    positions: String,
    report: String,
    sourceMode: AstrologSourceMode,
    moment: AstrologMoment,
    place: AstrologPlace
  ) throws -> ChartResult {
    let reportLines = report.components(separatedBy: .newlines)
    guard let title = reportLines.first(where: { !$0.isEmpty }),
          title.hasPrefix("Astrolog ") else { throw ChartResultError.missingHeader }
    let subtitle = reportLines.dropFirst().first(where: { !$0.isEmpty }) ?? ""
    let version = title.split(separator: " ").dropFirst().first.map(String.init) ?? "8.00"
    let chartName = title.components(separatedBy: " chart for ").dropFirst().joined(separator: " chart for ")
    let houseSystem = parseHouseSystem(reportLines) ?? "Unknown"
    let houseMembership = parseHouseMembership(reportLines)

    var bodies: [ChartBody] = []
    var houses: [HouseCusp] = []
    for line in positions.components(separatedBy: .newlines) where line.hasPrefix("-YF ") {
      let fields = line.replacingOccurrences(of: ",", with: "")
        .split(whereSeparator: { $0.isWhitespace }).map(String.init)
      guard fields.count >= 9,
            let degrees = Int(fields[2]),
            let sign = ZodiacSign(rawValue: fields[3]),
            let minutes = Double(fields[4]),
            let latitudeDegrees = Double(fields[5]),
            let latitudeMinutes = Double(fields[6]),
            let velocity = Double(fields[7]),
            let distance = Double(fields[8]) else {
        throw ChartResultError.malformedPosition(line)
      }
      let key = fields[1]
      let position = ZodiacPosition(sign: sign, degrees: degrees, minutes: minutes)
      let latitudeSign = latitudeDegrees < 0 || latitudeMinutes < 0 ? -1.0 : 1.0
      let latitude = latitudeSign * (abs(latitudeDegrees) + abs(latitudeMinutes) / 60.0)

      if let houseNumber = houseNumbers[key] {
        houses.append(HouseCusp(number: houseNumber, key: key, position: position))
      } else {
        bodies.append(ChartBody(
          key: key,
          name: bodyNames[key] ?? key,
          position: position,
          latitude: latitude,
          velocity: velocity,
          distanceAU: distance,
          house: houseMembership[key]))
      }
    }
    houses.sort { $0.number < $1.number }
    guard !bodies.isEmpty, houses.count == 12 else {
      throw ChartResultError.incompleteResult(bodyCount: bodies.count, houseCount: houses.count)
    }

    let metadata = ChartMetadata(
      engineVersion: version,
      chartName: chartName,
      sourceMode: sourceMode,
      moment: moment,
      place: place,
      houseSystem: houseSystem,
      engineTitle: title,
      engineSubtitle: subtitle)
    return ChartResult(
      metadata: metadata,
      bodies: bodies,
      houses: houses,
      aspects: parseAspects(reportLines),
      rawReport: report,
      rawPositions: positions)
  }

  private static func parseHouseSystem(_ lines: [String]) -> String? {
    guard let header = lines.first(where: { $0.hasPrefix("Body ") && $0.contains(" Houses") }),
          let velocityRange = header.range(of: "Veloc.") else { return nil }
    let value = header[velocityRange.upperBound...]
      .trimmingCharacters(in: .whitespaces)
    return value.hasSuffix(" Houses") ? String(value.dropLast(7)) : value
  }

  private static func parseHouseMembership(_ lines: [String]) -> [String: Int] {
    var result: [String: Int] = [:]
    for line in lines {
      guard let colon = line.firstIndex(of: ":"),
            let open = line.range(of: "[", range: colon..<line.endIndex),
            let close = line.range(of: "house]", range: open.upperBound..<line.endIndex) else { continue }
      let key = line[..<colon].trimmingCharacters(in: .whitespaces)
      let houseText = line[open.upperBound..<close.lowerBound]
      let digits = houseText.filter(\.isNumber)
      if let house = Int(digits) { result[key] = house }
    }
    return result
  }

  private static func parseAspects(_ lines: [String]) -> [ChartAspect] {
    let pattern = #"^\s*(\d+):\s+(.+?)\s+[\(\[]([A-Z][a-z]{2})[\)\]]\s+(Con|Opp|Squ|Tri|Sex)\s+[\(\[]([A-Z][a-z]{2})[\)\]]\s+(.+?)\s+- orb: ([+-])(\d+):(\d+)'\s+- power:\s+([0-9.]+)"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    return lines.compactMap { line in
      let range = NSRange(line.startIndex..<line.endIndex, in: line)
      guard let match = expression.firstMatch(in: line, range: range), match.numberOfRanges == 11,
            let rank = Int(capture(1, match, line)),
            let kind = AspectKind(rawValue: capture(4, match, line)),
            let orbDegrees = Double(capture(8, match, line)),
            let orbMinutes = Double(capture(9, match, line)),
            let power = Double(capture(10, match, line)) else { return nil }
      let sign = capture(7, match, line) == "-" ? -1.0 : 1.0
      return ChartAspect(
        rank: rank,
        firstBody: capture(2, match, line).trimmingCharacters(in: .whitespaces),
        secondBody: capture(6, match, line).trimmingCharacters(in: .whitespaces),
        kind: kind,
        orbDegrees: sign * (orbDegrees + orbMinutes / 60.0),
        power: power)
    }
  }

  private static func capture(_ index: Int, _ match: NSTextCheckingResult, _ source: String) -> String {
    guard let range = Range(match.range(at: index), in: source) else { return "" }
    return String(source[range])
  }
}
