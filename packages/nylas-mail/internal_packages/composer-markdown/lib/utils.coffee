
class Utils

  @getTextFromHtml: (html) ->
    div = document.createElement('div')
    div.innerHTML = html
    div.textContent ? div.innerText

module.exports = Utils
