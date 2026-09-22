import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// System strain in the bar: one dial that says how hard the machine is
// working, a hover tooltip that says what is driving it, and a panel with the
// numbers underneath.
//
// The dial is deliberately a single figure. Four numbers in the bar is a
// dashboard you stop reading after a week; one figure that changes colour is
// something you notice from the corner of your eye. The detail is all still
// here, one hover or one click away.
Panel {
  id: root
  moduleName: "blacksheep.sysload"
  ipcTarget: "blacksheep.sysload"

  implicitWidth: button.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

  readonly property string scriptPath:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/blacksheep.sysload/bin/sysload-sample"

  readonly property string gaugeStyle: setting("style", "arc")
  // Polling harder than the kernel updates PSI (10s windows, 2s ticks) buys
  // nothing but wakeups, and this widget is running all day.
  readonly property int openInterval: Math.max(500, setting("interval", 2) * 1000)
  readonly property int idleInterval: Math.max(1000, setting("idleInterval", 4) * 1000)

  property var sample: null
  property var prevSample: null
  property var d: Model.derive(null, null)

  function refresh() {
    if (sampleProc.running) return
    // The per-process walk costs ~500 file reads. Worth it while someone is
    // reading the panel, wasteful every few seconds behind a closed popup.
    sampleProc.command = root.opened ? [scriptPath, "--procs"] : [scriptPath]
    sampleProc.running = true
  }

  function applySample(text) {
    var next
    try {
      next = JSON.parse(String(text || "").trim() || "null")
    } catch (e) {
      return
    }
    if (!next) return
    next.__t = Date.now() / 1000
    prevSample = sample
    sample = next
    d = Model.derive(sample, prevSample)
  }

  Process {
    id: sampleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySample(text)
    }
  }

  Timer {
    interval: root.opened ? root.openInterval : root.idleInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Opening the panel switches the sampler into its detailed mode; waiting up
  // to a full interval for the process list to appear makes the panel feel
  // broken, so take an extra sample immediately.
  onOpenedChanged: if (opened) refresh()

  readonly property string tooltipSummary: {
    if (!sample) return "System — sampling…"
    var lines = [
      Model.moodFor(d.strain) + " — " + Model.percent(d.strain) + " (" + d.driverLabel + ")",
      "CPU " + Model.percent(d.cpu)
        + "   Mem " + Model.percent(d.memUsed)
        + "   " + Model.tempText(d.temp),
      "Net " + Model.rateText(d.netRx) + " down / " + Model.rateText(d.netTx) + " up"
    ]
    if (d.top && d.top.length > 0)
      lines.push("Busiest: " + d.top[0].name + " " + d.top[0].cpu.toFixed(0) + "%")
    return lines.join("\n")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltipSummary

    iconComponent: Component {
      Item {
        StrainGauge {
          anchors.centerIn: parent
          iconSize: Style.bar.iconCanvas
          style: root.gaugeStyle
          vertical: root.bar ? root.bar.vertical : false
          value: root.d.strain
          calmColor: root.bar ? root.bar.barForeground : Color.foreground
          midColor: Color.accent
          hotColor: root.bar ? root.bar.urgent : Color.urgent
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        // The panel is a summary by design. When you want the real thing,
        // btop is one right-click away rather than something this widget
        // tries and fails to reimplement.
        if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
        return
      }
      root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "b" || t === "B") {
          if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
          root.close()
        }
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          title: Model.moodFor(root.d.strain)
          meta: root.sample
            ? root.d.driverLabel + " leading · " + Model.percent(root.d.strain)
            : "Sampling…"
          iconComponent: Component {
            StrainGauge {
              iconSize: Style.font.display
              style: "arc"
              value: root.d.strain
              calmColor: root.bar ? root.bar.foreground : Color.foreground
              midColor: Color.accent
              hotColor: root.bar ? root.bar.urgent : Color.urgent
            }
          }
        }

        PanelSeparator { width: parent.width }

        // The four sub-scores, in the order they most often bite.
        Column {
          width: parent.width
          spacing: Style.space(8)

          MeterRow {
            width: parent.width
            label: "CPU"
            value: root.d.cpu
            valueText: Model.percent(root.d.cpu)
            leading: root.d.driver === "cpu"
            note: root.d.running > 0
              ? root.d.running + " running · load " + (root.d.load[0] || "0") + " over " + root.d.cores + " cores"
              : ""
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            hotColor: root.bar ? root.bar.urgent : Color.urgent
          }

          MeterRow {
            width: parent.width
            label: "Memory"
            value: root.d.scores.memory || 0
            valueText: Model.bytes(root.d.memUsedBytes) + " / " + Model.bytes(root.d.memTotalBytes)
            leading: root.d.driver === "memory"
            // Swap in use is the detail that explains a machine that feels
            // slow while every other number looks calm.
            note: root.d.swapUsedBytes > 0
              ? "swap " + Model.bytes(root.d.swapUsedBytes) + " of " + Model.bytes(root.d.swapTotalBytes)
                + (root.d.psi && root.d.psi.memFull > 0.5 ? " · stalling " + root.d.psi.memFull.toFixed(1) + "%" : "")
              : ""
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            hotColor: root.bar ? root.bar.urgent : Color.urgent
          }

          MeterRow {
            width: parent.width
            label: "Disk I/O"
            value: root.d.scores.io || 0
            valueText: Model.rateText(root.d.diskRead + root.d.diskWrite)
            leading: root.d.driver === "io"
            note: "read " + Model.rateText(root.d.diskRead) + " · write " + Model.rateText(root.d.diskWrite)
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            hotColor: root.bar ? root.bar.urgent : Color.urgent
          }

          MeterRow {
            width: parent.width
            visible: root.d.temp !== null
            label: "Heat"
            value: root.d.scores.thermal || 0
            valueText: Model.tempText(root.d.temp)
            leading: root.d.driver === "thermal"
            note: root.d.tempMax
              ? "throttles at " + Model.tempText(root.d.tempMax)
                + (root.d.tempNvme ? " · nvme " + Model.tempText(root.d.tempNvme) : "")
              : ""
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            hotColor: root.bar ? root.bar.urgent : Color.urgent
          }
        }

        PanelSeparator { width: parent.width }

        GridLayout {
          width: parent.width
          columns: 2
          columnSpacing: Style.space(14)
          rowSpacing: Style.space(6)

          InfoLabel { text: "Network" }
          InfoValue {
            Layout.fillWidth: true
            text: "↓ " + Model.rateText(root.d.netRx) + "   ↑ " + Model.rateText(root.d.netTx)
          }

          InfoLabel { text: "Load" }
          InfoValue {
            Layout.fillWidth: true
            text: (root.d.load || []).join("  ") + "   (" + root.d.cores + " cores)"
          }

          InfoLabel { text: "Uptime" }
          InfoValue { text: Model.uptimeText(root.d.uptime) }
        }

        PanelSeparator { width: parent.width; visible: topCpu.visible }

        PanelSectionHeader {
          id: topCpu
          visible: root.d.top && root.d.top.length > 0
          text: "Busiest now"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: topCpu.visible

          Repeater {
            model: root.d.top || []
            delegate: ProcRow {
              width: parent ? parent.width : 0
              procName: modelData.name
              procPid: modelData.pid
              // Per-process CPU is per core, as in top: 350% is one process
              // saturating three and a half of them.
              amount: modelData.cpu.toFixed(0) + "%"
              amountNote: Model.bytes(modelData.rss)
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }
          }
        }

        PanelSeparator { width: parent.width; visible: topMem.visible }

        PanelSectionHeader {
          id: topMem
          visible: root.d.topMem && root.d.topMem.length > 0
          text: "Most memory"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: topMem.visible

          Repeater {
            model: root.d.topMem || []
            delegate: ProcRow {
              width: parent ? parent.width : 0
              procName: modelData.name
              procPid: modelData.pid
              amount: Model.bytes(modelData.rss)
              amountNote: modelData.cpu > 0.05 ? modelData.cpu.toFixed(0) + "% cpu" : ""
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }
          }
        }

        Text {
          width: parent.width
          text: "r refresh · b btop · right-click the gauge for btop"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          opacity: 0.45
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar ? root.bar.foreground : Color.foreground
    opacity: 0.6
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.bar ? root.bar.foreground : Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
}
