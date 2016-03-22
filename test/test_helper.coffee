chai       = require 'chai'
chaiSubset = require 'chai-subset'
sinon      = require 'sinon'
sinonChai  = require 'sinon-chai'

chai.use sinonChai
chai.use chaiSubset

global.expect = chai.expect
global.sinon  = sinon
