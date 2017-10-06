import fs from 'fs';
import temp from 'temp';
import { app, shell } from 'electron';
import { React, PropTypes, RegExpUtils } from 'mailspring-exports';

const FormErrorMessage = props => {
  const { message, log, empty } = props;
  if (!message) {
    return <div className="message empty">{empty}</div>;
  }

  let rawLogLink = false;
  if (log && log.length > 0) {
    const onViewLog = () => {
      const logPath = temp.path({ suffix: '.log' });
      fs.writeFileSync(logPath, log);
      shell.openItem(logPath);
    };
    rawLogLink = (
      <a href="" onClick={onViewLog} style={{ paddingLeft: 5 }}>
        View Log
      </a>
    );
  }

  const linkMatch = RegExpUtils.urlRegex({ matchEntireString: false }).exec(message);
  if (linkMatch) {
    const link = linkMatch[0];
    return (
      <div className="message error">
        {message.substr(0, linkMatch.index)}
        <a href={link}>{link}</a>
        {message.substr(linkMatch.index + link.length)}
        {rawLogLink}
      </div>
    );
  }

  return (
    <div className="message error">
      {message}
      {rawLogLink}
    </div>
  );
};

FormErrorMessage.propTypes = {
  empty: PropTypes.string,
  message: PropTypes.string,
};

export default FormErrorMessage;
