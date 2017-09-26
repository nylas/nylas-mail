import { React, PropTypes } from 'mailspring-exports';

export default function CodeSnippet(props) {
  return (
    <div className={props.className}>
      {props.intro}
      <br />
      <br />
      <textarea disabled value={props.code} />
    </div>
  );
}

CodeSnippet.propTypes = {
  intro: PropTypes.string,
  code: PropTypes.string,
  className: PropTypes.string,
};
