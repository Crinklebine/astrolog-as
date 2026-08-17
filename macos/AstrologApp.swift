import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum AstrologAppError: LocalizedError {
  case missingEngine
  case engineFailed(String)
  case missingOutput

  var errorDescription: String? {
    switch self {
    case .missingEngine:
      return "The bundled Astrolog calculation engine could not be found."
    case .engineFailed(let details):
      return details.isEmpty ? "Astrolog could not generate this chart." : details
    case .missingOutput:
      return "Astrolog finished without creating a chart. Check the place name and try again."
    }
  }
}

struct EngineOutput {
  let standardOutput: String
  let standardError: String
}

enum AstrologEngine {
  private static var resourcesURL: URL? { Bundle.main.resourceURL }

  static func run(arguments: [String]) throws -> EngineOutput {
    guard let resourcesURL else { throw AstrologAppError.missingEngine }
    let executableURL = resourcesURL.appendingPathComponent("astrolog-cli")
    guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
      throw AstrologAppError.missingEngine
    }

    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.executableURL = executableURL
    process.currentDirectoryURL = resourcesURL
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let output = String(decoding: outputData, as: UTF8.self)
    let error = String(decoding: errorData, as: UTF8.self)
    guard process.terminationStatus == 0 else {
      let details = [error, output]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? "Astrolog exited with status \(process.terminationStatus)."
      throw AstrologAppError.engineFailed(details)
    }
    return EngineOutput(standardOutput: output, standardError: error)
  }

  static func calculate(_ request: ChartRequest) throws -> CalculatedChart {
    if ProcessInfo.processInfo.environment["ASTROLOG_DEBUG_TIMEZONE"] == "1" {
      let diagnostic = timezoneDiagnostic(
        sourceMode: request.sourceMode,
        placeQuery: request.requestedLocation,
        place: request.place,
        moment: request.moment,
        arguments: request.chartArguments)
      FileHandle.standardError.write(Data((diagnostic + "\n").utf8))
    }

    let engineOutput = try run(arguments: request.chartArguments + [
      "-o0", "-", "-v", "-a",
    ])
    guard let positionsStart = engineOutput.standardOutput.range(of: "@AP") else {
      throw AstrologAppError.missingOutput
    }
    let report = String(engineOutput.standardOutput[..<positionsStart.lowerBound])
    let positions = String(engineOutput.standardOutput[positionsStart.lowerBound...])
    let result = try ChartResultParser.parse(
      positions: positions,
      report: report,
      sourceMode: request.sourceMode,
      moment: request.moment,
      place: request.place)
    return CalculatedChart(request: request, result: result)
  }
}

enum AstrologRenderer {
  static func render(_ calculation: CalculatedChart) throws -> RenderedChart {
    let request = calculation.request
    let size = request.canvas.dimensions

    var graphicArguments = request.renderArguments + request.style.engineArguments
      + request.graphicEffectArguments
    graphicArguments += ["-Xx0", "-Xw", String(size.0), String(size.1)]
    if request.lightBackground { graphicArguments.append("-Xr") }
    graphicArguments += ["-XV", "-Xo", "-"]
    let engineOutput = try AstrologEngine.run(arguments: graphicArguments)

    let engineSVG = engineOutput.standardOutput
    guard engineSVG.contains("<svg"), engineSVG.contains("</svg>") else {
      throw AstrologAppError.missingOutput
    }
    var svg = engineSVG
    if request.style == .wheel {
      svg = try WheelTooltipAnnotator.annotatedSVG(
        svg,
        result: calculation.result,
        lightBackground: request.lightBackground)
    } else if request.style == .localHorizon {
      svg = try WheelTooltipAnnotator.annotatedLocalHorizonSVG(
        svg,
        result: calculation.result,
        lightBackground: request.lightBackground)
    } else if request.style == .solarSystem {
      svg = try WheelTooltipAnnotator.annotatedSolarSystemSVG(
        svg,
        result: calculation.result,
        radiusAU: request.solarSystemRadiusAU,
        lightBackground: request.lightBackground)
      svg = try SolarSystemZoomAnnotator.annotatedSVG(svg)
    }

    return RenderedChart(
      calculation: calculation,
      svg: svg,
      engineSVG: engineSVG)
  }

  static func generatePNG(_ calculation: CalculatedChart, at outputURL: URL) throws {
    let request = calculation.request
    let size = request.canvas.dimensions
    var arguments = request.renderArguments + request.style.engineArguments
      + request.graphicEffectArguments
    arguments += ["-Xx0", "-Xw", String(size.0), String(size.1)]
    if request.lightBackground { arguments.append("-Xr") }
    arguments += ["-Xbp", "-Xo", outputURL.path]
    _ = try AstrologEngine.run(arguments: arguments)
    guard FileManager.default.fileExists(atPath: outputURL.path) else {
      throw AstrologAppError.missingOutput
    }
  }
}

enum ResultView: Int, CaseIterable, Identifiable {
  case chart
  case positions
  case aspects

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .chart: return "Chart"
    case .positions: return "Positions"
    case .aspects: return "Aspects"
    }
  }
}

enum CSVClipboard {
  static func copy(_ csv: String) {
    let pasteboard = NSPasteboard.general
    let csvType = NSPasteboard.PasteboardType(UTType.commaSeparatedText.identifier)
    pasteboard.clearContents()
    pasteboard.declareTypes([csvType, .string], owner: nil)
    pasteboard.setString(csv, forType: csvType)
    pasteboard.setString(csv, forType: .string)
  }
}

@MainActor
final class ChartViewModel: ObservableObject {
  @Published var location: String
  @Published var useCurrentMoment = true
  @Published var chartDate = Date()
  @Published var displayTimeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
  @Published var chartStyle: ChartStyle
  @Published var canvasSize: CanvasSize
  @Published var lightBackground: Bool
  @Published private(set) var suggestedPlaces: [String]
  @Published var selectedResult = ResultView.chart
  @Published var generatedChart: RenderedChart?
  @Published var isWorking = false
  @Published private(set) var isUpdatingAppearance = false
  @Published var animationStep = ChartAnimationStep.day
  @Published var animationRate = ChartAnimationRate.fifteen
  @Published private(set) var animationDirection: ChartAnimationDirection?
  @Published private(set) var isAnimationRendering = false
  @Published private(set) var measuredAnimationFPS: Double?
  @Published private(set) var atlasPlaces: [AstrologPlace] = []
  @Published private(set) var isLoadingPlaces = false
  @Published var statusText = "Ready"
  @Published var errorMessage: String?

