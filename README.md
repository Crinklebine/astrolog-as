# Astrolog 8.00 on macOS

This source tree is configured for a native macOS command-line build. It keeps
Astrolog's graphics engine and SVG, PNG, PostScript, and bitmap exports enabled,
while disabling the optional X11 window layer.

## Requirements

- macOS
- Apple Command Line Tools (`xcode-select --install`)

## Build

```sh
make -j8
```

The result is the `astrolog` executable in this directory. Rebuild from scratch
with:

```sh
make clean
make -j8
```

## Run

Run Astrolog from this directory so it can find `astrolog.as`, `atlas.as`,
`timezone.as`, `sefstars.txt`, and the `ephem` directory:

```sh
./astrolog -H
./astrolog -n -v
```

The source distribution defaults to Seattle. Edit `astrolog.as`, or pass chart
location and time-zone switches, before relying on "current moment" charts.

For example, look up a city using the bundled atlas and timezone data:

```sh
./astrolog -n -zN "Seattle, WA, USA" -v
```

Generate chart graphics without X11:

```sh
./astrolog -n -zN "Seattle, WA, USA" -XV -Xo chart.svg
./astrolog -n -zN "Seattle, WA, USA" -Xbp -Xo chart.png
```

## Optional interactive windows

Interactive chart windows require XQuartz and an X11-enabled rebuild. Install
XQuartz separately, uncomment `#define X11` in `astrolog.h`, and add the XQuartz
include, library, and runtime settings to the Makefile.

## Native macOS app

Build the self-contained Apple Silicon app with:

```sh
./scripts/build_macos_app.sh
```

The result is `dist/Astrolog.app`. It embeds the calculation engine and runtime
data, provides native controls and chart preview, and does not require XQuartz.

Run the fixed-instant timezone and daylight-saving tests with:

```sh
./scripts/test_macos_time.sh
```

Run the typed chart-result regressions against fixed New York and Douglas
reference charts with:

```sh
./scripts/test_macos_chart_result.sh
```
