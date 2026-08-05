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

    test("Douglas winter fixed reference ChartResult") {
      let place = AstrologPlace(
        name: "Douglas", regionCode: "IM", timeZoneIdentifier: "Europe/Isle_of_Man",
        longitudeDegreesWest: 4.4833, latitudeDegreesNorth: 54.15)
      let moment = try astrologMoment(
        for: parseISO("2026-01-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let result = try calculate(
        engineURL: engineURL, resourcesURL: resourcesURL,
        moment: moment, place: place, chartName: "Douglas winter reference")

      expect(result.bodies.count == 11, "expected 11 configured bodies")
      expect(result.houses.count == 12, "expected all 12 house cusps")
      expect(result.aspects.count == 19, "expected 19 reference aspects")
      expect(result.metadata.engineSubtitle.contains("9:57pm (ST Zone 0W)"), "winter metadata changed")

      let sun = try requireBody("Sun", result)
      expect(sun.position.sign == .capricorn && sun.position.degrees == 15, "Sun position changed")
      near(sun.position.minutes, 34.548863584, tolerance: 0.000_000_001, "Sun longitude changed")
      expect(sun.house == 4, "Sun house changed")

      let jupiter = try requireBody("Jupi", result)
      expect(jupiter.isRetrograde, "Jupiter should be retrograde")
      expect(jupiter.house == 11, "Jupiter house changed")

      let ascendant = try requireHouse(1, result)
      expect(ascendant.position.sign == .virgo && ascendant.position.degrees == 16, "Ascendant changed")
      near(ascendant.position.minutes, 34.526860558, tolerance: 0.000_000_001, "Ascendant precision changed")
      let midheaven = try requireHouse(10, result)
      expect(midheaven.position.sign == .gemini && midheaven.position.degrees == 11, "Midheaven changed")

      guard let strongest = result.aspects.first else { throw TestError("missing aspects") }
      expect(strongest.firstBody == "Sun" && strongest.secondBody == "Venus", "strongest aspect bodies changed")
      expect(strongest.kind == .conjunction, "strongest aspect kind changed")
      near(strongest.power, 19.54, tolerance: 0.001, "strongest aspect power changed")
    }

    test("Malformed engine positions cannot create a partial ChartResult") {
      let place = AstrologPlace(
        name: "Douglas", regionCode: "IM", timeZoneIdentifier: "Europe/Isle_of_Man",
        longitudeDegreesWest: 4.4833, latitudeDegreesNorth: 54.15)
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
