"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.activate = activate;
exports.deactivate = deactivate;

var _nylasExports = require("nylas-exports");

function activate() {
  // FIXME: Use the nylas:// protocol handlers once we upgrade Electron past
  // v30.0
  // See: https://github.com/atom/electron/issues/1123
  _nylasExports.SoundRegistry.register({
    "send": ["internal_packages", "custom-sounds", "CUSTOM_UI_Send_v1.ogg"],
    "confirm": ["internal_packages", "custom-sounds", "CUSTOM_UI_Confirm_v1.ogg"],
    "hit-send": ["internal_packages", "custom-sounds", "CUSTOM_UI_HitSend_v1.ogg"],
    "new-mail": ["internal_packages", "custom-sounds", "CUSTOM_UI_NewMail_v1.ogg"]
  });
}

function deactivate() {
  _nylasExports.SoundRegistry.unregister(["send", "confirm", "hit-send", "new-mail"]);
}
//# sourceMappingURL=main.js.map
