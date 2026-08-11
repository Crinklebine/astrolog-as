import Foundation

enum SolarSystemZoomError: LocalizedError {
  case invalidSVG

  var errorDescription: String? {
    "Astrolog created an SVG that could not be prepared for Solar System zooming."
  }
}

enum SolarSystemZoomAnnotator {
  private static let interactionScript = #"""
  (() => {
    const svg = document.documentElement;
    if (!svg || svg.tagName.toLowerCase() !== "svg") return;
    const zoomHandler = window.webkit?.messageHandlers?.solarSystemZoom;
    if (!zoomHandler) return;

    svg.addEventListener("wheel", event => {
      event.preventDefault();
      if (!event.deltaY) return;

      const modeScale = event.deltaMode === 1 ? 16 :
        (event.deltaMode === 2 ? Math.max(svg.clientHeight, 1) : 1);
      zoomHandler.postMessage({ delta: event.deltaY * modeScale });
    }, { passive: false });

    svg.addEventListener("dblclick", event => {
      event.preventDefault();
      zoomHandler.postMessage({ reset: true });
    });
  })();
  """#

  static func annotate(svgAt url: URL) throws {
    let svg = try String(contentsOf: url, encoding: .utf8)
    let annotated = try annotatedSVG(svg)
    try annotated.write(to: url, atomically: true, encoding: .utf8)
  }

  static func annotatedSVG(_ svg: String) throws -> String {
    if svg.contains("id=\"astrolog-as-solar-zoom\"") { return svg }
    guard svg.contains("viewBox=\""),
          let closingTag = svg.range(of: "</svg>", options: .backwards) else {
      throw SolarSystemZoomError.invalidSVG
    }
    let markup = """
    <script id="astrolog-as-solar-zoom"><![CDATA[
    \(interactionScript)
    ]]></script>
    """
    var annotated = svg
    annotated.insert(contentsOf: markup, at: closingTag.lowerBound)
    return annotated
  }
}
