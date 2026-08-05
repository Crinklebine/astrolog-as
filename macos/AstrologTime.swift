import Foundation

enum AstrologSourceMode: String {
  case currentMoment = "current moment"
  case manual = "manually entered moment"
}

struct AstrologMoment {
  let instant: Date
  let localDateComponents: DateComponents
  let timeZoneIdentifier: String
  let secondsFromGMT: Int
  let isDaylightSavingTime: Bool
  let daylightSavingHours: Double
  let astrologStandardZoneHoursWest: Double

  var localCivilDescription: String {
    String(
      format: "%04d-%02d-%02d %02d:%02d:%02d",
      localDateComponents.year ?? 0,
      localDateComponents.month ?? 0,
      localDateComponents.day ?? 0,
      localDateComponents.hour ?? 0,
      localDateComponents.minute ?? 0,
      localDateComponents.second ?? 0)
  }

  var astrologLocalTime: String {
    String(
      format: "%02d:%02d:%02d",
      localDateComponents.hour ?? 0,
      localDateComponents.minute ?? 0,
      localDateComponents.second ?? 0)
  }

  var astrologZone: String {
    formatAstrologCoordinate(astrologStandardZoneHoursWest, positiveSuffix: "W", negativeSuffix: "E")
  }

  var astrologDST: String {
    formatAstrologNumber(daylightSavingHours)
  }
}

enum AstrologTimeError: LocalizedError, Equatable {
  case invalidTimeZone(String)
  case invalidCivilTime
  case nonexistentCivilTime(String, String)
  case ambiguousCivilTime(String, String)

  var errorDescription: String? {
    switch self {
    case .invalidTimeZone(let identifier):
      return "The selected place uses an unsupported timezone (\(identifier))."
    case .invalidCivilTime:
      return "The entered local date and time is incomplete or invalid."
    case .nonexistentCivilTime(let civilTime, let identifier):
      return "\(civilTime) does not exist in \(identifier) because the clock moves forward then. Choose a time after the daylight-saving change."
    case .ambiguousCivilTime(let civilTime, let identifier):
      return "\(civilTime) occurs twice in \(identifier) because the clock moves backward then. Choose an unambiguous time on either side of the daylight-saving change."
    }
  }
}

func astrologMoment(for instant: Date, at timeZone: TimeZone) throws -> AstrologMoment {
  var calendar = Calendar(identifier: .gregorian)
  calendar.locale = Locale(identifier: "en_US_POSIX")
  calendar.timeZone = timeZone
  let components = calendar.dateComponents(
    [.year, .month, .day, .hour, .minute, .second], from: instant)
  let effectiveOffset = timeZone.secondsFromGMT(for: instant)
  let daylightOffset = timeZone.daylightSavingTimeOffset(for: instant)
  let standardOffset = effectiveOffset - Int(daylightOffset.rounded())

  return AstrologMoment(
    instant: instant,
    localDateComponents: components,
    timeZoneIdentifier: timeZone.identifier,
    secondsFromGMT: effectiveOffset,
    isDaylightSavingTime: timeZone.isDaylightSavingTime(for: instant),
    daylightSavingHours: daylightOffset / 3600.0,
    astrologStandardZoneHoursWest: -Double(standardOffset) / 3600.0)
}

