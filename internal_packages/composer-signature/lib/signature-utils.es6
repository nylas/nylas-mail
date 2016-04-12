import {RegExpUtils} from 'nylas-exports'

export default {
  applySignature(body, signature) {
    // https://regex101.com/r/nC0qL2/2
    const signatureRegex = RegExpUtils.signatureRegex();

    let newBody = body;
    let paddingBefore = '';
    let paddingAfter = '';

    // Remove any existing signature in the body
    newBody = newBody.replace(signatureRegex, "");

    // http://www.regexpal.com/?fam=94390
    // prefer to put the signature one <br> before the beginning of the quote,
    // if possible.
    let insertionPoint = newBody.search(RegExpUtils.n1QuoteStartRegex());
    if (insertionPoint === -1) {
      insertionPoint = newBody.length;
      paddingBefore = '<br/><br/>';
    } else {
      paddingAfter = '<br/>';
    }

    const contentBefore = newBody.slice(0, insertionPoint);
    const contentAfter = newBody.slice(insertionPoint);
    return `${contentBefore}${paddingBefore}<signature>${signature}${paddingAfter}</signature>${contentAfter}`;
  },
};
