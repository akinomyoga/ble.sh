#!/usr/bin/gawk -f

# 20120726 行番号出力機能 (例: '#line 12 a.cpp')

function awk_getfiledir(_ret) {
  _ret = m_lineno_cfile;
  sub(/[^\/\\]+$/, "", _ret);
  if (_ret == "/") return "/";
  sub(/[\/\\]$/, "", _ret);
  return _ret;
}

function print_error(title, msg) {
  global_errorCount++;
  print "\33[1;31m" title "!\33[m " msg > "/dev/stderr";
}

function trim(text) {
  #gsub(/^[ \t]+|[ \t]+$/, "", text);
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", text);
  return text;
}

function slice(text, start, end, _l) {
  _l = length(text);
  if (start < 0) start += _l;
  end = end == null ? _l : end < 0 ? end + _l : end;

  return substr(text, start + 1, end - start);
}

#function head_token(text, ret, _, _i, _l) {
#  _i = match(text, /[^-a-zA-Z:0-9_]/);
#  _l = _i ? _i - 1 : length(text);
#  ret[0] = trim(substr(text, 1, _l));
#  ret[1] = trim(substr(text, _l + 1));
#}

#-------------------------------------------------------------------------------
function unescape(text, _, _ret, _capt) {
  _ret = "";
  while (match(text, /\\(.)/, _capt) > 0) {
    _ret = _ret substr(text, 1, RSTART - 1) _capt[1];
    text = substr(text, RSTART + RLENGTH);
  }
  return _ret text;
}

#-------------------------------------------------------------------------------
# replace
function replace(text, before, after, _is_tmpl, _is_head, _captures, _rep, _ltext, _rtext) {
  _is_tmpl = (match(after, /\$[0-9]+/) > 0);
  _is_head = (substr(before, 1, 1) == "^");

  _ret = "";
  while (match(text, before, _captures) > 0) {
    _ltext = substr(text, 1, RSTART - 1);
    _rtext = substr(text, RSTART + RLENGTH);

    _rep = _is_tmpl ? rep_instantiate_tmpl(after, _captures) : after;

    _ret = _ret _ltext _rep;
    text = _rtext;

    if (_is_head) break;
    if (RLENGTH == 0) {
      _ret = _ret substr(text, 1, 1);
      text = substr(text, 2);
      if (length(text) == 0) break;
    }
  }
  return _ret text;
}
function rep_instantiate_tmpl(text, captures, _, _ret, _num, _insert) {
  _ret = "";
  while (match(text, /\\(.)|\$([0-9]+)/, _num)) {
    #print "dbg: $ captured: RSTART = " RSTART "; num = " _num[1] "; captures[num] = " captures[_num[1]] > "/dev/stderr"
    if (_num[2] != "") {
      _insert = captures[_num[2]];
    } else if (_num[1] ~ /^[$\\]$/) {
      _insert = _num[1];
    } else {
      _insert = _num[0];
    }
    _ret = _ret substr(text, 1, RSTART - 1) _insert;
    text = substr(text, RSTART + RLENGTH);
  }
  return _ret text;
}

#===============================================================================
#  mwg_pp.eval
#-------------------------------------------------------------------------------
# function eval_expr(expression);

# -*- mode:awk -*-

function ev1scan_init_opregister(opname, optype, opprec) {
  ev_db_operator[opname] = optype;
  ev_db_operator[opname, "a"] = opprec;
}

function ev1scan_init() {
  OP_BIN = 1;
  OP_UNA = 2; # prefix
  OP_SGN = 3; # prefix or binary
  OP_INC = 4; # prefix or suffix

  ev1scan_init_opregister("." , OP_BIN, 12.0);

  ev1scan_init_opregister("++", OP_INC, 11.0);
  ev1scan_init_opregister("--", OP_INC, 11.0);
  ev1scan_init_opregister("!" , OP_UNA, 11.0);

  ev1scan_init_opregister("*" , OP_BIN, 10.0);
  ev1scan_init_opregister("/" , OP_BIN, 10.0);
  ev1scan_init_opregister("%" , OP_BIN, 10.0);

  ev1scan_init_opregister("+" , OP_SGN, 9.0);
  ev1scan_init_opregister("-" , OP_SGN, 9.0);

  ev1scan_init_opregister("==", OP_BIN, 8.0);
  ev1scan_init_opregister("!=", OP_BIN, 8.0);
  ev1scan_init_opregister("<" , OP_BIN, 8.0);
  ev1scan_init_opregister("<=", OP_BIN, 8.0);
  ev1scan_init_opregister(">" , OP_BIN, 8.0);
  ev1scan_init_opregister(">=", OP_BIN, 8.0);

  ev1scan_init_opregister("&" , OP_BIN, 7.4);
  ev1scan_init_opregister("^" , OP_BIN, 7.2);
  ev1scan_init_opregister("|" , OP_BIN, 7.0);
  ev1scan_init_opregister("&&", OP_BIN, 6.4);
  ev1scan_init_opregister("||", OP_BIN, 6.0);

  ev1scan_init_opregister("=" , OP_BIN, 2.0);
  ev1scan_init_opregister("+=", OP_BIN, 2.0);
  ev1scan_init_opregister("-=", OP_BIN, 2.0);
  ev1scan_init_opregister("*=", OP_BIN, 2.0);
  ev1scan_init_opregister("/=", OP_BIN, 2.0);
  ev1scan_init_opregister("%=", OP_BIN, 2.0);
  ev1scan_init_opregister("|=", OP_BIN, 2.0);
  ev1scan_init_opregister("^=", OP_BIN, 2.0);
  ev1scan_init_opregister("&=", OP_BIN, 2.0);
  ev1scan_init_opregister("," , OP_BIN, 1.0);

  # for ev2
  SE_VALU = 1;
  SE_PREF = 0;
  SE_MARK = -1;

  ATTR_SET = "t";
  ATTR_TYP = "T";
  ATTR_MOD = "M";

  MOD_NUL = 0;
  MOD_REF = 1;
  ATTR_REF = "R";
  MOD_ARG = 2;
  MOD_ARR = 4;
  MOD_MTH = 8;
  ATTR_MTH_OBJ = "Mo";
  ATTR_MTH_MEM = "Mf";

  TYPE_NUM = 0;
  TYPE_STR = 1;
}

function ev1scan_scan(expression, words, _wlen, _i, _len, _c, _t, _w) {
  _wlen = 0;
  _len = length(expression);
  for (_i = 0; _i < _len; _i++) {
    _c = substr(expression, _i + 1, 1);

    if (_c ~ /[.0-9]/) {
      _t = "n";
      _w = _c;
      while (_i + 1 < _len) {
        _c = substr(expression, _i + 2, 1);
        if (_c !~ /[.0-9]/) break;
        _w = _w _c;
        _i++;
      }
      #if (_w == ".")_w = 0;
      if (_w == ".") {
        _t = "o";
      }
    } else if (ev_db_operator[_c] != "") {
      _t = "o";
      _w = _c;
      while (_i + 1 < _len) {
        _c = substr(expression, _i + 2, 1);
        #print "dbg: ev_db_op[" _w _c "] = " ev_db_operator[_w _c] > "/dev/stderr"
        if (ev_db_operator[_w _c] != "") {
          _w = _w _c;
          _i++;
        } else break;
      }
    } else if (_c ~ "[[({?]") {
      _t = "op";
      _w = _c;
    } else if (_c ~ "[])}:]") {
      _t = "cl";
      _w = _c;
    } else if (_c ~ /[_a-zA-Z]/) {
      _t = "w";
      _w = _c;
      while (_i + 1 < _len) {
        _c = substr(expression, _i + 2, 1);
        if (_c !~ /[_a-zA-Z0-9]/) break;
        _w = _w _c;
        _i++;
      }
    } else if (_c == "\"") {
      # string literal
      _t = "S";
      _w = "";
      while (_i + 1 < _len) {
        _c = substr(expression, _i + 2, 1);
        _i++;
        if (_c  == "\"") {
          break;
        } else if (_c == "\\") {
          #print_error("dbg: (escchar = " _c " " substr(expression, _i + 2, 1) ")" );
          if (_i + 1 < _len) {
            _w = _w ev1scan_scan_escchar(substr(expression, _i + 2, 1));
            _i++;
          } else {
            _w = _w _c;
          }
        } else {
          _w = _w _c;
        }
      }
    } else if (_c ~ /[[:space:]]/) {
      continue; # ignore blank
    } else {
      print_error("mwg_pp.eval_expr", "unrecognizable character '" _c "'");
      continue; # ignore unknown character
    }

    words[_wlen, "t"] = _t;
    words[_wlen, "w"] = _w;
    _wlen++;
  }

  # debug
  #for (_i = 0; _i < _wlen; _i++) {
  #    print "yield " words[_i, "w"] " as " words[_i, "t"] > "/dev/stderr"
  #}

  return _wlen;
}