func astrologMoment(forLocalCivilTime components: DateComponents, at timeZone: TimeZone) throws -> AstrologMoment {
  guard let year = components.year,
        let month = components.month,
        let day = components.day,
        let hour = components.hour,
        let minute = components.minute else {
    throw AstrologTimeError.invalidCivilTime
  }

  let second = components.second ?? 0
  var calendar = Calendar(identifier: .gregorian)
  calendar.locale = Locale(identifier: "en_US_POSIX")
  calendar.timeZone = timeZone

  var noonComponents = DateComponents()
  noonComponents.year = year
  noonComponents.month = month
  noonComponents.day = day
  noonComponents.hour = 12
  guard let noon = calendar.date(from: noonComponents) else {
    throw AstrologTimeError.invalidCivilTime
  }
  let searchStart = calendar.startOfDay(for: noon).addingTimeInterval(-1)

  var match = DateComponents()
  match.year = year
  match.month = month
  match.day = day
  match.hour = hour
  match.minute = minute
  match.second = second

  let first = calendar.nextDate(
    after: searchStart,
    matching: match,
    matchingPolicy: .strict,
    repeatedTimePolicy: .first,
    direction: .forward)
  let last = calendar.nextDate(
    after: searchStart,
    matching: match,
    matchingPolicy: .strict,
    repeatedTimePolicy: .last,
    direction: .forward)
  let civilDescription = String(
    format: "%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)

  guard let first, let last else {
    throw AstrologTimeError.nonexistentCivilTime(civilDescription, timeZone.identifier)
  }
  if first != last {
    throw AstrologTimeError.ambiguousCivilTime(civilDescription, timeZone.identifier)
  }
  return try astrologMoment(for: first, at: timeZone)
}

struct AstrologPlace: Equatable {
  let name: String
  let regionCode: String
  let timeZoneIdentifier: String
  let longitudeDegreesWest: Double
  let latitudeDegreesNorth: Double

  var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

  var countryCode: String {
    if regionCode == regionCode.lowercased() {
      return AtlasResolver.canadianProvinceCodes.contains(regionCode.lowercased()) ? "CA" : "US"
    }
    return regionCode.uppercased()
  }

  var displayName: String {
    let locale = Locale(identifier: "en_US")
    let country = locale.localizedString(forRegionCode: countryCode) ?? countryCode
    if regionCode == regionCode.lowercased() {
      return "\(name), \(regionCode.uppercased()), \(country)"
    }
    return "\(name), \(country)"
  }

  var astrologLongitude: String {
    formatAstrologCoordinate(longitudeDegreesWest, positiveSuffix: "W", negativeSuffix: "E", precision: 4)
  }

  var astrologLatitude: String {
    formatAstrologCoordinate(latitudeDegreesNorth, positiveSuffix: "N", negativeSuffix: "S", precision: 4)
  }
}

enum AtlasResolverError: LocalizedError {
  case unreadableAtlas
  case placeNotFound(String)
  case invalidTimeZone(String)

  var errorDescription: String? {
    switch self {
    case .unreadableAtlas:
      return "The bundled city atlas could not be read."
    case .placeNotFound(let query):
      return "No city matching “\(query)” was found in the bundled atlas. Try a city name followed by its state or country."
    case .invalidTimeZone(let identifier):
      return "The timezone “\(identifier)” is not available on this Mac."
    }
  }
}

enum AtlasResolver {
  static let canadianProvinceCodes: Set<String> = [
    "ab", "bc", "mb", "nb", "nl", "ns", "nt", "nu", "on", "pe", "qc", "sk", "yt",
  ]

  private static let countryAliases: [String: String] = [
    "america": "US", "united states": "US", "united states of america": "US", "us": "US", "usa": "US",
    "canada": "CA",
    "britain": "GB", "england": "GB", "great britain": "GB", "scotland": "GB", "uk": "GB", "united kingdom": "GB", "wales": "GB",
  ]

  static func resolve(_ query: String, atlasURL: URL) throws -> AstrologPlace {
    guard let data = try? Data(contentsOf: atlasURL),
          let contents = String(data: data, encoding: .utf8) else {
      throw AtlasResolverError.unreadableAtlas
    }
    return try resolve(query, atlasContents: contents)
  }

  static func resolve(_ query: String, atlasContents: String) throws -> AstrologPlace {
    let queryParts = query.split(separator: ",").map { normalize(String($0)) }.filter { !$0.isEmpty }
    guard let cityQuery = queryParts.first else {
      throw AtlasResolverError.placeNotFound(query)
    }
    let qualifiers = Array(queryParts.dropFirst())
    var currentTimeZone = ""
    var best: (score: Int, place: AstrologPlace)?

    for rawLine in atlasContents.split(whereSeparator: \.isNewline) {
      let line = String(rawLine)
      if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("@") || line.hasPrefix("-YY") {
        continue
      }
      let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
      guard fields.count >= 4,
            let longitude = Double(fields[0]),
            let latitude = Double(fields[1]) else { continue }
      if fields.count >= 5, !fields[4].isEmpty { currentTimeZone = fields[4] }
      guard !currentTimeZone.isEmpty else { continue }

      let place = AstrologPlace(
        name: fields[3], regionCode: fields[2], timeZoneIdentifier: currentTimeZone,
        longitudeDegreesWest: longitude, latitudeDegreesNorth: latitude)
      let placeName = normalize(place.name)
      let nameWithoutCity = placeName.hasSuffix(" city") ? String(placeName.dropLast(5)) : placeName
      let cityScore: Int
      if placeName == cityQuery { cityScore = 120 }
      else if nameWithoutCity == cityQuery { cityScore = 115 }
      else if placeName.hasPrefix(cityQuery + " ") || placeName.hasSuffix(" " + cityQuery) { cityScore = 55 }
      else if placeName.contains(cityQuery) { cityScore = 35 }
      else { continue }

      var score = cityScore
      for qualifier in qualifiers {
        if qualifier == normalize(place.regionCode) {
          score += 40
        } else if countryCode(for: qualifier) == place.countryCode {
          score += 30
        } else if normalize(place.displayName).contains(qualifier) {
          score += 15
        } else {
          score -= 45
        }
      }
      if best == nil || score > best!.score { best = (score, place) }
    }

    guard let place = best?.place else { throw AtlasResolverError.placeNotFound(query) }
    guard place.timeZone != nil else { throw AtlasResolverError.invalidTimeZone(place.timeZoneIdentifier) }
    return place
  }

  private static func countryCode(for normalizedName: String) -> String? {
    if let alias = countryAliases[normalizedName] { return alias }
    let locale = Locale(identifier: "en_US")
    for region in Locale.Region.isoRegions {
      let code = region.identifier
      if let name = locale.localizedString(forRegionCode: code), normalize(name) == normalizedName {
        return code
      }
    }
    return nil
  }

  private static func normalize(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }
}

func astrologInputArguments(moment: AstrologMoment, place: AstrologPlace, chartName: String) -> [String] {
  let components = moment.localDateComponents
  return [
    "-qb",
    String(components.month ?? 1),
    String(components.day ?? 1),
    String(components.year ?? 2000),
    moment.astrologLocalTime,
    moment.astrologDST,
    moment.astrologZone,
    place.astrologLongitude,
    place.astrologLatitude,
    "-zi", chartName, place.displayName,
  ]
}

func timezoneDiagnostic(
  sourceMode: AstrologSourceMode,
  placeQuery: String,
  place: AstrologPlace,
  moment: AstrologMoment,
  arguments: [String]
) -> String {
  let iso = ISO8601DateFormatter()
  iso.formatOptions = [.withInternetDateTime]
  iso.timeZone = TimeZone(secondsFromGMT: 0)
  return """
  Source mode: \(sourceMode.rawValue)
  Absolute instant: \(iso.string(from: moment.instant))
  Place: \(placeQuery) → \(place.displayName)
  Timezone: \(moment.timeZoneIdentifier)
  Local civil time: \(moment.localCivilDescription)
  Effective offset: \(moment.secondsFromGMT) seconds
  DST active: \(moment.isDaylightSavingTime)
  DST supplied to Astrolog: \(moment.astrologDST)
  Astrolog standard zone: \(moment.astrologZone)
  Astrolog local time: \(moment.astrologLocalTime)
  Astrolog arguments: \(arguments.map(shellQuoted).joined(separator: " "))
  """
}

private func formatAstrologCoordinate(
  _ value: Double,
  positiveSuffix: String,
  negativeSuffix: String,
  precision: Int = 6
) -> String {
  let suffix = value < 0 ? negativeSuffix : positiveSuffix
  let absolute = abs(value)
  let rounded = absolute.rounded()
  if abs(absolute - rounded) < 0.000_000_1 { return "\(Int(rounded))\(suffix)" }
  return "\(formatAstrologNumber(absolute, precision: precision))\(suffix)"
}

private func formatAstrologNumber(_ value: Double, precision: Int = 6) -> String {
  if abs(value - value.rounded()) < 0.000_000_1 { return String(Int(value.rounded())) }
  var result = String(format: "%.*f", precision, value)
  while result.last == "0" { result.removeLast() }
  if result.last == "." { result.removeLast() }
  return result
}

private func shellQuoted(_ value: String) -> String {
  if value.allSatisfy({ $0.isLetter || $0.isNumber || "-_.:/".contains($0) }) { return value }
  return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}
