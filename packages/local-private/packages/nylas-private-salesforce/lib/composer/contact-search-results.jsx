import React from 'react'
import {Menu} from 'nylas-component-kit'
import {Contact, DatabaseStore} from 'nylas-exports'

import SalesforceIcon from '../shared-components/salesforce-icon'
import SalesforceObject from '../models/salesforce-object'

export function ContactSearchResult({token}) {
  return (
    <span key={token.id} className="salesforce-contact-search-result">
      <SalesforceIcon objectType="Contact" />
      <Menu.NameEmailItem name={token.name} email={token.email} />
    </span>
  )
}
ContactSearchResult.propTypes = {
  token: React.PropTypes.instanceOf(Contact),
}

/**
 * Registers as "ContactSearchResults"
 */
export default class ContactSearchResults extends React.Component {
  static displayName = "ContactSearchResults"

  static containerRequired = false

  static propTypes = {
    token: React.PropTypes.instanceOf(SalesforceObject),
  }

  /**
   * Finds Salesforce contacts and replaces any pre-found and sorted
   * nylasContacts with the corresponding Salesforce contact.
   */
  static findAdditionalContacts(search, nylasContacts) {
    return DatabaseStore.findAll(SalesforceObject)
    .search(search).then((results) => {
      const sfContacts = results.filter(c => c.type === "Contact")
        .map(o => {
          const c = new Contact({name: o.name, email: o.identifier})
          c.customComponent = ContactSearchResult
          return c;
        });

      const sfEmails = {}
      sfContacts.forEach((c, i) => {
        sfEmails[c.email.toLowerCase()] = i
      });

      const combinedContacts = []
      nylasContacts.forEach((c) => {
        const i = sfEmails[c.email.toLowerCase()]
        if (i >= 0) {
          combinedContacts.push(sfContacts.splice(i, 1)[0])
        } else {
          combinedContacts.push(c)
        }
      })

      return combinedContacts.concat(sfContacts);
    })
  }
}