function ev1scan_scan_escchar(c) {
  if (c !~ /[nrtvfaeb]/) return c;
  if (c == "n") return "\n";
  if (c == "r") return "\r";
  if (c == "t") return "\t";
  if (c == "v") return "\v";
  if (c == "f") return "\f";
  if (c == "a") return "\a";
  if (c == "e") return "\33";
  if (c == "b") return "\b";
  return c;
}

function ev1scan_cast_bool(arg) {
  return arg != 0 && arg != "";
}
# -*- mode: awk -*-

function eval_expr(expression) {
  return ev2_expr(expression);
}

function ev2_expr(expression, _wlen, _words, _i, _len, _t, _w, _v, _sp, _s, _sp1, _optype) {
  _wlen = ev1scan_scan(expression, _words);

  # <param name="_s">
  #  parsing stack
  #  _s[index, "t"]  : SE_PREF  SE_MARK  SE_VALU
  #  _s[index]       : lhs               value
  #  _s[index, "T"]  : dataType          dataType
  #  _s[index, "c"]  : b+ u!    op
  #  _s[index, "l"]  : assoc
  #
  #  _s[index, "M"] = MOD_ARG;
  #  _s[index, "A"] = length;
  #  _s[index, "A", i] = element;
  # </param>

  # parse
  _sp = -1;
  for (_i = 0; _i < _wlen; _i++) {
    # _t: token type
    # _w: token word
    # _l: token prefix level
    _t = _words[_i, "t"];
    _w = _words[_i, "w"];

    #-- process token --
    if (_t == "n") {
      _sp++;
      _s[_sp] = 0 + _w;
      _s[_sp, "t"] = SE_VALU;
      _s[_sp, "T"] = TYPE_NUM;
      _s[_sp, "M"] = MOD_NUL;
    #---------------------------------------------------------------------------
    } else if (_t == "o") {
      _optype = ev_db_operator[_w];
      if (_optype == OP_SGN) { # signature operator +-
        if (_sp >= 0 && _s[_sp, "t"] == SE_VALU) {
          _t = "b"; # binary operator
        } else {
          _t = "u"; # unary operator
        }
      } else if (_optype == OP_BIN) { # binary operator
        _t = "b";
      } else if (_optype == OP_UNA) { # unary prefix operator
        _t = "u";
      } else if (_optype == OP_INC) { # operator++ --
        if (_sp >= 0 && _s[_sp, "t"] == SE_VALU) {
          if (and(_s[_sp, "M"], MOD_REF)) {
            if (_w == "++")
              d_data[_s[_sp, "R"]]++;
            else if (_w == "--")
              d_data[_s[_sp, "R"]]--;
            else
              print_error("mwg_pp.eval", "unknown increment operator " _w);

            _s[_sp, "M"] = MOD_NUL;
            delete _s[_sp, "R"];
          }

          _t = "";
        } else {
          _t = "u"; # unary operator
        }
      } else {
        print_error("mwg_pp.eval", "unknown operator " _w);
      }

      if (_t == "b") {
        #-- binary operator
        _l = ev_db_operator[_w, "a"];
        #print "dbg: binary operator level = " _l > "/dev/stderr"

        # get lhs
        _sp = ev2_pop_value(_s, _sp, _l); # left assoc
        #_sp = ev2_pop_value(_s, _sp, _l + 0.1); # right assoc # TODO =

        # overwrite to lhs
        _s[_sp, "t"] = SE_PREF;
        _s[_sp, "p"] = "b";
        _s[_sp, "P"] = _w;
        _s[_sp, "l"] = _l; # assoc level
      } else if (_t == "u") {
        # unary operator
        _l = ev_db_operator[_w, "a"];

        _sp++;
        _s[_sp, "t"] = SE_PREF
        _s[_sp, "p"] = "u";
        _s[_sp, "P"] = _w;
        _s[_sp, "l"] = _l; # assoc level
      }
    #---------------------------------------------------------------------------
    } else if (_t == "op") {
      _sp++;
      _s[_sp, "t"] = SE_MARK;
      _s[_sp, "m"] = _w;
    } else if (_t == "cl") {
      if (_sp >= 0 && _s[_sp, "t"] == SE_VALU) {
        _sp1 = ev2_pop_value(_s, _sp, 0);
        _sp = _sp1-1;
      } else {
        # empty arg
        _sp1 = _sp+1;
        _s[_sp1] = "";
        _s[_sp1, "t"] = SE_VALU;
        _s[_sp1, "T"] = TYPE_STR;
        _s[_sp1, "M"] = MOD_ARG;
        _s[_sp1, "A"] = 0;
      }
      # state: [.. _sp=open _sp1]

      # parentheses
      if (!(_sp >= 0 && _s[_sp, "t"] == SE_MARK)) {
        print_error("mwg_pp.eval: no matching open paren to " _w " in " expression);
        continue;
      }
      _w = _s[_sp, "m"] _w;
      _sp--;


      # state: [_sp open _sp1]
      if (_sp >= 0 && _s[_sp, "t"] == SE_VALU) {
        if (_w == "?:") {
          _sp = ev2_pop_value(_s, _sp, 3.0); # assoc_value_3
          _v = (_s[_sp] != 0 && _s[_sp] != "") ? "T" : "F";
          #print_error("dbg: _s[_sp]=" _s[_sp] " _v=" _v);

          # last element
          _s[_sp] = _s[_sp1];
          _s[_sp, "t"] = SE_VALU;
          _s[_sp, "T"] = _s[_sp1, "T"];
          _s[_sp, "M"] = MOD_NUL; #TODO reference copy

          # overwrite pref
          _s[_sp, "t"] = SE_PREF;
          _s[_sp, "p"] = _w;
          _s[_sp, "P"] = _v;
          _s[_sp, "l"] = 3.0; # level
        } else {
          _sp = ev2_pop_value(_s, _sp, 12); # assoc_value_12

          if (_w == "[]" && and(_s[_sp, "M"], MOD_REF)) {
            # indexing
            _s[_sp] = d_data[_s[_sp, "R"], _s[_sp1]];
            _s[_sp, "t"] = SE_VALU;
            _s[_sp, "T"] = (_s[_sp] == 0 + _s[_sp]? TYPE_NUM: TYPE_STR);
            _s[_sp, "M"] = MOD_REF;
            _s[_sp, "R"] = _s[_sp, "R"] SUBSEP _s[_sp1];
          } else if (and(_s[_sp, "M"], MOD_REF)) {
            # function call
            ev2_funcall(_s, _sp, _s[_sp, "R"], _s, _sp1);
          } else if (and(_s[_sp, "M"], MOD_MTH)) {
            # member function call
            ev2_memcall(_s, _sp, _s, _sp SUBSEP ATTR_MTH_OBJ, _s[_sp, ATTR_MTH_MEM], _s, _sp1);
          } else {
            print "mwg_pp.eval: invalid function call " _s[_sp] " " _w " in " expression > "/dev/stderr"
          }
        }
      } else {
        _sp++;
        if (_w == "[]") {
          # array
          ev2_copy(_s, _sp, _s, _sp1);
          _s[_sp, "M"] = MOD_ARR;
        } else {
          # last element
          _s[_sp] = _s[_sp1];
          _s[_sp, "t"] = SE_VALU;
          _s[_sp, "T"] = _s[_sp1, "T"];
          _s[_sp, "M"] = MOD_NUL;
        }
      }
    #---------------------------------------------------------------------------
    } else if (_t == "w") {
      _sp++;
      _s[_sp] = d_data[_w];
      _s[_sp, "t"] = SE_VALU;
      _s[_sp, "T"] = (_s[_sp] == 0 + _s[_sp]? TYPE_NUM: TYPE_STR);
      _s[_sp, "M"] = MOD_REF;
      _s[_sp, "R"] = _w;
    } else if (_t == "S") {
      # string
      _sp++;
      _s[_sp] = _w;
      _s[_sp, "t"] = SE_VALU;
      _s[_sp, "T"] = TYPE_STR;
      _s[_sp, "M"] = MOD_NUL;
    } else {
      print_error("mwg_pp.eval:fatal", "unknown token type " _t);
    }
  }

  _sp = ev2_pop_value(_s, _sp, 0);
  return _sp >= 1? "err": _s[_sp];
}

