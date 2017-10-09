# This is the core set of universal, cross-platform keymaps. This is
# extended in the following places:
#
# 1. keymaps/base.json - (This file) Core, universal keymaps across all platforms
# 2. keymaps/base-darwin.json - Any universal mac-only keymaps
# 3. keymaps/base-win32.json - Any universal windows-only keymaps
# 4. keymaps/base-darwin.json - Any universal linux-only keymaps
# 5. keymaps/templates/Gmail.json - Gmail key bindings for all platforms
# 6. keymaps/templates/Outlook.json - Outlook key bindings for all platforms
# 7. keymaps/templates/Apple Mail.json - Mac Mail key bindings for all platforms
# 8. some/package/keymaps/package.json - Keymaps for a specific package
# 9. <config-dir>/keymap.json - Custom user-specific overrides
#
# NOTE: We have a special N1 extension called `mod` that automatically
# uses `command` on mac and `ctrl` on windows and linux. This covers most
# cross-platform cases. For truely platform-specific features, use the
# platform keymap extensions.
