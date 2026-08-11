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
  case ten = "10 fps"
  case thirty = "30 fps"
  case sixty = "60 fps"
  case maximum = "Maximum"

  var id: String { rawValue }

  var minimumFrameInterval: TimeInterval {
    switch self {
    case .one: return 1
    case .two: return 0.5
    case .five: return 0.2
    case .ten: return 0.1
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
