import QtQuick
import QtQuick.Effects
import "." as AirPods
import ".." as Shell

// Icon naming one part of the AirPods: "Left", "Right", "Case" or "Battery" (a headset).
// Pods and case come from assets/models/<model-slug>/, see assets/models/README.md to add a model.
// The headset uses Pond's headphone.
Image {
  id: root
  property string part: "Case"
  property color tint: Qt.alpha(Shell.Theme.colors.text, 0.5)

  readonly property string defaultModel: "airpods-pro-2"
  readonly property var files: ({ Left: "pod-left.svg", Right: "pod-right.svg", Case: "case.svg" })
  // "AirPods Pro 2" becomes "airpods-pro-2", the name of that model's folder.
  readonly property string modelSlug: String(AirPods.State.modelName).toLowerCase()
      .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  // Set once a model has no folder of its own, so it shows the default model's icons instead.
  property bool useDefault: false
  onModelSlugChanged: useDefault = false
  onStatusChanged: if (status === Image.Error && !useDefault) useDefault = true

  width: 16
  height: 16
  source: part === "Battery" ? Qt.resolvedUrl("../assets/bluetooth/headphone.svg")
      : Qt.resolvedUrl("assets/models/" + (useDefault || modelSlug === "" ? defaultModel : modelSlug)
          + "/" + (files[part] || files.Case))
  sourceSize: Qt.size(width * 2, height * 2)
  fillMode: Image.PreserveAspectFit
  smooth: true
  Accessible.role: Accessible.Graphic
  Accessible.name: part === "Battery" ? "Headphones" : part
  layer.enabled: true
  layer.effect: MultiEffect { colorization: 1; colorizationColor: root.tint }
}
