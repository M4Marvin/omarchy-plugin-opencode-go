import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "local.opencode-go"
  ipcTarget: "local.opencode-go"

  property double nowMs: Date.now()
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.35)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The window the `barWindow` setting puts in the bar label, plus the weekly
  // window that drives the alarm state — weekly is the budget that actually
  // bites, so it stays the alarm regardless of what the label shows.
  readonly property var barPick: Model.barWindow(service.account, service.barWindow, nowMs)
  readonly property bool alarming: Model.behindPace(
    Model.normalizeWindow(service.account ? service.account.weekly : null, "weekly", nowMs), nowMs)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    nowMs = Date.now()
    service.refresh()
  }

  function barLabel() {
    if (!barPick) return "—"
    return barPick.spec.tag + " · " + Model.percent(barPick.window.percent)
  }

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    if (!service.lastUpdated || (Date.now() - service.lastUpdated.getTime()) > service.refreshIntervalSec * 1000) root.refresh()
    Qt.callLater(function() { catcher.forceActiveFocus() })
  }

  Service {
    id: service
    settings: root.settings
    moduleName: root.moduleName
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.nowMs = Date.now()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    fixedWidth: vertical ? -1 : content.implicitWidth + Style.space(16)
    tooltipText: root.barPick
      ? "OpenCode Go · " + root.barPick.spec.label + " " + Model.percent(root.barPick.window.percent)
        + " used · " + Model.resetText(root.barPick.window, root.nowMs) + " · click for details"
      : "OpenCode Go usage · click for details"
    active: root.alarming
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(5)

      Image {
        visible: !(bar ? bar.vertical : false)
        width: Style.space(13)
        height: width
        anchors.verticalCenter: parent.verticalCenter
        source: Qt.resolvedUrl("opencode-go.svg")
        sourceSize: Qt.size(26, 26)
        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1
          colorizationColor: root.alarming ? root.urgent : root.foreground
        }
      }

      Text {
        visible: !(bar ? bar.vertical : false)
        anchors.verticalCenter: parent.verticalCenter
        text: root.barLabel()
        color: root.alarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        visible: bar ? bar.vertical : false
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        text: root.barPick ? Model.percent(root.barPick.window.percent) : "—"
        color: root.alarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: catcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: catcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: body.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scroll.contentItem
          property: "interactive"
          value: body.implicitHeight > scroll.height
        }

        Column {
          id: body
          width: scroll.availableWidth
          spacing: Style.space(12)

          Text {
            width: parent.width
            text: "Updated " + (service.lastUpdated ? Qt.formatTime(service.lastUpdated, "HH:mm:ss") : "never") + " · " + (service.refreshing ? "Refreshing…" : "R to refresh")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelHero {
            width: parent.width
            title: "OpenCode Go"
            meta: service.account ? service.account.label : "Go"
            detail: root.barPick ? root.barPick.spec.tag + " " + Model.percent(root.barPick.window.percent) : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Image {
                width: Style.font.display
                height: width
                source: Qt.resolvedUrl("opencode-go.svg")
                sourceSize: Qt.size(48, 48)
                layer.enabled: true
                layer.effect: MultiEffect {
                  colorization: 1
                  colorizationColor: root.alarming ? root.urgent : root.foreground
                }
              }
            }
          }

          Text {
            visible: service.lastError !== ""
            width: parent.width
            text: service.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            visible: service.refreshing && !service.account
            width: parent.width
            text: "Loading usage…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          PanelSectionHeader {
            text: "BAR PERCENTAGE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            text: "Which limit window the bar label reports."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: [
                { value: "5-hour", label: "5h" },
                { value: "Weekly", label: "Weekly" },
                { value: "Monthly", label: "Monthly" },
                { value: "Highest", label: "Highest" }
              ]

              delegate: BorderSurface {
                required property var modelData
                readonly property bool active: service.barWindow === modelData.value
                readonly property bool _hot: pickerHover.hovered
                readonly property var _spec: Border.controlSpec(
                  active ? "selected" : (_hot ? "hover-cursor" : "normal"), root.foreground, Color.accent)

                width: Math.max(Style.space(52), pickerLabel.implicitWidth + Style.space(20))
                height: Style.spacing.controlHeight
                radius: Style.cornerRadius
                color: Style.controlFill(active, _hot, root.foreground, Color.accent)
                borderSpec: _spec

                HoverHandler { id: pickerHover }

                Text {
                  id: pickerLabel
                  anchors.centerIn: parent
                  text: modelData.label
                  color: active
                    ? Style.selectedStateColor(root.foreground, Color.accent)
                    : (_hot ? Style.hoverStateColor(root.foreground, Color.accent) : root.foreground)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: active
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  enabled: !service.writingSetting
                  onClicked: service.setBarWindow(modelData.value)
                }
              }
            }
          }

          Text {
            visible: service.writeError !== ""
            width: parent.width
            text: service.writeError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          PanelSectionHeader {
            text: "LIMIT WINDOWS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          AccountCard {
            width: body.width
            account: service.account
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          Item {
            width: parent.width
            implicitHeight: Math.max(usageHeader.implicitHeight, usageValue.implicitHeight)

            PanelSectionHeader {
              id: usageHeader
              text: "RECENT USAGE"
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: usageValue
              visible: service.recentDays.length > 0
              text: Model.tokenCount(Model.recentTotal(service.recentDays)) + " tokens · "
                + Model.money(Model.recentCostTotal(service.recentDays))
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            visible: service.recentDays.length === 0 && !service.refreshing
            width: parent.width
            text: "No OpenCode Go messages in the last seven days."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Row {
            id: chart
            width: parent.width
            spacing: Style.space(4)
            readonly property real columnWidth: (width - spacing * Math.max(0, service.recentDays.length - 1))
              / Math.max(1, service.recentDays.length)

            Repeater {
              model: service.recentDays

              delegate: Column {
                id: day
                required property var modelData
                readonly property bool today: Model.isToday(modelData, root.nowMs)
                readonly property real barWidth: Math.min(Style.space(9), chart.columnWidth)
                width: chart.columnWidth
                spacing: Style.space(3)

                Text {
                  width: parent.width
                  text: Model.tokenCount(day.modelData.tokens)
                  color: day.today ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                }

                Item {
                  id: plot
                  width: parent.width
                  height: Style.space(38)

                  // Baseline, so an idle day still reads as a day rather than
                  // as a gap in the chart.
                  Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: day.barWidth
                    height: Style.spacing.hairline
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
                  }

                  Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: day.barWidth
                    // Floor at a visible sliver so a low-but-nonzero day is not
                    // rounded away next to a heavy one.
                    height: Model.dayTokens(day.modelData) <= 0 ? 0 : Math.max(Style.space(3),
                      plot.height * Model.dayTokens(day.modelData) / Math.max(1, Model.recentPeak(service.recentDays)))
                    radius: Style.space(2)
                    color: root.foreground
                    opacity: day.today ? 1 : 0.5

                    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                  }
                }

                Text {
                  width: parent.width
                  text: Model.dayLabel(day.modelData.date)
                  color: day.today ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: day.today
                  horizontalAlignment: Text.AlignHCenter
                }
              }
            }
          }
        }
      }
    }
  }

  component AccountCard: Column {
    id: card
    required property var account
    spacing: Style.space(12)

    Repeater {
      model: Model.WINDOWS

      delegate: Column {
        id: windowRow
        required property var modelData
        width: card.width
        spacing: Style.space(4)
        readonly property var w: Model.normalizeWindow(card.account ? card.account[modelData.key] : null, modelData.key, root.nowMs)
        readonly property bool behind: Model.behindPace(windowRow.w, root.nowMs)

        RowLayout {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: modelData.label
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.6
          }

          Item { Layout.fillWidth: true }

          Text {
            text: windowRow.w ? Model.percent(windowRow.w.percent) : "—"
            color: windowRow.behind ? root.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            visible: !!windowRow.w
            text: "of $" + (windowRow.w && windowRow.w.limitDollars ? windowRow.w.limitDollars : modelData.dollars)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Padded so the pace marker can overhang the track without clipping.
        Item {
          width: parent.width
          height: Style.space(11)

          Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.space(5)
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

            Rectangle {
              width: parent.width * (windowRow.w ? windowRow.w.percent : 0)
              height: parent.height
              radius: parent.radius
              color: windowRow.behind ? root.urgent : root.foreground

              Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 60 } }
            }
          }

          // Where an even spender would be right now: left of the marker is
          // ahead of pace, right of it is behind.
          Rectangle {
            readonly property real position: windowRow.w ? Model.expectedUsed(windowRow.w, root.nowMs) : 0
            visible: !!windowRow.w && windowRow.w.resetMs > 0 && position > 0.01 && position < 0.99
            x: Math.round(track.width * position) - width / 2
            width: Math.max(1, Style.space(2))
            height: parent.height
            radius: width / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)

            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
          }
        }

        RowLayout {
          width: parent.width
          visible: !!windowRow.w
          spacing: Style.space(6)

          Text {
            Layout.fillWidth: true
            text: windowRow.w ? Model.resetText(windowRow.w, root.nowMs) : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            text: windowRow.w ? Model.paceText(windowRow.w, root.nowMs) : ""
            color: windowRow.behind ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
