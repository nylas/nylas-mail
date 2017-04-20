import React from 'react';
import {RegExpUtils} from 'nylas-exports';

const FormErrorMessage = (props) => {
  const {message, statusCode, empty} = props;
  if (!message) {
    return <div className="message empty">{empty}</div>;
  }

  const isCertificateError = statusCode === 495
  if (isCertificateError) {
    return (
      <div className="error-region" style={{maxHeight: 21}}>
        <p className="message error error-message">{message}</p>
        <p className="message error error-message">
          The certificate for this server is invalid. Would you like to connect to the server anyway?
        </p>
      </div>
    );
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
  statusCode: React.PropTypes.number,
};

export default FormErrorMessage;