function ev2_pop_value(s, sp, assoc, rDict, rName, _vp, _value) {
  # <param> rDict [default = s]
  # <param> rName [default = <final stack top>]
  # <returns> sp = <final stack top>

  # read value
  if (sp >= 0 && s[sp, "t"] == SE_VALU) {
    sp--;
  } else {
    _vp = sp + 1;
    s[_vp] = 0;
    s[_vp, "t"] = SE_VALU;
    s[_vp, "T"] = TYPE_NUM;
    s[_vp, "M"] = MOD_NUL;
  }

  # proc prefices
  while(sp >= 0 && s[sp, "t"] == SE_PREF && s[sp, "l"] >= assoc) {
    ev2_apply(s, sp, sp + 1);
    sp--;
  }

  if (rDict == "")
    sp++;
  else
    ev2_copy(rDict, rName, s, sp + 1);

  return sp;
}

function ev2_memget(dDict, dName, oDict, oName, memname) {
  #print_error("mwg_pp.eval", "dbg: ev2_memget(memname=" memname ")");

  # embedded special member
  if (oDict[oName, "T"] == TYPE_STR) {
    if (memname == "length") {
      dDict[dName] = length(oDict[oName]);
      dDict[dName, "t"] = SE_VALU;
      dDict[dName, "T"] = TYPE_NUM;
      dDict[dName, "M"] = MOD_NUL;
      return;
    } else if (memname == "replace" || memname == "Replace" || memname == "slice" || memname ~ /^to(upper|lower)$/) {
      ev2_copy(dDict, dName SUBSEP ATTR_MTH_OBJ, oDict, oName);
      dDict[dName, ATTR_MTH_MEM] = memname;
      dDict[dName] = "";
      dDict[dName, "t"] = SE_VALU;
      dDict[dName, "T"] = TYPE_STR;
      dDict[dName, "M"] = MOD_MTH;
      #print_error("mwg_pp.eval", "dbg: method = String#" memname);
      return;
    }
  } else {
    # members for other types (TYPE_NUM MOD_ARR etc..)
  }

  # normal data member
  if (and(oDict[oName, ATTR_MOD], MOD_REF)) {
    dDict[dName] = d_data[oDict[oName, ATTR_REF], memname];
    dDict[dName, "t"] = SE_VALU;
    dDict[dName, "T"] = (dDict[dName] == 0 + dDict[dName]? TYPE_NUM: TYPE_STR);
    dDict[dName, "M"] = MOD_REF;
    dDict[dName, ATTR_REF] = oDict[oName, ATTR_REF] SUBSEP memname;
  } else {
    print_error("mwg.eval", "invalid member name '" memname "'");
    dDict[dName] = "";
    dDict[dName, "t"] = SE_VALU;
    dDict[dName, "T"] = TYPE_STR;
    dDict[dName, "M"] = MOD_NUL;
  }

  # rep: dDict dName oDict oName
}

function ev2_memcall(dDict, dName, oDict, oName, memname, aDict, aName, _a, _i, _c, _result, _resultT) {
  #print_error("mwg_pp.eval", "dbg: ev2_memcall(memname=" memname ")");

  _resultT = "";

  # read arguments
  if (aDict[aName, "M"] != MOD_ARG) {
    _c = 1;
    _a[0] = aDict[aName];
  } else {
    _c = aDict[aName, "A"];
    for (_i = 0; _i < _c; _i++) _a[_i] = aDict[aName, "A", _i];
  }

  #-----------------
  # process
  if (oDict[oName, "T"] == TYPE_STR) {
    if (memname == "replace") {
      _result = oDict[oName];
      gsub(_a[0], _a[1], _result);
      _resultT = TYPE_STR;
    } else if (memname == "Replace") {
      _result = replace(oDict[oName], _a[0], _a[1]);
      _resultT = TYPE_STR;
    } else if (memname == "slice") {
      _result = slice(oDict[oName], _a[0], _a[1]);
      _resultT = TYPE_STR;
    } else if (memname == "toupper") {
      _result = toupper(oDict[oName]);
      _resultT = TYPE_STR;
    } else if (memname == "tolower") {
      _result = tolower(oDict[oName]);
      _resultT = TYPE_STR;
    }
  }

  #-----------------
  # write value
  if (_resultT == "") {
    print_error("mwg.eval", "invalid member function name '" memname "'");
    _result = "";
    _resultT = TYPE_STR;
  }

  dDict[dName] = _result;
  dDict[dName, "t"] = SE_VALU;
  dDict[dName, "T"] = _resultT;
  dDict[dName, "M"] = MOD_NUL;
}

