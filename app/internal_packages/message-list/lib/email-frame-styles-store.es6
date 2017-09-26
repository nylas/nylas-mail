import MailspringStore from 'mailspring-store';

class EmailFrameStylesStore extends MailspringStore {
  styles() {
    if (!this._styles) {
      this._findStyles();
      this._listenToStyles();
    }
    return this._styles;
  }

  _findStyles = () => {
    this._styles = '';
    for (const sheet of Array.from(
      document.querySelectorAll('[source-path*="email-frame.less"]')
    )) {
      this._styles += `\n${sheet.innerText}`;
    }
    this._styles = this._styles.replace(/.ignore-in-parent-frame/g, '');
    this.trigger();
  };

  _listenToStyles() {
    const target = document.getElementsByTagName('managed-styles')[0];
    this._mutationObserver = new MutationObserver(this._findStyles);
    this._mutationObserver.observe(target, { attributes: true, subtree: true, childList: true });
  }

  _unlistenToStyles() {
    if (this._mutationObserver) {
      this._mutationObserver.disconnect();
    }
  }
}

export default new EmailFrameStylesStore();
