import Foundation

@main
enum AstrologChartResultTests {
  private static var failures = 0

  static func main() throws {
    guard CommandLine.arguments.count == 3 else {
      fputs("Usage: AstrologChartResultTests <engine> <resources>\n", stderr)
      exit(2)
    }
    let engineURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let resourcesURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    var newYorkReference: ChartResult?

    test("New York fixed reference ChartResult") {
      let place = AstrologPlace(
        name: "New York City", regionCode: "ny", timeZoneIdentifier: "America/New_York",
        longitudeDegreesWest: 74.006, latitudeDegreesNorth: 40.7143)
      let moment = try astrologMoment(
        for: parseISO("2026-08-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let result = try calculate(
        engineURL: engineURL, resourcesURL: resourcesURL,
        moment: moment, place: place, chartName: "Reference NY")
      newYorkReference = result

      expect(result.metadata.engineVersion == "8.00", "wrong engine version")
      expect(result.metadata.chartName == "Reference NY", "wrong chart name")
      expect(result.metadata.houseSystem == "Placidus", "wrong house system")
      expect(result.bodies.count == 11, "expected 11 configured bodies")
      expect(result.houses.count == 12, "expected all 12 house cusps")
      expect(result.aspects.count == 24, "expected 24 reference aspects")

      let sun = try requireBody("Sun", result)
      expect(sun.position.sign == .leo, "Sun sign changed")
      near(sun.position.minutes, 29.543646405, tolerance: 0.000_000_001, "Sun longitude changed")
      near(sun.velocity, 0.957863136, tolerance: 0.000_000_001, "Sun velocity changed")
      near(sun.distanceAU, 1.014335365, tolerance: 0.000_000_001, "Sun distance changed")
      expect(sun.house == 7, "Sun house changed")

      let saturn = try requireBody("Satu", result)
      expect(saturn.isRetrograde, "Saturn should be retrograde")
      expect(saturn.house == 3, "Saturn house changed")

      let ascendant = try requireHouse(1, result)
      expect(ascendant.position.sign == .capricorn, "Ascendant sign changed")
      near(ascendant.position.minutes, 22.414402571, tolerance: 0.000_000_001, "Ascendant changed")

      guard let strongest = result.aspects.first else { throw TestError("missing aspects") }
      expect(strongest.firstBody == "Sun" && strongest.secondBody == "Moon", "strongest aspect bodies changed")
      expect(strongest.kind == .square, "strongest aspect kind changed")
      near(strongest.orbDegrees, 2 + 22.0 / 60.0, tolerance: 0.000_001, "strongest aspect orb changed")
      near(strongest.power, 16.18, tolerance: 0.001, "strongest aspect power changed")
    }

    test("Wheel SVG contains semantic tooltip targets") {
      guard let result = newYorkReference else { throw TestError("missing New York reference") }
      let targets = WheelTooltipAnnotator.tooltipTargets(
        for: result, viewBoxWidth: 5760, viewBoxHeight: 4480)
      expect(targets.count == 37, "expected 37 primary wheel tooltip targets")
      expect(targets.filter { $0.kind == "body" }.count == 11, "expected all body tooltips")
      expect(targets.filter { $0.kind == "angle" }.count == 2, "expected Ascendant and Midheaven tooltips")
      expect(targets.filter { $0.kind == "sign" }.count == 12, "expected all zodiac sign tooltips")
      expect(targets.filter { $0.kind == "house" }.count == 12, "expected all house tooltips")

      guard let sun = targets.first(where: { $0.kind == "body" && $0.key == "Sun" }) else {
        throw TestError("missing Sun tooltip")
      }
      expect(sun.label.contains("Sun · 13°30′ Leo · House 7 · Direct"),
             "Sun tooltip lost its structured chart details")
      expect(sun.relationships.contains(where: { $0.contains("Moon · Square · orb 2°22′") }),
             "Sun tooltip lost its Moon relationship")
      expect(targets.filter { $0.kind == "body" }.allSatisfy { $0.relationships.count <= 6 },
             "a relationship tooltip can grow beyond its compact limit")
      expect(targets.allSatisfy { target in
        !target.relationships.contains(where: { $0.contains("… 1 more relationship") })
      }, "a single remaining relationship was unnecessarily collapsed")
      expect(targets.contains(where: {
        $0.kind == "body" && $0.relationships.last?.contains("more relationships") == true
      }), "crowded relationship tooltips lost their summary")
      expect(sun.x > 0 && sun.x < 4480 && sun.y > 0 && sun.y < 4480,
             "Sun tooltip target is outside the wheel")

      let source = """
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5760 4480">
      <g/>
      </svg>
      """
      let annotated = try WheelTooltipAnnotator.annotatedSVG(source, result: result)
      expect(annotated.contains("id=\"astrolog-as-tooltips\""), "tooltip layer was not added")
      expect(annotated.contains("id=\"astrolog-as-aspect-focus\""),
             "aspect focus layer was not added")
      expect(annotated.contains("data-first-key=\"Sun\" data-second-key=\"Moon\""),
             "Sun-Moon aspect was not made interactive")
      expect(annotated.contains("data-tooltip-relationships=\"Moon · Square · orb 2°22′"),
             "body relationship details were not embedded in the SVG")
      expect(annotated.components(separatedBy: "class=\"astrolog-as-tooltip-target\"").count - 1 == 37,
             "SVG tooltip target count changed")
      expect(annotated.contains("<title>Sun · 13°30′ Leo · House 7 · Direct</title>"),
             "exported SVG is missing the Sun title")
      let annotatedAgain = try WheelTooltipAnnotator.annotatedSVG(annotated, result: result)
      expect(annotatedAgain == annotated,
             "tooltip annotation is not idempotent")
      let lightAnnotated = try WheelTooltipAnnotator.annotatedSVG(
        source, result: result, lightBackground: true)
      expect(lightAnnotated.contains("fill=\"white\""),
             "light charts received a dark relationship mask")
    }

    test("Seattle winter fixed reference ChartResult") {
      let place = AstrologPlace(
        name: "Seattle", regionCode: "wa", timeZoneIdentifier: "America/Los_Angeles",
        longitudeDegreesWest: 122.3321, latitudeDegreesNorth: 47.6062)
      let moment = try astrologMoment(
        for: parseISO("2026-01-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let result = try calculate(
        engineURL: engineURL, resourcesURL: resourcesURL,
        moment: moment, place: place, chartName: "Seattle winter reference")

      expect(result.bodies.count == 11, "expected 11 configured bodies")
      expect(result.houses.count == 12, "expected all 12 house cusps")
      expect(result.aspects.count == 15, "expected 15 reference aspects")
      expect(result.metadata.engineSubtitle.contains("1:57pm (ST Zone 8W)"), "winter metadata changed")

      let sun = try requireBody("Sun", result)
      expect(sun.position.sign == .capricorn && sun.position.degrees == 15, "Sun position changed")
      near(sun.position.minutes, 34.548863584, tolerance: 0.000_000_001, "Sun longitude changed")
      expect(sun.house == 8, "Sun house changed")

      let jupiter = try requireBody("Jupi", result)
      expect(jupiter.isRetrograde, "Jupiter should be retrograde")
      expect(jupiter.house == 3, "Jupiter house changed")

      let ascendant = try requireHouse(1, result)
      expect(ascendant.position.sign == .gemini && ascendant.position.degrees == 10, "Ascendant changed")
      near(ascendant.position.minutes, 17.921377407, tolerance: 0.000_000_001, "Ascendant precision changed")
      let midheaven = try requireHouse(10, result)
      expect(midheaven.position.sign == .aquarius && midheaven.position.degrees == 9, "Midheaven changed")

      guard let strongest = result.aspects.first else { throw TestError("missing aspects") }
      expect(strongest.firstBody == "Sun" && strongest.secondBody == "Venus", "strongest aspect bodies changed")
      expect(strongest.kind == .conjunction, "strongest aspect kind changed")
      near(strongest.power, 19.54, tolerance: 0.001, "strongest aspect power changed")
    }

    test("Rendering option changes preserve the calculated chart") {
      let place = AstrologPlace(
        name: "Seattle", regionCode: "wa", timeZoneIdentifier: "America/Los_Angeles",
        longitudeDegreesWest: 122.3321, latitudeDegreesNorth: 47.6062)
      let moment = try astrologMoment(
        for: parseISO("2026-01-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let original = ChartRequest(
        requestedLocation: "Seattle, WA, USA",
        sourceMode: .currentMoment,
        moment: moment,
        place: place,
        style: .wheel,
        canvas: .compact,
        lightBackground: false)
      let updated = original.withRenderingOptions(
        style: .aspects,
        canvas: .large,
        lightBackground: true)

      expect(updated.lightBackground, "background choice did not change")
      expect(updated.moment.instant == original.moment.instant, "rerender changed the chart instant")
      expect(updated.moment.localCivilDescription == original.moment.localCivilDescription,
             "rerender changed the chart civil time")
      expect(updated.requestedLocation == original.requestedLocation, "rerender changed the place query")
      expect(updated.sourceMode == original.sourceMode, "rerender changed the source mode")
      expect(updated.style == .aspects, "chart style did not change")
      expect(updated.canvas == .large, "detail level did not change")
    }

    test("Wheel rendering uses the FLTK elemental palette") {
      let place = AstrologPlace(
        name: "Seattle", regionCode: "wa", timeZoneIdentifier: "America/Los_Angeles",
        longitudeDegreesWest: 122.3321, latitudeDegreesNorth: 47.6062)
      let moment = try astrologMoment(
        for: parseISO("2026-08-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let wheel = ChartRequest(
        requestedLocation: "Seattle, WA, USA", sourceMode: .manual,
        moment: moment, place: place, style: .wheel, canvas: .compact,
        lightBackground: false)
      let grid = ChartRequest(
        requestedLocation: "Seattle, WA, USA", sourceMode: .manual,
        moment: moment, place: place, style: .aspects, canvas: .compact,
        lightBackground: false)

      expect(wheel.graphicEffectArguments == ["-Xv", "1", "-YXk", "-YXk0"],
             "wheel is missing the standard elemental fill settings")
      expect(grid.graphicEffectArguments.isEmpty,
             "wheel-only color settings leaked into another chart style")
    }

    test("Graphic sidebar uses a bounded place label") {
      let place = AstrologPlace(
        name: "New York City", regionCode: "ny", timeZoneIdentifier: "America/New_York",
        longitudeDegreesWest: 74.006, latitudeDegreesNorth: 40.7143)
      let moment = try astrologMoment(
        for: parseISO("2026-08-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let request = ChartRequest(
        requestedLocation: "New York, NY, USA", sourceMode: .manual,
        moment: moment, place: place, style: .wheel, canvas: .compact,
        lightBackground: false)

      expect(place.displayName == "New York City, NY, United States",
             "canonical place name changed")
      expect(place.graphicDisplayName == "New York City, NY, USA",
             "US graphic label was not compacted")
      expect(place.graphicDisplayName.count <= 25, "graphic place label can overflow the sidebar")
      expect(request.chartArguments.contains(place.displayName),
             "calculation no longer receives the canonical place")
      expect(request.renderArguments.contains(place.graphicDisplayName),
             "renderer did not receive the compact place label")
    }

    test("Last successful place persists with a Seattle fallback") {
      let suiteName = "AstrologChartResultTests.\(UUID().uuidString)"
      let legacySuiteName = "AstrologChartResultTests.Legacy.\(UUID().uuidString)"
      guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw TestError("could not create isolated defaults")
      }
      guard let legacyDefaults = UserDefaults(suiteName: legacySuiteName) else {
        throw TestError("could not create isolated legacy defaults")
      }
      defer {
        defaults.removePersistentDomain(forName: suiteName)
        legacyDefaults.removePersistentDomain(forName: legacySuiteName)
      }
      let store = LastPlaceStore(defaults: defaults, legacyDefaults: legacyDefaults)

      expect(store.location == "Seattle, WA, USA", "first launch did not default to Seattle")
      store.save("  New York, NY, USA  ")
      expect(LastPlaceStore(defaults: defaults, legacyDefaults: legacyDefaults).location == "New York, NY, USA",
             "last successful place was not restored")
      store.save("   ")
      expect(store.location == "New York, NY, USA", "an empty place replaced the saved value")

      defaults.removeObject(forKey: "lastSuccessfulChartLocation")
      LastPlaceStore(defaults: legacyDefaults, legacyDefaults: nil).save("London, England")
      expect(store.location == "London, England", "legacy app preference was not migrated")
    }

    test("Malformed engine positions cannot create a partial ChartResult") {
      let place = AstrologPlace(
        name: "Seattle", regionCode: "wa", timeZoneIdentifier: "America/Los_Angeles",
        longitudeDegreesWest: 122.3321, latitudeDegreesNorth: 47.6062)
      let moment = try astrologMoment(
        for: parseISO("2026-01-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      do {
        _ = try ChartResultParser.parse(
          positions: "@AP800\n-YF Sun 1 Ari 0, 0 0, 1 1\n",
          report: "Astrolog 8.00 chart for Broken\nBroken subtitle\n",
          sourceMode: .manual,
          moment: moment,
          place: place)
        throw TestError("partial result was accepted")
      } catch ChartResultError.incompleteResult {
        // Expected: callers never receive a partially typed chart.
      }
    }

    if failures > 0 {
      fputs("\n\(failures) ChartResult regression test(s) failed.\n", stderr)
      exit(1)
    }
    print("\nAll ChartResult regression tests passed.")
  }

  private static func calculate(
    engineURL: URL,
    resourcesURL: URL,
    moment: AstrologMoment,
    place: AstrologPlace,
    chartName: String
  ) throws -> ChartResult {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AstrologChartResultTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let positionsURL = directory.appendingPathComponent("positions.as")
    let process = Process()
    let output = Pipe()
    let errors = Pipe()
    process.executableURL = engineURL
    process.currentDirectoryURL = resourcesURL
    process.arguments = astrologInputArguments(moment: moment, place: place, chartName: chartName) + [
      "-o0", positionsURL.path, "-v", "-a",
    ]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    let reportData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw TestError(String(decoding: errorData, as: UTF8.self))
    }
    let positions = try String(contentsOf: positionsURL, encoding: .utf8)
    return try ChartResultParser.parse(
      positions: positions,
      report: String(decoding: reportData, as: UTF8.self),
      sourceMode: .manual,
      moment: moment,
      place: place)
  }

  private static func test(_ name: String, _ body: () throws -> Void) {
    do {
      try body()
      print("✓ \(name)")
    } catch {
      failures += 1
      fputs("✗ \(name): \(error.localizedDescription)\n", stderr)
    }
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
      failures += 1
      fputs("  \(message)\n", stderr)
    }
  }

  private static func near(_ actual: Double, _ expected: Double, tolerance: Double, _ message: String) {
    expect(abs(actual - expected) <= tolerance, "\(message): expected \(expected), got \(actual)")
  }

  private static func requireBody(_ key: String, _ result: ChartResult) throws -> ChartBody {
    guard let body = result.body(key) else { throw TestError("missing body \(key)") }
    return body
  }

  private static func requireHouse(_ number: Int, _ result: ChartResult) throws -> HouseCusp {
    guard let house = result.house(number) else { throw TestError("missing house \(number)") }
    return house
  }

  private static func parseISO(_ value: String) throws -> Date {
    guard let date = ISO8601DateFormatter().date(from: value) else { throw TestError("bad test date") }
    return date
  }

  private static func requireZone(_ identifier: String) throws -> TimeZone {
    guard let zone = TimeZone(identifier: identifier) else { throw TestError("missing timezone \(identifier)") }
    return zone
  }

  private struct TestError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
  }
}
