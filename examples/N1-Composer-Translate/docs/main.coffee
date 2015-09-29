# # Translation Plugin
# Last Revised: April 23, 2015 by Ben Gotow
#
# TranslateButton is a simple React component that allows you to select
# a language from a popup menu and translates draft text into that language.
#

request = require 'request'

{Utils,
 React,
 ComponentRegistry,
 DraftStore} = require 'nylas-exports'
{Menu,
 RetinaImg,
 Popover} = require 'nylas-component-kit'

YandexTranslationURL = 'https://translate.yandex.net/api/v1.5/tr.json/translate'
YandexTranslationKey = 'trnsl.1.1.20150415T044616Z.24814c314120d022.0a339e2bc2d2337461a98d5ec9863fc46e42735e'
YandexLanguages =
  'English': 'en'
  'Spanish': 'es'
  'Russian': 'ru'
  'Chinese': 'zh'
  'French': 'fr'
  'German': 'de'
  'Italian': 'it'
  'Japanese': 'ja'
  'Portuguese': 'pt'
  'Korean': 'ko'

class TranslateButton extends React.Component

  # Adding a `displayName` makes debugging React easier
  @displayName: 'TranslateButton'

  # Since our button is being injected into the Composer Footer,
  # we receive the local id of the current draft as a `prop` (a read-only
  # property). Since our code depends on this prop, we mark it as a requirement.
  #
  @propTypes:
    draftLocalId: React.PropTypes.string.isRequired

  # The `render` method returns a React Virtual DOM element. This code looks
  # like HTML, but don't be fooled. The CJSX preprocessor converts
  #
  # `<a href="http://facebook.github.io/react/">Hello!</a>`
  #
  # into Javascript objects which describe the HTML you want:
  #
  # `React.createElement('a', {href: 'http://facebook.github.io/react/'}, 'Hello!')`
  #
  # We're rendering a `Popover` with a `Menu` inside. These components are part
  # of N1's standard `nylas-component-kit` library, and make it easy to build
  # interfaces that match the rest of N1's UI.
  #
  render: =>
    React.createElement(Popover, {"ref": "popover",  \
             "className": "translate-language-picker pull-right",  \
             "buttonComponent": (@_renderButton())},
      React.createElement(Menu, {"items": ( Object.keys(YandexLanguages) ),  \
            "itemKey": ( (item) -> item ),  \
            "itemContent": ( (item) -> item ),  \
            "onSelect": (@_onTranslate)
            })
    )

  # Helper method to render the button that will activate the popover. Using the
  # `RetinaImg` component makes it easy to display an image from our package.
  # `RetinaImg` will automatically chose the best image format for our display.
  #
  _renderButton: =>
    React.createElement("button", {"className": "btn btn-toolbar"}, """
      Translate
""", React.createElement(RetinaImg, {"name": "toolbar-chevron.png"})
    )

  _onTranslate: (lang) =>
    @refs.popover.close()

    # Obtain the session for the current draft. The draft session provides us
    # the draft object and also manages saving changes to the local cache and
    # Nilas API as multiple parts of the application touch the draft.
    #
    session = DraftStore.sessionForLocalId(@props.draftLocalId)
    session.prepare().then =>
      body = session.draft().body
      bodyQuoteStart = Utils.quotedTextIndex(body)

      # Identify the text we want to translate. We need to make sure we
      # don't translate quoted text.
      if bodyQuoteStart > 0
        text = body.substr(0, bodyQuoteStart)
      else
        text = body

      query =
        key: YandexTranslationKey
        lang: YandexLanguages[lang]
        text: text
        format: 'html'

      # Use Node's `request` library to perform the translation using the Yandex API.
      request {url: YandexTranslationURL, qs: query}, (error, resp, data) =>
        return @_onError(error) unless resp.statusCode is 200
        json = JSON.parse(data)

        # The new text of the draft is our translated response, plus any quoted text
        # that we didn't process.
        translated = json.text.join('')
        translated += body.substr(bodyQuoteStart) if bodyQuoteStart > 0

        # To update the draft, we add the new body to it's session. The session object
        # automatically marshalls changes to the database and ensures that others accessing
        # the same draft are notified of changes.
        session.changes.add(body: translated)
        session.changes.commit()

  _onError: (error) =>
    @refs.popover.close()
    dialog = require('remote').require('dialog')
    dialog.showErrorBox('Geolocation Failed', error.toString())


module.exports =
  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state) ->
    ComponentRegistry.register TranslateButton,
      role: 'Composer:ActionButton'

  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  #
  serialize: ->

  # This **optional** method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  #
  deactivate: ->
    ComponentRegistry.unregister(TranslateButton)
