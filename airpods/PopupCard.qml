pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

// Connection notification card, designed to match the AirPods flyout (Panel.qml) exactly:
//   • Same PanelBackground surface, radius, border, blur
//   • Same content insets (x:20 y:20), field width (276), font styles
//   • Same Ring components for battery, same label style
//   • Same PanelCloseButton at x:296 y:2
//   • Auto-dismisses after displayDuration; hovering pauses the timer
PanelWindow {
  id: root

  readonly property var service: AirPods.State
  property bool showing: false
  property int displayDuration: 5000
  readonly property int closeAllDuration: 200

  // ── Window setup ────────────────────────────────────────────────────────
  screen: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  color: "transparent"
  // Width = card (316) + right clearance for close button that hangs 20px outside card right edge
  implicitWidth: Shell.PanelStyle.width + 60
  // Height = same formula as Panel.qml: card sits at y:22, then card fills the rest
  implicitHeight: card.implicitHeight + 22
  visible: showing || closeCleanup.running
  // Centre horizontally at the bottom of the screen
  anchors { bottom: true }
  margins.bottom: 32

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "pond-airpods-popup"
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  // Input mask: only the card and the close button are interactive
  mask: Region { item: outer }

  BackgroundEffect.blurRegion: Shell.Theme.translucent ? blurReg : null
  Region {
    id: blurReg
    item: root.showing && outer.opacity > Shell.PanelStyle.blurRevealOpacity ? card : null
    radius: Shell.PanelStyle.radius
  }

  // ── Trigger connections ──────────────────────────────────────────────────
  Connections {
    target: root.service
    function onConnectedChanged() { if (root.service.connected) root.open(); }
    function onLidStateChanged() {
      if (root.service.lidState === Model.LID_OPEN && root.service.hasAirPods) root.open();
    }
    function onHasAirPodsChanged() { if (!root.service.hasAirPods) root.closeAll(); }
  }

  Timer { id: dismissTimer; interval: root.displayDuration; repeat: false; onTriggered: root.closeAll() }
  Timer { id: closeCleanup; interval: root.closeAllDuration }

  function open() {
    closeCleanup.stop(); dismissTimer.stop();
    showing = true; dismissTimer.start();
  }
  function closeAll() {
    if (!showing) return;
    showing = false; dismissTimer.stop(); closeCleanup.restart();
  }

  // ── Outer animation container ────────────────────────────────────────────
  // Mirrors Panel.qml: opacity + scale animate on open/close
  Item {
    id: outer
    // Align to the bottom-centre of the PanelWindow, same inset structure as Panel.qml
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: Shell.PanelStyle.width + 60
    height: card.implicitHeight + 22

    opacity: root.showing ? 1 : 0
    scale: root.showing ? 1 : 0.9
    transformOrigin: Item.Bottom

    Behavior on opacity {
      NumberAnimation {
        duration: root.showing ? Shell.PanelStyle.openDuration : root.closeAllDuration
        easing.type: root.showing ? Easing.InOutCubic : Easing.Bezier
        easing.bezierCurve: [0.19, 1, 0.22, 1, 1, 1]
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: root.showing ? Shell.PanelStyle.openDuration : root.closeAllDuration
        easing.type: root.showing ? Easing.InOutCubic : Easing.Bezier
        easing.bezierCurve: [0.19, 1, 0.22, 1, 1, 1]
      }
    }

    Shell.Shadow {
      anchors.fill: card
      cornerRadius: Shell.PanelStyle.radius
      shadows: Shell.PanelStyle.frontShadows
    }

    // ── Card — same structure as Panel.qml ────────────────────────────────
    Shell.PanelBackground {
      id: card
      y: 22                                       // matches Panel.qml
      width: Shell.PanelStyle.width               // 316
      implicitHeight: content.implicitHeight + 40 // matches Panel.qml
      height: implicitHeight
      Accessible.role: Accessible.Pane
      Accessible.name: "AirPods"

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        onEntered: dismissTimer.stop()
        onExited: if (root.showing) dismissTimer.restart()
      }

      // Content column — x:20 y:20 width:fieldWidth exactly like Panel.qml
      Column {
        id: content
        x: 20
        y: 20
        width: Shell.PanelStyle.fieldWidth          // 276
        spacing: 4

        // ── Product image (the only addition vs Panel.qml) ───────────────
        Item {
          width: parent.width
          height: 108
          Image {
            anchors.centerIn: parent
            source: Qt.resolvedUrl("assets/images/airpods.png")
            height: 100
            width: 180
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }
        }

        // ── Device name — identical spec to Panel.qml ────────────────────
        Text {
          width: parent.width
          height: 28
          verticalAlignment: Text.AlignVCenter
          text: root.service.deviceName || root.service.modelName || "AirPods"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Shell.Theme.colors.text
          font.family: Shell.Theme.fontFamily
          font.weight: Font.Medium
          font.pixelSize: 17
        }

        // ── Battery row — Ring + label per part, copied verbatim from Panel.qml ──
        Row {
          width: parent.width
          height: 94
          Repeater {
            model: root.service.isHeadset
                ? [{ name: "Battery", info: root.service.headsetBattery }]
                : [{ name: "Left",   info: root.service.leftPod },
                   { name: "Right",  info: root.service.rightPod },
                   { name: "Case",   info: root.service.caseBattery }]
            delegate: Item {
              id: cell
              required property var modelData
              width: content.width / (root.service.isHeadset ? 1 : 3)
              height: 94
              AirPods.Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                size: 60
                stroke: 5.5
                iconScale: 0.54
                level: cell.modelData.info.level
                charging: cell.modelData.info.charging
                showText: false
                part: cell.modelData.name
              }
              Text {
                y: 70
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
      }
    }

    // ── Close button — same x:296 y:2 as Panel.qml ───────────────────────
    Shell.PanelCloseButton {
      x: 296
      y: 2
      enabled: root.showing
      onClicked: root.closeAll()
    }
  }
}