  private let lastPlaceStore: LastPlaceStore
  private let chartAppearanceStore: ChartAppearanceStore
  private let suggestedPlacesStore: SuggestedPlacesStore
  private var pendingSolarSystemZoomDelta = 0.0
  private var solarSystemZoomResetRequested = false
  private var solarSystemZoomTask: Task<Void, Never>?
  private var solarSystemZoomTaskID: UUID?
  private var solarSystemZoomRevision = 0
  private var solarSystemChartCache: [String: RenderedChart] = [:]
  private var solarSystemChartCacheOrder: [String] = []
  private var animationTask: Task<Void, Never>?
  private var animationRevision = 0
  private var animationFrameCache: [String: RenderedChart] = [:]
  private var animationFrameCacheOrder: [String] = []
  private var animationFrameRateMeter = AnimationFrameRateMeter()
  private var lastPresentedAnimationFrameID: UUID?

  var isAnimating: Bool { animationDirection != nil }
  var isBusy: Bool {
    isWorking || isUpdatingAppearance || isAnimating
  }
  var isInteractionLocked: Bool { isBusy || isAnimationRendering }

  init(
    lastPlaceStore: LastPlaceStore = LastPlaceStore(),
    chartAppearanceStore: ChartAppearanceStore = ChartAppearanceStore(),
    suggestedPlacesStore: SuggestedPlacesStore = SuggestedPlacesStore()
  ) {
    self.lastPlaceStore = lastPlaceStore
    self.chartAppearanceStore = chartAppearanceStore
    self.suggestedPlacesStore = suggestedPlacesStore
    location = lastPlaceStore.location
    chartStyle = chartAppearanceStore.chartStyle
    canvasSize = chartAppearanceStore.canvasSize
    lightBackground = chartAppearanceStore.lightBackground
    suggestedPlaces = suggestedPlacesStore.places
  }

  func request(
    for currentInstant: Date,
    resolvedPlace: AstrologPlace? = nil
  ) throws -> ChartRequest {
    let requestedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !requestedLocation.isEmpty else {
      throw AtlasResolverError.placeNotFound(requestedLocation)
    }
    guard let resources = Bundle.main.resourceURL else { throw AstrologAppError.missingEngine }
    let place = try resolvedPlace ?? AtlasResolver.resolve(
      requestedLocation, atlasURL: resources.appendingPathComponent("atlas.as"))
    guard let selectedTimeZone = place.timeZone else {
      throw AtlasResolverError.invalidTimeZone(place.timeZoneIdentifier)
    }

    let sourceMode: AstrologSourceMode = useCurrentMoment ? .currentMoment : .manual
    let moment: AstrologMoment
    if useCurrentMoment {
      moment = try astrologMoment(for: currentInstant, at: selectedTimeZone)
    } else {
      var displayCalendar = Calendar(identifier: .gregorian)
      displayCalendar.timeZone = displayTimeZone
      let enteredComponents = displayCalendar.dateComponents(
        [.year, .month, .day, .hour, .minute], from: chartDate)
      moment = try astrologMoment(forLocalCivilTime: enteredComponents, at: selectedTimeZone)
    }

    return ChartRequest(
      requestedLocation: requestedLocation,
      sourceMode: sourceMode,
      moment: moment,
      place: place,
      style: chartStyle,
      canvas: canvasSize,
      lightBackground: lightBackground)
  }

  func generate(currentInstant: Date = Date()) async {
    await generate(currentInstant: currentInstant, updatesInPlace: false)
  }

  func selectSuggestedPlace(_ place: String, currentInstant: Date = Date()) async {
    guard !isInteractionLocked else { return }
    suggestedPlaces = suggestedPlacesStore.recordUse(of: place)
    location = place
    await generate(currentInstant: currentInstant, updatesInPlace: true)
  }

