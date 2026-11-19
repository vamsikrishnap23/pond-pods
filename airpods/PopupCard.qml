pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

// Connection popup — layout from iOS (IMG_8017) rendered in Pond design language.
//   • Title: two-line bold name split on the possessive ("Vamsi's" / "AirPods Pro")
//   • Middle: images of each part (pod-left + pod-right share one column, case gets one column)
//   • Bottom: Ring per part beneath each image, with levelText label
//   • Pond surface, shadow, blur, font, close button — no hardcoded colours
PanelWindow {
  id: root

  readonly property var service: AirPods.State
  property bool showing: false
  property int displayDuration: 5000
  readonly property int closeAllDuration: 200

  // Split device name on the possessive apostrophe, same as iOS.
  // "Vamsi's AirPods Pro"  → subtitle="Vamsi's"  title="AirPods Pro"
  // "AirPods Pro"          → subtitle=""          title="AirPods Pro"
  readonly property var nameParts: {
    var raw = service.deviceName || service.modelName || "AirPods";
    var m = raw.match(/^(.+?[''`']s)\s+(.+)$/);
    return m ? { subtitle: m[1], title: m[2] } : { subtitle: "", title: raw };
  }

  // Card width: wider than the standard flyout to hold image + ring columns side by side.
  readonly property int cardW: 360
  // Extra right clearance so the PanelCloseButton (40×40, overhangs 20px outside card right) is clickable.
  readonly property int windowW: cardW + 50

  // ── Window setup ─────────────────────────────────────────────────────────
  screen: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  color: "transparent"
  implicitWidth: windowW
  implicitHeight: card.implicitHeight + 22    // card sits at y:22, same as Panel.qml
  visible: showing || closeCleanup.running
  anchors { bottom: true }
  margins.bottom: 32

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "pond-airpods-popup"
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  mask: Region { item: outer }

  BackgroundEffect.blurRegion: Shell.Theme.translucent ? blurReg : null
  Region {
    id: blurReg
    item: root.showing && outer.opacity > Shell.PanelStyle.blurRevealOpacity ? card : null
    radius: Shell.PanelStyle.radius
  }

  // ── Triggers ─────────────────────────────────────────────────────────────
  Connections {
    target: root.service
    function onConnectedChanged()  { if (root.service.connected) root.open(); }
    function onLidStateChanged()   {
      if (root.service.lidState === Model.LID_OPEN && root.service.hasAirPods) root.open();
    }
    function onHasAirPodsChanged() { if (!root.service.hasAirPods) root.closeAll(); }
  }

  Timer { id: dismissTimer; interval: root.displayDuration; repeat: false; onTriggered: root.closeAll() }
  Timer { id: closeCleanup; interval: root.closeAllDuration }

  function open()     { closeCleanup.stop(); dismissTimer.stop(); showing = true;  dismissTimer.start(); }
  function closeAll() { if (!showing) return; showing = false; dismissTimer.stop(); closeCleanup.restart(); }

  // ── Animation container — same open/close motion as Panel.qml ────────────
  Item {
    id: outer
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.windowW
    height: card.implicitHeight + 22

    opacity: root.showing ? 1 : 0
    scale:   root.showing ? 1 : 0.9
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

    // ── Card ─────────────────────────────────────────────────────────────────
    Shell.PanelBackground {
      id: card
      y: 22
      width: root.cardW
      implicitHeight: contentCol.implicitHeight + 44
      height: implicitHeight
      Accessible.role: Accessible.Pane
      Accessible.name: "AirPods"

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        onEntered: dismissTimer.stop()
        onExited:  if (root.showing) dismissTimer.restart()
      }

      // ── Content ───────────────────────────────────────────────────────────
      Column {
        id: contentCol
        anchors {
          top: parent.top; topMargin: 24
          left: parent.left; leftMargin: 20
          right: parent.right; rightMargin: 20
        }
        spacing: 0

        // ── Two-line title (iOS style: subtitle smaller, title bold+large) ──
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          visible: root.nameParts.subtitle !== ""
          text: root.nameParts.subtitle
          color: Qt.alpha(Shell.Theme.colors.text, 0.55)
          font.family: Shell.Theme.fontFamily
          font.pixelSize: 17
          font.weight: Font.Medium
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          topPadding: root.nameParts.subtitle !== "" ? 2 : 0
          horizontalAlignment: Text.AlignHCenter
          text: root.nameParts.title
          color: Shell.Theme.colors.text
          font.family: Shell.Theme.fontFamily
          font.pixelSize: 26
          font.weight: Font.Bold
          textFormat: Text.PlainText
          elide: Text.ElideRight
        }

        // ── Spacer ────────────────────────────────────────────────────────
        Item { width: 1; height: 20 }

        // ── Image + Ring columns ──────────────────────────────────────────
        // Three-column layout matching 8017:
        //   col 0 = Left pod image + ring + label
        //   col 1 = Right pod image + ring + label
        //   col 2 = Case image (taller) + ring + label
        //
        // For headsets: single centred column with airpods.png
        Row {
          width: parent.width
          height: implicitHeight

          // ── Left pod column ───────────────────────────────────────────────
          Column {
            visible: !root.service.isHeadset
            width: parent.width / 3
            spacing: 8

            Item {
              width: parent.width; height: 110
              Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl("assets/images/pod-left.png")
                width: 70; height: 90
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
              }
            }

            AirPods.Ring {
              anchors.horizontalCenter: parent.horizontalCenter
              size: 56; stroke: 5; iconScale: 0.52
              level: root.service.leftPod.level
              charging: root.service.leftPod.charging
              showText: false
              part: "Left"
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: Model.levelText(root.service.leftPod.level)
              color: Shell.Theme.colors.text
              font.family: Shell.Theme.fontFamily
              font.weight: Font.Medium
              font.pixelSize: 13
              textFormat: Text.PlainText
            }

            Item { width: 1; height: 4 }
          }

          // ── Right pod column ──────────────────────────────────────────────
          Column {
            visible: !root.service.isHeadset
            width: parent.width / 3
            spacing: 8

            Item {
              width: parent.width; height: 110
              Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl("assets/images/pod-right.png")
                width: 70; height: 90
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
              }
            }

            AirPods.Ring {
              anchors.horizontalCenter: parent.horizontalCenter
              size: 56; stroke: 5; iconScale: 0.52
              level: root.service.rightPod.level
              charging: root.service.rightPod.charging
              showText: false
              part: "Right"
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: Model.levelText(root.service.rightPod.level)
              color: Shell.Theme.colors.text
              font.family: Shell.Theme.fontFamily
              font.weight: Font.Medium
              font.pixelSize: 13
              textFormat: Text.PlainText
            }

            Item { width: 1; height: 4 }
          }

          // ── Case column ───────────────────────────────────────────────────
          Column {
            visible: !root.service.isHeadset
            width: parent.width / 3
            spacing: 8

            Item {
              width: parent.width; height: 110
              Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl("assets/images/case.png")
                width: 100; height: 90
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
              }
            }

            AirPods.Ring {
              anchors.horizontalCenter: parent.horizontalCenter
              size: 56; stroke: 5; iconScale: 0.52
              level: root.service.caseBattery.level
              charging: root.service.caseBattery.charging
              showText: false
              part: "Case"
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: Model.levelText(root.service.caseBattery.level)
              color: Shell.Theme.colors.text
              font.family: Shell.Theme.fontFamily
              font.weight: Font.Medium
              font.pixelSize: 13
              textFormat: Text.PlainText
            }

            Item { width: 1; height: 4 }
          }

          // ── Headset: single centred column ────────────────────────────────
          Column {
            visible: root.service.isHeadset
            width: parent.width
            spacing: 8

            Item {
              width: parent.width; height: 110
              Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl("assets/images/airpods.png")
                width: 180; height: 100
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
              }
            }

            AirPods.Ring {
              anchors.horizontalCenter: parent.horizontalCenter
              size: 56; stroke: 5; iconScale: 0.52
              level: root.service.headsetBattery.level
              charging: root.service.headsetBattery.charging
              showText: false
              part: "Battery"
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: Model.levelText(root.service.headsetBattery.level)
              color: Shell.Theme.colors.text
              font.family: Shell.Theme.fontFamily
              font.weight: Font.Medium
              font.pixelSize: 13
              textFormat: Text.PlainText
            }

            Item { width: 1; height: 4 }
          }
        }
      }
    }

    // ── Close button — Pond PanelCloseButton, top-right of card ──────────
    // Position: right edge of card minus 20px (button is 40×40, overhangs 20px outside)
    // y: 2 puts it 2px above the card top (y:22) — same convention as Panel.qml
    Shell.PanelCloseButton {
      x: card.width - 20
      y: 2
      enabled: root.showing
      onClicked: root.closeAll()
    }
  }
}
