pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live config for the wallpaper clock. Ryoku Settings, desktop dragging and the
// right-click menu share widgets.json; FileView watches it so every surface
// follows the next write. Placement is a compass anchor or free monitor pixels.
Singleton {
    id: root
    property bool ready: false

    // -- clock ---------------------------------------------------------------
    property alias clockEnabled: adapter.clockEnabled
    property alias clockDesign:  adapter.clockDesign   // digital | minimal | analog | flip | rings
    property alias clock24h:     adapter.clock24h
    property alias clockSeconds: adapter.clockSeconds
    property alias clockAccent:  adapter.clockAccent   // palette | brand | mono
    property alias clockScale:   adapter.clockScale
    property alias clockAnchor:  adapter.clockAnchor   // top-left .. center .. bottom-right | free
    property alias clockX:       adapter.clockX        // free placement, monitor pixels
    property alias clockY:       adapter.clockY
    property alias clockLocked:  adapter.clockLocked   // prevent drag/resize
    property alias clockOpacity: adapter.clockOpacity
    property alias clockBg:      adapter.clockBg        // none | card | glass
    property alias clockRadius:  adapter.clockRadius
    // per-widget ink colour: "" follows the wallpaper (adaptive), a hex pins a
    // solid fill, and Gradient blends <widget>Color -> <widget>Color2 across the
    // rendered glyphs. Only the bare (bg:none) widgets read these.
    property alias clockColor:    adapter.clockColor
    property alias clockColor2:   adapter.clockColor2
    property alias clockGradient: adapter.clockGradient
    property alias dateShow:     adapter.dateShow
    property alias dateDesign:   adapter.dateDesign     // inline | badge | stacked

    // widget typography: the sans family every clock face and Theme.font widget
    // renders with. Empty = the built-in default (Space Grotesk); a bundled or
    // installed family name overrides it. Picked in Hub -> Widgets.
    property alias widgetFont: adapter.widgetFont

    property alias calendarEnabled:       adapter.calendarEnabled
    property alias calendarStyle:         adapter.calendarStyle
    property alias calendarWeeks:         adapter.calendarWeeks
    property alias calendarWeekNumbers:   adapter.calendarWeekNumbers
    property alias calendarHolidayRegion: adapter.calendarHolidayRegion
    property alias calendarScale:         adapter.calendarScale
    property alias calendarAnchor:        adapter.calendarAnchor
    property alias calendarX:             adapter.calendarX
    property alias calendarY:             adapter.calendarY
    property alias calendarLocked:        adapter.calendarLocked
    property alias calendarOpacity:       adapter.calendarOpacity
    property alias calendarColor:    adapter.calendarColor
    property alias calendarColor2:   adapter.calendarColor2
    property alias calendarGradient: adapter.calendarGradient

    property alias musicEnabled: adapter.musicEnabled
    property alias musicStyle:   adapter.musicStyle    // cover | glass
    property alias musicLyrics:  adapter.musicLyrics   // show the synced lyric sheet
    property alias musicViz:     adapter.musicViz     // bars | wave (no-lyrics visualiser look)
    property alias musicScale:   adapter.musicScale
    property alias musicAnchor:  adapter.musicAnchor
    property alias musicX:       adapter.musicX
    property alias musicY:       adapter.musicY
    property alias musicLocked:  adapter.musicLocked
    property alias musicOpacity: adapter.musicOpacity
    property alias musicApp:     adapter.musicApp     // launch command for the corner button
    property alias musicShape:     adapter.musicShape      // wide | tall (9:16)
    property alias musicVideo:     adapter.musicVideo      // off | canvas | custom
    property alias musicVideoFile: adapter.musicVideoFile  // custom backdrop file
    property alias musicColor:    adapter.musicColor
    property alias musicColor2:   adapter.musicColor2
    property alias musicGradient: adapter.musicGradient

    property alias aioEnabled: adapter.aioEnabled
    property alias aioStyle:   adapter.aioStyle     // wide | tall
    property alias aioScale:   adapter.aioScale
    property alias aioAnchor:  adapter.aioAnchor
    property alias aioX:       adapter.aioX
    property alias aioY:       adapter.aioY
    property alias aioLocked:  adapter.aioLocked
    property alias aioOpacity: adapter.aioOpacity
    property alias aioColor:    adapter.aioColor
    property alias aioColor2:   adapter.aioColor2
    property alias aioGradient: adapter.aioGradient

    property alias statsEnabled: adapter.statsEnabled
    property alias statsScale:   adapter.statsScale
    property alias statsAnchor:  adapter.statsAnchor
    property alias statsX:       adapter.statsX
    property alias statsY:       adapter.statsY
    property alias statsLocked:  adapter.statsLocked
    property alias statsOpacity: adapter.statsOpacity
    property alias statsColor:    adapter.statsColor
    property alias statsColor2:   adapter.statsColor2
    property alias statsGradient: adapter.statsGradient

    property alias weatherEnabled: adapter.weatherEnabled
    property alias weatherDesign:  adapter.weatherDesign   // compact | full
    property alias weatherScale:   adapter.weatherScale
    property alias weatherAnchor:  adapter.weatherAnchor
    property alias weatherX:       adapter.weatherX
    property alias weatherY:       adapter.weatherY
    property alias weatherLocked:  adapter.weatherLocked
    property alias weatherOpacity: adapter.weatherOpacity
    property alias weatherColor:    adapter.weatherColor
    property alias weatherColor2:   adapter.weatherColor2
    property alias weatherGradient: adapter.weatherGradient

    property alias notesEnabled: adapter.notesEnabled
    property alias notesScale:   adapter.notesScale
    property alias notesAnchor:  adapter.notesAnchor
    property alias notesX:       adapter.notesX
    property alias notesY:       adapter.notesY
    property alias notesLocked:  adapter.notesLocked
    property alias notesOpacity: adapter.notesOpacity
    property alias notesWidth:   adapter.notesWidth   // pad size in logical px, before scale
    property alias notesHeight:  adapter.notesHeight
    property alias notesColor:    adapter.notesColor
    property alias notesColor2:   adapter.notesColor2
    property alias notesGradient: adapter.notesGradient

    // dayProgress + shape: the two iRiS desktop widgets folded into Ryoku's
    // roster. Both carry the shared must-have contract (enable, placement, size,
    // lock, opacity, colour) plus their own look keys.
    property alias dayprogressEnabled:  adapter.dayprogressEnabled
    property alias dayprogressStyle:    adapter.dayprogressStyle   // ring | arc
    property alias dayprogressShowDate: adapter.dayprogressShowDate
    property alias dayprogressScale:    adapter.dayprogressScale
    property alias dayprogressAnchor:   adapter.dayprogressAnchor
    property alias dayprogressX:        adapter.dayprogressX
    property alias dayprogressY:        adapter.dayprogressY
    property alias dayprogressLocked:   adapter.dayprogressLocked
    property alias dayprogressOpacity:  adapter.dayprogressOpacity
    property alias dayprogressColor:    adapter.dayprogressColor
    property alias dayprogressColor2:   adapter.dayprogressColor2
    property alias dayprogressGradient: adapter.dayprogressGradient

    property alias shapeEnabled:  adapter.shapeEnabled
    property alias shapeKind:     adapter.shapeKind          // dot | ring | diamond | square
    property alias shapeOutline:  adapter.shapeOutline
    property alias shapeScale:    adapter.shapeScale
    property alias shapeAnchor:   adapter.shapeAnchor
    property alias shapeX:        adapter.shapeX
    property alias shapeY:        adapter.shapeY
    property alias shapeLocked:   adapter.shapeLocked
    property alias shapeOpacity:  adapter.shapeOpacity
    property alias shapeColor:    adapter.shapeColor
    property alias shapeColor2:   adapter.shapeColor2
    property alias shapeGradient: adapter.shapeGradient

    // iRiS face roster: the vendored inir desktop widget faces folded into
    // Ryoku's roster through IrisFaceWidget. Each carries the shared must-have
    // base (enable, placement, size, lock, opacity, backing, colour + Auto/Fixed/
    // Gradient) plus an iRiS size and a JSON blob of its own face options.
    property alias irisClockEnabled:  adapter.irisClockEnabled
    property alias irisClockScale:    adapter.irisClockScale
    property alias irisClockAnchor:   adapter.irisClockAnchor
    property alias irisClockX:        adapter.irisClockX
    property alias irisClockY:        adapter.irisClockY
    property alias irisClockLocked:   adapter.irisClockLocked
    property alias irisClockOpacity:  adapter.irisClockOpacity
    property alias irisClockBg:       adapter.irisClockBg
    property alias irisClockColor:    adapter.irisClockColor
    property alias irisClockColor2:   adapter.irisClockColor2
    property alias irisClockGradient: adapter.irisClockGradient
    property alias irisClockSize:     adapter.irisClockSize
    property alias irisClockOpts:     adapter.irisClockOpts
    property alias irisWeatherEnabled:  adapter.irisWeatherEnabled
    property alias irisWeatherScale:    adapter.irisWeatherScale
    property alias irisWeatherAnchor:   adapter.irisWeatherAnchor
    property alias irisWeatherX:        adapter.irisWeatherX
    property alias irisWeatherY:        adapter.irisWeatherY
    property alias irisWeatherLocked:   adapter.irisWeatherLocked
    property alias irisWeatherOpacity:  adapter.irisWeatherOpacity
    property alias irisWeatherBg:       adapter.irisWeatherBg
    property alias irisWeatherColor:    adapter.irisWeatherColor
    property alias irisWeatherColor2:   adapter.irisWeatherColor2
    property alias irisWeatherGradient: adapter.irisWeatherGradient
    property alias irisWeatherSize:     adapter.irisWeatherSize
    property alias irisWeatherOpts:     adapter.irisWeatherOpts
    property alias irisMediaEnabled:  adapter.irisMediaEnabled
    property alias irisMediaScale:    adapter.irisMediaScale
    property alias irisMediaAnchor:   adapter.irisMediaAnchor
    property alias irisMediaX:        adapter.irisMediaX
    property alias irisMediaY:        adapter.irisMediaY
    property alias irisMediaLocked:   adapter.irisMediaLocked
    property alias irisMediaOpacity:  adapter.irisMediaOpacity
    property alias irisMediaBg:       adapter.irisMediaBg
    property alias irisMediaColor:    adapter.irisMediaColor
    property alias irisMediaColor2:   adapter.irisMediaColor2
    property alias irisMediaGradient: adapter.irisMediaGradient
    property alias irisMediaSize:     adapter.irisMediaSize
    property alias irisMediaOpts:     adapter.irisMediaOpts
    property alias irisControlsEnabled:  adapter.irisControlsEnabled
    property alias irisControlsScale:    adapter.irisControlsScale
    property alias irisControlsAnchor:   adapter.irisControlsAnchor
    property alias irisControlsX:        adapter.irisControlsX
    property alias irisControlsY:        adapter.irisControlsY
    property alias irisControlsLocked:   adapter.irisControlsLocked
    property alias irisControlsOpacity:  adapter.irisControlsOpacity
    property alias irisControlsBg:       adapter.irisControlsBg
    property alias irisControlsColor:    adapter.irisControlsColor
    property alias irisControlsColor2:   adapter.irisControlsColor2
    property alias irisControlsGradient: adapter.irisControlsGradient
    property alias irisControlsSize:     adapter.irisControlsSize
    property alias irisControlsOpts:     adapter.irisControlsOpts
    property alias irisMonthEnabled:  adapter.irisMonthEnabled
    property alias irisMonthScale:    adapter.irisMonthScale
    property alias irisMonthAnchor:   adapter.irisMonthAnchor
    property alias irisMonthX:        adapter.irisMonthX
    property alias irisMonthY:        adapter.irisMonthY
    property alias irisMonthLocked:   adapter.irisMonthLocked
    property alias irisMonthOpacity:  adapter.irisMonthOpacity
    property alias irisMonthBg:       adapter.irisMonthBg
    property alias irisMonthColor:    adapter.irisMonthColor
    property alias irisMonthColor2:   adapter.irisMonthColor2
    property alias irisMonthGradient: adapter.irisMonthGradient
    property alias irisMonthSize:     adapter.irisMonthSize
    property alias irisMonthOpts:     adapter.irisMonthOpts
    property alias irisAgendaEnabled:  adapter.irisAgendaEnabled
    property alias irisAgendaScale:    adapter.irisAgendaScale
    property alias irisAgendaAnchor:   adapter.irisAgendaAnchor
    property alias irisAgendaX:        adapter.irisAgendaX
    property alias irisAgendaY:        adapter.irisAgendaY
    property alias irisAgendaLocked:   adapter.irisAgendaLocked
    property alias irisAgendaOpacity:  adapter.irisAgendaOpacity
    property alias irisAgendaBg:       adapter.irisAgendaBg
    property alias irisAgendaColor:    adapter.irisAgendaColor
    property alias irisAgendaColor2:   adapter.irisAgendaColor2
    property alias irisAgendaGradient: adapter.irisAgendaGradient
    property alias irisAgendaSize:     adapter.irisAgendaSize
    property alias irisAgendaOpts:     adapter.irisAgendaOpts
    property alias irisTodoEnabled:  adapter.irisTodoEnabled
    property alias irisTodoScale:    adapter.irisTodoScale
    property alias irisTodoAnchor:   adapter.irisTodoAnchor
    property alias irisTodoX:        adapter.irisTodoX
    property alias irisTodoY:        adapter.irisTodoY
    property alias irisTodoLocked:   adapter.irisTodoLocked
    property alias irisTodoOpacity:  adapter.irisTodoOpacity
    property alias irisTodoBg:       adapter.irisTodoBg
    property alias irisTodoColor:    adapter.irisTodoColor
    property alias irisTodoColor2:   adapter.irisTodoColor2
    property alias irisTodoGradient: adapter.irisTodoGradient
    property alias irisTodoSize:     adapter.irisTodoSize
    property alias irisTodoOpts:     adapter.irisTodoOpts
    property alias irisNotesEnabled:  adapter.irisNotesEnabled
    property alias irisNotesScale:    adapter.irisNotesScale
    property alias irisNotesAnchor:   adapter.irisNotesAnchor
    property alias irisNotesX:        adapter.irisNotesX
    property alias irisNotesY:        adapter.irisNotesY
    property alias irisNotesLocked:   adapter.irisNotesLocked
    property alias irisNotesOpacity:  adapter.irisNotesOpacity
    property alias irisNotesBg:       adapter.irisNotesBg
    property alias irisNotesColor:    adapter.irisNotesColor
    property alias irisNotesColor2:   adapter.irisNotesColor2
    property alias irisNotesGradient: adapter.irisNotesGradient
    property alias irisNotesSize:     adapter.irisNotesSize
    property alias irisNotesOpts:     adapter.irisNotesOpts
    property alias irisTimersEnabled:  adapter.irisTimersEnabled
    property alias irisTimersScale:    adapter.irisTimersScale
    property alias irisTimersAnchor:   adapter.irisTimersAnchor
    property alias irisTimersX:        adapter.irisTimersX
    property alias irisTimersY:        adapter.irisTimersY
    property alias irisTimersLocked:   adapter.irisTimersLocked
    property alias irisTimersOpacity:  adapter.irisTimersOpacity
    property alias irisTimersBg:       adapter.irisTimersBg
    property alias irisTimersColor:    adapter.irisTimersColor
    property alias irisTimersColor2:   adapter.irisTimersColor2
    property alias irisTimersGradient: adapter.irisTimersGradient
    property alias irisTimersSize:     adapter.irisTimersSize
    property alias irisTimersOpts:     adapter.irisTimersOpts
    property alias irisScreenEnabled:  adapter.irisScreenEnabled
    property alias irisScreenScale:    adapter.irisScreenScale
    property alias irisScreenAnchor:   adapter.irisScreenAnchor
    property alias irisScreenX:        adapter.irisScreenX
    property alias irisScreenY:        adapter.irisScreenY
    property alias irisScreenLocked:   adapter.irisScreenLocked
    property alias irisScreenOpacity:  adapter.irisScreenOpacity
    property alias irisScreenBg:       adapter.irisScreenBg
    property alias irisScreenColor:    adapter.irisScreenColor
    property alias irisScreenColor2:   adapter.irisScreenColor2
    property alias irisScreenGradient: adapter.irisScreenGradient
    property alias irisScreenSize:     adapter.irisScreenSize
    property alias irisScreenOpts:     adapter.irisScreenOpts
    property alias irisVitalsEnabled:  adapter.irisVitalsEnabled
    property alias irisVitalsScale:    adapter.irisVitalsScale
    property alias irisVitalsAnchor:   adapter.irisVitalsAnchor
    property alias irisVitalsX:        adapter.irisVitalsX
    property alias irisVitalsY:        adapter.irisVitalsY
    property alias irisVitalsLocked:   adapter.irisVitalsLocked
    property alias irisVitalsOpacity:  adapter.irisVitalsOpacity
    property alias irisVitalsBg:       adapter.irisVitalsBg
    property alias irisVitalsColor:    adapter.irisVitalsColor
    property alias irisVitalsColor2:   adapter.irisVitalsColor2
    property alias irisVitalsGradient: adapter.irisVitalsGradient
    property alias irisVitalsSize:     adapter.irisVitalsSize
    property alias irisVitalsOpts:     adapter.irisVitalsOpts
    property alias irisBatteryEnabled:  adapter.irisBatteryEnabled
    property alias irisBatteryScale:    adapter.irisBatteryScale
    property alias irisBatteryAnchor:   adapter.irisBatteryAnchor
    property alias irisBatteryX:        adapter.irisBatteryX
    property alias irisBatteryY:        adapter.irisBatteryY
    property alias irisBatteryLocked:   adapter.irisBatteryLocked
    property alias irisBatteryOpacity:  adapter.irisBatteryOpacity
    property alias irisBatteryBg:       adapter.irisBatteryBg
    property alias irisBatteryColor:    adapter.irisBatteryColor
    property alias irisBatteryColor2:   adapter.irisBatteryColor2
    property alias irisBatteryGradient: adapter.irisBatteryGradient
    property alias irisBatterySize:     adapter.irisBatterySize
    property alias irisBatteryOpts:     adapter.irisBatteryOpts
    property alias irisWorldEnabled:  adapter.irisWorldEnabled
    property alias irisWorldScale:    adapter.irisWorldScale
    property alias irisWorldAnchor:   adapter.irisWorldAnchor
    property alias irisWorldX:        adapter.irisWorldX
    property alias irisWorldY:        adapter.irisWorldY
    property alias irisWorldLocked:   adapter.irisWorldLocked
    property alias irisWorldOpacity:  adapter.irisWorldOpacity
    property alias irisWorldBg:       adapter.irisWorldBg
    property alias irisWorldColor:    adapter.irisWorldColor
    property alias irisWorldColor2:   adapter.irisWorldColor2
    property alias irisWorldGradient: adapter.irisWorldGradient
    property alias irisWorldSize:     adapter.irisWorldSize
    property alias irisWorldOpts:     adapter.irisWorldOpts
    property alias irisDateEnabled:  adapter.irisDateEnabled
    property alias irisDateScale:    adapter.irisDateScale
    property alias irisDateAnchor:   adapter.irisDateAnchor
    property alias irisDateX:        adapter.irisDateX
    property alias irisDateY:        adapter.irisDateY
    property alias irisDateLocked:   adapter.irisDateLocked
    property alias irisDateOpacity:  adapter.irisDateOpacity
    property alias irisDateBg:       adapter.irisDateBg
    property alias irisDateColor:    adapter.irisDateColor
    property alias irisDateColor2:   adapter.irisDateColor2
    property alias irisDateGradient: adapter.irisDateGradient
    property alias irisDateSize:     adapter.irisDateSize
    property alias irisDateOpts:     adapter.irisDateOpts
    property alias irisProfileEnabled:  adapter.irisProfileEnabled
    property alias irisProfileScale:    adapter.irisProfileScale
    property alias irisProfileAnchor:   adapter.irisProfileAnchor
    property alias irisProfileX:        adapter.irisProfileX
    property alias irisProfileY:        adapter.irisProfileY
    property alias irisProfileLocked:   adapter.irisProfileLocked
    property alias irisProfileOpacity:  adapter.irisProfileOpacity
    property alias irisProfileBg:       adapter.irisProfileBg
    property alias irisProfileColor:    adapter.irisProfileColor
    property alias irisProfileColor2:   adapter.irisProfileColor2
    property alias irisProfileGradient: adapter.irisProfileGradient
    property alias irisProfileSize:     adapter.irisProfileSize
    property alias irisProfileOpts:     adapter.irisProfileOpts
    property alias irisUptimeEnabled:  adapter.irisUptimeEnabled
    property alias irisUptimeScale:    adapter.irisUptimeScale
    property alias irisUptimeAnchor:   adapter.irisUptimeAnchor
    property alias irisUptimeX:        adapter.irisUptimeX
    property alias irisUptimeY:        adapter.irisUptimeY
    property alias irisUptimeLocked:   adapter.irisUptimeLocked
    property alias irisUptimeOpacity:  adapter.irisUptimeOpacity
    property alias irisUptimeBg:       adapter.irisUptimeBg
    property alias irisUptimeColor:    adapter.irisUptimeColor
    property alias irisUptimeColor2:   adapter.irisUptimeColor2
    property alias irisUptimeGradient: adapter.irisUptimeGradient
    property alias irisUptimeSize:     adapter.irisUptimeSize
    property alias irisUptimeOpts:     adapter.irisUptimeOpts
    property alias irisNewsEnabled:  adapter.irisNewsEnabled
    property alias irisNewsScale:    adapter.irisNewsScale
    property alias irisNewsAnchor:   adapter.irisNewsAnchor
    property alias irisNewsX:        adapter.irisNewsX
    property alias irisNewsY:        adapter.irisNewsY
    property alias irisNewsLocked:   adapter.irisNewsLocked
    property alias irisNewsOpacity:  adapter.irisNewsOpacity
    property alias irisNewsBg:       adapter.irisNewsBg
    property alias irisNewsColor:    adapter.irisNewsColor
    property alias irisNewsColor2:   adapter.irisNewsColor2
    property alias irisNewsGradient: adapter.irisNewsGradient
    property alias irisNewsSize:     adapter.irisNewsSize
    property alias irisNewsOpts:     adapter.irisNewsOpts
    // per-widget skin: "inir" (upstream face) | "ryoku" (additive Ryoku skin)
    property alias irisClockStyle:    adapter.irisClockStyle
    property alias irisWeatherStyle:    adapter.irisWeatherStyle
    property alias irisMediaStyle:    adapter.irisMediaStyle
    property alias irisControlsStyle:    adapter.irisControlsStyle
    property alias irisMonthStyle:    adapter.irisMonthStyle
    property alias irisAgendaStyle:    adapter.irisAgendaStyle
    property alias irisTodoStyle:    adapter.irisTodoStyle
    property alias irisNotesStyle:    adapter.irisNotesStyle
    property alias irisTimersStyle:    adapter.irisTimersStyle
    property alias irisScreenStyle:    adapter.irisScreenStyle
    property alias irisVitalsStyle:    adapter.irisVitalsStyle
    property alias irisBatteryStyle:    adapter.irisBatteryStyle
    property alias irisWorldStyle:    adapter.irisWorldStyle
    property alias irisDateStyle:    adapter.irisDateStyle
    property alias irisProfileStyle:    adapter.irisProfileStyle
    property alias irisUptimeStyle:    adapter.irisUptimeStyle
    property alias irisNewsStyle:    adapter.irisNewsStyle
    // per-widget geometry (Ryoku style): -1 = today's look
    property alias irisClockRadius: adapter.irisClockRadius
    property alias irisClockPad: adapter.irisClockPad
    property alias irisClockBorder: adapter.irisClockBorder
    property alias irisClockBorderOpacity: adapter.irisClockBorderOpacity
    property alias irisClockBackingOpacity: adapter.irisClockBackingOpacity
    property alias irisWeatherRadius: adapter.irisWeatherRadius
    property alias irisWeatherPad: adapter.irisWeatherPad
    property alias irisWeatherBorder: adapter.irisWeatherBorder
    property alias irisWeatherBorderOpacity: adapter.irisWeatherBorderOpacity
    property alias irisWeatherBackingOpacity: adapter.irisWeatherBackingOpacity
    property alias irisMediaRadius: adapter.irisMediaRadius
    property alias irisMediaPad: adapter.irisMediaPad
    property alias irisMediaBorder: adapter.irisMediaBorder
    property alias irisMediaBorderOpacity: adapter.irisMediaBorderOpacity
    property alias irisMediaBackingOpacity: adapter.irisMediaBackingOpacity
    property alias irisControlsRadius: adapter.irisControlsRadius
    property alias irisControlsPad: adapter.irisControlsPad
    property alias irisControlsBorder: adapter.irisControlsBorder
    property alias irisControlsBorderOpacity: adapter.irisControlsBorderOpacity
    property alias irisControlsBackingOpacity: adapter.irisControlsBackingOpacity
    property alias irisMonthRadius: adapter.irisMonthRadius
    property alias irisMonthPad: adapter.irisMonthPad
    property alias irisMonthBorder: adapter.irisMonthBorder
    property alias irisMonthBorderOpacity: adapter.irisMonthBorderOpacity
    property alias irisMonthBackingOpacity: adapter.irisMonthBackingOpacity
    property alias irisAgendaRadius: adapter.irisAgendaRadius
    property alias irisAgendaPad: adapter.irisAgendaPad
    property alias irisAgendaBorder: adapter.irisAgendaBorder
    property alias irisAgendaBorderOpacity: adapter.irisAgendaBorderOpacity
    property alias irisAgendaBackingOpacity: adapter.irisAgendaBackingOpacity
    property alias irisTodoRadius: adapter.irisTodoRadius
    property alias irisTodoPad: adapter.irisTodoPad
    property alias irisTodoBorder: adapter.irisTodoBorder
    property alias irisTodoBorderOpacity: adapter.irisTodoBorderOpacity
    property alias irisTodoBackingOpacity: adapter.irisTodoBackingOpacity
    property alias irisNotesRadius: adapter.irisNotesRadius
    property alias irisNotesPad: adapter.irisNotesPad
    property alias irisNotesBorder: adapter.irisNotesBorder
    property alias irisNotesBorderOpacity: adapter.irisNotesBorderOpacity
    property alias irisNotesBackingOpacity: adapter.irisNotesBackingOpacity
    property alias irisTimersRadius: adapter.irisTimersRadius
    property alias irisTimersPad: adapter.irisTimersPad
    property alias irisTimersBorder: adapter.irisTimersBorder
    property alias irisTimersBorderOpacity: adapter.irisTimersBorderOpacity
    property alias irisTimersBackingOpacity: adapter.irisTimersBackingOpacity
    property alias irisScreenRadius: adapter.irisScreenRadius
    property alias irisScreenPad: adapter.irisScreenPad
    property alias irisScreenBorder: adapter.irisScreenBorder
    property alias irisScreenBorderOpacity: adapter.irisScreenBorderOpacity
    property alias irisScreenBackingOpacity: adapter.irisScreenBackingOpacity
    property alias irisVitalsRadius: adapter.irisVitalsRadius
    property alias irisVitalsPad: adapter.irisVitalsPad
    property alias irisVitalsBorder: adapter.irisVitalsBorder
    property alias irisVitalsBorderOpacity: adapter.irisVitalsBorderOpacity
    property alias irisVitalsBackingOpacity: adapter.irisVitalsBackingOpacity
    property alias irisBatteryRadius: adapter.irisBatteryRadius
    property alias irisBatteryPad: adapter.irisBatteryPad
    property alias irisBatteryBorder: adapter.irisBatteryBorder
    property alias irisBatteryBorderOpacity: adapter.irisBatteryBorderOpacity
    property alias irisBatteryBackingOpacity: adapter.irisBatteryBackingOpacity
    property alias irisWorldRadius: adapter.irisWorldRadius
    property alias irisWorldPad: adapter.irisWorldPad
    property alias irisWorldBorder: adapter.irisWorldBorder
    property alias irisWorldBorderOpacity: adapter.irisWorldBorderOpacity
    property alias irisWorldBackingOpacity: adapter.irisWorldBackingOpacity
    property alias irisDateRadius: adapter.irisDateRadius
    property alias irisDatePad: adapter.irisDatePad
    property alias irisDateBorder: adapter.irisDateBorder
    property alias irisDateBorderOpacity: adapter.irisDateBorderOpacity
    property alias irisDateBackingOpacity: adapter.irisDateBackingOpacity
    property alias irisProfileRadius: adapter.irisProfileRadius
    property alias irisProfilePad: adapter.irisProfilePad
    property alias irisProfileBorder: adapter.irisProfileBorder
    property alias irisProfileBorderOpacity: adapter.irisProfileBorderOpacity
    property alias irisProfileBackingOpacity: adapter.irisProfileBackingOpacity
    property alias irisUptimeRadius: adapter.irisUptimeRadius
    property alias irisUptimePad: adapter.irisUptimePad
    property alias irisUptimeBorder: adapter.irisUptimeBorder
    property alias irisUptimeBorderOpacity: adapter.irisUptimeBorderOpacity
    property alias irisUptimeBackingOpacity: adapter.irisUptimeBackingOpacity
    property alias irisNewsRadius: adapter.irisNewsRadius
    property alias irisNewsPad: adapter.irisNewsPad
    property alias irisNewsBorder: adapter.irisNewsBorder
    property alias irisNewsBorderOpacity: adapter.irisNewsBorderOpacity
    property alias irisNewsBackingOpacity: adapter.irisNewsBackingOpacity
    // iRiS canvas widgets (hosted whole, no face)
    property alias irisCustomImageEnabled: adapter.irisCustomImageEnabled
    property alias irisCustomImageScale: adapter.irisCustomImageScale
    property alias irisCustomImageAnchor: adapter.irisCustomImageAnchor
    property alias irisCustomImageX: adapter.irisCustomImageX
    property alias irisCustomImageY: adapter.irisCustomImageY
    property alias irisCustomImageLocked: adapter.irisCustomImageLocked
    property alias irisCustomImageOpacity: adapter.irisCustomImageOpacity
    property alias irisCustomImageBg: adapter.irisCustomImageBg
    property alias irisCustomImageColor: adapter.irisCustomImageColor
    property alias irisCustomImageColor2: adapter.irisCustomImageColor2
    property alias irisCustomImageGradient: adapter.irisCustomImageGradient
    property alias irisCustomImageSize: adapter.irisCustomImageSize
    property alias irisCustomImageOpts: adapter.irisCustomImageOpts
    property alias irisCustomImageStyle: adapter.irisCustomImageStyle
    property alias irisCustomImageRadius: adapter.irisCustomImageRadius
    property alias irisCustomImagePad: adapter.irisCustomImagePad
    property alias irisCustomImageBorder: adapter.irisCustomImageBorder
    property alias irisCustomImageBorderOpacity: adapter.irisCustomImageBorderOpacity
    property alias irisCustomImageBackingOpacity: adapter.irisCustomImageBackingOpacity
    property alias irisEditorialEnabled: adapter.irisEditorialEnabled
    property alias irisEditorialScale: adapter.irisEditorialScale
    property alias irisEditorialAnchor: adapter.irisEditorialAnchor
    property alias irisEditorialX: adapter.irisEditorialX
    property alias irisEditorialY: adapter.irisEditorialY
    property alias irisEditorialLocked: adapter.irisEditorialLocked
    property alias irisEditorialOpacity: adapter.irisEditorialOpacity
    property alias irisEditorialBg: adapter.irisEditorialBg
    property alias irisEditorialColor: adapter.irisEditorialColor
    property alias irisEditorialColor2: adapter.irisEditorialColor2
    property alias irisEditorialGradient: adapter.irisEditorialGradient
    property alias irisEditorialSize: adapter.irisEditorialSize
    property alias irisEditorialOpts: adapter.irisEditorialOpts
    property alias irisEditorialStyle: adapter.irisEditorialStyle
    property alias irisEditorialRadius: adapter.irisEditorialRadius
    property alias irisEditorialPad: adapter.irisEditorialPad
    property alias irisEditorialBorder: adapter.irisEditorialBorder
    property alias irisEditorialBorderOpacity: adapter.irisEditorialBorderOpacity
    property alias irisEditorialBackingOpacity: adapter.irisEditorialBackingOpacity
    property alias irisConverterEnabled: adapter.irisConverterEnabled
    property alias irisConverterScale: adapter.irisConverterScale
    property alias irisConverterAnchor: adapter.irisConverterAnchor
    property alias irisConverterX: adapter.irisConverterX
    property alias irisConverterY: adapter.irisConverterY
    property alias irisConverterLocked: adapter.irisConverterLocked
    property alias irisConverterOpacity: adapter.irisConverterOpacity
    property alias irisConverterBg: adapter.irisConverterBg
    property alias irisConverterColor: adapter.irisConverterColor
    property alias irisConverterColor2: adapter.irisConverterColor2
    property alias irisConverterGradient: adapter.irisConverterGradient
    property alias irisConverterSize: adapter.irisConverterSize
    property alias irisConverterOpts: adapter.irisConverterOpts
    property alias irisConverterStyle: adapter.irisConverterStyle
    property alias irisConverterRadius: adapter.irisConverterRadius
    property alias irisConverterPad: adapter.irisConverterPad
    property alias irisConverterBorder: adapter.irisConverterBorder
    property alias irisConverterBorderOpacity: adapter.irisConverterBorderOpacity
    property alias irisConverterBackingOpacity: adapter.irisConverterBackingOpacity
    property alias irisJpEnabled: adapter.irisJpEnabled
    property alias irisJpScale: adapter.irisJpScale
    property alias irisJpAnchor: adapter.irisJpAnchor
    property alias irisJpX: adapter.irisJpX
    property alias irisJpY: adapter.irisJpY
    property alias irisJpLocked: adapter.irisJpLocked
    property alias irisJpOpacity: adapter.irisJpOpacity
    property alias irisJpBg: adapter.irisJpBg
    property alias irisJpColor: adapter.irisJpColor
    property alias irisJpColor2: adapter.irisJpColor2
    property alias irisJpGradient: adapter.irisJpGradient
    property alias irisJpSize: adapter.irisJpSize
    property alias irisJpOpts: adapter.irisJpOpts
    property alias irisJpStyle: adapter.irisJpStyle
    property alias irisJpRadius: adapter.irisJpRadius
    property alias irisJpPad: adapter.irisJpPad
    property alias irisJpBorder: adapter.irisJpBorder
    property alias irisJpBorderOpacity: adapter.irisJpBorderOpacity
    property alias irisJpBackingOpacity: adapter.irisJpBackingOpacity
    property alias irisVisualizerEnabled: adapter.irisVisualizerEnabled
    property alias irisVisualizerScale: adapter.irisVisualizerScale
    property alias irisVisualizerAnchor: adapter.irisVisualizerAnchor
    property alias irisVisualizerX: adapter.irisVisualizerX
    property alias irisVisualizerY: adapter.irisVisualizerY
    property alias irisVisualizerLocked: adapter.irisVisualizerLocked
    property alias irisVisualizerOpacity: adapter.irisVisualizerOpacity
    property alias irisVisualizerBg: adapter.irisVisualizerBg
    property alias irisVisualizerColor: adapter.irisVisualizerColor
    property alias irisVisualizerColor2: adapter.irisVisualizerColor2
    property alias irisVisualizerGradient: adapter.irisVisualizerGradient
    property alias irisVisualizerSize: adapter.irisVisualizerSize
    property alias irisVisualizerOpts: adapter.irisVisualizerOpts
    property alias irisVisualizerStyle: adapter.irisVisualizerStyle
    property alias irisVisualizerRadius: adapter.irisVisualizerRadius
    property alias irisVisualizerPad: adapter.irisVisualizerPad
    property alias irisVisualizerBorder: adapter.irisVisualizerBorder
    property alias irisVisualizerBorderOpacity: adapter.irisVisualizerBorderOpacity
    property alias irisVisualizerBackingOpacity: adapter.irisVisualizerBackingOpacity

    // brand: the desktop's mark + name, user-overridable from Ryoku Settings ->
    // Shell -> Global. a small cross-cutting identity master (like theme.json).
    // markText is the glyph/short-text seal (default 力); markImage an optional
    // image path that wins over the text; markTint recolours a single-colour
    // image to the accent; name is the wordmark ("Ryoku") shown in chrome copy.
    // Ryoku's own apps (the Hub, ryo* apps) never read this and keep the 力 brand.
    property alias markText:  brandAdapter.markText
    property alias markImage: brandAdapter.markImage
    property alias markTint:  brandAdapter.markTint
    property alias brandName: brandAdapter.name

    // write helpers used by desktop drag + right-click menu. write the same file
    // Settings does; the watch reloads it (no-op for the value just written) so
    // running widgets and the next Settings open agree.
    function set(key, value) {
        adapter[key] = value;
        file.writeAdapter();
    }
    // Many keys, one write. A burst of set() calls interleaves file writes with
    // the watcher's reloads of older versions, and a stale reload followed by
    // the next write can put an old value back (a Reset restoring thirty keys
    // lost some this way); assigning everything first and writing once cannot.
    function setMany(values) {
        for (const key in values)
            if (adapter[key] !== values[key])
                adapter[key] = values[key];
        file.writeAdapter();
    }
    // memory-only, no file write. for a live drag like resize: aliases update
    // at once so the widget re-renders; setFree/set on release does the single
    // persisting write.
    function setLive(key, value) {
        adapter[key] = value;
    }
    function toggle(key) {
        adapter[key] = !adapter[key];
        file.writeAdapter();
    }
    function setAnchor(prefix, zone) {
        adapter[prefix + "Anchor"] = zone;
        file.writeAdapter();
    }
    function setFree(prefix, x, y) {
        adapter[prefix + "Anchor"] = "free";
        adapter[prefix + "X"] = x;
        adapter[prefix + "Y"] = y;
        file.writeAdapter();
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/widgets.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.ready = true
        onLoadFailed: root.ready = true

        JsonAdapter {
            id: adapter
            property bool clockEnabled: true
            property string clockDesign: "digital"
            property bool clock24h: true
            property bool clockSeconds: false
            property string clockAccent: "palette"
            property real clockScale: 1.0
            property string clockAnchor: "top-left"
            property int clockX: 72
            property int clockY: 64
            property bool clockLocked: false
            property real clockOpacity: 1.0
            property string clockBg: "none"
            property int clockRadius: 26
            property string clockColor: ""
            property string clockColor2: ""
            property bool clockGradient: false
            property bool dateShow: true
            property string dateDesign: "inline"
            property string widgetFont: ""
            property bool calendarEnabled: true
            property string calendarStyle: "glass"
            property int calendarWeeks: 6
            property bool calendarWeekNumbers: true
            property string calendarHolidayRegion: ""
            property real calendarScale: 1.0
            property string calendarAnchor: "bottom-right"
            property int calendarX: 80
            property int calendarY: 80
            property bool calendarLocked: false
            property real calendarOpacity: 1.0
            property string calendarColor: ""
            property string calendarColor2: ""
            property bool calendarGradient: false
            property bool musicEnabled: false
            property string musicStyle: "cover"
            property bool musicLyrics: true
            property string musicViz: "bars"
            property real musicScale: 1.0
            property string musicAnchor: "bottom-left"
            property int musicX: 80
            property int musicY: 80
            property bool musicLocked: false
            property real musicOpacity: 1.0
            property string musicApp: ""
            property string musicShape: "wide"
            property string musicVideo: "canvas"
            property string musicVideoFile: ""
            property string musicColor: ""
            property string musicColor2: ""
            property bool musicGradient: false
            property bool aioEnabled: false
            property string aioStyle: "wide"
            property real aioScale: 1.0
            property string aioAnchor: "top-right"
            property int aioX: 80
            property int aioY: 80
            property bool aioLocked: false
            property real aioOpacity: 1.0
            property string aioColor: ""
            property string aioColor2: ""
            property bool aioGradient: false
            property bool statsEnabled: false
            property real statsScale: 1.0
            property string statsAnchor: "bottom-right"
            property int statsX: 80
            property int statsY: 80
            property bool statsLocked: false
            property real statsOpacity: 1.0
            property string statsColor: ""
            property string statsColor2: ""
            property bool statsGradient: false
            property bool weatherEnabled: false
            property string weatherDesign: "compact"
            property real weatherScale: 1.0
            property string weatherAnchor: "top-right"
            property int weatherX: 80
            property int weatherY: 80
            property bool weatherLocked: false
            property real weatherOpacity: 1.0
            property string weatherColor: ""
            property string weatherColor2: ""
            property bool weatherGradient: false
            property bool notesEnabled: false
            property real notesScale: 1.0
            property string notesAnchor: "right"
            property int notesX: 80
            property int notesY: 80
            property bool notesLocked: false
            property real notesOpacity: 1.0
            property int notesWidth: 260
            property int notesHeight: 180
            property string notesColor: ""
            property string notesColor2: ""
            property bool notesGradient: false
            property bool dayprogressEnabled: false
            property string dayprogressStyle: "ring"
            property bool dayprogressShowDate: true
            property real dayprogressScale: 1.0
            property string dayprogressAnchor: "left"
            property int dayprogressX: 80
            property int dayprogressY: 260
            property bool dayprogressLocked: false
            property real dayprogressOpacity: 1.0
            property string dayprogressColor: ""
            property string dayprogressColor2: ""
            property bool dayprogressGradient: false
            property bool shapeEnabled: false
            property string shapeKind: "dot"
            property bool shapeOutline: false
            property real shapeScale: 1.0
            property string shapeAnchor: "bottom-left"
            property int shapeX: 80
            property int shapeY: 240
            property bool shapeLocked: false
            property real shapeOpacity: 1.0
            property string shapeColor: ""
            property string shapeColor2: ""
            property bool shapeGradient: false
            property bool irisClockEnabled: false
            property real irisClockScale: 1.0
            property string irisClockAnchor: "free"
            property int irisClockX: 120
            property int irisClockY: 120
            property bool irisClockLocked: false
            property real irisClockOpacity: 1.0
            property string irisClockBg: "card"
            property string irisClockColor: ""
            property string irisClockColor2: ""
            property bool irisClockGradient: false
            property string irisClockSize: "small"
            property string irisClockOpts: ""
            property bool irisWeatherEnabled: false
            property real irisWeatherScale: 1.0
            property string irisWeatherAnchor: "free"
            property int irisWeatherX: 168
            property int irisWeatherY: 160
            property bool irisWeatherLocked: false
            property real irisWeatherOpacity: 1.0
            property string irisWeatherBg: "card"
            property string irisWeatherColor: ""
            property string irisWeatherColor2: ""
            property bool irisWeatherGradient: false
            property string irisWeatherSize: "small"
            property string irisWeatherOpts: ""
            property bool irisMediaEnabled: false
            property real irisMediaScale: 1.0
            property string irisMediaAnchor: "free"
            property int irisMediaX: 216
            property int irisMediaY: 200
            property bool irisMediaLocked: false
            property real irisMediaOpacity: 1.0
            property string irisMediaBg: "card"
            property string irisMediaColor: ""
            property string irisMediaColor2: ""
            property bool irisMediaGradient: false
            property string irisMediaSize: "medium"
            property string irisMediaOpts: ""
            property bool irisControlsEnabled: false
            property real irisControlsScale: 1.0
            property string irisControlsAnchor: "free"
            property int irisControlsX: 120
            property int irisControlsY: 240
            property bool irisControlsLocked: false
            property real irisControlsOpacity: 1.0
            property string irisControlsBg: "card"
            property string irisControlsColor: ""
            property string irisControlsColor2: ""
            property bool irisControlsGradient: false
            property string irisControlsSize: "medium"
            property string irisControlsOpts: ""
            property bool irisMonthEnabled: false
            property real irisMonthScale: 1.0
            property string irisMonthAnchor: "free"
            property int irisMonthX: 168
            property int irisMonthY: 280
            property bool irisMonthLocked: false
            property real irisMonthOpacity: 1.0
            property string irisMonthBg: "card"
            property string irisMonthColor: ""
            property string irisMonthColor2: ""
            property bool irisMonthGradient: false
            property string irisMonthSize: "medium"
            property string irisMonthOpts: ""
            property bool irisAgendaEnabled: false
            property real irisAgendaScale: 1.0
            property string irisAgendaAnchor: "free"
            property int irisAgendaX: 216
            property int irisAgendaY: 320
            property bool irisAgendaLocked: false
            property real irisAgendaOpacity: 1.0
            property string irisAgendaBg: "card"
            property string irisAgendaColor: ""
            property string irisAgendaColor2: ""
            property bool irisAgendaGradient: false
            property string irisAgendaSize: "medium"
            property string irisAgendaOpts: ""
            property bool irisTodoEnabled: false
            property real irisTodoScale: 1.0
            property string irisTodoAnchor: "free"
            property int irisTodoX: 120
            property int irisTodoY: 360
            property bool irisTodoLocked: false
            property real irisTodoOpacity: 1.0
            property string irisTodoBg: "card"
            property string irisTodoColor: ""
            property string irisTodoColor2: ""
            property bool irisTodoGradient: false
            property string irisTodoSize: "medium"
            property string irisTodoOpts: ""
            property bool irisNotesEnabled: false
            property real irisNotesScale: 1.0
            property string irisNotesAnchor: "free"
            property int irisNotesX: 168
            property int irisNotesY: 400
            property bool irisNotesLocked: false
            property real irisNotesOpacity: 1.0
            property string irisNotesBg: "card"
            property string irisNotesColor: ""
            property string irisNotesColor2: ""
            property bool irisNotesGradient: false
            property string irisNotesSize: "medium"
            property string irisNotesOpts: ""
            property bool irisTimersEnabled: false
            property real irisTimersScale: 1.0
            property string irisTimersAnchor: "free"
            property int irisTimersX: 216
            property int irisTimersY: 440
            property bool irisTimersLocked: false
            property real irisTimersOpacity: 1.0
            property string irisTimersBg: "card"
            property string irisTimersColor: ""
            property string irisTimersColor2: ""
            property bool irisTimersGradient: false
            property string irisTimersSize: "medium"
            property string irisTimersOpts: ""
            property bool irisScreenEnabled: false
            property real irisScreenScale: 1.0
            property string irisScreenAnchor: "free"
            property int irisScreenX: 120
            property int irisScreenY: 480
            property bool irisScreenLocked: false
            property real irisScreenOpacity: 1.0
            property string irisScreenBg: "card"
            property string irisScreenColor: ""
            property string irisScreenColor2: ""
            property bool irisScreenGradient: false
            property string irisScreenSize: "medium"
            property string irisScreenOpts: ""
            property bool irisVitalsEnabled: false
            property real irisVitalsScale: 1.0
            property string irisVitalsAnchor: "free"
            property int irisVitalsX: 168
            property int irisVitalsY: 520
            property bool irisVitalsLocked: false
            property real irisVitalsOpacity: 1.0
            property string irisVitalsBg: "card"
            property string irisVitalsColor: ""
            property string irisVitalsColor2: ""
            property bool irisVitalsGradient: false
            property string irisVitalsSize: "medium"
            property string irisVitalsOpts: ""
            property bool irisBatteryEnabled: false
            property real irisBatteryScale: 1.0
            property string irisBatteryAnchor: "free"
            property int irisBatteryX: 216
            property int irisBatteryY: 560
            property bool irisBatteryLocked: false
            property real irisBatteryOpacity: 1.0
            property string irisBatteryBg: "card"
            property string irisBatteryColor: ""
            property string irisBatteryColor2: ""
            property bool irisBatteryGradient: false
            property string irisBatterySize: "small"
            property string irisBatteryOpts: ""
            property bool irisWorldEnabled: false
            property real irisWorldScale: 1.0
            property string irisWorldAnchor: "free"
            property int irisWorldX: 120
            property int irisWorldY: 600
            property bool irisWorldLocked: false
            property real irisWorldOpacity: 1.0
            property string irisWorldBg: "card"
            property string irisWorldColor: ""
            property string irisWorldColor2: ""
            property bool irisWorldGradient: false
            property string irisWorldSize: "medium"
            property string irisWorldOpts: ""
            property bool irisDateEnabled: false
            property real irisDateScale: 1.0
            property string irisDateAnchor: "free"
            property int irisDateX: 168
            property int irisDateY: 640
            property bool irisDateLocked: false
            property real irisDateOpacity: 1.0
            property string irisDateBg: "card"
            property string irisDateColor: ""
            property string irisDateColor2: ""
            property bool irisDateGradient: false
            property string irisDateSize: "small"
            property string irisDateOpts: ""
            property bool irisProfileEnabled: false
            property real irisProfileScale: 1.0
            property string irisProfileAnchor: "free"
            property int irisProfileX: 216
            property int irisProfileY: 680
            property bool irisProfileLocked: false
            property real irisProfileOpacity: 1.0
            property string irisProfileBg: "card"
            property string irisProfileColor: ""
            property string irisProfileColor2: ""
            property bool irisProfileGradient: false
            property string irisProfileSize: "medium"
            property string irisProfileOpts: ""
            property bool irisUptimeEnabled: false
            property real irisUptimeScale: 1.0
            property string irisUptimeAnchor: "free"
            property int irisUptimeX: 120
            property int irisUptimeY: 720
            property bool irisUptimeLocked: false
            property real irisUptimeOpacity: 1.0
            property string irisUptimeBg: "card"
            property string irisUptimeColor: ""
            property string irisUptimeColor2: ""
            property bool irisUptimeGradient: false
            property string irisUptimeSize: "small"
            property string irisUptimeOpts: ""
            property bool irisNewsEnabled: false
            property real irisNewsScale: 1.0
            property string irisNewsAnchor: "free"
            property int irisNewsX: 168
            property int irisNewsY: 760
            property bool irisNewsLocked: false
            property real irisNewsOpacity: 1.0
            property string irisNewsBg: "card"
            property string irisNewsColor: ""
            property string irisNewsColor2: ""
            property bool irisNewsGradient: false
            property string irisNewsSize: "medium"
            property string irisNewsOpts: ""
            property string irisClockStyle: "inir"
            property string irisWeatherStyle: "inir"
            property string irisMediaStyle: "inir"
            property string irisControlsStyle: "inir"
            property string irisMonthStyle: "inir"
            property string irisAgendaStyle: "inir"
            property string irisTodoStyle: "inir"
            property string irisNotesStyle: "inir"
            property string irisTimersStyle: "inir"
            property string irisScreenStyle: "inir"
            property string irisVitalsStyle: "inir"
            property string irisBatteryStyle: "inir"
            property string irisWorldStyle: "inir"
            property string irisDateStyle: "inir"
            property string irisProfileStyle: "inir"
            property string irisUptimeStyle: "inir"
            property string irisNewsStyle: "inir"
            property int irisClockRadius: -1
            property real irisClockPad: -1
            property real irisClockBorder: -1
            property real irisClockBorderOpacity: -1
            property real irisClockBackingOpacity: -1
            property int irisWeatherRadius: -1
            property real irisWeatherPad: -1
            property real irisWeatherBorder: -1
            property real irisWeatherBorderOpacity: -1
            property real irisWeatherBackingOpacity: -1
            property int irisMediaRadius: -1
            property real irisMediaPad: -1
            property real irisMediaBorder: -1
            property real irisMediaBorderOpacity: -1
            property real irisMediaBackingOpacity: -1
            property int irisControlsRadius: -1
            property real irisControlsPad: -1
            property real irisControlsBorder: -1
            property real irisControlsBorderOpacity: -1
            property real irisControlsBackingOpacity: -1
            property int irisMonthRadius: -1
            property real irisMonthPad: -1
            property real irisMonthBorder: -1
            property real irisMonthBorderOpacity: -1
            property real irisMonthBackingOpacity: -1
            property int irisAgendaRadius: -1
            property real irisAgendaPad: -1
            property real irisAgendaBorder: -1
            property real irisAgendaBorderOpacity: -1
            property real irisAgendaBackingOpacity: -1
            property int irisTodoRadius: -1
            property real irisTodoPad: -1
            property real irisTodoBorder: -1
            property real irisTodoBorderOpacity: -1
            property real irisTodoBackingOpacity: -1
            property int irisNotesRadius: -1
            property real irisNotesPad: -1
            property real irisNotesBorder: -1
            property real irisNotesBorderOpacity: -1
            property real irisNotesBackingOpacity: -1
            property int irisTimersRadius: -1
            property real irisTimersPad: -1
            property real irisTimersBorder: -1
            property real irisTimersBorderOpacity: -1
            property real irisTimersBackingOpacity: -1
            property int irisScreenRadius: -1
            property real irisScreenPad: -1
            property real irisScreenBorder: -1
            property real irisScreenBorderOpacity: -1
            property real irisScreenBackingOpacity: -1
            property int irisVitalsRadius: -1
            property real irisVitalsPad: -1
            property real irisVitalsBorder: -1
            property real irisVitalsBorderOpacity: -1
            property real irisVitalsBackingOpacity: -1
            property int irisBatteryRadius: -1
            property real irisBatteryPad: -1
            property real irisBatteryBorder: -1
            property real irisBatteryBorderOpacity: -1
            property real irisBatteryBackingOpacity: -1
            property int irisWorldRadius: -1
            property real irisWorldPad: -1
            property real irisWorldBorder: -1
            property real irisWorldBorderOpacity: -1
            property real irisWorldBackingOpacity: -1
            property int irisDateRadius: -1
            property real irisDatePad: -1
            property real irisDateBorder: -1
            property real irisDateBorderOpacity: -1
            property real irisDateBackingOpacity: -1
            property int irisProfileRadius: -1
            property real irisProfilePad: -1
            property real irisProfileBorder: -1
            property real irisProfileBorderOpacity: -1
            property real irisProfileBackingOpacity: -1
            property int irisUptimeRadius: -1
            property real irisUptimePad: -1
            property real irisUptimeBorder: -1
            property real irisUptimeBorderOpacity: -1
            property real irisUptimeBackingOpacity: -1
            property int irisNewsRadius: -1
            property real irisNewsPad: -1
            property real irisNewsBorder: -1
            property real irisNewsBorderOpacity: -1
            property real irisNewsBackingOpacity: -1
            property bool irisCustomImageEnabled: false
            property real irisCustomImageScale: 1.0
            property string irisCustomImageAnchor: "free"
            property int irisCustomImageX: 216
            property int irisCustomImageY: 800
            property bool irisCustomImageLocked: false
            property real irisCustomImageOpacity: 1.0
            property string irisCustomImageBg: "card"
            property string irisCustomImageColor: ""
            property string irisCustomImageColor2: ""
            property bool irisCustomImageGradient: false
            property string irisCustomImageSize: "small"
            property string irisCustomImageOpts: ""
            property string irisCustomImageStyle: "inir"
            property int irisCustomImageRadius: -1
            property real irisCustomImagePad: -1
            property real irisCustomImageBorder: -1
            property real irisCustomImageBorderOpacity: -1
            property real irisCustomImageBackingOpacity: -1
            property bool irisEditorialEnabled: false
            property real irisEditorialScale: 1.0
            property string irisEditorialAnchor: "free"
            property int irisEditorialX: 120
            property int irisEditorialY: 840
            property bool irisEditorialLocked: false
            property real irisEditorialOpacity: 1.0
            property string irisEditorialBg: "card"
            property string irisEditorialColor: ""
            property string irisEditorialColor2: ""
            property bool irisEditorialGradient: false
            property string irisEditorialSize: "small"
            property string irisEditorialOpts: ""
            property string irisEditorialStyle: "inir"
            property int irisEditorialRadius: -1
            property real irisEditorialPad: -1
            property real irisEditorialBorder: -1
            property real irisEditorialBorderOpacity: -1
            property real irisEditorialBackingOpacity: -1
            property bool irisConverterEnabled: false
            property real irisConverterScale: 1.0
            property string irisConverterAnchor: "free"
            property int irisConverterX: 168
            property int irisConverterY: 880
            property bool irisConverterLocked: false
            property real irisConverterOpacity: 1.0
            property string irisConverterBg: "card"
            property string irisConverterColor: ""
            property string irisConverterColor2: ""
            property bool irisConverterGradient: false
            property string irisConverterSize: "small"
            property string irisConverterOpts: ""
            property string irisConverterStyle: "inir"
            property int irisConverterRadius: -1
            property real irisConverterPad: -1
            property real irisConverterBorder: -1
            property real irisConverterBorderOpacity: -1
            property real irisConverterBackingOpacity: -1
            property bool irisJpEnabled: false
            property real irisJpScale: 1.0
            property string irisJpAnchor: "free"
            property int irisJpX: 120
            property int irisJpY: 960
            property bool irisJpLocked: false
            property real irisJpOpacity: 1.0
            property string irisJpBg: "card"
            property string irisJpColor: ""
            property string irisJpColor2: ""
            property bool irisJpGradient: false
            property string irisJpSize: "small"
            property string irisJpOpts: ""
            property string irisJpStyle: "inir"
            property int irisJpRadius: -1
            property real irisJpPad: -1
            property real irisJpBorder: -1
            property real irisJpBorderOpacity: -1
            property real irisJpBackingOpacity: -1
            property bool irisVisualizerEnabled: false
            property real irisVisualizerScale: 1.0
            property string irisVisualizerAnchor: "free"
            property int irisVisualizerX: 168
            property int irisVisualizerY: 1000
            property bool irisVisualizerLocked: false
            property real irisVisualizerOpacity: 1.0
            property string irisVisualizerBg: "card"
            property string irisVisualizerColor: ""
            property string irisVisualizerColor2: ""
            property bool irisVisualizerGradient: false
            property string irisVisualizerSize: "small"
            property string irisVisualizerOpts: ""
            property string irisVisualizerStyle: "inir"
            property int irisVisualizerRadius: -1
            property real irisVisualizerPad: -1
            property real irisVisualizerBorder: -1
            property real irisVisualizerBorderOpacity: -1
            property real irisVisualizerBackingOpacity: -1
        }
    }

    // brand identity master (mark + name), the cross-cutting identity shared with
    // doctor, the Hub editor and the rest of the shell. the always-on
    // pill seeds it; these defaults cover its absence, so no seed is written here.
    FileView {
        id: brandFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        JsonAdapter {
            id: brandAdapter
            property string markText: "力"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }

    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
