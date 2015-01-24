// Generated by CoffeeScript 1.4.0
(function() {
  var AndValidator, ArrayValidator, EventEmitter, ObjectValidator, OrValidator, RangeValidator, RegexValidator, Validator, email, errorlet, funclet, integer, loglet, natural, number, required, string,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  EventEmitter = require('events').EventEmitter;

  errorlet = require('errorlet');

  funclet = require('funclet');

  email = require('email-validator');

  loglet = require('loglet');

  Validator = (function(_super) {

    __extends(Validator, _super);

    Validator.registry = {};

    Validator.register = function(name, validator) {
      this.registry[name] = validator;
      return validator;
    };

    Validator.types = {};

    Validator.registerType = function(name, validatorClass) {
      this.types[name] = validatorClass;
      return this[name] = function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return (function(func, args, ctor) {
          ctor.prototype = func.prototype;
          var child = new ctor, result = func.apply(child, args);
          return Object(result) === result ? result : child;
        })(validatorClass, args, function(){});
      };
    };

    Validator.make = function(spec) {
      var key, val;
      if (spec instanceof this) {
        return spec;
      } else if (spec instanceof RegExp) {
        return new RegexValidator(spec);
      } else if (spec instanceof Object) {
        for (key in spec) {
          val = spec[key];
          if (this.types.hasOwnProperty(key)) {
            return this.types[key].make(val);
          }
        }
        throw errorlet.create({
          error: 'unknown_validator_type',
          spec: spec
        });
      } else if (typeof spec === 'string') {
        if (this.registry.hasOwnProperty(spec)) {
          return this.registry[spec];
        } else {
          throw errorlet.create({
            error: 'unknown_validator',
            name: spec
          });
        }
      } else {
        throw errorlet.create({
          error: 'invalid_validator_spec',
          spec: spec
        });
      }
    };

    function Validator(obj) {
      var key, val;
      if (obj == null) {
        obj = {};
      }
      for (key in obj) {
        val = obj[key];
        this[key] = val;
      }
      if (!this.isa || this.callback) {
        throw errorlet.create({
          error: 'validate_require_callback_or_run',
          message: 'validator requires a callback (async) or run (sync) function.'
        });
      }
    }

    Validator.prototype.isAsync = function() {
      return this.hasOwnProperty('callback') && (typeof this.callback === 'function') || (this.callback instanceof Function);
    };

    Validator.prototype.sync = function(v) {
      if (!this.isa(v)) {
        if (this.raise) {
          throw this.raise(v);
        } else {
          throw errorlet.create({
            error: "error:" + this.name,
            value: v,
            validator: this
          });
        }
      }
    };

    Validator.prototype.async = function(v, cb) {
      try {
        if (this.callback) {
          return this.callback(v, cb);
        } else {
          return cb(null, this.sync(v));
        }
      } catch (e) {
        return cb(e);
      }
    };

    Validator.prototype.validate = function(v) {
      var _this = this;
      if (this.isAsync()) {
        return this.async(v, function(err) {
          if (err) {
            return _this.emit('validate-error', err);
          } else {
            return _this.emit('validate-ok', v);
          }
        });
      } else {
        try {
          this.sync(v);
          return this.emit('validate-ok', v);
        } catch (e) {
          return this.emit('validate-error', e);
        }
      }
    };

    return Validator;

  })(EventEmitter);

  required = Validator.register('required', new Validator({
    name: 'required',
    isa: function(v) {
      return v !== null && v !== void 0 && v !== '';
    }
  }));

  string = Validator.register('string', new Validator({
    name: 'string',
    isa: function(v) {
      return typeof v === 'string';
    }
  }));

  Validator.register('email', new Validator({
    name: 'email',
    isa: function(v) {
      return email.validate(v);
    }
  }));

  RangeValidator = (function(_super) {

    __extends(RangeValidator, _super);

    RangeValidator.make = function(range) {
      var max, min;
      min = range[0], max = range[1];
      return new this(min, max);
    };

    function RangeValidator(min, max) {
      this.min = min;
      this.max = max;
    }

    RangeValidator.prototype.isa = function(v) {
      return (v != null ? v.length : void 0) && v.length >= this.min && v.length <= this.max;
    };

    return RangeValidator;

  })(Validator);

  Validator.registerType('range', RangeValidator);

  RegexValidator = (function(_super) {

    __extends(RegexValidator, _super);

    function RegexValidator(regex) {
      this.regex = regex;
    }

    RegexValidator.prototype.sync = function(v) {
      string.sync(v);
      if (!v.match(this.regex)) {
        throw errorlet.create({
          error: 'regex_validate',
          value: v,
          validator: this
        });
      }
    };

    return RegexValidator;

  })(Validator);

  number = Validator.register('number', new RegexValidator(/^[+-]?\d+(\.\d+)?$/));

  integer = Validator.register('integer', new RegexValidator(/^[+-]?\d+$/));

  natural = Validator.register('natural', new RegexValidator(/^\d+$/));

  ArrayValidator = (function(_super) {

    __extends(ArrayValidator, _super);

    ArrayValidator.make = function(inner) {
      return new this(Validator.make(inner));
    };

    function ArrayValidator(inner) {
      this.inner = inner;
    }

    ArrayValidator.prototype.isAsync = function() {
      return this.inner.isAsync();
    };

    ArrayValidator.prototype.sync = function(v) {
      var item, _i, _len, _results;
      if (!v instanceof Array) {
        throw errorlet.create({
          error: 'array_validate:not_array',
          value: v,
          message: "not an array.",
          validator: this
        });
      }
      _results = [];
      for (_i = 0, _len = v.length; _i < _len; _i++) {
        item = v[_i];
        _results.push(this.inner.sync(item));
      }
      return _results;
    };

    ArrayValidator.prototype.async = function(v, cb) {
      var _this = this;
      if (!v instanceof Array) {
        return cb(errorlet.create({
          error: 'array_validate:not_array',
          value: v,
          message: "not an array.",
          validator: this
        }));
      }
      return funclet.each(v, function(item, next) {
        return _this.inner.async(item, next);
      })["catch"](cb).done(function() {
        return cb(null);
      });
    };

    return ArrayValidator;

  })(Validator);

  Validator.registerType('array', ArrayValidator);

  AndValidator = (function(_super) {

    __extends(AndValidator, _super);

    AndValidator.make = function(list) {
      var inners, item;
      inners = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = list.length; _i < _len; _i++) {
          item = list[_i];
          _results.push(Validator.make(item));
        }
        return _results;
      })();
      return (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(this, inners, function(){});
    };

    function AndValidator() {
      var inners;
      inners = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      this.inners = inners;
    }

    AndValidator.prototype.sync = function(v) {
      var inner, _i, _len, _ref, _results;
      _ref = this.inners;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        inner = _ref[_i];
        _results.push(inner.sync(v));
      }
      return _results;
    };

    AndValidator.prototype.isAsync = function() {
      var inner, _i, _len, _ref;
      _ref = this.inners;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        inner = _ref[_i];
        if (inner.isAsync()) {
          return true;
        }
      }
      return false;
    };

    AndValidator.prototype.async = function(v, cb) {
      return funclet.each(this.inners, function(inner, next) {
        return inner.async(v, next);
      })["catch"](cb).done(function() {
        return cb(null);
      });
    };

    return AndValidator;

  })(Validator);

  Validator.registerType('and', AndValidator);

  OrValidator = (function(_super) {

    __extends(OrValidator, _super);

    OrValidator.make = function(list) {
      var inners, item;
      inners = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = list.length; _i < _len; _i++) {
          item = list[_i];
          _results.push(Validator.make(item));
        }
        return _results;
      })();
      return (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(this, inners, function(){});
    };

    function OrValidator() {
      var inners;
      inners = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      this.inners = inners;
    }

    OrValidator.prototype.sync = function(v) {
      var errors, inner, pass, _i, _len, _ref;
      errors = [];
      pass = false;
      _ref = this.inners;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        inner = _ref[_i];
        try {
          inner.sync(v);
          pass = true;
          return;
        } catch (e) {
          errors.push(e);
        }
      }
      throw errorlet.create({
        error: 'or_validate',
        inners: errors,
        validator: this
      });
    };

    OrValidator.prototype.isAsync = function() {
      var inner, _i, _len, _ref;
      _ref = this.inners;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        inner = _ref[_i];
        if (inner.isAsync()) {
          return true;
        }
      }
      return false;
    };

    OrValidator.prototype.async = function(v, cb) {
      var errors, pass;
      errors = [];
      pass = false;
      return funclet.each(this.inners, function(inner, next) {
        return inner.async(v, function(err) {
          if (err) {
            errors.push(err);
          } else {
            pass = true;
          }
          return next(null);
        });
      })["catch"](cb).done(function() {
        if (pass) {
          return cb(null);
        } else {
          throw errorlet.create({
            error: 'or_validate',
            value: v,
            errors: errors,
            validator: this
          });
        }
      });
    };

    return OrValidator;

  })(Validator);

  Validator.registerType('or', OrValidator);

  ObjectValidator = (function(_super) {

    __extends(ObjectValidator, _super);

    ObjectValidator.make = function(obj) {
      var inner, key, val;
      loglet.log('ObjectValidator.make', obj);
      inner = {};
      for (key in obj) {
        val = obj[key];
        inner[key] = Validator.make(val);
      }
      return new this(inner);
    };

    function ObjectValidator(inner) {
      this.inner = inner;
    }

    ObjectValidator.prototype.sync = function(v) {
      var errors, hasError, key, val, _ref;
      if (!v instanceof Object) {
        throw errorlet.create({
          error: 'object_validate:not_an_object',
          value: v,
          validator: this
        });
      }
      errors = {};
      hasError = false;
      _ref = this.inner;
      for (key in _ref) {
        val = _ref[key];
        try {
          val.sync(v[key]);
        } catch (e) {
          errors[key] = e;
          hasError = true;
        }
      }
      if (hasError) {
        throw errorlet.create({
          error: 'object_validate:key_error',
          value: v,
          errors: errors,
          validator: this
        });
      }
    };

    ObjectValidator.prototype.isAsync = function(v) {
      var key, val, _ref;
      _ref = this.inner;
      for (key in _ref) {
        val = _ref[key];
        if (val.isAsync()) {
          return true;
        }
      }
      return false;
    };

    ObjectValidator.prototype.async = function(v, cb) {
      var errors, hasError,
        _this = this;
      if (!v instanceof Object) {
        return cb(errorlet.create({
          error: 'object_validate:not_an_object',
          value: v,
          validator: this
        }));
      }
      errors = {};
      hasError = false;
      return funclet.each(Object.keys(this.inner), function(key, next) {
        var inner;
        inner = _this.inner[key];
        return inner.async(v[key], function(err) {
          if (err) {
            errors[key] = err;
            hasError = true;
          }
          return next(null);
        });
      })["catch"](cb).done(function() {
        if (hasError) {
          return cb(errorlet.create({
            error: 'object_validate:key_error',
            value: v,
            errors: errors,
            validator: _this
          }));
        } else {
          return cb(null);
        }
      });
    };

    return ObjectValidator;

  })(Validator);

  Validator.registerType('object', ObjectValidator);

  module.exports = Validator;

}).call(this);