pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

// Connection popup — 8017 layout in Pond design language.
// Uses Pond panel components (opacity on root Item, card at y:22,
// close button at Panel.qml convention). Fixed window size to prevent flicker.
PanelWindow {
  id: root

  readonly property var service: AirPods.State
  property bool showing: false
  property int displayDuration: 5000
  readonly property int closeAllDuration: 220
  property string displayedName: "AirPods"
  property int nameWaitTicks: 0

  // "Vamsi's AirPods Pro" → subtitle:"Vamsi's"  title:"AirPods Pro"
  // "AirPods Pro"         → subtitle:""          title:"AirPods Pro"
  readonly property var nameParts: {
    // Snapshot at reveal time; asynchronous Bluetooth updates won't swap the
    // visible title while the card is already on screen.
    var raw = root.displayedName;
    var m = raw.match(/^(.+?['’]s)\s+(.+)$/);
    return m ? { subtitle: m[1], title: m[2] } : { subtitle: "", title: raw };
  }

  // Fixed card width (wider than standard 316 flyout to fit image columns comfortably)
  readonly property int cardW: 360

  // ── Window ───────────────────────────────────────────────────────────────
  screen: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  color: "transparent"
  // Fixed dimensions — prevents reflow flicker when images load or state changes
  implicitWidth:  cardW + 60   // card + close btn overhang (40px) + left gap (20px)
  implicitHeight: 352          // 22px top clearance + 330px content card
  visible: root.showing || closeCleanup.running
  anchors { bottom: true }
  // Float above the screen edge to match the app window gutter and sidebar outer margin (10px).
  margins.bottom: Shell.Theme.sidebarOuterMargin

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "pond-airpods-popup"
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  mask: Region { item: container }

  BackgroundEffect.blurRegion: Shell.Theme.translucent ? blurReg : null
  Region {
    id: blurReg
    // Retain blur throughout the fade-out; don't drop it on the first close frame.
    item: container.opacity > 0.02 ? card : null
    radius: Shell.PanelStyle.radius
  }

  // ── Triggers ─────────────────────────────────────────────────────────────
  Connections {
    target: root.service
    function onConnectedChanged()  { if (root.service.connected)  root.requestOpen(); }
    function onLidStateChanged()   {
      if (root.service.lidState === Model.LID_OPEN && root.service.hasAirPods) root.requestOpen();
    }
    function onHasAirPodsChanged() { if (!root.service.hasAirPods) { nameWait.stop(); root.closeAll(); } }
  }

  Timer { id: dismissTimer;  interval: root.displayDuration; repeat: false; onTriggered: root.closeAll() }
  // Keep the Wayland surface alive briefly beyond the fade's last frame.
  Timer { id: closeCleanup;  interval: root.closeAllDuration + 90 }
  // Give the Bluetooth service up to 800ms to resolve the actual device name.
  // A minimum 200ms wait avoids a blank -> generic -> custom title flash.
  Timer {
    id: nameWait
    interval: 100
    repeat: true
    onTriggered: {
      root.nameWaitTicks++;
      if ((root.service.deviceName && root.nameWaitTicks >= 2) || root.nameWaitTicks >= 8) {
        stop();
        root.open();
      }
    }
  }

  function requestOpen() {
    if (showing) { dismissTimer.restart(); return; }
    nameWaitTicks = 0;
    nameWait.restart();
  }

  function open() {
    closeCleanup.stop(); dismissTimer.stop();
    displayedName = service.deviceName || service.modelName || "AirPods";
    showing = true; dismissTimer.start();
  }
  function closeAll() {
    if (!showing) return;
    showing = false; dismissTimer.stop(); closeCleanup.restart();
  }

  // ── Popup ring component (8017 style: clean arc, bolt centered, no pod icon) ──
  // Separate from AirPods.Ring which always draws PartIcon when part is set.
  component PopupRing: Item {
    id: pr
    property int  level:    Model.LEVEL_UNKNOWN
    property bool charging: false

    readonly property bool  known:    level !== Model.LEVEL_UNKNOWN
    readonly property real  fraction: known ? Math.max(0, Math.min(100, level)) / 100 : 0
    readonly property color arcColor: charging        ? "#CBE25B"
                                    : (known && level <= 20) ? "#FB9B89"
                                    : Shell.Theme.colors.text
    width: 56; height: 56

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      // Track (dim background ring)
      ShapePath {
        strokeWidth:  5
        strokeColor:  Qt.alpha(Shell.Theme.colors.text, 0.12)
        fillColor:    "transparent"
        capStyle:     ShapePath.FlatCap
        PathAngleArc {
          centerX: 28; centerY: 28
          radiusX: 25.5; radiusY: 25.5
          startAngle: -90; sweepAngle: 360
        }
      }
      // Filled arc
      ShapePath {
        strokeWidth: 5
        strokeColor: pr.arcColor
        fillColor:   "transparent"
        capStyle:    ShapePath.RoundCap
        PathAngleArc {
          centerX: 28; centerY: 28
          radiusX: 25.5; radiusY: 25.5
          startAngle: -90
          sweepAngle: 360 * pr.fraction
          Behavior on sweepAngle {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
          }
        }
      }
    }

    // Charging bolt — centered inside the ring (like 8017)
    Image {
      visible:          pr.charging
      anchors.centerIn: parent
      source:           Qt.resolvedUrl("assets/bolt.svg")
      width: 9; height: 15
      sourceSize:   Qt.size(18, 30)
      fillMode:     Image.PreserveAspectFit
      smooth:       true
      layer.enabled: true
      layer.effect: MultiEffect {
        colorization:       1
        colorizationColor:  pr.arcColor
      }
    }
  }

  // ── Battery column (image + ring + badge label) — one per part ────────────
  component BatteryCol: Column {
    id: bc
    property string part:     "Left"
    property int    level:    Model.LEVEL_UNKNOWN
    property bool   charging: false
    property string imgSource: ""
    property real   imgW: 70
    property real   imgH: 90

    width:   parent ? parent.width / (root.service.isHeadset ? 1 : 3) : 0
    spacing: 0

    // Stable image slot: asset decoding never changes column geometry.
    Item {
      width: parent.width; height: 116
      Image {
        anchors.centerIn: parent
        // Pull the earbuds toward each other without affecting column/ring layout.
        anchors.horizontalCenterOffset: bc.part === "Left" ? 10 : (bc.part === "Right" ? -10 : 0)
        source:    bc.imgSource
        width:     bc.imgW; height: bc.imgH
        fillMode:  Image.PreserveAspectFit
        smooth:    true; mipmap: true
      }
    }

    // Ring — consistent gap for all three products
    Item { width: 1; height: 8 }
    PopupRing {
      anchors.horizontalCenter: parent.horizontalCenter
      level:    bc.level
      charging: bc.charging
    }

    // iPhone-style L/R white circular badges; keep Pond's case glyph.
    Item { width: 1; height: 6 }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      Rectangle {
        visible: bc.part === "Left" || bc.part === "Right"
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14
        radius: width / 2
        color: Shell.Theme.colors.text
        Text {
          anchors.fill: parent
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: bc.part === "Left" ? "L" : "R"
          color: Shell.PanelStyle.panelSurface
          font.family: Shell.Theme.fontFamily
          font.weight: Font.Bold
          font.pixelSize: 9
          textFormat: Text.PlainText
        }
      }
      AirPods.PartIcon {
        visible: bc.part !== "Left" && bc.part !== "Right"
        anchors.verticalCenter: parent.verticalCenter
        width: 17; height: 17
        part: bc.part
        tint: Shell.Theme.colors.text
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Model.levelText(bc.level)
        color: Shell.Theme.colors.text
        font.family: Shell.Theme.fontFamily
        font.weight: Font.Medium
        font.pixelSize: 13
        textFormat: Text.PlainText
      }
    }

    Item { width: 1; height: 20 }
  }

  // ── Container — fixed geometry; fade without scaling the contents ─
  Item {
    id: container
    // bottom-anchor so card sits flush at bottom of window; gap above is transparent
    anchors.bottom:            parent.bottom
    anchors.horizontalCenter:  parent.horizontalCenter
    width:  root.cardW + 60
    height: root.implicitHeight

    opacity: root.showing ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration:              root.showing ? Shell.PanelStyle.openDuration : root.closeAllDuration
        easing.type:           Easing.OutCubic
      }
    }

    Shell.Shadow {
      anchors.fill:  card
      cornerRadius:  Shell.PanelStyle.radius
      shadows:       Shell.PanelStyle.frontShadows
    }

    // ── Card (PanelBackground at y:22, same as Panel.qml) ─────────────────
    Shell.PanelBackground {
      id:   card
      y:    22
      width: root.cardW
      // Fixed 330px card: content fits without excess empty space
      height: container.height - 22
      Accessible.role: Accessible.Pane
      Accessible.name: "AirPods"

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        onEntered: dismissTimer.stop()
        onExited:  if (root.showing) dismissTimer.restart()
      }

      Column {
        id: content
        x: 20; y: 20
        width: root.cardW - 40
        spacing: 0

        // Fixed header height: delayed Bluetooth name/font updates cannot
        // push the product images and battery rings down after opening.
        Item {
          width: parent.width
          height: 58
          Text {
            anchors.top: parent.top
            width: parent.width
            height: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: root.nameParts.subtitle !== ""
            text: root.nameParts.subtitle
            color: Qt.alpha(Shell.Theme.colors.text, 0.55)
            font.family: Shell.Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
            textFormat: Text.PlainText
          }
          Text {
            anchors.top: parent.top
            anchors.topMargin: 20
            width: parent.width
            height: 38
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.nameParts.title
            color: Shell.Theme.colors.text
            font.family: Shell.Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.Bold
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Item { width: 1; height: 16 }

        // ── Battery columns: image → ring → badge+label ─────────────────
        Row {
          width: parent.width

          // AirPods (non-headset)
          BatteryCol {
            visible:   !root.service.isHeadset
            part:      "Left"
            level:     root.service.leftPod.level
            charging:  root.service.leftPod.charging
            imgSource: Qt.resolvedUrl("assets/images/pod-left.png")
            imgW: 82; imgH: 106
          }
          BatteryCol {
            visible:   !root.service.isHeadset
            part:      "Right"
            level:     root.service.rightPod.level
            charging:  root.service.rightPod.charging
            imgSource: Qt.resolvedUrl("assets/images/pod-right.png")
            imgW: 82; imgH: 106
          }
          BatteryCol {
            visible:   !root.service.isHeadset
            part:      "Case"
            level:     root.service.caseBattery.level
            charging:  root.service.caseBattery.charging
            imgSource: Qt.resolvedUrl("assets/images/case.png")
            imgW: 120; imgH: 112
          }

          // Headset (single column, full width)
          BatteryCol {
            visible:   root.service.isHeadset
            part:      "Battery"
            level:     root.service.headsetBattery.level
            charging:  root.service.headsetBattery.charging
            imgSource: Qt.resolvedUrl("assets/images/airpods.png")
            imgW: 180; imgH: 90
          }
        }
      }
    }

    // ── Close button — same x/y convention as Panel.qml ───────────────────
    // Panel.qml: card.width=316, button at x:296 → 316-20=296 (20px from card right)
    // Our card: width=360 → x: 360-20=340
    Shell.PanelCloseButton {
      x: root.cardW - 20
      y: 2
      enabled: root.showing
      onClicked: root.closeAll()
    }
  }
}
