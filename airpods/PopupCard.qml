
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as AirPods
import ".." as Shell
import "Model.js" as Model

PanelWindow {
    id: root

    readonly property var service: AirPods.State

    property bool showing: false
    property bool persistent: false
    property bool testMode: false

    property int displayDuration: 5000
    readonly property int closeAllDuration: 220

    property string displayedName: "AirPods"
    property int nameWaitTicks: 0

    readonly property int cardW: 360

    readonly property var nameParts: {
        var raw = root.displayedName;
        var m = raw.match(/^(.+?['’]s)\s+(.+)$/);

        return m
            ? { subtitle: m[1], title: m[2] }
            : { subtitle: "", title: raw };
    }

    // Window geometry
    screen: Quickshell.screens && Quickshell.screens.length > 0
        ? Quickshell.screens[0]
        : null

    color: "transparent"

    implicitWidth: cardW + 60
    implicitHeight: 368

    // Keep the Wayland surface mapped.
    visible: true

    anchors {
        bottom: true
    }

    margins.bottom: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pond-notification-airpods"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Includes both the card and floating close button.
    // An invisible popup must not intercept mouse input.
    mask: Region {
        item: root.showing ? container : null
    }

    // Pond-style background blur.
    BackgroundEffect.blurRegion:
        Shell.Theme.translucent ? blurReg : null

    Region {
        id: blurReg

        item: root.showing && container.opacity > Shell.PanelStyle.blurRevealOpacity
            ? card
            : null

        radius: Shell.PanelStyle.radius
    }

    // Connection events
    Connections {
        target: root.service

        function onConnectedChanged() {
            if (root.service.connected)
                root.requestOpen();
        }

        function onLidStateChanged() {
            if (root.service.lidState === Model.LID_OPEN
                    && root.service.hasAirPods)
                root.requestOpen();
        }

        function onHasAirPodsChanged() {
            if (!root.service.hasAirPods) {
                nameWait.stop();
                root.closeAll();
            }
        }

        function onRequestPopup(test) {
            nameWait.stop();

            root.testMode = test;

            if (test)
                root.displayedName = "Vamsi's AirPods Pro";

            root.persistent = true;
            root.open();

            dismissTimer.stop();
        }

        function onRequestClose() {
            nameWait.stop();
            root.closeAll();
        }

        function onRequestToggle() {
            if (root.showing) {
                root.closeAll();
            } else {
                nameWait.stop();

                root.persistent = true;
                root.open();

                dismissTimer.stop();
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: root.displayDuration
        repeat: false

        onTriggered: root.closeAll()
    }

    Timer {
        id: closeCleanup
        interval: root.closeAllDuration + 90
        repeat: false
    }

    // Wait briefly for the Bluetooth device name.
    Timer {
        id: nameWait

        interval: 100
        repeat: true

        onTriggered: {
            root.nameWaitTicks++;

            if ((root.service.deviceName
                    && root.nameWaitTicks >= 2)
                    || root.nameWaitTicks >= 8) {
                stop();
                root.open();
            }
        }
    }

    function requestOpen() {
        if (showing) {
            if (!persistent)
                dismissTimer.restart();

            return;
        }

        nameWaitTicks = 0;
        nameWait.restart();
    }

    function open() {
        closeCleanup.stop();
        dismissTimer.stop();

        if (!testMode) {
            displayedName = service.deviceName
                || service.modelName
                || "AirPods";
        }

        showing = true;

        if (!persistent)
            dismissTimer.start();
    }

    function closeAll() {
        if (!showing)
            return;

        showing = false;
        persistent = false;
        testMode = false;

        nameWait.stop();
        dismissTimer.stop();
        closeCleanup.restart();
    }

    // Battery ring
    component PopupRing: Item {
        id: pr

        property int level: Model.LEVEL_UNKNOWN
        property bool charging: false

        readonly property bool known:
            level !== Model.LEVEL_UNKNOWN

        readonly property real fraction:
            known
                ? Math.max(0, Math.min(100, level)) / 100
                : 0

        readonly property color arcColor:
            charging
                ? "#CBE25B"
                : (known && level <= 20)
                    ? "#FB9B89"
                    : Shell.Theme.colors.text

        width: 56
        height: 56

        Shape {
            anchors.fill: parent

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 5
                strokeColor:
                    Qt.alpha(Shell.Theme.colors.text, 0.12)

                fillColor: "transparent"
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: 28
                    centerY: 28

                    radiusX: 25.5
                    radiusY: 25.5

                    startAngle: -90
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeWidth: 5
                strokeColor: pr.arcColor

                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 28
                    centerY: 28

                    radiusX: 25.5
                    radiusY: 25.5

                    startAngle: -90
                    sweepAngle: 360 * pr.fraction

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Image {
            visible: pr.charging
            anchors.centerIn: parent

            source: Qt.resolvedUrl("assets/bolt.svg")

            width: 9
            height: 18

            sourceSize: Qt.size(18, 36)

            fillMode: Image.PreserveAspectFit
            smooth: true

            layer.enabled: true

            layer.effect: MultiEffect {
                colorization: 1
                colorizationColor: pr.arcColor
            }
        }
    }

    // Product image, battery ring and percentage
    component BatteryCol: Column {
        id: bc

        property string part: "Left"

        property int level: Model.LEVEL_UNKNOWN
        property bool charging: false

        property string imgSource: ""

        property real imgW: 70
        property real imgH: 90

        width: parent
            ? parent.width / (root.service.isHeadset ? 1 : 3)
            : 0

        spacing: 0

        // Fixed image container
        Item {
            width: parent.width
            height: 116

            Image {
                anchors.centerIn: parent

                anchors.horizontalCenterOffset:
                    bc.part === "Left"
                        ? 10
                        : bc.part === "Right"
                            ? -10
                            : 0

                source: bc.imgSource

                width: bc.imgW
                height: bc.imgH

                fillMode: Image.PreserveAspectFit

                smooth: true
                mipmap: true
            }
        }

        Item {
            width: 1
            height: 8
        }

        PopupRing {
            anchors.horizontalCenter: parent.horizontalCenter

            level: bc.level
            charging: bc.charging
        }

        Item {
            width: 1
            height: 6
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            // iOS-style L/R badge
            Rectangle {
                visible:
                    bc.part === "Left" || bc.part === "Right"

                anchors.verticalCenter: parent.verticalCenter

                width: 14
                height: 14
                radius: 7

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
                visible:
                    bc.part !== "Left" && bc.part !== "Right"

                anchors.verticalCenter: parent.verticalCenter

                width: 17
                height: 17

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

        Item {
            width: 1
            height: 20
        }
    }

    // Main popup container
    Item {
        id: container

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.cardW + 60
        height: root.implicitHeight

        opacity: root.showing ? 1 : 0
        onOpacityChanged: blurReg.changed()

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing
                    ? Shell.PanelStyle.openDuration
                    : root.closeAllDuration

                easing.type: Easing.OutCubic
            }
        }

        // Pond flyout shadow, softened for this card size.
        Shell.Shadow {
            anchors.fill: card

            cornerRadius: Shell.PanelStyle.radius
            shadows: Shell.PanelStyle.frontShadows

            opacity: 0.65
        }

        Shell.PanelBackground {
            id: card

            x: 24
            y: 22

            width: root.cardW
            height: 330

            Accessible.role: Accessible.Pane
            Accessible.name: "AirPods"

            MouseArea {
                anchors.fill: parent

                acceptedButtons:
                    Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                hoverEnabled: true

                onEntered: dismissTimer.stop()

                onExited: {
                    if (root.showing && !root.persistent)
                        dismissTimer.restart();
                }
            }

            Column {
                id: content

                x: 20
                y: 20

                width: root.cardW - 40
                spacing: 0

                // Fixed-height header prevents delayed-name reflow.
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

                        color: Qt.alpha(
                            Shell.Theme.colors.text, 0.55
                        )

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

                Item {
                    width: 1
                    height: 16
                }

                Row {
                    width: parent.width

                    BatteryCol {
                        visible: !root.service.isHeadset

                        part: "Left"

                        level: root.testMode
                            ? 97
                            : root.service.leftPod.level

                        charging: root.testMode
                            ? true
                            : root.service.leftPod.charging

                        imgSource:
                            Qt.resolvedUrl("assets/images/pod-left.png")

                        imgW: 82
                        imgH: 106
                    }

                    BatteryCol {
                        visible: !root.service.isHeadset

                        part: "Right"

                        level: root.testMode
                            ? 98
                            : root.service.rightPod.level

                        charging: root.testMode
                            ? true
                            : root.service.rightPod.charging

                        imgSource:
                            Qt.resolvedUrl("assets/images/pod-right.png")

                        imgW: 82
                        imgH: 106
                    }

                    BatteryCol {
                        visible: !root.service.isHeadset

                        part: "Case"

                        level: root.testMode
                            ? 88
                            : root.service.caseBattery.level

                        charging: root.testMode
                            ? false
                            : root.service.caseBattery.charging

                        imgSource:
                            Qt.resolvedUrl("assets/images/case.png")

                        imgW: 120
                        imgH: 112
                    }

                    BatteryCol {
                        visible: root.service.isHeadset

                        part: "Battery"

                        level: root.service.headsetBattery.level
                        charging: root.service.headsetBattery.charging

                        imgSource:
                            Qt.resolvedUrl("assets/images/airpods.png")

                        imgW: 180
                        imgH: 90
                    }
                }
            }
        }

        // Floating close button
        Shell.PanelCloseButton {
            x: card.x + root.cardW - 20
            y: 2

            enabled: root.showing

            onClicked: root.closeAll()
        }
    }
}
