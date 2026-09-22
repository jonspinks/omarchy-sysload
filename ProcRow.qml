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
      anchors.leftMargin: Math.min(parent.contentWidth + Style.space(6),
                                   parent.width - implicitWidth)
      anchors.baseline: parent.baseline
      visible: root.procPid > 0 && parent.contentWidth < parent.width - implicitWidth
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
    width: Style.space(104)
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
