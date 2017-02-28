import Jasmine from 'jasmine'
import JasmineExtensions from './extensions'

export default function execute(extendOpts) {
  const jasmine = new Jasmine()
  jasmine.loadConfigFile('spec/jasmine/config.json')
  const jasmineExtensions = new JasmineExtensions()
  jasmineExtensions.extend(extendOpts)
  jasmine.execute()
}