  func loadAtlasPlaces() async {
    guard atlasPlaces.isEmpty, !isLoadingPlaces else { return }
    guard let atlasURL = Bundle.main.resourceURL?.appendingPathComponent("atlas.as") else {
      errorMessage = AstrologAppError.missingEngine.localizedDescription
      return
    }
    isLoadingPlaces = true
    defer { isLoadingPlaces = false }
    do {
      atlasPlaces = try await Task.detached(priority: .userInitiated) {
        try AtlasResolver.places(at: atlasURL)
      }.value
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func selectAtlasPlace(_ place: AstrologPlace, currentInstant: Date = Date()) async {
    guard !isInteractionLocked else { return }
    location = place.displayName
    suggestedPlaces = suggestedPlacesStore.recordUse(of: place.displayName)
    await generate(
      currentInstant: currentInstant,
      updatesInPlace: true,
      resolvedPlace: place)
  }

  func saveLightBackgroundPreference() {
    chartAppearanceStore.saveLightBackground(lightBackground)
  }

  func saveChartStylePreference() {
    chartAppearanceStore.saveChartStyle(chartStyle)
  }

  func saveCanvasSizePreference() {
    chartAppearanceStore.saveCanvasSize(canvasSize)
  }

  private func generate(
    currentInstant: Date,
    updatesInPlace: Bool,
    resolvedPlace: AstrologPlace? = nil
  ) async {
    guard !isInteractionLocked else { return }
    guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      errorMessage = "Enter a city or place before generating the chart."
      return
    }

    resetSolarSystemZoomState()
    if updatesInPlace {
      isUpdatingAppearance = true
    } else {
      isWorking = true
    }
    defer {
      if updatesInPlace {
        isUpdatingAppearance = false
      } else {
        isWorking = false
      }
    }
    errorMessage = nil
    statusText = updatesInPlace ? "Updating place…" : "Calculating chart…"
    do {
      let request = try request(for: currentInstant, resolvedPlace: resolvedPlace)
      let chart = try await Task.detached(priority: .userInitiated) {
        let calculation = try AstrologEngine.calculate(request)
        return try AstrologRenderer.render(calculation)
      }.value
      generatedChart = chart
      clearAnimationFrameCache(keeping: chart)
      cacheSolarSystemChart(chart)
      lastPlaceStore.save(request.requestedLocation)
      displayTimeZone = request.place.timeZone ?? displayTimeZone
      chartDate = request.moment.instant
      statusText = "Updated just now"
    } catch {
      errorMessage = error.localizedDescription
      statusText = "Couldn’t generate chart"
    }
  }

  func updateChartRendering() async {
    guard let chart = generatedChart, !isInteractionLocked else { return }

    let request = chart.request.withRenderingOptions(
      style: chartStyle,
      canvas: canvasSize,
      lightBackground: lightBackground)
    guard request.style != chart.request.style ||
          request.canvas != chart.request.canvas ||
          request.lightBackground != chart.request.lightBackground else { return }

    resetAnimationState()
    cancelQueuedSolarSystemZoom()
    isUpdatingAppearance = true
    errorMessage = nil
    statusText = "Updating chart…"
    let calculation = CalculatedChart(request: request, result: chart.result)
    do {
      let updatedChart = try await Task.detached(priority: .userInitiated) {
        try AstrologRenderer.render(calculation)
      }.value
      generatedChart = updatedChart
      clearAnimationFrameCache(keeping: updatedChart)
      clearSolarSystemChartCache()
      cacheSolarSystemChart(updatedChart)
      statusText = "Chart updated"
    } catch {
      chartStyle = chart.request.style
      canvasSize = chart.request.canvas
      lightBackground = chart.request.lightBackground
      errorMessage = error.localizedDescription
      statusText = "Couldn’t update chart"
    }
    isUpdatingAppearance = false
  }

  func queueSolarSystemZoom(_ command: SolarSystemZoomCommand) {
    guard generatedChart?.request.style == .solarSystem else { return }
    switch command {
    case .change(let delta):
      pendingSolarSystemZoomDelta += delta
    case .reset:
      pendingSolarSystemZoomDelta = 0
      solarSystemZoomResetRequested = true
    }

    scheduleSolarSystemZoomIfNeeded()
  }

  private func scheduleSolarSystemZoomIfNeeded() {
    guard solarSystemZoomTask == nil else { return }
    let taskID = UUID()
    solarSystemZoomTaskID = taskID
    solarSystemZoomTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await Task.sleep(nanoseconds: 30_000_000)
      } catch {
        if self.solarSystemZoomTaskID == taskID {
          self.solarSystemZoomTask = nil
          self.solarSystemZoomTaskID = nil
        }
        return
      }
      let delta = max(-500, min(500, self.pendingSolarSystemZoomDelta))
      let reset = self.solarSystemZoomResetRequested
      self.pendingSolarSystemZoomDelta = 0
      self.solarSystemZoomResetRequested = false
      await self.applySolarSystemZoom(delta: delta, reset: reset)
      guard self.solarSystemZoomTaskID == taskID else { return }
      self.solarSystemZoomTask = nil
      self.solarSystemZoomTaskID = nil
      if self.pendingSolarSystemZoomDelta != 0 || self.solarSystemZoomResetRequested {
        self.scheduleSolarSystemZoomIfNeeded()
      }
    }
  }

  private func applySolarSystemZoom(delta: Double, reset: Bool) async {
    guard let chart = generatedChart,
          chart.request.style == .solarSystem,
          chartStyle == .solarSystem,
          !isWorking,
          !isUpdatingAppearance,
          !isAnimating,
          !isAnimationRendering else { return }
    let currentRadius = chart.request.solarSystemRadiusAU
    let requestedRadius = reset
      ? ChartRequest.defaultSolarSystemRadiusAU
      : currentRadius * exp(delta * 0.002)
    let radius = max(
      ChartRequest.minimumSolarSystemRadiusAU,
      min(ChartRequest.maximumSolarSystemRadiusAU, requestedRadius))
    guard abs(radius - currentRadius) > 0.000001 else {
      if radius == ChartRequest.minimumSolarSystemRadiusAU {
        statusText = "Maximum zoom: 0.0001 AU radius"
      }
      return
    }

    let request = chart.request.withSolarSystemRadiusAU(radius)
    if let cachedChart = solarSystemChartCache[solarSystemCacheKey(for: request)] {
      generatedChart = cachedChart
      statusText = solarSystemRadiusStatus(radius)
      return
    }

    let revision = solarSystemZoomRevision
    let calculation = CalculatedChart(request: request, result: chart.result)
    do {
      let renderedChart = try await Task.detached(priority: .userInitiated) {
        try AstrologRenderer.render(calculation)
      }.value
      guard revision == solarSystemZoomRevision,
            chartStyle == .solarSystem else { return }
      generatedChart = renderedChart
      cacheSolarSystemChart(renderedChart)
      statusText = solarSystemRadiusStatus(radius)
    } catch {
      guard revision == solarSystemZoomRevision else { return }
      errorMessage = "Astrolog could not render that zoom level. The previous chart was kept."
      statusText = "Zoom unchanged"
    }
  }

  private func solarSystemRadiusStatus(_ radius: Double) -> String {
    String(
      format: "Solar System radius: %.3g AU",
      locale: Locale(identifier: "en_US_POSIX"), radius)
  }

  private func solarSystemCacheKey(for request: ChartRequest) -> String {
    String(
      format: "%@|%@|%d|%.6f",
      locale: Locale(identifier: "en_US_POSIX"),
      request.canvas.rawValue,
      request.style.rawValue,
      request.lightBackground ? 1 : 0,
      request.solarSystemRadiusAU)
  }

  private func cacheSolarSystemChart(_ chart: RenderedChart) {
    guard chart.request.style == .solarSystem else { return }
    let key = solarSystemCacheKey(for: chart.request)
    solarSystemChartCache[key] = chart
    solarSystemChartCacheOrder.removeAll { $0 == key }
    solarSystemChartCacheOrder.append(key)
    while solarSystemChartCacheOrder.count > 16 {
      let discardedKey = solarSystemChartCacheOrder.removeFirst()
      solarSystemChartCache.removeValue(forKey: discardedKey)
    }
  }

  private func clearSolarSystemChartCache() {
    solarSystemChartCache.removeAll()
    solarSystemChartCacheOrder.removeAll()
  }

  private func cancelQueuedSolarSystemZoom() {
    solarSystemZoomRevision += 1
    solarSystemZoomTask?.cancel()
    solarSystemZoomTask = nil
    solarSystemZoomTaskID = nil
    pendingSolarSystemZoomDelta = 0
    solarSystemZoomResetRequested = false
  }

  private func resetSolarSystemZoomState() {
    cancelQueuedSolarSystemZoom()
    clearSolarSystemChartCache()
  }

  func toggleAnimation(_ direction: ChartAnimationDirection) {
    if animationDirection == direction {
      pauseAnimation()
      return
    }
    startAnimation(direction)
  }

  func pauseAnimation(updateStatus: Bool = true) {
    animationRevision += 1
    animationTask?.cancel()
    animationTask = nil
    animationDirection = nil
    isAnimationRendering = false
    if updateStatus, generatedChart != nil {
      statusText = "Animation paused"
    }
  }

  func recordPresentedAnimationFrame(_ frameID: UUID) {
    guard isAnimating,
          generatedChart?.id == frameID,
          lastPresentedAnimationFrameID != frameID else { return }
    lastPresentedAnimationFrameID = frameID
    if let framesPerSecond = animationFrameRateMeter.recordPresentation(
      at: ProcessInfo.processInfo.systemUptime) {
      measuredAnimationFPS = framesPerSecond
    }
  }

  func stepAnimation(_ direction: ChartAnimationDirection) async {
    guard generatedChart != nil, !isWorking, !isUpdatingAppearance,
          !isAnimationRendering else { return }
    pauseAnimation(updateStatus: false)
    animationRevision += 1
    let revision = animationRevision
    _ = await renderAnimationFrame(direction: direction, revision: revision)
  }

  private func startAnimation(_ direction: ChartAnimationDirection) {
    guard let chart = generatedChart, !isWorking, !isUpdatingAppearance,
          !isAnimationRendering else { return }
    pauseAnimation(updateStatus: false)
    useCurrentMoment = false
    chartDate = chart.request.moment.instant
    cacheAnimationFrame(chart)
    animationFrameRateMeter.reset()
    lastPresentedAnimationFrameID = nil
    measuredAnimationFPS = nil
    animationDirection = direction
    statusText = direction == .forward ? "Starting forward animation…" : "Starting reverse animation…"
    animationRevision += 1
    let revision = animationRevision
    animationTask = Task { [weak self] in
      await self?.runAnimation(direction: direction, revision: revision)
    }
  }

  private func runAnimation(
    direction: ChartAnimationDirection,
    revision: Int
  ) async {
    while !Task.isCancelled, revision == animationRevision {
      let frameStarted = Date()
      guard await renderAnimationFrame(direction: direction, revision: revision) else { break }
      let remainingDelay = animationRate.minimumFrameInterval
        - Date().timeIntervalSince(frameStarted)
      if remainingDelay > 0 {
        do {
          try await Task.sleep(
            nanoseconds: UInt64((remainingDelay * 1_000_000_000).rounded()))
        } catch {
          break
        }
      }
    }
    guard revision == animationRevision else { return }
    animationTask = nil
    animationDirection = nil
    isAnimationRendering = false
  }

  private func renderAnimationFrame(
    direction: ChartAnimationDirection,
    revision: Int
  ) async -> Bool {
    guard let chart = generatedChart,
          let timeZone = chart.request.place.timeZone,
          let nextInstant = animationStep.advancing(
            chart.request.moment.instant, direction: direction, in: timeZone) else {
      errorMessage = "The next animation time could not be calculated."
      statusText = "Animation stopped"
      return false
    }

    do {
      let nextMoment = try astrologMoment(for: nextInstant, at: timeZone)
      let request = chart.request.withMoment(nextMoment)
      let nextChart: RenderedChart
      if let cached = animationFrameCache[animationCacheKey(for: request)] {
        nextChart = cached
      } else {
        isAnimationRendering = true
        nextChart = try await Task.detached(priority: .userInitiated) {
          let calculation = try AstrologEngine.calculate(request)
          return try AstrologRenderer.render(calculation)
        }.value
      }

      guard revision == animationRevision, !Task.isCancelled else {
        return false
      }

      generatedChart = nextChart
      useCurrentMoment = false
      displayTimeZone = timeZone
      chartDate = nextMoment.instant
      clearSolarSystemChartCache()
      cacheSolarSystemChart(nextChart)
      cacheAnimationFrame(nextChart)
      isAnimationRendering = false
      errorMessage = nil
      if animationDirection == nil {
        let directionText = direction == .forward ? "forward" : "backward"
        statusText = "Stepped \(directionText) · \(animationStep.rawValue)"
      } else {
        let directionText = direction == .forward ? "Forward" : "Reverse"
        statusText = "\(directionText) · \(animationStep.rawValue) · \(animationRate.rawValue)"
      }
      return true
    } catch {
      guard revision == animationRevision else { return false }
      isAnimationRendering = false
      errorMessage = error.localizedDescription
      statusText = "Animation stopped"
      return false
    }
  }

  private func animationCacheKey(for request: ChartRequest) -> String {
    String(
      format: "%.6f|%@|%@|%@|%d|%.6f",
      locale: Locale(identifier: "en_US_POSIX"),
      request.moment.instant.timeIntervalSince1970,
      request.requestedLocation,
      request.style.rawValue,
      request.canvas.rawValue,
      request.lightBackground ? 1 : 0,
      request.solarSystemRadiusAU)
  }

  private func cacheAnimationFrame(_ chart: RenderedChart) {
    let key = animationCacheKey(for: chart.request)
    animationFrameCache[key] = chart
    animationFrameCacheOrder.removeAll { $0 == key }
    animationFrameCacheOrder.append(key)
    while animationFrameCacheOrder.count > 8 {
      let discardedKey = animationFrameCacheOrder.removeFirst()
      animationFrameCache.removeValue(forKey: discardedKey)
    }
  }

  private func clearAnimationFrameCache(keeping chart: RenderedChart? = nil) {
    animationFrameCache.removeAll()
    animationFrameCacheOrder.removeAll()
    if let chart { cacheAnimationFrame(chart) }
  }

  private func resetAnimationState() {
    pauseAnimation(updateStatus: false)
    clearAnimationFrameCache(keeping: generatedChart)
  }

  func exportSVG() {
    guard let chart = generatedChart else { return }
    let panel = NSSavePanel()
    panel.title = "Export Astrolog-AS Chart"
    panel.nameFieldStringValue = "astrolog-as-chart.svg"
    panel.allowedContentTypes = [.svg]
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      try chart.svg.write(to: destination, atomically: true, encoding: .utf8)
      statusText = "SVG exported"
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func exportReport() {
    guard let chart = generatedChart else { return }
    let panel = NSSavePanel()
    panel.title = "Export Astrolog-AS Report"
    panel.nameFieldStringValue = "astrolog-as-report.txt"
    panel.allowedContentTypes = [.plainText]
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      try chart.result.rawReport.write(to: destination, atomically: true, encoding: .utf8)
      statusText = "Report exported"
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func exportPNG() async {
    guard let chart = generatedChart else { return }
    let panel = NSSavePanel()
    panel.title = "Export Astrolog-AS Chart"
    panel.nameFieldStringValue = "astrolog-as-chart.png"
    panel.allowedContentTypes = [.png]
    guard panel.runModal() == .OK, let destination = panel.url else { return }

    isWorking = true
    statusText = "Rendering PNG…"
    let temporaryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("astrolog-export-\(UUID().uuidString).png")
    do {
      try await Task.detached(priority: .userInitiated) {
        try AstrologRenderer.generatePNG(chart.calculation, at: temporaryURL)
      }.value
      try replaceFile(at: destination, with: temporaryURL)
      try? FileManager.default.removeItem(at: temporaryURL)
      statusText = "PNG exported"
    } catch {
      errorMessage = error.localizedDescription
      statusText = "Export failed"
    }
    isWorking = false
  }

  private func replaceFile(at destination: URL, with source: URL) throws {
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: source, to: destination)
  }
}

