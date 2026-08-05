import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum ChartStyle: String, CaseIterable, Identifiable {
  case wheel = "Birth Wheel"
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

    let calculationDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AstrologCalculation", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: calculationDirectory, withIntermediateDirectories: true)
    let positionsURL = calculationDirectory.appendingPathComponent("positions.as")

    let engineOutput = try run(arguments: request.chartArguments + [
      "-o0", positionsURL.path, "-v", "-a",
    ])
    guard let positions = try? String(contentsOf: positionsURL, encoding: .utf8) else {
      throw AstrologAppError.missingOutput
    }
    let result = try ChartResultParser.parse(
      positions: positions,
      report: engineOutput.standardOutput,
      sourceMode: request.sourceMode,
      moment: request.moment,
      place: request.place)
    return CalculatedChart(request: request, result: result)
  }
}

enum AstrologRenderer {
  static func render(_ calculation: CalculatedChart) throws -> RenderedChart {
    let request = calculation.request
    let previewDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AstrologPreview", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
    let svgURL = previewDirectory.appendingPathComponent("chart.svg")
    let size = request.canvas.dimensions

    var graphicArguments = request.chartArguments + request.style.engineArguments
    graphicArguments += ["-Xx0", "-Xw", String(size.0), String(size.1)]
    if request.lightBackground { graphicArguments.append("-Xr") }
    graphicArguments += ["-XV", "-Xo", svgURL.path]
    _ = try AstrologEngine.run(arguments: graphicArguments)

    guard FileManager.default.fileExists(atPath: svgURL.path) else {
      throw AstrologAppError.missingOutput
    }

    return RenderedChart(calculation: calculation, svgURL: svgURL)
  }

  static func generatePNG(_ calculation: CalculatedChart, at outputURL: URL) throws {
    let request = calculation.request
    let size = request.canvas.dimensions
    var arguments = request.chartArguments + request.style.engineArguments
    arguments += ["-Xx0", "-Xw", String(size.0), String(size.1)]
    if request.lightBackground { arguments.append("-Xr") }
    arguments += ["-Xbp", "-Xo", outputURL.path]
    _ = try AstrologEngine.run(arguments: arguments)
    guard FileManager.default.fileExists(atPath: outputURL.path) else {
      throw AstrologAppError.missingOutput
    }
  }
}

@MainActor
final class ChartViewModel: ObservableObject {
  @Published var location = "Douglas, Isle of Man"
  @Published var useCurrentMoment = true
  @Published var chartDate = Date()
  @Published var displayTimeZone = TimeZone(identifier: "Europe/Isle_of_Man") ?? .current
  @Published var chartStyle = ChartStyle.wheel
  @Published var canvasSize = CanvasSize.standard
  @Published var lightBackground = true
  @Published var selectedResult = 0
  @Published var generatedChart: RenderedChart?
  @Published var isWorking = false
  @Published var statusText = "Ready"
  @Published var errorMessage: String?

  let suggestedPlaces = [
    "Douglas, Isle of Man",
    "London, England",
    "New York, NY, USA",
    "Los Angeles, CA, USA",
    "Sydney, Australia",
    "Tokyo, Japan",
  ]

  func request(for currentInstant: Date) throws -> ChartRequest {
    let requestedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !requestedLocation.isEmpty else {
      throw AtlasResolverError.placeNotFound(requestedLocation)
    }
    guard let resources = Bundle.main.resourceURL else { throw AstrologAppError.missingEngine }
    let place = try AtlasResolver.resolve(
      requestedLocation,
      atlasURL: resources.appendingPathComponent("atlas.as"))
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
    guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      errorMessage = "Enter a city or place before generating the chart."
      return
    }

