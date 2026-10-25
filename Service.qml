import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// What is playing, mounted once for the shell.
//
// Omarchy builds a bar per monitor; the chosen player, the window it plays in
// and the service behind it (YouTube in a browser, Spotify, ...) live here so
// every bar agrees. Players come straight from MPRIS; bin/media-window maps a
// player to its Hyprland window and focuses it.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  // Host injection.
  property var shell: null
  property var manifest: null

  readonly property string ctl: Qt.resolvedUrl("bin/media-window").toString().replace(/^file:\/\//, "")

  // Services with a bundled logo; anything else uses its desktop entry icon.
  readonly property var bundledLogos: ["spotify", "youtube", "youtubemusic", "soundcloud", "twitch", "netflix", "applemusic", "tidal"]
  readonly property var appNames: ({
    spotify: "Spotify", youtube: "YouTube", youtubemusic: "YouTube Music", soundcloud: "SoundCloud",
    twitch: "Twitch", netflix: "Netflix", applemusic: "Apple Music", tidal: "TIDAL", deezer: "Deezer"
  })

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // The player picked in the panel, or the one that last started playing.
  property string preferredKey: ""
  // Order in which players started playing, so the newest one wins.
  property var startedAt: ({})
  property int serial: 0

  // From bin/media-window, for the active player.
  property var win: ({ address: "", "class": "", title: "", workspace: "", app: "", key: "" })

  readonly property var sources: {
    var list = root.players.filter(function(p) { return root.hasTrack(p) && !root.isProxy(p) })
    list.sort(function(a, b) {
      if (!!a.isPlaying !== !!b.isPlaying) return a.isPlaying ? -1 : 1
      return root.order(b) - root.order(a)
    })
    return list
  }

  readonly property var activePlayer: {
    var list = root.sources
    var preferred = null
    for (var i = 0; i < list.length; i++)
      if (root.keyOf(list[i]) === root.preferredKey) preferred = list[i]
    if (preferred && preferred.isPlaying) return preferred
    // Newest playing first, then the one picked last, then whatever has a track.
    if (list.length > 0 && list[0].isPlaying) return list[0]
    return preferred || (list.length > 0 ? list[0] : null)
  }

  readonly property bool hasMedia: root.activePlayer !== null
  readonly property bool playing: root.hasMedia && root.activePlayer.isPlaying
  readonly property string title: root.hasMedia ? String(root.activePlayer.trackTitle || "") : ""
  readonly property string artist: root.hasMedia ? String(root.activePlayer.trackArtist || "") : ""
  readonly property string album: root.hasMedia ? String(root.activePlayer.trackAlbum || "") : ""
  readonly property string artUrl: root.hasMedia ? String(root.activePlayer.trackArtUrl || "") : ""
  readonly property string app: root.appFor(root.activePlayer)
  readonly property string appName: root.appNameFor(root.activePlayer)
  readonly property string logo: root.logoFor(root.activePlayer)

  function isProxy(p) {
    var bus = String(p && p.dbusName || "").toLowerCase()
    return bus.indexOf("playerctld") !== -1
  }

  function hasTrack(p) {
    return !!(p && (p.trackTitle || p.trackArtist))
  }

  function keyOf(p) {
    return p ? String(p.dbusName || p.identity || "") : ""
  }

  function order(p) {
    var v = root.startedAt[root.keyOf(p)]
    return v === undefined ? 0 : v
  }

  function urlOf(p) {
    if (!p || !p.metadata) return ""
    return String(p.metadata["xesam:url"] || "")
  }

  // The service from the track URL or the player itself; for the active
  // player, also from its window (a browser tab titled "... - YouTube").
  function appFor(p) {
    if (!p) return ""
    var hay = (root.urlOf(p) + " " + (p.desktopEntry || "") + " " + (p.identity || "")).toLowerCase()
    if (hay.indexOf("music.youtube.com") !== -1) return "youtubemusic"
    if (hay.indexOf("youtube.com") !== -1 || hay.indexOf("youtu.be") !== -1) return "youtube"
    for (var k in root.appNames) if (hay.indexOf(k) !== -1) return k
    if (root.keyOf(p) === root.win.key && root.win.app) return root.win.app
    return ""
  }

  function appNameFor(p) {
    if (!p) return ""
    var a = root.appFor(p)
    return a ? root.appNames[a] : String(p.identity || p.desktopEntry || "Media")
  }

  // An image URL for the player's logo, "" when there is none.
  function logoFor(p) {
    if (!p) return ""
    var a = root.appFor(p)
    if (a && root.bundledLogos.indexOf(a) !== -1) return Qt.resolvedUrl("icons/" + a + ".svg").toString()
    var names = [p.desktopEntry, root.keyOf(p) === root.win.key ? root.win["class"] : "", p.identity]
    for (var i = 0; i < names.length; i++) {
      if (!names[i]) continue
      var entry = DesktopEntries.heuristicLookup(String(names[i]))
      var path = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
      if (path) return path
    }
    return ""
  }

  function syncOrder() {
    var next = {}
    var n = root.serial
    for (var i = 0; i < root.players.length; i++) {
      var p = root.players[i]
      var key = root.keyOf(p)
      if (!key) continue
      if (root.startedAt[key] !== undefined) next[key] = root.startedAt[key]
      if (p.isPlaying && (next[key] === undefined || !root._wasPlaying[key])) {
        n += 1
        next[key] = n
      }
    }
    var playingNow = {}
    for (var j = 0; j < root.players.length; j++)
      if (root.players[j].isPlaying) playingNow[root.keyOf(root.players[j])] = true
    root._wasPlaying = playingNow
    root.serial = n
    root.startedAt = next
  }
  property var _wasPlaying: ({})

  // ------------------------------------------------------------- controls

  function playPause() {
    var p = root.activePlayer
    if (!p) return false
    root.preferredKey = root.keyOf(p)
    if (p.canTogglePlaying) p.togglePlaying()
    else if (p.isPlaying && p.canPause) p.pause()
    else if (!p.isPlaying && p.canPlay) p.play()
    else return false
    return true
  }

  function next() {
    var p = root.activePlayer
    if (!p || !p.canGoNext) return false
    root.preferredKey = root.keyOf(p)
    p.next()
    return true
  }

  function previous() {
    var p = root.activePlayer
    if (!p || !p.canGoPrevious) return false
    root.preferredKey = root.keyOf(p)
    p.previous()
    return true
  }

  function seek(seconds) {
    var p = root.activePlayer
    if (!p || !p.canSeek) return
    p.position = Math.max(0, Math.min(seconds, p.length))
  }

  function select(p) {
    if (p) root.preferredKey = root.keyOf(p)
  }

  // Step through the sources, for the panel's j/k.
  function cycle(delta) {
    var list = root.sources
    if (list.length < 2) return
    var i = list.indexOf(root.activePlayer)
    root.select(list[(i + delta + list.length) % list.length])
  }

  // Bring the player forward and go to its workspace. Browsers raise the tab
  // that plays (so the window title then matches the track); Hyprland is
  // asked to focus the window either way, since raise alone rarely does.
  function jump(p) {
    p = p || root.activePlayer
    if (!p) return false
    if (p.canRaise) p.raise()
    focusProc.command = [root.ctl, "focus", String(p.dbusName || ""), String(p.trackTitle || ""),
                         String(p.identity || ""), String(p.desktopEntry || ""), root.urlOf(p)]
    focusDelay.restart()
    return true
  }

  // ---------------------------------------------------------- window lookup

  function lookup() {
    var p = root.activePlayer
    if (!p) {
      root.win = { address: "", "class": "", title: "", workspace: "", app: "", key: "" }
      return
    }
    if (findProc.running) {
      lookupDelay.restart()
      return
    }
    findProc.key = root.keyOf(p)
    findProc.command = [root.ctl, "find", String(p.dbusName || ""), String(p.trackTitle || ""),
                        String(p.identity || ""), String(p.desktopEntry || ""), root.urlOf(p)]
    findProc.running = true
  }

  function parse(text) {
    try {
      return JSON.parse(String(text || ""))
    } catch (e) {
      return null
    }
  }

  onActivePlayerChanged: lookupDelay.restart()
  onTitleChanged: lookupDelay.restart()
  onPlayersChanged: root.syncOrder()
  Component.onCompleted: root.syncOrder()

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.syncOrder() }
    }
  }

  // Track changes come in bursts (title, then artist, then art).
  Timer {
    id: lookupDelay
    interval: 400
    onTriggered: root.lookup()
  }

  // A browser's window title follows its active tab, which can change any time.
  Timer {
    interval: 8000
    repeat: true
    running: root.hasMedia
    onTriggered: root.lookup()
  }

  Timer {
    id: focusDelay
    interval: 200
    onTriggered: focusProc.running = true
  }

  Process {
    id: findProc
    property string key: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var w = root.parse(text)
        if (!w) return
        w.key = findProc.key
        root.win = w
      }
    }
  }

  Process {
    id: focusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var w = root.parse(text)
        if (w && w.address) {
          w.key = root.keyOf(root.activePlayer)
          root.win = w
        }
      }
    }
  }

  IpcHandler {
    target: "media-player"

    function status(): string {
      return JSON.stringify({
        playing: root.playing, app: root.app, appName: root.appName,
        title: root.title, artist: root.artist, album: root.album,
        player: root.keyOf(root.activePlayer), workspace: root.win.workspace || ""
      })
    }
    function playPause(): string { return root.playPause() ? "ok" : "unhandled" }
    function next(): string { return root.next() ? "ok" : "unhandled" }
    function previous(): string { return root.previous() ? "ok" : "unhandled" }
    function jump(): string { return root.jump(null) ? "ok" : "unhandled" }
  }
}
