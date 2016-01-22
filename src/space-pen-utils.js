(function() {
  var macModifierKeyMap, nonMacModifierKeyMap, plus, shiftKeyMap

  macModifierKeyMap = {
    cmd: '\u2318',
    ctrl: '\u2303',
    alt: '\u2325',
    option: '\u2325',
    shift: '\u21e7',
    enter: '\u23ce',
    left: '\u2190',
    right: '\u2192',
    up: '\u2191',
    down: '\u2193'
  };

  nonMacModifierKeyMap = {
    cmd: 'Cmd',
    ctrl: 'Ctrl',
    alt: 'Alt',
    option: 'Alt',
    shift: 'Shift',
    enter: 'Enter',
    left: 'Left',
    right: 'Right',
    up: 'Up',
    down: 'Down'
  };

  shiftKeyMap = {
    '~': '`',
    '_': '-',
    '+': '=',
    '|': '\\',
    '{': '[',
    '}': ']',
    ':': ';',
    '"': '\'',
    '<': ',',
    '>': '.',
    '?': '/'
  };

  plus = {
    capitalize: function(word) {
      if (!word) {
        return '';
      }
      if (word.toLowerCase() === 'github') {
        return 'GitHub';
      } else {
        return word[0].toUpperCase() + word.slice(1);
      }
    },
    humanizeKey: function(key, platform) {
      var modifierKeyMap;
      if (platform == null) {
        platform = process.platform;
      }
      if (!key) {
        return key;
      }
      modifierKeyMap = platform === 'darwin' ? macModifierKeyMap : nonMacModifierKeyMap;
      if (modifierKeyMap[key]) {
        return modifierKeyMap[key];
      } else if (key.length === 1 && (shiftKeyMap[key] != null)) {
        return [modifierKeyMap.shift, shiftKeyMap[key]];
      } else if (key.length === 1 && key === key.toUpperCase() && key.toUpperCase() !== key.toLowerCase()) {
        return [modifierKeyMap.shift, key.toUpperCase()];
      } else if (key.length === 1 || /f[0-9]{1,2}/.test(key)) {
        return key.toUpperCase();
      } else {
        if (platform === 'darwin') {
          return key;
        } else {
          return plus.capitalize(key);
        }
      }
    },
    humanizeKeystroke: function(keystroke, platform) {
      var humanizedKeystrokes, index, key, keys, keystrokes, splitKeystroke, _i, _j, _len, _len1;
      if (platform == null) {
        platform = process.platform;
      }
      if (!keystroke) {
        return keystroke;
      }
      keystrokes = keystroke.split(' ');
      humanizedKeystrokes = [];
      for (_i = 0, _len = keystrokes.length; _i < _len; _i++) {
        keystroke = keystrokes[_i];
        keys = [];
        splitKeystroke = keystroke.split('-');
        for (index = _j = 0, _len1 = splitKeystroke.length; _j < _len1; index = ++_j) {
          key = splitKeystroke[index];
          if (key === '' && splitKeystroke[index - 1] === '') {
            key = '-';
          }
          if (key) {
            keys.push(plus.humanizeKey(key, platform));
          }
        }
        keys = _.uniq(_.flatten(keys));
        if (platform === 'darwin') {
          keys = keys.join('');
        } else {
          keys = keys.join('+');
        }
        humanizedKeystrokes.push(keys);
      }
      return humanizedKeystrokes.join(' ');
    }
  }

  module.exports = plus

}).call(this)
