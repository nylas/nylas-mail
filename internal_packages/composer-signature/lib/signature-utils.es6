export default {
  applySignature(body, signature) {
    // https://regex101.com/r/nC0qL2/1
    const signatureRegex = /<div class="nylas-n1-signature">[^]*<\/div>/;

    let signatureHTML = '<div class="nylas-n1-signature">' + signature + '</div>';
    let insertionPoint = body.search(signatureRegex);
    let newBody = body;

    // If there is a signature already present
    if (insertionPoint !== -1) {
      // Remove it
      newBody = newBody.replace(signatureRegex, "");
    } else {
      insertionPoint = newBody.indexOf('<blockquote');

      if (insertionPoint === -1) {
        insertionPoint = newBody.length;
        signatureHTML = '<br/><br/>' + signatureHTML;
      }
    }
    return newBody.slice(0, insertionPoint) + signatureHTML + newBody.slice(insertionPoint);
  },
};
