import {Table} from 'nylas-component-kit'
import TokenDataSource from '../lib/token-data-source'

const {TableDataSource} = Table

export const testData = {
  columns: ['name', 'email'],
  rows: [
    ['donald', 'donald@nylas.com'],
    ['hilary', 'hilary@nylas.com'],
  ],
}

export const testDataSource = new TableDataSource(testData)

export const testSelection = {rowIdx: 1, colIdx: 0, key: 'Enter'}

export const testTokenDataSource =
  new TokenDataSource()
  .linkToken('to', {colName: 'name', colIdx: 0, tokenId: 'name-0'})
  .linkToken('bcc', {colName: 'email', colIdx: 1, tokenId: 'email-1'})

export const testState = {
  isWorkspaceOpen: true,
  selection: testSelection,
  tableDataSource: testDataSource,
  tokenDataSource: testTokenDataSource,
}

export const testAnchorMarkup = (tokenId) => {
  return `<img class="n1-overlaid-component-anchor-container mail-merge-token-wrap" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" data-overlay-id="${tokenId}" data-component-props="{&quot;field&quot;:&quot;subject&quot;,&quot;colIdx&quot;:&quot;0&quot;,&quot;colName&quot;:&quot;email&quot;,&quot;draftClientId&quot;:&quot;local-0cab45d1-c763&quot;,&quot;className&quot;:&quot;mail-merge-token-wrap&quot;}" data-component-key="MailMergeBodyToken" style="width: 132.156px; height: 21px;">`
}

export const testContenteditableContent = () => {
  const nameSpan = testAnchorMarkup('name-anchor')
  const emailSpan = testAnchorMarkup('email-anchor')
  return `<div>${nameSpan}<br>stuff${emailSpan}</div>`
}
