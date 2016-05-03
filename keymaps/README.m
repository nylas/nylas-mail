# This is the core set of universal, cross-platform keymaps. This is
# extended in the following places:
#
# 1. keymaps/base.cson - (This file) Core, universal keymaps across all platforms
# 2. keymaps/base-darwin.cson - Any universal mac-only keymaps
# 3. keymaps/base-win32.cson - Any universal windows-only keymaps
# 4. keymaps/base-darwin.cson - Any universal linux-only keymaps
# 5. keymaps/templates/Gmail.cson - Gmail key bindings for all platforms
# 6. keymaps/templates/Outlook.cson - Outlook key bindings for all platforms
# 7. keymaps/templates/Apple Mail.cson - Mac Mail key bindings for all platforms
# 8. some/package/keymaps/package.cson - Keymaps for a specific package
# 9. ~/.nylas/keymap.cson - Custom user-specific overrides
#
# NOTE: We have a special N1 extension called `mod` that automatically
# uses `cmd` on mac and `ctrl` on windows and linux. This covers most
# cross-platform cases. For truely platform-specific features, use the
# platform keymap extensions.
