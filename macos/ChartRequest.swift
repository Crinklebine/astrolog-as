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
  case aspects = "Aspect Grid"
  case world = "World Map"
  case solarSystem = "Solar System"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .wheel: return "circle.circle"
    case .aspects: return "square.grid.3x3"
    case .world: return "globe.europe.africa"
    case .solarSystem: return "sun.max"
    }
  }

  var engineArguments: [String] {
    switch self {
    case .wheel: return []
    case .aspects: return ["-g"]
    case .world: return ["-L"]
    case .solarSystem: return ["-S"]
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

struct ChartRequest {
  let requestedLocation: String
  let sourceMode: AstrologSourceMode
  let moment: AstrologMoment
  let place: AstrologPlace
  let style: ChartStyle
  let canvas: CanvasSize
  let lightBackground: Bool

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
    guard style == .wheel else { return [] }
    return ["-Xv", "1", "-YXk", "-YXk0"]
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
      lightBackground: lightBackground)
  }
}

struct CalculatedChart {
  let request: ChartRequest
  let result: ChartResult
}

struct RenderedChart {
  let calculation: CalculatedChart
  let svgURL: URL

  var request: ChartRequest { calculation.request }
  var result: ChartResult { calculation.result }
}
