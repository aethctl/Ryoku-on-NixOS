pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import inir.services

Singleton {
    id: root

    function capitalized(text: string): string {
        const value = String(text ?? "")
        return value.length > 0 ? value.charAt(0).toUpperCase() + value.slice(1) : value
    }

    function eventDate(event: var): var {
        return new Date(event?.dateTime ?? event?.startDate ?? 0)
    }

    function upcomingEvents(from: var, days: int): var {
        const now = new Date(from)
        const local = Array.from(Events.getUpcomingEvents(days) ?? [])
        const external = Array.from(CalendarSync.getUpcomingEvents(days) ?? [])
        const today = new Date(now)
        today.setHours(0, 0, 0, 0)
        const allDay = Array.from(CalendarSync.getEventsForDate(today) ?? []).filter(event => event.allDay)
        return local.concat(external, allDay.filter(event => !external.includes(event)))
            .sort((a, b) => root.eventDate(a) - root.eventDate(b))
    }

    function hasEvents(date: var): bool {
        return (Events.getEventsForDate(date) ?? []).length > 0
            || (CalendarSync.getEventsForDate(date) ?? []).length > 0
    }

    function eventTitle(event: var): string {
        return String(event?.title || event?.summary || Translation.tr("Event"))
    }

    function eventTint(event: var, fallback: color): color {
        const tint = String(event?.sourceColor ?? "")
        return tint.length > 0 ? tint : fallback
    }

    function eventWhen(event: var, now: var): string {
        if (!event)
            return ""
        const when = root.eventDate(event)
        const today = new Date(now)
        today.setHours(0, 0, 0, 0)
        const day = new Date(when)
        day.setHours(0, 0, 0, 0)
        const days = Math.round((day.getTime() - today.getTime()) / 86400000)
        const time = event.allDay ? Translation.tr("All day")
            : Qt.locale().toString(when, Qt.locale().timeFormat(Locale.ShortFormat))
        const minutes = Math.round((when.getTime() - new Date(now).getTime()) / 60000)
        if (!event.allDay && minutes >= 0 && minutes < 60)
            return minutes < 1 ? Translation.tr("Now") : Translation.tr("In %1 min").arg(minutes)
        if (days === 0)
            return time
        if (days === 1)
            return Translation.tr("Tomorrow · %1").arg(time)
        return root.capitalized(Qt.locale().toString(when, "dddd")) + " · " + time
    }
}
