import QtQuick
import QtQuick.Shapes
import ".." as Shell
import "Model.js" as Model

// Circular battery gauge shared by the sidebar card and the flyout.
Item {
  id: ring
  property int size: 38
  property int level: Model.LEVEL_UNKNOWN
  property bool charging: false
  property bool showText: true
  // Names a part of the AirPods to draw as an icon in the centre, instead of the percentage.
  property string part: ""
  property real stroke: 4
  readonly property bool known: level !== Model.LEVEL_UNKNOWN
  readonly property real fraction: known ? Math.max(0, Math.min(100, level)) / 100 : 0
  readonly property color tint: charging ? "#CBE25B"
      : known && level <= 20 ? "#FB9B89" : Shell.Theme.colors.text
  width: size
  height: size

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: ring.stroke
      strokeColor: Qt.alpha(Shell.Theme.colors.text, 0.1)
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.size / 2; centerY: ring.size / 2
        radiusX: (ring.size - ring.stroke) / 2; radiusY: radiusX
        startAngle: 0; sweepAngle: 360
      }
    }
    ShapePath {
      strokeWidth: ring.stroke
      strokeColor: ring.tint
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.size / 2; centerY: ring.size / 2
        radiusX: (ring.size - ring.stroke) / 2; radiusY: radiusX
        startAngle: -90
        sweepAngle: 359.9 * ring.fraction
      }
    }
  }
  Text {
    anchors.centerIn: parent
    visible: ring.showText
    text: ring.known ? ring.level : "–"
    color: Shell.Theme.colors.text
    font.family: Shell.Theme.fontFamily
    font.weight: Font.Medium
    font.pixelSize: Math.round(ring.size * 0.32)
  }
  PartIcon {
    anchors.centerIn: parent
    visible: ring.part !== ""
    width: Math.round(ring.size * 0.44)
    height: width
    part: ring.part === "" ? "Case" : ring.part
    tint: Shell.Theme.colors.text
  }
}
