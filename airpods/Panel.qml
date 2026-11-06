pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

// Flyout beside the sidebar: battery, listening mode and the AirPods options.
Item {
  id: root

  property bool opened: false
  readonly property int closeAllDuration: 200
  readonly property var service: AirPods.State
  readonly property var modes: service.availableModes()
  readonly property Region blurRegion: Region {
    item: root.opened && root.opacity > Shell.PanelStyle.blurRevealOpacity ? card : null
    radius: Shell.PanelStyle.radius
  }
  onXChanged: blurRegion.changed()
  onYChanged: blurRegion.changed()
  onScaleChanged: blurRegion.changed()

  width: 336
  height: card.implicitHeight + 22
  visible: opened || closeCleanup.running
  opacity: opened ? 1 : 0
  scale: opened ? 1 : 0.9
  transformOrigin: Item.TopLeft

  // Nothing to show once the AirPods go away, so the flyout leaves with them.
  Connections {
    target: root.service
    function onHasAirPodsChanged() { if (!root.service.hasAirPods) root.closeAll(); }
  }

  Behavior on height {
    NumberAnimation {
      duration: 350
      easing.type: Easing.Bezier
      easing.bezierCurve: [0.19, 1, 0.22, 1, 1, 1]
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: root.opened ? Shell.PanelStyle.openDuration : root.closeAllDuration
      easing.type: root.opened ? Easing.InOutCubic : Easing.Bezier
      easing.bezierCurve: [0.19, 1, 0.22, 1, 1, 1]
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: root.opened ? Shell.PanelStyle.openDuration : root.closeAllDuration
      easing.type: root.opened ? Easing.InOutCubic : Easing.Bezier
      easing.bezierCurve: [0.19, 1, 0.22, 1, 1, 1]
    }
  }

  Shell.Shadow {
    anchors.fill: card
    cornerRadius: Shell.PanelStyle.radius
    shadows: Shell.PanelStyle.frontShadows
  }

  Shell.PanelBackground {
    id: card
    y: 22
    width: Shell.PanelStyle.width
    height: root.height - y
    implicitHeight: content.implicitHeight + 40
    Accessible.role: Accessible.Pane
    Accessible.name: "AirPods"

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    }

    Column {
      id: content
      x: 20
      y: 20
      width: Shell.PanelStyle.fieldWidth
      spacing: 4

      Text {
        width: parent.width
        height: 28
        verticalAlignment: Text.AlignVCenter
        text: root.service.modelName || root.service.deviceName || "AirPods"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Shell.Theme.colors.text
        font.family: Shell.Theme.fontFamily
        font.weight: Font.Medium
        font.pixelSize: 17
      }

      // Battery.
      Row {
        width: parent.width
        height: 84
        Repeater {
          model: root.service.isHeadset
              ? [{ name: "Battery", info: root.service.headsetBattery }]
              : [{ name: "Left", info: root.service.leftPod },
                 { name: "Right", info: root.service.rightPod },
                 { name: "Case", info: root.service.caseBattery }]
          delegate: Item {
            id: cell
            required property var modelData
            width: content.width / (root.service.isHeadset ? 1 : 3)
            height: 84
            AirPods.Ring {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 6
              size: 52
              stroke: 5
              level: cell.modelData.info.level
              charging: cell.modelData.info.charging
              showText: false
              part: cell.modelData.name
            }
            Text {
              y: 62
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: Model.levelText(cell.modelData.info.level)
              textFormat: Text.PlainText
              color: Shell.Theme.colors.text
              font.family: Shell.Theme.fontFamily
              font.weight: Font.Medium
              font.pixelSize: 13
            }
          }
        }
      }

      // Listening mode.
      SectionLabel { visible: root.modes.length > 0; text: "Listening mode" }
      Repeater {
        model: root.modes
        delegate: OptionRow {
          required property int modelData
          label: Model.noiseModeName(modelData)
          selected: root.service.noiseMode === modelData
          onClicked: root.service.setNoiseMode(modelData)
        }
      }
      Item {
        width: parent.width
        height: 36
        visible: root.service.supportsAdaptive && root.service.noiseMode === Model.NOISE_ADAPTIVE
        Shell.Slider {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          externalValue: root.service.adaptiveNoiseLevel / 100
          trackColor: Shell.PanelStyle.drawerSliderTrack
          onDragFinished: root.service.setAdaptiveNoiseLevel(value * 100)
        }
      }

      // Options.
      SectionLabel {
        visible: root.service.supportsConversationalAwareness || root.service.supportsOneBudANC
            || !root.service.isHeadset
        text: "Options"
      }
      ToggleRow {
        visible: root.service.supportsConversationalAwareness
        label: "Conversation Awareness"
        checked: root.service.conversationalAwareness
        onToggled: value => root.service.setConversationalAwareness(value)
      }
      ToggleRow {
        visible: root.service.supportsOneBudANC && !root.service.isHeadset
        label: "One-Bud ANC"
        checked: root.service.oneBudANC
        onToggled: value => root.service.setOneBudANC(value)
      }
      OptionRow {
        visible: !root.service.isHeadset
        label: "Ear detection"
        detail: Model.earDetectionName(root.service.earDetectionBehavior)
        onClicked: root.service.cycleEarDetection()
      }

      Text {
        width: parent.width
        visible: root.service.actionStatus !== ""
        topPadding: 4
        text: root.service.actionStatus
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: "#FB9B89"
        font.family: Shell.Theme.fontFamily
        font.pixelSize: 12
      }
    }
  }

  Shell.PanelCloseButton {
    x: 296
    y: 2
    enabled: root.opened
    onClicked: root.closeAll()
  }

  Timer {
    id: closeCleanup
    interval: root.closeAllDuration
  }

  function open() {
    closeCleanup.stop();
    opened = true;
    service.refresh();
  }

  function closeAll() {
    if (!opened) return;
    opened = false;
    closeCleanup.restart();
  }

  component SectionLabel: Text {
    width: parent ? parent.width : 0
    height: 26
    verticalAlignment: Text.AlignBottom
    bottomPadding: 4
    textFormat: Text.PlainText
    color: Qt.alpha(Shell.Theme.colors.text, 0.5)
    font.family: Shell.Theme.fontFamily
    font.pixelSize: 11
    font.letterSpacing: 0.11
  }

  component OptionRow: Item {
    id: row
    property string label: ""
    property string detail: ""
    property bool selected: false
    signal clicked
    width: parent ? parent.width : 0
    height: 40

    Rectangle {
      anchors.fill: parent
      radius: Shell.PanelStyle.rowRadius
      color: hover.hovered ? Shell.PanelStyle.drawerRowHover : "transparent"
    }
    Text {
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      textFormat: Text.PlainText
      color: Shell.Theme.colors.text
      font.family: Shell.Theme.fontFamily
      font.weight: Font.Medium
      font.pixelSize: 14
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      visible: row.detail !== ""
      text: row.detail
      textFormat: Text.PlainText
      color: Qt.alpha(Shell.Theme.colors.text, 0.5)
      font.family: Shell.Theme.fontFamily
      font.pixelSize: 12
    }
    Image {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      visible: row.selected
      source: Qt.resolvedUrl("../assets/check.svg")
      sourceSize: Qt.size(36, 36)
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: row.clicked() }
  }

  component ToggleRow: Item {
    id: row
    property string label: ""
    property bool checked: false
    signal toggled(bool value)
    width: parent ? parent.width : 0
    height: 44

    Rectangle {
      anchors.fill: parent
      radius: Shell.PanelStyle.rowRadius
      color: hover.hovered ? Shell.PanelStyle.drawerRowHover : "transparent"
    }
    Text {
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      textFormat: Text.PlainText
      color: Shell.Theme.colors.text
      font.family: Shell.Theme.fontFamily
      font.weight: Font.Medium
      font.pixelSize: 14
    }
    Shell.Toggle {
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      trackAlpha: Shell.PanelStyle.drawerToggleAlpha
      checked: row.checked
      onToggled: value => row.toggled(value)
    }
    HoverHandler { id: hover }
  }
}
