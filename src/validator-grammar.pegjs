{
  function makeNumberAST(num, frac, exp) {
    return parseFloat([num, frac, exp].join(''));
  }
}

start 
= _ exp:Expression _ { return exp; }

Expression
= identifier 
/ NumberExp
/ FuncallExp

//******************** FUNCALL ******************************//
FuncallExp
= function:identifier _ params:_funcallParamsExp _ { return {funcall: function, args: params}; }

_funcallParamsExp
= '(' _ ')' _ { return []; }
/ '(' params:_funcallParamsList _ ')' _ { return params; }

_funcallParamsList
= exp:Expression _ rest:_restFuncallParam* { return [ exp ].concat(rest); }

_restFuncallParam
= ',' _ exp:Expression _ { return exp; }

//******************** IDENTIFIER ******************************//

identifier
= c:_idChar1 rest:_idCharRest* _ { return [c].concat(rest).join(''); }

_idChar1
= [a-z]
/ [A-Z]
/ '_'

_idCharRest
= _idChar1
/ [0-9]

//******************** NUMBER ******************************//

NumberExp
= int:int frac:frac exp:exp _ { 
  return makeNumberAST(int, frac, exp);
}
/ int:int frac:frac _     { 
  return makeNumberAST(int, frac, '');
}
/ '-' frac:frac _ { 
  return makeNumberAST('-', frac, '');
}
/ frac:frac _ { 
  return makeNumberAST('', frac, '');
}
/ int:int exp:exp _      { 
  return makeNumberAST(int, '', exp);
}
/ int:int _          { 
  return makeNumberAST(int, '', '');
}

int
= digits:digits { return digits.join(''); }
/ "-" digits:digits { return ['-'].concat(digits).join(''); }

frac
= "." digits:digits { return ['.'].concat(digits).join(''); }

exp
= e digits:digits { return ['e'].concat(digits).join(''); }

digits
= digit+

e
= [eE] [+-]?

digit
= [0-9]

digit19
= [1-9]

hexDigit
= [0-9a-fA-F]

//******************** WHITESPACE ******************************//
_ "whitespace"
= whitespace*

// Whitespace is undefined in the original JSON grammar, so I assume a simple
// conventional definition consistent with ECMA-262, 5th ed.
whitespace
= comment
/ [ \t\n\r]


lineTermChar
= [\n\r\u2028\u2029]

lineTerm "end of line"
= "\r\n"
/ "\n"
/ "\r"
/ "\u2028" // line separator
/ "\u2029" // paragraph separator

sourceChar
= .

// should also deal with comment.
comment
= multiLineComment
/ singleLineComment

singleLineCommentStart
= '//' // c style

singleLineComment
= singleLineCommentStart chars:(!lineTermChar sourceChar)* lineTerm? { 
  return {comment: chars.join('')}; 
}

multiLineComment
= '/*' chars:(!'*/' sourceChar)* '*/' { return {comment: chars.join('')}; }
