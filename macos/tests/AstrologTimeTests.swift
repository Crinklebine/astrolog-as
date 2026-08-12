import Foundation

@main
enum AstrologTimeTests {
  private static var failureCount = 0

  static func main() throws {
    test("New York summer current instant") {
      let moment = try moment("2026-08-05T21:57:00Z", zone: "America/New_York")
      expectCivil(moment, 2026, 8, 5, 17, 57)
      expect(moment.secondsFromGMT == -14_400, "expected UTC-4 effective offset")
      expect(moment.isDaylightSavingTime, "expected daylight saving to be active")
      expect(moment.astrologStandardZoneHoursWest == 5, "expected Astrolog standard zone 5W")
      expect(moment.astrologZone == "5W", "expected formatted zone 5W")
      expect(moment.astrologDST == "1", "expected separate one-hour DST value")
    }

    test("New York winter current instant") {
      let moment = try moment("2026-01-05T21:57:00Z", zone: "America/New_York")
      expectCivil(moment, 2026, 1, 5, 16, 57)
      expect(moment.secondsFromGMT == -18_000, "expected UTC-5 effective offset")
      expect(!moment.isDaylightSavingTime, "expected standard time")
      expect(moment.astrologStandardZoneHoursWest == 5, "expected Astrolog standard zone 5W")
      expect(moment.astrologDST == "0", "expected zero DST value")
    }

    test("Isle of Man summer current instant") {
      let moment = try moment("2026-08-05T21:57:00Z", zone: "Europe/Isle_of_Man")
      expectCivil(moment, 2026, 8, 5, 22, 57)
      expect(moment.secondsFromGMT == 3_600, "expected UTC+1 effective offset")
      expect(moment.isDaylightSavingTime, "expected daylight saving to be active")
      expect(moment.astrologZone == "0W", "expected Greenwich standard zone")
      expect(moment.astrologDST == "1", "expected separate one-hour DST value")
    }

    test("Isle of Man winter current instant") {
      let moment = try moment("2026-01-05T21:57:00Z", zone: "Europe/Isle_of_Man")
      expectCivil(moment, 2026, 1, 5, 21, 57)
      expect(moment.secondsFromGMT == 0, "expected UTC effective offset")
      expect(!moment.isDaylightSavingTime, "expected standard time")
      expect(moment.astrologZone == "0W", "expected Greenwich standard zone")
    }

    test("Manual New York civil time") {
      let zone = try requireZone("America/New_York")
      let entered = DateComponents(year: 2026, month: 8, day: 5, hour: 17, minute: 57, second: 0)
      let moment = try astrologMoment(forLocalCivilTime: entered, at: zone)
      expect(iso(moment.instant) == "2026-08-05T21:57:00Z", "manual time should resolve to the intended UTC instant")
      expectCivil(moment, 2026, 8, 5, 17, 57)
    }

    test("Date crossing midnight") {
      let moment = try moment("2026-08-06T01:00:00Z", zone: "America/New_York")
      expectCivil(moment, 2026, 8, 5, 21, 0)
    }

    test("New York nonexistent spring time is rejected") {
      let zone = try requireZone("America/New_York")
      let entered = DateComponents(year: 2026, month: 3, day: 8, hour: 2, minute: 30, second: 0)
      do {
        _ = try astrologMoment(forLocalCivilTime: entered, at: zone)
        fail("expected a nonexistent-time error")
      } catch AstrologTimeError.nonexistentCivilTime {
        // Expected.
      }
    }

    test("New York ambiguous autumn time is rejected") {
      let zone = try requireZone("America/New_York")
      let entered = DateComponents(year: 2026, month: 11, day: 1, hour: 1, minute: 30, second: 0)
      do {
        _ = try astrologMoment(forLocalCivilTime: entered, at: zone)
        fail("expected an ambiguous-time error")
      } catch AstrologTimeError.ambiguousCivilTime {
        // Expected.
      }
    }

    test("Fixed instant ignores Mac timezone") {
      let original = NSTimeZone.default
      defer { NSTimeZone.default = original }
      let instant = try parseISO("2026-08-05T21:57:00Z")
      let selectedZone = try requireZone("America/New_York")
      NSTimeZone.default = try requireZone("Europe/Isle_of_Man")
      let first = try astrologMoment(for: instant, at: selectedZone)
      NSTimeZone.default = try requireZone("Asia/Tokyo")
      let second = try astrologMoment(for: instant, at: selectedZone)
      expect(first.localCivilDescription == second.localCivilDescription, "selected-place civil time changed with Mac timezone")
      expect(first.secondsFromGMT == second.secondsFromGMT, "selected-place offset changed with Mac timezone")
    }

    test("Atlas resolves New York user-facing name") {
      let place = try AtlasResolver.resolve("New York, NY, USA", atlasURL: atlasURL())
      expect(place.name == "New York City", "expected New York City, got \(place.name)")
      expect(place.regionCode == "ny", "expected New York state")
      expect(place.timeZoneIdentifier == "America/New_York", "expected IANA New York timezone")
    }

    test("Atlas resolves Seattle default") {
      let place = try AtlasResolver.resolve("Seattle, WA, USA", atlasURL: atlasURL())
      expect(place.name == "Seattle", "expected Seattle")
      expect(place.regionCode == "wa", "expected Washington state")
      expect(place.timeZoneIdentifier == "America/Los_Angeles", "expected Pacific timezone")
    }

    test("Atlas resolves Douglas suggested place") {
      let place = try AtlasResolver.resolve("Douglas, Isle of Man", atlasURL: atlasURL())
      expect(place.name == "Douglas", "expected Douglas")
      expect(place.regionCode == "IM", "expected Isle of Man region")
      expect(place.timeZoneIdentifier == "Europe/Isle_of_Man", "expected Isle of Man timezone")
    }

    test("Atlas resolves Bangkok suggested place") {
      let place = try AtlasResolver.resolve("Bangkok, Thailand", atlasURL: atlasURL())
      expect(place.name == "Bangkok", "expected Bangkok")
      expect(place.regionCode == "TH", "expected Thailand region")
      expect(place.timeZoneIdentifier == "Asia/Bangkok", "expected Bangkok timezone")
    }

    test("Atlas place search ranks and qualifies matches") {
      let places = try AtlasResolver.places(at: atlasURL())
      expect(places.count == 33_702, "expected every bundled atlas place")
      let seattle = AtlasResolver.search("Seattle", in: places, limit: 10)
      expect(seattle.first?.displayName == "Seattle, WA, United States",
             "city prefix search did not rank Seattle first")
      let london = AtlasResolver.search("London, Canada", in: places, limit: 10)
      expect(london.first?.regionCode == "on",
             "country qualifier did not select London, Ontario")
      expect(AtlasResolver.search("", in: places).isEmpty,
             "empty atlas search unexpectedly returned every city")
    }

    test("Astrolog receives local civil time, standard zone, and separate DST") {
      let place = try AtlasResolver.resolve("New York, NY, USA", atlasURL: atlasURL())
      let moment = try moment("2026-08-05T21:57:00Z", zone: place.timeZoneIdentifier)
      let arguments = astrologInputArguments(moment: moment, place: place, chartName: "Current moment")
      expect(arguments.prefix(5) == ["-qb", "8", "5", "2026", "17:57:00"], "wrong local date/time arguments: \(arguments)")
      expect(arguments[5] == "1", "DST must be passed separately")
      expect(arguments[6] == "5W", "standard zone must be 5W, not the UTC-4 effective offset")
      expect(!arguments.contains("-n"), "current mode must not delegate clock conversion to Astrolog -n")
      expect(!arguments.contains("-zN"), "timezone metadata must not be changed after constructing the civil time")
    }

    test("Timezone diagnostic contains authoritative conversion values") {
      let place = try AtlasResolver.resolve("New York, NY, USA", atlasURL: atlasURL())
      let moment = try moment("2026-08-05T21:57:00Z", zone: place.timeZoneIdentifier)
      let arguments = astrologInputArguments(moment: moment, place: place, chartName: "Current moment")
      let diagnostic = timezoneDiagnostic(
        sourceMode: .currentMoment,
        placeQuery: "New York, NY, USA",
        place: place,
        moment: moment,
        arguments: arguments)
      for expected in [
        "Absolute instant: 2026-08-05T21:57:00Z",
        "Timezone: America/New_York",
        "Local civil time: 2026-08-05 17:57:00",
        "Effective offset: -14400 seconds",
        "DST active: true",
        "Astrolog standard zone: 5W",
        "Astrolog local time: 17:57:00",
        "-qb 8 5 2026 17:57:00 1 5W",
      ] {
        expect(diagnostic.contains(expected), "diagnostic missing: \(expected)")
      }
    }

    if failureCount > 0 {
      fputs("\n\(failureCount) timezone test(s) failed.\n", stderr)
      exit(1)
    }
    print("\nAll Astrolog timezone tests passed.")
  }

  private static func test(_ name: String, _ body: () throws -> Void) {
    do {
      try body()
      print("✓ \(name)")
    } catch {
      failureCount += 1
      fputs("✗ \(name): \(error)\n", stderr)
    }
  }

  private static func moment(_ value: String, zone identifier: String) throws -> AstrologMoment {
    try astrologMoment(for: parseISO(value), at: requireZone(identifier))
  }

  private static func requireZone(_ identifier: String) throws -> TimeZone {
    guard let zone = TimeZone(identifier: identifier) else {
      throw AstrologTimeError.invalidTimeZone(identifier)
    }
    return zone
  }

  private static func parseISO(_ value: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: value) else { throw AstrologTimeError.invalidCivilTime }
    return date
  }

  private static func iso(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }

  private static func atlasURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("atlas.as")
  }

  private static func expectCivil(
    _ moment: AstrologMoment,
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int
  ) {
    let components = moment.localDateComponents
    expect(
      components.year == year && components.month == month && components.day == day &&
        components.hour == hour && components.minute == minute,
      "unexpected civil time: \(moment.localCivilDescription)")
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fail(message) }
  }

  private static func fail(_ message: String) {
    failureCount += 1
    fputs("  \(message)\n", stderr)
  }
}