final class ChartWebView: WKWebView, WKNavigationDelegate {
  var chartSVG: String?
  var clipboardSVG: String?
  var onFramePresented: ((UUID) -> Void)?
  private var renderedChartID: UUID?
  private var tooltipsEnabled = true

  func displayChart(_ svg: String, id: UUID) {
    chartSVG = svg
    guard renderedChartID != id else { return }
    let hasRenderedChart = renderedChartID != nil
    renderedChartID = id

    guard hasRenderedChart,
          let script = try? SVGDocumentUpdater.replacementJavaScript(
            for: svg, frameID: id) else {
      loadChartData(svg, id: id)
      return
    }

    evaluateJavaScript(script) { [weak self] _, error in
      guard let self, error != nil, self.renderedChartID == id else { return }
      self.loadChartData(svg, id: id)
    }
  }

  private func loadChartData(_ svg: String, id: UUID) {
    renderedChartID = id
    load(
      Data(svg.utf8),
      mimeType: "image/svg+xml",
      characterEncodingName: "utf-8",
      baseURL: Bundle.main.resourceURL ?? URL(fileURLWithPath: "/"))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
    guard let renderedChartID else { return }
    onFramePresented?(renderedChartID)
  }

  func setTooltipsEnabled(_ enabled: Bool) {
    guard enabled != tooltipsEnabled else { return }
    tooltipsEnabled = enabled
    let script = enabled ? """
      document.documentElement.removeAttribute('data-astrolog-tooltips-disabled');
      """ : """
      document.documentElement.setAttribute('data-astrolog-tooltips-disabled', 'true');
      document.querySelector('#astrolog-as-tooltip-popup')?.setAttribute('display', 'none');
      document.querySelector('#astrolog-as-aspect-focus')?.setAttribute('display', 'none');
      """
    evaluateJavaScript(script)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let event = NSApp.currentEvent else { return super.hitTest(point) }
    if event.type == .rightMouseDown ||
        (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) {
      return self
    }
    return super.hitTest(point)
  }

