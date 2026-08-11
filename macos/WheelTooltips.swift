import Foundation

struct WheelTooltipTarget: Equatable {
  let kind: String
  let key: String
  let label: String
  let relationships: [String]
  let x: Double
  let y: Double
  let radius: Double
}

enum WheelTooltipError: LocalizedError {
  case invalidSVG

  var errorDescription: String? {
    "Astrolog created an SVG that could not be prepared for interactive tooltips."
  }
}

enum WheelTooltipAnnotator {
  private static let interactionScript = #"""
  (() => {
    const svg = document.documentElement;
    if (!svg || svg.tagName.toLowerCase() !== "svg" ||
        !svg.querySelector(".astrolog-as-tooltip-target")) return;
    const aspectFocus = svg.querySelector("#astrolog-as-aspect-focus");
    const aspectLines = aspectFocus?.querySelectorAll(".astrolog-as-aspect-relation") ?? [];
    const aspectNodes = aspectFocus?.querySelectorAll(".astrolog-as-aspect-node") ?? [];

    const namespace = "http://www.w3.org/2000/svg";
    const layer = document.createElementNS(namespace, "g");
    const background = document.createElementNS(namespace, "rect");
    const text = document.createElementNS(namespace, "text");
    layer.id = "astrolog-as-tooltip-popup";
    layer.setAttribute("pointer-events", "none");
    layer.setAttribute("display", "none");
    background.setAttribute("rx", "18");
    background.setAttribute("fill", "#20242a");
    background.setAttribute("fill-opacity", "0.96");
    background.setAttribute("stroke", "#ffffff");
    background.setAttribute("stroke-opacity", "0.35");
    text.setAttribute("fill", "white");
    text.setAttribute("font-family", "-apple-system, BlinkMacSystemFont, sans-serif");
    layer.append(background, text);
    svg.appendChild(layer);

    // Use the immediate popup in interactive viewers. The title elements
    // remain in the file as a script-free fallback for other SVG consumers.
    svg.querySelectorAll(".astrolog-as-tooltip-target > title").forEach(title => title.remove());

    let focusedBody = null;
    const clearAspectFocus = () => {
      if (!aspectFocus || focusedBody === null) return;
      aspectFocus.setAttribute("display", "none");
      aspectLines.forEach(line => line.setAttribute("display", "none"));
      aspectNodes.forEach(node => node.setAttribute("display", "none"));
      focusedBody = null;
    };
    const showAspectFocus = target => {
      if (!aspectFocus || target?.getAttribute("data-tooltip-kind") !== "body") {
        clearAspectFocus();
        return;
      }
      const key = target.getAttribute("data-tooltip-key");
      if (!key || key === focusedBody) return;
      focusedBody = key;
      let visibleCount = 0;
      const connectedBodies = new Set([key]);
      aspectLines.forEach(line => {
        const visible = line.getAttribute("data-first-key") === key ||
          line.getAttribute("data-second-key") === key;
        line.setAttribute("display", visible ? "inline" : "none");
        if (visible) {
          visibleCount += 1;
          connectedBodies.add(line.getAttribute("data-first-key"));
          connectedBodies.add(line.getAttribute("data-second-key"));
        }
      });
      aspectNodes.forEach(node => {
        const nodeKey = node.getAttribute("data-body-key");
        const visible = connectedBodies.has(nodeKey) && visibleCount;
        node.setAttribute("display", visible ? "inline" : "none");
        node.setAttribute("stroke-opacity", nodeKey === key ? "1" : "0.55");
      });
      aspectFocus.setAttribute("display", visibleCount ? "inline" : "none");
    };
    const hide = () => {
      layer.setAttribute("display", "none");
      clearAspectFocus();
    };
    svg.addEventListener("pointerleave", hide);
    svg.addEventListener("pointermove", event => {
      if (svg.dataset.astrologTooltipsDisabled === "true") {
        hide();
        return;
      }
      const point = svg.createSVGPoint();
      point.x = event.clientX;
      point.y = event.clientY;
      const location = point.matrixTransform(svg.getScreenCTM().inverse());
      let target = null;
      let nearestDistance = Infinity;
      svg.querySelectorAll(".astrolog-as-tooltip-target").forEach(candidate => {
        const dx = location.x - Number(candidate.getAttribute("cx"));
        const dy = location.y - Number(candidate.getAttribute("cy"));
        const distance = Math.hypot(dx, dy);
        const radius = Number(candidate.getAttribute("r"));
        if (distance <= radius && distance < nearestDistance) {
          target = candidate;
          nearestDistance = distance;
        }
      });
      const label = target?.getAttribute("aria-label");
      if (!label) {
        hide();
        return;
      }
      showAspectFocus(target);

      const viewBox = svg.viewBox.baseVal;
      const fontSize = viewBox.height / 52;
      const padding = fontSize * 0.42;
      text.setAttribute("font-size", String(fontSize));
      text.replaceChildren();
      const relationships = (target.getAttribute("data-tooltip-relationships") || "")
        .split("|").filter(Boolean);
      const lines = [label, ...relationships];
      const tspans = lines.map((line, index) => {
        const tspan = document.createElementNS(namespace, "tspan");
        tspan.setAttribute("x", String(padding));
        tspan.setAttribute("dy", index ? String(fontSize * 1.22) : "0");
        tspan.textContent = line;
        text.appendChild(tspan);
        return tspan;
      });
      text.setAttribute("y", String(fontSize + padding * 0.55));
      layer.removeAttribute("display");

      const width = Math.max(...tspans.map(tspan => tspan.getComputedTextLength())) + padding * 2;
      const height = fontSize * (1 + (lines.length - 1) * 1.22) + padding;
      background.setAttribute("width", String(width));
      background.setAttribute("height", String(height));

      let x = location.x + fontSize * 0.35;
      let y = location.y - height - fontSize * 0.25;
      if (x + width > viewBox.x + viewBox.width) x = viewBox.x + viewBox.width - width;
      if (x < viewBox.x) x = viewBox.x;
      if (y < viewBox.y) y = location.y + fontSize * 0.35;
      if (y + height > viewBox.y + viewBox.height) y = viewBox.y + viewBox.height - height;
      layer.setAttribute("transform", `translate(${x} ${y})`);
    });
  })();
  """#

  private struct SVGViewBox {
    let minimumX: Double
    let minimumY: Double
    let width: Double
    let height: Double
  }

  private struct RingItem {
    let kind: String
    let key: String
    let label: String
    let longitude: Double
  }

  private struct SVGMarker {
    let x: Double
    let y: Double
    let radius: Double
  }

  private struct AspectLine {
    let firstKey: String
    let secondKey: String
    let kind: AspectKind
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
  }

  static func annotate(
    svgAt url: URL,
    result: ChartResult,
    lightBackground: Bool = false
  ) throws {
    let svg = try String(contentsOf: url, encoding: .utf8)
    let annotated = try annotatedSVG(
      svg, result: result, lightBackground: lightBackground)
    try annotated.write(to: url, atomically: true, encoding: .utf8)
  }

  static func annotatedSVG(
    _ svg: String,
    result: ChartResult,
    lightBackground: Bool = false
  ) throws -> String {
    if svg.contains("id=\"astrolog-as-tooltips\"") { return svg }
    guard let viewBox = parseViewBox(svg),
          let closingTag = svg.range(of: "</svg>", options: .backwards) else {
      throw WheelTooltipError.invalidSVG
    }

    let targets = tooltipTargets(for: result, viewBox: viewBox)
    let aspects = aspectLines(for: result, targets: targets, viewBox: viewBox)
    let markup = tooltipMarkup(
      targets, aspects: aspects, viewBox: viewBox,
      lightBackground: lightBackground)
    var annotated = svg
    annotated.insert(contentsOf: markup, at: closingTag.lowerBound)
    return annotated
  }

  static func annotateLocalHorizon(
    svgAt url: URL,
    result: ChartResult,
    lightBackground: Bool = false
  ) throws {
    let svg = try String(contentsOf: url, encoding: .utf8)
    let annotated = try annotatedLocalHorizonSVG(
      svg, result: result, lightBackground: lightBackground)
    try annotated.write(to: url, atomically: true, encoding: .utf8)
  }

  static func annotatedLocalHorizonSVG(
    _ svg: String,
    result: ChartResult,
    lightBackground: Bool = false
  ) throws -> String {
    if svg.contains("id=\"astrolog-as-tooltips\"") { return svg }
    guard let viewBox = parseViewBox(svg),
          let closingTag = svg.range(of: "</svg>", options: .backwards) else {
      throw WheelTooltipError.invalidSVG
    }
    let targets = localHorizonTooltipTargets(in: svg, result: result)
    guard !targets.isEmpty else { throw WheelTooltipError.invalidSVG }
    let markup = tooltipMarkup(
      targets, aspects: [], viewBox: viewBox,
      lightBackground: lightBackground)
    var annotated = svg
    annotated.insert(contentsOf: markup, at: closingTag.lowerBound)
    return annotated
  }

  static func annotateSolarSystem(
    svgAt url: URL,
    result: ChartResult,
    radiusAU: Double,
    lightBackground: Bool = false
  ) throws {
    let svg = try String(contentsOf: url, encoding: .utf8)
    let annotated = try annotatedSolarSystemSVG(
      svg, result: result, radiusAU: radiusAU,
      lightBackground: lightBackground)
    try annotated.write(to: url, atomically: true, encoding: .utf8)
  }

  static func annotatedSolarSystemSVG(
    _ svg: String,
    result: ChartResult,
    radiusAU: Double,
    lightBackground: Bool = false
  ) throws -> String {
    if svg.contains("id=\"astrolog-as-tooltips\"") { return svg }
    guard let viewBox = parseViewBox(svg),
          let closingTag = svg.range(of: "</svg>", options: .backwards) else {
      throw WheelTooltipError.invalidSVG
    }
    let targets = solarSystemTooltipTargets(
      in: svg, result: result, radiusAU: radiusAU)
    let markup = tooltipMarkup(
      targets, aspects: [], viewBox: viewBox,
      lightBackground: lightBackground)
    var annotated = svg
    annotated.insert(contentsOf: markup, at: closingTag.lowerBound)
    return annotated
  }

  static func solarSystemTooltipTargets(
    in svg: String,
    result: ChartResult,
    radiusAU: Double
  ) -> [WheelTooltipTarget] {
    guard radiusAU > 0, let viewBox = parseViewBox(svg) else { return [] }
    let glyphScale = localHorizonGlyphScale(viewBox: viewBox)
    let markerRadius = glyphScale / 2.0
    var seenMarkerLocations = Set<String>()
    let markers = localHorizonMarkers(in: svg).filter { marker in
      guard abs(marker.radius - markerRadius) < 0.51 else { return false }
      let key = "\(marker.x)|\(marker.y)"
      return seenMarkerLocations.insert(key).inserted
    }
    guard !markers.isEmpty else { return [] }

    let centerX = viewBox.minimumX + viewBox.width / 2.0
    let centerY = viewBox.minimumY + viewBox.height / 2.0
    let edge = glyphScale * 6.0
    let horizontalScale = (viewBox.width / 2.0 - edge) / radiusAU
    let verticalScale = (viewBox.height / 2.0 - edge) / radiusAU
    let expectedBodies = result.bodies.enumerated().compactMap { index, body ->
      (index: Int, body: ChartBody, x: Double, y: Double)? in
      let longitude = body.position.longitude * .pi / 180.0
      let latitude = body.latitude * .pi / 180.0
      let planarDistance = body.distanceAU * cos(latitude)
      let x = centerX - planarDistance * cos(longitude) * horizontalScale
      let y = centerY + planarDistance * sin(longitude) * verticalScale
      guard x >= viewBox.minimumX + edge, x <= viewBox.minimumX + viewBox.width - edge,
            y >= viewBox.minimumY + edge, y <= viewBox.minimumY + viewBox.height - edge else {
        return nil
      }
      return (index, body, x, y)
    }

    var candidates: [(distance: Double, marker: Int, body: Int)] = []
    for markerIndex in markers.indices {
      for bodyIndex in expectedBodies.indices {
        let body = expectedBodies[bodyIndex]
        candidates.append((
          hypot(markers[markerIndex].x - body.x, markers[markerIndex].y - body.y),
          markerIndex, bodyIndex))
      }
    }
    candidates.sort { $0.distance < $1.distance }

    var usedMarkers = Set<Int>()
    var usedBodies = Set<Int>()
    var matches: [(index: Int, body: ChartBody, marker: SVGMarker)] = []
    let tolerance = max(32.0, glyphScale * 4.0)
    for candidate in candidates where candidate.distance <= tolerance {
      guard !usedMarkers.contains(candidate.marker),
            !usedBodies.contains(candidate.body) else { continue }
      usedMarkers.insert(candidate.marker)
      usedBodies.insert(candidate.body)
      let body = expectedBodies[candidate.body]
      matches.append((body.index, body.body, markers[candidate.marker]))
    }
    matches.sort { $0.index < $1.index }

    let centers = solarSystemGlyphCenters(
      for: matches.map(\.marker), viewBox: viewBox, edge: edge)
    let hitRadius = glyphScale * 4.0
    return zip(matches, centers).compactMap { match, center in
      guard center.x >= viewBox.minimumX + edge,
            center.x <= viewBox.minimumX + viewBox.width - edge,
            center.y >= viewBox.minimumY + edge,
            center.y <= viewBox.minimumY + viewBox.height - edge else { return nil }
      return WheelTooltipTarget(
        kind: "body", key: match.body.key,
        label: "\(match.body.name) · \(solarSystemDistanceText(match.body.distanceAU))",
        relationships: [], x: center.x, y: center.y, radius: hitRadius)
    }
  }

  private static func solarSystemDistanceText(_ distanceAU: Double) -> String {
    let locale = Locale(identifier: "en_US_POSIX")
    return String(format: "%.4g AU", locale: locale, distanceAU)
  }

  static func localHorizonTooltipTargets(
    in svg: String,
    result: ChartResult
  ) -> [WheelTooltipTarget] {
    guard let viewBox = parseViewBox(svg) else { return [] }
    let markers = localHorizonMarkers(in: svg)
    var items: [(kind: String, key: String, label: String, relationships: [String])] = []

    // DrawObjects() emits Local Horizon markers in descending Astrolog object
    // index: Midheaven, Ascendant, then the configured bodies in reverse order.
    for number in [10, 1] {
      guard let house = result.house(number) else { continue }
      items.append((
        kind: "angle", key: house.key,
        label: house.name, relationships: []))
    }
    for body in result.bodies.reversed() {
      items.append((
        kind: "body", key: body.key, label: body.name,
        relationships: []))
    }

    guard markers.count >= items.count else { return [] }
    let selectedMarkers = Array(markers.suffix(items.count))
    let glyphCenters = localHorizonGlyphCenters(
      for: selectedMarkers, viewBox: viewBox)
    let glyphScale = localHorizonGlyphScale(viewBox: viewBox)
    return zip(items, zip(selectedMarkers, glyphCenters)).map { item, placement in
      let (marker, center) = placement
      return WheelTooltipTarget(
        kind: item.kind, key: item.key, label: item.label,
        relationships: item.relationships,
        x: center.x, y: center.y,
        radius: max(marker.radius * 5.0, glyphScale * 4.0))
    }
  }

  static func tooltipTargets(
    for result: ChartResult,
    viewBoxWidth: Double,
    viewBoxHeight: Double
  ) -> [WheelTooltipTarget] {
    tooltipTargets(
      for: result,
      viewBox: SVGViewBox(
        minimumX: 0, minimumY: 0, width: viewBoxWidth, height: viewBoxHeight))
  }

  private static func tooltipTargets(
    for result: ChartResult,
    viewBox: SVGViewBox
  ) -> [WheelTooltipTarget] {
    guard let ascendant = result.house(1) else { return [] }

    // A wheel occupies the square at the left of Astrolog's sidebar. Astrolog
    // scales SVG coordinates by eight and computes its center one unit left
    // and above the exact midpoint.
    let unit = viewBox.height / 2.0 - 1.0
    let centerX = viewBox.minimumX + unit
    let centerY = viewBox.minimumY + unit
    let ascendantLongitude = ascendant.position.longitude
    let unscaledHeight = viewBox.height / 8.0
    let glyphScale = Double(
      unscaledHeight < 350 ? 1 : (unscaledHeight < 750 ? 2 : (unscaledHeight < 950 ? 3 : 4))) * 8.0
    let hitRadius = max(112.0, glyphScale * 8.0)

    func wheelAngle(for longitude: Double) -> Double {
      modulo(180.0 - longitude + ascendantLongitude, 360.0)
    }

    func point(angle: Double, radius: Double) -> (Double, Double) {
      let radians = angle * .pi / 180.0
      return (
        centerX + unit * radius * cos(radians),
        centerY + unit * radius * sin(radians))
    }

    var targets: [WheelTooltipTarget] = []

    for sign in ZodiacSign.allCases {
      let angle = wheelAngle(for: Double(sign.index * 30 + 15))
      let location = point(angle: angle, radius: 0.875)
      targets.append(WheelTooltipTarget(
        kind: "sign", key: sign.rawValue, label: sign.name, relationships: [],
        x: location.0, y: location.1, radius: hitRadius))
    }

    for house in result.houses {
      guard let next = result.house(house.number == 12 ? 1 : house.number + 1) else { continue }
      let span = modulo(next.position.longitude - house.position.longitude, 360.0)
      let midpoint = modulo(house.position.longitude + span / 2.0, 360.0)
      let location = point(angle: wheelAngle(for: midpoint), radius: 0.70)
      let name = house.number == 1 || house.number == 4 ||
        house.number == 7 || house.number == 10
        ? "\(house.name) (House \(house.number))" : house.name
      targets.append(WheelTooltipTarget(
        kind: "house", key: String(house.number),
        label: "\(name) · \(house.position.displayText)", relationships: [],
        x: location.0, y: location.1, radius: hitRadius))
    }

    var ringItems = result.bodies.map { body in
      return RingItem(
        kind: "body", key: body.key,
        label: bodyLabel(body),
        longitude: body.position.longitude)
    }
    for number in [1, 10] {
      guard let house = result.house(number) else { continue }
      ringItems.append(RingItem(
        kind: "angle", key: house.key,
        label: "\(house.name) · \(house.position.displayText)",
        longitude: house.position.longitude))
    }

    var ringAngles = ringItems.map { wheelAngle(for: $0.longitude) }
    distributeSymbolRing(
      &ringAngles,
      minimumSeparation: 7.0 * 256.0 / viewBox.height * glyphScale)
    for (item, angle) in zip(ringItems, ringAngles) {
      let location = point(angle: angle, radius: 0.60)
      let relationships = item.kind == "body"
        ? relationshipLabels(forBodyNamed: result.body(item.key)?.name, in: result)
        : []
      targets.append(WheelTooltipTarget(
        kind: item.kind, key: item.key, label: item.label,
        relationships: relationships,
        x: location.0, y: location.1, radius: hitRadius))
    }

    return targets
  }

  private static func bodyLabel(_ body: ChartBody) -> String {
    let house = body.house.map { "House \($0)" } ?? "House unavailable"
    let motion = body.isRetrograde ? "Retrograde" : "Direct"
    return "\(body.name) · \(body.position.displayText) · \(house) · \(motion)"
  }

  private static func localHorizonMarkers(in svg: String) -> [SVGMarker] {
    let pattern = #"<circle\s+r=\"([0-9.]+)\"\s+cx=\"(-?[0-9.]+)\"\s+cy=\"(-?[0-9.]+)\"\s+fill=\"[^\"]+\"\s*/>"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(svg.startIndex..<svg.endIndex, in: svg)
    return expression.matches(in: svg, range: range).compactMap { match in
      func number(_ index: Int) -> Double? {
        guard let range = Range(match.range(at: index), in: svg) else { return nil }
        return Double(svg[range])
      }
      guard let radius = number(1), let x = number(2), let y = number(3) else { return nil }
      return SVGMarker(x: x, y: y, radius: radius)
    }
  }

  private static func localHorizonGlyphScale(viewBox: SVGViewBox) -> Double {
    let unscaledHeight = viewBox.height / 8.0
    let scale = unscaledHeight < 350 ? 1.0 :
      (unscaledHeight < 750 ? 2.0 : (unscaledHeight < 950 ? 3.0 : 4.0))
    return scale * 8.0
  }

  private static func localHorizonGlyphCenters(
    for descendingMarkers: [SVGMarker],
    viewBox: SVGViewBox
  ) -> [(x: Double, y: Double)] {
    let offset = localHorizonGlyphScale(viewBox: viewBox) * 7.0
    let glyphDiameter = offset * 2.0
    let ascendingMarkers = Array(descendingMarkers.reversed())
    var centers: [(x: Double, y: Double)] = []

    // Mirror Astrolog's DrawObjects() placement pass. Glyphs normally sit
    // below their exact marker, but crowded glyphs move above it when that
    // provides more separation from objects already placed.
    for marker in ascendingMarkers {
      var belowDistance = Double.greatestFiniteMagnitude
      var aboveDistance = Double.greatestFiniteMagnitude
      let belowY = marker.y + offset
      let aboveY = marker.y - offset
      for center in centers {
        belowDistance = min(
          belowDistance, abs(marker.x - center.x) + abs(belowY - center.y))
        aboveDistance = min(
          aboveDistance, abs(marker.x - center.x) + abs(aboveY - center.y))
      }
      let crowded = belowDistance < glyphDiameter || aboveDistance < glyphDiameter
      let tooCloseToBottom = belowY >= viewBox.minimumY + viewBox.height - offset
      let y = (crowded && belowDistance < aboveDistance) || tooCloseToBottom
        ? aboveY : belowY
      centers.append((marker.x, y))
    }
    return Array(centers.reversed())
  }

  private static func solarSystemGlyphCenters(
    for ascendingMarkers: [SVGMarker],
    viewBox: SVGViewBox,
    edge: Double
  ) -> [(x: Double, y: Double)] {
    let offset = localHorizonGlyphScale(viewBox: viewBox) * 7.0
    let glyphDiameter = offset * 2.0
    var centers: [(x: Double, y: Double)] = []
    for marker in ascendingMarkers {
      var belowDistance = Double.greatestFiniteMagnitude
      var aboveDistance = Double.greatestFiniteMagnitude
      let belowY = marker.y + offset
      let aboveY = marker.y - offset
      for center in centers {
        belowDistance = min(
          belowDistance, abs(marker.x - center.x) + abs(belowY - center.y))
        aboveDistance = min(
          aboveDistance, abs(marker.x - center.x) + abs(aboveY - center.y))
      }
      let crowded = belowDistance < glyphDiameter || aboveDistance < glyphDiameter
      let tooCloseToBottom = belowY >= viewBox.minimumY + viewBox.height - edge
      let y = (crowded && belowDistance < aboveDistance) || tooCloseToBottom
        ? aboveY : belowY
      centers.append((marker.x, y))
    }
    return centers
  }

  private static func relationshipLabels(
    forBodyNamed bodyName: String?,
    in result: ChartResult
  ) -> [String] {
    guard let bodyName else { return [] }
    let labels: [String] = result.aspects.compactMap { aspect in
      let otherName: String
      if aspect.firstBody == bodyName {
        otherName = aspect.secondBody
      } else if aspect.secondBody == bodyName {
        otherName = aspect.firstBody
      } else {
        return nil
      }
      return "\(otherName) · \(aspect.kind.name) · orb \(orbText(aspect.orbDegrees))"
    }
    let visibleLimit = 5
    guard labels.count > visibleLimit + 1 else { return labels }
    return Array(labels.prefix(visibleLimit)) + ["… \(labels.count - visibleLimit) more relationships"]
  }

  private static func aspectLines(
    for result: ChartResult,
    targets: [WheelTooltipTarget],
    viewBox: SVGViewBox
  ) -> [AspectLine] {
    let bodyByName = Dictionary(uniqueKeysWithValues: result.bodies.map { ($0.name, $0) })
    let targetByKey = Dictionary(uniqueKeysWithValues: targets.compactMap { target in
      target.kind == "body" ? (target.key, target) : nil
    })
    let nodeRadius = max(40.0, viewBox.height / 70.0)

    return result.aspects.compactMap { aspect in
      guard let first = bodyByName[aspect.firstBody],
            let second = bodyByName[aspect.secondBody],
            let firstTarget = targetByKey[first.key],
            let secondTarget = targetByKey[second.key] else { return nil }
      let dx = secondTarget.x - firstTarget.x
      let dy = secondTarget.y - firstTarget.y
      let distance = max(hypot(dx, dy), nodeRadius * 2.0)
      let inset = min(nodeRadius, distance * 0.25)
      let ux = dx / distance
      let uy = dy / distance
      return AspectLine(
        firstKey: first.key, secondKey: second.key, kind: aspect.kind,
        x1: firstTarget.x + ux * inset,
        y1: firstTarget.y + uy * inset,
        x2: secondTarget.x - ux * inset,
        y2: secondTarget.y - uy * inset)
    }
  }

  private static func distributeSymbolRing(
    _ angles: inout [Double],
    minimumSeparation: Double
  ) {
    guard angles.count > 1 else { return }
    for _ in 0..<(48 * 2) {
      var moved = false
      for index in angles.indices {
        var nearestPositive = Double.greatestFiniteMagnitude
        var nearestNegative = -Double.greatestFiniteMagnitude
        for otherIndex in angles.indices where otherIndex != index {
          var difference = angles[otherIndex] - angles[index]
          if abs(difference) > 180.0 {
            difference -= 360.0 * (difference < 0 ? -1.0 : 1.0)
          }
          if difference < nearestPositive && difference > 0.0 {
            nearestPositive = difference
          } else if difference > nearestNegative && difference <= 0.0 {
            nearestNegative = difference
          }
        }

        if nearestNegative > -minimumSeparation && nearestPositive > minimumSeparation {
          moved = true
          angles[index] = modulo(
            angles[index] + minimumSeparation * 0.51 + nearestNegative * 0.49, 360.0)
        } else if nearestPositive < minimumSeparation && nearestNegative < -minimumSeparation {
          moved = true
          angles[index] = modulo(
            angles[index] - minimumSeparation * 0.51 + nearestPositive * 0.49, 360.0)
        } else if nearestNegative > -minimumSeparation && nearestPositive < minimumSeparation {
          moved = true
          angles[index] = modulo(
            angles[index] + (nearestPositive + nearestNegative) * 0.5, 360.0)
        }
      }
      if !moved { break }
    }
  }

  private static func parseViewBox(_ svg: String) -> SVGViewBox? {
    guard let start = svg.range(of: "viewBox=\"")?.upperBound,
          let end = svg[start...].firstIndex(of: "\"") else { return nil }
    let values = svg[start..<end].split(whereSeparator: { $0.isWhitespace }).compactMap {
      Double($0)
    }
    guard values.count == 4, values[2] > 0, values[3] > 0 else { return nil }
    return SVGViewBox(
      minimumX: values[0], minimumY: values[1], width: values[2], height: values[3])
  }

  private static func tooltipMarkup(
    _ targets: [WheelTooltipTarget],
    aspects: [AspectLine],
    viewBox: SVGViewBox,
    lightBackground: Bool
  ) -> String {
    let locale = Locale(identifier: "en_US_POSIX")
    let unit = viewBox.height / 2.0 - 1.0
    let centerX = viewBox.minimumX + unit
    let centerY = viewBox.minimumY + unit
    let focusRadius = unit * 0.565
    let strokeWidth = max(8.0, viewBox.height / 360.0)
    let nodeRadius = max(40.0, viewBox.height / 70.0)
    let backgroundColor = lightBackground ? "white" : "black"
    let nodeColor = lightBackground ? "black" : "white"
    var lines = [
      "<g id=\"astrolog-as-aspect-focus\" display=\"none\" pointer-events=\"none\">",
      "<circle cx=\"\(format(centerX, locale))\" cy=\"\(format(centerY, locale))\" " +
        "r=\"\(format(focusRadius, locale))\" fill=\"\(backgroundColor)\"/>",
    ]
    for aspect in aspects {
      lines.append(
        "<g class=\"astrolog-as-aspect-relation\" display=\"none\" " +
        "data-first-key=\"\(escapeXML(aspect.firstKey))\" " +
        "data-second-key=\"\(escapeXML(aspect.secondKey))\">" +
        "<line " +
        "x1=\"\(format(aspect.x1, locale))\" y1=\"\(format(aspect.y1, locale))\" " +
        "x2=\"\(format(aspect.x2, locale))\" y2=\"\(format(aspect.y2, locale))\" " +
        "stroke=\"\(backgroundColor)\" stroke-width=\"\(format(strokeWidth * 2.25, locale))\" " +
        "stroke-linecap=\"round\"/>" +
        "<line " +
        "x1=\"\(format(aspect.x1, locale))\" y1=\"\(format(aspect.y1, locale))\" " +
        "x2=\"\(format(aspect.x2, locale))\" y2=\"\(format(aspect.y2, locale))\" " +
        "stroke=\"\(aspectColor(aspect.kind))\" stroke-width=\"\(format(strokeWidth, locale))\" " +
        "stroke-linecap=\"round\"/>" +
        "</g>")
    }
    for target in targets where target.kind == "body" {
      lines.append(
        "<circle class=\"astrolog-as-aspect-node\" display=\"none\" " +
        "data-body-key=\"\(escapeXML(target.key))\" " +
        "cx=\"\(format(target.x, locale))\" cy=\"\(format(target.y, locale))\" " +
        "r=\"\(format(nodeRadius, locale))\" fill=\"none\" stroke=\"\(nodeColor)\" " +
        "stroke-width=\"\(format(strokeWidth * 0.65, locale))\"/>")
    }
    lines += [
      "</g>",
      "<g id=\"astrolog-as-tooltips\" fill=\"transparent\" stroke=\"none\" pointer-events=\"all\">"
    ]
    for target in targets {
      let x = String(format: "%.2f", locale: locale, target.x)
      let y = String(format: "%.2f", locale: locale, target.y)
      let radius = String(format: "%.2f", locale: locale, target.radius)
      let label = escapeXML(target.label)
      let relationships = escapeXML(target.relationships.joined(separator: "|"))
      lines.append(
        "<circle class=\"astrolog-as-tooltip-target\" data-tooltip-kind=\"\(escapeXML(target.kind))\" " +
        "data-tooltip-key=\"\(escapeXML(target.key))\" " +
        "data-tooltip-relationships=\"\(relationships)\" aria-label=\"\(label)\" " +
        "cx=\"\(x)\" cy=\"\(y)\" r=\"\(radius)\">" +
        "<title>\(label)</title></circle>")
    }
    lines.append("</g>")
    lines.append("<script id=\"astrolog-as-tooltip-script\"><![CDATA[")
    lines.append(interactionScript)
    lines.append("]]></script>\n")
    return lines.joined(separator: "\n")
  }

  private static func format(_ value: Double, _ locale: Locale) -> String {
    String(format: "%.2f", locale: locale, value)
  }

  private static func orbText(_ orb: Double) -> String {
    let totalMinutes = Int((abs(orb) * 60.0).rounded())
    return "\(totalMinutes / 60)°\(String(format: "%02d", totalMinutes % 60))′"
  }

  private static func aspectColor(_ kind: AspectKind) -> String {
    switch kind {
    case .conjunction: return "yellow"
    case .opposition: return "blue"
    case .square: return "red"
    case .trine: return "lime"
    case .sextile: return "cyan"
    }
  }

  private static func escapeXML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&apos;")
  }

  private static func modulo(_ value: Double, _ modulus: Double) -> Double {
    let remainder = value.truncatingRemainder(dividingBy: modulus)
    return remainder < 0 ? remainder + modulus : remainder
  }
}
