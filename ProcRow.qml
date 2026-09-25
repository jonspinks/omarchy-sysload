import QtQuick
import qs.Commons

// One process in the "busiest now" / "most memory" lists: what it is on the
// left, what it is costing on the right.
Item {
  id: root

  property string procName: ""
  property int procPid: 0
  property string amount: ""
  property string amountNote: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  implicitHeight: nameText.implicitHeight

  Text {
    id: nameText
    anchors.left: parent.left
    anchors.right: amountText.left
    anchors.rightMargin: Style.space(10)
    // The pid trails the name dimly rather than in its own column: it is the
    // thing you need only once you have decided to go and do something about
    // the process, so it should not compete for the scan.
    text: root.procName
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall

    Text {
      anchors.left: parent.left
      anchors.leftMargin: parent.contentWidth + Style.space(6)
      anchors.baseline: parent.baseline
      // Only when the gap fits too; otherwise a long name runs into its pid.
      visible: root.procPid > 0
        && parent.contentWidth + Style.space(6) + implicitWidth <= parent.width
      text: root.procPid
      textFormat: Text.PlainText
      color: root.foreground
      opacity: 0.4
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    id: amountText
    anchors.right: parent.right
    anchors.verticalCenter: nameText.verticalCenter
    // Fits "594 MB  ·  1% cpu" whole; the name to the left elides instead.
    width: Math.max(Style.space(104), Math.min(implicitWidth, root.width * 0.5))
    horizontalAlignment: Text.AlignRight
    text: root.amountNote !== "" ? root.amount + "  ·  " + root.amountNote : root.amount
    textFormat: Text.PlainText
    elide: Text.ElideRight
    opacity: 0.75
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
