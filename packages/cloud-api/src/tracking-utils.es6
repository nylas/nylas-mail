import atob from 'atob'

/**
 * As of April 26, 2017 we encode the recipient of an open/link track in
 * the `recipient` query field as a plain url-encoded email.
 *
 * Before we used to put an encoded email in the `r` query field and
 * encoded it with the following scheme:
 *
 *     btoa(recipient.email).replace(/\+/g,'-').replace(/\//g, '_')
 *
 * We revert to a much more human-transparent method of encoding the
 * recipient email to allow for easier understanding of the codebase and
 * open/link tracking performance.
 */
export function decodeRecipient(query = {}) {
  if (query.recipient) {
    return query.recipient
  }

  // Legacy encoding scheme
  if (query.r) {
    // reverse of btoa(recipient.email).replace(/\+/g,'-').replace(/\//g, '_')
    return atob(query.r.replace(/_/g, "/").replace(/-/g, "+"))
  }

  return null
}
