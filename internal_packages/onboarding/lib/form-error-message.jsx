import React from 'react';
import {RegExpUtils} from 'nylas-exports';

const FormErrorMessage = (props) => {
  let {message, empty} = props;
  if (!message) {
    return <div className="message empty">{empty}</div>;
  }

  const result = RegExpUtils.urlRegex({matchEntireString: false}).exec(message);
  if (result) {
    const link = result[0];
    return (
      <div className="message error">
        {message.substr(0, result.index)}
        <a href={link}>{link}</a>
        {message.substr(result.index + link.length)}
      </div>
    );
  }

  return (
    <div className="message error">
      {message}
    </div>
  );
}

FormErrorMessage.propTypes = {
  empty: React.PropTypes.string,
  message: React.PropTypes.string,
};

export default FormErrorMessage;
