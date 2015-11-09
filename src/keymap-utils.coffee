KeymapUtils =
  cmdCtrlPreprocessor: (keymap={}) ->
    re = /(cmdctrl|ctrlcmd)/i
    for selector, keyBindings of keymap
      normalizedBindings = {}
      for keystrokes, command of keyBindings
        if re.test keystrokes
          if process.platform is "darwin"
            newKeystrokes1= keystrokes.replace(re, "ctrl")
            newKeystrokes2= keystrokes.replace(re, "cmd")
            normalizedBindings[newKeystrokes1] = command
            normalizedBindings[newKeystrokes2] = command
          else
            newKeystrokes = keystrokes.replace(re, "ctrl")
            normalizedBindings[newKeystrokes] = command
        else
          normalizedBindings[keystrokes] = command
      keymap[selector] = normalizedBindings

    return keymap

module.exports = KeymapUtils
