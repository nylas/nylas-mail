import _ from 'underscore';
import MailspringStore from 'mailspring-store';
import { FocusedContactsStore } from 'mailspring-exports';

// This package uses the Flux pattern - our Store is a small singleton that
// observes other parts of the application and vends data to our React
// component. If the user could interact with the GithubSidebar, this store
// would also listen for `Actions` emitted by our React components.
class GithubUserStore extends MailspringStore {
  constructor() {
    super();

    this._profile = null;
    this._cache = {};
    this._loading = false;
    this._error = null;

    // Register a callback with the FocusedContactsStore. This will tell us
    // whenever the selected person has changed so we can refresh our data.
    this.listenTo(FocusedContactsStore, this._onFocusedContactChanged);
  }

  // Getter Methods

  profileForFocusedContact() {
    return this._profile;
  }

  loading() {
    return this._loading;
  }

  error() {
    return this._error;
  }

  // Called when the FocusedContactStore `triggers`, notifying us that the data
  // it vends has changed.
  _onFocusedContactChanged = () => {
    // Grab the new focused contact
    const contact = FocusedContactsStore.focusedContact();

    // First, clear the contact that we're currently showing and `trigger`. Since
    // our React component observes our store, `trigger` causes our React component
    // to re-render.
    this._error = null;
    this._profile = null;

    if (contact) {
      this._profile = this._cache[contact.email];
      if (this._profile === undefined) {
        // Make a Github search request to find the matching user profile
        this._githubFetchProfile(contact.email);
      }
    }

    this.trigger(this);
  };

  async _githubFetchProfile(email) {
    this._loading = true;

    try {
      const data = await this._githubRequest(`https://api.github.com/search/users?q=${email}`);

      if (data.message !== undefined) {
        console.warn(data.message);
      }

      // Sometimes we get rate limit errors, etc., so we need to check and make
      // sure we've gotten items before pulling the first one.
      let profile = false;
      if (data && data.items && data.items[0]) {
        profile = data.items[0];
      }

      // If a profile was found, make a second request for the user's public
      // repositories.
      if (profile !== false) {
        profile.repos = [];
        const repos = await this._githubRequest(
          `https://api.github.com/search/repositories?q=user:${profile.login}&sort=stars&order=desc`
        );
        // Sort the repositories by their stars (`-` for descending order)
        profile.repos = _.sortBy(repos.items, repo => -repo.stargazers_count);
        // Trigger so that our React components refresh their state and display
        // the updated data.
        this.trigger(this);
      }

      this._loading = false;
      this._profile = this._cache[email] = profile;
      this.trigger(this);
    } catch (err) {
      // fail silently
    }
  }

  // Wrap the Node `request` library and pass the User-Agent header, which is required
  // by Github's API. Also pass `json:true`, which causes responses to be automatically
  // parsed.
  async _githubRequest(url) {
    const headers = new Headers();
    headers.append('User-Agent', 'fetch-request');
    const resp = await fetch(url, { headers });
    if (!resp.ok) {
      throw new Error('Sorry, we were unable to complete the translation request.');
    }
    return resp.json();
  }
}

export default new GithubUserStore();
