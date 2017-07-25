import {SoundRegistry} from 'nylas-exports'

export function activate() {
  // FIXME: Use the nylas:// protocol handlers once we upgrade Electron past
  // v30.0
  // See: https://github.com/atom/electron/issues/1123
  SoundRegistry.register({
    "send": ["internal_packages", "nylas-private-sounds", "NYLAS_UI_Send_v1.ogg"],
    "confirm": ["internal_packages", "nylas-private-sounds", "NYLAS_UI_Confirm_v1.ogg"],
    "hit-send": ["internal_packages", "nylas-private-sounds", "NYLAS_UI_HitSend_v1.ogg"],
    "new-mail": ["internal_packages", "nylas-private-sounds", "NYLAS_UI_NewMail_v1.ogg"],
  })
}

export function deactivate() {
  SoundRegistry.unregister(["send", "confirm", "hit-send", "new-mail"])
}
