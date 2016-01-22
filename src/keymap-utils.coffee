KeymapUtils =
  cmdCtrlPreprocessor: (keymap={}) ->
    re = /(cmdctrl|ctrlcmd)/i
    if process.platform is "darwin"
      cmdctrl = 'cmd'
    else
      cmdctrl = 'ctrl'

    for selector, keyBindings of keymap
      normalizedBindings = {}
      for keystrokes, command of keyBindings
        keystrokes = keystrokes.replace(re, cmdctrl)
        normalizedBindings[keystrokes] = command
      keymap[selector] = normalizedBindings

    return keymap

module.exports = KeymapUtils
