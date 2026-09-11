import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Date/time label for the bar, and the host for the calendar popup.
//
// Left click reveals the calendar — asking "what is the date?" is what a
// click on a clock means — right click walks the common label formats, and
// middle click opens the timezone picker.
BarWidget {
  id: root
  moduleName: "omarchy.clock"

  property date displayDate: clock.date

  readonly property string configuredFormat: vertical
    ? setting("verticalFormat", "HH\n—\nmm")
    : setting("format", "dddd HH:mm")
  readonly property string configuredAltFormat: vertical
    ? setting("verticalFormatAlt", "dd\nMMM\n'W'ww\n''yy")
    : setting("formatAlt", "d MMMM 'W'ww yyyy")

  readonly property var formatRing: Model.clockFormatRing(configuredFormat, configuredAltFormat, Model.clockFormats(vertical))

  // What the bar shows is what shell.json stores, so a cycled format is the
  // format from then on rather than something that reverts on restart.
  readonly property string activeFormat: configuredFormat
  readonly property string displayText: formatted(displayDate)
  readonly property var verticalLines: displayText.split("\n")

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var current = String(configuredFormat)
    var next = Model.nextClockFormat(formatRing, current)
    if (next === "" || next === current) return

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next

    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  readonly property var japaneseWeekdaysFull: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
  readonly property var japaneseWeekdaysShort: ["日", "月", "火", "水", "木", "金", "土"]

  function japaneseWeekday(date, short) {
    var names = short ? root.japaneseWeekdaysShort : root.japaneseWeekdaysFull
    return names[date.getDay()]
  }

  readonly property var japaneseMonths: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

  function japaneseMonth(date) {
    return root.japaneseMonths[date.getMonth()]
  }

  // Weekday/month substitution only -- shared by the plain label and the
  // day-highlight path below, which both need this done before Qt sees the
  // format (Qt has no idea what to do with 'dddd' as Japanese text).
  function substitutedFormat(date) {
    var withWeek = activeFormat.replace(/ww/g, Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate()))
    var withWeekday = withWeek.replace(/d{3,4}/g, function(match) { return root.japaneseWeekday(date, match.length === 3) })
    return withWeekday.replace(/M{3,4}/g, function() { return root.japaneseMonth(date) })
  }

  function formatted(date) {
    return Qt.formatDateTime(date, substitutedFormat(date))
  }

  // Today's events, for the day-number highlight below. Re-derived from the
  // panel's own cache rather than duplicating a fetch/parse of anything --
  // this bar label never talks to the filesystem or the sync process
  // itself.
  readonly property var todayEvents: (panelLoader.item && panelLoader.item.calendarCache)
    ? Model.eventsForDay(panelLoader.item.calendarCache, Model.keyForDate(root.displayDate))
    : []
  readonly property bool hasEventToday: todayEvents.length > 0
  // Theme accent, matching the month-grid dots and agenda chip in the
  // panel below -- Google's plain ICS export carries no per-event color, so
  // the calendar's configured hex was never anything but a fixed color the
  // rest of the theme never agreed to.
  readonly property color eventHighlightColor: Color.accent

  // The day number split out of the rendered label, or null when today's
  // format has no bare day-of-month token (a pure-time format like
  // "HH:mm") -- there is nothing to highlight in that case.
  readonly property var dayHighlightParts: {
    if (root.vertical) return null
    var marked = Model.markDayToken(substitutedFormat(root.displayDate))
    if (!marked) return null
    return Model.splitOnDayMark(Qt.formatDateTime(root.displayDate, marked))
  }
  readonly property bool showDayHighlight: root.hasEventToday && root.dayHighlightParts !== null

  // ---- Calendar popup. Shape contract for shell.summon/hide/toggle
  //      routing: Bar.findPanelWidget requires open/close/opened on the
  //      bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function toggleWeekStart() {
    if (panelLoader.item) panelLoader.item.toggleWeekStart()
  }

  // The clock fills more slot than it paints a mark for, at both
  // orientations: horizontally it is a text label in a padded slot, so the
  // dot takes the label width; vertically it is a stack of icon-sized lines,
  // so the dot takes one line — the same mark every icon widget gets, rather
  // than a rule running the height of the whole stack.
  //
  // button.labelWidth reads WidgetButton's own built-in label, which is
  // hidden (and reports 0) whenever the day-highlight overlay is showing
  // instead -- so this has to follow whichever one is actually on screen or
  // the indicator collapses to the bar's short fallback mark the moment an
  // event lights up the day number.
  readonly property real openPanelIndicatorWidth: showDayHighlight ? highlightRow.width : button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    // The clone tool leaves the panel's own moduleName at the built-in id
    // ("omarchy.clock") as a stable IPC target, but shell.updateEntryInline
    // compares that id by strict equality against the clone's real id — so
    // without this, every persistSettings() call from the panel (week-start
    // toggle, birth year) silently fails to write back to shell.json.
    if ("moduleName" in target) target.moduleName = root.moduleName
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "omarchy.clock"

    function refresh(): void { root.broadcast("refresh") }
    function cycleFormat(): void { root.cycleFormat() }
    function toggleWeekStart(): void { root.toggleWeekStart() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Bound even while hidden by showDayHighlight below: WidgetButton sizes
    // itself off this label's own implicitWidth, and the highlighted Row
    // needs to land on the exact same footprint the plain label would.
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical && !root.showDayHighlight
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-menu-timezone") }
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3
            ? button.fontSize * 0.9
            : button.fontSize
          color: button.foreground
        }
      }
    }

    // Stands in for the plain label only when today has an event and the
    // active format actually shows a day number -- same font, same
    // centering, just the day segment recolored to the event's calendar
    // color instead of one uniform Text underneath it all.
    //
    // Three separate Text items don't share a baseline by default -- a Row
    // top-aligns them, and CJK glyphs measure a different implicit height
    // than bare digits at the same pixel size, so the day number floats up
    // off the line the rest of the label sits on. Anchoring the day and
    // trailing segments to the leading segment's own baseline (the same
    // fix the calendar hero date uses for its icon-versus-digits mismatch)
    // keeps every segment on one visual line regardless of what glyphs it
    // holds.
    Item {
      id: highlightRow
      visible: root.showDayHighlight
      anchors.centerIn: parent
      width: beforeSegment.width + daySegment.width + afterSegment.width
      height: beforeSegment.height

      Text {
        id: beforeSegment
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.dayHighlightParts ? root.dayHighlightParts.before : ""
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
      }

      Text {
        id: daySegment
        textFormat: Text.PlainText
        anchors.left: beforeSegment.right
        anchors.baseline: beforeSegment.baseline
        text: root.dayHighlightParts ? root.dayHighlightParts.day : ""
        color: root.eventHighlightColor
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        font.bold: true
        renderType: Text.NativeRendering
      }

      Text {
        id: afterSegment
        textFormat: Text.PlainText
        anchors.left: daySegment.right
        anchors.baseline: beforeSegment.baseline
        text: root.dayHighlightParts ? root.dayHighlightParts.after : ""
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
      }
    }
  }

}
