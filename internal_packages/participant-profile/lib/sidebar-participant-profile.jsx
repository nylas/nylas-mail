/** @babel */
import _ from 'underscore'
import React from 'react'
import {shell} from 'electron'
import {DOMUtils, Utils} from 'nylas-exports'
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
        <div className="selectable full-name" onClick={this._select}>{this.props.contact.fullName()}</div>
        <div className="selectable email" onClick={this._select}>{this.props.contact.email}</div>
        {this._renderSocialProfiles()}
      </div>
    )
  }

  _renderSocialProfiles() {
    if (!this.state.socialProfiles) { return false }
    const profiles = _.map(this.state.socialProfiles, (profile, type) => {
      const linkFn = () => {shell.openExternal(profile.url)}
      return (
        <a className="social-profile-item" onClick={linkFn} key={type}>
          <RetinaImg url={`nylas://participant-profile/assets/${type}-sidebar-icon@2x.png`}
                     mode={RetinaImg.Mode.ContentPreserve} />
        </a>
      )
    });
    return <div className="social-profiles-wrap">{profiles}</div>
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
      <p className="selectable current-job">{title}{this.state.employer}</p>
    )
  }

  _renderBio() {
    if (!this.state.bio) { return false; }
    return (
      <p className="selectable bio">{this.state.bio}</p>
    )
  }

  _renderLocation() {
    if (!this.state.location) { return false; }
    return (
      <p className="location">
        <RetinaImg url={`nylas://participant-profile/assets/location-icon@2x.png`}
                   mode={RetinaImg.Mode.ContentPreserve}
                   style={{float: "left"}} />
        <span className="selectable" style={{display: "block", marginLeft: 20}}>{this.state.location}</span>
      </p>
    )
  }

  _select(event) {
    const el = event.target;
    const sel = document.getSelection()
    if (el.contains(sel.anchorNode) && !sel.isCollapsed) {
      return
    }
    const anchor = DOMUtils.findFirstTextNode(el)
    const focus = DOMUtils.findLastTextNode(el)
    if (anchor && focus && focus.data) {
      sel.setBaseAndExtent(anchor, 0, focus, focus.data.length)
    }
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