function ev2_funcall(dDict, dName, funcname, aDict, aName, _a, _i, _c, _result, _resultT, _cmd, _line) {
  _resultT = TYPE_NUM;

  if (aDict[aName, "M"] != MOD_ARG) {
    _c = 1;
    _a[0] = aDict[aName];
  } else {
    _c = aDict[aName, "A"];
    for (_i = 0; _i < _c; _i++) _a[_i] = aDict[aName, "A", _i];
  }

  if (funcname == "int") {
    _result = int(_a[0]);
  } else if (funcname == "float") {
    _result = 0 + _a[0];
  } else if (funcname == "floor") {
    if (_a[0] >= 0) {
      _result = int(_a[0]);
    } else {
      _result = int(1 - _a[0]);
      _result = int(_a[0] + _result)-_result;
    }
  } else if (funcname == "ceil") {
    if (_a[0] <= 0) {
      _result = int(_a[0]);
    } else {
      _result = int(1 + _a[0]);
      _result = int(_a[0]-_result) + _result;
    }
  } else if (funcname == "sqrt") {
    _result = sqrt(_a[0]);
  } else if (funcname == "sin") {
    _result = sin(_a[0]);
  } else if (funcname == "cos") {
    _result = cos(_a[0]);
  } else if (funcname == "tan") {
    _result = sin(_a[0]) / cos(_a[0]);
  } else if (funcname == "atan") {
    _result = atan2(_a[0], 1);
  } else if (funcname == "atan2") {
    _result = atan2(_a[0], _a[1]);
  } else if (funcname == "exp") {
    _result = exp(_a[0]);
  } else if (funcname == "log") {
    _result = log(_a[0]);
  } else if (funcname == "sinh") {
    _x = exp(_a[0]);
    _result = 0.5*(_x-1/_x);
  } else if (funcname == "cosh") {
    _x = exp(_a[0]);
    _result = 0.5 * (_x + 1 / _x);
  } else if (funcname == "tanh") {
    _x = exp(2 * _a[0]);
    _result = (_x - 1) / (_x + 1);
  } else if (funcname == "rand") {
    _result = rand();
  } else if (funcname == "srand") {
    _result = srand(_a[0]);
  } else if (funcname == "trim") {
    _resultT = TYPE_STR;
    _result = _a[0];
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", _result);
  } else if (funcname == "sprintf") {
    _resultT = TYPE_STR;
    _result = sprintf(_a[0], _a[1], _a[2], _a[3], _a[4], _a[5], _a[6], _a[7], _a[8], _a[9]);
  } else if (funcname == "slice") {
    _resultT = TYPE_STR;
    _result = slice(_a[0], _a[1], _a[2]);
  } else if (funcname == "length") {
    _result = length(_a[0]);
  } else if (funcname == "getenv") {
    _resultT = TYPE_STR;
    _result = ENVIRON[_a[0]];
  } else if (funcname == "system") {
    _resultT = TYPE_STR;
    _result = "";
    _cmd = _a[0];
    while ((_cmd | getline _line) > 0)
       _result = _result _line "\n";
    close(_cmd);
    sub(/\n+$/, "", _result);
  } else {
    print_error("mwg_pp.eval", "unknown function " funcname);
    _result = 0;
  }

  dDict[dName] = _result;
  dDict[dName, "t"] = SE_VALU;
  dDict[dName, "T"] = _resultT;
  dDict[dName, "M"] = MOD_NUL;
}

function ev2_unsigned(value) {
  return value >= 0 ? value : value + 0x100000000;
}

function ev2_apply(stk, iPre, iVal, _pT, _pW, _lhs, _rhs, _lhsT, _rhsT, _result, _i, _a, _b, _c) {
  # <param name="stk">stack</param>
  # <param name="iPre">prefix operator/resulting value</param>
  # <param name="iVal">input value</param>

  _pT = stk[iPre, "p"];
  _pW = stk[iPre, "P"];

  if (_pT == "b") {
    _lhs = stk[iPre];
    _rhs = stk[iVal];
    _lhsT = stk[iPre, "T"];
    _rhsT = stk[iVal, "T"];
    _resultT = TYPE_NUM;

    #print "binary " _lhs " " _pW " " _rhs > "/dev/stderr"
    if (_pW == "+") {
      if (_lhsT == TYPE_STR || _rhsT == TYPE_STR) {
        _result = _lhs _rhs;
        _resultT = TYPE_STR;
      } else
        _result = _lhs+_rhs;
    } else if (_pW == "-") _result = _lhs - _rhs;
    else if (_pW == "*") _result = _lhs * _rhs;
    else if (_pW == "/") _result = _lhs / _rhs;
    else if (_pW == "%") _result = _lhs % _rhs;
    else if (_pW == "==") _result = _lhs == _rhs;
    else if (_pW == "!=") _result = _lhs != _rhs;
    else if (_pW == ">=") _result = _lhs >= _rhs;
    else if (_pW == "<=") _result = _lhs <= _rhs;
    else if (_pW == "<") _result = _lhs < _rhs;
    else if (_pW == ">") _result = _lhs > _rhs;
    else if (_pW == "|") _result = or(ev2_unsigned(_lhs), ev2_unsigned(_rhs));
    else if (_pW == "^") _result = xor(ev2_unsigned(_lhs), ev2_unsigned(_rhs));
    else if (_pW == "&") _result = and(ev2_unsigned(_lhs), ev2_unsigned(_rhs));
    else if (_pW == "||") _result = ev1scan_cast_bool(_lhs) || ev1scan_cast_bool(_rhs); # not lazy evaluation
    else if (_pW == "&&") _result = ev1scan_cast_bool(_lhs) && ev1scan_cast_bool(_rhs); # not lazy evaluation
    else if (_pW ~ /[-+*/%|^&]?=/) {
      if (and(stk[iPre, "M"], MOD_REF)) {
        _resultT = TYPE_NUM;
        if (_pW == "=") {
          _result = _rhs;
          _resultT = _rhsT;
        } else if (_pW == "+=") _result = _lhs + _rhs;
        else if (_pW == "-=") _result = _lhs - _rhs;
        else if (_pW == "*=") _result = _lhs * _rhs;
        else if (_pW == "/=") _result = _lhs / _rhs;
        else if (_pW == "%=") _result = _lhs % _rhs;
        else if (_pW == "|=") _result = or(ev2_unsigned(_lhs), ev2_unsigned(_rhs));
        else if (_pW == "^=") _result = xor(ev2_unsigned(_lhs), ev2_unsigned(_rhs));
        else if (_pW == "&=") _result = and(ev2_unsigned(_lhs), ev2_unsigned(_rhs));

        stk[iPre] = _result;
        stk[iPre, "t"] = SE_VALU;
        stk[iPre, "T"] = _resultT;
        d_data[stk[iPre, "R"]] = _result;

        # TODO: array copy?
      } else {
        ev2_copy(stk, iPre, stk, iVal);
        # err?
      }
      return;
    } else if (_pW == ",") {
      if (stk[iPre, "M"] == MOD_ARG) {
        stk[iPre] = _rhs;
        stk[iPre, "t"] = SE_VALU;
        stk[iPre, "T"] = _rhsT;
        _i = stk[iPre, "A"]++;
        ev2_copy(stk, iPre SUBSEP "A" SUBSEP _i, stk, iVal);
      } else {
        stk[iPre, "t"] = SE_VALU;
        ev2_copy(stk, iPre SUBSEP "A" SUBSEP 0, stk, iPre);
        ev2_copy(stk, iPre SUBSEP "A" SUBSEP 1, stk, iVal);
        stk[iPre] = _rhs;
        stk[iPre, "T"] = _rhsT;
        stk[iPre, "M"] = MOD_ARG;
        stk[iPre, "A"] = 2;
      }
      return;
    } else if (_pW == ".") {
      _a = and(stk[iVal, "M"], MOD_REF)? stk[iVal, ATTR_REF]: _rhs;
      stk[iPre, "t"] = SE_VALU;
      ev2_memget(stk, iPre, stk, iPre, _a);
      return;
    }

    stk[iPre] = _result;
    stk[iPre, "t"] = SE_VALU;
    stk[iPre, "T"] = _resultT;
    stk[iPre, "M"] = MOD_NUL;
  } else if (_pT == "u") {
    _rhs = stk[iVal];

    if (_pW == "+") _result = _rhs;
    else if (_pW == "-") _result = -_rhs;
    else if (_pW == "!") _result = !ev1scan_cast_bool(_rhs);
    else if (_pW == "++") {
      _result = _rhs+1;
      stk[iPre] = _result;
      stk[iPre, "t"] = SE_VALU;
      stk[iPre, "T"] = TYPE_NUM;
      if (and(stk[iVal, "M"], MOD_REF)) {
        stk[iPre, "M"] = MOD_REF;
        stk[iPre, "R"] = stk[iVal, "R"];
        d_data[stk[iPre, "R"]] = _result;
      } else {
        stk[iPre, "M"] = MOD_NUL;
      }
      return;
    } else if (_pW == "--") {
      _result = _rhs-1;
      stk[iPre] = _result;
      stk[iPre, "t"] = SE_VALU;
      stk[iPre, "T"] = TYPE_NUM;
      if (and(stk[iVal, "M"], MOD_REF)) {
        stk[iPre, "M"] = MOD_REF;
        stk[iPre, "R"] = stk[iVal, "R"];
        d_data[stk[iPre, "R"]] = _result;
      } else {
        stk[iPre, "M"] = MOD_NUL;
      }
      return;
    }

    stk[iPre] = _result;
    stk[iPre, "t"] = SE_VALU;
    stk[iPre, "T"] = TYPE_NUM;
    stk[iPre, "M"] = MOD_NUL;
  } else if (_pT == "?:") {
    if (_pW == "T") {
      stk[iPre, "t"] = SE_VALU;
    } else {
      ev2_copy(stk, iPre, stk, iVal);
    }
  } else {
    ev2_copy(stk, iPre, stk, iVal);
  }
}