    isWorking = true
    errorMessage = nil
    statusText = "Calculating chart…"
    do {
      let request = try request(for: currentInstant)
      let chart = try await Task.detached(priority: .userInitiated) {
        let calculation = try AstrologEngine.calculate(request)
        return try AstrologRenderer.render(calculation)
      }.value
      generatedChart = chart
      displayTimeZone = request.place.timeZone ?? displayTimeZone
      chartDate = request.moment.instant
      statusText = "Updated just now"
    } catch {
      errorMessage = error.localizedDescription
      statusText = "Couldn’t generate chart"
    }
    isWorking = false
  }

  func exportSVG() {
    guard let chart = generatedChart else { return }
    let panel = NSSavePanel()
    panel.title = "Export Astrolog Chart"
    panel.nameFieldStringValue = "astrolog-chart.svg"
    panel.allowedContentTypes = [.svg]
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      try replaceFile(at: destination, with: chart.svgURL)
      statusText = "SVG exported"
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func exportReport() {
    guard let chart = generatedChart else { return }
    let panel = NSSavePanel()
    panel.title = "Export Astrolog Report"
    panel.nameFieldStringValue = "astrolog-report.txt"
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
    panel.title = "Export Astrolog Chart"
    panel.nameFieldStringValue = "astrolog-chart.png"
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

final class ChartWebView: WKWebView {
  var chartFileURL: URL?

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

    let backItem = NSMenuItem(title: "Back", action: #selector(navigateBack(_:)), keyEquivalent: "")
    backItem.target = self
    backItem.isEnabled = canGoBack
    menu.addItem(backItem)

    let reloadItem = NSMenuItem(title: "Reload", action: #selector(reloadChart(_:)), keyEquivalent: "")
    reloadItem.target = self
    menu.addItem(reloadItem)

    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }

  @objc private func copyChart(_ sender: Any?) {
    guard let chartFileURL,
          let svgData = try? Data(contentsOf: chartFileURL),
          let image = NSImage(data: svgData),
          let rasterImage = rasterizedClipboardImage(from: image),
          let tiffData = rasterImage.tiffRepresentation else {
      NSSound.beep()
      return
    }

    let pasteboard = NSPasteboard.general
    let svgType = NSPasteboard.PasteboardType("public.svg-image")
    var types: [NSPasteboard.PasteboardType] = [svgType, .tiff]
    var pngData: Data?
    if let bitmap = NSBitmapImageRep(data: tiffData) {
      pngData = bitmap.representation(using: .png, properties: [:])
      if pngData != nil { types.append(.png) }
    }

    pasteboard.clearContents()
    pasteboard.declareTypes(types, owner: nil)
    pasteboard.setData(svgData, forType: svgType)
    pasteboard.setData(tiffData, forType: .tiff)
    if let pngData { pasteboard.setData(pngData, forType: .png) }
  }

  private func rasterizedClipboardImage(from source: NSImage) -> NSImage? {
    let maximumDimension = 1800.0
    let sourceSize = source.size
    guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
    let scale = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
    let targetSize = NSSize(
      width: max(1, (sourceSize.width * scale).rounded()),
      height: max(1, (sourceSize.height * scale).rounded()))
    let image = NSImage(size: targetSize)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: NSRect(origin: .zero, size: sourceSize),
      operation: .copy,
      fraction: 1)
    image.unlockFocus()
    return image
  }

  @objc private func navigateBack(_ sender: Any?) {
    goBack()
  }

  @objc private func reloadChart(_ sender: Any?) {
    reload()
  }
}

struct SVGPreview: NSViewRepresentable {
  let fileURL: URL

  func makeNSView(context: Context) -> ChartWebView {
    let configuration = WKWebViewConfiguration()
    let webView = ChartWebView(frame: .zero, configuration: configuration)
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsMagnification = true
    return webView
  }

  func updateNSView(_ webView: ChartWebView, context: Context) {
    webView.chartFileURL = fileURL
    if webView.url != fileURL {
      webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }
  }
}

struct ChartImageView: View {
  let chart: RenderedChart

  var body: some View {
    SVGPreview(fileURL: chart.svgURL)
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

struct SidebarView: View {
  @ObservedObject var model: ChartViewModel

  var body: some View {
    Form {
      Section("Place") {
        TextField("City or place", text: $model.location)
          .textFieldStyle(.roundedBorder)
          .onSubmit { Task { await model.generate() } }

        Menu("Suggested places") {
          ForEach(model.suggestedPlaces, id: \.self) { place in
            Button(place) { model.location = place }
          }
        }
      }

      Section("Moment") {
        Toggle("Use current moment", isOn: $model.useCurrentMoment)
        DatePicker(
          "Date and time", selection: $model.chartDate,
          displayedComponents: [.date, .hourAndMinute])
          .disabled(model.useCurrentMoment)
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
        Picker("Detail", selection: $model.canvasSize) {
          ForEach(CanvasSize.allCases) { size in
            Text(size.rawValue).tag(size)
          }
        }
        Toggle("Light background", isOn: $model.lightBackground)
      }

      Section {
        Button {
          Task { await model.generate() }
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
        .disabled(model.isWorking)
      }

      if let error = model.errorMessage {
        Section {
          Label(error, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .font(.callout)
        }
      }

      Section("About") {
        Text("Astrolog 8.00 calculation engine by Walter D. Pullen. Native macOS interface by Crinklebine.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 285, idealWidth: 310)
  }
}

struct ChartDetailView: View {
  @ObservedObject var model: ChartViewModel

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 3) {
          Text(model.generatedChart?.request.style.rawValue ?? "Astrolog")
            .font(.title2.weight(.semibold))
          Text(model.generatedChart?.result.metadata.heading ?? "Create a chart to begin")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Picker("Result", selection: $model.selectedResult) {
          Text("Chart").tag(0)
          Text("Positions").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(width: 210)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)

      Divider()

      Group {
        if let chart = model.generatedChart {
          if model.selectedResult == 0 {
            ChartImageView(chart: chart)
          } else {
            PositionsResultView(result: chart.result)
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

      Divider()
      HStack {
        Label(model.statusText, systemImage: model.isWorking ? "clock" : "checkmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text("Astrolog 8.00 · Apple Silicon")
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
        .disabled(model.generatedChart == nil || model.isWorking)

        Menu {
          Button("PNG Image…") { Task { await model.exportPNG() } }
          Button("Text Report…") { model.exportReport() }
        } label: {
          Label("More Exports", systemImage: "ellipsis.circle")
        }
        .disabled(model.generatedChart == nil || model.isWorking)
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
struct AstrologMacApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .defaultSize(width: 1240, height: 820)
    .commands {
      CommandGroup(replacing: .newItem) { }
    }
  }
}
