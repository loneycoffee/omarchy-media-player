import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Now playing on the bar: the app's logo (Spotify, YouTube, ...), the track,
// and previous / play-pause / next.
//
// Left click on the logo or the track goes to the app's window and its
// workspace, right click opens the panel (cover, progress, every player),
// middle click plays or pauses, scrolling skips tracks.
//
// Summon from a keybinding with:  omarchy-shell shell toggle media-player
Panel {
  id: root

  moduleName: "media-player"

  property var svc: null

  function bindService() {
    if (root.svc) return
    var host = root.bar && root.bar.shell ? root.bar.shell : null
    if (!host || typeof host.serviceFor !== "function") return
    root.svc = host.serviceFor("media-player")
  }

  onBarChanged: bindService()

  // The service may mount after the bar, and is rebuilt on plugin hot-reload.
  Timer {
    interval: 250
    repeat: true
    running: !root.svc
    onTriggered: root.bindService()
  }

  readonly property real maxLabelWidth: Number(root.setting("maxWidth", 220))
  readonly property bool showArtist: root.setting("showArtist", true) === true
  readonly property bool showControls: root.setting("showControls", true) === true
  readonly property bool hideWhenIdle: root.setting("hideWhenIdle", true) === true

  readonly property var player: root.svc ? root.svc.activePlayer : null
  readonly property bool hasMedia: root.svc ? root.svc.hasMedia : false
  readonly property bool playing: root.svc ? root.svc.playing : false
  readonly property string title: root.svc ? root.svc.title : ""
  readonly property string artist: root.svc ? root.svc.artist : ""
  readonly property string logo: root.svc ? root.svc.logo : ""
  readonly property string appName: root.svc ? root.svc.appName : ""
  readonly property string label: root.title + (root.showArtist && root.artist ? "  ·  " + root.artist : "")
  readonly property bool vertical: root.bar ? root.bar.vertical : false

  readonly property color barFg: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
  readonly property color fg: Color.popups.text
  readonly property color dim: Util.alpha(fg, 0.62)
  readonly property color faint: Util.alpha(fg, 0.38)
  readonly property color solidBackground: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.96)

  // Set by the Return key, which the key catcher also reports as activate.
  property bool _returning: false

  function goToApp() {
    if (!root.svc) return
    root.svc.jump(null)
    root.close()
  }

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds || 0))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var sec = s % 60
    var pad = function(n) { return n < 10 ? "0" + n : String(n) }
    return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec)
  }

  visible: root.hasMedia || !root.hideWhenIdle
  implicitWidth: root.visible ? (root.vertical ? (root.bar ? root.bar.barSize : col.implicitWidth) : row.implicitWidth + Style.space(12)) : 0
  implicitHeight: root.visible ? (root.vertical ? col.implicitHeight + Style.space(12) : (root.bar ? root.bar.barSize : row.implicitHeight)) : 0

  component Logo: Item {
    id: logoItem
    property real size: Style.font.body + 2
    property string source: ""
    property color glyphColor: root.barFg
    implicitWidth: size
    implicitHeight: size

    Image {
      id: logoImage
      anchors.fill: parent
      source: logoItem.source
      sourceSize.width: logoItem.size * 2
      sourceSize.height: logoItem.size * 2
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
      visible: status === Image.Ready
    }

    Text {
      anchors.centerIn: parent
      visible: !logoImage.visible
      textFormat: Text.PlainText
      text: "󰝚"
      color: logoItem.glyphColor
      font.family: root.fontFamily
      font.pixelSize: logoItem.size
    }
  }

  component Control: Text {
    id: control
    property bool enabledAction: true
    signal activated()
    textFormat: Text.PlainText
    color: root.barFg
    opacity: !enabledAction ? 0.3 : (controlMouse.containsMouse ? 1 : 0.8)
    font.family: root.fontFamily
    font.pixelSize: Style.font.body + 1
    MouseArea {
      id: controlMouse
      anchors.fill: parent
      anchors.margins: -Style.space(3)
      hoverEnabled: true
      cursorShape: control.enabledAction ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (control.enabledAction) control.activated()
    }
  }

  // ------------------------------------------------------------ the bar

  // Under the controls, so their clicks win; everything else lands here.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(mouse) {
      if (!root.svc) return
      if (mouse.button === Qt.RightButton) root.toggle()
      else if (mouse.button === Qt.MiddleButton) root.svc.playPause()
      else if (root.hasMedia) root.goToApp()
      else root.toggle()
    }
    onWheel: function(wheel) {
      if (!root.svc) return
      if (wheel.angleDelta.y > 0) root.svc.previous()
      else if (wheel.angleDelta.y < 0) root.svc.next()
    }
    onEntered: if (root.bar && root.hasMedia)
      root.bar.showTooltip(root, root.appName + "\n" + root.title + (root.artist ? " — " + root.artist : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: Style.space(7)

    Logo {
      anchors.verticalCenter: parent.verticalCenter
      source: root.logo
      opacity: root.playing ? 1 : 0.55
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    // Elided at rest, scrolls while hovered when the track is too long.
    Item {
      id: clip
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: labelText.implicitHeight
      clip: true
      visible: root.label !== "" && root.maxLabelWidth > 0

      HoverHandler { id: labelHover }

      Text {
        id: labelText
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.label
        color: root.barFg
        opacity: root.playing ? 1 : 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: scrolling.running ? implicitWidth : clip.width
        elide: scrolling.running ? Text.ElideNone : Text.ElideRight

        SequentialAnimation on x {
          id: scrolling
          running: labelHover.hovered && labelText.implicitWidth > clip.width
          loops: Animation.Infinite
          onRunningChanged: if (!running) labelText.x = 0
          PauseAnimation { duration: 500 }
          NumberAnimation {
            from: 0
            to: clip.width - labelText.implicitWidth
            duration: Math.max(1500, (labelText.implicitWidth - clip.width) * 22)
            easing.type: Easing.Linear
          }
          PauseAnimation { duration: 900 }
          NumberAnimation { to: 0; duration: 350; easing.type: Easing.OutQuad }
        }
      }
    }

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)
      visible: root.showControls

      Control {
        text: "󰒮"
        enabledAction: !!(root.player && root.player.canGoPrevious)
        onActivated: root.svc.previous()
      }
      Control {
        text: root.playing ? "󰏤" : "󰐊"
        onActivated: root.svc.playPause()
      }
      Control {
        text: "󰒭"
        enabledAction: !!(root.player && root.player.canGoNext)
        onActivated: root.svc.next()
      }
    }
  }

  Column {
    id: col
    visible: root.vertical
    anchors.centerIn: parent
    spacing: Style.space(6)

    Logo {
      anchors.horizontalCenter: parent.horizontalCenter
      source: root.logo
      opacity: root.playing ? 1 : 0.55
    }
    Control {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.showControls
      text: root.playing ? "󰏤" : "󰐊"
      onActivated: root.svc.playPause()
    }
  }

  // ------------------------------------------------------------ the panel

  // MPRIS does not push the position; ask while someone is looking.
  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.playing
    triggeredOnStart: true
    onTriggered: if (root.player && root.player.positionSupported) root.player.positionChanged()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(view.implicitHeight, Style.space(640))

    Rectangle {
      anchors.fill: parent
      anchors.margins: -panel.padding
      radius: Style.cornerRadius
      color: root.solidBackground
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onReturnRequested: root._returning = true
      onActivateRequested: {
        if (root._returning) root.goToApp()
        else if (root.svc) root.svc.playPause()
        root._returning = false
      }
      onMoveRequested: function(dx, dy) {
        if (!root.svc) return
        if (dx > 0) root.svc.next()
        else if (dx < 0) root.svc.previous()
        else root.svc.cycle(dy)
      }

      Column {
        id: view
        width: parent.width
        spacing: Style.space(14)

        Text {
          visible: !root.hasMedia
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          text: "Nothing is playing. Start something in Spotify, a browser or any MPRIS player."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        // ---------- Cover and track ----------
        Row {
          visible: root.hasMedia
          width: parent.width
          spacing: Style.space(14)

          Item {
            width: Style.space(88)
            height: width

            Rectangle {
              anchors.fill: parent
              radius: Style.space(6)
              color: Util.alpha(root.fg, 0.08)
              clip: true

              Image {
                id: cover
                anchors.fill: parent
                source: root.svc ? root.svc.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
              }

              Logo {
                anchors.centerIn: parent
                visible: !cover.visible
                size: Style.space(40)
                source: root.logo
                glyphColor: root.dim
              }
            }

            // The app's badge in the corner of the cover.
            Rectangle {
              visible: cover.visible
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: -Style.space(5)
              width: Style.space(26)
              height: width
              radius: width / 2
              color: root.solidBackground
              Logo {
                anchors.centerIn: parent
                size: Style.space(16)
                source: root.logo
                glyphColor: root.fg
              }
            }
          }

          Column {
            width: parent.width - Style.space(102)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.title
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              visible: text !== ""
              textFormat: Text.PlainText
              text: root.artist
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              visible: text !== "" && root.svc && root.svc.album !== root.title
              textFormat: Text.PlainText
              text: root.svc ? root.svc.album : ""
              color: root.faint
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }
        }

        // ---------- Progress ----------
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.hasMedia && root.player && root.player.lengthSupported && root.player.length > 0

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: root.player ? Math.max(1, root.player.length) : 1
            value: root.player && root.player.positionSupported ? root.player.position : 0
            step: 5
            enabled: !!(root.player && root.player.canSeek)
            onReleased: function(v) { if (root.svc) root.svc.seek(v) }
          }

          Item {
            width: parent.width
            height: elapsed.implicitHeight
            Text {
              id: elapsed
              textFormat: Text.PlainText
              text: root.player ? root.clock(root.player.position) : ""
              color: root.faint
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: root.player ? root.clock(root.player.length) : ""
              color: root.faint
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---------- Controls ----------
        Row {
          visible: root.hasMedia
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            iconText: "󰒮"
            foreground: root.fg
            fontFamily: root.fontFamily
            enabled: !!(root.player && root.player.canGoPrevious)
            opacity: enabled ? 1 : 0.4
            onClicked: root.svc.previous()
          }
          Button {
            iconText: root.playing ? "󰏤" : "󰐊"
            iconSize: Style.font.iconLarge
            bordered: true
            foreground: root.fg
            fontFamily: root.fontFamily
            horizontalPadding: Style.spacing.panelGap
            onClicked: root.svc.playPause()
          }
          Button {
            iconText: "󰒭"
            foreground: root.fg
            fontFamily: root.fontFamily
            enabled: !!(root.player && root.player.canGoNext)
            opacity: enabled ? 1 : 0.4
            onClicked: root.svc.next()
          }
        }

        Button {
          visible: root.hasMedia
          width: parent.width
          text: "Go to " + root.appName + (root.svc && root.svc.win.workspace ? "  ·  workspace " + root.svc.win.workspace : "")
          iconText: "󰁔"
          bordered: true
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.goToApp()
        }

        // ---------- Other players ----------
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.svc && root.svc.sources.length > 1

          PanelSeparator { foreground: root.fg }

          Repeater {
            model: root.svc ? root.svc.sources : []

            Rectangle {
              id: source
              required property var modelData
              readonly property bool selected: modelData === root.player

              width: parent.width
              height: sourceRow.implicitHeight + Style.space(12)
              radius: Style.space(6)
              color: selected ? Util.alpha(root.fg, 0.1) : (sourceMouse.containsMouse ? Util.alpha(root.fg, 0.05) : "transparent")

              Row {
                id: sourceRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                Logo {
                  anchors.verticalCenter: parent.verticalCenter
                  size: Style.space(18)
                  source: root.svc ? root.svc.logoFor(source.modelData) : ""
                  glyphColor: root.fg
                }

                Column {
                  width: parent.width - Style.space(56)
                  anchors.verticalCenter: parent.verticalCenter
                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: source.modelData.trackTitle || ""
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: source.selected
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.svc ? root.svc.appNameFor(source.modelData) + (source.modelData.trackArtist ? "  ·  " + source.modelData.trackArtist : "") : ""
                    color: root.faint
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: source.modelData.isPlaying ? "󰏤" : "󰐊"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }

              MouseArea {
                id: sourceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.svc.select(source.modelData)
              }
            }
          }
        }

        Text {
          visible: root.hasMedia
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: "space play · ←/→ skip · ↑/↓ player · enter go to app"
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
