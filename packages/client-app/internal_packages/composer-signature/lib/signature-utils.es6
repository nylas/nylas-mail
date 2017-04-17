import {RegExpUtils} from 'nylas-exports'

export default {
  applySignature(body, signature) {
    // https://regex101.com/r/nC0qL2/2
    const signatureRegex = RegExpUtils.signatureRegex();

    let newBody = body;
    let paddingBefore = '';

    // Remove any existing signature in the body
    newBody = newBody.replace(signatureRegex, "");
    const signatureInPrevious = newBody !== body

    // http://www.regexpal.com/?fam=94390
    // prefer to put the signature one <br> before the beginning of the quote,
    // if possible.
    let insertionPoint = newBody.search(RegExpUtils.n1QuoteStartRegex());
    if (insertionPoint === -1) {
      insertionPoint = newBody.length;
      if (!signatureInPrevious) paddingBefore = '<br><br>'
    }

    const contentBefore = newBody.slice(0, insertionPoint);
    const contentAfter = newBody.slice(insertionPoint);
    return `${contentBefore}${paddingBefore}<signature>${signature}</signature>${contentAfter}`;
  },
};
