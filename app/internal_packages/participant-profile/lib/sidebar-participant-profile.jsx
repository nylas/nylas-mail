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
import moment from 'moment-timezone';

import ParticipantProfileDataSource from './participant-profile-data-source';

class ProfilePictureOrColorBox extends React.Component {
  static propTypes = {
    loading: PropTypes.bool,
    contact: PropTypes.object,
    profilePicture: PropTypes.string,
  };
  render() {
    const { contact, loading, avatar } = this.props;

    const hue = Utils.hueForString(contact.email);
    const bgColor = `hsl(${hue}, 50%, 45%)`;

    let content = (
      <div className="default-profile-image" style={{ backgroundColor: bgColor }}>
        {contact.nameAbbreviation()}
      </div>
    );

    if (loading) {
      content = (
        <div className="default-profile-image">
          <RetinaImg
            className="spinner"
            style={{ width: 20, height: 20 }}
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
          />
        </div>
      );
    }

    if (avatar) {
      content = <img alt="Profile" src={avatar} />;
    }

    return (
      <div className="profile-photo-wrap">
        <div className="profile-photo">{content}</div>
      </div>
    );
  }
}
class SocialProfileLink extends React.Component {
  static propTypes = {
    service: PropTypes.string,
    handle: PropTypes.string,
  };

  render() {
    const { handle, service } = this.props;

    if (!handle) {
      return false;
    }
    return (
      <a
        className="social-profile-item"
        title={`https://${service}.com/${handle}`}
        href={`https://${service}.com/${handle}`}
      >
        <RetinaImg
          url={`mailspring://participant-profile/assets/${service}-sidebar-icon@2x.png`}
          mode={RetinaImg.Mode.ContentPreserve}
        />
      </a>
    );
  }
}

class TextBlockWithAutolinkedElements extends React.Component {
  static propTypes = {
    className: PropTypes.string,
    string: PropTypes.string,
  };

  render() {
    if (!this.props.string) {
      return false;
    }

    const nodes = [];
    const hashtagOrMentionRegex = RegExpUtils.hashtagOrMentionRegex();

    let remainder = this.props.string;
    let match = null;
    let count = 0;

    /* I thought we were friends. */
    /* eslint no-cond-assign: 0 */
    while ((match = hashtagOrMentionRegex.exec(remainder))) {
      // the first char of the match is whitespace, match[1] is # or @, match[2] is the tag itself.
      nodes.push(remainder.substr(0, match.index + 1));
      if (match[1] === '#') {
        nodes.push(
          <a key={count} href={`https://twitter.com/hashtag/${match[2]}`}>{`#${match[2]}`}</a>
        );
      }
      if (match[1] === '@') {
        nodes.push(<a key={count} href={`https://twitter.com/${match[2]}`}>{`@${match[2]}`}</a>);
      }
      remainder = remainder.substr(match.index + match[0].length);
      count += 1;
    }
    nodes.push(remainder);

    return <p className={`selectable ${this.props.className}`}>{nodes}</p>;
  }
}

class IconRow extends React.Component {
  static propTypes = {
    string: PropTypes.string,
    icon: PropTypes.string,
  };

  render() {
    const { string, icon } = this.props;

    if (!string) {
      return false;
    }
    return (
      <div className={`icon-row ${icon}`}>
        <RetinaImg
          url={`mailspring://participant-profile/assets/${icon}-icon@2x.png`}
          mode={RetinaImg.Mode.ContentPreserve}
          style={{ float: 'left' }}
        />
        <span className="selectable" style={{ display: 'block', marginLeft: 25 }}>
          {string}
        </span>
      </div>
    );
  }
}

class LocationRow extends React.Component {
  static propTypes = {
    string: PropTypes.string,
  };