  override func mouseDown(with event: NSEvent) {
    if event.modifierFlags.contains(.control) {
      rightMouseDown(with: event)
    } else {
      super.mouseDown(with: event)
    }
  }

  override func rightMouseDown(with event: NSEvent) {
    let menu = NSMenu()
    let copyItem = NSMenuItem(
      title: "Copy Chart Image",
      action: #selector(copyChart(_:)),
      keyEquivalent: "")
    copyItem.target = self
    menu.addItem(copyItem)
    menu.addItem(.separator())

    let reloadItem = NSMenuItem(title: "Reload", action: #selector(reloadChart(_:)), keyEquivalent: "")
    reloadItem.target = self
    menu.addItem(reloadItem)

    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }

  @objc private func copyChart(_ sender: Any?) {
    guard let clipboardSVG else {
      NSSound.beep()
      return
    }
    let svgData = Data(clipboardSVG.utf8)
    let pasteboard = NSPasteboard.general
    let svgType = NSPasteboard.PasteboardType("public.svg-image")
    pasteboard.clearContents()
    pasteboard.declareTypes([svgType], owner: nil)
    pasteboard.setData(svgData, forType: svgType)

    let suppressOverlays = """
    (() => {
      const nodes = document.querySelectorAll(
        '#astrolog-as-aspect-focus, #astrolog-as-tooltips, #astrolog-as-tooltip-popup');
      nodes.forEach(node => {
        node.dataset.astrologCopyDisplay = node.style.display;
        node.style.display = 'none';
      });
    })();
    """
    evaluateJavaScript(suppressOverlays) { [weak self] _, _ in
      guard let self else { return }
      let configuration = WKSnapshotConfiguration()
      configuration.rect = self.bounds
      configuration.snapshotWidth = NSNumber(
        value: max(1, min(1800, self.bounds.width * 2)))
      self.takeSnapshot(with: configuration) { [weak self] image, error in
        guard let self else { return }
        self.restoreClipboardOverlays()
        guard error == nil,
              let image,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
          NSSound.beep()
          return
        }

        pasteboard.clearContents()
        pasteboard.declareTypes([svgType, .png, .tiff], owner: nil)
        pasteboard.setData(svgData, forType: svgType)
        pasteboard.setData(pngData, forType: .png)
        pasteboard.setData(tiffData, forType: .tiff)
      }
    }
  }

  private func restoreClipboardOverlays() {
    evaluateJavaScript("""
    (() => {
      const nodes = document.querySelectorAll('[data-astrolog-copy-display]');
      nodes.forEach(node => {
        node.style.display = node.dataset.astrologCopyDisplay;
        delete node.dataset.astrologCopyDisplay;
      });
    })();
    """)
  }

  @objc private func reloadChart(_ sender: Any?) {
    if let chartSVG, let renderedChartID {
      loadChartData(chartSVG, id: renderedChartID)
    } else {
      reload()
    }
  }
}

enum SolarSystemZoomCommand {
  case change(Double)
  case reset
}

