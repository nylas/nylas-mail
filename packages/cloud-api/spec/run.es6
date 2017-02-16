import Jasmine from 'jasmine'
import JasmineExtensions from './jasmine/extensions'

const jasmine = new Jasmine()
jasmine.loadConfigFile('spec/jasmine/config.json')
const jasmineExtensions = new JasmineExtensions()
jasmineExtensions.extend()
jasmine.execute()
