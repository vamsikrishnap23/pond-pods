import QtQuick
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

// Sidebar card: one battery ring per pod and the case, like the macOS battery widget.
Shell.Card {
  id: root
  property real collapseProgress: 0
  readonly property bool shown: AirPods.State.hasAirPods && AirPods.State.hasBattery
  readonly property real widthProgress: Shell.Theme.collapseWidth(collapseProgress)
  readonly property real heightProgress: Shell.Theme.collapseHeight(collapseProgress)
  readonly property real expandedOpacity: 1 - Shell.Theme.ramp(collapseProgress, 0, 0.3)
  readonly property real collapsedOpacity: Shell.Theme.ramp(collapseProgress, 0.56, 0.9)

  readonly property var entries: AirPods.State.isHeadset
      ? [{ name: "Battery", info: AirPods.State.headsetBattery, inEar: false }]
      : [{ name: "Left", info: AirPods.State.leftPod, inEar: AirPods.State.leftPod.inEar },
         { name: "Right", info: AirPods.State.rightPod, inEar: AirPods.State.rightPod.inEar },
         { name: "Case", info: AirPods.State.caseBattery, inEar: false }]
  // The collapsed card has room for one ring, so it shows whichever part is lowest.
  readonly property var lowest: {
    let low = null;
    for (const entry of entries) {
      if (entry.info.level === Model.LEVEL_UNKNOWN) continue;
      if (low === null || entry.info.level < low.info.level) low = entry;
    }
    return low;
  }

  implicitWidth: Shell.Theme.lerp(Shell.Theme.sidebarCardExpandedWidth,
      Shell.Theme.sidebarCardCollapsedWidth, widthProgress)
  implicitHeight: !shown ? 0 : Shell.Theme.lerp(106, Shell.Theme.sidebarCardCollapsedWidth, heightProgress)
  visible: shown
  radius: Shell.Theme.sidebarCardRadius
  Accessible.role: Accessible.StaticText
  Accessible.name: AirPods.State.modelName + " battery"
  signal clicked

  MouseArea {
    anchors.fill: parent
    z: 10
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  // Expanded layout.
  Item {
    id: expanded
    width: Shell.Theme.sidebarCardExpandedWidth
    height: parent.height
    opacity: root.expandedOpacity
    visible: opacity > 0.001

    Text {
      x: 14
      y: 12
      width: parent.width - 28
      text: AirPods.State.modelName || AirPods.State.deviceName
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Qt.alpha(Shell.Theme.colors.text, 0.5)
      font.family: Shell.Theme.fontFamily
      font.pixelSize: 11
      font.letterSpacing: 0.11
    }

    Row {
      x: 6
      y: 36
      width: parent.width - 12
      Repeater {
        model: root.entries
        delegate: Item {
          id: cell
          required property var modelData
          width: parent.width / root.entries.length
          height: 56

          Ring {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 38
            level: cell.modelData.info.level
            charging: cell.modelData.info.charging
            showText: false
            part: cell.modelData.name
          }
          Text {
            y: 43
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Model.levelText(cell.modelData.info.level)
            textFormat: Text.PlainText
            color: Shell.Theme.colors.text
            font.family: Shell.Theme.fontFamily
            font.weight: Font.Medium
            font.pixelSize: 12
          }
        }
      }
    }
  }

  // Collapsed layout.
  Ring {
    anchors.centerIn: parent
    visible: opacity > 0.001
    opacity: root.collapsedOpacity
    size: 28
    level: root.lowest ? root.lowest.info.level : Model.LEVEL_UNKNOWN
    charging: root.lowest ? root.lowest.info.charging : false
    showText: false
  }
}
