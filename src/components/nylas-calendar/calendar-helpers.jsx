import {Utils} from 'nylas-exports'

export function calcColor(calendarId, opacity) {
  const alpha = opacity || 0.35;
  const hue = NylasEnv.config.get(`calendar.colors.${calendarId}`) || Utils.hueForString(calendarId);
  return `hsla(${hue}, 50%, 45%, ${alpha})`
}
