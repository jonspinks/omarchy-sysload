import QtQuick
import qs.Commons

// One resource, one bar, one number. Used for the four sub-scores that feed
// the gauge, so the panel answers "why is it at 80%" without further clicks.
Item {
  id: root

  property string label: ""
  property real value: 0            // 0..1, drives the bar
  property string valueText: ""
  property string note: ""
  property bool leading: false      // this is the resource setting the strain
  property color foreground: Color.foreground
  property color hotColor: Color.urgent
  property color midColor: Color.accent
  property string fontFamily: Style.font.family

  implicitHeight: labelText.implicitHeight + (note !== "" ? noteText.implicitHeight + Style.space(2) : 0)

  function mix(a, b, t) {
    t = t < 0 ? 0 : (t > 1 ? 1 : t)
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
  }

  readonly property color barColor: value < 0.5
    ? mix(foreground, midColor, value / 0.5)
    : mix(midColor, hotColor, (value - 0.5) / 0.5)

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.top: parent.top
    width: Style.space(58)
    text: root.label
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    // The leading resource is the answer to the question the gauge raises, so
    // it gets the only emphasis in the block; dimming the other three would
    // just make the panel harder to scan.
    opacity: root.leading ? 1.0 : 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: root.leading
  }

  Rectangle {
    id: track
    anchors.left: labelText.right
    anchors.leftMargin: Style.space(10)
    anchors.right: valueLabel.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: labelText.verticalCenter
    height: Math.max(3, Style.space(4))
    radius: height / 2
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

    Rectangle {
      width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
      height: parent.height
      radius: parent.radius
      color: root.barColor
      Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }
  }

  Text {
    id: valueLabel
    anchors.right: parent.right
    anchors.verticalCenter: labelText.verticalCenter
    // Grows to fit "11.2 GB / 31.3 GB" rather than eliding it; the fixed floor
    // keeps short values in a column, the cap keeps room for the bar.
    width: Math.max(Style.space(62), Math.min(implicitWidth, root.width * 0.45))
    horizontalAlignment: Text.AlignRight
    text: root.valueText
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    opacity: root.leading ? 1.0 : 0.75
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Text {
    id: noteText
    visible: root.note !== ""
    anchors.left: labelText.left
    anchors.right: parent.right
    anchors.top: labelText.bottom
    anchors.topMargin: Style.space(2)
    text: root.note
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    opacity: 0.5
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
