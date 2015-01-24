# validator combinator.

{EventEmitter} = require 'events'
errorlet = require 'errorlet'
funclet = require 'funclet'
email = require 'email-validator'
loglet = require 'loglet'

class Validator extends EventEmitter
  @registry = {}
  @register: (name, validator) ->
    @registry[name] = validator
    validator
  @types = {}
  @registerType: (name, validatorClass) ->
    @types[name] = validatorClass
    @[name] = (args...) ->
      new validatorClass args...
  @make: (spec) ->
    if spec instanceof @
      spec
    else if spec instanceof RegExp
      new RegexValidator spec
    else if spec instanceof Object
      for key, val of spec
        if @types.hasOwnProperty(key)
          return @types[key].make val
      throw errorlet.create {error: 'unknown_validator_type', spec: spec}
    else if typeof(spec) == 'string' # this is the simplest type of validator...
      # what we want to do is to figure out if something is already registered.
      # we also want to deal with higher order validator as well... 
      # higher order validator can be complex... 
      if @registry.hasOwnProperty(spec)
        @registry[spec]
      else
        throw errorlet.create {error: 'unknown_validator', name: spec}
    else 
      throw errorlet.create {error: 'invalid_validator_spec', spec: spec}
  constructor: (obj = {}) ->
    for key, val of obj
      @[key] = val
    if not @isa or @callback
      throw errorlet.create {error: 'validate_require_callback_or_run', message: 'validator requires a callback (async) or run (sync) function.'}
  isAsync: () -> 
    @hasOwnProperty('callback') and (typeof(@callback) == 'function') or (@callback instanceof Function)
  sync: (v) -> 
    if not @isa v
      if @raise
        throw @raise(v)
      else
        throw errorlet.create {error: "error:#{@name}", value: v, validator: @}
  async: (v, cb) ->
    try 
      if @callback 
        @callback v, cb
      else
        cb null, @sync(v)
    catch e
      cb e
  validate: (v) -> # this is the event-based call.
    if @isAsync()
      @async v, (err) =>
        if err 
          @emit 'validate-error', err
        else
          @emit 'validate-ok', v
    else
      try 
        @sync v
        @emit 'validate-ok', v
      catch e
        @emit 'validate-error', e

# a validator is an object that has the following functions.
# name
# isAsync
# sync # not supported when isAsync == true
# async
# 

required = Validator.register 'required', new Validator
  name: 'required'
  isa: (v) -> v != null and v != undefined and v != ''

string = Validator.register 'string', new Validator
  name: 'string'
  isa: (v) -> typeof(v) == 'string'

Validator.register 'email', new Validator
  name: 'email'
  isa: (v) ->
    email.validate v

class RangeValidator extends Validator 
  @make: (range) ->
    [min, max] = range
    new @ min, max
  constructor: (@min, @max) ->
  isa: (v) ->
    v?.length and v.length >= @min and v.length <= @max

Validator.registerType 'range', RangeValidator

class RegexValidator extends Validator
  constructor: (@regex) ->
  sync: (v) ->
    string.sync v
    if not v.match @regex
      throw errorlet.create {error: 'regex_validate', value: v, validator: @}

number = Validator.register 'number', new RegexValidator /^[+-]?\d+(\.\d+)?$/
integer = Validator.register 'integer', new RegexValidator /^[+-]?\d+$/
natural = Validator.register 'natural', new RegexValidator /^\d+$/

class ArrayValidator extends Validator
  @make: (inner) ->
    new @ Validator.make(inner)
  constructor: (@inner) ->
  isAsync: () ->
    @inner.isAsync()
  sync: (v) ->
    if not v instanceof Array
      throw errorlet.create {error: 'array_validate:not_array', value: v, message: "not an array.", validator: @}
    for item in v 
      @inner.sync item 
  async: (v, cb) ->
    if not v instanceof Array
      return cb errorlet.create {error: 'array_validate:not_array', value: v, message: "not an array.", validator: @}
    funclet
      .each v, (item, next) =>
        @inner.async item, next
      .catch(cb)
      .done () -> cb null

Validator.registerType 'array', ArrayValidator

class AndValidator extends Validator
  @make: (list) ->
    inners = 
      for item in list 
        Validator.make item 
    new @ inners...
  constructor: (@inners...) ->
  sync: (v) ->
    for inner in @inners
      inner.sync v
  isAsync: () ->
    for inner in @inners
      if inner.isAsync()
        return true
    false
  async: (v, cb) ->
    funclet
      .each @inners, (inner, next) ->
        inner.async v, next
      .catch(cb)
      .done () -> cb null

Validator.registerType 'and', AndValidator

class OrValidator extends Validator
  @make: (list) ->
    inners = 
      for item in list 
        Validator.make item 
    new @ inners...
  constructor: (@inners...) ->
  sync: (v) ->
    errors = []
    pass = false
    for inner in @inners
      try 
        inner.sync v
        pass = true
        return
      catch e
        errors.push e
    # if we get here - nothing passes
    throw errorlet.create {error: 'or_validate', inners: errors, validator: @}
  isAsync: () ->
    for inner in @inners
      if inner.isAsync()
        return true
    false
  async: (v, cb) ->
    # this one can be hard - because we just need one to pass through... 
    errors = []
    pass = false
    funclet
      .each @inners, (inner, next) ->
        inner.async v, (err) ->
          if err 
            errors.push err
          else
            pass = true
          next null
      .catch(cb)
      .done () ->
        if pass 
          cb null
        else
          throw errorlet.create {error: 'or_validate', value: v, errors: errors, validator: @}

Validator.registerType 'or', OrValidator

class ObjectValidator extends Validator
  @make: (obj) ->
    loglet.log 'ObjectValidator.make', obj
    inner = {}
    for key, val of obj
      inner[key] = Validator.make val 
    new @ inner
  constructor: (@inner) ->
  sync: (v) ->
    if not v instanceof Object
      throw errorlet.create {error: 'object_validate:not_an_object', value: v, validator: @}
    errors = {}
    hasError = false
    for key, val of @inner
      try 
        val.sync v[key]
      catch e
        errors[key] = e
        hasError = true
    if hasError
      throw errorlet.create {error: 'object_validate:key_error', value: v, errors: errors, validator: @}
  isAsync: (v) ->
    for key, val of @inner
      if val.isAsync()
        return true
    false
  async: (v, cb) ->
    if not v instanceof Object
      return cb errorlet.create {error: 'object_validate:not_an_object', value: v, validator: @}
    errors = {}
    hasError = false
    funclet
      .each Object.keys(@inner), (key, next) =>
        inner = @inner[key]
        inner.async v[key], (err) ->
          if err 
            errors[key] = err
            hasError = true
          next null
      .catch(cb)
      .done () =>
        if hasError
          cb errorlet.create {error: 'object_validate:key_error', value: v, errors: errors, validator: @}
        else
          cb null

Validator.registerType 'object', ObjectValidator
    
module.exports = Validator



  