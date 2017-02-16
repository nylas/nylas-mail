
import {
  DatabaseStore,
  Thread,
} from 'nylas-exports'

import SalesforceObject from '../lib/models/salesforce-object'
import SalesforceAPI from '../lib/salesforce-api'

const companyNames = [
  "Lyft",
  "Airbnb",
  "Salesforce",
  "Facebook",
  "Google",
  "Apple",
  "Tesla",
  "SpaceX",
  "Dropbox",
  "Snap",
  "Twitter",
  "Oracle",
  "Sequoia Capital",
  "KPCB",
  "Andreessen Horowitz",
]

const oppNames = [
  "Lyft Sales",
  "Airbnb Marketing",
  "Salesforce Recruiting",
  "Facebook Sales",
  "Google Marketing",
  "Apple Recruiting",
  "Tesla Sales",
  "SpaceX Marketing",
  "Dropbox Recruiting",
  "Snap Sales",
  "Twitter Marketing",
  "Oracle Recruiting",
  "Sequoia Capital Sales",
  "KPCB Marketing",
  "Andreessen Horowitz Recruiting",
]


class GenerateTestData {

  constructor() {
    this._threads = []
    this._contacts = []
    this._accounts = []
    this._index = 29
  }

  populateAccounts() {
    DatabaseStore.findAll(SalesforceObject, {
      type: "Account",
    })
    .then((accounts) => {
      console.log(accounts)
      this._accounts = accounts
    })
  }

  createSalesforceContacts() {
    DatabaseStore.findAll(Thread)
    .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
    .limit(2000)
    .then((threads) => {
      this._threads = threads
      const contactEmails = []
      this._threads.forEach((thread) => {
        thread.participants.forEach((contact) => {
          if (!contactEmails.includes(contact.email)) {
            this._contacts.push(contact)
            contactEmails.push(contact.email)
          }
        })
      })

      for (const contact of this._contacts) {
        const formPostData = {
          Email: contact.email,
          FirstName: contact.firstName,
          LastName: contact.lastName,
          OwnerId: "00541000000ohxCAAQ",
        }
        SalesforceAPI.makeRequest({
          path: "/sobjects/Contact/",
          method: "POST",
          body: formPostData,
        })
      }
    })
  }

  createSalesforceAccounts() {
    for (const companyName of companyNames) {
      const formPostData = {
        Name: companyName,
        OwnerId: "00541000000ohxCAAQ",
      }
      SalesforceAPI.makeRequest({
        path: "/sobjects/Account/",
        method: "POST",
        body: formPostData,
      })
    }
  }

  createSalesforceOpportunities() {
    for (const oppName of oppNames) {
      const formPostData = {
        CloseDate: "2016-11-20",
        Name: oppName,
        StageName: "Prospecting",
        Probability: "20",
        Amount: "15000",
        OwnerId: "00541000000ohxCAAQ",
      }
      SalesforceAPI.makeRequest({
        path: "/sobjects/Opportunity/",
        method: "POST",
        body: formPostData,
      })
    }
  }

  // Adding to accounts didn't work for some reason
  addContactsToAccountsAndOpportunities() {
    DatabaseStore.findAll(SalesforceObject, {
      type: "Contact",
    })
    .then((contacts) => {
      for (const contact of contacts) {
        if (this._isLucky()) {
          this._chooseAccountAndOpportunity()
          .then(({account, opportunity}) => {
            const accountData = {
              Email: contact.email,
              FirstName: contact.firstName,
              LastName: contact.lastName,
              AccountId: account.id,
              OwnerId: "00541000000ohxCAAQ",
            }
            SalesforceAPI.makeRequest({
              path: "/sobjects/Contact/",
              method: "PATCH",
              body: accountData,
            })
            const opportunityData = {
              ContactId: contact.id,
              OpportunityId: opportunity.id,
            }
            SalesforceAPI.makeRequest({
              path: "/sobjects/OpportunityContactRole/",
              method: "POST",
              body: opportunityData,
            })
          })
        }
      }
    })
  }

  _chooseAccountAndOpportunity() {
    const account = this._accounts[this._getIndex()]
    return DatabaseStore.findAll(SalesforceObject, {
      type: "Opportunity",
    })
    .where(SalesforceObject.attributes.name.like(account.name))
    .then((opportunities) => {
      return Promise.resolve({
        account: account,
        opportunity: opportunities[0],
      })
    })
  }

  _isLucky() {
    return Math.floor((Math.random() * 100)) < 75
  }

  _getIndex() {
    if (this._index === 44) {
      this._index = 29
    }
    this._index++
    return this._index
  }
}

export default new GenerateTestData()
