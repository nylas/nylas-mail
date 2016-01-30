fs = require 'fs'

style = null

module.exports =
  activate: ->
    NylasEnv.commands.add "body", "window:toggle-screenshot-mode", ->
      if not style
        style = document.createElement('style')
        style.innerText = fs.readFileSync(path.join(__dirname, '..', 'assets','font-override.css')).toString()

      if style.parentElement
        document.body.removeChild(style)
      else
        document.body.appendChild(style)

  deactivate: ->
    if style.parentElement
      document.body.removeChild(style)

  serialize: ->