function ev2_copy(dDict, dName, sDict, sName, _M, _t, _i, _iN) {
  # assertion
  if (sDict[sName, "t"] != SE_VALU) {
    print_error("mwg_pp.eval:fatal", "copying not value element");
  }

  dDict[dName] = sDict[sName];                # value
  _t = dDict[dName, "t"] = sDict[sName, "t"]; # sttype
  _M = dDict[dName, "M"] = sDict[sName, "M"]; # mod

  if (_t == SE_VALU)
    dDict[dName, "T"] = sDict[sName, "T"];  # datatype

  # special data
  if (and(_M, MOD_REF)) {
    # reference
    dDict[dName, "R"] = sDict[sName, "R"]; # name in d_data
  }
  if (and(_M, MOD_ARG) || and(_M, MOD_ARR)) {
    # argument/array
    _iN = dDict[dName, "A"] = sDict[sName, "A"]; # array length
    for (_i = 0; _i < _iN; _i++)
      ev2_copy(dDict, dName SUBSEP "A" SUBSEP _i, sDict, sName SUBSEP "A" SUBSEP _i);
  }
  if (and(_M, MOD_MTH)) {
    # member function
    dDict[dName, ATTR_MTH_MEM] = sDict[sName, ATTR_MTH_MEM];
    ev2_copy(dDict, dName SUBSEP ATTR_MTH_OBJ, sDict, sName SUBSEP ATTR_MTH_OBJ);
  }
}

function ev2_delete(sDict, sName) {
  if (sDict[sName, "t"] != SE_VALU) {
    print_error("mwg_pp.eval:fatal", "deleting not value element");
  }

  delete sDict[sName];     # value
  delete sDict[sName, "t"]; # sttype
  delete sDict[sName, "T"]; # datatype
  _M = sDict[sName, "M"];     # mod
  delete sDict[sName, "M"];

  # special data
  if (_M == MOD_REF) {
    # reference
    delete sDict[sName, "R"]; # name in d_data
  } else if (_M == MOD_ARG || _M == MOD_ARR) {
    # argument/array
    _iN = sDict[sName, "A"];
    delete sDict[sName, "A"]; # array length
    for (_i = 0; _i < _iN; _i++)
      ev2_delete(sDict, sName SUBSEP "A" SUBSEP _i);
  }
}

# TODO? Dict[sp]       -> Dict[sp, "v"]
# TODO? s[i, "c"]="b+" -> s[i, "k"]="b" s["o"]="+"

