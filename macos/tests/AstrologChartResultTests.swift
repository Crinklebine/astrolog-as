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
      expect(annotated.contains("astrologTooltipsDisabled"),
             "tooltip interaction cannot be suspended during animation")
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

    test("Local Horizon SVG contains object tooltips and preserves a clean copy") {
      guard let result = newYorkReference else { throw TestError("missing New York reference") }
      let markerCount = result.bodies.count + 2
      let markerTags = (0..<markerCount).map { index in
        let x = index == 10 ? 3000 : (index == 11 ? 3005 : 200 + index * 240)
        let y = index == 10 ? 1500 : (index == 11 ? 1547 : 400 + index * 120)
        return "<circle r=\"8\" cx=\"\(x)\" cy=\"\(y)\" fill=\"red\"/>"
      }.joined(separator: "\n")
      let source = """
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5600 4480">
      <g>\(markerTags)</g>
      </svg>
      """

      let targets = WheelTooltipAnnotator.localHorizonTooltipTargets(
        in: source, result: result)
      expect(targets.count == markerCount,
             "Local Horizon did not receive every primary object tooltip")
      expect(targets.filter { $0.kind == "body" }.count == result.bodies.count,
             "Local Horizon lost a body tooltip")
      expect(targets.filter { $0.kind == "angle" }.count == 2,
             "Local Horizon lost its Ascendant or Midheaven tooltip")
      guard let sun = targets.first(where: { $0.key == "Sun" }) else {
        throw TestError("missing Local Horizon Sun tooltip")
      }
      expect(sun.label == "Sun",
             "Local Horizon Sun tooltip contains more than its object name")
      expect(targets.allSatisfy { $0.relationships.isEmpty },
             "Local Horizon tooltips unexpectedly contain aspects")
      expect(sun.x == Double(200 + (markerCount - 1) * 240),
             "Local Horizon Sun tooltip is not attached to Astrolog's marker")
      guard let moon = targets.first(where: { $0.key == "Moon" }),
            let mercury = targets.first(where: { $0.key == "Merc" }) else {
        throw TestError("missing crowded Local Horizon targets")
      }
      expect(hypot(moon.x - mercury.x, moon.y - mercury.y) > moon.radius + mercury.radius,
             "crowded Local Horizon glyph tooltips still overlap")

      let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("astrolog-horizon-tooltip-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(
        at: temporaryDirectory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
      let engineSVG = temporaryDirectory.appendingPathComponent("astrolog.svg")
      let displaySVG = temporaryDirectory.appendingPathComponent("chart.svg")
      try source.write(to: engineSVG, atomically: true, encoding: .utf8)
      try FileManager.default.copyItem(at: engineSVG, to: displaySVG)
      try WheelTooltipAnnotator.annotateLocalHorizon(svgAt: displaySVG, result: result)

      let cleanCopy = try String(contentsOf: engineSVG, encoding: .utf8)
      let interactiveCopy = try String(contentsOf: displaySVG, encoding: .utf8)
      expect(cleanCopy == source,
             "Local Horizon annotations changed the clean engine SVG")
      expect(!cleanCopy.contains("astrolog-as-tooltips"),
             "clean Local Horizon SVG contains app annotations")
      expect(interactiveCopy.contains("id=\"astrolog-as-tooltips\""),
             "interactive Local Horizon SVG is missing tooltips")
      expect(
        interactiveCopy.components(separatedBy: "class=\"astrolog-as-tooltip-target\"").count - 1 ==
          markerCount,
        "interactive Local Horizon tooltip count changed")
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

    test("Aspects encode as spreadsheet-compatible CSV") {
      let aspects = [
        ChartAspect(
          rank: 1, firstBody: "Sun, Sol", secondBody: "Moon \"Luna\"",
          kind: .square, orbDegrees: -(2 + 22.0 / 60.0), power: 16.18),
        ChartAspect(
          rank: 2, firstBody: "Venus", secondBody: "Mars",
          kind: .trine, orbDegrees: 0.15, power: 9.5),
      ]
      let csv = AspectCSVEncoder.encode(aspects)
      let expected =
        "Rank,First Body,Aspect,Second Body,Orb,Power\r\n" +
        "1,\"Sun, Sol\",Square,\"Moon \"\"Luna\"\"\",2°22′,16.18\r\n" +
        "2,Venus,Trine,Mars,0°09′,9.50\r\n"
      expect(csv == expected, "aspect CSV formatting or escaping changed")
    }

    test("Positions encode as spreadsheet-compatible CSV") {
      let bodies = [
        ChartBody(
          key: "Merc", name: "Mercury, \"Hermes\"",
          position: ZodiacPosition(sign: .leo, degrees: 3, minutes: 4.4),
          latitude: -1.25, velocity: -0.123, distanceAU: 0.9, house: 7),
        ChartBody(
          key: "Sun", name: "Sun",
          position: ZodiacPosition(sign: .leo, degrees: 18, minutes: 54.0),
          latitude: 0, velocity: 0.958, distanceAU: 1.0, house: nil),
      ]
      let csv = PositionCSVEncoder.encode(bodies)
      let expected =
        "Body,Position,Motion,House,Latitude,Velocity\r\n" +
        "\"Mercury, \"\"Hermes\"\"\",3°04′ Leo,Retrograde,7,1.25° S,-0.123°/day\r\n" +
        "Sun,18°54′ Leo,Direct,—,0.00° N,+0.958°/day\r\n"
      expect(csv == expected, "position CSV formatting or escaping changed")
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
      expect(updated.solarSystemRadiusAU == original.solarSystemRadiusAU,
             "rerender changed the Solar System scale")
    }

    test("Animation steps preserve civil time and chart settings") {
      let place = AstrologPlace(
        name: "New York City", regionCode: "ny", timeZoneIdentifier: "America/New_York",
        longitudeDegreesWest: 74.006, latitudeDegreesNorth: 40.7143)
      let timeZone = try requireZone(place.timeZoneIdentifier)
      let start = try parseISO("2026-03-07T17:00:00Z")
      let expectedNextDay = try parseISO("2026-03-08T16:00:00Z")
      expect(ChartAnimationStep.allCases.map(\.rawValue).first == "1 second",
             "one-second animation stepping is unavailable")
      expect(
        ChartAnimationStep.second.advancing(
          start, direction: .forward, in: timeZone) == start.addingTimeInterval(1),
        "one-second animation did not advance by exactly one second")
      guard let nextDay = ChartAnimationStep.day.advancing(
        start, direction: .forward, in: timeZone) else {
        throw TestError("could not advance an animation day")
      }
      expect(nextDay == expectedNextDay,
             "a daily step did not preserve local noon across daylight saving")
      expect(
        ChartAnimationStep.day.advancing(nextDay, direction: .backward, in: timeZone) == start,
        "reverse animation did not return to the previous civil time")

      let moment = try astrologMoment(for: start, at: timeZone)
      let nextMoment = try astrologMoment(for: nextDay, at: timeZone)
      let original = ChartRequest(
        requestedLocation: "New York, NY, USA", sourceMode: .currentMoment,
        moment: moment, place: place, style: .solarSystem, canvas: .large,
        lightBackground: true, solarSystemRadiusAU: 2.5)
      let animated = original.withMoment(nextMoment)
      expect(animated.sourceMode == .manual,
             "animation did not freeze the current-moment chart onto a manual timeline")
      expect(animated.moment.instant == nextDay, "animation request used the wrong instant")
      expect(animated.requestedLocation == original.requestedLocation,
             "animation changed the requested place")
      expect(animated.style == original.style && animated.canvas == original.canvas,
             "animation changed the chart rendering options")
      expect(animated.lightBackground == original.lightBackground,
             "animation changed the chart background")
      expect(animated.solarSystemRadiusAU == original.solarSystemRadiusAU,
             "animation changed the Solar System radius")
      expect(ChartAnimationRate.allCases.map(\.rawValue) ==
        ["1 fps", "2 fps", "5 fps", "15 fps", "30 fps", "60 fps", "Maximum"],
        "animation frame-rate choices changed")
      expect(ChartAnimationRate.fifteen.rawValue == "15 fps",
             "the default animation rate is unavailable")
      expect(ChartAnimationRate.five.minimumFrameInterval == 0.2,
             "smooth animation no longer targets five frames per second")
      near(
        ChartAnimationRate.fifteen.minimumFrameInterval,
        1.0 / 15.0,
        tolerance: 0.000_000_001,
        "default animation no longer targets fifteen frames per second")
      near(
        ChartAnimationRate.thirty.minimumFrameInterval,
        1.0 / 30.0,
        tolerance: 0.000_000_001,
        "thirty-frame animation interval changed")
      near(
        ChartAnimationRate.sixty.minimumFrameInterval,
        1.0 / 60.0,
        tolerance: 0.000_000_001,
        "sixty-frame animation interval changed")
      expect(ChartAnimationRate.maximum.minimumFrameInterval == 0,
             "maximum animation is unexpectedly throttled")
    }

    test("Solar System SVG requests engine scale changes") {
      let source = """
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5760 4480">
      <g/>
      </svg>
      """
      let annotated = try SolarSystemZoomAnnotator.annotatedSVG(source)
      expect(annotated.contains("id=\"astrolog-as-solar-zoom\""),
             "Solar System zoom script was not added")
      expect(annotated.contains("messageHandlers?.solarSystemZoom"),
             "Solar System zoom is not connected to the native renderer")
      expect(annotated.contains("event.deltaY * modeScale"),
             "Solar System zoom does not normalize wheel input")
      expect(!annotated.contains("setAttribute(\"viewBox\""),
             "Solar System zoom still magnifies the existing SVG")
      expect(annotated.contains("{ passive: false }"),
             "Solar System wheel events cannot suppress page scrolling")
      let annotatedAgain = try SolarSystemZoomAnnotator.annotatedSVG(annotated)
      expect(annotatedAgain == annotated,
             "Solar System zoom annotation is not idempotent")
      let updateScript = try SVGDocumentUpdater.replacementJavaScript(for: annotated)
      expect(updateScript.contains("document.documentElement.replaceWith(nextRoot)"),
             "SVG updates still require a WebKit navigation")
      expect(updateScript.contains("astrolog-as-solar-zoom"),
             "SVG replacement did not safely embed the new chart")
      expect(!updateScript.contains("#(json)"),
             "SVG replacement left an uninterpolated JavaScript placeholder")
      expect(updateScript.contains("scripts.forEach(source => window.eval(source))"),
             "SVG replacement does not restore chart interactions")
      expect(updateScript.contains("nextRoot.dataset.astrologTooltipsDisabled"),
             "SVG replacement does not preserve animation tooltip suppression")
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
      let solar = ChartRequest(
        requestedLocation: "Seattle, WA, USA", sourceMode: .manual,
        moment: moment, place: place, style: .solarSystem, canvas: .compact,
        lightBackground: false, solarSystemRadiusAU: 12.5)

      expect(wheel.graphicEffectArguments == ["-Xv", "1", "-YXk", "-YXk0"],
             "wheel is missing the standard elemental fill settings")
      expect(grid.graphicEffectArguments.isEmpty,
             "wheel-only color settings leaked into another chart style")
      expect(solar.graphicEffectArguments == ["-YXS", "12.500000"],
             "Solar System radius was not passed to Astrolog")
      expect(solar.withSolarSystemRadiusAU(0.00001).solarSystemRadiusAU == 0.0001,
             "Solar System zoom exceeded Astrolog's supported close range")
      expect(solar.withSolarSystemRadiusAU(500).solarSystemRadiusAU == 360,
             "Solar System zoom exceeded Astrolog's supported radius")
    }

    test("Chart styles use the intended names and picker order") {
      expect(
        ChartStyle.allCases.map(\.rawValue) ==
          ["Wheel", "Solar System", "Local Horizon", "Astrocartography", "Aspect Grid"],
        "chart style names or picker order changed")
      expect(ChartStyle.localHorizon.engineArguments == ["-Z"],
             "Local Horizon no longer selects Astrolog's standard sky view")
      expect(ChartStyle.astrocartography.engineArguments == ["-L"],
             "Astrocartography no longer selects Astrolog's map view")
    }

    test("Close Solar System SVG renders filled planet disks") {
      let place = AstrologPlace(
        name: "New York City", regionCode: "ny", timeZoneIdentifier: "America/New_York",
        longitudeDegreesWest: 74.006, latitudeDegreesNorth: 40.7143)
      let moment = try astrologMoment(
        for: parseISO("2026-08-05T21:57:00Z"),
        at: requireZone(place.timeZoneIdentifier))
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AstrologSolarSystemTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let svgURL = directory.appendingPathComponent("close-solar-system.svg")
      let process = Process()
      let errors = Pipe()
      process.executableURL = engineURL
      process.currentDirectoryURL = resourcesURL
      process.arguments = astrologInputArguments(
        moment: moment, place: place, chartName: "Close Solar System") + [
          "-S", "-YXS", "1", "-Xx0", "-Xw", "700", "560",
          "-XV", "-Xo", svgURL.path,
        ]
      process.standardInput = FileHandle.nullDevice
      process.standardOutput = FileHandle.nullDevice
      process.standardError = errors
      try process.run()
      let errorData = errors.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else {
        throw TestError(
          "close SVG exited with status \(process.terminationStatus): " +
          String(decoding: errorData, as: UTF8.self))
      }
      let svg = try String(contentsOf: svgURL, encoding: .utf8)
      expect(svg.contains("fill=\""), "close SVG omitted filled planet disks")
    }

    test("Solar System SVG contains object distance tooltips") {
      guard let result = newYorkReference else { throw TestError("missing New York reference") }
      let place = result.metadata.place
      let moment = result.metadata.moment
      let radiusAU = 30.0
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AstrologSolarTooltipTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let svgURL = directory.appendingPathComponent("solar-system.svg")
      let process = Process()
      let errors = Pipe()
      process.executableURL = engineURL
      process.currentDirectoryURL = resourcesURL
      process.arguments = astrologInputArguments(
        moment: moment, place: place, chartName: "Solar tooltip reference") + [
          "-S", "-YXS", "30", "-Xx0", "-Xw", "700", "560",
          "-XV", "-Xo", svgURL.path,
        ]
      process.standardInput = FileHandle.nullDevice
      process.standardOutput = FileHandle.nullDevice
      process.standardError = errors
      try process.run()
      let errorData = errors.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else {
        throw TestError(
          "Solar tooltip SVG exited with status \(process.terminationStatus): " +
          String(decoding: errorData, as: UTF8.self))
      }

      let source = try String(contentsOf: svgURL, encoding: .utf8)
      let targets = WheelTooltipAnnotator.solarSystemTooltipTargets(
        in: source, result: result, radiusAU: radiusAU)
      expect(targets.count >= 8,
             "Solar System did not receive tooltips for the visible primary objects")
      expect(targets.allSatisfy { $0.kind == "body" && $0.relationships.isEmpty },
             "Solar System tooltips unexpectedly contain aspect relationships")
      expect(targets.contains(where: { $0.key == "Sun" && $0.label == "Sun · 1.014 AU" }),
             "Solar System is missing the Sun's AU distance")
      expect(targets.allSatisfy { $0.label.hasSuffix(" AU") },
             "a Solar System object tooltip is missing its AU distance")

      let tooltipSVG = try WheelTooltipAnnotator.annotatedSolarSystemSVG(
        source, result: result, radiusAU: radiusAU)
      let interactiveSVG = try SolarSystemZoomAnnotator.annotatedSVG(tooltipSVG)
      expect(interactiveSVG.contains("id=\"astrolog-as-tooltips\""),
             "Solar System tooltip layer was not added")
      expect(interactiveSVG.contains("id=\"astrolog-as-solar-zoom\""),
             "Solar System tooltips displaced wheel zooming")
      expect(interactiveSVG.contains("nearestDistance"),
             "crowded Solar System targets do not select the nearest object")
      expect(!source.contains("astrolog-as-tooltips"),
             "Solar System annotations changed the clean engine SVG")
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
