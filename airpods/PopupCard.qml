pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

// Connection popup — layout from iOS (IMG_8017) rendered in Pond design language.
//   • Title: two-line bold name split on the possessive ("Vamsi's" / "AirPods Pro")
//   • Middle: images of each part (left pod, right pod, case — one column each)
//   • Bottom: clean battery ring per column (no icons inside) + percentage label
//   • Pond surface, shadow, blur, font, PanelCloseButton inside the card top-right
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

  readonly property int cardW: 360

  // ── Window setup ─────────────────────────────────────────────────────────
  screen: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  color: "transparent"
  implicitWidth: cardW
  implicitHeight: card.implicitHeight
  visible: showing || closeCleanup.running
  anchors { bottom: true }
  margins.bottom: 32

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "pond-airpods-popup"
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  mask: Region { item: card; radius: Shell.PanelStyle.radius }

  BackgroundEffect.blurRegion: Shell.Theme.translucent ? blurReg : null
  Region {
    id: blurReg
    item: root.showing && card.opacity > Shell.PanelStyle.blurRevealOpacity ? card : null
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

  // ── Custom battery ring — clean arc, no pod icon, charging bolt only ──────
  component BatteryRing: Item {
    id: ringRoot
    property int level: Model.LEVEL_UNKNOWN
    property bool charging: false
    readonly property bool known: level !== Model.LEVEL_UNKNOWN
    readonly property real fraction: known ? Math.max(0, Math.min(100, level)) / 100 : 0
    readonly property color arcColor: charging ? "#CBE25B"
        : known && level <= 20 ? "#FB9B89"
        : Shell.Theme.colors.text

    width: 56; height: 56

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      // Track ring (dim)
      ShapePath {
        strokeWidth: 5
        strokeColor: Qt.alpha(Shell.Theme.colors.text, 0.1)
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap
        PathAngleArc {
          centerX: 28; centerY: 28
          radiusX: 25.5; radiusY: 25.5
          startAngle: -90; sweepAngle: 360
        }
      }
      // Fill arc
      ShapePath {
        strokeWidth: 5
        strokeColor: ringRoot.arcColor
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: 28; centerY: 28
          radiusX: 25.5; radiusY: 25.5
          startAngle: -90
          sweepAngle: 360 * ringRoot.fraction
          Behavior on sweepAngle { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        }
      }
    }

    // Charging bolt — centred inside the ring
    Image {
      visible: ringRoot.charging
      anchors.centerIn: parent
      source: Qt.resolvedUrl("assets/bolt.svg")
      width: 9; height: 15
      sourceSize: Qt.size(18, 30)
      fillMode: Image.PreserveAspectFit
      smooth: true
      layer.enabled: true
      layer.effect: MultiEffect { colorization: 1; colorizationColor: ringRoot.arcColor }
    }
  }

  // ── Card ──────────────────────────────────────────────────────────────────
  Shell.Shadow {
    anchors.fill: card
    cornerRadius: Shell.PanelStyle.radius
    shadows: Shell.PanelStyle.frontShadows
    opacity: root.showing ? 1 : 0
  }

  Shell.PanelBackground {
    id: card
    width: root.cardW
    implicitHeight: contentCol.implicitHeight + 44
    height: implicitHeight
    Accessible.role: Accessible.Pane
    Accessible.name: "AirPods"

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

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      hoverEnabled: true
      onEntered: dismissTimer.stop()
      onExited:  if (root.showing) dismissTimer.restart()
    }

    // ── Close button — inside the card, top-right corner ─────────────────
    Shell.PanelCloseButton {
      anchors.top: parent.top
      anchors.topMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      z: 10
      enabled: root.showing
      onClicked: root.closeAll()
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

      // ── Two-line title ─────────────────────────────────────────────────
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: root.nameParts.subtitle !== ""
        text: root.nameParts.subtitle
        color: Qt.alpha(Shell.Theme.colors.text, 0.55)
        font.family: Shell.Theme.fontFamily
        font.pixelSize: 15
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

      Item { width: 1; height: 20 }

      // ── Three-column layout: image on top, ring below, label at bottom ──
      Row {
        width: parent.width

        // Left pod
        Column {
          visible: !root.service.isHeadset
          width: parent.width / 3
          spacing: 10

          Item {
            width: parent.width; height: 100
            Image {
              anchors.centerIn: parent
              source: Qt.resolvedUrl("assets/images/pod-left.png")
              width: 68; height: 90
              fillMode: Image.PreserveAspectFit
              smooth: true; mipmap: true
            }
          }

          BatteryRing {
            anchors.horizontalCenter: parent.horizontalCenter
            level: root.service.leftPod.level
            charging: root.service.leftPod.charging
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

          Item { width: 1; height: 8 }
        }

        // Right pod
        Column {
          visible: !root.service.isHeadset
          width: parent.width / 3
          spacing: 10

          Item {
            width: parent.width; height: 100
            Image {
              anchors.centerIn: parent
              source: Qt.resolvedUrl("assets/images/pod-right.png")
              width: 68; height: 90
              fillMode: Image.PreserveAspectFit
              smooth: true; mipmap: true
            }
          }

          BatteryRing {
            anchors.horizontalCenter: parent.horizontalCenter
            level: root.service.rightPod.level
            charging: root.service.rightPod.charging
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

          Item { width: 1; height: 8 }
        }

        // Case
        Column {
          visible: !root.service.isHeadset
          width: parent.width / 3
          spacing: 10

          Item {
            width: parent.width; height: 100
            Image {
              anchors.centerIn: parent
              source: Qt.resolvedUrl("assets/images/case.png")
              width: 96; height: 90
              fillMode: Image.PreserveAspectFit
              smooth: true; mipmap: true
            }
          }

          BatteryRing {
            anchors.horizontalCenter: parent.horizontalCenter
            level: root.service.caseBattery.level
            charging: root.service.caseBattery.charging
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

          Item { width: 1; height: 8 }
        }

        // Headset: single centred column
        Column {
          visible: root.service.isHeadset
          width: parent.width
          spacing: 10

          Item {
            width: parent.width; height: 100
            Image {
              anchors.centerIn: parent
              source: Qt.resolvedUrl("assets/images/airpods.png")
              width: 180; height: 90
              fillMode: Image.PreserveAspectFit
              smooth: true; mipmap: true
            }
          }

          BatteryRing {
            anchors.horizontalCenter: parent.horizontalCenter
            level: root.service.headsetBattery.level
            charging: root.service.headsetBattery.charging
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

          Item { width: 1; height: 8 }
        }
      }
    }
  }
}
