Validator = require '../src/validator'
assert = require 'assert'
loglet = require 'loglet'

syncOK = (validator, data) ->
  it "#{data} will pass #{validator.name}", (done) ->
    try 
      validator.sync data
      done null
    catch e 
      done e

syncFail = (validator, data) ->
  it "#{data} will fail #{validator.name}", (done) ->
    try 
      validator.sync data
      done new Error("#{data} failed #{validator.name}")
    catch e 
      done null

asyncOK = (validator, data) ->
  it "#{data} will pass #{validator.name}", (done) ->
    try 
      validator.async data, done
    catch e 
      done e

asyncFail = (validator, data) ->  
  it "#{data} will fail #{validator.name}", (done) ->
    try 
      validator.async data, (err) ->
        if err 
          done null
        else
          done new Error("#{data} failed #{validator.name}")
    catch e 
      done e

ok = (v, d) ->
  syncOK v, d
  asyncOK v, d

fail = (v, d) ->
  syncFail v, d
  asyncFail v, d

uuid = Validator.register 'uuid', new Validator
  name: 'uuid'
  isa: (v) ->
    v.match /^[0-9a-zA-Z]{8}-?[0-9a-zA-Z]{4}-?[0-9a-zA-Z]{4}-?[0-9a-zA-Z]{4}-?[0-9a-zA-Z]{12}$/

ssn = Validator.register 'ssn', new Validator
  name: 'ssn'
  isa: (v) ->
    v.match /^[0-9]{3}-?[0-9]{2}-?[0-9]{4}$/

optional = Validator.register 'optional', new Validator
  name: 'optional'
  isa: (v) -> 
    v == null or v == undefined or v == ''


describe 'validator test', () ->
  
  required = Validator.make('required')
  ok required, 'abc' # we also want to make sure this isn't an empty string... (but zero is okay)
  fail required, null
  fail required, undefined
  fail required, ''
  
  fail optional, 'abc'
  ok optional, null
  ok optional, undefined
  ok optional, ''
  
  email = Validator.make('email')
  ok email, 'test@test.com'
  fail email, 'test@'
  
  natural = Validator.make('natural')
  ok natural, '1234'
  ok natural, '0'
  fail natural, '-1'
  
  ok uuid, '3a91f950-dec8-4688-ba14-5b7bbfc7a563'
  ok uuid, '3a91f950dec84688ba145b7bbfc7a563'
  fail uuid, '1087oij;o7poiu'
  
  ok ssn, '123-46-6789'
  fail ssn, '10987lkj1'
  
  range = Validator.range 2, 5
  range = Validator.make {range: [2, 5]}
  ok range, 'abcd'
  fail range, 'a'
  fail range, '123456'
  
  emailOrSSN = Validator.or email, ssn
  emailOrSSN = Validator.make {or: ['email', 'ssn']}
  ok emailOrSSN, 'test@test.com'
  ok emailOrSSN, '123456789'
  
  arrayEmailOrSSN = Validator.array emailOrSSN
  arrayEmailOrSSN = Validator.make {array: {or: ['email', 'ssn']}}
  arrayEmailOrSSN = Validator.make {array: emailOrSSN}
  ok arrayEmailOrSSN, ['test@test.com', '123-45-6789']
  fail arrayEmailOrSSN, ['test@test.com', '123-45-6789', '1234']
  
  objEmailSSN = Validator.object {email: email, ssn: ssn}
  objEmailSSN = Validator.make {object: {email: 'email', ssn: 'ssn'}}
  ok objEmailSSN, {email: 'test@test.com', ssn: '123-45-6789', skip: true}
  fail objEmailSSN, {email: 'test', ssn: '123-45-6789'}
  
  
    
  