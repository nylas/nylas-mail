import {React} from 'nylas-exports';

export default function CodeSnippet(props) {
  return (
    <div className={props.className}>
      {props.intro}
      <br /><br />
      <textarea disabled value={props.code} />
    </div>
  )
}

CodeSnippet.propTypes = {
  intro: React.PropTypes.string,
  code: React.PropTypes.string,
  className: React.PropTypes.string,
}
