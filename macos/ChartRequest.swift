import Foundation

struct LastPlaceStore {
  static let defaultLocation = "Seattle, WA, USA"
  private static let locationKey = "lastSuccessfulChartLocation"

  private let defaults: UserDefaults
  private let legacyDefaults: UserDefaults?

  init(
    defaults: UserDefaults = .standard,
    legacyDefaults: UserDefaults? = UserDefaults(suiteName: "org.crinklebine.astrolog")
  ) {
    self.defaults = defaults
    self.legacyDefaults = legacyDefaults
  }

  var location: String {
    for source in [defaults, legacyDefaults].compactMap({ $0 }) {
      let saved = source.string(forKey: Self.locationKey)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if let saved, !saved.isEmpty { return saved }
    }
    return Self.defaultLocation
  }

  func save(_ location: String) {
    let value = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    defaults.set(value, forKey: Self.locationKey)
  }
}

struct ChartAppearanceStore {
  private static let lightBackgroundKey = "lightChartBackground"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var lightBackground: Bool {
    defaults.object(forKey: Self.lightBackgroundKey) as? Bool ?? false
  }

  func saveLightBackground(_ enabled: Bool) {
    defaults.set(enabled, forKey: Self.lightBackgroundKey)
  }
}

struct SuggestedPlacesStore {
  static let maximumPlaces = 8
  static let defaultPlaces = [
    "Seattle, WA, USA",
    "London, England",
    "Douglas, Isle of Man",
    "New York, NY, USA",
    "Los Angeles, CA, USA",
    "Sydney, Australia",
    "Bangkok, Thailand",
    "Tokyo, Japan",
  ]

  private struct PlaceRecord: Codable {
    let location: String
    var useCount: Int
    var lastUsed: Int
  }

  private struct SavedState: Codable {
    var records: [PlaceRecord]
    var usageClock: Int
  }

  private static let stateKey = "adaptiveSuggestedPlaces"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var places: [String] {
    orderedRecords(loadState().records).map(\.location)
  }

  @discardableResult
  func recordUse(of location: String) -> [String] {
    let location = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !location.isEmpty else { return places }

    var state = loadState()
    state.usageClock += 1
    if let index = state.records.firstIndex(where: {
      $0.location.caseInsensitiveCompare(location) == .orderedSame
    }) {
      state.records[index].useCount += 1
      state.records[index].lastUsed = state.usageClock
    } else {
      if state.records.count >= Self.maximumPlaces,
         let evictionIndex = evictionIndex(in: state.records) {
        state.records.remove(at: evictionIndex)
      }
      state.records.append(PlaceRecord(
        location: location, useCount: 1, lastUsed: state.usageClock))
    }
    save(state)
    return orderedRecords(state.records).map(\.location)
  }

  private func loadState() -> SavedState {
    if let data = defaults.data(forKey: Self.stateKey),
       let saved = try? JSONDecoder().decode(SavedState.self, from: data),
       !saved.records.isEmpty {
      var seen = Set<String>()
      let records = saved.records.filter {
        seen.insert($0.location.lowercased()).inserted
      }
      return SavedState(
        records: Array(records.prefix(Self.maximumPlaces)),
        usageClock: max(saved.usageClock, records.map(\.lastUsed).max() ?? 0))
    }
    return SavedState(
      records: Self.defaultPlaces.map {
        PlaceRecord(location: $0, useCount: 0, lastUsed: 0)
      },
      usageClock: 0)
  }

  private func save(_ state: SavedState) {
    guard let data = try? JSONEncoder().encode(state) else { return }
    defaults.set(data, forKey: Self.stateKey)
  }

  private func orderedRecords(_ records: [PlaceRecord]) -> [PlaceRecord] {
    records.enumerated().sorted { lhs, rhs in
      if lhs.element.lastUsed != rhs.element.lastUsed {
        return lhs.element.lastUsed > rhs.element.lastUsed
      }
      return lhs.offset < rhs.offset
    }.map(\.element)
  }

  private func evictionIndex(in records: [PlaceRecord]) -> Int? {
    let protected = Set(
      records.enumerated()
        .filter { $0.element.lastUsed > 0 }
        .sorted { $0.element.lastUsed > $1.element.lastUsed }
        .prefix(2)
        .map(\.offset))
    return records.enumerated()
      .filter { !protected.contains($0.offset) }
      .min { lhs, rhs in
        let lhsNeverUsed = lhs.element.useCount == 0
        let rhsNeverUsed = rhs.element.useCount == 0
        if lhsNeverUsed != rhsNeverUsed { return lhsNeverUsed }
        if lhs.element.useCount != rhs.element.useCount {
          return lhs.element.useCount < rhs.element.useCount
        }
        if lhs.element.lastUsed != rhs.element.lastUsed {
          return lhs.element.lastUsed < rhs.element.lastUsed
        }
        return lhs.offset < rhs.offset
      }?.offset
  }
}

enum ChartStyle: String, CaseIterable, Identifiable {
  case wheel = "Wheel"
  case solarSystem = "Solar System"
  case localHorizon = "Local Horizon"
  case astrocartography = "Astrocartography"
  case aspects = "Aspect Grid"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .wheel: return "circle.circle"
    case .solarSystem: return "sun.max"
    case .localHorizon: return "location.north.circle"
    case .astrocartography: return "globe.europe.africa"
    case .aspects: return "square.grid.3x3"
    }
  }

  var engineArguments: [String] {
    switch self {
    case .wheel: return []
    case .solarSystem: return ["-S"]
    case .localHorizon: return ["-Z"]
    case .astrocartography: return ["-L"]
    case .aspects: return ["-g"]
    }
  }
}

