/* eslint-disable */
/**
 * mapping of special keycodes to their corresponding keys
 *
 * everything in this dictionary cannot use keypress events
 * so it has to be here to map to the correct keycodes for
 * keyup/keydown events
 *
 * @type {Object}
 */
var _MAP = {
  '8': 'backspace',
  '9': 'tab',
  '13': 'enter',
  '16': 'shift',
  '17': 'ctrl',
  '18': 'alt',
  '20': 'capslock',
  '27': 'esc',
  '32': 'space',
  '33': 'pageup',
  '34': 'pagedown',
  '35': 'end',
  '36': 'home',
  '37': 'left',
  '38': 'up',
  '39': 'right',
  '40': 'down',
  '45': 'ins',
  '46': 'del',
  '91': 'meta',
  '93': 'meta',
  '224': 'meta',
};

/**
 * mapping for special characters so they can support
 *
 * this dictionary is only used incase you want to bind a
 * keyup or keydown event to one of these keys
 *
 * @type {Object}
 */
var _KEYCODE_MAP = {
  '106': '*',
  '107': '+',
  '109': '-',
  '110': '.',
  '111': '/',
  '186': ';',
  '187': '=',
  '188': ',',
  '189': '-',
  '190': '.',
  '191': '/',
  '192': '`',
  '219': '[',
  '220': '\\',
  '221': ']',
  '222': "'",
};

/**
 * this is a mapping of keys that require shift on a US keypad
 * back to the non shift equivelents
 *
 * this is so you can use keyup events with these keys
 *
 * note that this will only work reliably on US keyboards
 *
 * @type {Object}
 */
var _SHIFT_MAP = {
  '~': '`',
  '!': '1',
  '@': '2',
  '#': '3',
  $: '4',
  '%': '5',
  '^': '6',
  '&': '7',
  '*': '8',
  '(': '9',
  ')': '0',
  _: '-',
  '+': '=',
  ':': ';',
  '"': "'",
  '<': ',',
  '>': '.',
  '?': '/',
  '|': '\\',
};

/**
 * this is a list of special strings you can use to map
 * to modifier keys when you specify your keyboard shortcuts
 *
 * @type {Object}
 */
var _SPECIAL_ALIASES = {
  option: 'alt',
  command: 'meta',
  return: 'enter',
  escape: 'esc',
  plus: '+',
  mod: /Mac|iPod|iPhone|iPad/.test(navigator.platform) ? 'meta' : 'ctrl',
};

/**
 * variable to store the flipped version of _MAP from above
 * needed to check if we should use keypress or not when no action
 * is specified
 *
 * @type {Object|undefined}
 */
var _REVERSE_SHIFT_MAP = {};
for (var key of Object.keys(_SHIFT_MAP)) {
  _REVERSE_SHIFT_MAP[_SHIFT_MAP[key]] = key;
}

/**
 * loop through the f keys, f1 to f19 and add them to the map
 * programatically
 */
for (var i = 1; i < 20; ++i) {
  _MAP[111 + i] = 'f' + i;
}

/**
 * loop through to map numbers on the numeric keypad
 */
for (i = 0; i <= 9; ++i) {
  _MAP[i + 96] = i;
}

function characterFromEvent(e) {
  // for keypress events we should return the character as is
  if (e.type == 'keypress') {
    var character = String.fromCharCode(e.which);

    // if the shift key is not pressed then it is safe to assume
    // that we want the character to be lowercase.  this means if
    // you accidentally have caps lock on then your key bindings
    // will continue to work
    //
    // the only side effect that might not be desired is if you
    // bind something like 'A' cause you want to trigger an
    // event when capital A is pressed caps lock will no longer
    // trigger the event.  shift+a will though.
    if (!e.shiftKey) {
      character = character.toLowerCase();
    }

    return character;
  }

  // for non keypress events the special maps are needed
  if (_MAP[e.which]) {
    return _MAP[e.which];
  }

  if (_KEYCODE_MAP[`${e.which}`]) {
    return _KEYCODE_MAP[`${e.which}`];
  }

  // if it is not in the special map

  // with keydown and keyup events the character seems to always
  // come in as an uppercase character whether you are pressing shift
  // or not.  we should make sure it is always lowercase for comparisons
  return String.fromCharCode(e.which).toLowerCase();
}

/**
 * takes a key event and figures out what the modifiers are
 *
 * @param {Event} e
 * @returns {Array}
 */
function eventModifiers(e) {
  var modifiers = [];

  if (e.shiftKey) {
    modifiers.push('shift');
  }

  if (e.altKey) {
    modifiers.push('alt');
  }

  if (e.ctrlKey) {
    modifiers.push('ctrl');
  }

  if (e.metaKey) {
    modifiers.push('meta');
  }

  return modifiers;
}

function keyAndModifiersForEvent(e) {
  var eventKey = characterFromEvent(e);
  var eventMods = eventModifiers(e);
  if (_REVERSE_SHIFT_MAP[eventKey] && eventMods.indexOf('shift') !== -1) {
    eventKey = _REVERSE_SHIFT_MAP[eventKey];
    eventMods = eventMods.filter(k => k !== 'shift');
  }
  return [eventKey, eventMods];
}

module.exports = { characterFromEvent, eventModifiers, keyAndModifiersForEvent };
