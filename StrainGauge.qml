import QtQuick
import qs.Commons

// The always-visible mark: one figure, drawn rather than written.
//
// Two forms, picked with the `style` setting. "arc" is a 270-degree dial with
// the gap at the bottom, which reads as a gauge at 16px in a way a needle
// never would — a needle at this size is three pixels of mush. "bar" is a flat
// fill for people who want the bar to stay visually quiet.
//
// Drawn on a Canvas for the same reason the NextDNS shield is: Qt's SVG
// rendering is unreliable at bar-icon sizes, and a font glyph cannot animate
// between values.
Item {
  id: root

  property real value: 0          // 0..1 strain
  property string style: "arc"
  property bool vertical: false
  property real iconSize: Style.bar.iconCanvas
  property color calmColor: Color.foreground
  property color midColor: Color.accent
  property color hotColor: Color.urgent
  property real trackOpacity: 0.18

  // The gauge moves toward a new reading rather than snapping to it. Sampling
  // is discrete but load is not, and an unsmoothed gauge reads as noise you
  // learn to ignore. 600ms is slow enough to look considered and fast enough
  // that a spike is still visibly a spike.
  property real displayValue: 0
  Behavior on displayValue {
    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
  }
  onValueChanged: displayValue = value
  Component.onCompleted: displayValue = value

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  function mix(a, b, t) {
    t = t < 0 ? 0 : (t > 1 ? 1 : t)
    return Qt.rgba(a.r + (b.r - a.r) * t,
                   a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t,
                   a.a + (b.a - a.a) * t)
  }

  // Calm to working to hot. Themes where `accent` resolves to the same colour
  // as `foreground` simply lose the middle stop and still ramp to urgent.
  readonly property color activeColor: {
    var v = displayValue
    return v < 0.5 ? mix(calmColor, midColor, v / 0.5)
                   : mix(midColor, hotColor, (v - 0.5) / 0.5)
  }

  onDisplayValueChanged: canvas.requestPaint()
  onActiveColorChanged: canvas.requestPaint()
  onStyleChanged: canvas.requestPaint()
  onVerticalChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (root.style === "bar") paintBar(ctx)
      else paintArc(ctx)
    }

    function paintArc(ctx) {
      var s = Math.min(width, height)
      var lw = Math.max(1.6, s * 0.16)
      var r = (s - lw) / 2 - s * 0.04
      var cx = width / 2
      var cy = height / 2

      // Canvas angles run clockwise from 3 o'clock with y pointing down, so
      // 0.75pi is the 7:30 position. Sweeping 1.5pi from there leaves the gap
      // across the bottom, where a dial's gap belongs.
      var start = Math.PI * 0.75
      var sweep = Math.PI * 1.5

      ctx.lineCap = "round"
      ctx.lineWidth = lw

      ctx.beginPath()
      ctx.strokeStyle = Qt.rgba(root.calmColor.r, root.calmColor.g, root.calmColor.b, root.trackOpacity)
      ctx.arc(cx, cy, r, start, start + sweep, false)
      ctx.stroke()

      // Below about a degree of sweep the round cap is the only thing drawn
      // and a genuinely idle machine shows a stray dot, so keep a floor that
      // is visible but unmistakably "nearly nothing".
      var filled = sweep * Math.max(root.displayValue, 0.012)
      ctx.beginPath()
      ctx.strokeStyle = root.activeColor
      ctx.arc(cx, cy, r, start, start + filled, false)
      ctx.stroke()
    }

    function paintBar(ctx) {
      var thickness = Math.max(2.5, Math.min(width, height) * 0.30)
      var along = root.vertical ? height : width
      var pad = Math.max(1, along * 0.08)
      var len = along - pad * 2
      var r = thickness / 2

      function track(x, y, w, h, fill) {
        ctx.beginPath()
        ctx.fillStyle = fill
        // roundedRect is not in Qt's Canvas 2D, so lay the pill down by hand.
        var rr = Math.min(r, w / 2, h / 2)
        ctx.moveTo(x + rr, y)
        ctx.lineTo(x + w - rr, y)
        ctx.arcTo(x + w, y, x + w, y + rr, rr)
        ctx.lineTo(x + w, y + h - rr)
        ctx.arcTo(x + w, y + h, x + w - rr, y + h, rr)
        ctx.lineTo(x + rr, y + h)
        ctx.arcTo(x, y + h, x, y + h - rr, rr)
        ctx.lineTo(x, y + rr)
        ctx.arcTo(x, y, x + rr, y, rr)
        ctx.fill()
      }

      var dim = Qt.rgba(root.calmColor.r, root.calmColor.g, root.calmColor.b, root.trackOpacity)
      var filledLen = Math.max(thickness, len * root.displayValue)

      if (root.vertical) {
        var bx = (width - thickness) / 2
        track(bx, pad, thickness, len, dim)
        // Fills upward: on a vertical bar, "more" reading downward would
        // fight every other meter on the screen.
        track(bx, pad + len - filledLen, thickness, filledLen, root.activeColor)
      } else {
        var by = (height - thickness) / 2
        track(pad, by, len, thickness, dim)
        track(pad, by, filledLen, thickness, root.activeColor)
      }
    }
  }
}
