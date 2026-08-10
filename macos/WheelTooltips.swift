import Foundation

struct WheelTooltipTarget: Equatable {
  let kind: String
  let key: String
  let label: String
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

    const hide = () => layer.setAttribute("display", "none");
    svg.addEventListener("pointerleave", hide);
    svg.addEventListener("pointermove", event => {
      const target = event.target.closest?.(".astrolog-as-tooltip-target");
      const label = target?.getAttribute("aria-label");
      if (!label) {
        hide();
        return;
      }

      const viewBox = svg.viewBox.baseVal;
      const fontSize = viewBox.height / 52;
      const padding = fontSize * 0.42;
      text.setAttribute("font-size", String(fontSize));
      text.setAttribute("x", String(padding));
      text.setAttribute("y", String(fontSize + padding * 0.55));
      text.textContent = label;
      layer.removeAttribute("display");

      const width = text.getComputedTextLength() + padding * 2;
      const height = fontSize + padding;
      background.setAttribute("width", String(width));
      background.setAttribute("height", String(height));

      const point = svg.createSVGPoint();
      point.x = event.clientX;
      point.y = event.clientY;
      const location = point.matrixTransform(svg.getScreenCTM().inverse());
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

  static func annotate(svgAt url: URL, result: ChartResult) throws {
    let svg = try String(contentsOf: url, encoding: .utf8)
    let annotated = try annotatedSVG(svg, result: result)
    try annotated.write(to: url, atomically: true, encoding: .utf8)
  }

  static func annotatedSVG(_ svg: String, result: ChartResult) throws -> String {
    if svg.contains("id=\"astrolog-as-tooltips\"") { return svg }
    guard let viewBox = parseViewBox(svg),
          let closingTag = svg.range(of: "</svg>", options: .backwards) else {
      throw WheelTooltipError.invalidSVG
    }

    let targets = tooltipTargets(for: result, viewBox: viewBox)
    let markup = tooltipMarkup(targets)
    var annotated = svg
    annotated.insert(contentsOf: markup, at: closingTag.lowerBound)
    return annotated
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
        kind: "sign", key: sign.rawValue, label: sign.name,
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
        label: "\(name) · \(house.position.displayText)",
        x: location.0, y: location.1, radius: hitRadius))
    }

    var ringItems = result.bodies.map { body in
      let house = body.house.map { "House \($0)" } ?? "House unavailable"
      let motion = body.isRetrograde ? "Retrograde" : "Direct"
      return RingItem(
        kind: "body", key: body.key,
        label: "\(body.name) · \(body.position.displayText) · \(house) · \(motion)",
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
      targets.append(WheelTooltipTarget(
        kind: item.kind, key: item.key, label: item.label,
        x: location.0, y: location.1, radius: hitRadius))
    }

    return targets
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

  private static func tooltipMarkup(_ targets: [WheelTooltipTarget]) -> String {
    let locale = Locale(identifier: "en_US_POSIX")
    var lines = [
      "<g id=\"astrolog-as-tooltips\" fill=\"transparent\" stroke=\"none\" pointer-events=\"all\">"
    ]
    for target in targets {
      let x = String(format: "%.2f", locale: locale, target.x)
      let y = String(format: "%.2f", locale: locale, target.y)
      let radius = String(format: "%.2f", locale: locale, target.radius)
      let label = escapeXML(target.label)
      lines.append(
        "<circle class=\"astrolog-as-tooltip-target\" data-tooltip-kind=\"\(escapeXML(target.kind))\" " +
        "data-tooltip-key=\"\(escapeXML(target.key))\" aria-label=\"\(label)\" " +
        "cx=\"\(x)\" cy=\"\(y)\" r=\"\(radius)\">" +
        "<title>\(label)</title></circle>")
    }
    lines.append("</g>")
    lines.append("<script id=\"astrolog-as-tooltip-script\"><![CDATA[")
    lines.append(interactionScript)
    lines.append("]]></script>\n")
    return lines.joined(separator: "\n")
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
