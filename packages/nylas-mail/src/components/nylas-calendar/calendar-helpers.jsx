import {Utils} from 'nylas-exports'

export function calcColor(calendarId) {
  let bgColor = NylasEnv.config.get(`calendar.colors.${calendarId}`)
  if (!bgColor) {
    const hue = Utils.hueForString(calendarId);
    bgColor = `hsla(${hue}, 50%, 45%, 0.35)`
  }
  return bgColor
}
