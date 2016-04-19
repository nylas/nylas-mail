import moment from 'moment-timezone'
import React from 'react'
import {Utils, DateUtils} from 'nylas-exports'
import b64Imgs from './email-b64-images'

const TZ = moment.tz(Utils.timeZone).format("z");

export default class NewEventPreview extends React.Component {
  static propTypes = {
    event: React.PropTypes.object,
  }

  static defaultProps = {
    draft: {},
  }

  static displyName = "NewEventPreview";

  _renderB64Img(name, styles = {}) {
    let imgStyles = {
      width: "16px",
      height: "16px",
      display: "inline-block",
      marginRight: "10px",
      backgroundRepeat: "no-repeat",
      backgroundImage: `url('${b64Imgs[name]}')`,
    }
    imgStyles = Object.assign(imgStyles, styles);
    return <div style={imgStyles}></div>
  }

  _renderEventInfo() {
    const styles = {
      fontSize: "20px",
      fontWeight: 400,
      margin: "0 10px 15px 10px",
    }
    const noteStyles = {
      marginTop: "12px",
      paddingLeft: "40px",
    }
    return (
      <div className="new-event-preview">
        <h2 style={styles}>
          {this._renderB64Img("description", {verticalAlign: "middle"})}
          {this.props.event.title}
        </h2>
        <span style={{margin: "0 10px"}}>
          {this._renderB64Img("time", {verticalAlign: "super"})}
          {this._renderEventTime()}
        </span>
        <div style={noteStyles}>You will receive a calendar invite for this event shortly.</div>
      </div>
    )
  }

  _renderEventTime() {
    const start = moment.unix(this.props.event._start)
    const end = moment.unix(this.props.event._end).add(1, 'second')
    const dayTxt = start.format(DateUtils.DATE_FORMAT_LLLL_NO_TIME)
    const tz = (<span style={{fontSize: "10px", color: "#aaa"}}>{TZ}</span>);
    const styles = {
      display: "inline-block",
    }
    return <span style={styles}>{dayTxt}<br />{`${start.format("LT")} – ${end.format("LT")}`} {tz}</span>
  }

  _sEventPreviewWrap() {
    return {
      borderRadius: "4px",
      border: "1px solid rgba(0,0,0,0.15)",
      padding: "15px",
      margin: "10px 0",
      position: "relative",
    }
  }

  render() {
    return (
      <div style={this._sEventPreviewWrap()}>
        {this._renderEventInfo()}
      </div>
    )
  }
}
