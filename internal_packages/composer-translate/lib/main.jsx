// // Translation Plugin
// Last Revised: Feb. 29, 2016 by Ben Gotow

// TranslateButton is a simple React component that allows you to select
// a language from a popup menu and translates draft text into that language.

import request from 'request'

import {
  React,
  ReactDOM,
  ComponentRegistry,
  QuotedHTMLTransformer,
  DraftStore,
  Actions,
} from 'nylas-exports';

import {
  Menu,
  RetinaImg,
} from 'nylas-component-kit';

const YandexTranslationURL = 'https://translate.yandex.net/api/v1.5/tr.json/translate';
const YandexTranslationKey = 'trnsl.1.1.20150415T044616Z.24814c314120d022.0a339e2bc2d2337461a98d5ec9863fc46e42735e';
const YandexLanguages = {
  'English': 'en',
  'Spanish': 'es',
  'Russian': 'ru',
  'Chinese': 'zh',
  'French': 'fr',
  'German': 'de',
  'Italian': 'it',
  'Japanese': 'ja',
  'Portuguese': 'pt',
  'Korean': 'ko',
};

class TranslateButton extends React.Component {

  // Adding a `displayName` makes debugging React easier
  static displayName = 'TranslateButton';

  // Since our button is being injected into the Composer Footer,
  // we receive the local id of the current draft as a `prop` (a read-only
  // property). Since our code depends on this prop, we mark it as a requirement.
  static propTypes = {
    draftClientId: React.PropTypes.string.isRequired,
  };

  _onError(error) {
    Actions.closePopover()
    const dialog = require('remote').require('dialog');
    dialog.showErrorBox('Language Conversion Failed', error.toString());
  }

  _onTranslate = (lang) => {
    Actions.closePopover()

    // Obtain the session for the current draft. The draft session provides us
    // the draft object and also manages saving changes to the local cache and
    // Nilas API as multiple parts of the application touch the draft.
    DraftStore.sessionForClientId(this.props.draftClientId).then((session)=> {
      const draftHtml = session.draft().body;
      const text = QuotedHTMLTransformer.removeQuotedHTML(draftHtml);

      const query = {
        key: YandexTranslationKey,
        lang: YandexLanguages[lang],
        text: text,
        format: 'html',
      };

      // Use Node's `request` library to perform the translation using the Yandex API.
      request({url: YandexTranslationURL, qs: query}, (error, resp, data)=> {
        if (resp.statusCode !== 200) {
          this._onError(error);
          return;
        }

        const json = JSON.parse(data);
        let translated = json.text.join('');

        // The new text of the draft is our translated response, plus any quoted text
        // that we didn't process.
        translated = QuotedHTMLTransformer.appendQuotedHTML(translated, draftHtml);

        // To update the draft, we add the new body to it's session. The session object
        // automatically marshalls changes to the database and ensures that others accessing
        // the same draft are notified of changes.
        session.changes.add({body: translated});
        session.changes.commit();
      });
    });
  };

  _onClickTranslateButton = ()=> {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    Actions.openPopover(
      this._renderPopover(),
      {originRect: buttonRect, direction: 'up'}
    )
  };

  // Helper method that will render the contents of our popover.
  _renderPopover() {
    const headerComponents = [
      <span>Translate:</span>,
    ];
    return (
      <Menu
        className="translate-language-picker"
        items={ Object.keys(YandexLanguages) }
        itemKey={ (item)=> item }
        itemContent={ (item)=> item }
        headerComponents={headerComponents}
        defaultSelectedIndex={-1}
        onSelect={this._onTranslate}
      />
    )
  }

  // The `render` method returns a React Virtual DOM element. This code looks
  // like HTML, but don't be fooled. The JSX preprocessor converts
  // `<a href="http://facebook.github.io/react/">Hello!</a>`
  // into Javascript objects which describe the HTML you want:
  // `React.createElement('a', {href: 'http://facebook.github.io/react/'}, 'Hello!')`

  // We're rendering a `Menu` inside our Popover, and using a `RetinaImg` for the button.
  // These components are part of N1's standard `nylas-component-kit` library,
  // and make it easy to build interfaces that match the rest of N1's UI.
  //
  // For example, using the `RetinaImg` component makes it easy to display an
  // image from our package. `RetinaImg` will automatically chose the best image
  // format for our display.
  render() {
    return (
      <button
        tabIndex={-1}
        className="btn btn-toolbar pull-right"
        onClick={this._onClickTranslateButton}
        title="Translate email body…">
        <RetinaImg
          mode={RetinaImg.Mode.ContentIsMask}
          url="nylas://composer-translate/assets/icon-composer-translate@2x.png" />
        &nbsp;
        <RetinaImg
          name="icon-composer-dropdown.png"
          mode={RetinaImg.Mode.ContentIsMask}/>
      </button>
    );
  }
}

/*
All packages must export a basic object that has at least the following 3
methods:

1. `activate` - Actions to take once the package gets turned on.
Pre-enabled packages get activated on N1 bootup. They can also be
activated manually by a user.

2. `deactivate` - Actions to take when a package gets turned off. This can
happen when a user manually disables a package.

3. `serialize` - A simple serializable object that gets saved to disk
before N1 quits. This gets passed back into `activate` next time N1 boots
up or your package is manually activated.
*/

export function activate() {
  ComponentRegistry.register(TranslateButton, {
    role: 'Composer:ActionButton',
  });
}

export function serialize() {

}

export function deactivate() {
  ComponentRegistry.unregister(TranslateButton);
}
