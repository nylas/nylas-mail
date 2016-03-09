/** @babel */
import _ from 'underscore'
import React from 'react'
import {shell} from 'electron'
import {Utils} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import ParticipantProfileStore from './participant-profile-store'

export default class SidebarParticipantProfile extends React.Component {
  static displayName = "SidebarParticipantProfile";

  static propTypes = {
    contact: React.PropTypes.object,
    contactThreads: React.PropTypes.array,
  }

  constructor(props) {
    super(props);

    /* We expect ParticipantProfileStore.dataForContact to return the
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
    this.state = ParticipantProfileStore.dataForContact(props.contact)
  }

  componentDidMount() {
    this.usub = ParticipantProfileStore.listen(() => {
      this.setState(ParticipantProfileStore.dataForContact(this.props.contact))
    })
  }

  componentWillUnmount() {
    this.usub()
  }

  static containerStyles = {
    order: 0,
  }

  _renderProfilePhoto() {
    if (this.state.profilePhotoUrl) {
      return (
        <div className="profile-photo-wrap">
          <div className="profile-photo">
            <img src={this.state.profilePhotoUrl}/>
          </div>
        </div>
      )
    }
    return this._renderDefaultProfileImage()
  }

  _renderDefaultProfileImage() {
    const hue = Utils.hueForString(this.props.contact.email);
    const bgColor = `hsl(${hue}, 50%, 34%)`
    const abv = this.props.contact.nameAbbreviation()
    return (
      <div className="profile-photo-wrap">
        <div className="profile-photo">
          <div className="default-profile-image"
               style={{backgroundColor: bgColor}}>{abv}
          </div>
        </div>
      </div>
    )
  }

  _renderCorePersonalInfo() {
    return (
      <div className="core-personal-info">
        <div className="full-name">{this.props.contact.fullName()}</div>
        <div className="email">{this.props.contact.email}</div>
        <div className="social-profiles-wrap">{this._renderSocialProfiles()}</div>
      </div>
    )
  }

  _renderSocialProfiles() {
    if (!this.state.socialProfiles) { return false }
    return _.map(this.state.socialProfiles, (profile, type) => {
      const linkFn = () => {shell.openExternal(profile.url)}
      return (
        <a className="social-profile-item" onClick={linkFn} key={type}>
          <RetinaImg url={`nylas://participant-profile/assets/${type}-sidebar-icon@2x.png`}
                     mode={RetinaImg.Mode.ContentPreserve} />
        </a>
      )
    });
  }

  _renderAdditionalInfo() {
    return (
      <div className="additional-info">
        {this._renderCurrentJob()}
        {this._renderBio()}
        {this._renderLocation()}
      </div>
    )
  }

  _renderCurrentJob() {
    if (!this.state.employer) { return false; }
    let title = false;
    if (this.state.title) {
      title = <span>{this.state.title},&nbsp;</span>
    }
    return (
      <p className="current-job">{title}{this.state.employer}</p>
    )
  }

  _renderBio() {
    if (!this.state.bio) { return false; }
    return (
      <p className="bio">{this.state.bio}</p>
    )
  }

  _renderLocation() {
    if (!this.state.location) { return false; }
    return (
      <p className="location">
        <RetinaImg url={`nylas://participant-profile/assets/location-icon@2x.png`}
                   mode={RetinaImg.Mode.ContentPreserve}
                   style={{marginRight: 10}} />
        {this.state.location}
      </p>
    )
  }

  render() {
    return (
      <div className="participant-profile">
        {this._renderProfilePhoto()}
        {this._renderCorePersonalInfo()}
        {this._renderAdditionalInfo()}
      </div>
    )
  }

}