struct SVGPreview: NSViewRepresentable {
  let chartID: UUID
  let svg: String
  let clipboardSVG: String
  let tooltipsEnabled: Bool
  let onSolarSystemZoom: (SolarSystemZoomCommand) -> Void
  let onFramePresented: (UUID) -> Void

  final class Coordinator: NSObject, WKScriptMessageHandler {
    var onSolarSystemZoom: (SolarSystemZoomCommand) -> Void
    var onFramePresented: (UUID) -> Void

    init(
      onSolarSystemZoom: @escaping (SolarSystemZoomCommand) -> Void,
      onFramePresented: @escaping (UUID) -> Void
    ) {
      self.onSolarSystemZoom = onSolarSystemZoom
      self.onFramePresented = onFramePresented
    }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      if message.name == "chartFramePresented",
         let rawFrameID = message.body as? String,
         let frameID = UUID(uuidString: rawFrameID) {
        onFramePresented(frameID)
        return
      }
      guard message.name == "solarSystemZoom",
            let body = message.body as? [String: Any] else { return }
      if body["reset"] as? Bool == true {
        onSolarSystemZoom(.reset)
      } else if let delta = body["delta"] as? Double, delta.isFinite {
        onSolarSystemZoom(.change(delta))
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      onSolarSystemZoom: onSolarSystemZoom,
      onFramePresented: onFramePresented)
  }

  func makeNSView(context: Context) -> ChartWebView {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(context.coordinator, name: "solarSystemZoom")
    configuration.userContentController.add(context.coordinator, name: "chartFramePresented")
    let webView = ChartWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = webView
    webView.onFramePresented = context.coordinator.onFramePresented
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsMagnification = false
    webView.clipboardSVG = clipboardSVG
    return webView
  }

  func updateNSView(_ webView: ChartWebView, context: Context) {
    context.coordinator.onSolarSystemZoom = onSolarSystemZoom
    context.coordinator.onFramePresented = onFramePresented
    webView.onFramePresented = onFramePresented
    webView.clipboardSVG = clipboardSVG
    webView.displayChart(svg, id: chartID)
    webView.setTooltipsEnabled(tooltipsEnabled)
  }

  static func dismantleNSView(_ webView: ChartWebView, coordinator: Coordinator) {
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: "solarSystemZoom")
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: "chartFramePresented")
  }
}

struct ChartImageView: View {
  let chart: RenderedChart
  let tooltipsEnabled: Bool
  let onSolarSystemZoom: (SolarSystemZoomCommand) -> Void
  let onFramePresented: (UUID) -> Void

  var body: some View {
    SVGPreview(
      chartID: chart.id,
      svg: chart.svg,
      clipboardSVG: chart.engineSVG,
      tooltipsEnabled: tooltipsEnabled,
      onSolarSystemZoom: onSolarSystemZoom,
      onFramePresented: onFramePresented)
      .background(Color(nsColor: .windowBackgroundColor))
      .accessibilityLabel(
        "\(chart.request.style.rawValue) for \(chart.result.metadata.place.displayName), " +
        "calculated from \(chart.result.bodies.count) bodies and \(chart.result.houses.count) houses")
  }
}

struct PositionsResultView: View {
  let result: ChartResult

  private let houseColumns = [
    GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 8, alignment: .leading)
  ]

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        Label(result.metadata.place.displayName, systemImage: "mappin.and.ellipse")
        Label(result.metadata.moment.timeZoneIdentifier, systemImage: "clock")
        Label("\(result.metadata.houseSystem) houses", systemImage: "circle.grid.cross")
        Spacer()
        Text("\(result.aspects.count) aspects")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 18)
      .padding(.vertical, 10)

      Divider()

      Table(result.bodies) {
        TableColumn("Body", value: \.name)
          .width(min: 90, ideal: 115)
        TableColumn("Position") { body in
          Text(body.position.displayText)
            .monospacedDigit()
        }
        .width(min: 130, ideal: 165)
        TableColumn("Motion") { body in
          Text(body.isRetrograde ? "Retrograde" : "Direct")
            .foregroundStyle(body.isRetrograde ? .orange : .secondary)
        }
        .width(min: 75, ideal: 90)
        TableColumn("House") { body in
          Text(body.house.map(String.init) ?? "—")
            .monospacedDigit()
        }
        .width(55)
        TableColumn("Latitude") { body in
          Text(body.latitudeText).monospacedDigit()
        }
        .width(min: 75, ideal: 90)
        TableColumn("Velocity") { body in
          Text(body.velocityText).monospacedDigit()
        }
        .width(min: 90, ideal: 110)
      }
      .contextMenu {
        Button {
          CSVClipboard.copy(PositionCSVEncoder.encode(result.bodies))
        } label: {
          Label("Copy Positions as CSV", systemImage: "doc.on.doc")
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 8) {
        Text("House cusps")
          .font(.headline)
        LazyVGrid(columns: houseColumns, alignment: .leading, spacing: 8) {
          ForEach(result.houses) { house in
            VStack(alignment: .leading, spacing: 3) {
              Text(house.name)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text(house.position.displayText)
                .font(.callout.weight(.medium))
                .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      .padding(14)
    }
    .background(Color(nsColor: .textBackgroundColor))
  }
}

struct AspectsResultView: View {
  let result: ChartResult
  @State private var sortOrder = [KeyPathComparator(\ChartAspect.rank)]

  private var sortedAspects: [ChartAspect] {
    result.aspects.sorted(using: sortOrder)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        Label(result.metadata.place.displayName, systemImage: "mappin.and.ellipse")
        Label("\(result.aspects.count) major aspects", systemImage: "arrow.triangle.branch")
        Spacer()
        Text("Ranked by power")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 18)
      .padding(.vertical, 10)

      Divider()

      if result.aspects.isEmpty {
        ContentUnavailableView(
          "No Major Aspects", systemImage: "arrow.triangle.branch",
          description: Text("Astrolog did not report any major aspects for this chart."))
      } else {
        Table(sortedAspects, sortOrder: $sortOrder) {
          TableColumn("Rank", value: \.rank) { aspect in
            Text(aspect.rank, format: .number)
              .monospacedDigit()
          }
          .width(55)

          TableColumn("First body", value: \.firstBody)
            .width(min: 90, ideal: 120)

          TableColumn("Aspect", value: \.kind.name) { aspect in
            HStack(spacing: 7) {
              Circle()
                .fill(color(for: aspect.kind))
                .frame(width: 8, height: 8)
              Text(aspect.kind.name)
            }
          }
          .width(min: 100, ideal: 125)

          TableColumn("Second body", value: \.secondBody)
            .width(min: 90, ideal: 120)

          TableColumn("Orb", value: \.orbMagnitude) { aspect in
            Text(orbText(aspect.orbDegrees))
              .monospacedDigit()
          }
          .width(min: 70, ideal: 85)

          TableColumn("Power", value: \.power) { aspect in
            Text(aspect.power, format: .number.precision(.fractionLength(2)))
              .monospacedDigit()
          }
          .width(min: 65, ideal: 80)
        }
        .contextMenu {
          Button {
            copyAspectsAsCSV()
          } label: {
            Label("Copy Aspects as CSV", systemImage: "doc.on.doc")
          }
        }
      }
    }
    .background(Color(nsColor: .textBackgroundColor))
  }

  private func orbText(_ orb: Double) -> String {
    let totalMinutes = Int((abs(orb) * 60.0).rounded())
    return "\(totalMinutes / 60)°\(String(format: "%02d", totalMinutes % 60))′"
  }

  private func copyAspectsAsCSV() {
    CSVClipboard.copy(AspectCSVEncoder.encode(sortedAspects))
  }

  private func color(for kind: AspectKind) -> Color {
    switch kind {
    case .conjunction: return .yellow
    case .opposition: return .blue
    case .square: return .red
    case .trine: return .green
    case .sextile: return .cyan
    }
  }
}