#===============================================================================
#  Parameter Expansion
#-------------------------------------------------------------------------------
function inline_expand(text, _, _ret, _ltext, _rtext, _mtext, _name, _r, _s, _a, _caps) {
  _ret = "";
  while (match(text, /\${([^{}]|\\.)+}|\$"([^"]|\\.)+"/) > 0) {
    _ltext = substr(text, 1, RSTART - 1);
    _mtext = substr(text, RSTART, RLENGTH);
    _rtext = substr(text, RSTART + RLENGTH);
    _name = unescape(slice(_mtext, 2, -1));
    if (match(_name, /^[-a-zA-Z0-9_]+$/) > 0) {                     # ${key}
      _r = "" d_data[_name];
    } else if (match(_name, /^[-a-zA-Z0-9_]+:-/) > 0) {             # ${key:-alter}
      _s["key"] = slice(_name, 0, RLENGTH - 2);
      _s["alter"] = slice(_name, RLENGTH);
      _r = "" d_data[_s["key"]];
      if (_r == "") _r = _s["alter"];
    } else if (match(_name, /^[-a-zA-Z0-9_]+:\+/) > 0) {            # ${key:+value}
      _s["key"] = slice(_name, 0, RLENGTH - 2);
      _s["value"] = slice(_name, RLENGTH);
      _r = "" d_data[_s["key"]];
      _r = _r == "" ? "" : _s["value"];
    } else if (match(_name, /^[-a-zA-Z0-9_]+:\?/) > 0) {            # ${key:?warn}
      _s["key"] = slice(_name, 0, RLENGTH - 2);
      _s["warn"] = slice(_name, RLENGTH);
      _r = "" d_data[_s["key"]];
      if (_r == "") {
        print "(parameter expansion:" _mtext ")! " _s["warn"] > "/dev/stderr"
        _ltext = _ltext _mtext;
        _r = "";
      }
    } else if (match(_name, /^([-a-zA-Z0-9_]+):([0-9]+):([0-9]+)$/, _caps) > 0) { # ${key:start:length}
      _r = substr(d_data[_caps[1]], _caps[2] + 1, _caps[3]);
    } else if (match(_name, /^([-a-zA-Z0-9_]+)(\/\/?)(([^/]|\\.)+)\/(.*)$/, _caps) > 0) { # ${key/before/after}
      _r = d_data[_caps[1]];
      if (_caps[3] == "/")
        sub(_caps[3], _caps[5], _r);
      else
        gsub(_caps[3], _caps[5], _r);
    } else if (match(_name, /^([-a-zA-Z0-9_]+)(##?|%%?)(.+)$/, _caps) > 0) { # ${key#head} ${key%tail}
      if (length(_caps[2]) == 2) {
        # TODO
        gsub(/\./, /\./, _caps[3]);
        gsub(/\*/, /.+/, _caps[3]);
        gsub(/\?/, /./, _caps[3]);
      }
      if (_caps[2] == "#" || _caps[2] == "##") {
        _caps[3] = "^" _caps[3];
      } else {
        _caps[3] = _caps[3] "$";
      }

      _r = d_data[_caps[1]];
      sub(_caps[3], "", _r);
    } else if (match(_name, /^#[-a-zA-Z0-9_]+$/) > 0) {             # ${#key}
      _r = length("" d_data[substr(_name, 2)]);
    } else if (match(_name, /^([-a-zA-Z0-9_]+)(\..+)$/, _caps) > 0) { # ${key.modifiers}
      _r = modify_text(d_data[_caps[1]], _caps[2]);
    } else if (match(_name, /^\.[-a-zA-Z0-9_]+./) > 0) {             # ${.function:args...}
      match(_name, /^\.[-a-zA-Z0-9_]+./);
      _s["i"] = RLENGTH;
      _s["func"] = substr(_name, 2, _s["i"] - 2);
      _s["sep"] =substr(_name, _s["i"], 1);
      _s["args"] = substr(_name, _s["i"] + 1);
      _s["argc"] = split(_s["args"], _a, _s["sep"]);
      if (_s["func"] == "for" && _s["argc"] == 5) {
        _r = inline_function_for(_a);
      } else if (_s["func"] == "sep_for" && _s["argc"] == 5) {
        _r = inline_function_sepfor(_a);
      } else if (_s["func"] == "for_sep" && _s["argc"] == 5) {
        _r = inline_function_forsep(_a);
      } else if (_s["func"] == "eval" && _s["argc"] == 1) {
        _r = inline_function_eval(_a);
      } else {
        print "(parameter function:" _s["func"] ")! unrecognized function." > "/dev/stderr";
        _r = _mtext;
      }
    } else {
      print "(parameter expansion:" _mtext ")! unrecognized expansion." > "/dev/stderr";
      _r = _mtext;
    }

    if (_mtext ~ /^\${/) {
      # enable re-expansion ${}
      _ret = _ret _ltext;
      text = _r _rtext;
    } else {
      # disable re-expansion $""
      _ret = _ret _ltext _r;
      text = _rtext;
    }
  }
  return _ret text;
}

function inline_function_forsep(args, _, _r, _sep) {
  _sep = args[5];
  _r = inline_function_for(args);
  return _r == "" ? "" : _r _sep;
}
function inline_function_sepfor(args, _, _r, _sep) {
  _sep = args[5];
  _r = inline_function_for(args);
  return _r == "" ? "" : _sep _r;
}
function inline_function_for(args, _, _rex_i, _i0, _iM, _field, _sep, _i, _r, _t) {
  # ${for:%i%:1:9:typename A%i%:,}
  _rex_i = args[1];
  _i0 = int(eval_expr(args[2]));
  _iM = int(eval_expr(args[3]));
  _field = args[4];
  _sep = args[5];

  _r = "";
  for (_i = _i0; _i < _iM; _i++) {
    _t = _field;
    gsub(_rex_i, _i, _t);
    _r = _i == _i0?_t:_r _sep _t;
  }
  return _r;
}
function inline_function_eval(args) {
  return eval_expr(args[1]);
}

#===============================================================================
#   mwg.pp text modification
#-------------------------------------------------------------------------------
function modify_text__replace0(text, before, after, flags) {
  if (index(flags, "R")) {
    return replace(text, before, after);
  } else {
    gsub(before, after, text);
    return text;
  }
}

function modify_text__replace(content, before, after, flags) {
  if (index(flags, "m")) {
    _jlen = split(content, _lines, "\n");
    content = modify_text__replace0(_lines[1], before, after, flags);
    #print_error("mwg_pp(modify_text)", "replace('" _lines[1] "','" before "','" after "') = '" content "'");
    for (_j = 1; _j < _jlen; _j++)
      content = content "\n" modify_text__replace0(_lines[_j + 1], before, after, flags);
  } else {
    content = modify_text__replace0(content, before, after, flags);
  }
  return content;
}

function modify_text(content, args, _len, _i, _m, _s, _c, _j, _jlen, _lines) {
  # _len: length of args
  # _i: index in args
  # _c: current character in args
  # _m: current context mode in args
  # _s: data store

  _m = "";
  _len = length(args);
  for (_i = 0; _i < _len; _i++) {
    _c = substr(args, _i + 1, 1);
    #-------------------------------------------------
    if (_m == "c") {
      if (_c == "r" || _c == "R") {
        _m = "r0";
        _s["flags"] = _c == "R"?_c:"";
        _s["sep"] = "";
        _s["rep_before"] = "";
        _s["rep_after"] = "";
      } else if (_c == "f") {
        _m = "f0";
        _s["sep"] = "";
        _s["for_var"] = "";
        _s["for_begin"] = "";
        _s["for_end"] = "";
      } else if (_c == "i") {
        content = inline_expand(content);
        _m = "";
      } else {
        print "unrecognized expand fun '" _c "'" > "/dev/stderr"
      }
    #-------------------------------------------------
    # r, R: replace
    } else if (_m == "r0") {
      _s["sep"] = _c;
      _m = "r1";
    } else if (_m == "r1") {
      if (_c == _s["sep"]) {
        _m = "r2";
      } else {
        _s["rep_before"] = _s["rep_before"] _c;
      }
    } else if (_m == "r2") {
      if (_c == _s["sep"]) {

        # check flag m
        _c = substr(args, _i + 2, 1);
        if (_c == "m") {
          _s["flags"] = _s["flags"] "m";
          _i++;
        }

        content = modify_text__replace(content, _s["rep_before"], _s["rep_after"], _s["flags"]);
        _m = "";
      } else {
        _s["rep_after"] = _s["rep_after"] _c;
      }
    #-------------------------------------------------
    # f: for
    } else if (_m == "f0") {
      _s["sep"] = _c;
      _m = "f1";
    } else if (_m == "f1") {
      if (_c != _s["sep"]) {
        _s["for_var"] = _s["for_var"] _c;
      } else {
        _m = "f2";
      }
    } else if (_m == "f2") {
      if (_c != _s["sep"]) {
        _s["for_begin"] = _s["for_begin"] _c;
      } else {
        _s["for_begin"] = int(eval_expr(_s["for_begin"]));
        _m = "f3";
      }
    } else if (_m == "f3") {
      if (_c != _s["sep"]) {
        _s["for_end"] = _s["for_end"] _c;
      } else {
        _s["for_end"] = int(eval_expr(_s["for_end"]));
        _m = "";

        _s["content"] = content;
        content = "";
        for (_s["i"] = _s["for_begin"]; _s["i"] < _s["for_end"]; _s["i"]++) {
          _c = _s["content"];
          gsub(_s["for_var"], _s["i"], _c);
          content = content _c;
        }
      }
    #-------------------------------------------------
    } else {
      if (_c == ".") {
        _m = "c";
      } else if (_c ~ /[/#]/) {
        break;
      } else if (_c !~ /[ \t\r\n]/) {
        print "unrecognized expand cmd '" _c  "'" > "/dev/stderr"
      }
    }
  }

  return content;
}
#===============================================================================
#   mwg.pp commands
#-------------------------------------------------------------------------------
function range_begin(cmd, arg) {
  d_level++;
  d_rstack[d_level, "c"] = cmd;
  d_rstack[d_level, "a"] = arg;
  d_content[d_level] = "";
  d_content[d_level, "L"] = "";
  d_content[d_level, "F"] = "";
}
function range_end(args, _cmd, _arg, _txt, _clines, _cfiles) {
  if (d_level == 0) {
    print "mwg_pp.awk:#%}: no matching range beginning" > "/dev/stderr"
    return;
  }

  # pop data
  _cmd = d_rstack[d_level, "c"];
  _arg = d_rstack[d_level, "a"];
  _txt = d_content[d_level];
  if (m_lineno) { # 20120726
    _clines = d_content[d_level, "L"];
    _cfiles = d_content[d_level, "F"];
  }
  d_level--;

  if (args != "")
    _txt = modify_text(_txt, args);

  # process
  if (_cmd == "define") {
    d_data[_arg] = _txt;
    if (m_lineno) { # 20120726
      d_data[_arg, "L"] = _clines;
      d_data[_arg, "F"] = _cfiles;
    }
  } else if (_cmd == "expand" || _cmd == "IF1" || _cmd == "IF4") {
    process_multiline(_txt, _clines, _cfiles); # 20120726
  } else if (_cmd == "none" || _cmd ~ /IF[023]/) {
    # do nothing
  } else {
    print "mwg_pp.awk:#%}: unknown range beginning '" _cmd " ( " _arg " )'" > "/dev/stderr"
  }
}

function dctv_define(args, _, _cap, _name, _name2) {
  if (match(args, /^([-A-Za-z0-9_:]+)[[:space:]]*(\([[:space:]]*)?$/, _cap) > 0) {
    # dctv: #%define hoge
    # dctv: #%define hoge (
    _name = _cap[1];
    if (_name == "end")
      range_end("");
    else
      range_begin("define", _name);
  } else if (match(args, /^([-_:[:alnum:]]+)[[:space:]]+([-_:[:alnum:]]+)(.*)$/, _cap) > 0) {
    # dctv: #%define a b.mods
    _name = _cap[1];
    _name2 = _cap[2];
    _args = trim(_cap[3]);
    if (_args != "")
      d_data[_name] = modify_text(d_data[_name2], _args);
    else
      d_data[_name] = d_data[_name2];

    if (m_lineno) {
      d_data[_name, "L"] = d_data[_name2, "L"];
      d_data[_name, "F"] = d_data[_name2, "F"];
    }
  } else {
    print "mwg_pp.awk:#%define: missing data name" > "/dev/stderr"
    return;
  }
}

# 状態は何種類あるか?
#     END      CONDT CONDF ELSE
# IF0 出力せず IF1   IF0   IF4  (not matched)
# IF1 出力する IF2   IF2   IF3  (matched)
# IF2 出力せず IF2   IF2   IF3  (finished)
# IF3 出力せず !IF3  !IF3  !IF3 (else unmatched) 旧 "el0"
# IF4 出力する !IF3  !IF3  !IF3 (else matched)   旧 "el1"

function dctv_if(cond, _, _cap) {
  gsub(/^[ \t]+|[ \t]*(\([ \t]*)?$/, "", cond);
  if (cond != "") {
    #print "dbg: if( "cond " ) -> " eval_expr(cond) > "/dev/stderr"
    if (cond == "end") {
      range_end("");
    } else if (eval_expr(cond)) {
      range_begin("IF1");
    } else {
      range_begin("IF0");
    }
  } else {
    print "mwg_pp.awk:#%define: missing data name" > "/dev/stderr"
    return;
  }
}
function dctv_elif(cond, _cmd) {
  if (d_level == 0) {
    print "mwg_pp.awk:#%elif: no matching if directive" > "/dev/stderr"
    return;
  }

  _cmd = d_rstack[d_level, "c"];
  if (_cmd ~ /IF[0-4]/) {
    range_end("");
    if (_cmd == "IF0") {
      if (eval_expr(cond)) {
        range_begin("IF1");
      } else {
        range_begin("IF0");
      }
    } else if (_cmd ~ /IF[12]/) {
      range_begin("IF2");
    } else {
      range_begin("IF3");
      if (_cmd ~ /IF[34]/)
        print_error("mwgpp:#%else", "if clause have already ended!");
    }
  } else {
    print_error("mwgpp:#%else", "no matching if directive");
  }
}
function dctv_else(_, _cap, _cmd) {
  if (d_level == 0) {
    print_error("mwgpp:#%else", "no matching if directive");
    return;
  }

  _cmd = d_rstack[d_level, "c"];
  if (_cmd ~ /IF[0-4]/) {
    range_end("");
    if (_cmd == "IF0") {
      range_begin("IF4");
    } else {
      range_begin("IF3");
      if (_cmd ~ /IF[34]/)
        print_error("mwgpp:#%else", "if clause have already ended!");
    }
  } else {
    print_error("mwgpp:#%else", "no matching if directive");
  }
}

function dctv_expand(args, _, _cap, _txt, _type) {
  if (match(args, /^([-a-zA-Z:0-9_]+|[\(])(.*)$/, _cap) > 0) {
    if (_cap[1] == "(") {
      _type = 1;
    } else {
      _txt = d_data[_cap[1]];
      _txt = modify_text(_txt, _cap[2]);
      process_multiline(_txt, d_data[_cap[1], "L"], d_data[_cap[1], "F"]);
    }
  } else if (match(args, /^[[:space:]]*$/) > 0) {
    _type = 1;
  } else {
    print "mwg_pp.awk:#%expand: missing data name" > "/dev/stderr"
    return;
  }

  if (_type == 1) {
    # begin expand
    range_begin("expand", _cap[2]); # _cap[2] not used
  }
}

function dctv_modify(args, _, _i, _len, _name, _content) {
  _i = match(args, /[^-a-zA-Z:0-9_]/);
  _len = _i?_i - 1:length(args);
  _name = substr(args, 1, _len);
  args = trim(substr(args, _len + 1));

  d_data[_name] = modify_text(d_data[_name], args);
}

function include_file(file, _line, _lines, _i, _n, _dir, _originalFile, _originalLine) {
  if (file ~ /^<.+>$/) {
    gsub(/^<|>$/, "", file);
    file = INCLUDE_DIRECTORY "/" file;
  } else {
    gsub(/^"|"$/, "", file);
    if (file !~ /^\//) {
      _dir = awk_getfiledir();
      if (_dir != "") file = _dir "/" file;
    }
  }

  _n = 0;
  while ((_r = getline _line < file) >0)
    _lines[_n++] = _line;
  if (_r < 0)
    print_error("could not open the include file '" file "'");
  close(file);

  dependency_add(file);

  _originalFile = m_lineno_cfile;
  _originalLine = m_lineno_cline;
  for (_i = 0; _i < _n; _i++) {
    m_lineno_cfile = file; # 20120726
    m_lineno_cline = _i + 1; # 20120726
    process_line(_lines[_i]);
  }
  m_lineno_cfile = _originalFile; # 2015-01-24
  m_lineno_cline = _originalLine; # 2015-01-24
}

function dctv_error(message, _title) {
  if (m_lineno_cfile != "" || m_lineno)
    _title = m_lineno_cfile ":" m_lineno_cline;
  else
    _title = FILENAME;

  print_error(_title, message);
}

#===============================================================================
function data_define(pair, _sep, _i, _k, _v, _capt, _rex) {
  if (pair ~ /^[^\(_a-zA-Z0-9]/) { # #%data/name/value/

    _sep = "\\" substr(pair, 1, 1);
    _rex = "^" _sep "([^" _sep "]+)" _sep "([^" _sep "]+)" _sep
    if (match(pair, _rex, _capt)) {
      _k = _capt[1];
      _v = _capt[2];
      d_data[_k] = _v;
    } else {
      printf("(#%%data directive)! ill-formed. (pair=%s, _rex=%s)\n", pair, _rex) > "/dev/stderr"
      return 0;
    }
  } else { # #%data name value
    # #%data(=) name=value
    _sep = "";
    if (match(pair, /^\([^\)]+\)/) > 0) {
      _sep = substr(pair, 2, RLENGTH - 2);
      pair = trim(substr(pair, RLENGTH + 1));
    }

    _i = _sep != ""?index(pair, _sep):match(pair, /[ \t]/);
    if (_i <= 0) {
      printf("(#%%data directive)! ill-formed. (pair=%s, _sep=%s)\n", pair, _sep) > "/dev/stderr"
      return 0;
    }

    _k = substr(pair, 1, _i - 1);
    _v = trim(substr(pair, _i + length(_sep)))
    d_data[_k] = _v;

    #_t[0]; head_token(pair, _t);
    #d_data[_t[0]] = _t[1];
  }
}
function data_print(key) {
  add_line(d_data[key]);
}
function execute(command, _line, _caps, _n, _cfile) {
  if (match(command, /^(>>?)[[:space:]]*([^[:space:]]*)/, _caps) > 0) {
    # 出力先の変更
    fflush(m_outpath);
    m_outpath = _caps[2];
    m_addline_cfile = "";
    if (_caps[1] == ">" && m_outpath != "") {
      printf("") > m_outpath
    }
  } else {
    _n = 0;
    while ((command | getline _line) > 0)
      _lines[_n++] = _line;
    close(command);

    _cfile = "$(" command ")";
    gsub(/[\\"]/, "\\\\&", _cfile);
    for (_i = 0; _i < _n; _i++) {
      m_lineno_cfile = _cfile;
      m_lineno_cline = _i + 1;
      process_line(_lines[_i]);
    }
  }
}
#===============================================================================
function add_line(line) {
  if (d_level == 0) {
    if (m_lineno) { # 20120726
      if (m_addline_cfile != m_lineno_cfile||++m_addline_cline != m_lineno_cline) {
        m_addline_cline = m_lineno_cline;
        m_addline_cfile = m_lineno_cfile;
        if (m_addline_cline != "" && m_addline_cfile != "") {
          if (m_outpath == "")
            print "#line " m_addline_cline " \"" m_addline_cfile "\""
          else
            print "#line " m_addline_cline " \"" m_addline_cfile "\"" >> m_outpath
        }
      }
    }

    if (m_outpath == "")
      print line
    else
      print line >> m_outpath
  } else {
    d_content[d_level] = d_content[d_level] line "\n"
    d_content[d_level, "L"] = d_content[d_level, "L"] m_lineno_cline "\n";
    d_content[d_level, "F"] = d_content[d_level, "F"] m_lineno_cfile "\n";
  }
}

# function process_multiline2(txt, cline, cfile, _s, _l, _f, _len, _i) {
#   _len = split(txt, _s, "\n");
#   if (length(_s[_len]) == 0) _len--;

#   split(clines, _l, "\n");
#   split(cfiles, _f, "\n");
#   for (_i = 0; _i < _len; _i++) {
#     m_lineno_cline = _l[_i + 1];
#     m_lineno_cfile = _f[_i + 1];
#     process_line(_s[_i + 1]);
#   }
# }

function process_multiline(txt, clines, cfiles, _, _s, _l, _f, _len, _i) {
  _len = split(txt, _s, "\n");
  if (length(_s[_len]) == 0) _len--;

  split(clines, _l, "\n");
  split(cfiles, _f, "\n");
  for (_i = 0; _i < _len; _i++) {
    m_lineno_cline = _l[_i + 1];
    m_lineno_cfile = _f[_i + 1];
    process_line(_s[_i + 1]);
  }
}

function process_line(line, _line, _text, _ind, _len, _directive, _cap) {
  _line = line;

  sub(/^[ \t]+/, "", _line);
  sub(/[ \t\r]+$/, "", _line);
  if (m_comment_cpp)
    sub(/^\/\//, "#", _line);
  if (m_comment_pragma)
    sub(/^[[:space:]]*#[[:space:]]*pragma/, "#", _line);
  if (m_comment_c && match(_line, /^\/\*(.+)\*\/$/, _cap) > 0)
    _line = "#" _cap[1];

  if (_line ~ /^#%[^%]/) {
    # cut directive
    if (match(_line, /^#%[ \t]*([-a-zA-Z_0-9:]+)(.*)$/, _cap) > 0) {
      _directive = _cap[1];
      _text = trim(_cap[2]);
    } else if (match(_line, /^#%[ \t]*([^-a-zA-Z_0-9:])(.*)$/, _cap) > 0) {
      _directive = _cap[1];
      _text = trim(_cap[2]);
    } else {
      print_error("unrecognized directive line: " line);
      return;
    }

    # switch directive
    if (_directive == "(" || _directive == "begin") {
      range_begin("none", _text);
    } else if (_directive == ")" || _directive == "end") {
      range_end(_text);
    } else if (_directive == "define" || _directive == "m") {
      dctv_define(_text);
    } else if (_directive == "expand" || _directive == "x") {
      dctv_expand(_text);
    } else if (_directive == "if") {
      dctv_if(_text);
    } else if (_directive == "else") {
      dctv_else(_text);
    } else if (_directive == "elif") {
      dctv_elif(_text);
    } else if (_directive == "modify") { # obsoleted. use #%define name name.mods
      print_error("obsoleted directive modify");
      dctv_modify(_text);
    } else if (_directive == "include" || _directive == "<") {
      include_file(_text);
    } else if (_directive == "data") { # obs → データ設定に有意。残す?
      data_define(_text);
    } else if (_directive == "print") { #obs
      data_print(_text);
    } else if (_directive == "eval") {
      eval_expr(_text);
    } else if (_directive == "[" && match(_text, /^(.+)\]$/, _cap) > 0) {
      eval_expr(_cap[1]);
    } else if (_directive == "exec" || _directive == "$") {
      execute(_text);
    } else if (_directive == "#") {
      # comment. just ignored.
    } else if (_directive == "error") {
      dctv_error(_text);
    } else {
      print_error("unrecognized directive " _directive);
    }
  } else if (_line ~ /^##+%/) {
    add_line(substr(_line, 2));
  } else if (_line ~ /^#%%+/) {
    add_line("#" substr(_line, 3));
  } else {
    add_line(line);
  }
}

BEGIN{
  FS = "MWG_PP" "_COMMENT";
  ev1scan_init();
  d_level = 0;
  d_data[0] = "";

  m_outpath = "";
  m_comment_c      = int(ENVIRON["PPC_C"]) != 0;
  m_comment_cpp    = int(ENVIRON["PPC_CPP"]) != 0;
  m_comment_pragma = int(ENVIRON["PPC_PRAGMA"]) != 0;

  m_lineno         = int(ENVIRON["PPLINENO"]) != 0;

  INCLUDE_DIRECTORY = ENVIRON["HOME"] "/.mwg/mwgpp/include"

  m_dependency_count = 0
  m_dependency_guard[""] = 1;
  m_dependency[0] = "";
}

{
  if (FNR == 1) {
    if (ENVIRON["PPLINENO_FILE"] != "")
      m_rfile = ENVIRON["PPLINENO_FILE"];
    else
      m_rfile = FILENAME;
    dependency_add(m_rfile);
  }
  m_lineno_cfile = m_rfile;
  m_lineno_cline = FNR;
  process_line($1);
}

function dependency_add(file) {
  if (!m_dependency_guard[file]) {
    m_dependency_guard[file] = 1;
    m_dependency[m_dependency_count++] = file;
  }
}
function dependency_generate(output, target, is_phony, _i, _iMax, _line, _file) {
  if (!target) {
    target = m_rfile;
    sub(/\.pp$/, "", target);
    target = target ".out";
  }

  if (m_dependency_count == 0)
    print target ":" > output;
  else {
    _iMax = m_dependency_count - 1;
    for (_i = 0; _i < m_dependency_count; _i++) {
      _file = m_dependency[_i];
      gsub(/[[:space:]]/, "\\\\&", _file);
      _line = _i == 0? target ": ": "  ";
      _line = _line _file;
      if (_i < _iMax) _line = _line " \\";
      print _line > output;
    }

    if (is_phony) {
      for (_i = 0; _i < m_dependency_count; _i++) {
        _file = m_dependency[_i];
        gsub(/[[:space:]]/, "\\\\&", _file);
        printf("%s:\n\n", _file) > output;
      }
    }
  }
}

END {
  # output dependencies
  DEPENDENCIES_OUTPUT = ENVIRON["DEPENDENCIES_OUTPUT"];
  if (DEPENDENCIES_OUTPUT) {
    is_phony = ENVIRON["DEPENDENCIES_PHONY"];
    dependency_generate(DEPENDENCIES_OUTPUT, ENVIRON["DEPENDENCIES_TARGET"], is_phony);
  }

  if (global_errorCount) exit(1);
}
