import url from 'url'
import querystring from 'querystring';
import {ipcRenderer} from 'electron';
import {DatabaseStore, Thread, Matcher, Actions} from "nylas-exports";


const DATE_EPSILON = 60  // Seconds

const parseOpenThreadUrl = (nylasUrlString) => {
  const parsedUrl = url.parse(nylasUrlString)
  const params = querystring.parse(parsedUrl.query)
  params.lastDate = parseInt(params.lastDate, 10)
  return params;
}

const findCorrespondingThread = ({subject, lastDate}, dateEpsilon = DATE_EPSILON) => {
  return DatabaseStore.findBy(Thread).where([
    Thread.attributes.subject.equal(subject),
    new Matcher.Or([
      new Matcher.And([
        Thread.attributes.lastMessageSentTimestamp.lessThan(lastDate + dateEpsilon),
        Thread.attributes.lastMessageSentTimestamp.greaterThan(lastDate - dateEpsilon),
      ]),
      new Matcher.And([
        Thread.attributes.lastMessageReceivedTimestamp.lessThan(lastDate + dateEpsilon),
        Thread.attributes.lastMessageReceivedTimestamp.greaterThan(lastDate - dateEpsilon),
      ]),
    ]),
  ])
}

const _openExternalThread = (event, nylasUrl) => {
  const {subject, lastDate} = parseOpenThreadUrl(nylasUrl);

  findCorrespondingThread({subject, lastDate})
  .then((thread) => {
    if (!thread) {
      throw new Error('Thread not found')
    }
    Actions.popoutThread(thread);
  })
  .catch((error) => {
    NylasEnv.reportError(error)
    NylasEnv.showErrorDialog(`The thread ${subject} does not exist in your mailbox!`)
  })
}

const activate = () => {
  ipcRenderer.on('openExternalThread', _openExternalThread)
}

const deactivate = () => {
  ipcRenderer.removeListener('openExternalThread', _openExternalThread)
}

export default {activate, deactivate}
