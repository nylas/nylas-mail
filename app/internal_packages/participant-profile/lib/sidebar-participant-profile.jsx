import {
  IdentityStore,
  FeatureUsageStore,
  React,
  PropTypes,
  DOMUtils,
  RegExpUtils,
  Utils,
} from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';

import ParticipantProfileDataSource from './participant-profile-data-source';

/* We expect ParticipantProfileDataSource.find to return the
  * following schema:
  * {
  *    profilePhotoUrl: string
  *    bio: string
  *    location: string
  *    currentTitle: string
  *    currentEmployer: string
  *    socialProfiles: hash keyed by type: ('twitter', 'facebook' etc)
  *      url: string
  *      handle: string
  * }
  */

export default class SidebarParticipantProfile extends React.Component {
  static displayName = 'SidebarParticipantProfile';

  static propTypes = {
    contact: PropTypes.object,
    contactThreads: PropTypes.array,
  };

  static containerStyles = {
    order: 0,
  };

  constructor(props) {
    super(props);

    this.state = {
      loaded: false,
      loading: false,
      trialing: !IdentityStore.hasProFeatures(),
    };
    const contactState = ParticipantProfileDataSource.getCache(props.contact.email);
    if (contactState) {
      this.state = Object.assign(this.state, { loaded: true }, contactState);
    }
  }

  componentDidMount() {
    this._mounted = true;
    if (!this.state.loaded && !this.state.trialing) {
      this._findContact();
    }
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _onClickedToTry = async () => {
    try {
      await FeatureUsageStore.asyncUseFeature('contact-profiles', {
        usedUpHeader: 'All Contact Previews Used',
        usagePhrase: 'view contact profiles for',
        iconUrl: 'mailspring://participant-profile/assets/ic-contact-profile-modal@2x.png',
      });
    } catch (err) {
      // user does not have access to this feature
      return;
    }
    this._findContact();
  };

  async _findContact() {
    this.setState({ loading: true });
    ParticipantProfileDataSource.find(this.props.contact.email).then(result => {
      if (!this._mounted) {
        return;
      }
      this.setState(Object.assign({ loading: false, loaded: true }, result));
    });
  }

  _renderProfilePhoto() {
    if (this.state.profilePhotoUrl) {
      return (
        <div className="profile-photo-wrap">
          <div className="profile-photo">
            <img alt="Profile" src={this.state.profilePhotoUrl} />
          </div>
        </div>
      );
    }
    return this._renderDefaultProfileImage();
  }

  _renderDefaultProfileImage() {
    const hue = Utils.hueForString(this.props.contact.email);
    const bgColor = `hsl(${hue}, 50%, 45%)`;
    const abv = this.props.contact.nameAbbreviation();
    return (
      <div className="profile-photo-wrap">
        <div className="profile-photo">
          <div className="default-profile-image" style={{ backgroundColor: bgColor }}>
            {abv}
          </div>
        </div>
      </div>
    );
  }

  _renderCorePersonalInfo() {
    const fullName = this.props.contact.fullName();
    let renderName = false;
    if (fullName !== this.props.contact.email) {
      renderName = (
        <div className="selectable full-name" onClick={this._select}>
          {this.props.contact.fullName()}
        </div>
      );
    }
    return (
      <div className="core-personal-info">
        {renderName}
        <div className="selectable email" onClick={this._select}>
          {this.props.contact.email}
        </div>
        {this._renderSocialProfiles()}
      </div>
    );
  }

  _renderSocialProfiles() {
    if (!this.state.socialProfiles) {
      return false;
    }
    const profiles = Object.entries(this.state.socialProfiles).map(([type, profile]) => {
      return (
        <a className="social-profile-item" key={type} title={profile.url} href={profile.url}>
          <RetinaImg
            url={`mailspring://participant-profile/assets/${type}-sidebar-icon@2x.png`}
            mode={RetinaImg.Mode.ContentPreserve}
          />
        </a>
      );
    });
    return <div className="social-profiles-wrap">{profiles}</div>;
  }

  _renderAdditionalInfo() {
    return (
      <div className="additional-info">
        {this._renderCurrentJob()}
        {this._renderBio()}
        {this._renderLocation()}
      </div>
    );
  }

  _renderCurrentJob() {
    if (!this.state.employer) {
      return false;
    }
    let title = false;
    if (this.state.title) {
      title = <span>{this.state.title},&nbsp;</span>;
    }
    return (
      <p className="selectable current-job">
        {title}
        {this.state.employer}
      </p>
    );
  }

  _renderBio() {
    if (!this.state.bio) {
      return false;
    }

    const bioNodes = [];
    const hashtagOrMentionRegex = RegExpUtils.hashtagOrMentionRegex();

    let bioRemainder = this.state.bio;
    let match = null;
    let count = 0;

    /* I thought we were friends. */
    /* eslint no-cond-assign: 0 */
    while ((match = hashtagOrMentionRegex.exec(bioRemainder))) {
      // the first char of the match is whitespace, match[1] is # or @, match[2] is the tag itself.
      bioNodes.push(bioRemainder.substr(0, match.index + 1));
      if (match[1] === '#') {
        bioNodes.push(
          <a key={count} href={`https://twitter.com/hashtag/${match[2]}`}>{`#${match[2]}`}</a>
        );
      }
      if (match[1] === '@') {
        bioNodes.push(<a key={count} href={`https://twitter.com/${match[2]}`}>{`@${match[2]}`}</a>);
      }
      bioRemainder = bioRemainder.substr(match.index + match[0].length);
      count += 1;
    }
    bioNodes.push(bioRemainder);

    return <p className="selectable bio">{bioNodes}</p>;
  }

  _renderLocation() {
    if (!this.state.location) {
      return false;
    }
    return (
      <p className="location">
        <RetinaImg
          url={`mailspring://participant-profile/assets/location-icon@2x.png`}
          mode={RetinaImg.Mode.ContentPreserve}
          style={{ float: 'left' }}
        />
        <span className="selectable" style={{ display: 'block', marginLeft: 20 }}>
          {this.state.location}
        </span>
      </p>
    );
  }

  _select(event) {
    const el = event.target;
    const sel = document.getSelection();
    if (el.contains(sel.anchorNode) && !sel.isCollapsed) {
      return;
    }
    const anchor = DOMUtils.findFirstTextNode(el);
    const focus = DOMUtils.findLastTextNode(el);
    if (anchor && focus && focus.data) {
      sel.setBaseAndExtent(anchor, 0, focus, focus.data.length);
    }
  }

  _renderFindCTA() {
    if (!this.state.trialing || this.state.loaded) {
      return;
    }
    if (!this.props.contact.email || Utils.likelyNonHumanEmail(this.props.contact.email)) {
      return;
    }

    return (
      <div style={{ textAlign: 'center' }}>
        <p>
          The contact sidebar in Mailspring Pro shows information about the people and companies
          you're emailing with.
        </p>
        <div className="btn" onClick={!this.state.loading ? this._onClickedToTry : null}>
          {!this.state.loading ? `Try it Now` : `Loading...`}
        </div>
      </div>
    );
  }

  render() {
    return (
      <div className="participant-profile">
        {this._renderProfilePhoto()}
        {this._renderCorePersonalInfo()}
        {this._renderAdditionalInfo()}

        {this._renderFindCTA()}
      </div>
    );
  }
}
