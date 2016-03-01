import NylasStore from 'nylas-store';
import fs from 'fs';
import path from 'path';
import {Utils, MessageBodyProcessor} from 'nylas-exports';
import AutoloadImagesActions from './autoload-images-actions';

const ImagesRegexp = /((?:src|background|placeholder|icon|background|poster|srcset)\s*=\s*['"]?(?=\w*:\/\/)|:\s*url\()+([^"'\)]*)/gi;

class AutoloadImagesStore extends NylasStore {

  constructor() {
    super();

    this.ImagesRegexp = ImagesRegexp;

    this._whitelistEmails = {}
    this._whitelistMessageIds = {}
    this._whitelistEmailsPath = path.join(NylasEnv.getConfigDirPath(), 'autoload-images-whitelist.txt');

    this._loadWhitelist();

    this.listenTo(AutoloadImagesActions.temporarilyEnableImages, this._onTemporarilyEnableImages);
    this.listenTo(AutoloadImagesActions.permanentlyEnableImages, this._onPermanentlyEnableImages);

    NylasEnv.config.onDidChange('core.reading.autoloadImages', ()=> {
      MessageBodyProcessor.resetCache()
    });
  }

  shouldBlockImagesIn = (message)=> {
    if (NylasEnv.config.get('core.reading.autoloadImages') === true) {
      return false;
    }
    if (this._whitelistEmails[Utils.toEquivalentEmailForm(message.fromContact().email)]) {
      return false;
    }
    if (this._whitelistMessageIds[message.id]) {
      return false;
    }

    return ImagesRegexp.test(message.body);
  }

  _loadWhitelist = ()=> {
    fs.exists(this._whitelistEmailsPath, (exists)=> {
      if (!exists) { return; }

      fs.readFile(this._whitelistEmailsPath, (err, body)=> {
        if (err || !body) { return console.log(err); }

        this._whitelistEmails = {}
        body.toString().split(/[\n\r]+/).forEach((email)=> {
          this._whitelistEmails[Utils.toEquivalentEmailForm(email)] = true;
        });
      });
    });
  }

  _saveWhitelist = ()=> {
    const data = Object.keys(this._whitelistEmails).join('\n');
    fs.writeFile(this._whitelistEmailsPath, data, (err) => {
      if (err) {
        console.error(`AutoloadImagesStore could not save whitelist: ${err.toString()}`);
      }
    });
  }

  _onTemporarilyEnableImages = (message)=> {
    this._whitelistMessageIds[message.id] = true;
    MessageBodyProcessor.resetCache();
  }

  _onPermanentlyEnableImages = (message)=> {
    const email = Utils.toEquivalentEmailForm(message.fromContact().email);
    this._whitelistEmails[email] = true;
    MessageBodyProcessor.resetCache();
    setTimeout(this._saveWhitelist, 1);
  }
}

export default new AutoloadImagesStore();