enum CanvasSize: String, CaseIterable, Identifiable {
  case compact = "Compact"
  case standard = "Standard"
  case large = "Large"

  var id: String { rawValue }

  var dimensions: (Int, Int) {
    switch self {
    case .compact: return (700, 560)
    case .standard: return (900, 720)
    case .large: return (1200, 960)
    }
  }
}

enum ChartAnimationDirection: Int {
  case backward = -1
  case forward = 1
}

enum ChartAnimationStep: String, CaseIterable, Identifiable {
  case second = "1 second"
  case minute = "1 minute"
  case tenMinutes = "10 minutes"
  case hour = "1 hour"
  case sixHours = "6 hours"
  case day = "1 day"
  case week = "1 week"
  case month = "1 month"
  case year = "1 year"

  var id: String { rawValue }

  private var calendarIncrement: (component: Calendar.Component, value: Int) {
    switch self {
    case .second: return (.second, 1)
    case .minute: return (.minute, 1)
    case .tenMinutes: return (.minute, 10)
    case .hour: return (.hour, 1)
    case .sixHours: return (.hour, 6)
    case .day: return (.day, 1)
    case .week: return (.day, 7)
    case .month: return (.month, 1)
    case .year: return (.year, 1)
    }
  }

  func advancing(
    _ instant: Date,
    direction: ChartAnimationDirection,
    in timeZone: TimeZone
  ) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    let increment = calendarIncrement
    return calendar.date(
      byAdding: increment.component,
      value: increment.value * direction.rawValue,
      to: instant)
  }
}

enum ChartAnimationRate: String, CaseIterable, Identifiable {
  case one = "1 fps"
  case two = "2 fps"
  case five = "5 fps"
  case fifteen = "15 fps"
  case thirty = "30 fps"
  case sixty = "60 fps"
  case maximum = "Maximum"

  var id: String { rawValue }

  var minimumFrameInterval: TimeInterval {
    switch self {
    case .one: return 1
    case .two: return 0.5
    case .five: return 0.2
    case .fifteen: return 1.0 / 15.0
    case .thirty: return 1.0 / 30.0
    case .sixty: return 1.0 / 60.0
    case .maximum: return 0
    }
  }
}

struct ChartRequest {
  static let defaultSolarSystemRadiusAU = 30.0
  static let minimumSolarSystemRadiusAU = 0.0001
  static let maximumSolarSystemRadiusAU = 360.0

  let requestedLocation: String
  let sourceMode: AstrologSourceMode
  let moment: AstrologMoment
  let place: AstrologPlace
  let style: ChartStyle
  let canvas: CanvasSize
  let lightBackground: Bool
  let solarSystemRadiusAU: Double

  init(
    requestedLocation: String,
    sourceMode: AstrologSourceMode,
    moment: AstrologMoment,
    place: AstrologPlace,
    style: ChartStyle,
    canvas: CanvasSize,
    lightBackground: Bool,
    solarSystemRadiusAU: Double = Self.defaultSolarSystemRadiusAU
  ) {
    self.requestedLocation = requestedLocation
    self.sourceMode = sourceMode
    self.moment = moment
    self.place = place
    self.style = style
    self.canvas = canvas
    self.lightBackground = lightBackground
    self.solarSystemRadiusAU = solarSystemRadiusAU
  }

  var chartArguments: [String] {
    astrologInputArguments(
      moment: moment,
      place: place,
      chartName: sourceMode == .currentMoment ? "Current moment" : "Custom chart")
  }

  var renderArguments: [String] {
    astrologInputArguments(
      moment: moment,
      place: place,
      chartName: sourceMode == .currentMoment ? "Current moment" : "Custom chart",
      placeName: place.graphicDisplayName)
  }

  var graphicEffectArguments: [String] {
    switch style {
    case .wheel:
      return ["-Xv", "1", "-YXk", "-YXk0"]
    case .solarSystem:
      let radius = String(
        format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), solarSystemRadiusAU)
      return ["-YXS", radius]
    case .localHorizon, .astrocartography, .aspects:
      return []
    }
  }

  func withRenderingOptions(
    style: ChartStyle,
    canvas: CanvasSize,
    lightBackground: Bool
  ) -> ChartRequest {
    ChartRequest(
      requestedLocation: requestedLocation,
      sourceMode: sourceMode,
      moment: moment,
      place: place,
      style: style,
      canvas: canvas,
      lightBackground: lightBackground,
      solarSystemRadiusAU: solarSystemRadiusAU)
  }

  func withSolarSystemRadiusAU(_ radius: Double) -> ChartRequest {
    ChartRequest(
      requestedLocation: requestedLocation,
      sourceMode: sourceMode,
      moment: moment,
      place: place,
      style: style,
      canvas: canvas,
      lightBackground: lightBackground,
      solarSystemRadiusAU: max(
        Self.minimumSolarSystemRadiusAU,
        min(Self.maximumSolarSystemRadiusAU, radius)))
  }

  func withMoment(
    _ moment: AstrologMoment,
    sourceMode: AstrologSourceMode = .manual
  ) -> ChartRequest {
    ChartRequest(
      requestedLocation: requestedLocation,
      sourceMode: sourceMode,
      moment: moment,
      place: place,
      style: style,
      canvas: canvas,
      lightBackground: lightBackground,
      solarSystemRadiusAU: solarSystemRadiusAU)
  }
}

struct CalculatedChart {
  let request: ChartRequest
  let result: ChartResult
}

struct RenderedChart {
  let calculation: CalculatedChart
  let svgURL: URL
  let engineSVGURL: URL

  var request: ChartRequest { calculation.request }
  var result: ChartResult { calculation.result }
}