struct AtlasPlacePickerView: View {
  @ObservedObject var model: ChartViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  private var matches: [AstrologPlace] {
    AtlasResolver.search(query, in: model.atlasPlaces)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Find a Place")
            .font(.title2.weight(.semibold))
          Text("Search the bundled Astrolog atlas by city, state, or country.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Close") { dismiss() }
          .keyboardShortcut(.cancelAction)
      }
      .padding(20)

      TextField("City, state, or country", text: $query)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)

      Divider()

      Group {
        if model.isLoadingPlaces {
          ProgressView("Loading places…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          ContentUnavailableView(
            "Search 33,000+ Places",
            systemImage: "magnifyingglass",
            description: Text("Start typing a city name, then add a state or country to narrow the results."))
        } else if matches.isEmpty {
          ContentUnavailableView.search(text: query)
        } else {
          List(matches, id: \.atlasIdentifier) { place in
            Button {
              dismiss()
              Task { await model.selectAtlasPlace(place) }
            } label: {
              HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                  .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                  Text(place.displayName)
                    .foregroundStyle(.primary)
                  Text(place.timeZoneIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
              }
              .contentShape(Rectangle())
              .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: 620, height: 520)
    .task { await model.loadAtlasPlaces() }
  }
}

struct SidebarView: View {
  @ObservedObject var model: ChartViewModel
  @State private var isShowingPlaces = false

  var body: some View {
    Form {
      Section("Place") {
        TextField("City or place", text: $model.location)
          .textFieldStyle(.roundedBorder)
          .onSubmit { Task { await model.generate() } }
          .disabled(model.isBusy)

        HStack {
          Menu("Suggested places") {
            ForEach(model.suggestedPlaces, id: \.self) { place in
              Button(place) {
                Task { await model.selectSuggestedPlace(place) }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Button("Places…") {
            isShowingPlaces = true
          }
        }
        .disabled(model.isBusy)
      }

      Section("Moment") {
        Toggle("Use current moment", isOn: $model.useCurrentMoment)
          .disabled(model.isBusy)
        DatePicker(
          "Date and time", selection: $model.chartDate,
          displayedComponents: [.date, .hourAndMinute])
          .disabled(model.useCurrentMoment || model.isBusy)
          .environment(\.timeZone, model.displayTimeZone)
        Text(model.displayTimeZone.identifier)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Chart") {
        Picker("Style", selection: $model.chartStyle) {
          ForEach(ChartStyle.allCases) { style in
            Label(style.rawValue, systemImage: style.symbol).tag(style)
          }
        }
        .disabled(model.isBusy)
        .onChange(of: model.chartStyle) {
          model.saveChartStylePreference()
          Task { await model.updateChartRendering() }
        }
        Picker("Detail", selection: $model.canvasSize) {
          ForEach(CanvasSize.allCases) { size in
            Text(size.rawValue).tag(size)
          }
        }
        .disabled(model.isBusy)
        .onChange(of: model.canvasSize) {
          model.saveCanvasSizePreference()
          Task { await model.updateChartRendering() }
        }
        Toggle("Light background", isOn: $model.lightBackground)
          .disabled(model.isBusy)
          .onChange(of: model.lightBackground) {
            model.saveLightBackgroundPreference()
            Task { await model.updateChartRendering() }
          }
      }

      Section {
        Button {
          generateAfterCommittingEdits()
        } label: {
          HStack {
            Spacer()
            if model.isWorking {
              ProgressView().controlSize(.small)
            } else {
              Image(systemName: "sparkles")
            }
            Text(model.isWorking ? "Working…" : "Generate Chart")
            Spacer()
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.isBusy)
      }

      if let error = model.errorMessage {
        Section {
          Label(error, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .font(.callout)
        }
      }

      Section("About") {
        VStack(alignment: .leading, spacing: 8) {
          AboutAttribution(
            component: "Astrolog-AS",
            detail: "Native macOS interface by Crinklebine")
          AboutAttribution(
            component: "Astrolog 8.00",
            detail: "Calculation and graphics engine by Walter D. Pullen")
          AboutAttribution(
            component: "Swiss Ephemeris 2.10.03",
            detail: "Included for astronomical calculations")
        }
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 285, idealWidth: 310)
    .allowsHitTesting(!model.isAnimationRendering)
    .sheet(isPresented: $isShowingPlaces) {
      AtlasPlacePickerView(model: model)
    }
  }

  private func generateAfterCommittingEdits() {
    NSApp.keyWindow?.makeFirstResponder(nil)
    DispatchQueue.main.async {
      Task { await model.generate() }
    }
  }
}

private struct AboutAttribution: View {
  let component: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(component)
        .fontWeight(.semibold)
      Text(detail)
        .foregroundStyle(.tertiary)
    }
    .font(.caption)
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct AnimationControlsView: View {
  @ObservedObject var model: ChartViewModel

  var body: some View {
    HStack(spacing: 10) {
      HStack(spacing: 4) {
        Button {
          Task { await model.stepAnimation(.backward) }
        } label: {
          Label("Previous frame", systemImage: "backward.frame.fill")
            .labelStyle(.iconOnly)
        }
        .help("Move backward by \(model.animationStep.rawValue)")
        .disabled(model.isAnimating)
        .allowsHitTesting(!model.isAnimationRendering)

        Button {
          model.toggleAnimation(.backward)
        } label: {
          Label("Play backward", systemImage: "backward.fill")
            .labelStyle(.iconOnly)
        }
        .help(model.animationDirection == .backward ? "Pause" : "Play backward")
        .foregroundStyle(
          model.animationDirection == .backward ? Color.accentColor : Color.primary)

        Button {
          model.pauseAnimation()
        } label: {
          Label("Pause", systemImage: "pause.fill")
            .labelStyle(.iconOnly)
        }
        .help("Pause animation")
        .disabled(!model.isAnimating)

        Button {
          model.toggleAnimation(.forward)
        } label: {
          Label("Play forward", systemImage: "forward.fill")
            .labelStyle(.iconOnly)
        }
        .help(model.animationDirection == .forward ? "Pause" : "Play forward")
        .foregroundStyle(
          model.animationDirection == .forward ? Color.accentColor : Color.primary)

        Button {
          Task { await model.stepAnimation(.forward) }
        } label: {
          Label("Next frame", systemImage: "forward.frame.fill")
            .labelStyle(.iconOnly)
        }
        .help("Move forward by \(model.animationStep.rawValue)")
        .disabled(model.isAnimating)
        .allowsHitTesting(!model.isAnimationRendering)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)

      Divider()
        .frame(height: 20)

      Picker("Step", selection: $model.animationStep) {
        ForEach(ChartAnimationStep.allCases) { step in
          Text(step.rawValue).tag(step)
        }
      }
      .pickerStyle(.menu)
      .frame(width: 155)

      Picker("Speed", selection: $model.animationRate) {
        ForEach(ChartAnimationRate.allCases) { rate in
          Text(rate.rawValue).tag(rate)
        }
      }
      .pickerStyle(.menu)
      .frame(width: 135)

      ProgressView()
        .controlSize(.small)
        .frame(width: 16, height: 16)
        .opacity(model.isAnimationRendering ? 1 : 0)
        .accessibilityHidden(!model.isAnimationRendering)
        .help("Rendering the next animation frame")

      Text(model.measuredAnimationFPS.map {
        String(format: "%.0f fps", locale: Locale(identifier: "en_US_POSIX"), $0)
      } ?? "— fps")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 50, alignment: .trailing)
        .opacity(model.isAnimating ? 1 : 0)
        .help("Frames actually presented, averaged over the last second")
        .accessibilityHidden(!model.isAnimating)
        .accessibilityLabel(
          model.measuredAnimationFPS.map {
            String(format: "Actual animation rate %.1f frames per second", $0)
          } ?? "Actual animation rate not measured")
    }
    .padding(.horizontal, 16)
    .frame(height: 42)
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Chart animation controls")
  }
}

struct ChartDetailView: View {
  @ObservedObject var model: ChartViewModel

  private var title: String {
    guard let chart = model.generatedChart else { return "Astrolog-AS" }
    switch model.selectedResult {
    case .chart: return chart.request.style.rawValue
    case .positions: return "Positions"
    case .aspects: return "Aspects"
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.title2.weight(.semibold))
          Text(model.generatedChart?.result.metadata.heading ?? "Create a chart to begin")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Picker("Result", selection: $model.selectedResult) {
          ForEach(ResultView.allCases) { resultView in
            Text(resultView.title).tag(resultView)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 300)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)

      Divider()

      Group {
        if let chart = model.generatedChart {
          switch model.selectedResult {
          case .chart:
            ChartImageView(
              chart: chart,
              tooltipsEnabled: !model.isAnimating,
              onSolarSystemZoom: { command in model.queueSolarSystemZoom(command) },
              onFramePresented: { frameID in
                model.recordPresentedAnimationFrame(frameID)
              })
          case .positions:
            PositionsResultView(result: chart.result)
              .id(chart.id)
              .onAppear { model.recordPresentedAnimationFrame(chart.id) }
          case .aspects:
            AspectsResultView(result: chart.result)
              .id(chart.id)
              .onAppear { model.recordPresentedAnimationFrame(chart.id) }
          }
        } else if model.isWorking {
          ProgressView("Calculating your chart…")
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ContentUnavailableView(
            "No Chart Yet", systemImage: "circle.hexagongrid",
            description: Text("Choose a place and moment, then generate a chart."))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      if model.generatedChart != nil {
        Divider()
        AnimationControlsView(model: model)
      }

      Divider()
      HStack {
        Label(
          model.statusText,
          systemImage: model.isAnimating
            ? "play.circle"
            : (model.isUpdatingAppearance
              ? "paintbrush" : (model.isWorking ? "clock" : "checkmark.circle")))
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text("Astrolog-AS · Astrolog 8.00 engine · Apple Silicon")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .frame(height: 30)
    }
    .toolbar {
      ToolbarItemGroup {
        Button {
          model.exportSVG()
        } label: {
          Label("Export SVG", systemImage: "square.and.arrow.up")
        }
        .disabled(model.generatedChart == nil || model.isBusy)
        .allowsHitTesting(!model.isAnimationRendering)

        Menu {
          Button("PNG Image…") { Task { await model.exportPNG() } }
          Button("Text Report…") { model.exportReport() }
        } label: {
          Label("More Exports", systemImage: "ellipsis.circle")
        }
        .disabled(model.generatedChart == nil || model.isBusy)
        .allowsHitTesting(!model.isAnimationRendering)
      }
    }
  }
}

struct ContentView: View {
  @StateObject private var model = ChartViewModel()

  var body: some View {
    NavigationSplitView {
      SidebarView(model: model)
        .navigationSplitViewColumnWidth(min: 285, ideal: 310, max: 360)
    } detail: {
      ChartDetailView(model: model)
    }
    .frame(minWidth: 1000, minHeight: 680)
    .task {
      if model.generatedChart == nil { await model.generate() }
    }
  }
}

@main
struct AstrologASMacApp: App {
  var body: some Scene {
    Window("Astrolog-AS", id: "main") {
      ContentView()
    }
    .defaultSize(width: 1240, height: 820)
  }
}
