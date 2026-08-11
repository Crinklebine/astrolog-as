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

enum SVGDocumentUpdater {
  static func replacementJavaScript(for svg: String) throws -> String {
    let encoded = try JSONSerialization.data(withJSONObject: [svg])
    guard let json = String(data: encoded, encoding: .utf8) else {
      throw SolarSystemZoomError.invalidSVG
    }
    return #"""
    (() => {
      const markup = \#(json)[0];
      const parsed = new DOMParser().parseFromString(markup, "image/svg+xml");
      if (parsed.querySelector("parsererror")) throw new Error("Invalid SVG");
      const nextRoot = document.adoptNode(parsed.documentElement);
      const scripts = Array.from(nextRoot.querySelectorAll("script"), node => node.textContent);
      document.documentElement.replaceWith(nextRoot);
      scripts.forEach(source => window.eval(source));
    })();
    """#
  }
}