  render() {
    return (
      <IconRow
        icon="location"
        string={
          this.props.string && (
            <span>
              {this.props.string}
              {' ['}
              <a className="plain" href={`https://maps.google.com/?q=${this.props.string}`}>
                View
              </a>
              {']'}
            </span>
          )
        }
      />
    );
  }
}

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
      // Wait until we know they've "settled" on this email to reduce the number of
      // requests to the contact search endpoint.
      this.setState({ loading: true });
      setTimeout(this._onFindContact, 2000);
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
    this._onFindContact();
  };

  _onFindContact = async () => {
    if (!this._mounted) {
      return;
    }
    if (!this.state.loading) {
      this.setState({ loading: true });
    }
    ParticipantProfileDataSource.find(this.props.contact.email).then(result => {
      if (!this._mounted) {
        return;
      }
      this.setState(Object.assign({ loading: false, loaded: true }, result));
    });
  };

  _onSelect = event => {
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
  };

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

  _renderCompanyInfo() {
    const {
      name,
      domain,
      category,
      description,
      location,
      timeZone,
      logo,
      facebook,
      twitter,
      linkedin,
      crunchbase,
      type,
      ticker,
      phone,
      metrics,
    } =
      this.state.company || {};

    if (!name) {
      return;
    }

    let employees = null;
    let funding = null;

    if (metrics) {
      if (metrics.raised) {
        funding = `Raised $${(metrics.raised / 1 || 0).toLocaleString()}`;
      } else if (metrics.marketCap) {
        funding = `Market cap $${(metrics.marketCap / 1 || 0).toLocaleString()}`;
      }

      if (metrics.employees) {
        employees = `${(metrics.employees / 1 || 0).toLocaleString()} employees`;
      } else if (metrics.employeesRange) {
        employees = `${metrics.employeesRange} employees`;
      }
    }

    return (
      <div className="company-profile">
        {logo && (
          <RetinaImg url={logo} className="company-logo" mode={RetinaImg.Mode.ContentPreserve} />
        )}

        <div className="selectable larger" onClick={this._onSelect}>
          {name}
        </div>

        {domain && (
          <a className="domain" href={domain.startsWith('http') ? domain : `http://${domain}`}>
            {domain}
          </a>
        )}

        <div className="additional-info">
          <TextBlockWithAutolinkedElements string={description} className="description" />
          <LocationRow string={location} />
          <IconRow
            icon="timezone"
            string={
              timeZone && (
                <span>
                  {`${timeZone.replace('_', ' ')} - `}
                  <strong>
                    {`Currently ${moment()
                      .tz(timeZone)
                      .format('h:MMa')}`}
                  </strong>
                </span>
              )
            }
          />
          <IconRow icon="industry" string={category && (category.industry || category.sector)} />
          <IconRow
            icon="holding"
            string={{ private: 'Privately Held', public: `Stock Symbol ${ticker}` }[type]}
          />
          <IconRow icon="phone" string={phone} />
          <IconRow icon="employees" string={employees} />
          <IconRow icon="funding" string={funding} />

          <div className="social-profiles-wrap">
            <SocialProfileLink service="facebook" handle={facebook && facebook.handle} />
            <SocialProfileLink service="crunchbase" handle={crunchbase && crunchbase.handle} />
            <SocialProfileLink service="linkedin" handle={linkedin && linkedin.handle} />
            <SocialProfileLink service="twitter" handle={twitter && twitter.handle} />
          </div>
        </div>
      </div>
    );
  }

  _renderPersonInfo() {
    const { facebook, linkedin, twitter, employment, location, bio } = this.state.person || {};

    return (
      <div className="participant-profile">
        <ProfilePictureOrColorBox
          loading={this.state.loading}
          avatar={this.state.avatar}
          contact={this.props.contact}
        />
        <div className="personal-info">
          {this.props.contact.fullName() !== this.props.contact.email && (
            <div className="selectable larger" onClick={this._onSelect}>
              {this.props.contact.fullName()}
            </div>
          )}

          {employment && (
            <div className="selectable current-job">
              {employment.title && <span>{employment.title},&nbsp;</span>}
              {employment.name}
            </div>
          )}

          <div className="selectable email" onClick={this._onSelect}>
            {this.props.contact.email}
          </div>

          <div className="social-profiles-wrap">
            <SocialProfileLink service="facebook" handle={facebook && facebook.handle} />
            <SocialProfileLink service="linkedin" handle={linkedin && linkedin.handle} />
            <SocialProfileLink service="twitter" handle={twitter && twitter.handle} />
          </div>
        </div>

        <div className="additional-info">
          <TextBlockWithAutolinkedElements string={bio} className="bio" />
          <LocationRow string={location} />
        </div>
      </div>
    );
  }

  render() {
    return (
      <div>
        {this._renderPersonInfo()}

        {this._renderCompanyInfo()}

        {this._renderFindCTA()}
      </div>
    );
  }
}
