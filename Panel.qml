import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "stolli.borg"
  ipcTarget: "stolli.borg"
  manageIpc: false

  property string focusSection: "backup"
  property int archiveIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color stateColor: {
    if (borg.state === "failed" || borg.state === "overdue") return urgent
    if (borg.state === "running") return accent
    if (borg.state === "stale" || borg.state === "never" || borg.state === "missing") return dim
    return foreground
  }
  readonly property color barIconColor: {
    if (borg.state === "failed" || borg.state === "overdue") return bar ? bar.urgent : Color.urgent
    if (borg.state === "stale" || borg.state === "never" || borg.state === "missing") return Qt.darker(barForeground, 1.55)
    return barForeground
  }
  readonly property string glyph: "󰀼"
  readonly property var actionIds: ["backup", "vorta", "refresh"]

  function actionIndex() {
    var idx = actionIds.indexOf(focusSection)
    return idx < 0 ? 0 : idx
  }

  function setAction(id) {
    cursorActive = true
    focusSection = id
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dy === 0) return
    if (focusSection === "archives") {
      if (dy < 0 && archiveIndex === 0) {
        focusSection = "refresh"
        return
      }
      archiveIndex = Math.max(0, Math.min(borg.archives.length - 1, archiveIndex + dy))
      return
    }
    var idx = actionIndex()
    var next = idx + dy
    if (next < 0) {
      focusSection = "backup"
      return
    }
    if (next >= actionIds.length) {
      if (borg.archives.length > 0) {
        focusSection = "archives"
        archiveIndex = 0
      }
      return
    }
    focusSection = actionIds[next]
  }

  function activateCursor() {
    if (focusSection === "backup") borg.startBackup()
    else if (focusSection === "vorta") borg.openVorta()
    else if (focusSection === "refresh") borg.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    focusSection = "backup"
    if (panelFlick) panelFlick.contentY = 0
    borg.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: borg
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { borg.refresh(); return "ok" }
    function backup(): string { borg.startBackup(); return "ok" }
    function status(): string { return borg.stateText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: borg.stateText
    iconComponent: Component {
      Text {
        text: root.glyph
        color: root.barIconColor
        opacity: borg.backupRunning ? pulse.opacity : 1.0
        font.family: root.fontFamily
        font.pixelSize: Style.bar.iconFont
        anchors.centerIn: parent
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) borg.startBackup()
      else if (buttonCode === Qt.MiddleButton) borg.refresh()
      else root.toggle()
    }
  }

  SequentialAnimation {
    id: pulse
    property real opacity: 1
    running: borg.backupRunning
    loops: Animation.Infinite
    NumberAnimation { target: pulse; property: "opacity"; from: 1.0; to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
    NumberAnimation { target: pulse; property: "opacity"; from: 0.45; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
    onStopped: pulse.opacity = 1
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") borg.refresh()
        else if (t === "b" || t === "B") borg.startBackup()
        else if (t === "v" || t === "V") borg.openVorta()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Borg"
            meta: borg.stateText
            detail: borg.repoHost
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: borg.backupRunning ? 1.0 : (borg.state === "ok" ? 1.0 : 0.7)
            iconComponent: Component {
              Text {
                text: root.glyph
                color: root.stateColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: borg.actionStatus !== "" || borg.lastError !== ""
            width: parent.width
            text: borg.actionStatus !== "" ? borg.actionStatus : borg.lastError
            color: borg.lastError !== "" && borg.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap
            InfoPair { label: "Last backup"; value: borg.lastBackupTs > 0 ? borg.liveAgeLabel : "never" }
            InfoPair { label: "When"; value: borg.lastBackupAt !== "" ? borg.lastBackupAt : "—" }
            InfoPair { label: "Result"; value: Model.resultLabel(borg.lastReturncode) }
            InfoPair { label: "Schedule"; value: borg.scheduleLabel }
            InfoPair { label: "Next"; value: borg.nextText }
            InfoPair { label: "Vorta"; value: borg.vortaRunning ? "running" : (borg.vortaInstalled ? "not running" : "not installed") }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(6)

            ActionRow {
              actionId: "backup"
              title: borg.backupRunning ? "Backup running…" : "Backup now"
              subtitle: "vorta --create " + borg.profileName
              icon: "󰁯"
              enabled: !borg.busy && borg.vortaInstalled
            }
            ActionRow {
              actionId: "vorta"
              title: "Open Vorta"
              subtitle: "Full backup UI"
              icon: "󰘔"
              enabled: borg.vortaInstalled
            }
            ActionRow {
              actionId: "refresh"
              title: "Refresh status"
              subtitle: borg.refreshing ? "Reading Vorta…" : "r"
              icon: "󰑐"
              enabled: true
            }
          }

          PanelSeparator {
            visible: borg.archives.length > 0
            foreground: root.foreground
          }

          Column {
            visible: borg.archives.length > 0
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "RECENT ARCHIVES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: borg.archives
              ArchiveRow {
                required property var modelData
                required property int index
                width: column.width
                archive: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string actionId: ""
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool enabled: true

    hasCursor: root.cursorActive && root.focusSection === actionId
    foreground: root.foreground
    implicitHeight: actionContent.implicitHeight + Style.spacing.rowPaddingX
    opacity: enabled ? 1.0 : 0.45

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: actionRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: actionRow.enabled
      onEntered: root.setAction(actionRow.actionId)
      onClicked: {
        root.setAction(actionRow.actionId)
        root.activateCursor()
      }
    }

    RowLayout {
      id: actionContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: actionRow.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: actionRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: actionRow.subtitle
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component ArchiveRow: Item {
    id: archiveRow
    property var archive: null
    property int rowIndex: 0
    implicitHeight: archiveCol.implicitHeight + Style.space(4)

    Column {
      id: archiveCol
      width: parent.width
      spacing: Style.space(1)
      Text {
        width: parent.width
        text: archiveRow.archive ? String(archiveRow.archive.name || "") : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideMiddle
      }
      Text {
        width: parent.width
        text: archiveRow.archive ? String(archiveRow.archive.ageLabel || "") : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.space(8)
    Text {
      text: label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
      height: 1
    }
    Text {
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }
}
