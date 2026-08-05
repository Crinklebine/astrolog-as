import AppKit

guard CommandLine.arguments.count == 2 else {
  fputs("Usage: GenerateIcon <iconset-directory>\n", stderr)
  exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func makeMasterIcon() -> NSImage {
  let size = NSSize(width: 1024, height: 1024)
  let image = NSImage(size: size)
  image.lockFocus()

  NSColor.clear.setFill()
  NSRect(origin: .zero, size: size).fill()

  let tile = NSBezierPath(roundedRect: NSRect(x: 44, y: 44, width: 936, height: 936), xRadius: 210, yRadius: 210)
  let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.06, blue: 0.30, alpha: 1),
    NSColor(calibratedRed: 0.24, green: 0.12, blue: 0.55, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.62, alpha: 1),
  ])!
  gradient.draw(in: tile, angle: -48)

  let center = NSPoint(x: 512, y: 512)
  let gold = NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.40, alpha: 1)
  let pale = NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 0.92)

  for radius in [340.0, 252.0, 118.0] {
    let circle = NSBezierPath(ovalIn: NSRect(
      x: center.x - radius, y: center.y - radius,
      width: radius * 2, height: radius * 2))
    circle.lineWidth = radius == 340 ? 18 : 9
    (radius == 340 ? gold : pale).setStroke()
    circle.stroke()
  }

  pale.setStroke()
  for index in 0..<12 {
    let angle = Double(index) * .pi / 6.0
    let inner = NSPoint(x: center.x + cos(angle) * 252, y: center.y + sin(angle) * 252)
    let outer = NSPoint(x: center.x + cos(angle) * 340, y: center.y + sin(angle) * 340)
    let line = NSBezierPath()
    line.move(to: inner)
    line.line(to: outer)
    line.lineWidth = 8
    line.stroke()
  }

  gold.setFill()
  NSBezierPath(ovalIn: NSRect(x: 435, y: 435, width: 154, height: 154)).fill()
  pale.setStroke()
  for index in 0..<8 {
    let angle = Double(index) * .pi / 4.0
    let ray = NSBezierPath()
    ray.move(to: NSPoint(x: center.x + cos(angle) * 132, y: center.y + sin(angle) * 132))
    ray.line(to: NSPoint(x: center.x + cos(angle) * 202, y: center.y + sin(angle) * 202))
    ray.lineWidth = 13
    ray.lineCapStyle = .round
    ray.stroke()
  }

  let stars: [(CGFloat, CGFloat, CGFloat)] = [
    (242, 731, 13), (755, 697, 10), (696, 254, 14), (281, 302, 9),
    (512, 884, 8), (850, 476, 7), (168, 505, 7),
  ]
  gold.setFill()
  for (x, y, radius) in stars {
    NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)).fill()
  }

  image.unlockFocus()
  return image
}

func writePNG(master: NSImage, pixels: Int, name: String) throws {
  let target = NSImage(size: NSSize(width: pixels, height: pixels))
  target.lockFocus()
  NSGraphicsContext.current?.imageInterpolation = .high
  master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
              from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
              operation: .copy, fraction: 1)
  target.unlockFocus()

  guard let tiff = target.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "AstrologIcon", code: 1)
  }
  try png.write(to: outputDirectory.appendingPathComponent(name))
}

let master = makeMasterIcon()
let variants = [
  (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
  (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
  (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
  (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
  (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (pixels, name) in variants {
  try writePNG(master: master, pixels: pixels, name: name)
}
