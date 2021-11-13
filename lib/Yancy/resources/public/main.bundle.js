/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ "./lib/Yancy/resources/src/editor.html":
/*!*********************************************!*\
  !*** ./lib/Yancy/resources/src/editor.html ***!
  \*********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
// Module
var code = "<nav>\n  <ul id=\"schema-list\">\n  </ul>\n</nav>\n<tab-view>\n</tab-view>\n";
// Exports
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (code);

/***/ }),

/***/ "./lib/Yancy/resources/src/tabview.html":
/*!**********************************************!*\
  !*** ./lib/Yancy/resources/src/tabview.html ***!
  \**********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
// Module
var code = "<style>\n#tab-pane > * {\n  display: none;\n}\n#tab-pane > .active {\n  display: block;\n}\n</style>\n<div>\n  <ul id=\"tab-bar\"></ul>\n  <div id=\"tab-pane\"></div>\n</div>\n";
// Exports
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (code);

/***/ }),

/***/ "./lib/Yancy/resources/src/editor.ts":
/*!*******************************************!*\
  !*** ./lib/Yancy/resources/src/editor.ts ***!
  \*******************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ Editor)
/* harmony export */ });
/* harmony import */ var _tabview__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./tabview */ "./lib/Yancy/resources/src/tabview.ts");
/* harmony import */ var _schemaform__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./schemaform */ "./lib/Yancy/resources/src/schemaform.ts");
/* harmony import */ var _editor_html__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./editor.html */ "./lib/Yancy/resources/src/editor.html");



class Editor extends HTMLElement {
    constructor() {
        super();
        window.customElements.define('tab-view', _tabview__WEBPACK_IMPORTED_MODULE_0__["default"]);
        window.customElements.define('schema-form', _schemaform__WEBPACK_IMPORTED_MODULE_1__["default"]);
    }
    get tabView() {
        return this.querySelector('tab-view');
    }
    get schemaList() {
        return this.querySelector('#schema-list');
    }
    connectedCallback() {
        this.innerHTML = _editor_html__WEBPACK_IMPORTED_MODULE_2__["default"].trim();
        this.schemaList.addEventListener('click', (e) => this.clickSchema(e));
        // Show welcome pane
        let hello = document.createElement('div');
        hello.appendChild(document.createTextNode('Hello, World!'));
        this.tabView.addTab("Hello", hello);
        // Add schema list
        for (let schemaName of Object.keys(this.schema).sort()) {
            let li = document.createElement('li');
            li.dataset["schema"] = schemaName;
            li.appendChild(document.createTextNode(schemaName));
            this.schemaList.appendChild(li);
        }
    }
    clickSchema(e) {
        let schemaName = e.target.dataset["schema"];
        // Find the schema's tab or open one
        if (this.tabView.showTab(schemaName)) {
            return;
        }
        let editForm = document.createElement('schema-form');
        editForm.schema = this.schema[schemaName];
        this.tabView.addTab(schemaName, editForm);
    }
}


/***/ }),

/***/ "./lib/Yancy/resources/src/schemaform.ts":
/*!***********************************************!*\
  !*** ./lib/Yancy/resources/src/schemaform.ts ***!
  \***********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ SchemaForm)
/* harmony export */ });
/* harmony import */ var marked__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! marked */ "./node_modules/marked/lib/marked.esm.js");
/* harmony import */ var _schemainput_textinput__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./schemainput/textinput */ "./lib/Yancy/resources/src/schemainput/textinput.ts");

class SchemaForm extends HTMLElement {
    constructor() {
        super();
        // This document fragment allows us to build the form before
        // anything is added to the page DOM
        this._root = document.createDocumentFragment();
    }
    static addInputType(ft) {
        const tagName = ft.register();
        SchemaForm._inputOrder.unshift(tagName);
        SchemaForm._inputTypes[tagName] = ft;
    }
    set schema(newSchema) {
        if (this._schema) {
            // Remove existing inputs
        }
        if (newSchema.properties) {
            for (const propName in newSchema.properties) {
                const prop = newSchema.properties[propName];
                const inputTag = SchemaForm._inputOrder.find(tagName => SchemaForm._inputTypes[tagName].handles(prop));
                if (!inputTag) {
                    throw new Error(`Could not find input to handle prop: ${JSON.stringify(prop)}`);
                }
                const input = document.createElement(inputTag);
                input.schema = prop;
                input.setAttribute('aria-labelledby', `input-${propName}-label`);
                input.setAttribute('aria-describedby', `input-${propName}-desc`);
                input.setAttribute('id', `input-${propName}`);
                const field = document.createElement('div');
                field.setAttribute("name", propName);
                // <label>
                const label = document.createElement('label');
                label.setAttribute('id', `input-${propName}-label`);
                label.setAttribute('for', `input-${propName}`);
                label.appendChild(document.createTextNode(prop.title || propName));
                // Since the `for` attribute doesn't point to an input element,
                // the default focus behavior doesn't work. Instead, we have to
                // do it ourselves...
                label.addEventListener('click', event => {
                    const firstFocusableElement = input.querySelector('input,textarea,select,[tabindex]');
                    firstFocusableElement.focus();
                    event.preventDefault();
                });
                // <small> for description
                const desc = document.createElement('small');
                desc.setAttribute('id', `input-${propName}-desc`);
                desc.innerHTML = marked__WEBPACK_IMPORTED_MODULE_0__.marked.parse(prop.description || '');
                // XXX: <div> for validation error
                // XXX: HTML should be fetched from the app at runtime so that
                // it can be overridden by the user.
                field.appendChild(label);
                field.appendChild(input);
                field.appendChild(desc);
                this._root.appendChild(field);
            }
        }
        // XXX: Handle array types
        this._schema = newSchema;
    }
    set value(newValue) {
        for (let propName in newValue) {
            let input = this.querySelector(`[name=${propName}]`);
            input.value = newValue[propName];
        }
    }
    get value() {
        let val = {};
        for (const el of this._root.children) {
            const input = el;
            val[input.name] = input.value;
        }
        return val;
    }
    connectedCallback() {
        this.appendChild(this._root);
    }
}
SchemaForm._inputTypes = {};
SchemaForm._inputOrder = [];

SchemaForm.addInputType(_schemainput_textinput__WEBPACK_IMPORTED_MODULE_1__["default"]);


/***/ }),

/***/ "./lib/Yancy/resources/src/schemainput.ts":
/*!************************************************!*\
  !*** ./lib/Yancy/resources/src/schemainput.ts ***!
  \************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "SchemaInput": () => (/* binding */ SchemaInput)
/* harmony export */ });
class SchemaInput extends HTMLElement {
    static handles(input) {
        return false;
    }
}


/***/ }),

/***/ "./lib/Yancy/resources/src/schemainput/textinput.ts":
/*!**********************************************************!*\
  !*** ./lib/Yancy/resources/src/schemainput/textinput.ts ***!
  \**********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ TextInput)
/* harmony export */ });
/* harmony import */ var _schemainput__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../schemainput */ "./lib/Yancy/resources/src/schemainput.ts");

class TextInput extends _schemainput__WEBPACK_IMPORTED_MODULE_0__.SchemaInput {
    constructor() {
        super();
        this.input = document.createElement('input');
    }
    get value() {
        return this.input.value;
    }
    set value(newValue) {
        this.input.value = newValue;
    }
    set schema(newSchema) {
        console.log("Setting schema for textinput", newSchema);
        let inputType = 'text';
        let inputMode = 'text';
        let pattern = newSchema.pattern;
        if (newSchema.type === 'string') {
            if (newSchema.format === 'email') {
                inputType = 'email';
                inputMode = 'email';
            }
            else if (newSchema.format === 'url') {
                inputType = 'url';
                inputMode = 'url';
            }
            else if (newSchema.format === 'tel') {
                inputType = 'tel';
                inputMode = 'tel';
            }
        }
        else if (newSchema.type === 'integer' || newSchema.type === 'number') {
            inputType = 'number';
            inputMode = 'decimal';
            if (newSchema.type === 'integer') {
                // Use pattern to show numeric input on iOS
                // https://css-tricks.com/finger-friendly-numerical-inputs-with-inputmode/
                pattern = pattern || '[0-9]*';
                inputMode = 'numeric';
            }
        }
        this.input.setAttribute('type', inputType);
        this.input.setAttribute('inputmode', inputMode);
        if (pattern) {
            this.input.setAttribute('pattern', pattern);
        }
        if (newSchema.minLength) {
            this.input.setAttribute('minlength', newSchema.minLength.toString());
        }
        if (newSchema.maxLength) {
            this.input.setAttribute('maxlength', newSchema.maxLength.toString());
        }
        if (newSchema.minimum) {
            this.input.setAttribute('min', newSchema.minimum.toString());
        }
        if (newSchema.maximum) {
            this.input.setAttribute('max', newSchema.maximum.toString());
        }
    }
    connectedCallback() {
        this.appendChild(this.input);
    }
    static handles(input) {
        return true;
    }
    static register() {
        const tagName = 'schema-text-input';
        window.customElements.define(tagName, TextInput);
        return tagName;
    }
}


/***/ }),

/***/ "./lib/Yancy/resources/src/tabview.ts":
/*!********************************************!*\
  !*** ./lib/Yancy/resources/src/tabview.ts ***!
  \********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ TabView)
/* harmony export */ });
/* harmony import */ var _tabview_html__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./tabview.html */ "./lib/Yancy/resources/src/tabview.html");

class TabView extends HTMLElement {
    get tabBar() {
        return this.querySelector('#tab-bar');
    }
    get tabPanes() {
        return this.querySelector('#tab-pane');
    }
    get tabs() {
        return Array.from(this.tabBar.children);
    }
    connectedCallback() {
        this.innerHTML = _tabview_html__WEBPACK_IMPORTED_MODULE_0__["default"].trim();
        this.tabBar.addEventListener('click', (e) => this.clickTab(e));
    }
    addTab(label, content) {
        const li = document.createElement('li');
        li.appendChild(document.createTextNode(label));
        this.tabBar.appendChild(li);
        this.tabPanes.appendChild(content);
        this.showTab(label);
    }
    showTab(label) {
        let idx = this.tabs.findIndex(el => el.innerText == label);
        if (idx < 0) {
            console.log(`Could not find tab with label ${label}`);
            return false;
        }
        if (this.tabBar.querySelector('.active')) {
            this.tabBar.querySelector('.active').classList.remove('active');
            this.tabPanes.querySelector('.active').classList.remove('active');
        }
        this.tabBar.children[idx].classList.add('active');
        this.tabPanes.children[idx].classList.add('active');
        return true;
    }
    clickTab(e) {
    }
}


/***/ }),

/***/ "./node_modules/marked/lib/marked.esm.js":
/*!***********************************************!*\
  !*** ./node_modules/marked/lib/marked.esm.js ***!
  \***********************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Lexer": () => (/* binding */ Lexer),
/* harmony export */   "Parser": () => (/* binding */ Parser),
/* harmony export */   "Renderer": () => (/* binding */ Renderer),
/* harmony export */   "Slugger": () => (/* binding */ Slugger),
/* harmony export */   "TextRenderer": () => (/* binding */ TextRenderer),
/* harmony export */   "Tokenizer": () => (/* binding */ Tokenizer),
/* harmony export */   "defaults": () => (/* binding */ defaults),
/* harmony export */   "getDefaults": () => (/* binding */ getDefaults),
/* harmony export */   "lexer": () => (/* binding */ lexer),
/* harmony export */   "marked": () => (/* binding */ marked),
/* harmony export */   "options": () => (/* binding */ options),
/* harmony export */   "parse": () => (/* binding */ parse),
/* harmony export */   "parseInline": () => (/* binding */ parseInline),
/* harmony export */   "parser": () => (/* binding */ parser),
/* harmony export */   "setOptions": () => (/* binding */ setOptions),
/* harmony export */   "use": () => (/* binding */ use),
/* harmony export */   "walkTokens": () => (/* binding */ walkTokens)
/* harmony export */ });
/**
 * marked - a markdown parser
 * Copyright (c) 2011-2021, Christopher Jeffrey. (MIT Licensed)
 * https://github.com/markedjs/marked
 */

/**
 * DO NOT EDIT THIS FILE
 * The code in this file is generated from files in ./src/
 */

function getDefaults() {
  return {
    baseUrl: null,
    breaks: false,
    extensions: null,
    gfm: true,
    headerIds: true,
    headerPrefix: '',
    highlight: null,
    langPrefix: 'language-',
    mangle: true,
    pedantic: false,
    renderer: null,
    sanitize: false,
    sanitizer: null,
    silent: false,
    smartLists: false,
    smartypants: false,
    tokenizer: null,
    walkTokens: null,
    xhtml: false
  };
}

let defaults = getDefaults();

function changeDefaults(newDefaults) {
  defaults = newDefaults;
}

/**
 * Helpers
 */
const escapeTest = /[&<>"']/;
const escapeReplace = /[&<>"']/g;
const escapeTestNoEncode = /[<>"']|&(?!#?\w+;)/;
const escapeReplaceNoEncode = /[<>"']|&(?!#?\w+;)/g;
const escapeReplacements = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;'
};
const getEscapeReplacement = (ch) => escapeReplacements[ch];
function escape(html, encode) {
  if (encode) {
    if (escapeTest.test(html)) {
      return html.replace(escapeReplace, getEscapeReplacement);
    }
  } else {
    if (escapeTestNoEncode.test(html)) {
      return html.replace(escapeReplaceNoEncode, getEscapeReplacement);
    }
  }

  return html;
}

const unescapeTest = /&(#(?:\d+)|(?:#x[0-9A-Fa-f]+)|(?:\w+));?/ig;

function unescape(html) {
  // explicitly match decimal, hex, and named HTML entities
  return html.replace(unescapeTest, (_, n) => {
    n = n.toLowerCase();
    if (n === 'colon') return ':';
    if (n.charAt(0) === '#') {
      return n.charAt(1) === 'x'
        ? String.fromCharCode(parseInt(n.substring(2), 16))
        : String.fromCharCode(+n.substring(1));
    }
    return '';
  });
}

const caret = /(^|[^\[])\^/g;
function edit(regex, opt) {
  regex = regex.source || regex;
  opt = opt || '';
  const obj = {
    replace: (name, val) => {
      val = val.source || val;
      val = val.replace(caret, '$1');
      regex = regex.replace(name, val);
      return obj;
    },
    getRegex: () => {
      return new RegExp(regex, opt);
    }
  };
  return obj;
}

const nonWordAndColonTest = /[^\w:]/g;
const originIndependentUrl = /^$|^[a-z][a-z0-9+.-]*:|^[?#]/i;
function cleanUrl(sanitize, base, href) {
  if (sanitize) {
    let prot;
    try {
      prot = decodeURIComponent(unescape(href))
        .replace(nonWordAndColonTest, '')
        .toLowerCase();
    } catch (e) {
      return null;
    }
    if (prot.indexOf('javascript:') === 0 || prot.indexOf('vbscript:') === 0 || prot.indexOf('data:') === 0) {
      return null;
    }
  }
  if (base && !originIndependentUrl.test(href)) {
    href = resolveUrl(base, href);
  }
  try {
    href = encodeURI(href).replace(/%25/g, '%');
  } catch (e) {
    return null;
  }
  return href;
}

const baseUrls = {};
const justDomain = /^[^:]+:\/*[^/]*$/;
const protocol = /^([^:]+:)[\s\S]*$/;
const domain = /^([^:]+:\/*[^/]*)[\s\S]*$/;

function resolveUrl(base, href) {
  if (!baseUrls[' ' + base]) {
    // we can ignore everything in base after the last slash of its path component,
    // but we might need to add _that_
    // https://tools.ietf.org/html/rfc3986#section-3
    if (justDomain.test(base)) {
      baseUrls[' ' + base] = base + '/';
    } else {
      baseUrls[' ' + base] = rtrim(base, '/', true);
    }
  }
  base = baseUrls[' ' + base];
  const relativeBase = base.indexOf(':') === -1;

  if (href.substring(0, 2) === '//') {
    if (relativeBase) {
      return href;
    }
    return base.replace(protocol, '$1') + href;
  } else if (href.charAt(0) === '/') {
    if (relativeBase) {
      return href;
    }
    return base.replace(domain, '$1') + href;
  } else {
    return base + href;
  }
}

const noopTest = { exec: function noopTest() {} };

function merge(obj) {
  let i = 1,
    target,
    key;

  for (; i < arguments.length; i++) {
    target = arguments[i];
    for (key in target) {
      if (Object.prototype.hasOwnProperty.call(target, key)) {
        obj[key] = target[key];
      }
    }
  }

  return obj;
}

function splitCells(tableRow, count) {
  // ensure that every cell-delimiting pipe has a space
  // before it to distinguish it from an escaped pipe
  const row = tableRow.replace(/\|/g, (match, offset, str) => {
      let escaped = false,
        curr = offset;
      while (--curr >= 0 && str[curr] === '\\') escaped = !escaped;
      if (escaped) {
        // odd number of slashes means | is escaped
        // so we leave it alone
        return '|';
      } else {
        // add space before unescaped |
        return ' |';
      }
    }),
    cells = row.split(/ \|/);
  let i = 0;

  // First/last cell in a row cannot be empty if it has no leading/trailing pipe
  if (!cells[0].trim()) { cells.shift(); }
  if (!cells[cells.length - 1].trim()) { cells.pop(); }

  if (cells.length > count) {
    cells.splice(count);
  } else {
    while (cells.length < count) cells.push('');
  }

  for (; i < cells.length; i++) {
    // leading or trailing whitespace is ignored per the gfm spec
    cells[i] = cells[i].trim().replace(/\\\|/g, '|');
  }
  return cells;
}

// Remove trailing 'c's. Equivalent to str.replace(/c*$/, '').
// /c*$/ is vulnerable to REDOS.
// invert: Remove suffix of non-c chars instead. Default falsey.
function rtrim(str, c, invert) {
  const l = str.length;
  if (l === 0) {
    return '';
  }

  // Length of suffix matching the invert condition.
  let suffLen = 0;

  // Step left until we fail to match the invert condition.
  while (suffLen < l) {
    const currChar = str.charAt(l - suffLen - 1);
    if (currChar === c && !invert) {
      suffLen++;
    } else if (currChar !== c && invert) {
      suffLen++;
    } else {
      break;
    }
  }

  return str.substr(0, l - suffLen);
}

function findClosingBracket(str, b) {
  if (str.indexOf(b[1]) === -1) {
    return -1;
  }
  const l = str.length;
  let level = 0,
    i = 0;
  for (; i < l; i++) {
    if (str[i] === '\\') {
      i++;
    } else if (str[i] === b[0]) {
      level++;
    } else if (str[i] === b[1]) {
      level--;
      if (level < 0) {
        return i;
      }
    }
  }
  return -1;
}

function checkSanitizeDeprecation(opt) {
  if (opt && opt.sanitize && !opt.silent) {
    console.warn('marked(): sanitize and sanitizer parameters are deprecated since version 0.7.0, should not be used and will be removed in the future. Read more here: https://marked.js.org/#/USING_ADVANCED.md#options');
  }
}

// copied from https://stackoverflow.com/a/5450113/806777
function repeatString(pattern, count) {
  if (count < 1) {
    return '';
  }
  let result = '';
  while (count > 1) {
    if (count & 1) {
      result += pattern;
    }
    count >>= 1;
    pattern += pattern;
  }
  return result + pattern;
}

function outputLink(cap, link, raw, lexer) {
  const href = link.href;
  const title = link.title ? escape(link.title) : null;
  const text = cap[1].replace(/\\([\[\]])/g, '$1');

  if (cap[0].charAt(0) !== '!') {
    lexer.state.inLink = true;
    const token = {
      type: 'link',
      raw,
      href,
      title,
      text,
      tokens: lexer.inlineTokens(text, [])
    };
    lexer.state.inLink = false;
    return token;
  } else {
    return {
      type: 'image',
      raw,
      href,
      title,
      text: escape(text)
    };
  }
}

function indentCodeCompensation(raw, text) {
  const matchIndentToCode = raw.match(/^(\s+)(?:```)/);

  if (matchIndentToCode === null) {
    return text;
  }

  const indentToCode = matchIndentToCode[1];

  return text
    .split('\n')
    .map(node => {
      const matchIndentInNode = node.match(/^\s+/);
      if (matchIndentInNode === null) {
        return node;
      }

      const [indentInNode] = matchIndentInNode;

      if (indentInNode.length >= indentToCode.length) {
        return node.slice(indentToCode.length);
      }

      return node;
    })
    .join('\n');
}

/**
 * Tokenizer
 */
class Tokenizer {
  constructor(options) {
    this.options = options || defaults;
  }

  space(src) {
    const cap = this.rules.block.newline.exec(src);
    if (cap) {
      if (cap[0].length > 1) {
        return {
          type: 'space',
          raw: cap[0]
        };
      }
      return { raw: '\n' };
    }
  }

  code(src) {
    const cap = this.rules.block.code.exec(src);
    if (cap) {
      const text = cap[0].replace(/^ {1,4}/gm, '');
      return {
        type: 'code',
        raw: cap[0],
        codeBlockStyle: 'indented',
        text: !this.options.pedantic
          ? rtrim(text, '\n')
          : text
      };
    }
  }

  fences(src) {
    const cap = this.rules.block.fences.exec(src);
    if (cap) {
      const raw = cap[0];
      const text = indentCodeCompensation(raw, cap[3] || '');

      return {
        type: 'code',
        raw,
        lang: cap[2] ? cap[2].trim() : cap[2],
        text
      };
    }
  }

  heading(src) {
    const cap = this.rules.block.heading.exec(src);
    if (cap) {
      let text = cap[2].trim();

      // remove trailing #s
      if (/#$/.test(text)) {
        const trimmed = rtrim(text, '#');
        if (this.options.pedantic) {
          text = trimmed.trim();
        } else if (!trimmed || / $/.test(trimmed)) {
          // CommonMark requires space before trailing #s
          text = trimmed.trim();
        }
      }

      const token = {
        type: 'heading',
        raw: cap[0],
        depth: cap[1].length,
        text: text,
        tokens: []
      };
      this.lexer.inline(token.text, token.tokens);
      return token;
    }
  }

  hr(src) {
    const cap = this.rules.block.hr.exec(src);
    if (cap) {
      return {
        type: 'hr',
        raw: cap[0]
      };
    }
  }

  blockquote(src) {
    const cap = this.rules.block.blockquote.exec(src);
    if (cap) {
      const text = cap[0].replace(/^ *> ?/gm, '');

      return {
        type: 'blockquote',
        raw: cap[0],
        tokens: this.lexer.blockTokens(text, []),
        text
      };
    }
  }

  list(src) {
    let cap = this.rules.block.list.exec(src);
    if (cap) {
      let raw, istask, ischecked, indent, i, blankLine, endsWithBlankLine,
        line, lines, itemContents;

      let bull = cap[1].trim();
      const isordered = bull.length > 1;

      const list = {
        type: 'list',
        raw: '',
        ordered: isordered,
        start: isordered ? +bull.slice(0, -1) : '',
        loose: false,
        items: []
      };

      bull = isordered ? `\\d{1,9}\\${bull.slice(-1)}` : `\\${bull}`;

      if (this.options.pedantic) {
        bull = isordered ? bull : '[*+-]';
      }

      // Get next list item
      const itemRegex = new RegExp(`^( {0,3}${bull})((?: [^\\n]*| *)(?:\\n[^\\n]*)*(?:\\n|$))`);

      // Get each top-level item
      while (src) {
        if (this.rules.block.hr.test(src)) { // End list if we encounter an HR (possibly move into itemRegex?)
          break;
        }

        if (!(cap = itemRegex.exec(src))) {
          break;
        }

        lines = cap[2].split('\n');

        if (this.options.pedantic) {
          indent = 2;
          itemContents = lines[0].trimLeft();
        } else {
          indent = cap[2].search(/[^ ]/); // Find first non-space char
          indent = cap[1].length + (indent > 4 ? 1 : indent); // intented code blocks after 4 spaces; indent is always 1
          itemContents = lines[0].slice(indent - cap[1].length);
        }

        blankLine = false;
        raw = cap[0];

        if (!lines[0] && /^ *$/.test(lines[1])) { // items begin with at most one blank line
          raw = cap[1] + lines.slice(0, 2).join('\n') + '\n';
          list.loose = true;
          lines = [];
        }

        const nextBulletRegex = new RegExp(`^ {0,${Math.min(3, indent - 1)}}(?:[*+-]|\\d{1,9}[.)])`);

        for (i = 1; i < lines.length; i++) {
          line = lines[i];

          if (this.options.pedantic) { // Re-align to follow commonmark nesting rules
            line = line.replace(/^ {1,4}(?=( {4})*[^ ])/g, '  ');
          }

          // End list item if found start of new bullet
          if (nextBulletRegex.test(line)) {
            raw = cap[1] + lines.slice(0, i).join('\n') + '\n';
            break;
          }

          // Until we encounter a blank line, item contents do not need indentation
          if (!blankLine) {
            if (!line.trim()) { // Check if current line is empty
              blankLine = true;
            }

            // Dedent if possible
            if (line.search(/[^ ]/) >= indent) {
              itemContents += '\n' + line.slice(indent);
            } else {
              itemContents += '\n' + line;
            }
            continue;
          }

          // Dedent this line
          if (line.search(/[^ ]/) >= indent || !line.trim()) {
            itemContents += '\n' + line.slice(indent);
            continue;
          } else { // Line was not properly indented; end of this item
            raw = cap[1] + lines.slice(0, i).join('\n') + '\n';
            break;
          }
        }

        if (!list.loose) {
          // If the previous item ended with a blank line, the list is loose
          if (endsWithBlankLine) {
            list.loose = true;
          } else if (/\n *\n *$/.test(raw)) {
            endsWithBlankLine = true;
          }
        }

        // Check for task list items
        if (this.options.gfm) {
          istask = /^\[[ xX]\] /.exec(itemContents);
          if (istask) {
            ischecked = istask[0] !== '[ ] ';
            itemContents = itemContents.replace(/^\[[ xX]\] +/, '');
          }
        }

        list.items.push({
          type: 'list_item',
          raw: raw,
          task: !!istask,
          checked: ischecked,
          loose: false,
          text: itemContents
        });

        list.raw += raw;
        src = src.slice(raw.length);
      }

      // Do not consume newlines at end of final item. Alternatively, make itemRegex *start* with any newlines to simplify/speed up endsWithBlankLine logic
      list.items[list.items.length - 1].raw = raw.trimRight();
      list.items[list.items.length - 1].text = itemContents.trimRight();
      list.raw = list.raw.trimRight();

      const l = list.items.length;

      // Item child tokens handled here at end because we needed to have the final item to trim it first
      for (i = 0; i < l; i++) {
        this.lexer.state.top = false;
        list.items[i].tokens = this.lexer.blockTokens(list.items[i].text, []);
        if (list.items[i].tokens.some(t => t.type === 'space')) {
          list.loose = true;
          list.items[i].loose = true;
        }
      }

      return list;
    }
  }

  html(src) {
    const cap = this.rules.block.html.exec(src);
    if (cap) {
      const token = {
        type: 'html',
        raw: cap[0],
        pre: !this.options.sanitizer
          && (cap[1] === 'pre' || cap[1] === 'script' || cap[1] === 'style'),
        text: cap[0]
      };
      if (this.options.sanitize) {
        token.type = 'paragraph';
        token.text = this.options.sanitizer ? this.options.sanitizer(cap[0]) : escape(cap[0]);
        token.tokens = [];
        this.lexer.inline(token.text, token.tokens);
      }
      return token;
    }
  }

  def(src) {
    const cap = this.rules.block.def.exec(src);
    if (cap) {
      if (cap[3]) cap[3] = cap[3].substring(1, cap[3].length - 1);
      const tag = cap[1].toLowerCase().replace(/\s+/g, ' ');
      return {
        type: 'def',
        tag,
        raw: cap[0],
        href: cap[2],
        title: cap[3]
      };
    }
  }

  table(src) {
    const cap = this.rules.block.table.exec(src);
    if (cap) {
      const item = {
        type: 'table',
        header: splitCells(cap[1]).map(c => { return { text: c }; }),
        align: cap[2].replace(/^ *|\| *$/g, '').split(/ *\| */),
        rows: cap[3] ? cap[3].replace(/\n$/, '').split('\n') : []
      };

      if (item.header.length === item.align.length) {
        item.raw = cap[0];

        let l = item.align.length;
        let i, j, k, row;
        for (i = 0; i < l; i++) {
          if (/^ *-+: *$/.test(item.align[i])) {
            item.align[i] = 'right';
          } else if (/^ *:-+: *$/.test(item.align[i])) {
            item.align[i] = 'center';
          } else if (/^ *:-+ *$/.test(item.align[i])) {
            item.align[i] = 'left';
          } else {
            item.align[i] = null;
          }
        }

        l = item.rows.length;
        for (i = 0; i < l; i++) {
          item.rows[i] = splitCells(item.rows[i], item.header.length).map(c => { return { text: c }; });
        }

        // parse child tokens inside headers and cells

        // header child tokens
        l = item.header.length;
        for (j = 0; j < l; j++) {
          item.header[j].tokens = [];
          this.lexer.inlineTokens(item.header[j].text, item.header[j].tokens);
        }

        // cell child tokens
        l = item.rows.length;
        for (j = 0; j < l; j++) {
          row = item.rows[j];
          for (k = 0; k < row.length; k++) {
            row[k].tokens = [];
            this.lexer.inlineTokens(row[k].text, row[k].tokens);
          }
        }

        return item;
      }
    }
  }

  lheading(src) {
    const cap = this.rules.block.lheading.exec(src);
    if (cap) {
      const token = {
        type: 'heading',
        raw: cap[0],
        depth: cap[2].charAt(0) === '=' ? 1 : 2,
        text: cap[1],
        tokens: []
      };
      this.lexer.inline(token.text, token.tokens);
      return token;
    }
  }

  paragraph(src) {
    const cap = this.rules.block.paragraph.exec(src);
    if (cap) {
      const token = {
        type: 'paragraph',
        raw: cap[0],
        text: cap[1].charAt(cap[1].length - 1) === '\n'
          ? cap[1].slice(0, -1)
          : cap[1],
        tokens: []
      };
      this.lexer.inline(token.text, token.tokens);
      return token;
    }
  }

  text(src) {
    const cap = this.rules.block.text.exec(src);
    if (cap) {
      const token = {
        type: 'text',
        raw: cap[0],
        text: cap[0],
        tokens: []
      };
      this.lexer.inline(token.text, token.tokens);
      return token;
    }
  }

  escape(src) {
    const cap = this.rules.inline.escape.exec(src);
    if (cap) {
      return {
        type: 'escape',
        raw: cap[0],
        text: escape(cap[1])
      };
    }
  }

  tag(src) {
    const cap = this.rules.inline.tag.exec(src);
    if (cap) {
      if (!this.lexer.state.inLink && /^<a /i.test(cap[0])) {
        this.lexer.state.inLink = true;
      } else if (this.lexer.state.inLink && /^<\/a>/i.test(cap[0])) {
        this.lexer.state.inLink = false;
      }
      if (!this.lexer.state.inRawBlock && /^<(pre|code|kbd|script)(\s|>)/i.test(cap[0])) {
        this.lexer.state.inRawBlock = true;
      } else if (this.lexer.state.inRawBlock && /^<\/(pre|code|kbd|script)(\s|>)/i.test(cap[0])) {
        this.lexer.state.inRawBlock = false;
      }

      return {
        type: this.options.sanitize
          ? 'text'
          : 'html',
        raw: cap[0],
        inLink: this.lexer.state.inLink,
        inRawBlock: this.lexer.state.inRawBlock,
        text: this.options.sanitize
          ? (this.options.sanitizer
            ? this.options.sanitizer(cap[0])
            : escape(cap[0]))
          : cap[0]
      };
    }
  }

  link(src) {
    const cap = this.rules.inline.link.exec(src);
    if (cap) {
      const trimmedUrl = cap[2].trim();
      if (!this.options.pedantic && /^</.test(trimmedUrl)) {
        // commonmark requires matching angle brackets
        if (!(/>$/.test(trimmedUrl))) {
          return;
        }

        // ending angle bracket cannot be escaped
        const rtrimSlash = rtrim(trimmedUrl.slice(0, -1), '\\');
        if ((trimmedUrl.length - rtrimSlash.length) % 2 === 0) {
          return;
        }
      } else {
        // find closing parenthesis
        const lastParenIndex = findClosingBracket(cap[2], '()');
        if (lastParenIndex > -1) {
          const start = cap[0].indexOf('!') === 0 ? 5 : 4;
          const linkLen = start + cap[1].length + lastParenIndex;
          cap[2] = cap[2].substring(0, lastParenIndex);
          cap[0] = cap[0].substring(0, linkLen).trim();
          cap[3] = '';
        }
      }
      let href = cap[2];
      let title = '';
      if (this.options.pedantic) {
        // split pedantic href and title
        const link = /^([^'"]*[^\s])\s+(['"])(.*)\2/.exec(href);

        if (link) {
          href = link[1];
          title = link[3];
        }
      } else {
        title = cap[3] ? cap[3].slice(1, -1) : '';
      }

      href = href.trim();
      if (/^</.test(href)) {
        if (this.options.pedantic && !(/>$/.test(trimmedUrl))) {
          // pedantic allows starting angle bracket without ending angle bracket
          href = href.slice(1);
        } else {
          href = href.slice(1, -1);
        }
      }
      return outputLink(cap, {
        href: href ? href.replace(this.rules.inline._escapes, '$1') : href,
        title: title ? title.replace(this.rules.inline._escapes, '$1') : title
      }, cap[0], this.lexer);
    }
  }

  reflink(src, links) {
    let cap;
    if ((cap = this.rules.inline.reflink.exec(src))
        || (cap = this.rules.inline.nolink.exec(src))) {
      let link = (cap[2] || cap[1]).replace(/\s+/g, ' ');
      link = links[link.toLowerCase()];
      if (!link || !link.href) {
        const text = cap[0].charAt(0);
        return {
          type: 'text',
          raw: text,
          text
        };
      }
      return outputLink(cap, link, cap[0], this.lexer);
    }
  }

  emStrong(src, maskedSrc, prevChar = '') {
    let match = this.rules.inline.emStrong.lDelim.exec(src);
    if (!match) return;

    // _ can't be between two alphanumerics. \p{L}\p{N} includes non-english alphabet/numbers as well
    if (match[3] && prevChar.match(/[\p{L}\p{N}]/u)) return;

    const nextChar = match[1] || match[2] || '';

    if (!nextChar || (nextChar && (prevChar === '' || this.rules.inline.punctuation.exec(prevChar)))) {
      const lLength = match[0].length - 1;
      let rDelim, rLength, delimTotal = lLength, midDelimTotal = 0;

      const endReg = match[0][0] === '*' ? this.rules.inline.emStrong.rDelimAst : this.rules.inline.emStrong.rDelimUnd;
      endReg.lastIndex = 0;

      // Clip maskedSrc to same section of string as src (move to lexer?)
      maskedSrc = maskedSrc.slice(-1 * src.length + lLength);

      while ((match = endReg.exec(maskedSrc)) != null) {
        rDelim = match[1] || match[2] || match[3] || match[4] || match[5] || match[6];

        if (!rDelim) continue; // skip single * in __abc*abc__

        rLength = rDelim.length;

        if (match[3] || match[4]) { // found another Left Delim
          delimTotal += rLength;
          continue;
        } else if (match[5] || match[6]) { // either Left or Right Delim
          if (lLength % 3 && !((lLength + rLength) % 3)) {
            midDelimTotal += rLength;
            continue; // CommonMark Emphasis Rules 9-10
          }
        }

        delimTotal -= rLength;

        if (delimTotal > 0) continue; // Haven't found enough closing delimiters

        // Remove extra characters. *a*** -> *a*
        rLength = Math.min(rLength, rLength + delimTotal + midDelimTotal);

        // Create `em` if smallest delimiter has odd char count. *a***
        if (Math.min(lLength, rLength) % 2) {
          const text = src.slice(1, lLength + match.index + rLength);
          return {
            type: 'em',
            raw: src.slice(0, lLength + match.index + rLength + 1),
            text,
            tokens: this.lexer.inlineTokens(text, [])
          };
        }

        // Create 'strong' if smallest delimiter has even char count. **a***
        const text = src.slice(2, lLength + match.index + rLength - 1);
        return {
          type: 'strong',
          raw: src.slice(0, lLength + match.index + rLength + 1),
          text,
          tokens: this.lexer.inlineTokens(text, [])
        };
      }
    }
  }

  codespan(src) {
    const cap = this.rules.inline.code.exec(src);
    if (cap) {
      let text = cap[2].replace(/\n/g, ' ');
      const hasNonSpaceChars = /[^ ]/.test(text);
      const hasSpaceCharsOnBothEnds = /^ /.test(text) && / $/.test(text);
      if (hasNonSpaceChars && hasSpaceCharsOnBothEnds) {
        text = text.substring(1, text.length - 1);
      }
      text = escape(text, true);
      return {
        type: 'codespan',
        raw: cap[0],
        text
      };
    }
  }

  br(src) {
    const cap = this.rules.inline.br.exec(src);
    if (cap) {
      return {
        type: 'br',
        raw: cap[0]
      };
    }
  }

  del(src) {
    const cap = this.rules.inline.del.exec(src);
    if (cap) {
      return {
        type: 'del',
        raw: cap[0],
        text: cap[2],
        tokens: this.lexer.inlineTokens(cap[2], [])
      };
    }
  }

  autolink(src, mangle) {
    const cap = this.rules.inline.autolink.exec(src);
    if (cap) {
      let text, href;
      if (cap[2] === '@') {
        text = escape(this.options.mangle ? mangle(cap[1]) : cap[1]);
        href = 'mailto:' + text;
      } else {
        text = escape(cap[1]);
        href = text;
      }

      return {
        type: 'link',
        raw: cap[0],
        text,
        href,
        tokens: [
          {
            type: 'text',
            raw: text,
            text
          }
        ]
      };
    }
  }

  url(src, mangle) {
    let cap;
    if (cap = this.rules.inline.url.exec(src)) {
      let text, href;
      if (cap[2] === '@') {
        text = escape(this.options.mangle ? mangle(cap[0]) : cap[0]);
        href = 'mailto:' + text;
      } else {
        // do extended autolink path validation
        let prevCapZero;
        do {
          prevCapZero = cap[0];
          cap[0] = this.rules.inline._backpedal.exec(cap[0])[0];
        } while (prevCapZero !== cap[0]);
        text = escape(cap[0]);
        if (cap[1] === 'www.') {
          href = 'http://' + text;
        } else {
          href = text;
        }
      }
      return {
        type: 'link',
        raw: cap[0],
        text,
        href,
        tokens: [
          {
            type: 'text',
            raw: text,
            text
          }
        ]
      };
    }
  }

  inlineText(src, smartypants) {
    const cap = this.rules.inline.text.exec(src);
    if (cap) {
      let text;
      if (this.lexer.state.inRawBlock) {
        text = this.options.sanitize ? (this.options.sanitizer ? this.options.sanitizer(cap[0]) : escape(cap[0])) : cap[0];
      } else {
        text = escape(this.options.smartypants ? smartypants(cap[0]) : cap[0]);
      }
      return {
        type: 'text',
        raw: cap[0],
        text
      };
    }
  }
}

/**
 * Block-Level Grammar
 */
const block = {
  newline: /^(?: *(?:\n|$))+/,
  code: /^( {4}[^\n]+(?:\n(?: *(?:\n|$))*)?)+/,
  fences: /^ {0,3}(`{3,}(?=[^`\n]*\n)|~{3,})([^\n]*)\n(?:|([\s\S]*?)\n)(?: {0,3}\1[~`]* *(?=\n|$)|$)/,
  hr: /^ {0,3}((?:- *){3,}|(?:_ *){3,}|(?:\* *){3,})(?:\n+|$)/,
  heading: /^ {0,3}(#{1,6})(?=\s|$)(.*)(?:\n+|$)/,
  blockquote: /^( {0,3}> ?(paragraph|[^\n]*)(?:\n|$))+/,
  list: /^( {0,3}bull)( [^\n]+?)?(?:\n|$)/,
  html: '^ {0,3}(?:' // optional indentation
    + '<(script|pre|style|textarea)[\\s>][\\s\\S]*?(?:</\\1>[^\\n]*\\n+|$)' // (1)
    + '|comment[^\\n]*(\\n+|$)' // (2)
    + '|<\\?[\\s\\S]*?(?:\\?>\\n*|$)' // (3)
    + '|<![A-Z][\\s\\S]*?(?:>\\n*|$)' // (4)
    + '|<!\\[CDATA\\[[\\s\\S]*?(?:\\]\\]>\\n*|$)' // (5)
    + '|</?(tag)(?: +|\\n|/?>)[\\s\\S]*?(?:(?:\\n *)+\\n|$)' // (6)
    + '|<(?!script|pre|style|textarea)([a-z][\\w-]*)(?:attribute)*? */?>(?=[ \\t]*(?:\\n|$))[\\s\\S]*?(?:(?:\\n *)+\\n|$)' // (7) open tag
    + '|</(?!script|pre|style|textarea)[a-z][\\w-]*\\s*>(?=[ \\t]*(?:\\n|$))[\\s\\S]*?(?:(?:\\n *)+\\n|$)' // (7) closing tag
    + ')',
  def: /^ {0,3}\[(label)\]: *\n? *<?([^\s>]+)>?(?:(?: +\n? *| *\n *)(title))? *(?:\n+|$)/,
  table: noopTest,
  lheading: /^([^\n]+)\n {0,3}(=+|-+) *(?:\n+|$)/,
  // regex template, placeholders will be replaced according to different paragraph
  // interruption rules of commonmark and the original markdown spec:
  _paragraph: /^([^\n]+(?:\n(?!hr|heading|lheading|blockquote|fences|list|html| +\n)[^\n]+)*)/,
  text: /^[^\n]+/
};

block._label = /(?!\s*\])(?:\\[\[\]]|[^\[\]])+/;
block._title = /(?:"(?:\\"?|[^"\\])*"|'[^'\n]*(?:\n[^'\n]+)*\n?'|\([^()]*\))/;
block.def = edit(block.def)
  .replace('label', block._label)
  .replace('title', block._title)
  .getRegex();

block.bullet = /(?:[*+-]|\d{1,9}[.)])/;
block.listItemStart = edit(/^( *)(bull) */)
  .replace('bull', block.bullet)
  .getRegex();

block.list = edit(block.list)
  .replace(/bull/g, block.bullet)
  .replace('hr', '\\n+(?=\\1?(?:(?:- *){3,}|(?:_ *){3,}|(?:\\* *){3,})(?:\\n+|$))')
  .replace('def', '\\n+(?=' + block.def.source + ')')
  .getRegex();

block._tag = 'address|article|aside|base|basefont|blockquote|body|caption'
  + '|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption'
  + '|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe'
  + '|legend|li|link|main|menu|menuitem|meta|nav|noframes|ol|optgroup|option'
  + '|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|title|tr'
  + '|track|ul';
block._comment = /<!--(?!-?>)[\s\S]*?(?:-->|$)/;
block.html = edit(block.html, 'i')
  .replace('comment', block._comment)
  .replace('tag', block._tag)
  .replace('attribute', / +[a-zA-Z:_][\w.:-]*(?: *= *"[^"\n]*"| *= *'[^'\n]*'| *= *[^\s"'=<>`]+)?/)
  .getRegex();

block.paragraph = edit(block._paragraph)
  .replace('hr', block.hr)
  .replace('heading', ' {0,3}#{1,6} ')
  .replace('|lheading', '') // setex headings don't interrupt commonmark paragraphs
  .replace('blockquote', ' {0,3}>')
  .replace('fences', ' {0,3}(?:`{3,}(?=[^`\\n]*\\n)|~{3,})[^\\n]*\\n')
  .replace('list', ' {0,3}(?:[*+-]|1[.)]) ') // only lists starting from 1 can interrupt
  .replace('html', '</?(?:tag)(?: +|\\n|/?>)|<(?:script|pre|style|textarea|!--)')
  .replace('tag', block._tag) // pars can be interrupted by type (6) html blocks
  .getRegex();

block.blockquote = edit(block.blockquote)
  .replace('paragraph', block.paragraph)
  .getRegex();

/**
 * Normal Block Grammar
 */

block.normal = merge({}, block);

/**
 * GFM Block Grammar
 */

block.gfm = merge({}, block.normal, {
  table: '^ *([^\\n ].*\\|.*)\\n' // Header
    + ' {0,3}(?:\\| *)?(:?-+:? *(?:\\| *:?-+:? *)*)(?:\\| *)?' // Align
    + '(?:\\n((?:(?! *\\n|hr|heading|blockquote|code|fences|list|html).*(?:\\n|$))*)\\n*|$)' // Cells
});

block.gfm.table = edit(block.gfm.table)
  .replace('hr', block.hr)
  .replace('heading', ' {0,3}#{1,6} ')
  .replace('blockquote', ' {0,3}>')
  .replace('code', ' {4}[^\\n]')
  .replace('fences', ' {0,3}(?:`{3,}(?=[^`\\n]*\\n)|~{3,})[^\\n]*\\n')
  .replace('list', ' {0,3}(?:[*+-]|1[.)]) ') // only lists starting from 1 can interrupt
  .replace('html', '</?(?:tag)(?: +|\\n|/?>)|<(?:script|pre|style|textarea|!--)')
  .replace('tag', block._tag) // tables can be interrupted by type (6) html blocks
  .getRegex();

/**
 * Pedantic grammar (original John Gruber's loose markdown specification)
 */

block.pedantic = merge({}, block.normal, {
  html: edit(
    '^ *(?:comment *(?:\\n|\\s*$)'
    + '|<(tag)[\\s\\S]+?</\\1> *(?:\\n{2,}|\\s*$)' // closed tag
    + '|<tag(?:"[^"]*"|\'[^\']*\'|\\s[^\'"/>\\s]*)*?/?> *(?:\\n{2,}|\\s*$))')
    .replace('comment', block._comment)
    .replace(/tag/g, '(?!(?:'
      + 'a|em|strong|small|s|cite|q|dfn|abbr|data|time|code|var|samp|kbd|sub'
      + '|sup|i|b|u|mark|ruby|rt|rp|bdi|bdo|span|br|wbr|ins|del|img)'
      + '\\b)\\w+(?!:|[^\\w\\s@]*@)\\b')
    .getRegex(),
  def: /^ *\[([^\]]+)\]: *<?([^\s>]+)>?(?: +(["(][^\n]+[")]))? *(?:\n+|$)/,
  heading: /^(#{1,6})(.*)(?:\n+|$)/,
  fences: noopTest, // fences not supported
  paragraph: edit(block.normal._paragraph)
    .replace('hr', block.hr)
    .replace('heading', ' *#{1,6} *[^\n]')
    .replace('lheading', block.lheading)
    .replace('blockquote', ' {0,3}>')
    .replace('|fences', '')
    .replace('|list', '')
    .replace('|html', '')
    .getRegex()
});

/**
 * Inline-Level Grammar
 */
const inline = {
  escape: /^\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])/,
  autolink: /^<(scheme:[^\s\x00-\x1f<>]*|email)>/,
  url: noopTest,
  tag: '^comment'
    + '|^</[a-zA-Z][\\w:-]*\\s*>' // self-closing tag
    + '|^<[a-zA-Z][\\w-]*(?:attribute)*?\\s*/?>' // open tag
    + '|^<\\?[\\s\\S]*?\\?>' // processing instruction, e.g. <?php ?>
    + '|^<![a-zA-Z]+\\s[\\s\\S]*?>' // declaration, e.g. <!DOCTYPE html>
    + '|^<!\\[CDATA\\[[\\s\\S]*?\\]\\]>', // CDATA section
  link: /^!?\[(label)\]\(\s*(href)(?:\s+(title))?\s*\)/,
  reflink: /^!?\[(label)\]\[(?!\s*\])((?:\\[\[\]]?|[^\[\]\\])+)\]/,
  nolink: /^!?\[(?!\s*\])((?:\[[^\[\]]*\]|\\[\[\]]|[^\[\]])*)\](?:\[\])?/,
  reflinkSearch: 'reflink|nolink(?!\\()',
  emStrong: {
    lDelim: /^(?:\*+(?:([punct_])|[^\s*]))|^_+(?:([punct*])|([^\s_]))/,
    //        (1) and (2) can only be a Right Delimiter. (3) and (4) can only be Left.  (5) and (6) can be either Left or Right.
    //        () Skip orphan delim inside strong    (1) #***                (2) a***#, a***                   (3) #***a, ***a                 (4) ***#              (5) #***#                 (6) a***a
    rDelimAst: /^[^_*]*?\_\_[^_*]*?\*[^_*]*?(?=\_\_)|[punct_](\*+)(?=[\s]|$)|[^punct*_\s](\*+)(?=[punct_\s]|$)|[punct_\s](\*+)(?=[^punct*_\s])|[\s](\*+)(?=[punct_])|[punct_](\*+)(?=[punct_])|[^punct*_\s](\*+)(?=[^punct*_\s])/,
    rDelimUnd: /^[^_*]*?\*\*[^_*]*?\_[^_*]*?(?=\*\*)|[punct*](\_+)(?=[\s]|$)|[^punct*_\s](\_+)(?=[punct*\s]|$)|[punct*\s](\_+)(?=[^punct*_\s])|[\s](\_+)(?=[punct*])|[punct*](\_+)(?=[punct*])/ // ^- Not allowed for _
  },
  code: /^(`+)([^`]|[^`][\s\S]*?[^`])\1(?!`)/,
  br: /^( {2,}|\\)\n(?!\s*$)/,
  del: noopTest,
  text: /^(`+|[^`])(?:(?= {2,}\n)|[\s\S]*?(?:(?=[\\<!\[`*_]|\b_|$)|[^ ](?= {2,}\n)))/,
  punctuation: /^([\spunctuation])/
};

// list of punctuation marks from CommonMark spec
// without * and _ to handle the different emphasis markers * and _
inline._punctuation = '!"#$%&\'()+\\-.,/:;<=>?@\\[\\]`^{|}~';
inline.punctuation = edit(inline.punctuation).replace(/punctuation/g, inline._punctuation).getRegex();

// sequences em should skip over [title](link), `code`, <html>
inline.blockSkip = /\[[^\]]*?\]\([^\)]*?\)|`[^`]*?`|<[^>]*?>/g;
inline.escapedEmSt = /\\\*|\\_/g;

inline._comment = edit(block._comment).replace('(?:-->|$)', '-->').getRegex();

inline.emStrong.lDelim = edit(inline.emStrong.lDelim)
  .replace(/punct/g, inline._punctuation)
  .getRegex();

inline.emStrong.rDelimAst = edit(inline.emStrong.rDelimAst, 'g')
  .replace(/punct/g, inline._punctuation)
  .getRegex();

inline.emStrong.rDelimUnd = edit(inline.emStrong.rDelimUnd, 'g')
  .replace(/punct/g, inline._punctuation)
  .getRegex();

inline._escapes = /\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])/g;

inline._scheme = /[a-zA-Z][a-zA-Z0-9+.-]{1,31}/;
inline._email = /[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+(@)[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?![-_])/;
inline.autolink = edit(inline.autolink)
  .replace('scheme', inline._scheme)
  .replace('email', inline._email)
  .getRegex();

inline._attribute = /\s+[a-zA-Z:_][\w.:-]*(?:\s*=\s*"[^"]*"|\s*=\s*'[^']*'|\s*=\s*[^\s"'=<>`]+)?/;

inline.tag = edit(inline.tag)
  .replace('comment', inline._comment)
  .replace('attribute', inline._attribute)
  .getRegex();

inline._label = /(?:\[(?:\\.|[^\[\]\\])*\]|\\.|`[^`]*`|[^\[\]\\`])*?/;
inline._href = /<(?:\\.|[^\n<>\\])+>|[^\s\x00-\x1f]*/;
inline._title = /"(?:\\"?|[^"\\])*"|'(?:\\'?|[^'\\])*'|\((?:\\\)?|[^)\\])*\)/;

inline.link = edit(inline.link)
  .replace('label', inline._label)
  .replace('href', inline._href)
  .replace('title', inline._title)
  .getRegex();

inline.reflink = edit(inline.reflink)
  .replace('label', inline._label)
  .getRegex();

inline.reflinkSearch = edit(inline.reflinkSearch, 'g')
  .replace('reflink', inline.reflink)
  .replace('nolink', inline.nolink)
  .getRegex();

/**
 * Normal Inline Grammar
 */

inline.normal = merge({}, inline);

/**
 * Pedantic Inline Grammar
 */

inline.pedantic = merge({}, inline.normal, {
  strong: {
    start: /^__|\*\*/,
    middle: /^__(?=\S)([\s\S]*?\S)__(?!_)|^\*\*(?=\S)([\s\S]*?\S)\*\*(?!\*)/,
    endAst: /\*\*(?!\*)/g,
    endUnd: /__(?!_)/g
  },
  em: {
    start: /^_|\*/,
    middle: /^()\*(?=\S)([\s\S]*?\S)\*(?!\*)|^_(?=\S)([\s\S]*?\S)_(?!_)/,
    endAst: /\*(?!\*)/g,
    endUnd: /_(?!_)/g
  },
  link: edit(/^!?\[(label)\]\((.*?)\)/)
    .replace('label', inline._label)
    .getRegex(),
  reflink: edit(/^!?\[(label)\]\s*\[([^\]]*)\]/)
    .replace('label', inline._label)
    .getRegex()
});

/**
 * GFM Inline Grammar
 */

inline.gfm = merge({}, inline.normal, {
  escape: edit(inline.escape).replace('])', '~|])').getRegex(),
  _extended_email: /[A-Za-z0-9._+-]+(@)[a-zA-Z0-9-_]+(?:\.[a-zA-Z0-9-_]*[a-zA-Z0-9])+(?![-_])/,
  url: /^((?:ftp|https?):\/\/|www\.)(?:[a-zA-Z0-9\-]+\.?)+[^\s<]*|^email/,
  _backpedal: /(?:[^?!.,:;*_~()&]+|\([^)]*\)|&(?![a-zA-Z0-9]+;$)|[?!.,:;*_~)]+(?!$))+/,
  del: /^(~~?)(?=[^\s~])([\s\S]*?[^\s~])\1(?=[^~]|$)/,
  text: /^([`~]+|[^`~])(?:(?= {2,}\n)|(?=[a-zA-Z0-9.!#$%&'*+\/=?_`{\|}~-]+@)|[\s\S]*?(?:(?=[\\<!\[`*~_]|\b_|https?:\/\/|ftp:\/\/|www\.|$)|[^ ](?= {2,}\n)|[^a-zA-Z0-9.!#$%&'*+\/=?_`{\|}~-](?=[a-zA-Z0-9.!#$%&'*+\/=?_`{\|}~-]+@)))/
});

inline.gfm.url = edit(inline.gfm.url, 'i')
  .replace('email', inline.gfm._extended_email)
  .getRegex();
/**
 * GFM + Line Breaks Inline Grammar
 */

inline.breaks = merge({}, inline.gfm, {
  br: edit(inline.br).replace('{2,}', '*').getRegex(),
  text: edit(inline.gfm.text)
    .replace('\\b_', '\\b_| {2,}\\n')
    .replace(/\{2,\}/g, '*')
    .getRegex()
});

/**
 * smartypants text replacement
 */
function smartypants(text) {
  return text
    // em-dashes
    .replace(/---/g, '\u2014')
    // en-dashes
    .replace(/--/g, '\u2013')
    // opening singles
    .replace(/(^|[-\u2014/(\[{"\s])'/g, '$1\u2018')
    // closing singles & apostrophes
    .replace(/'/g, '\u2019')
    // opening doubles
    .replace(/(^|[-\u2014/(\[{\u2018\s])"/g, '$1\u201c')
    // closing doubles
    .replace(/"/g, '\u201d')
    // ellipses
    .replace(/\.{3}/g, '\u2026');
}

/**
 * mangle email addresses
 */
function mangle(text) {
  let out = '',
    i,
    ch;

  const l = text.length;
  for (i = 0; i < l; i++) {
    ch = text.charCodeAt(i);
    if (Math.random() > 0.5) {
      ch = 'x' + ch.toString(16);
    }
    out += '&#' + ch + ';';
  }

  return out;
}

/**
 * Block Lexer
 */
class Lexer {
  constructor(options) {
    this.tokens = [];
    this.tokens.links = Object.create(null);
    this.options = options || defaults;
    this.options.tokenizer = this.options.tokenizer || new Tokenizer();
    this.tokenizer = this.options.tokenizer;
    this.tokenizer.options = this.options;
    this.tokenizer.lexer = this;
    this.inlineQueue = [];
    this.state = {
      inLink: false,
      inRawBlock: false,
      top: true
    };

    const rules = {
      block: block.normal,
      inline: inline.normal
    };

    if (this.options.pedantic) {
      rules.block = block.pedantic;
      rules.inline = inline.pedantic;
    } else if (this.options.gfm) {
      rules.block = block.gfm;
      if (this.options.breaks) {
        rules.inline = inline.breaks;
      } else {
        rules.inline = inline.gfm;
      }
    }
    this.tokenizer.rules = rules;
  }

  /**
   * Expose Rules
   */
  static get rules() {
    return {
      block,
      inline
    };
  }

  /**
   * Static Lex Method
   */
  static lex(src, options) {
    const lexer = new Lexer(options);
    return lexer.lex(src);
  }

  /**
   * Static Lex Inline Method
   */
  static lexInline(src, options) {
    const lexer = new Lexer(options);
    return lexer.inlineTokens(src);
  }

  /**
   * Preprocessing
   */
  lex(src) {
    src = src
      .replace(/\r\n|\r/g, '\n')
      .replace(/\t/g, '    ');

    this.blockTokens(src, this.tokens);

    let next;
    while (next = this.inlineQueue.shift()) {
      this.inlineTokens(next.src, next.tokens);
    }

    return this.tokens;
  }

  /**
   * Lexing
   */
  blockTokens(src, tokens = []) {
    if (this.options.pedantic) {
      src = src.replace(/^ +$/gm, '');
    }
    let token, lastToken, cutSrc, lastParagraphClipped;

    while (src) {
      if (this.options.extensions
        && this.options.extensions.block
        && this.options.extensions.block.some((extTokenizer) => {
          if (token = extTokenizer.call({ lexer: this }, src, tokens)) {
            src = src.substring(token.raw.length);
            tokens.push(token);
            return true;
          }
          return false;
        })) {
        continue;
      }

      // newline
      if (token = this.tokenizer.space(src)) {
        src = src.substring(token.raw.length);
        if (token.type) {
          tokens.push(token);
        }
        continue;
      }

      // code
      if (token = this.tokenizer.code(src)) {
        src = src.substring(token.raw.length);
        lastToken = tokens[tokens.length - 1];
        // An indented code block cannot interrupt a paragraph.
        if (lastToken && (lastToken.type === 'paragraph' || lastToken.type === 'text')) {
          lastToken.raw += '\n' + token.raw;
          lastToken.text += '\n' + token.text;
          this.inlineQueue[this.inlineQueue.length - 1].src = lastToken.text;
        } else {
          tokens.push(token);
        }
        continue;
      }

      // fences
      if (token = this.tokenizer.fences(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // heading
      if (token = this.tokenizer.heading(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // hr
      if (token = this.tokenizer.hr(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // blockquote
      if (token = this.tokenizer.blockquote(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // list
      if (token = this.tokenizer.list(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // html
      if (token = this.tokenizer.html(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // def
      if (token = this.tokenizer.def(src)) {
        src = src.substring(token.raw.length);
        lastToken = tokens[tokens.length - 1];
        if (lastToken && (lastToken.type === 'paragraph' || lastToken.type === 'text')) {
          lastToken.raw += '\n' + token.raw;
          lastToken.text += '\n' + token.raw;
          this.inlineQueue[this.inlineQueue.length - 1].src = lastToken.text;
        } else if (!this.tokens.links[token.tag]) {
          this.tokens.links[token.tag] = {
            href: token.href,
            title: token.title
          };
        }
        continue;
      }

      // table (gfm)
      if (token = this.tokenizer.table(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // lheading
      if (token = this.tokenizer.lheading(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // top-level paragraph
      // prevent paragraph consuming extensions by clipping 'src' to extension start
      cutSrc = src;
      if (this.options.extensions && this.options.extensions.startBlock) {
        let startIndex = Infinity;
        const tempSrc = src.slice(1);
        let tempStart;
        this.options.extensions.startBlock.forEach(function(getStartIndex) {
          tempStart = getStartIndex.call({ lexer: this }, tempSrc);
          if (typeof tempStart === 'number' && tempStart >= 0) { startIndex = Math.min(startIndex, tempStart); }
        });
        if (startIndex < Infinity && startIndex >= 0) {
          cutSrc = src.substring(0, startIndex + 1);
        }
      }
      if (this.state.top && (token = this.tokenizer.paragraph(cutSrc))) {
        lastToken = tokens[tokens.length - 1];
        if (lastParagraphClipped && lastToken.type === 'paragraph') {
          lastToken.raw += '\n' + token.raw;
          lastToken.text += '\n' + token.text;
          this.inlineQueue.pop();
          this.inlineQueue[this.inlineQueue.length - 1].src = lastToken.text;
        } else {
          tokens.push(token);
        }
        lastParagraphClipped = (cutSrc.length !== src.length);
        src = src.substring(token.raw.length);
        continue;
      }

      // text
      if (token = this.tokenizer.text(src)) {
        src = src.substring(token.raw.length);
        lastToken = tokens[tokens.length - 1];
        if (lastToken && lastToken.type === 'text') {
          lastToken.raw += '\n' + token.raw;
          lastToken.text += '\n' + token.text;
          this.inlineQueue.pop();
          this.inlineQueue[this.inlineQueue.length - 1].src = lastToken.text;
        } else {
          tokens.push(token);
        }
        continue;
      }

      if (src) {
        const errMsg = 'Infinite loop on byte: ' + src.charCodeAt(0);
        if (this.options.silent) {
          console.error(errMsg);
          break;
        } else {
          throw new Error(errMsg);
        }
      }
    }

    this.state.top = true;
    return tokens;
  }

  inline(src, tokens) {
    this.inlineQueue.push({ src, tokens });
  }

  /**
   * Lexing/Compiling
   */
  inlineTokens(src, tokens = []) {
    let token, lastToken, cutSrc;

    // String with links masked to avoid interference with em and strong
    let maskedSrc = src;
    let match;
    let keepPrevChar, prevChar;

    // Mask out reflinks
    if (this.tokens.links) {
      const links = Object.keys(this.tokens.links);
      if (links.length > 0) {
        while ((match = this.tokenizer.rules.inline.reflinkSearch.exec(maskedSrc)) != null) {
          if (links.includes(match[0].slice(match[0].lastIndexOf('[') + 1, -1))) {
            maskedSrc = maskedSrc.slice(0, match.index) + '[' + repeatString('a', match[0].length - 2) + ']' + maskedSrc.slice(this.tokenizer.rules.inline.reflinkSearch.lastIndex);
          }
        }
      }
    }
    // Mask out other blocks
    while ((match = this.tokenizer.rules.inline.blockSkip.exec(maskedSrc)) != null) {
      maskedSrc = maskedSrc.slice(0, match.index) + '[' + repeatString('a', match[0].length - 2) + ']' + maskedSrc.slice(this.tokenizer.rules.inline.blockSkip.lastIndex);
    }

    // Mask out escaped em & strong delimiters
    while ((match = this.tokenizer.rules.inline.escapedEmSt.exec(maskedSrc)) != null) {
      maskedSrc = maskedSrc.slice(0, match.index) + '++' + maskedSrc.slice(this.tokenizer.rules.inline.escapedEmSt.lastIndex);
    }

    while (src) {
      if (!keepPrevChar) {
        prevChar = '';
      }
      keepPrevChar = false;

      // extensions
      if (this.options.extensions
        && this.options.extensions.inline
        && this.options.extensions.inline.some((extTokenizer) => {
          if (token = extTokenizer.call({ lexer: this }, src, tokens)) {
            src = src.substring(token.raw.length);
            tokens.push(token);
            return true;
          }
          return false;
        })) {
        continue;
      }

      // escape
      if (token = this.tokenizer.escape(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // tag
      if (token = this.tokenizer.tag(src)) {
        src = src.substring(token.raw.length);
        lastToken = tokens[tokens.length - 1];
        if (lastToken && token.type === 'text' && lastToken.type === 'text') {
          lastToken.raw += token.raw;
          lastToken.text += token.text;
        } else {
          tokens.push(token);
        }
        continue;
      }

      // link
      if (token = this.tokenizer.link(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // reflink, nolink
      if (token = this.tokenizer.reflink(src, this.tokens.links)) {
        src = src.substring(token.raw.length);
        lastToken = tokens[tokens.length - 1];
        if (lastToken && token.type === 'text' && lastToken.type === 'text') {
          lastToken.raw += token.raw;
          lastToken.text += token.text;
        } else {
          tokens.push(token);
        }
        continue;
      }

      // em & strong
      if (token = this.tokenizer.emStrong(src, maskedSrc, prevChar)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // code
      if (token = this.tokenizer.codespan(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // br
      if (token = this.tokenizer.br(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // del (gfm)
      if (token = this.tokenizer.del(src)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // autolink
      if (token = this.tokenizer.autolink(src, mangle)) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // url (gfm)
      if (!this.state.inLink && (token = this.tokenizer.url(src, mangle))) {
        src = src.substring(token.raw.length);
        tokens.push(token);
        continue;
      }

      // text
      // prevent inlineText consuming extensions by clipping 'src' to extension start
      cutSrc = src;
      if (this.options.extensions && this.options.extensions.startInline) {
        let startIndex = Infinity;
        const tempSrc = src.slice(1);
        let tempStart;
        this.options.extensions.startInline.forEach(function(getStartIndex) {
          tempStart = getStartIndex.call({ lexer: this }, tempSrc);
          if (typeof tempStart === 'number' && tempStart >= 0) { startIndex = Math.min(startIndex, tempStart); }
        });
        if (startIndex < Infinity && startIndex >= 0) {
          cutSrc = src.substring(0, startIndex + 1);
        }
      }
      if (token = this.tokenizer.inlineText(cutSrc, smartypants)) {
        src = src.substring(token.raw.length);
        if (token.raw.slice(-1) !== '_') { // Track prevChar before string of ____ started
          prevChar = token.raw.slice(-1);
        }
        keepPrevChar = true;
        lastToken = tokens[tokens.length - 1];
        if (lastToken && lastToken.type === 'text') {
          lastToken.raw += token.raw;
          lastToken.text += token.text;
        } else {
          tokens.push(token);
        }
        continue;
      }

      if (src) {
        const errMsg = 'Infinite loop on byte: ' + src.charCodeAt(0);
        if (this.options.silent) {
          console.error(errMsg);
          break;
        } else {
          throw new Error(errMsg);
        }
      }
    }

    return tokens;
  }
}

/**
 * Renderer
 */
class Renderer {
  constructor(options) {
    this.options = options || defaults;
  }

  code(code, infostring, escaped) {
    const lang = (infostring || '').match(/\S*/)[0];
    if (this.options.highlight) {
      const out = this.options.highlight(code, lang);
      if (out != null && out !== code) {
        escaped = true;
        code = out;
      }
    }

    code = code.replace(/\n$/, '') + '\n';

    if (!lang) {
      return '<pre><code>'
        + (escaped ? code : escape(code, true))
        + '</code></pre>\n';
    }

    return '<pre><code class="'
      + this.options.langPrefix
      + escape(lang, true)
      + '">'
      + (escaped ? code : escape(code, true))
      + '</code></pre>\n';
  }

  blockquote(quote) {
    return '<blockquote>\n' + quote + '</blockquote>\n';
  }

  html(html) {
    return html;
  }

  heading(text, level, raw, slugger) {
    if (this.options.headerIds) {
      return '<h'
        + level
        + ' id="'
        + this.options.headerPrefix
        + slugger.slug(raw)
        + '">'
        + text
        + '</h'
        + level
        + '>\n';
    }
    // ignore IDs
    return '<h' + level + '>' + text + '</h' + level + '>\n';
  }

  hr() {
    return this.options.xhtml ? '<hr/>\n' : '<hr>\n';
  }

  list(body, ordered, start) {
    const type = ordered ? 'ol' : 'ul',
      startatt = (ordered && start !== 1) ? (' start="' + start + '"') : '';
    return '<' + type + startatt + '>\n' + body + '</' + type + '>\n';
  }

  listitem(text) {
    return '<li>' + text + '</li>\n';
  }

  checkbox(checked) {
    return '<input '
      + (checked ? 'checked="" ' : '')
      + 'disabled="" type="checkbox"'
      + (this.options.xhtml ? ' /' : '')
      + '> ';
  }

  paragraph(text) {
    return '<p>' + text + '</p>\n';
  }

  table(header, body) {
    if (body) body = '<tbody>' + body + '</tbody>';

    return '<table>\n'
      + '<thead>\n'
      + header
      + '</thead>\n'
      + body
      + '</table>\n';
  }

  tablerow(content) {
    return '<tr>\n' + content + '</tr>\n';
  }

  tablecell(content, flags) {
    const type = flags.header ? 'th' : 'td';
    const tag = flags.align
      ? '<' + type + ' align="' + flags.align + '">'
      : '<' + type + '>';
    return tag + content + '</' + type + '>\n';
  }

  // span level renderer
  strong(text) {
    return '<strong>' + text + '</strong>';
  }

  em(text) {
    return '<em>' + text + '</em>';
  }

  codespan(text) {
    return '<code>' + text + '</code>';
  }

  br() {
    return this.options.xhtml ? '<br/>' : '<br>';
  }

  del(text) {
    return '<del>' + text + '</del>';
  }

  link(href, title, text) {
    href = cleanUrl(this.options.sanitize, this.options.baseUrl, href);
    if (href === null) {
      return text;
    }
    let out = '<a href="' + escape(href) + '"';
    if (title) {
      out += ' title="' + title + '"';
    }
    out += '>' + text + '</a>';
    return out;
  }

  image(href, title, text) {
    href = cleanUrl(this.options.sanitize, this.options.baseUrl, href);
    if (href === null) {
      return text;
    }

    let out = '<img src="' + href + '" alt="' + text + '"';
    if (title) {
      out += ' title="' + title + '"';
    }
    out += this.options.xhtml ? '/>' : '>';
    return out;
  }

  text(text) {
    return text;
  }
}

/**
 * TextRenderer
 * returns only the textual part of the token
 */
class TextRenderer {
  // no need for block level renderers
  strong(text) {
    return text;
  }

  em(text) {
    return text;
  }

  codespan(text) {
    return text;
  }

  del(text) {
    return text;
  }

  html(text) {
    return text;
  }

  text(text) {
    return text;
  }

  link(href, title, text) {
    return '' + text;
  }

  image(href, title, text) {
    return '' + text;
  }

  br() {
    return '';
  }
}

/**
 * Slugger generates header id
 */
class Slugger {
  constructor() {
    this.seen = {};
  }

  serialize(value) {
    return value
      .toLowerCase()
      .trim()
      // remove html tags
      .replace(/<[!\/a-z].*?>/ig, '')
      // remove unwanted chars
      .replace(/[\u2000-\u206F\u2E00-\u2E7F\\'!"#$%&()*+,./:;<=>?@[\]^`{|}~]/g, '')
      .replace(/\s/g, '-');
  }

  /**
   * Finds the next safe (unique) slug to use
   */
  getNextSafeSlug(originalSlug, isDryRun) {
    let slug = originalSlug;
    let occurenceAccumulator = 0;
    if (this.seen.hasOwnProperty(slug)) {
      occurenceAccumulator = this.seen[originalSlug];
      do {
        occurenceAccumulator++;
        slug = originalSlug + '-' + occurenceAccumulator;
      } while (this.seen.hasOwnProperty(slug));
    }
    if (!isDryRun) {
      this.seen[originalSlug] = occurenceAccumulator;
      this.seen[slug] = 0;
    }
    return slug;
  }

  /**
   * Convert string to unique id
   * @param {object} options
   * @param {boolean} options.dryrun Generates the next unique slug without updating the internal accumulator.
   */
  slug(value, options = {}) {
    const slug = this.serialize(value);
    return this.getNextSafeSlug(slug, options.dryrun);
  }
}

/**
 * Parsing & Compiling
 */
class Parser {
  constructor(options) {
    this.options = options || defaults;
    this.options.renderer = this.options.renderer || new Renderer();
    this.renderer = this.options.renderer;
    this.renderer.options = this.options;
    this.textRenderer = new TextRenderer();
    this.slugger = new Slugger();
  }

  /**
   * Static Parse Method
   */
  static parse(tokens, options) {
    const parser = new Parser(options);
    return parser.parse(tokens);
  }

  /**
   * Static Parse Inline Method
   */
  static parseInline(tokens, options) {
    const parser = new Parser(options);
    return parser.parseInline(tokens);
  }

  /**
   * Parse Loop
   */
  parse(tokens, top = true) {
    let out = '',
      i,
      j,
      k,
      l2,
      l3,
      row,
      cell,
      header,
      body,
      token,
      ordered,
      start,
      loose,
      itemBody,
      item,
      checked,
      task,
      checkbox,
      ret;

    const l = tokens.length;
    for (i = 0; i < l; i++) {
      token = tokens[i];

      // Run any renderer extensions
      if (this.options.extensions && this.options.extensions.renderers && this.options.extensions.renderers[token.type]) {
        ret = this.options.extensions.renderers[token.type].call({ parser: this }, token);
        if (ret !== false || !['space', 'hr', 'heading', 'code', 'table', 'blockquote', 'list', 'html', 'paragraph', 'text'].includes(token.type)) {
          out += ret || '';
          continue;
        }
      }

      switch (token.type) {
        case 'space': {
          continue;
        }
        case 'hr': {
          out += this.renderer.hr();
          continue;
        }
        case 'heading': {
          out += this.renderer.heading(
            this.parseInline(token.tokens),
            token.depth,
            unescape(this.parseInline(token.tokens, this.textRenderer)),
            this.slugger);
          continue;
        }
        case 'code': {
          out += this.renderer.code(token.text,
            token.lang,
            token.escaped);
          continue;
        }
        case 'table': {
          header = '';

          // header
          cell = '';
          l2 = token.header.length;
          for (j = 0; j < l2; j++) {
            cell += this.renderer.tablecell(
              this.parseInline(token.header[j].tokens),
              { header: true, align: token.align[j] }
            );
          }
          header += this.renderer.tablerow(cell);

          body = '';
          l2 = token.rows.length;
          for (j = 0; j < l2; j++) {
            row = token.rows[j];

            cell = '';
            l3 = row.length;
            for (k = 0; k < l3; k++) {
              cell += this.renderer.tablecell(
                this.parseInline(row[k].tokens),
                { header: false, align: token.align[k] }
              );
            }

            body += this.renderer.tablerow(cell);
          }
          out += this.renderer.table(header, body);
          continue;
        }
        case 'blockquote': {
          body = this.parse(token.tokens);
          out += this.renderer.blockquote(body);
          continue;
        }
        case 'list': {
          ordered = token.ordered;
          start = token.start;
          loose = token.loose;
          l2 = token.items.length;

          body = '';
          for (j = 0; j < l2; j++) {
            item = token.items[j];
            checked = item.checked;
            task = item.task;

            itemBody = '';
            if (item.task) {
              checkbox = this.renderer.checkbox(checked);
              if (loose) {
                if (item.tokens.length > 0 && item.tokens[0].type === 'paragraph') {
                  item.tokens[0].text = checkbox + ' ' + item.tokens[0].text;
                  if (item.tokens[0].tokens && item.tokens[0].tokens.length > 0 && item.tokens[0].tokens[0].type === 'text') {
                    item.tokens[0].tokens[0].text = checkbox + ' ' + item.tokens[0].tokens[0].text;
                  }
                } else {
                  item.tokens.unshift({
                    type: 'text',
                    text: checkbox
                  });
                }
              } else {
                itemBody += checkbox;
              }
            }

            itemBody += this.parse(item.tokens, loose);
            body += this.renderer.listitem(itemBody, task, checked);
          }

          out += this.renderer.list(body, ordered, start);
          continue;
        }
        case 'html': {
          // TODO parse inline content if parameter markdown=1
          out += this.renderer.html(token.text);
          continue;
        }
        case 'paragraph': {
          out += this.renderer.paragraph(this.parseInline(token.tokens));
          continue;
        }
        case 'text': {
          body = token.tokens ? this.parseInline(token.tokens) : token.text;
          while (i + 1 < l && tokens[i + 1].type === 'text') {
            token = tokens[++i];
            body += '\n' + (token.tokens ? this.parseInline(token.tokens) : token.text);
          }
          out += top ? this.renderer.paragraph(body) : body;
          continue;
        }

        default: {
          const errMsg = 'Token with "' + token.type + '" type was not found.';
          if (this.options.silent) {
            console.error(errMsg);
            return;
          } else {
            throw new Error(errMsg);
          }
        }
      }
    }

    return out;
  }

  /**
   * Parse Inline Tokens
   */
  parseInline(tokens, renderer) {
    renderer = renderer || this.renderer;
    let out = '',
      i,
      token,
      ret;

    const l = tokens.length;
    for (i = 0; i < l; i++) {
      token = tokens[i];

      // Run any renderer extensions
      if (this.options.extensions && this.options.extensions.renderers && this.options.extensions.renderers[token.type]) {
        ret = this.options.extensions.renderers[token.type].call({ parser: this }, token);
        if (ret !== false || !['escape', 'html', 'link', 'image', 'strong', 'em', 'codespan', 'br', 'del', 'text'].includes(token.type)) {
          out += ret || '';
          continue;
        }
      }

      switch (token.type) {
        case 'escape': {
          out += renderer.text(token.text);
          break;
        }
        case 'html': {
          out += renderer.html(token.text);
          break;
        }
        case 'link': {
          out += renderer.link(token.href, token.title, this.parseInline(token.tokens, renderer));
          break;
        }
        case 'image': {
          out += renderer.image(token.href, token.title, token.text);
          break;
        }
        case 'strong': {
          out += renderer.strong(this.parseInline(token.tokens, renderer));
          break;
        }
        case 'em': {
          out += renderer.em(this.parseInline(token.tokens, renderer));
          break;
        }
        case 'codespan': {
          out += renderer.codespan(token.text);
          break;
        }
        case 'br': {
          out += renderer.br();
          break;
        }
        case 'del': {
          out += renderer.del(this.parseInline(token.tokens, renderer));
          break;
        }
        case 'text': {
          out += renderer.text(token.text);
          break;
        }
        default: {
          const errMsg = 'Token with "' + token.type + '" type was not found.';
          if (this.options.silent) {
            console.error(errMsg);
            return;
          } else {
            throw new Error(errMsg);
          }
        }
      }
    }
    return out;
  }
}

/**
 * Marked
 */
function marked(src, opt, callback) {
  // throw error in case of non string input
  if (typeof src === 'undefined' || src === null) {
    throw new Error('marked(): input parameter is undefined or null');
  }
  if (typeof src !== 'string') {
    throw new Error('marked(): input parameter is of type '
      + Object.prototype.toString.call(src) + ', string expected');
  }

  if (typeof opt === 'function') {
    callback = opt;
    opt = null;
  }

  opt = merge({}, marked.defaults, opt || {});
  checkSanitizeDeprecation(opt);

  if (callback) {
    const highlight = opt.highlight;
    let tokens;

    try {
      tokens = Lexer.lex(src, opt);
    } catch (e) {
      return callback(e);
    }

    const done = function(err) {
      let out;

      if (!err) {
        try {
          if (opt.walkTokens) {
            marked.walkTokens(tokens, opt.walkTokens);
          }
          out = Parser.parse(tokens, opt);
        } catch (e) {
          err = e;
        }
      }

      opt.highlight = highlight;

      return err
        ? callback(err)
        : callback(null, out);
    };

    if (!highlight || highlight.length < 3) {
      return done();
    }

    delete opt.highlight;

    if (!tokens.length) return done();

    let pending = 0;
    marked.walkTokens(tokens, function(token) {
      if (token.type === 'code') {
        pending++;
        setTimeout(() => {
          highlight(token.text, token.lang, function(err, code) {
            if (err) {
              return done(err);
            }
            if (code != null && code !== token.text) {
              token.text = code;
              token.escaped = true;
            }

            pending--;
            if (pending === 0) {
              done();
            }
          });
        }, 0);
      }
    });

    if (pending === 0) {
      done();
    }

    return;
  }

  try {
    const tokens = Lexer.lex(src, opt);
    if (opt.walkTokens) {
      marked.walkTokens(tokens, opt.walkTokens);
    }
    return Parser.parse(tokens, opt);
  } catch (e) {
    e.message += '\nPlease report this to https://github.com/markedjs/marked.';
    if (opt.silent) {
      return '<p>An error occurred:</p><pre>'
        + escape(e.message + '', true)
        + '</pre>';
    }
    throw e;
  }
}

/**
 * Options
 */

marked.options =
marked.setOptions = function(opt) {
  merge(marked.defaults, opt);
  changeDefaults(marked.defaults);
  return marked;
};

marked.getDefaults = getDefaults;

marked.defaults = defaults;

/**
 * Use Extension
 */

marked.use = function(...args) {
  const opts = merge({}, ...args);
  const extensions = marked.defaults.extensions || { renderers: {}, childTokens: {} };
  let hasExtensions;

  args.forEach((pack) => {
    // ==-- Parse "addon" extensions --== //
    if (pack.extensions) {
      hasExtensions = true;
      pack.extensions.forEach((ext) => {
        if (!ext.name) {
          throw new Error('extension name required');
        }
        if (ext.renderer) { // Renderer extensions
          const prevRenderer = extensions.renderers ? extensions.renderers[ext.name] : null;
          if (prevRenderer) {
            // Replace extension with func to run new extension but fall back if false
            extensions.renderers[ext.name] = function(...args) {
              let ret = ext.renderer.apply(this, args);
              if (ret === false) {
                ret = prevRenderer.apply(this, args);
              }
              return ret;
            };
          } else {
            extensions.renderers[ext.name] = ext.renderer;
          }
        }
        if (ext.tokenizer) { // Tokenizer Extensions
          if (!ext.level || (ext.level !== 'block' && ext.level !== 'inline')) {
            throw new Error("extension level must be 'block' or 'inline'");
          }
          if (extensions[ext.level]) {
            extensions[ext.level].unshift(ext.tokenizer);
          } else {
            extensions[ext.level] = [ext.tokenizer];
          }
          if (ext.start) { // Function to check for start of token
            if (ext.level === 'block') {
              if (extensions.startBlock) {
                extensions.startBlock.push(ext.start);
              } else {
                extensions.startBlock = [ext.start];
              }
            } else if (ext.level === 'inline') {
              if (extensions.startInline) {
                extensions.startInline.push(ext.start);
              } else {
                extensions.startInline = [ext.start];
              }
            }
          }
        }
        if (ext.childTokens) { // Child tokens to be visited by walkTokens
          extensions.childTokens[ext.name] = ext.childTokens;
        }
      });
    }

    // ==-- Parse "overwrite" extensions --== //
    if (pack.renderer) {
      const renderer = marked.defaults.renderer || new Renderer();
      for (const prop in pack.renderer) {
        const prevRenderer = renderer[prop];
        // Replace renderer with func to run extension, but fall back if false
        renderer[prop] = (...args) => {
          let ret = pack.renderer[prop].apply(renderer, args);
          if (ret === false) {
            ret = prevRenderer.apply(renderer, args);
          }
          return ret;
        };
      }
      opts.renderer = renderer;
    }
    if (pack.tokenizer) {
      const tokenizer = marked.defaults.tokenizer || new Tokenizer();
      for (const prop in pack.tokenizer) {
        const prevTokenizer = tokenizer[prop];
        // Replace tokenizer with func to run extension, but fall back if false
        tokenizer[prop] = (...args) => {
          let ret = pack.tokenizer[prop].apply(tokenizer, args);
          if (ret === false) {
            ret = prevTokenizer.apply(tokenizer, args);
          }
          return ret;
        };
      }
      opts.tokenizer = tokenizer;
    }

    // ==-- Parse WalkTokens extensions --== //
    if (pack.walkTokens) {
      const walkTokens = marked.defaults.walkTokens;
      opts.walkTokens = function(token) {
        pack.walkTokens.call(this, token);
        if (walkTokens) {
          walkTokens.call(this, token);
        }
      };
    }

    if (hasExtensions) {
      opts.extensions = extensions;
    }

    marked.setOptions(opts);
  });
};

/**
 * Run callback for every token
 */

marked.walkTokens = function(tokens, callback) {
  for (const token of tokens) {
    callback.call(marked, token);
    switch (token.type) {
      case 'table': {
        for (const cell of token.header) {
          marked.walkTokens(cell.tokens, callback);
        }
        for (const row of token.rows) {
          for (const cell of row) {
            marked.walkTokens(cell.tokens, callback);
          }
        }
        break;
      }
      case 'list': {
        marked.walkTokens(token.items, callback);
        break;
      }
      default: {
        if (marked.defaults.extensions && marked.defaults.extensions.childTokens && marked.defaults.extensions.childTokens[token.type]) { // Walk any extensions
          marked.defaults.extensions.childTokens[token.type].forEach(function(childTokens) {
            marked.walkTokens(token[childTokens], callback);
          });
        } else if (token.tokens) {
          marked.walkTokens(token.tokens, callback);
        }
      }
    }
  }
};

/**
 * Parse Inline
 */
marked.parseInline = function(src, opt) {
  // throw error in case of non string input
  if (typeof src === 'undefined' || src === null) {
    throw new Error('marked.parseInline(): input parameter is undefined or null');
  }
  if (typeof src !== 'string') {
    throw new Error('marked.parseInline(): input parameter is of type '
      + Object.prototype.toString.call(src) + ', string expected');
  }

  opt = merge({}, marked.defaults, opt || {});
  checkSanitizeDeprecation(opt);

  try {
    const tokens = Lexer.lexInline(src, opt);
    if (opt.walkTokens) {
      marked.walkTokens(tokens, opt.walkTokens);
    }
    return Parser.parseInline(tokens, opt);
  } catch (e) {
    e.message += '\nPlease report this to https://github.com/markedjs/marked.';
    if (opt.silent) {
      return '<p>An error occurred:</p><pre>'
        + escape(e.message + '', true)
        + '</pre>';
    }
    throw e;
  }
};

/**
 * Expose
 */
marked.Parser = Parser;
marked.parser = Parser.parse;
marked.Renderer = Renderer;
marked.TextRenderer = TextRenderer;
marked.Lexer = Lexer;
marked.lexer = Lexer.lex;
marked.Tokenizer = Tokenizer;
marked.Slugger = Slugger;
marked.parse = marked;

const options = marked.options;
const setOptions = marked.setOptions;
const use = marked.use;
const walkTokens = marked.walkTokens;
const parseInline = marked.parseInline;
const parse = marked;
const parser = Parser.parse;
const lexer = Lexer.lex;




/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be isolated against other modules in the chunk.
(() => {
/*!******************************************!*\
  !*** ./lib/Yancy/resources/src/index.ts ***!
  \******************************************/
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _editor__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./editor */ "./lib/Yancy/resources/src/editor.ts");

customElements.define('yancy-editor', _editor__WEBPACK_IMPORTED_MODULE_0__["default"]);

})();

/******/ })()
;
//# sourceMappingURL=data:application/json;charset=utf-8;base64,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QjtBQUNBO0FBQ0E7QUFDQTs7QUFFQSxTQUFTLHNCQUFzQjtBQUMvQjtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxRQUFRO0FBQ1I7QUFDQTtBQUNBO0FBQ0EsS0FBSztBQUNMO0FBQ0E7O0FBRUE7QUFDQSwwQkFBMEI7QUFDMUIseUNBQXlDOztBQUV6QztBQUNBO0FBQ0EsSUFBSTtBQUNKO0FBQ0E7O0FBRUEsU0FBUyxrQkFBa0I7QUFDM0I7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLE1BQU07QUFDTjtBQUNBLE1BQU07QUFDTjtBQUNBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFNBQVMsT0FBTztBQUNoQjtBQUNBO0FBQ0EsTUFBTTtBQUNOO0FBQ0EsTUFBTTtBQUNOO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsSUFBSTtBQUNKO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTs7QUFFQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQSxLQUFLO0FBQ0w7QUFD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OztBQUVBO0FBQ0E7QUFDQSxvQkFBb0IsT0FBTztBQUMzQjtBQUNBLHNCQUFzQixnQkFBZ0I7QUFDdEM7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFFBQVE7QUFDUjtBQUNBO0FBQ0E7QUFDQTtBQUNBLFFBQVE7QUFDUjtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFFBQVE7QUFDUjtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQSxRQUFRO0FBQ1I7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsVUFBVTtBQUNWO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLE9BQU87QUFDUDtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBOztB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Q0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsMENBQTBDLGFBQWE7QUFDdkQ7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFNBQVM7QUFDVDtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsVUFBVTtBQUNWO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxVQUFVO0FBQ1Y7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsMkNBQTJDLGFBQWE7QUFDeEQsaUVBQWlFO0FBQ2pFLFNBQVM7QUFDVDtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsVUFBVTtBQUNWO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxVQUFVO0FBQ1Y7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFVBQVU7QUFDVjtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQSw0QkFBNEIsYUFBYTtBQUN6Qzs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsMENBQTBDLGFBQWE7QUFDdkQ7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFNBQVM7QUFDVDtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFVBQVU7QUFDVjtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxVQUFVO0FBQ1Y7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLDJDQUEyQyxhQUFhO0FBQ3hELGlFQUFpRTtBQUNqRSxTQUFTO0FBQ1Q7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsMkNBQTJDO0FBQzNDO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsVUFBVTtBQUNWO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxVQUFVO0FBQ1Y7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTs7QUFFQTtB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VUFDQTs7Ozs7V0N0QkE7V0FDQTtXQUNBO1dBQ0E7V0FDQSx5Q0FBeUMsd0NBQXdDO1dBQ2pGO1dBQ0E7V0FDQTs7Ozs7V0NQQTs7Ozs7V0NBQTtXQUNBO1dBQ0E7V0FDQSx1REFBdUQsaUJBQWlCO1dBQ3hFO1dBQ0EsZ0RBQWdELGFBQWE7V0FDN0Q7Ozs7Ozs7Ozs7OztBQ042QjtBQUM3QixjQUFjLENBQUMsTUFBTSxDQUFFLGNBQWMsRUFBRSwrQ0FBTSxDQUFFLENBQUMiLCJzb3VyY2VzIjpbIndlYnBhY2s6Ly9ZYW5jeS8uL2xpYi9ZYW5jeS9yZXNvdXJjZXMvc3JjL2VkaXRvci5odG1sIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvdGFidmlldy5odG1sIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvZWRpdG9yLnRzIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvc2NoZW1hZm9ybS50cyIsIndlYnBhY2s6Ly9ZYW5jeS8uL2xpYi9ZYW5jeS9yZXNvdXJjZXMvc3JjL3NjaGVtYWlucHV0LnRzIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvc2NoZW1haW5wdXQvdGV4dGlucHV0LnRzIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvdGFidmlldy50cyIsIndlYnBhY2s6Ly9ZYW5jeS8uL25vZGVfbW9kdWxlcy9tYXJrZWQvbGliL21hcmtlZC5lc20uanMiLCJ3ZWJwYWNrOi8vWWFuY3kvd2VicGFjay9ib290c3RyYXAiLCJ3ZWJwYWNrOi8vWWFuY3kvd2VicGFjay9ydW50aW1lL2RlZmluZSBwcm9wZXJ0eSBnZXR0ZXJzIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svcnVudGltZS9oYXNPd25Qcm9wZXJ0eSBzaG9ydGhhbmQiLCJ3ZWJwYWNrOi8vWWFuY3kvd2VicGFjay9ydW50aW1lL21ha2UgbmFtZXNwYWNlIG9iamVjdCIsIndlYnBhY2s6Ly9ZYW5jeS8uL2xpYi9ZYW5jeS9yZXNvdXJjZXMvc3JjL2luZGV4LnRzIl0sInNvdXJjZXNDb250ZW50IjpbIi8vIE1vZHVsZVxudmFyIGNvZGUgPSBcIjxuYXY+XFxuICA8dWwgaWQ9XFxcInNjaGVtYS1saXN0XFxcIj5cXG4gIDwvdWw+XFxuPC9uYXY+XFxuPHRhYi12aWV3PlxcbjwvdGFiLXZpZXc+XFxuXCI7XG4vLyBFeHBvcnRzXG5leHBvcnQgZGVmYXVsdCBjb2RlOyIsIi8vIE1vZHVsZVxudmFyIGNvZGUgPSBcIjxzdHlsZT5cXG4jdGFiLXBhbmUgPiAqIHtcXG4gIGRpc3BsYXk6IG5vbmU7XFxufVxcbiN0YWItcGFuZSA+IC5hY3RpdmUge1xcbiAgZGlzcGxheTogYmxvY2s7XFxufVxcbjwvc3R5bGU+XFxuPGRpdj5cXG4gIDx1bCBpZD1cXFwidGFiLWJhclxcXCI+PC91bD5cXG4gIDxkaXYgaWQ9XFxcInRhYi1wYW5lXFxcIj48L2Rpdj5cXG48L2Rpdj5cXG5cIjtcbi8vIEV4cG9ydHNcbmV4cG9ydCBkZWZhdWx0IGNvZGU7IiwiXG5pbXBvcnQgVGFiVmlldyBmcm9tICcuL3RhYnZpZXcnO1xuaW1wb3J0IFNjaGVtYUZvcm0gZnJvbSAnLi9zY2hlbWFmb3JtJztcbmltcG9ydCBodG1sIGZyb20gJy4vZWRpdG9yLmh0bWwnO1xuZXhwb3J0IGRlZmF1bHQgY2xhc3MgRWRpdG9yIGV4dGVuZHMgSFRNTEVsZW1lbnQge1xuXG4gIHNjaGVtYTogYW55XG4gIGNvbnN0cnVjdG9yKCkge1xuICAgIHN1cGVyKCk7XG5cbiAgICB3aW5kb3cuY3VzdG9tRWxlbWVudHMuZGVmaW5lKCAndGFiLXZpZXcnLCBUYWJWaWV3ICk7XG4gICAgd2luZG93LmN1c3RvbUVsZW1lbnRzLmRlZmluZSggJ3NjaGVtYS1mb3JtJywgU2NoZW1hRm9ybSApO1xuICB9XG5cbiAgZ2V0IHRhYlZpZXcoKSB7XG4gICAgcmV0dXJuIHRoaXMucXVlcnlTZWxlY3RvcigndGFiLXZpZXcnKSBhcyBUYWJWaWV3O1xuICB9XG5cbiAgZ2V0IHNjaGVtYUxpc3QoKSB7XG4gICAgcmV0dXJuIHRoaXMucXVlcnlTZWxlY3RvcignI3NjaGVtYS1saXN0Jyk7XG4gIH1cblxuICBjb25uZWN0ZWRDYWxsYmFjaygpIHtcbiAgICB0aGlzLmlubmVySFRNTCA9IGh0bWwudHJpbSgpO1xuICAgIHRoaXMuc2NoZW1hTGlzdC5hZGRFdmVudExpc3RlbmVyKCdjbGljaycsIChlKSA9PiB0aGlzLmNsaWNrU2NoZW1hKGUpKTtcblxuICAgIC8vIFNob3cgd2VsY29tZSBwYW5lXG4gICAgbGV0IGhlbGxvID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZGl2Jyk7XG4gICAgaGVsbG8uYXBwZW5kQ2hpbGQoIGRvY3VtZW50LmNyZWF0ZVRleHROb2RlKCAnSGVsbG8sIFdvcmxkIScgKSApO1xuICAgIHRoaXMudGFiVmlldy5hZGRUYWIoXCJIZWxsb1wiLCBoZWxsbyk7XG5cbiAgICAvLyBBZGQgc2NoZW1hIGxpc3RcbiAgICBmb3IgKCBsZXQgc2NoZW1hTmFtZSBvZiBPYmplY3Qua2V5cyh0aGlzLnNjaGVtYSkuc29ydCgpICkge1xuICAgICAgbGV0IGxpID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggJ2xpJyApO1xuICAgICAgbGkuZGF0YXNldFtcInNjaGVtYVwiXSA9IHNjaGVtYU5hbWU7XG4gICAgICBsaS5hcHBlbmRDaGlsZCggZG9jdW1lbnQuY3JlYXRlVGV4dE5vZGUoIHNjaGVtYU5hbWUgKSApO1xuICAgICAgdGhpcy5zY2hlbWFMaXN0LmFwcGVuZENoaWxkKCBsaSApO1xuICAgIH1cbiAgfVxuXG4gIGNsaWNrU2NoZW1hKGU6RXZlbnQpIHtcbiAgICBsZXQgc2NoZW1hTmFtZSA9ICg8SFRNTEVsZW1lbnQ+ZS50YXJnZXQpLmRhdGFzZXRbXCJzY2hlbWFcIl07XG4gICAgLy8gRmluZCB0aGUgc2NoZW1hJ3MgdGFiIG9yIG9wZW4gb25lXG4gICAgaWYgKCB0aGlzLnRhYlZpZXcuc2hvd1RhYiggc2NoZW1hTmFtZSApICkge1xuICAgICAgcmV0dXJuO1xuICAgIH1cbiAgICBsZXQgZWRpdEZvcm0gPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCAnc2NoZW1hLWZvcm0nICkgYXMgU2NoZW1hRm9ybTtcbiAgICBlZGl0Rm9ybS5zY2hlbWEgPSB0aGlzLnNjaGVtYVsgc2NoZW1hTmFtZSBdO1xuICAgIHRoaXMudGFiVmlldy5hZGRUYWIoIHNjaGVtYU5hbWUsIGVkaXRGb3JtICk7XG4gIH1cbn1cblxuIiwiaW1wb3J0IHsgbWFya2VkIH0gZnJvbSAnbWFya2VkJztcbmltcG9ydCB7IFNjaGVtYVByb3BlcnR5IH0gZnJvbSAnLi9zY2hlbWEnXG5pbXBvcnQgeyBTY2hlbWFJbnB1dCwgU2NoZW1hSW5wdXRDbGFzcyB9IGZyb20gJy4vc2NoZW1haW5wdXQnO1xuXG5leHBvcnQgZGVmYXVsdCBjbGFzcyBTY2hlbWFGb3JtIGV4dGVuZHMgSFRNTEVsZW1lbnQge1xuXG4gIHN0YXRpYyBfaW5wdXRUeXBlczogeyBbaW5kZXg6IHN0cmluZ106IFNjaGVtYUlucHV0Q2xhc3MgfSA9IHt9O1xuICBzdGF0aWMgX2lucHV0T3JkZXI6IHN0cmluZ1tdID0gW107XG4gIF9zY2hlbWE6IE9iamVjdDtcbiAgX3Jvb3Q6IERvY3VtZW50RnJhZ21lbnQ7XG5cbiAgY29uc3RydWN0b3IoKSB7XG4gICAgc3VwZXIoKTtcbiAgICAvLyBUaGlzIGRvY3VtZW50IGZyYWdtZW50IGFsbG93cyB1cyB0byBidWlsZCB0aGUgZm9ybSBiZWZvcmVcbiAgICAvLyBhbnl0aGluZyBpcyBhZGRlZCB0byB0aGUgcGFnZSBET01cbiAgICB0aGlzLl9yb290ID0gZG9jdW1lbnQuY3JlYXRlRG9jdW1lbnRGcmFnbWVudCgpO1xuICB9XG5cbiAgc3RhdGljIGFkZElucHV0VHlwZSggZnQ6IFNjaGVtYUlucHV0Q2xhc3MgKSB7XG4gICAgY29uc3QgdGFnTmFtZSA9IGZ0LnJlZ2lzdGVyKCk7XG4gICAgU2NoZW1hRm9ybS5faW5wdXRPcmRlci51bnNoaWZ0KCB0YWdOYW1lICk7XG4gICAgU2NoZW1hRm9ybS5faW5wdXRUeXBlc1sgdGFnTmFtZSBdID0gZnQ7XG4gIH1cblxuICBzZXQgc2NoZW1hKG5ld1NjaGVtYTogYW55KSB7XG4gICAgaWYgKCB0aGlzLl9zY2hlbWEgKSB7XG4gICAgICAvLyBSZW1vdmUgZXhpc3RpbmcgaW5wdXRzXG4gICAgfVxuICAgIGlmICggbmV3U2NoZW1hLnByb3BlcnRpZXMgKSB7XG4gICAgICBmb3IgKCBjb25zdCBwcm9wTmFtZSBpbiBuZXdTY2hlbWEucHJvcGVydGllcyApIHtcbiAgICAgICAgY29uc3QgcHJvcCA9IG5ld1NjaGVtYS5wcm9wZXJ0aWVzWyBwcm9wTmFtZSBdO1xuICAgICAgICBjb25zdCBpbnB1dFRhZyA9IFNjaGVtYUZvcm0uX2lucHV0T3JkZXIuZmluZChcbiAgICAgICAgICB0YWdOYW1lID0+IFNjaGVtYUZvcm0uX2lucHV0VHlwZXNbIHRhZ05hbWUgXS5oYW5kbGVzKCBwcm9wIClcbiAgICAgICAgKTtcbiAgICAgICAgaWYgKCAhaW5wdXRUYWcgKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCBgQ291bGQgbm90IGZpbmQgaW5wdXQgdG8gaGFuZGxlIHByb3A6ICR7SlNPTi5zdHJpbmdpZnkocHJvcCl9YCApO1xuICAgICAgICB9XG4gICAgICAgIGNvbnN0IGlucHV0ID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggaW5wdXRUYWcgKSBhcyBTY2hlbWFJbnB1dDtcbiAgICAgICAgaW5wdXQuc2NoZW1hID0gcHJvcDtcbiAgICAgICAgaW5wdXQuc2V0QXR0cmlidXRlKCAnYXJpYS1sYWJlbGxlZGJ5JywgYGlucHV0LSR7cHJvcE5hbWV9LWxhYmVsYCApO1xuICAgICAgICBpbnB1dC5zZXRBdHRyaWJ1dGUoICdhcmlhLWRlc2NyaWJlZGJ5JywgYGlucHV0LSR7cHJvcE5hbWV9LWRlc2NgICk7XG4gICAgICAgIGlucHV0LnNldEF0dHJpYnV0ZSggJ2lkJywgYGlucHV0LSR7cHJvcE5hbWV9YCApO1xuXG4gICAgICAgIGNvbnN0IGZpZWxkID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggJ2RpdicgKTtcbiAgICAgICAgZmllbGQuc2V0QXR0cmlidXRlKCBcIm5hbWVcIiwgcHJvcE5hbWUgKTtcbiAgICAgICAgLy8gPGxhYmVsPlxuICAgICAgICBjb25zdCBsYWJlbCA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdsYWJlbCcgKTtcbiAgICAgICAgbGFiZWwuc2V0QXR0cmlidXRlKCAnaWQnLCBgaW5wdXQtJHtwcm9wTmFtZX0tbGFiZWxgICk7XG4gICAgICAgIGxhYmVsLnNldEF0dHJpYnV0ZSggJ2ZvcicsIGBpbnB1dC0ke3Byb3BOYW1lfWAgKTtcbiAgICAgICAgbGFiZWwuYXBwZW5kQ2hpbGQoIGRvY3VtZW50LmNyZWF0ZVRleHROb2RlKCBwcm9wLnRpdGxlIHx8IHByb3BOYW1lICkgKTtcbiAgICAgICAgLy8gU2luY2UgdGhlIGBmb3JgIGF0dHJpYnV0ZSBkb2Vzbid0IHBvaW50IHRvIGFuIGlucHV0IGVsZW1lbnQsXG4gICAgICAgIC8vIHRoZSBkZWZhdWx0IGZvY3VzIGJlaGF2aW9yIGRvZXNuJ3Qgd29yay4gSW5zdGVhZCwgd2UgaGF2ZSB0b1xuICAgICAgICAvLyBkbyBpdCBvdXJzZWx2ZXMuLi5cbiAgICAgICAgbGFiZWwuYWRkRXZlbnRMaXN0ZW5lcihcbiAgICAgICAgICAnY2xpY2snLFxuICAgICAgICAgIGV2ZW50ID0+IHtcbiAgICAgICAgICAgIGNvbnN0IGZpcnN0Rm9jdXNhYmxlRWxlbWVudCA9IGlucHV0LnF1ZXJ5U2VsZWN0b3IoICdpbnB1dCx0ZXh0YXJlYSxzZWxlY3QsW3RhYmluZGV4XScgKSBhcyBIVE1MRWxlbWVudDtcbiAgICAgICAgICAgIGZpcnN0Rm9jdXNhYmxlRWxlbWVudC5mb2N1cygpO1xuICAgICAgICAgICAgZXZlbnQucHJldmVudERlZmF1bHQoKTtcbiAgICAgICAgICB9LFxuICAgICAgICApO1xuICAgICAgICAvLyA8c21hbGw+IGZvciBkZXNjcmlwdGlvblxuICAgICAgICBjb25zdCBkZXNjID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggJ3NtYWxsJyApO1xuICAgICAgICBkZXNjLnNldEF0dHJpYnV0ZSggJ2lkJywgYGlucHV0LSR7cHJvcE5hbWV9LWRlc2NgICk7XG4gICAgICAgIGRlc2MuaW5uZXJIVE1MID0gbWFya2VkLnBhcnNlKCBwcm9wLmRlc2NyaXB0aW9uIHx8ICcnICk7XG4gICAgICAgIC8vIFhYWDogPGRpdj4gZm9yIHZhbGlkYXRpb24gZXJyb3JcblxuICAgICAgICAvLyBYWFg6IEhUTUwgc2hvdWxkIGJlIGZldGNoZWQgZnJvbSB0aGUgYXBwIGF0IHJ1bnRpbWUgc28gdGhhdFxuICAgICAgICAvLyBpdCBjYW4gYmUgb3ZlcnJpZGRlbiBieSB0aGUgdXNlci5cblxuICAgICAgICBmaWVsZC5hcHBlbmRDaGlsZCggbGFiZWwgKTtcbiAgICAgICAgZmllbGQuYXBwZW5kQ2hpbGQoIGlucHV0ICk7XG4gICAgICAgIGZpZWxkLmFwcGVuZENoaWxkKCBkZXNjICk7XG4gICAgICAgIHRoaXMuX3Jvb3QuYXBwZW5kQ2hpbGQoIGZpZWxkICk7XG4gICAgICB9XG4gICAgfVxuICAgIC8vIFhYWDogSGFuZGxlIGFycmF5IHR5cGVzXG4gICAgdGhpcy5fc2NoZW1hID0gbmV3U2NoZW1hO1xuICB9XG5cbiAgc2V0IHZhbHVlKG5ld1ZhbHVlOiBhbnkpIHtcbiAgICBmb3IgKCBsZXQgcHJvcE5hbWUgaW4gbmV3VmFsdWUgKSB7XG4gICAgICBsZXQgaW5wdXQgPSB0aGlzLnF1ZXJ5U2VsZWN0b3IoIGBbbmFtZT0ke3Byb3BOYW1lfV1gICkgYXMgU2NoZW1hSW5wdXQ7XG4gICAgICBpbnB1dC52YWx1ZSA9IG5ld1ZhbHVlWyBwcm9wTmFtZSBdO1xuICAgIH1cbiAgfVxuXG4gIGdldCB2YWx1ZSgpOiBhbnkge1xuICAgIGxldCB2YWwgPSB7fSBhcyBhbnk7XG4gICAgZm9yICggY29uc3QgZWwgb2YgdGhpcy5fcm9vdC5jaGlsZHJlbiApIHtcbiAgICAgIGNvbnN0IGlucHV0ID0gZWwgYXMgU2NoZW1hSW5wdXQ7XG4gICAgICB2YWxbIGlucHV0Lm5hbWUgXSA9IGlucHV0LnZhbHVlO1xuICAgIH1cbiAgICByZXR1cm4gdmFsO1xuICB9XG5cbiAgY29ubmVjdGVkQ2FsbGJhY2soKSB7XG4gICAgdGhpcy5hcHBlbmRDaGlsZCggdGhpcy5fcm9vdCApO1xuICB9XG5cbn1cblxuaW1wb3J0IFRleHRJbnB1dCBmcm9tICcuL3NjaGVtYWlucHV0L3RleHRpbnB1dCc7XG5TY2hlbWFGb3JtLmFkZElucHV0VHlwZSggVGV4dElucHV0ICk7XG5cbiIsImltcG9ydCB7IFNjaGVtYVByb3BlcnR5IH0gZnJvbSAnLi9zY2hlbWEnXG5cbmV4cG9ydCBhYnN0cmFjdCBjbGFzcyBTY2hlbWFJbnB1dCBleHRlbmRzIEhUTUxFbGVtZW50IHtcbiAgbmFtZTogc3RyaW5nO1xuICBhYnN0cmFjdCBzY2hlbWE6IFNjaGVtYVByb3BlcnR5O1xuICBhYnN0cmFjdCB2YWx1ZTogYW55O1xuICBzdGF0aWMgaGFuZGxlcyggaW5wdXQ6IFNjaGVtYVByb3BlcnR5ICk6IGJvb2xlYW4ge1xuICAgIHJldHVybiBmYWxzZTtcbiAgfVxufVxuXG5leHBvcnQgdHlwZSBTY2hlbWFJbnB1dENsYXNzID0ge1xuICBuZXcoIC4uLmFyZ3M6IGFueVtdICk6IFNjaGVtYUlucHV0O1xuICBoYW5kbGVzKGlucHV0OiBTY2hlbWFQcm9wZXJ0eSk6IGJvb2xlYW47XG4gIHJlZ2lzdGVyKCk6IHN0cmluZztcbn1cblxuIiwiaW1wb3J0IHsgU2NoZW1hUHJvcGVydHkgfSBmcm9tICcuLi9zY2hlbWEnXG5pbXBvcnQgeyBTY2hlbWFJbnB1dCwgU2NoZW1hSW5wdXRDbGFzcyB9IGZyb20gJy4uL3NjaGVtYWlucHV0JztcblxuZXhwb3J0IGRlZmF1bHQgY2xhc3MgVGV4dElucHV0IGV4dGVuZHMgU2NoZW1hSW5wdXQge1xuICBpbnB1dDogSFRNTElucHV0RWxlbWVudDtcblxuICBjb25zdHJ1Y3RvcigpIHtcbiAgICBzdXBlcigpO1xuICAgIHRoaXMuaW5wdXQgPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCAnaW5wdXQnICk7XG4gIH1cblxuICBnZXQgdmFsdWUoKTogYW55IHtcbiAgICByZXR1cm4gdGhpcy5pbnB1dC52YWx1ZTtcbiAgfVxuICBzZXQgdmFsdWUoIG5ld1ZhbHVlOiBhbnkgKSB7XG4gICAgdGhpcy5pbnB1dC52YWx1ZSA9IG5ld1ZhbHVlO1xuICB9XG5cbiAgc2V0IHNjaGVtYSggbmV3U2NoZW1hOiBTY2hlbWFQcm9wZXJ0eSApIHtcbiAgICBjb25zb2xlLmxvZyggXCJTZXR0aW5nIHNjaGVtYSBmb3IgdGV4dGlucHV0XCIsIG5ld1NjaGVtYSApO1xuICAgIGxldCBpbnB1dFR5cGUgPSAndGV4dCc7XG4gICAgbGV0IGlucHV0TW9kZSA9ICd0ZXh0JztcbiAgICBsZXQgcGF0dGVybiA9IG5ld1NjaGVtYS5wYXR0ZXJuO1xuXG4gICAgaWYgKCBuZXdTY2hlbWEudHlwZSA9PT0gJ3N0cmluZycgKSB7XG4gICAgICBpZiAoIG5ld1NjaGVtYS5mb3JtYXQgPT09ICdlbWFpbCcgKSB7XG4gICAgICAgIGlucHV0VHlwZSA9ICdlbWFpbCc7XG4gICAgICAgIGlucHV0TW9kZSA9ICdlbWFpbCc7XG4gICAgICB9XG4gICAgICBlbHNlIGlmICggbmV3U2NoZW1hLmZvcm1hdCA9PT0gJ3VybCcgKSB7XG4gICAgICAgIGlucHV0VHlwZSA9ICd1cmwnO1xuICAgICAgICBpbnB1dE1vZGUgPSAndXJsJztcbiAgICAgIH1cbiAgICAgIGVsc2UgaWYgKCBuZXdTY2hlbWEuZm9ybWF0ID09PSAndGVsJyApIHtcbiAgICAgICAgaW5wdXRUeXBlID0gJ3RlbCc7XG4gICAgICAgIGlucHV0TW9kZSA9ICd0ZWwnO1xuICAgICAgfVxuICAgIH1cbiAgICBlbHNlIGlmICggbmV3U2NoZW1hLnR5cGUgPT09ICdpbnRlZ2VyJyB8fCBuZXdTY2hlbWEudHlwZSA9PT0gJ251bWJlcicgKSB7XG4gICAgICBpbnB1dFR5cGUgPSAnbnVtYmVyJztcbiAgICAgIGlucHV0TW9kZSA9ICdkZWNpbWFsJztcbiAgICAgIGlmICggbmV3U2NoZW1hLnR5cGUgID09PSAnaW50ZWdlcicgKSB7XG4gICAgICAgIC8vIFVzZSBwYXR0ZXJuIHRvIHNob3cgbnVtZXJpYyBpbnB1dCBvbiBpT1NcbiAgICAgICAgLy8gaHR0cHM6Ly9jc3MtdHJpY2tzLmNvbS9maW5nZXItZnJpZW5kbHktbnVtZXJpY2FsLWlucHV0cy13aXRoLWlucHV0bW9kZS9cbiAgICAgICAgcGF0dGVybiA9IHBhdHRlcm4gfHwgJ1swLTldKic7XG4gICAgICAgIGlucHV0TW9kZSA9ICdudW1lcmljJztcbiAgICAgIH1cbiAgICB9XG5cbiAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ3R5cGUnLCBpbnB1dFR5cGUgKTtcbiAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ2lucHV0bW9kZScsIGlucHV0TW9kZSApO1xuICAgIGlmICggcGF0dGVybiApIHtcbiAgICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAncGF0dGVybicsIHBhdHRlcm4gKTtcbiAgICB9XG4gICAgaWYgKCBuZXdTY2hlbWEubWluTGVuZ3RoICkge1xuICAgICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICdtaW5sZW5ndGgnLCBuZXdTY2hlbWEubWluTGVuZ3RoLnRvU3RyaW5nKCkgKTtcbiAgICB9XG4gICAgaWYgKCBuZXdTY2hlbWEubWF4TGVuZ3RoICkge1xuICAgICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICdtYXhsZW5ndGgnLCBuZXdTY2hlbWEubWF4TGVuZ3RoLnRvU3RyaW5nKCkgKTtcbiAgICB9XG4gICAgaWYgKCBuZXdTY2hlbWEubWluaW11bSApIHtcbiAgICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAnbWluJywgbmV3U2NoZW1hLm1pbmltdW0udG9TdHJpbmcoKSApO1xuICAgIH1cbiAgICBpZiAoIG5ld1NjaGVtYS5tYXhpbXVtICkge1xuICAgICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICdtYXgnLCBuZXdTY2hlbWEubWF4aW11bS50b1N0cmluZygpICk7XG4gICAgfVxuICB9XG5cbiAgY29ubmVjdGVkQ2FsbGJhY2soKSB7XG4gICAgdGhpcy5hcHBlbmRDaGlsZCggdGhpcy5pbnB1dCApO1xuICB9XG5cbiAgc3RhdGljIGhhbmRsZXMoIGlucHV0OiBTY2hlbWFQcm9wZXJ0eSApOiBib29sZWFuIHtcbiAgICByZXR1cm4gdHJ1ZTtcbiAgfVxuXG4gIHN0YXRpYyByZWdpc3RlcigpOnN0cmluZyB7XG4gICAgY29uc3QgdGFnTmFtZSA9ICdzY2hlbWEtdGV4dC1pbnB1dCc7XG4gICAgd2luZG93LmN1c3RvbUVsZW1lbnRzLmRlZmluZSggdGFnTmFtZSwgVGV4dElucHV0ICk7XG4gICAgcmV0dXJuIHRhZ05hbWU7XG4gIH1cbn1cbiIsIlxuaW1wb3J0IGh0bWwgZnJvbSAnLi90YWJ2aWV3Lmh0bWwnO1xuZXhwb3J0IGRlZmF1bHQgY2xhc3MgVGFiVmlldyBleHRlbmRzIEhUTUxFbGVtZW50IHtcblxuICBnZXQgdGFiQmFyKCkge1xuICAgIHJldHVybiB0aGlzLnF1ZXJ5U2VsZWN0b3IoICcjdGFiLWJhcicgKTtcbiAgfVxuICBnZXQgdGFiUGFuZXMoKSB7XG4gICAgcmV0dXJuIHRoaXMucXVlcnlTZWxlY3RvciggJyN0YWItcGFuZScgKTtcbiAgfVxuICBnZXQgdGFicygpOiBBcnJheTxIVE1MRWxlbWVudD4ge1xuICAgIHJldHVybiBBcnJheS5mcm9tKHRoaXMudGFiQmFyLmNoaWxkcmVuKSBhcyBBcnJheTxIVE1MRWxlbWVudD47XG4gIH1cblxuICBjb25uZWN0ZWRDYWxsYmFjaygpIHtcbiAgICB0aGlzLmlubmVySFRNTCA9IGh0bWwudHJpbSgpO1xuICAgIHRoaXMudGFiQmFyLmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgKGUpID0+IHRoaXMuY2xpY2tUYWIoZSkpO1xuICB9XG5cbiAgYWRkVGFiKCBsYWJlbDogc3RyaW5nLCBjb250ZW50OiBIVE1MRWxlbWVudCApIHtcbiAgICBjb25zdCBsaSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdsaScgKTtcbiAgICBsaS5hcHBlbmRDaGlsZCggZG9jdW1lbnQuY3JlYXRlVGV4dE5vZGUoIGxhYmVsICkgKTtcbiAgICB0aGlzLnRhYkJhci5hcHBlbmRDaGlsZCggbGkgKTtcbiAgICB0aGlzLnRhYlBhbmVzLmFwcGVuZENoaWxkKCBjb250ZW50ICk7XG4gICAgdGhpcy5zaG93VGFiKGxhYmVsKTtcbiAgfVxuXG4gIHNob3dUYWIoIGxhYmVsOiBzdHJpbmcgKSA6IGJvb2xlYW4ge1xuICAgIGxldCBpZHggPSB0aGlzLnRhYnMuZmluZEluZGV4KCBlbCA9PiBlbC5pbm5lclRleHQgPT0gbGFiZWwgKTtcbiAgICBpZiAoIGlkeCA8IDAgKSB7XG4gICAgICBjb25zb2xlLmxvZyggYENvdWxkIG5vdCBmaW5kIHRhYiB3aXRoIGxhYmVsICR7bGFiZWx9YCApO1xuICAgICAgcmV0dXJuIGZhbHNlO1xuICAgIH1cbiAgICBpZiAoIHRoaXMudGFiQmFyLnF1ZXJ5U2VsZWN0b3IoICcuYWN0aXZlJyApICkge1xuICAgICAgdGhpcy50YWJCYXIucXVlcnlTZWxlY3RvciggJy5hY3RpdmUnICkuY2xhc3NMaXN0LnJlbW92ZSggJ2FjdGl2ZScgKTtcbiAgICAgIHRoaXMudGFiUGFuZXMucXVlcnlTZWxlY3RvciggJy5hY3RpdmUnICkuY2xhc3NMaXN0LnJlbW92ZSggJ2FjdGl2ZScgKTtcbiAgICB9XG4gICAgdGhpcy50YWJCYXIuY2hpbGRyZW5baWR4XS5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTtcbiAgICB0aGlzLnRhYlBhbmVzLmNoaWxkcmVuW2lkeF0uY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7XG4gICAgcmV0dXJuIHRydWU7XG4gIH1cblxuICBjbGlja1RhYiggZTogRXZlbnQgKSB7XG4gIH1cbn1cblxuIiwiLyoqXG4gKiBtYXJrZWQgLSBhIG1hcmtkb3duIHBhcnNlclxuICogQ29weXJpZ2h0IChjKSAyMDExLTIwMjEsIENocmlzdG9waGVyIEplZmZyZXkuIChNSVQgTGljZW5zZWQpXG4gKiBodHRwczovL2dpdGh1Yi5jb20vbWFya2VkanMvbWFya2VkXG4gKi9cblxuLyoqXG4gKiBETyBOT1QgRURJVCBUSElTIEZJTEVcbiAqIFRoZSBjb2RlIGluIHRoaXMgZmlsZSBpcyBnZW5lcmF0ZWQgZnJvbSBmaWxlcyBpbiAuL3NyYy9cbiAqL1xuXG5mdW5jdGlvbiBnZXREZWZhdWx0cygpIHtcbiAgcmV0dXJuIHtcbiAgICBiYXNlVXJsOiBudWxsLFxuICAgIGJyZWFrczogZmFsc2UsXG4gICAgZXh0ZW5zaW9uczogbnVsbCxcbiAgICBnZm06IHRydWUsXG4gICAgaGVhZGVySWRzOiB0cnVlLFxuICAgIGhlYWRlclByZWZpeDogJycsXG4gICAgaGlnaGxpZ2h0OiBudWxsLFxuICAgIGxhbmdQcmVmaXg6ICdsYW5ndWFnZS0nLFxuICAgIG1hbmdsZTogdHJ1ZSxcbiAgICBwZWRhbnRpYzogZmFsc2UsXG4gICAgcmVuZGVyZXI6IG51bGwsXG4gICAgc2FuaXRpemU6IGZhbHNlLFxuICAgIHNhbml0aXplcjogbnVsbCxcbiAgICBzaWxlbnQ6IGZhbHNlLFxuICAgIHNtYXJ0TGlzdHM6IGZhbHNlLFxuICAgIHNtYXJ0eXBhbnRzOiBmYWxzZSxcbiAgICB0b2tlbml6ZXI6IG51bGwsXG4gICAgd2Fsa1Rva2VuczogbnVsbCxcbiAgICB4aHRtbDogZmFsc2VcbiAgfTtcbn1cblxubGV0IGRlZmF1bHRzID0gZ2V0RGVmYXVsdHMoKTtcblxuZnVuY3Rpb24gY2hhbmdlRGVmYXVsdHMobmV3RGVmYXVsdHMpIHtcbiAgZGVmYXVsdHMgPSBuZXdEZWZhdWx0cztcbn1cblxuLyoqXG4gKiBIZWxwZXJzXG4gKi9cbmNvbnN0IGVzY2FwZVRlc3QgPSAvWyY8PlwiJ10vO1xuY29uc3QgZXNjYXBlUmVwbGFjZSA9IC9bJjw+XCInXS9nO1xuY29uc3QgZXNjYXBlVGVzdE5vRW5jb2RlID0gL1s8PlwiJ118Jig/ISM/XFx3KzspLztcbmNvbnN0IGVzY2FwZVJlcGxhY2VOb0VuY29kZSA9IC9bPD5cIiddfCYoPyEjP1xcdys7KS9nO1xuY29uc3QgZXNjYXBlUmVwbGFjZW1lbnRzID0ge1xuICAnJic6ICcmYW1wOycsXG4gICc8JzogJyZsdDsnLFxuICAnPic6ICcmZ3Q7JyxcbiAgJ1wiJzogJyZxdW90OycsXG4gIFwiJ1wiOiAnJiMzOTsnXG59O1xuY29uc3QgZ2V0RXNjYXBlUmVwbGFjZW1lbnQgPSAoY2gpID0+IGVzY2FwZVJlcGxhY2VtZW50c1tjaF07XG5mdW5jdGlvbiBlc2NhcGUoaHRtbCwgZW5jb2RlKSB7XG4gIGlmIChlbmNvZGUpIHtcbiAgICBpZiAoZXNjYXBlVGVzdC50ZXN0KGh0bWwpKSB7XG4gICAgICByZXR1cm4gaHRtbC5yZXBsYWNlKGVzY2FwZVJlcGxhY2UsIGdldEVzY2FwZVJlcGxhY2VtZW50KTtcbiAgICB9XG4gIH0gZWxzZSB7XG4gICAgaWYgKGVzY2FwZVRlc3ROb0VuY29kZS50ZXN0KGh0bWwpKSB7XG4gICAgICByZXR1cm4gaHRtbC5yZXBsYWNlKGVzY2FwZVJlcGxhY2VOb0VuY29kZSwgZ2V0RXNjYXBlUmVwbGFjZW1lbnQpO1xuICAgIH1cbiAgfVxuXG4gIHJldHVybiBodG1sO1xufVxuXG5jb25zdCB1bmVzY2FwZVRlc3QgPSAvJigjKD86XFxkKyl8KD86I3hbMC05QS1GYS1mXSspfCg/OlxcdyspKTs/L2lnO1xuXG5mdW5jdGlvbiB1bmVzY2FwZShodG1sKSB7XG4gIC8vIGV4cGxpY2l0bHkgbWF0Y2ggZGVjaW1hbCwgaGV4LCBhbmQgbmFtZWQgSFRNTCBlbnRpdGllc1xuICByZXR1cm4gaHRtbC5yZXBsYWNlKHVuZXNjYXBlVGVzdCwgKF8sIG4pID0+IHtcbiAgICBuID0gbi50b0xvd2VyQ2FzZSgpO1xuICAgIGlmIChuID09PSAnY29sb24nKSByZXR1cm4gJzonO1xuICAgIGlmIChuLmNoYXJBdCgwKSA9PT0gJyMnKSB7XG4gICAgICByZXR1cm4gbi5jaGFyQXQoMSkgPT09ICd4J1xuICAgICAgICA/IFN0cmluZy5mcm9tQ2hhckNvZGUocGFyc2VJbnQobi5zdWJzdHJpbmcoMiksIDE2KSlcbiAgICAgICAgOiBTdHJpbmcuZnJvbUNoYXJDb2RlKCtuLnN1YnN0cmluZygxKSk7XG4gICAgfVxuICAgIHJldHVybiAnJztcbiAgfSk7XG59XG5cbmNvbnN0IGNhcmV0ID0gLyhefFteXFxbXSlcXF4vZztcbmZ1bmN0aW9uIGVkaXQocmVnZXgsIG9wdCkge1xuICByZWdleCA9IHJlZ2V4LnNvdXJjZSB8fCByZWdleDtcbiAgb3B0ID0gb3B0IHx8ICcnO1xuICBjb25zdCBvYmogPSB7XG4gICAgcmVwbGFjZTogKG5hbWUsIHZhbCkgPT4ge1xuICAgICAgdmFsID0gdmFsLnNvdXJjZSB8fCB2YWw7XG4gICAgICB2YWwgPSB2YWwucmVwbGFjZShjYXJldCwgJyQxJyk7XG4gICAgICByZWdleCA9IHJlZ2V4LnJlcGxhY2UobmFtZSwgdmFsKTtcbiAgICAgIHJldHVybiBvYmo7XG4gICAgfSxcbiAgICBnZXRSZWdleDogKCkgPT4ge1xuICAgICAgcmV0dXJuIG5ldyBSZWdFeHAocmVnZXgsIG9wdCk7XG4gICAgfVxuICB9O1xuICByZXR1cm4gb2JqO1xufVxuXG5jb25zdCBub25Xb3JkQW5kQ29sb25UZXN0ID0gL1teXFx3Ol0vZztcbmNvbnN0IG9yaWdpbkluZGVwZW5kZW50VXJsID0gL14kfF5bYS16XVthLXowLTkrLi1dKjp8Xls/I10vaTtcbmZ1bmN0aW9uIGNsZWFuVXJsKHNhbml0aXplLCBiYXNlLCBocmVmKSB7XG4gIGlmIChzYW5pdGl6ZSkge1xuICAgIGxldCBwcm90O1xuICAgIHRyeSB7XG4gICAgICBwcm90ID0gZGVjb2RlVVJJQ29tcG9uZW50KHVuZXNjYXBlKGhyZWYpKVxuICAgICAgICAucmVwbGFjZShub25Xb3JkQW5kQ29sb25UZXN0LCAnJylcbiAgICAgICAgLnRvTG93ZXJDYXNlKCk7XG4gICAgfSBjYXRjaCAoZSkge1xuICAgICAgcmV0dXJuIG51bGw7XG4gICAgfVxuICAgIGlmIChwcm90LmluZGV4T2YoJ2phdmFzY3JpcHQ6JykgPT09IDAgfHwgcHJvdC5pbmRleE9mKCd2YnNjcmlwdDonKSA9PT0gMCB8fCBwcm90LmluZGV4T2YoJ2RhdGE6JykgPT09IDApIHtcbiAgICAgIHJldHVybiBudWxsO1xuICAgIH1cbiAgfVxuICBpZiAoYmFzZSAmJiAhb3JpZ2luSW5kZXBlbmRlbnRVcmwudGVzdChocmVmKSkge1xuICAgIGhyZWYgPSByZXNvbHZlVXJsKGJhc2UsIGhyZWYpO1xuICB9XG4gIHRyeSB7XG4gICAgaHJlZiA9IGVuY29kZVVSSShocmVmKS5yZXBsYWNlKC8lMjUvZywgJyUnKTtcbiAgfSBjYXRjaCAoZSkge1xuICAgIHJldHVybiBudWxsO1xuICB9XG4gIHJldHVybiBocmVmO1xufVxuXG5jb25zdCBiYXNlVXJscyA9IHt9O1xuY29uc3QganVzdERvbWFpbiA9IC9eW146XSs6XFwvKlteL10qJC87XG5jb25zdCBwcm90b2NvbCA9IC9eKFteOl0rOilbXFxzXFxTXSokLztcbmNvbnN0IGRvbWFpbiA9IC9eKFteOl0rOlxcLypbXi9dKilbXFxzXFxTXSokLztcblxuZnVuY3Rpb24gcmVzb2x2ZVVybChiYXNlLCBocmVmKSB7XG4gIGlmICghYmFzZVVybHNbJyAnICsgYmFzZV0pIHtcbiAgICAvLyB3ZSBjYW4gaWdub3JlIGV2ZXJ5dGhpbmcgaW4gYmFzZSBhZnRlciB0aGUgbGFzdCBzbGFzaCBvZiBpdHMgcGF0aCBjb21wb25lbnQsXG4gICAgLy8gYnV0IHdlIG1pZ2h0IG5lZWQgdG8gYWRkIF90aGF0X1xuICAgIC8vIGh0dHBzOi8vdG9vbHMuaWV0Zi5vcmcvaHRtbC9yZmMzOTg2I3NlY3Rpb24tM1xuICAgIGlmIChqdXN0RG9tYWluLnRlc3QoYmFzZSkpIHtcbiAgICAgIGJhc2VVcmxzWycgJyArIGJhc2VdID0gYmFzZSArICcvJztcbiAgICB9IGVsc2Uge1xuICAgICAgYmFzZVVybHNbJyAnICsgYmFzZV0gPSBydHJpbShiYXNlLCAnLycsIHRydWUpO1xuICAgIH1cbiAgfVxuICBiYXNlID0gYmFzZVVybHNbJyAnICsgYmFzZV07XG4gIGNvbnN0IHJlbGF0aXZlQmFzZSA9IGJhc2UuaW5kZXhPZignOicpID09PSAtMTtcblxuICBpZiAoaHJlZi5zdWJzdHJpbmcoMCwgMikgPT09ICcvLycpIHtcbiAgICBpZiAocmVsYXRpdmVCYXNlKSB7XG4gICAgICByZXR1cm4gaHJlZjtcbiAgICB9XG4gICAgcmV0dXJuIGJhc2UucmVwbGFjZShwcm90b2NvbCwgJyQxJykgKyBocmVmO1xuICB9IGVsc2UgaWYgKGhyZWYuY2hhckF0KDApID09PSAnLycpIHtcbiAgICBpZiAocmVsYXRpdmVCYXNlKSB7XG4gICAgICByZXR1cm4gaHJlZjtcbiAgICB9XG4gICAgcmV0dXJuIGJhc2UucmVwbGFjZShkb21haW4sICckMScpICsgaHJlZjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gYmFzZSArIGhyZWY7XG4gIH1cbn1cblxuY29uc3Qgbm9vcFRlc3QgPSB7IGV4ZWM6IGZ1bmN0aW9uIG5vb3BUZXN0KCkge30gfTtcblxuZnVuY3Rpb24gbWVyZ2Uob2JqKSB7XG4gIGxldCBpID0gMSxcbiAgICB0YXJnZXQsXG4gICAga2V5O1xuXG4gIGZvciAoOyBpIDwgYXJndW1lbnRzLmxlbmd0aDsgaSsrKSB7XG4gICAgdGFyZ2V0ID0gYXJndW1lbnRzW2ldO1xuICAgIGZvciAoa2V5IGluIHRhcmdldCkge1xuICAgICAgaWYgKE9iamVjdC5wcm90b3R5cGUuaGFzT3duUHJvcGVydHkuY2FsbCh0YXJnZXQsIGtleSkpIHtcbiAgICAgICAgb2JqW2tleV0gPSB0YXJnZXRba2V5XTtcbiAgICAgIH1cbiAgICB9XG4gIH1cblxuICByZXR1cm4gb2JqO1xufVxuXG5mdW5jdGlvbiBzcGxpdENlbGxzKHRhYmxlUm93LCBjb3VudCkge1xuICAvLyBlbnN1cmUgdGhhdCBldmVyeSBjZWxsLWRlbGltaXRpbmcgcGlwZSBoYXMgYSBzcGFjZVxuICAvLyBiZWZvcmUgaXQgdG8gZGlzdGluZ3Vpc2ggaXQgZnJvbSBhbiBlc2NhcGVkIHBpcGVcbiAgY29uc3Qgcm93ID0gdGFibGVSb3cucmVwbGFjZSgvXFx8L2csIChtYXRjaCwgb2Zmc2V0LCBzdHIpID0+IHtcbiAgICAgIGxldCBlc2NhcGVkID0gZmFsc2UsXG4gICAgICAgIGN1cnIgPSBvZmZzZXQ7XG4gICAgICB3aGlsZSAoLS1jdXJyID49IDAgJiYgc3RyW2N1cnJdID09PSAnXFxcXCcpIGVzY2FwZWQgPSAhZXNjYXBlZDtcbiAgICAgIGlmIChlc2NhcGVkKSB7XG4gICAgICAgIC8vIG9kZCBudW1iZXIgb2Ygc2xhc2hlcyBtZWFucyB8IGlzIGVzY2FwZWRcbiAgICAgICAgLy8gc28gd2UgbGVhdmUgaXQgYWxvbmVcbiAgICAgICAgcmV0dXJuICd8JztcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIC8vIGFkZCBzcGFjZSBiZWZvcmUgdW5lc2NhcGVkIHxcbiAgICAgICAgcmV0dXJuICcgfCc7XG4gICAgICB9XG4gICAgfSksXG4gICAgY2VsbHMgPSByb3cuc3BsaXQoLyBcXHwvKTtcbiAgbGV0IGkgPSAwO1xuXG4gIC8vIEZpcnN0L2xhc3QgY2VsbCBpbiBhIHJvdyBjYW5ub3QgYmUgZW1wdHkgaWYgaXQgaGFzIG5vIGxlYWRpbmcvdHJhaWxpbmcgcGlwZVxuICBpZiAoIWNlbGxzWzBdLnRyaW0oKSkgeyBjZWxscy5zaGlmdCgpOyB9XG4gIGlmICghY2VsbHNbY2VsbHMubGVuZ3RoIC0gMV0udHJpbSgpKSB7IGNlbGxzLnBvcCgpOyB9XG5cbiAgaWYgKGNlbGxzLmxlbmd0aCA+IGNvdW50KSB7XG4gICAgY2VsbHMuc3BsaWNlKGNvdW50KTtcbiAgfSBlbHNlIHtcbiAgICB3aGlsZSAoY2VsbHMubGVuZ3RoIDwgY291bnQpIGNlbGxzLnB1c2goJycpO1xuICB9XG5cbiAgZm9yICg7IGkgPCBjZWxscy5sZW5ndGg7IGkrKykge1xuICAgIC8vIGxlYWRpbmcgb3IgdHJhaWxpbmcgd2hpdGVzcGFjZSBpcyBpZ25vcmVkIHBlciB0aGUgZ2ZtIHNwZWNcbiAgICBjZWxsc1tpXSA9IGNlbGxzW2ldLnRyaW0oKS5yZXBsYWNlKC9cXFxcXFx8L2csICd8Jyk7XG4gIH1cbiAgcmV0dXJuIGNlbGxzO1xufVxuXG4vLyBSZW1vdmUgdHJhaWxpbmcgJ2Mncy4gRXF1aXZhbGVudCB0byBzdHIucmVwbGFjZSgvYyokLywgJycpLlxuLy8gL2MqJC8gaXMgdnVsbmVyYWJsZSB0byBSRURPUy5cbi8vIGludmVydDogUmVtb3ZlIHN1ZmZpeCBvZiBub24tYyBjaGFycyBpbnN0ZWFkLiBEZWZhdWx0IGZhbHNleS5cbmZ1bmN0aW9uIHJ0cmltKHN0ciwgYywgaW52ZXJ0KSB7XG4gIGNvbnN0IGwgPSBzdHIubGVuZ3RoO1xuICBpZiAobCA9PT0gMCkge1xuICAgIHJldHVybiAnJztcbiAgfVxuXG4gIC8vIExlbmd0aCBvZiBzdWZmaXggbWF0Y2hpbmcgdGhlIGludmVydCBjb25kaXRpb24uXG4gIGxldCBzdWZmTGVuID0gMDtcblxuICAvLyBTdGVwIGxlZnQgdW50aWwgd2UgZmFpbCB0byBtYXRjaCB0aGUgaW52ZXJ0IGNvbmRpdGlvbi5cbiAgd2hpbGUgKHN1ZmZMZW4gPCBsKSB7XG4gICAgY29uc3QgY3VyckNoYXIgPSBzdHIuY2hhckF0KGwgLSBzdWZmTGVuIC0gMSk7XG4gICAgaWYgKGN1cnJDaGFyID09PSBjICYmICFpbnZlcnQpIHtcbiAgICAgIHN1ZmZMZW4rKztcbiAgICB9IGVsc2UgaWYgKGN1cnJDaGFyICE9PSBjICYmIGludmVydCkge1xuICAgICAgc3VmZkxlbisrO1xuICAgIH0gZWxzZSB7XG4gICAgICBicmVhaztcbiAgICB9XG4gIH1cblxuICByZXR1cm4gc3RyLnN1YnN0cigwLCBsIC0gc3VmZkxlbik7XG59XG5cbmZ1bmN0aW9uIGZpbmRDbG9zaW5nQnJhY2tldChzdHIsIGIpIHtcbiAgaWYgKHN0ci5pbmRleE9mKGJbMV0pID09PSAtMSkge1xuICAgIHJldHVybiAtMTtcbiAgfVxuICBjb25zdCBsID0gc3RyLmxlbmd0aDtcbiAgbGV0IGxldmVsID0gMCxcbiAgICBpID0gMDtcbiAgZm9yICg7IGkgPCBsOyBpKyspIHtcbiAgICBpZiAoc3RyW2ldID09PSAnXFxcXCcpIHtcbiAgICAgIGkrKztcbiAgICB9IGVsc2UgaWYgKHN0cltpXSA9PT0gYlswXSkge1xuICAgICAgbGV2ZWwrKztcbiAgICB9IGVsc2UgaWYgKHN0cltpXSA9PT0gYlsxXSkge1xuICAgICAgbGV2ZWwtLTtcbiAgICAgIGlmIChsZXZlbCA8IDApIHtcbiAgICAgICAgcmV0dXJuIGk7XG4gICAgICB9XG4gICAgfVxuICB9XG4gIHJldHVybiAtMTtcbn1cblxuZnVuY3Rpb24gY2hlY2tTYW5pdGl6ZURlcHJlY2F0aW9uKG9wdCkge1xuICBpZiAob3B0ICYmIG9wdC5zYW5pdGl6ZSAmJiAhb3B0LnNpbGVudCkge1xuICAgIGNvbnNvbGUud2FybignbWFya2VkKCk6IHNhbml0aXplIGFuZCBzYW5pdGl6ZXIgcGFyYW1ldGVycyBhcmUgZGVwcmVjYXRlZCBzaW5jZSB2ZXJzaW9uIDAuNy4wLCBzaG91bGQgbm90IGJlIHVzZWQgYW5kIHdpbGwgYmUgcmVtb3ZlZCBpbiB0aGUgZnV0dXJlLiBSZWFkIG1vcmUgaGVyZTogaHR0cHM6Ly9tYXJrZWQuanMub3JnLyMvVVNJTkdfQURWQU5DRUQubWQjb3B0aW9ucycpO1xuICB9XG59XG5cbi8vIGNvcGllZCBmcm9tIGh0dHBzOi8vc3RhY2tvdmVyZmxvdy5jb20vYS81NDUwMTEzLzgwNjc3N1xuZnVuY3Rpb24gcmVwZWF0U3RyaW5nKHBhdHRlcm4sIGNvdW50KSB7XG4gIGlmIChjb3VudCA8IDEpIHtcbiAgICByZXR1cm4gJyc7XG4gIH1cbiAgbGV0IHJlc3VsdCA9ICcnO1xuICB3aGlsZSAoY291bnQgPiAxKSB7XG4gICAgaWYgKGNvdW50ICYgMSkge1xuICAgICAgcmVzdWx0ICs9IHBhdHRlcm47XG4gICAgfVxuICAgIGNvdW50ID4+PSAxO1xuICAgIHBhdHRlcm4gKz0gcGF0dGVybjtcbiAgfVxuICByZXR1cm4gcmVzdWx0ICsgcGF0dGVybjtcbn1cblxuZnVuY3Rpb24gb3V0cHV0TGluayhjYXAsIGxpbmssIHJhdywgbGV4ZXIpIHtcbiAgY29uc3QgaHJlZiA9IGxpbmsuaHJlZjtcbiAgY29uc3QgdGl0bGUgPSBsaW5rLnRpdGxlID8gZXNjYXBlKGxpbmsudGl0bGUpIDogbnVsbDtcbiAgY29uc3QgdGV4dCA9IGNhcFsxXS5yZXBsYWNlKC9cXFxcKFtcXFtcXF1dKS9nLCAnJDEnKTtcblxuICBpZiAoY2FwWzBdLmNoYXJBdCgwKSAhPT0gJyEnKSB7XG4gICAgbGV4ZXIuc3RhdGUuaW5MaW5rID0gdHJ1ZTtcbiAgICBjb25zdCB0b2tlbiA9IHtcbiAgICAgIHR5cGU6ICdsaW5rJyxcbiAgICAgIHJhdyxcbiAgICAgIGhyZWYsXG4gICAgICB0aXRsZSxcbiAgICAgIHRleHQsXG4gICAgICB0b2tlbnM6IGxleGVyLmlubGluZVRva2Vucyh0ZXh0LCBbXSlcbiAgICB9O1xuICAgIGxleGVyLnN0YXRlLmluTGluayA9IGZhbHNlO1xuICAgIHJldHVybiB0b2tlbjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4ge1xuICAgICAgdHlwZTogJ2ltYWdlJyxcbiAgICAgIHJhdyxcbiAgICAgIGhyZWYsXG4gICAgICB0aXRsZSxcbiAgICAgIHRleHQ6IGVzY2FwZSh0ZXh0KVxuICAgIH07XG4gIH1cbn1cblxuZnVuY3Rpb24gaW5kZW50Q29kZUNvbXBlbnNhdGlvbihyYXcsIHRleHQpIHtcbiAgY29uc3QgbWF0Y2hJbmRlbnRUb0NvZGUgPSByYXcubWF0Y2goL14oXFxzKykoPzpgYGApLyk7XG5cbiAgaWYgKG1hdGNoSW5kZW50VG9Db2RlID09PSBudWxsKSB7XG4gICAgcmV0dXJuIHRleHQ7XG4gIH1cblxuICBjb25zdCBpbmRlbnRUb0NvZGUgPSBtYXRjaEluZGVudFRvQ29kZVsxXTtcblxuICByZXR1cm4gdGV4dFxuICAgIC5zcGxpdCgnXFxuJylcbiAgICAubWFwKG5vZGUgPT4ge1xuICAgICAgY29uc3QgbWF0Y2hJbmRlbnRJbk5vZGUgPSBub2RlLm1hdGNoKC9eXFxzKy8pO1xuICAgICAgaWYgKG1hdGNoSW5kZW50SW5Ob2RlID09PSBudWxsKSB7XG4gICAgICAgIHJldHVybiBub2RlO1xuICAgICAgfVxuXG4gICAgICBjb25zdCBbaW5kZW50SW5Ob2RlXSA9IG1hdGNoSW5kZW50SW5Ob2RlO1xuXG4gICAgICBpZiAoaW5kZW50SW5Ob2RlLmxlbmd0aCA+PSBpbmRlbnRUb0NvZGUubGVuZ3RoKSB7XG4gICAgICAgIHJldHVybiBub2RlLnNsaWNlKGluZGVudFRvQ29kZS5sZW5ndGgpO1xuICAgICAgfVxuXG4gICAgICByZXR1cm4gbm9kZTtcbiAgICB9KVxuICAgIC5qb2luKCdcXG4nKTtcbn1cblxuLyoqXG4gKiBUb2tlbml6ZXJcbiAqL1xuY2xhc3MgVG9rZW5pemVyIHtcbiAgY29uc3RydWN0b3Iob3B0aW9ucykge1xuICAgIHRoaXMub3B0aW9ucyA9IG9wdGlvbnMgfHwgZGVmYXVsdHM7XG4gIH1cblxuICBzcGFjZShzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLm5ld2xpbmUuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGlmIChjYXBbMF0ubGVuZ3RoID4gMSkge1xuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgIHR5cGU6ICdzcGFjZScsXG4gICAgICAgICAgcmF3OiBjYXBbMF1cbiAgICAgICAgfTtcbiAgICAgIH1cbiAgICAgIHJldHVybiB7IHJhdzogJ1xcbicgfTtcbiAgICB9XG4gIH1cblxuICBjb2RlKHNyYykge1xuICAgIGNvbnN0IGNhcCA9IHRoaXMucnVsZXMuYmxvY2suY29kZS5leGVjKHNyYyk7XG4gICAgaWYgKGNhcCkge1xuICAgICAgY29uc3QgdGV4dCA9IGNhcFswXS5yZXBsYWNlKC9eIHsxLDR9L2dtLCAnJyk7XG4gICAgICByZXR1cm4ge1xuICAgICAgICB0eXBlOiAnY29kZScsXG4gICAgICAgIHJhdzogY2FwWzBdLFxuICAgICAgICBjb2RlQmxvY2tTdHlsZTogJ2luZGVudGVkJyxcbiAgICAgICAgdGV4dDogIXRoaXMub3B0aW9ucy5wZWRhbnRpY1xuICAgICAgICAgID8gcnRyaW0odGV4dCwgJ1xcbicpXG4gICAgICAgICAgOiB0ZXh0XG4gICAgICB9O1xuICAgIH1cbiAgfVxuXG4gIGZlbmNlcyhzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLmZlbmNlcy5leGVjKHNyYyk7XG4gICAgaWYgKGNhcCkge1xuICAgICAgY29uc3QgcmF3ID0gY2FwWzBdO1xuICAgICAgY29uc3QgdGV4dCA9IGluZGVudENvZGVDb21wZW5zYXRpb24ocmF3LCBjYXBbM10gfHwgJycpO1xuXG4gICAgICByZXR1cm4ge1xuICAgICAgICB0eXBlOiAnY29kZScsXG4gICAgICAgIHJhdyxcbiAgICAgICAgbGFuZzogY2FwWzJdID8gY2FwWzJdLnRyaW0oKSA6IGNhcFsyXSxcbiAgICAgICAgdGV4dFxuICAgICAgfTtcbiAgICB9XG4gIH1cblxuICBoZWFkaW5nKHNyYykge1xuICAgIGNvbnN0IGNhcCA9IHRoaXMucnVsZXMuYmxvY2suaGVhZGluZy5leGVjKHNyYyk7XG4gICAgaWYgKGNhcCkge1xuICAgICAgbGV0IHRleHQgPSBjYXBbMl0udHJpbSgpO1xuXG4gICAgICAvLyByZW1vdmUgdHJhaWxpbmcgI3NcbiAgICAgIGlmICgvIyQvLnRlc3QodGV4dCkpIHtcbiAgICAgICAgY29uc3QgdHJpbW1lZCA9IHJ0cmltKHRleHQsICcjJyk7XG4gICAgICAgIGlmICh0aGlzLm9wdGlvbnMucGVkYW50aWMpIHtcbiAgICAgICAgICB0ZXh0ID0gdHJpbW1lZC50cmltKCk7XG4gICAgICAgIH0gZWxzZSBpZiAoIXRyaW1tZWQgfHwgLyAkLy50ZXN0KHRyaW1tZWQpKSB7XG4gICAgICAgICAgLy8gQ29tbW9uTWFyayByZXF1aXJlcyBzcGFjZSBiZWZvcmUgdHJhaWxpbmcgI3NcbiAgICAgICAgICB0ZXh0ID0gdHJpbW1lZC50cmltKCk7XG4gICAgICAgIH1cbiAgICAgIH1cblxuICAgICAgY29uc3QgdG9rZW4gPSB7XG4gICAgICAgIHR5cGU6ICdoZWFkaW5nJyxcbiAgICAgICAgcmF3OiBjYXBbMF0sXG4gICAgICAgIGRlcHRoOiBjYXBbMV0ubGVuZ3RoLFxuICAgICAgICB0ZXh0OiB0ZXh0LFxuICAgICAgICB0b2tlbnM6IFtdXG4gICAgICB9O1xuICAgICAgdGhpcy5sZXhlci5pbmxpbmUodG9rZW4udGV4dCwgdG9rZW4udG9rZW5zKTtcbiAgICAgIHJldHVybiB0b2tlbjtcbiAgICB9XG4gIH1cblxuICBocihzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLmhyLmV4ZWMoc3JjKTtcbiAgICBpZiAoY2FwKSB7XG4gICAgICByZXR1cm4ge1xuICAgICAgICB0eXBlOiAnaHInLFxuICAgICAgICByYXc6IGNhcFswXVxuICAgICAgfTtcbiAgICB9XG4gIH1cblxuICBibG9ja3F1b3RlKHNyYykge1xuICAgIGNvbnN0IGNhcCA9IHRoaXMucnVsZXMuYmxvY2suYmxvY2txdW90ZS5leGVjKHNyYyk7XG4gICAgaWYgKGNhcCkge1xuICAgICAgY29uc3QgdGV4dCA9IGNhcFswXS5yZXBsYWNlKC9eICo+ID8vZ20sICcnKTtcblxuICAgICAgcmV0dXJuIHtcbiAgICAgICAgdHlwZTogJ2Jsb2NrcXVvdGUnLFxuICAgICAgICByYXc6IGNhcFswXSxcbiAgICAgICAgdG9rZW5zOiB0aGlzLmxleGVyLmJsb2NrVG9rZW5zKHRleHQsIFtdKSxcbiAgICAgICAgdGV4dFxuICAgICAgfTtcbiAgICB9XG4gIH1cblxuICBsaXN0KHNyYykge1xuICAgIGxldCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLmxpc3QuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGxldCByYXcsIGlzdGFzaywgaXNjaGVja2VkLCBpbmRlbnQsIGksIGJsYW5rTGluZSwgZW5kc1dpdGhCbGFua0xpbmUsXG4gICAgICAgIGxpbmUsIGxpbmVzLCBpdGVtQ29udGVudHM7XG5cbiAgICAgIGxldCBidWxsID0gY2FwWzFdLnRyaW0oKTtcbiAgICAgIGNvbnN0IGlzb3JkZXJlZCA9IGJ1bGwubGVuZ3RoID4gMTtcblxuICAgICAgY29uc3QgbGlzdCA9IHtcbiAgICAgICAgdHlwZTogJ2xpc3QnLFxuICAgICAgICByYXc6ICcnLFxuICAgICAgICBvcmRlcmVkOiBpc29yZGVyZWQsXG4gICAgICAgIHN0YXJ0OiBpc29yZGVyZWQgPyArYnVsbC5zbGljZSgwLCAtMSkgOiAnJyxcbiAgICAgICAgbG9vc2U6IGZhbHNlLFxuICAgICAgICBpdGVtczogW11cbiAgICAgIH07XG5cbiAgICAgIGJ1bGwgPSBpc29yZGVyZWQgPyBgXFxcXGR7MSw5fVxcXFwke2J1bGwuc2xpY2UoLTEpfWAgOiBgXFxcXCR7YnVsbH1gO1xuXG4gICAgICBpZiAodGhpcy5vcHRpb25zLnBlZGFudGljKSB7XG4gICAgICAgIGJ1bGwgPSBpc29yZGVyZWQgPyBidWxsIDogJ1sqKy1dJztcbiAgICAgIH1cblxuICAgICAgLy8gR2V0IG5leHQgbGlzdCBpdGVtXG4gICAgICBjb25zdCBpdGVtUmVnZXggPSBuZXcgUmVnRXhwKGBeKCB7MCwzfSR7YnVsbH0pKCg/OiBbXlxcXFxuXSp8ICopKD86XFxcXG5bXlxcXFxuXSopKig/OlxcXFxufCQpKWApO1xuXG4gICAgICAvLyBHZXQgZWFjaCB0b3AtbGV2ZWwgaXRlbVxuICAgICAgd2hpbGUgKHNyYykge1xuICAgICAgICBpZiAodGhpcy5ydWxlcy5ibG9jay5oci50ZXN0KHNyYykpIHsgLy8gRW5kIGxpc3QgaWYgd2UgZW5jb3VudGVyIGFuIEhSIChwb3NzaWJseSBtb3ZlIGludG8gaXRlbVJlZ2V4PylcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfVxuXG4gICAgICAgIGlmICghKGNhcCA9IGl0ZW1SZWdleC5leGVjKHNyYykpKSB7XG4gICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cblxuICAgICAgICBsaW5lcyA9IGNhcFsyXS5zcGxpdCgnXFxuJyk7XG5cbiAgICAgICAgaWYgKHRoaXMub3B0aW9ucy5wZWRhbnRpYykge1xuICAgICAgICAgIGluZGVudCA9IDI7XG4gICAgICAgICAgaXRlbUNvbnRlbnRzID0gbGluZXNbMF0udHJpbUxlZnQoKTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBpbmRlbnQgPSBjYXBbMl0uc2VhcmNoKC9bXiBdLyk7IC8vIEZpbmQgZmlyc3Qgbm9uLXNwYWNlIGNoYXJcbiAgICAgICAgICBpbmRlbnQgPSBjYXBbMV0ubGVuZ3RoICsgKGluZGVudCA+IDQgPyAxIDogaW5kZW50KTsgLy8gaW50ZW50ZWQgY29kZSBibG9ja3MgYWZ0ZXIgNCBzcGFjZXM7IGluZGVudCBpcyBhbHdheXMgMVxuICAgICAgICAgIGl0ZW1Db250ZW50cyA9IGxpbmVzWzBdLnNsaWNlKGluZGVudCAtIGNhcFsxXS5sZW5ndGgpO1xuICAgICAgICB9XG5cbiAgICAgICAgYmxhbmtMaW5lID0gZmFsc2U7XG4gICAgICAgIHJhdyA9IGNhcFswXTtcblxuICAgICAgICBpZiAoIWxpbmVzWzBdICYmIC9eICokLy50ZXN0KGxpbmVzWzFdKSkgeyAvLyBpdGVtcyBiZWdpbiB3aXRoIGF0IG1vc3Qgb25lIGJsYW5rIGxpbmVcbiAgICAgICAgICByYXcgPSBjYXBbMV0gKyBsaW5lcy5zbGljZSgwLCAyKS5qb2luKCdcXG4nKSArICdcXG4nO1xuICAgICAgICAgIGxpc3QubG9vc2UgPSB0cnVlO1xuICAgICAgICAgIGxpbmVzID0gW107XG4gICAgICAgIH1cblxuICAgICAgICBjb25zdCBuZXh0QnVsbGV0UmVnZXggPSBuZXcgUmVnRXhwKGBeIHswLCR7TWF0aC5taW4oMywgaW5kZW50IC0gMSl9fSg/OlsqKy1dfFxcXFxkezEsOX1bLildKWApO1xuXG4gICAgICAgIGZvciAoaSA9IDE7IGkgPCBsaW5lcy5sZW5ndGg7IGkrKykge1xuICAgICAgICAgIGxpbmUgPSBsaW5lc1tpXTtcblxuICAgICAgICAgIGlmICh0aGlzLm9wdGlvbnMucGVkYW50aWMpIHsgLy8gUmUtYWxpZ24gdG8gZm9sbG93IGNvbW1vbm1hcmsgbmVzdGluZyBydWxlc1xuICAgICAgICAgICAgbGluZSA9IGxpbmUucmVwbGFjZSgvXiB7MSw0fSg/PSggezR9KSpbXiBdKS9nLCAnICAnKTtcbiAgICAgICAgICB9XG5cbiAgICAgICAgICAvLyBFbmQgbGlzdCBpdGVtIGlmIGZvdW5kIHN0YXJ0IG9mIG5ldyBidWxsZXRcbiAgICAgICAgICBpZiAobmV4dEJ1bGxldFJlZ2V4LnRlc3QobGluZSkpIHtcbiAgICAgICAgICAgIHJhdyA9IGNhcFsxXSArIGxpbmVzLnNsaWNlKDAsIGkpLmpvaW4oJ1xcbicpICsgJ1xcbic7XG4gICAgICAgICAgICBicmVhaztcbiAgICAgICAgICB9XG5cbiAgICAgICAgICAvLyBVbnRpbCB3ZSBlbmNvdW50ZXIgYSBibGFuayBsaW5lLCBpdGVtIGNvbnRlbnRzIGRvIG5vdCBuZWVkIGluZGVudGF0aW9uXG4gICAgICAgICAgaWYgKCFibGFua0xpbmUpIHtcbiAgICAgICAgICAgIGlmICghbGluZS50cmltKCkpIHsgLy8gQ2hlY2sgaWYgY3VycmVudCBsaW5lIGlzIGVtcHR5XG4gICAgICAgICAgICAgIGJsYW5rTGluZSA9IHRydWU7XG4gICAgICAgICAgICB9XG5cbiAgICAgICAgICAgIC8vIERlZGVudCBpZiBwb3NzaWJsZVxuICAgICAgICAgICAgaWYgKGxpbmUuc2VhcmNoKC9bXiBdLykgPj0gaW5kZW50KSB7XG4gICAgICAgICAgICAgIGl0ZW1Db250ZW50cyArPSAnXFxuJyArIGxpbmUuc2xpY2UoaW5kZW50KTtcbiAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgIGl0ZW1Db250ZW50cyArPSAnXFxuJyArIGxpbmU7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICB9XG5cbiAgICAgICAgICAvLyBEZWRlbnQgdGhpcyBsaW5lXG4gICAgICAgICAgaWYgKGxpbmUuc2VhcmNoKC9bXiBdLykgPj0gaW5kZW50IHx8ICFsaW5lLnRyaW0oKSkge1xuICAgICAgICAgICAgaXRlbUNvbnRlbnRzICs9ICdcXG4nICsgbGluZS5zbGljZShpbmRlbnQpO1xuICAgICAgICAgICAgY29udGludWU7XG4gICAgICAgICAgfSBlbHNlIHsgLy8gTGluZSB3YXMgbm90IHByb3Blcmx5IGluZGVudGVkOyBlbmQgb2YgdGhpcyBpdGVtXG4gICAgICAgICAgICByYXcgPSBjYXBbMV0gKyBsaW5lcy5zbGljZSgwLCBpKS5qb2luKCdcXG4nKSArICdcXG4nO1xuICAgICAgICAgICAgYnJlYWs7XG4gICAgICAgICAgfVxuICAgICAgICB9XG5cbiAgICAgICAgaWYgKCFsaXN0Lmxvb3NlKSB7XG4gICAgICAgICAgLy8gSWYgdGhlIHByZXZpb3VzIGl0ZW0gZW5kZWQgd2l0aCBhIGJsYW5rIGxpbmUsIHRoZSBsaXN0IGlzIGxvb3NlXG4gICAgICAgICAgaWYgKGVuZHNXaXRoQmxhbmtMaW5lKSB7XG4gICAgICAgICAgICBsaXN0Lmxvb3NlID0gdHJ1ZTtcbiAgICAgICAgICB9IGVsc2UgaWYgKC9cXG4gKlxcbiAqJC8udGVzdChyYXcpKSB7XG4gICAgICAgICAgICBlbmRzV2l0aEJsYW5rTGluZSA9IHRydWU7XG4gICAgICAgICAgfVxuICAgICAgICB9XG5cbiAgICAgICAgLy8gQ2hlY2sgZm9yIHRhc2sgbGlzdCBpdGVtc1xuICAgICAgICBpZiAodGhpcy5vcHRpb25zLmdmbSkge1xuICAgICAgICAgIGlzdGFzayA9IC9eXFxbWyB4WF1cXF0gLy5leGVjKGl0ZW1Db250ZW50cyk7XG4gICAgICAgICAgaWYgKGlzdGFzaykge1xuICAgICAgICAgICAgaXNjaGVja2VkID0gaXN0YXNrWzBdICE9PSAnWyBdICc7XG4gICAgICAgICAgICBpdGVtQ29udGVudHMgPSBpdGVtQ29udGVudHMucmVwbGFjZSgvXlxcW1sgeFhdXFxdICsvLCAnJyk7XG4gICAgICAgICAgfVxuICAgICAgICB9XG5cbiAgICAgICAgbGlzdC5pdGVtcy5wdXNoKHtcbiAgICAgICAgICB0eXBlOiAnbGlzdF9pdGVtJyxcbiAgICAgICAgICByYXc6IHJhdyxcbiAgICAgICAgICB0YXNrOiAhIWlzdGFzayxcbiAgICAgICAgICBjaGVja2VkOiBpc2NoZWNrZWQsXG4gICAgICAgICAgbG9vc2U6IGZhbHNlLFxuICAgICAgICAgIHRleHQ6IGl0ZW1Db250ZW50c1xuICAgICAgICB9KTtcblxuICAgICAgICBsaXN0LnJhdyArPSByYXc7XG4gICAgICAgIHNyYyA9IHNyYy5zbGljZShyYXcubGVuZ3RoKTtcbiAgICAgIH1cblxuICAgICAgLy8gRG8gbm90IGNvbnN1bWUgbmV3bGluZXMgYXQgZW5kIG9mIGZpbmFsIGl0ZW0uIEFsdGVybmF0aXZlbHksIG1ha2UgaXRlbVJlZ2V4ICpzdGFydCogd2l0aCBhbnkgbmV3bGluZXMgdG8gc2ltcGxpZnkvc3BlZWQgdXAgZW5kc1dpdGhCbGFua0xpbmUgbG9naWNcbiAgICAgIGxpc3QuaXRlbXNbbGlzdC5pdGVtcy5sZW5ndGggLSAxXS5yYXcgPSByYXcudHJpbVJpZ2h0KCk7XG4gICAgICBsaXN0Lml0ZW1zW2xpc3QuaXRlbXMubGVuZ3RoIC0gMV0udGV4dCA9IGl0ZW1Db250ZW50cy50cmltUmlnaHQoKTtcbiAgICAgIGxpc3QucmF3ID0gbGlzdC5yYXcudHJpbVJpZ2h0KCk7XG5cbiAgICAgIGNvbnN0IGwgPSBsaXN0Lml0ZW1zLmxlbmd0aDtcblxuICAgICAgLy8gSXRlbSBjaGlsZCB0b2tlbnMgaGFuZGxlZCBoZXJlIGF0IGVuZCBiZWNhdXNlIHdlIG5lZWRlZCB0byBoYXZlIHRoZSBmaW5hbCBpdGVtIHRvIHRyaW0gaXQgZmlyc3RcbiAgICAgIGZvciAoaSA9IDA7IGkgPCBsOyBpKyspIHtcbiAgICAgICAgdGhpcy5sZXhlci5zdGF0ZS50b3AgPSBmYWxzZTtcbiAgICAgICAgbGlzdC5pdGVtc1tpXS50b2tlbnMgPSB0aGlzLmxleGVyLmJsb2NrVG9rZW5zKGxpc3QuaXRlbXNbaV0udGV4dCwgW10pO1xuICAgICAgICBpZiAobGlzdC5pdGVtc1tpXS50b2tlbnMuc29tZSh0ID0+IHQudHlwZSA9PT0gJ3NwYWNlJykpIHtcbiAgICAgICAgICBsaXN0Lmxvb3NlID0gdHJ1ZTtcbiAgICAgICAgICBsaXN0Lml0ZW1zW2ldLmxvb3NlID0gdHJ1ZTtcbiAgICAgICAgfVxuICAgICAgfVxuXG4gICAgICByZXR1cm4gbGlzdDtcbiAgICB9XG4gIH1cblxuICBodG1sKHNyYykge1xuICAgIGNvbnN0IGNhcCA9IHRoaXMucnVsZXMuYmxvY2suaHRtbC5leGVjKHNyYyk7XG4gICAgaWYgKGNhcCkge1xuICAgICAgY29uc3QgdG9rZW4gPSB7XG4gICAgICAgIHR5cGU6ICdodG1sJyxcbiAgICAgICAgcmF3OiBjYXBbMF0sXG4gICAgICAgIHByZTogIXRoaXMub3B0aW9ucy5zYW5pdGl6ZXJcbiAgICAgICAgICAmJiAoY2FwWzFdID09PSAncHJlJyB8fCBjYXBbMV0gPT09ICdzY3JpcHQnIHx8IGNhcFsxXSA9PT0gJ3N0eWxlJyksXG4gICAgICAgIHRleHQ6IGNhcFswXVxuICAgICAgfTtcbiAgICAgIGlmICh0aGlzLm9wdGlvbnMuc2FuaXRpemUpIHtcbiAgICAgICAgdG9rZW4udHlwZSA9ICdwYXJhZ3JhcGgnO1xuICAgICAgICB0b2tlbi50ZXh0ID0gdGhpcy5vcHRpb25zLnNhbml0aXplciA/IHRoaXMub3B0aW9ucy5zYW5pdGl6ZXIoY2FwWzBdKSA6IGVzY2FwZShjYXBbMF0pO1xuICAgICAgICB0b2tlbi50b2tlbnMgPSBbXTtcbiAgICAgICAgdGhpcy5sZXhlci5pbmxpbmUodG9rZW4udGV4dCwgdG9rZW4udG9rZW5zKTtcbiAgICAgIH1cbiAgICAgIHJldHVybiB0b2tlbjtcbiAgICB9XG4gIH1cblxuICBkZWYoc3JjKSB7XG4gICAgY29uc3QgY2FwID0gdGhpcy5ydWxlcy5ibG9jay5kZWYuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGlmIChjYXBbM10pIGNhcFszXSA9IGNhcFszXS5zdWJzdHJpbmcoMSwgY2FwWzNdLmxlbmd0aCAtIDEpO1xuICAgICAgY29uc3QgdGFnID0gY2FwWzFdLnRvTG93ZXJDYXNlKCkucmVwbGFjZSgvXFxzKy9nLCAnICcpO1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgdHlwZTogJ2RlZicsXG4gICAgICAgIHRhZyxcbiAgICAgICAgcmF3OiBjYXBbMF0sXG4gICAgICAgIGhyZWY6IGNhcFsyXSxcbiAgICAgICAgdGl0bGU6IGNhcFszXVxuICAgICAgfTtcbiAgICB9XG4gIH1cblxuICB0YWJsZShzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLnRhYmxlLmV4ZWMoc3JjKTtcbiAgICBpZiAoY2FwKSB7XG4gICAgICBjb25zdCBpdGVtID0ge1xuICAgICAgICB0eXBlOiAndGFibGUnLFxuICAgICAgICBoZWFkZXI6IHNwbGl0Q2VsbHMoY2FwWzFdKS5tYXAoYyA9PiB7IHJldHVybiB7IHRleHQ6IGMgfTsgfSksXG4gICAgICAgIGFsaWduOiBjYXBbMl0ucmVwbGFjZSgvXiAqfFxcfCAqJC9nLCAnJykuc3BsaXQoLyAqXFx8ICovKSxcbiAgICAgICAgcm93czogY2FwWzNdID8gY2FwWzNdLnJlcGxhY2UoL1xcbiQvLCAnJykuc3BsaXQoJ1xcbicpIDogW11cbiAgICAgIH07XG5cbiAgICAgIGlmIChpdGVtLmhlYWRlci5sZW5ndGggPT09IGl0ZW0uYWxpZ24ubGVuZ3RoKSB7XG4gICAgICAgIGl0ZW0ucmF3ID0gY2FwWzBdO1xuXG4gICAgICAgIGxldCBsID0gaXRlbS5hbGlnbi5sZW5ndGg7XG4gICAgICAgIGxldCBpLCBqLCBrLCByb3c7XG4gICAgICAgIGZvciAoaSA9IDA7IGkgPCBsOyBpKyspIHtcbiAgICAgICAgICBpZiAoL14gKi0rOiAqJC8udGVzdChpdGVtLmFsaWduW2ldKSkge1xuICAgICAgICAgICAgaXRlbS5hbGlnbltpXSA9ICdyaWdodCc7XG4gICAgICAgICAgfSBlbHNlIGlmICgvXiAqOi0rOiAqJC8udGVzdChpdGVtLmFsaWduW2ldKSkge1xuICAgICAgICAgICAgaXRlbS5hbGlnbltpXSA9ICdjZW50ZXInO1xuICAgICAgICAgIH0gZWxzZSBpZiAoL14gKjotKyAqJC8udGVzdChpdGVtLmFsaWduW2ldKSkge1xuICAgICAgICAgICAgaXRlbS5hbGlnbltpXSA9ICdsZWZ0JztcbiAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgaXRlbS5hbGlnbltpXSA9IG51bGw7XG4gICAgICAgICAgfVxuICAgICAgICB9XG5cbiAgICAgICAgbCA9IGl0ZW0ucm93cy5sZW5ndGg7XG4gICAgICAgIGZvciAoaSA9IDA7IGkgPCBsOyBpKyspIHtcbiAgICAgICAgICBpdGVtLnJvd3NbaV0gPSBzcGxpdENlbGxzKGl0ZW0ucm93c1tpXSwgaXRlbS5oZWFkZXIubGVuZ3RoKS5tYXAoYyA9PiB7IHJldHVybiB7IHRleHQ6IGMgfTsgfSk7XG4gICAgICAgIH1cblxuICAgICAgICAvLyBwYXJzZSBjaGlsZCB0b2tlbnMgaW5zaWRlIGhlYWRlcnMgYW5kIGNlbGxzXG5cbiAgICAgICAgLy8gaGVhZGVyIGNoaWxkIHRva2Vuc1xuICAgICAgICBsID0gaXRlbS5oZWFkZXIubGVuZ3RoO1xuICAgICAgICBmb3IgKGogPSAwOyBqIDwgbDsgaisrKSB7XG4gICAgICAgICAgaXRlbS5oZWFkZXJbal0udG9rZW5zID0gW107XG4gICAgICAgICAgdGhpcy5sZXhlci5pbmxpbmVUb2tlbnMoaXRlbS5oZWFkZXJbal0udGV4dCwgaXRlbS5oZWFkZXJbal0udG9rZW5zKTtcbiAgICAgICAgfVxuXG4gICAgICAgIC8vIGNlbGwgY2hpbGQgdG9rZW5zXG4gICAgICAgIGwgPSBpdGVtLnJvd3MubGVuZ3RoO1xuICAgICAgICBmb3IgKGogPSAwOyBqIDwgbDsgaisrKSB7XG4gICAgICAgICAgcm93ID0gaXRlbS5yb3dzW2pdO1xuICAgICAgICAgIGZvciAoayA9IDA7IGsgPCByb3cubGVuZ3RoOyBrKyspIHtcbiAgICAgICAgICAgIHJvd1trXS50b2tlbnMgPSBbXTtcbiAgICAgICAgICAgIHRoaXMubGV4ZXIuaW5saW5lVG9rZW5zKHJvd1trXS50ZXh0LCByb3dba10udG9rZW5zKTtcbiAgICAgICAgICB9XG4gICAgICAgIH1cblxuICAgICAgICByZXR1cm4gaXRlbTtcbiAgICAgIH1cbiAgICB9XG4gIH1cblxuICBsaGVhZGluZyhzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLmxoZWFkaW5nLmV4ZWMoc3JjKTtcbiAgICBpZiAoY2FwKSB7XG4gICAgICBjb25zdCB0b2tlbiA9IHtcbiAgICAgICAgdHlwZTogJ2hlYWRpbmcnLFxuICAgICAgICByYXc6IGNhcFswXSxcbiAgICAgICAgZGVwdGg6IGNhcFsyXS5jaGFyQXQoMCkgPT09ICc9JyA/IDEgOiAyLFxuICAgICAgICB0ZXh0OiBjYXBbMV0sXG4gICAgICAgIHRva2VuczogW11cbiAgICAgIH07XG4gICAgICB0aGlzLmxleGVyLmlubGluZSh0b2tlbi50ZXh0LCB0b2tlbi50b2tlbnMpO1xuICAgICAgcmV0dXJuIHRva2VuO1xuICAgIH1cbiAgfVxuXG4gIHBhcmFncmFwaChzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmJsb2NrLnBhcmFncmFwaC5leGVjKHNyYyk7XG4gICAgaWYgKGNhcCkge1xuICAgICAgY29uc3QgdG9rZW4gPSB7XG4gICAgICAgIHR5cGU6ICdwYXJhZ3JhcGgnLFxuICAgICAgICByYXc6IGNhcFswXSxcbiAgICAgICAgdGV4dDogY2FwWzFdLmNoYXJBdChjYXBbMV0ubGVuZ3RoIC0gMSkgPT09ICdcXG4nXG4gICAgICAgICAgPyBjYXBbMV0uc2xpY2UoMCwgLTEpXG4gICAgICAgICAgOiBjYXBbMV0sXG4gICAgICAgIHRva2VuczogW11cbiAgICAgIH07XG4gICAgICB0aGlzLmxleGVyLmlubGluZSh0b2tlbi50ZXh0LCB0b2tlbi50b2tlbnMpO1xuICAgICAgcmV0dXJuIHRva2VuO1xuICAgIH1cbiAgfVxuXG4gIHRleHQoc3JjKSB7XG4gICAgY29uc3QgY2FwID0gdGhpcy5ydWxlcy5ibG9jay50ZXh0LmV4ZWMoc3JjKTtcbiAgICBpZiAoY2FwKSB7XG4gICAgICBjb25zdCB0b2tlbiA9IHtcbiAgICAgICAgdHlwZTogJ3RleHQnLFxuICAgICAgICByYXc6IGNhcFswXSxcbiAgICAgICAgdGV4dDogY2FwWzBdLFxuICAgICAgICB0b2tlbnM6IFtdXG4gICAgICB9O1xuICAgICAgdGhpcy5sZXhlci5pbmxpbmUodG9rZW4udGV4dCwgdG9rZW4udG9rZW5zKTtcbiAgICAgIHJldHVybiB0b2tlbjtcbiAgICB9XG4gIH1cblxuICBlc2NhcGUoc3JjKSB7XG4gICAgY29uc3QgY2FwID0gdGhpcy5ydWxlcy5pbmxpbmUuZXNjYXBlLmV4ZWMoc3JjKTtcbiAgICBpZiAoY2FwKSB7XG4gICAgICByZXR1cm4ge1xuICAgICAgICB0eXBlOiAnZXNjYXBlJyxcbiAgICAgICAgcmF3OiBjYXBbMF0sXG4gICAgICAgIHRleHQ6IGVzY2FwZShjYXBbMV0pXG4gICAgICB9O1xuICAgIH1cbiAgfVxuXG4gIHRhZyhzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmlubGluZS50YWcuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGlmICghdGhpcy5sZXhlci5zdGF0ZS5pbkxpbmsgJiYgL148YSAvaS50ZXN0KGNhcFswXSkpIHtcbiAgICAgICAgdGhpcy5sZXhlci5zdGF0ZS5pbkxpbmsgPSB0cnVlO1xuICAgICAgfSBlbHNlIGlmICh0aGlzLmxleGVyLnN0YXRlLmluTGluayAmJiAvXjxcXC9hPi9pLnRlc3QoY2FwWzBdKSkge1xuICAgICAgICB0aGlzLmxleGVyLnN0YXRlLmluTGluayA9IGZhbHNlO1xuICAgICAgfVxuICAgICAgaWYgKCF0aGlzLmxleGVyLnN0YXRlLmluUmF3QmxvY2sgJiYgL148KHByZXxjb2RlfGtiZHxzY3JpcHQpKFxcc3w+KS9pLnRlc3QoY2FwWzBdKSkge1xuICAgICAgICB0aGlzLmxleGVyLnN0YXRlLmluUmF3QmxvY2sgPSB0cnVlO1xuICAgICAgfSBlbHNlIGlmICh0aGlzLmxleGVyLnN0YXRlLmluUmF3QmxvY2sgJiYgL148XFwvKHByZXxjb2RlfGtiZHxzY3JpcHQpKFxcc3w+KS9pLnRlc3QoY2FwWzBdKSkge1xuICAgICAgICB0aGlzLmxleGVyLnN0YXRlLmluUmF3QmxvY2sgPSBmYWxzZTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIHtcbiAgICAgICAgdHlwZTogdGhpcy5vcHRpb25zLnNhbml0aXplXG4gICAgICAgICAgPyAndGV4dCdcbiAgICAgICAgICA6ICdodG1sJyxcbiAgICAgICAgcmF3OiBjYXBbMF0sXG4gICAgICAgIGluTGluazogdGhpcy5sZXhlci5zdGF0ZS5pbkxpbmssXG4gICAgICAgIGluUmF3QmxvY2s6IHRoaXMubGV4ZXIuc3RhdGUuaW5SYXdCbG9jayxcbiAgICAgICAgdGV4dDogdGhpcy5vcHRpb25zLnNhbml0aXplXG4gICAgICAgICAgPyAodGhpcy5vcHRpb25zLnNhbml0aXplclxuICAgICAgICAgICAgPyB0aGlzLm9wdGlvbnMuc2FuaXRpemVyKGNhcFswXSlcbiAgICAgICAgICAgIDogZXNjYXBlKGNhcFswXSkpXG4gICAgICAgICAgOiBjYXBbMF1cbiAgICAgIH07XG4gICAgfVxuICB9XG5cbiAgbGluayhzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmlubGluZS5saW5rLmV4ZWMoc3JjKTtcbiAgICBpZiAoY2FwKSB7XG4gICAgICBjb25zdCB0cmltbWVkVXJsID0gY2FwWzJdLnRyaW0oKTtcbiAgICAgIGlmICghdGhpcy5vcHRpb25zLnBlZGFudGljICYmIC9ePC8udGVzdCh0cmltbWVkVXJsKSkge1xuICAgICAgICAvLyBjb21tb25tYXJrIHJlcXVpcmVzIG1hdGNoaW5nIGFuZ2xlIGJyYWNrZXRzXG4gICAgICAgIGlmICghKC8+JC8udGVzdCh0cmltbWVkVXJsKSkpIHtcbiAgICAgICAgICByZXR1cm47XG4gICAgICAgIH1cblxuICAgICAgICAvLyBlbmRpbmcgYW5nbGUgYnJhY2tldCBjYW5ub3QgYmUgZXNjYXBlZFxuICAgICAgICBjb25zdCBydHJpbVNsYXNoID0gcnRyaW0odHJpbW1lZFVybC5zbGljZSgwLCAtMSksICdcXFxcJyk7XG4gICAgICAgIGlmICgodHJpbW1lZFVybC5sZW5ndGggLSBydHJpbVNsYXNoLmxlbmd0aCkgJSAyID09PSAwKSB7XG4gICAgICAgICAgcmV0dXJuO1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICAvLyBmaW5kIGNsb3NpbmcgcGFyZW50aGVzaXNcbiAgICAgICAgY29uc3QgbGFzdFBhcmVuSW5kZXggPSBmaW5kQ2xvc2luZ0JyYWNrZXQoY2FwWzJdLCAnKCknKTtcbiAgICAgICAgaWYgKGxhc3RQYXJlbkluZGV4ID4gLTEpIHtcbiAgICAgICAgICBjb25zdCBzdGFydCA9IGNhcFswXS5pbmRleE9mKCchJykgPT09IDAgPyA1IDogNDtcbiAgICAgICAgICBjb25zdCBsaW5rTGVuID0gc3RhcnQgKyBjYXBbMV0ubGVuZ3RoICsgbGFzdFBhcmVuSW5kZXg7XG4gICAgICAgICAgY2FwWzJdID0gY2FwWzJdLnN1YnN0cmluZygwLCBsYXN0UGFyZW5JbmRleCk7XG4gICAgICAgICAgY2FwWzBdID0gY2FwWzBdLnN1YnN0cmluZygwLCBsaW5rTGVuKS50cmltKCk7XG4gICAgICAgICAgY2FwWzNdID0gJyc7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICAgIGxldCBocmVmID0gY2FwWzJdO1xuICAgICAgbGV0IHRpdGxlID0gJyc7XG4gICAgICBpZiAodGhpcy5vcHRpb25zLnBlZGFudGljKSB7XG4gICAgICAgIC8vIHNwbGl0IHBlZGFudGljIGhyZWYgYW5kIHRpdGxlXG4gICAgICAgIGNvbnN0IGxpbmsgPSAvXihbXidcIl0qW15cXHNdKVxccysoWydcIl0pKC4qKVxcMi8uZXhlYyhocmVmKTtcblxuICAgICAgICBpZiAobGluaykge1xuICAgICAgICAgIGhyZWYgPSBsaW5rWzFdO1xuICAgICAgICAgIHRpdGxlID0gbGlua1szXTtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIHtcbiAgICAgICAgdGl0bGUgPSBjYXBbM10gPyBjYXBbM10uc2xpY2UoMSwgLTEpIDogJyc7XG4gICAgICB9XG5cbiAgICAgIGhyZWYgPSBocmVmLnRyaW0oKTtcbiAgICAgIGlmICgvXjwvLnRlc3QoaHJlZikpIHtcbiAgICAgICAgaWYgKHRoaXMub3B0aW9ucy5wZWRhbnRpYyAmJiAhKC8+JC8udGVzdCh0cmltbWVkVXJsKSkpIHtcbiAgICAgICAgICAvLyBwZWRhbnRpYyBhbGxvd3Mgc3RhcnRpbmcgYW5nbGUgYnJhY2tldCB3aXRob3V0IGVuZGluZyBhbmdsZSBicmFja2V0XG4gICAgICAgICAgaHJlZiA9IGhyZWYuc2xpY2UoMSk7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgaHJlZiA9IGhyZWYuc2xpY2UoMSwgLTEpO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgICByZXR1cm4gb3V0cHV0TGluayhjYXAsIHtcbiAgICAgICAgaHJlZjogaHJlZiA/IGhyZWYucmVwbGFjZSh0aGlzLnJ1bGVzLmlubGluZS5fZXNjYXBlcywgJyQxJykgOiBocmVmLFxuICAgICAgICB0aXRsZTogdGl0bGUgPyB0aXRsZS5yZXBsYWNlKHRoaXMucnVsZXMuaW5saW5lLl9lc2NhcGVzLCAnJDEnKSA6IHRpdGxlXG4gICAgICB9LCBjYXBbMF0sIHRoaXMubGV4ZXIpO1xuICAgIH1cbiAgfVxuXG4gIHJlZmxpbmsoc3JjLCBsaW5rcykge1xuICAgIGxldCBjYXA7XG4gICAgaWYgKChjYXAgPSB0aGlzLnJ1bGVzLmlubGluZS5yZWZsaW5rLmV4ZWMoc3JjKSlcbiAgICAgICAgfHwgKGNhcCA9IHRoaXMucnVsZXMuaW5saW5lLm5vbGluay5leGVjKHNyYykpKSB7XG4gICAgICBsZXQgbGluayA9IChjYXBbMl0gfHwgY2FwWzFdKS5yZXBsYWNlKC9cXHMrL2csICcgJyk7XG4gICAgICBsaW5rID0gbGlua3NbbGluay50b0xvd2VyQ2FzZSgpXTtcbiAgICAgIGlmICghbGluayB8fCAhbGluay5ocmVmKSB7XG4gICAgICAgIGNvbnN0IHRleHQgPSBjYXBbMF0uY2hhckF0KDApO1xuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgIHR5cGU6ICd0ZXh0JyxcbiAgICAgICAgICByYXc6IHRleHQsXG4gICAgICAgICAgdGV4dFxuICAgICAgICB9O1xuICAgICAgfVxuICAgICAgcmV0dXJuIG91dHB1dExpbmsoY2FwLCBsaW5rLCBjYXBbMF0sIHRoaXMubGV4ZXIpO1xuICAgIH1cbiAgfVxuXG4gIGVtU3Ryb25nKHNyYywgbWFza2VkU3JjLCBwcmV2Q2hhciA9ICcnKSB7XG4gICAgbGV0IG1hdGNoID0gdGhpcy5ydWxlcy5pbmxpbmUuZW1TdHJvbmcubERlbGltLmV4ZWMoc3JjKTtcbiAgICBpZiAoIW1hdGNoKSByZXR1cm47XG5cbiAgICAvLyBfIGNhbid0IGJlIGJldHdlZW4gdHdvIGFscGhhbnVtZXJpY3MuIFxccHtMfVxccHtOfSBpbmNsdWRlcyBub24tZW5nbGlzaCBhbHBoYWJldC9udW1iZXJzIGFzIHdlbGxcbiAgICBpZiAobWF0Y2hbM10gJiYgcHJldkNoYXIubWF0Y2goL1tcXHB7TH1cXHB7Tn1dL3UpKSByZXR1cm47XG5cbiAgICBjb25zdCBuZXh0Q2hhciA9IG1hdGNoWzFdIHx8IG1hdGNoWzJdIHx8ICcnO1xuXG4gICAgaWYgKCFuZXh0Q2hhciB8fCAobmV4dENoYXIgJiYgKHByZXZDaGFyID09PSAnJyB8fCB0aGlzLnJ1bGVzLmlubGluZS5wdW5jdHVhdGlvbi5leGVjKHByZXZDaGFyKSkpKSB7XG4gICAgICBjb25zdCBsTGVuZ3RoID0gbWF0Y2hbMF0ubGVuZ3RoIC0gMTtcbiAgICAgIGxldCByRGVsaW0sIHJMZW5ndGgsIGRlbGltVG90YWwgPSBsTGVuZ3RoLCBtaWREZWxpbVRvdGFsID0gMDtcblxuICAgICAgY29uc3QgZW5kUmVnID0gbWF0Y2hbMF1bMF0gPT09ICcqJyA/IHRoaXMucnVsZXMuaW5saW5lLmVtU3Ryb25nLnJEZWxpbUFzdCA6IHRoaXMucnVsZXMuaW5saW5lLmVtU3Ryb25nLnJEZWxpbVVuZDtcbiAgICAgIGVuZFJlZy5sYXN0SW5kZXggPSAwO1xuXG4gICAgICAvLyBDbGlwIG1hc2tlZFNyYyB0byBzYW1lIHNlY3Rpb24gb2Ygc3RyaW5nIGFzIHNyYyAobW92ZSB0byBsZXhlcj8pXG4gICAgICBtYXNrZWRTcmMgPSBtYXNrZWRTcmMuc2xpY2UoLTEgKiBzcmMubGVuZ3RoICsgbExlbmd0aCk7XG5cbiAgICAgIHdoaWxlICgobWF0Y2ggPSBlbmRSZWcuZXhlYyhtYXNrZWRTcmMpKSAhPSBudWxsKSB7XG4gICAgICAgIHJEZWxpbSA9IG1hdGNoWzFdIHx8IG1hdGNoWzJdIHx8IG1hdGNoWzNdIHx8IG1hdGNoWzRdIHx8IG1hdGNoWzVdIHx8IG1hdGNoWzZdO1xuXG4gICAgICAgIGlmICghckRlbGltKSBjb250aW51ZTsgLy8gc2tpcCBzaW5nbGUgKiBpbiBfX2FiYyphYmNfX1xuXG4gICAgICAgIHJMZW5ndGggPSByRGVsaW0ubGVuZ3RoO1xuXG4gICAgICAgIGlmIChtYXRjaFszXSB8fCBtYXRjaFs0XSkgeyAvLyBmb3VuZCBhbm90aGVyIExlZnQgRGVsaW1cbiAgICAgICAgICBkZWxpbVRvdGFsICs9IHJMZW5ndGg7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH0gZWxzZSBpZiAobWF0Y2hbNV0gfHwgbWF0Y2hbNl0pIHsgLy8gZWl0aGVyIExlZnQgb3IgUmlnaHQgRGVsaW1cbiAgICAgICAgICBpZiAobExlbmd0aCAlIDMgJiYgISgobExlbmd0aCArIHJMZW5ndGgpICUgMykpIHtcbiAgICAgICAgICAgIG1pZERlbGltVG90YWwgKz0gckxlbmd0aDtcbiAgICAgICAgICAgIGNvbnRpbnVlOyAvLyBDb21tb25NYXJrIEVtcGhhc2lzIFJ1bGVzIDktMTBcbiAgICAgICAgICB9XG4gICAgICAgIH1cblxuICAgICAgICBkZWxpbVRvdGFsIC09IHJMZW5ndGg7XG5cbiAgICAgICAgaWYgKGRlbGltVG90YWwgPiAwKSBjb250aW51ZTsgLy8gSGF2ZW4ndCBmb3VuZCBlbm91Z2ggY2xvc2luZyBkZWxpbWl0ZXJzXG5cbiAgICAgICAgLy8gUmVtb3ZlIGV4dHJhIGNoYXJhY3RlcnMuICphKioqIC0+ICphKlxuICAgICAgICByTGVuZ3RoID0gTWF0aC5taW4ockxlbmd0aCwgckxlbmd0aCArIGRlbGltVG90YWwgKyBtaWREZWxpbVRvdGFsKTtcblxuICAgICAgICAvLyBDcmVhdGUgYGVtYCBpZiBzbWFsbGVzdCBkZWxpbWl0ZXIgaGFzIG9kZCBjaGFyIGNvdW50LiAqYSoqKlxuICAgICAgICBpZiAoTWF0aC5taW4obExlbmd0aCwgckxlbmd0aCkgJSAyKSB7XG4gICAgICAgICAgY29uc3QgdGV4dCA9IHNyYy5zbGljZSgxLCBsTGVuZ3RoICsgbWF0Y2guaW5kZXggKyByTGVuZ3RoKTtcbiAgICAgICAgICByZXR1cm4ge1xuICAgICAgICAgICAgdHlwZTogJ2VtJyxcbiAgICAgICAgICAgIHJhdzogc3JjLnNsaWNlKDAsIGxMZW5ndGggKyBtYXRjaC5pbmRleCArIHJMZW5ndGggKyAxKSxcbiAgICAgICAgICAgIHRleHQsXG4gICAgICAgICAgICB0b2tlbnM6IHRoaXMubGV4ZXIuaW5saW5lVG9rZW5zKHRleHQsIFtdKVxuICAgICAgICAgIH07XG4gICAgICAgIH1cblxuICAgICAgICAvLyBDcmVhdGUgJ3N0cm9uZycgaWYgc21hbGxlc3QgZGVsaW1pdGVyIGhhcyBldmVuIGNoYXIgY291bnQuICoqYSoqKlxuICAgICAgICBjb25zdCB0ZXh0ID0gc3JjLnNsaWNlKDIsIGxMZW5ndGggKyBtYXRjaC5pbmRleCArIHJMZW5ndGggLSAxKTtcbiAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICB0eXBlOiAnc3Ryb25nJyxcbiAgICAgICAgICByYXc6IHNyYy5zbGljZSgwLCBsTGVuZ3RoICsgbWF0Y2guaW5kZXggKyByTGVuZ3RoICsgMSksXG4gICAgICAgICAgdGV4dCxcbiAgICAgICAgICB0b2tlbnM6IHRoaXMubGV4ZXIuaW5saW5lVG9rZW5zKHRleHQsIFtdKVxuICAgICAgICB9O1xuICAgICAgfVxuICAgIH1cbiAgfVxuXG4gIGNvZGVzcGFuKHNyYykge1xuICAgIGNvbnN0IGNhcCA9IHRoaXMucnVsZXMuaW5saW5lLmNvZGUuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGxldCB0ZXh0ID0gY2FwWzJdLnJlcGxhY2UoL1xcbi9nLCAnICcpO1xuICAgICAgY29uc3QgaGFzTm9uU3BhY2VDaGFycyA9IC9bXiBdLy50ZXN0KHRleHQpO1xuICAgICAgY29uc3QgaGFzU3BhY2VDaGFyc09uQm90aEVuZHMgPSAvXiAvLnRlc3QodGV4dCkgJiYgLyAkLy50ZXN0KHRleHQpO1xuICAgICAgaWYgKGhhc05vblNwYWNlQ2hhcnMgJiYgaGFzU3BhY2VDaGFyc09uQm90aEVuZHMpIHtcbiAgICAgICAgdGV4dCA9IHRleHQuc3Vic3RyaW5nKDEsIHRleHQubGVuZ3RoIC0gMSk7XG4gICAgICB9XG4gICAgICB0ZXh0ID0gZXNjYXBlKHRleHQsIHRydWUpO1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgdHlwZTogJ2NvZGVzcGFuJyxcbiAgICAgICAgcmF3OiBjYXBbMF0sXG4gICAgICAgIHRleHRcbiAgICAgIH07XG4gICAgfVxuICB9XG5cbiAgYnIoc3JjKSB7XG4gICAgY29uc3QgY2FwID0gdGhpcy5ydWxlcy5pbmxpbmUuYnIuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIHR5cGU6ICdicicsXG4gICAgICAgIHJhdzogY2FwWzBdXG4gICAgICB9O1xuICAgIH1cbiAgfVxuXG4gIGRlbChzcmMpIHtcbiAgICBjb25zdCBjYXAgPSB0aGlzLnJ1bGVzLmlubGluZS5kZWwuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIHR5cGU6ICdkZWwnLFxuICAgICAgICByYXc6IGNhcFswXSxcbiAgICAgICAgdGV4dDogY2FwWzJdLFxuICAgICAgICB0b2tlbnM6IHRoaXMubGV4ZXIuaW5saW5lVG9rZW5zKGNhcFsyXSwgW10pXG4gICAgICB9O1xuICAgIH1cbiAgfVxuXG4gIGF1dG9saW5rKHNyYywgbWFuZ2xlKSB7XG4gICAgY29uc3QgY2FwID0gdGhpcy5ydWxlcy5pbmxpbmUuYXV0b2xpbmsuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGxldCB0ZXh0LCBocmVmO1xuICAgICAgaWYgKGNhcFsyXSA9PT0gJ0AnKSB7XG4gICAgICAgIHRleHQgPSBlc2NhcGUodGhpcy5vcHRpb25zLm1hbmdsZSA/IG1hbmdsZShjYXBbMV0pIDogY2FwWzFdKTtcbiAgICAgICAgaHJlZiA9ICdtYWlsdG86JyArIHRleHQ7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB0ZXh0ID0gZXNjYXBlKGNhcFsxXSk7XG4gICAgICAgIGhyZWYgPSB0ZXh0O1xuICAgICAgfVxuXG4gICAgICByZXR1cm4ge1xuICAgICAgICB0eXBlOiAnbGluaycsXG4gICAgICAgIHJhdzogY2FwWzBdLFxuICAgICAgICB0ZXh0LFxuICAgICAgICBocmVmLFxuICAgICAgICB0b2tlbnM6IFtcbiAgICAgICAgICB7XG4gICAgICAgICAgICB0eXBlOiAndGV4dCcsXG4gICAgICAgICAgICByYXc6IHRleHQsXG4gICAgICAgICAgICB0ZXh0XG4gICAgICAgICAgfVxuICAgICAgICBdXG4gICAgICB9O1xuICAgIH1cbiAgfVxuXG4gIHVybChzcmMsIG1hbmdsZSkge1xuICAgIGxldCBjYXA7XG4gICAgaWYgKGNhcCA9IHRoaXMucnVsZXMuaW5saW5lLnVybC5leGVjKHNyYykpIHtcbiAgICAgIGxldCB0ZXh0LCBocmVmO1xuICAgICAgaWYgKGNhcFsyXSA9PT0gJ0AnKSB7XG4gICAgICAgIHRleHQgPSBlc2NhcGUodGhpcy5vcHRpb25zLm1hbmdsZSA/IG1hbmdsZShjYXBbMF0pIDogY2FwWzBdKTtcbiAgICAgICAgaHJlZiA9ICdtYWlsdG86JyArIHRleHQ7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICAvLyBkbyBleHRlbmRlZCBhdXRvbGluayBwYXRoIHZhbGlkYXRpb25cbiAgICAgICAgbGV0IHByZXZDYXBaZXJvO1xuICAgICAgICBkbyB7XG4gICAgICAgICAgcHJldkNhcFplcm8gPSBjYXBbMF07XG4gICAgICAgICAgY2FwWzBdID0gdGhpcy5ydWxlcy5pbmxpbmUuX2JhY2twZWRhbC5leGVjKGNhcFswXSlbMF07XG4gICAgICAgIH0gd2hpbGUgKHByZXZDYXBaZXJvICE9PSBjYXBbMF0pO1xuICAgICAgICB0ZXh0ID0gZXNjYXBlKGNhcFswXSk7XG4gICAgICAgIGlmIChjYXBbMV0gPT09ICd3d3cuJykge1xuICAgICAgICAgIGhyZWYgPSAnaHR0cDovLycgKyB0ZXh0O1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIGhyZWYgPSB0ZXh0O1xuICAgICAgICB9XG4gICAgICB9XG4gICAgICByZXR1cm4ge1xuICAgICAgICB0eXBlOiAnbGluaycsXG4gICAgICAgIHJhdzogY2FwWzBdLFxuICAgICAgICB0ZXh0LFxuICAgICAgICBocmVmLFxuICAgICAgICB0b2tlbnM6IFtcbiAgICAgICAgICB7XG4gICAgICAgICAgICB0eXBlOiAndGV4dCcsXG4gICAgICAgICAgICByYXc6IHRleHQsXG4gICAgICAgICAgICB0ZXh0XG4gICAgICAgICAgfVxuICAgICAgICBdXG4gICAgICB9O1xuICAgIH1cbiAgfVxuXG4gIGlubGluZVRleHQoc3JjLCBzbWFydHlwYW50cykge1xuICAgIGNvbnN0IGNhcCA9IHRoaXMucnVsZXMuaW5saW5lLnRleHQuZXhlYyhzcmMpO1xuICAgIGlmIChjYXApIHtcbiAgICAgIGxldCB0ZXh0O1xuICAgICAgaWYgKHRoaXMubGV4ZXIuc3RhdGUuaW5SYXdCbG9jaykge1xuICAgICAgICB0ZXh0ID0gdGhpcy5vcHRpb25zLnNhbml0aXplID8gKHRoaXMub3B0aW9ucy5zYW5pdGl6ZXIgPyB0aGlzLm9wdGlvbnMuc2FuaXRpemVyKGNhcFswXSkgOiBlc2NhcGUoY2FwWzBdKSkgOiBjYXBbMF07XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB0ZXh0ID0gZXNjYXBlKHRoaXMub3B0aW9ucy5zbWFydHlwYW50cyA/IHNtYXJ0eXBhbnRzKGNhcFswXSkgOiBjYXBbMF0pO1xuICAgICAgfVxuICAgICAgcmV0dXJuIHtcbiAgICAgICAgdHlwZTogJ3RleHQnLFxuICAgICAgICByYXc6IGNhcFswXSxcbiAgICAgICAgdGV4dFxuICAgICAgfTtcbiAgICB9XG4gIH1cbn1cblxuLyoqXG4gKiBCbG9jay1MZXZlbCBHcmFtbWFyXG4gKi9cbmNvbnN0IGJsb2NrID0ge1xuICBuZXdsaW5lOiAvXig/OiAqKD86XFxufCQpKSsvLFxuICBjb2RlOiAvXiggezR9W15cXG5dKyg/Olxcbig/OiAqKD86XFxufCQpKSopPykrLyxcbiAgZmVuY2VzOiAvXiB7MCwzfShgezMsfSg/PVteYFxcbl0qXFxuKXx+ezMsfSkoW15cXG5dKilcXG4oPzp8KFtcXHNcXFNdKj8pXFxuKSg/OiB7MCwzfVxcMVt+YF0qICooPz1cXG58JCl8JCkvLFxuICBocjogL14gezAsM30oKD86LSAqKXszLH18KD86XyAqKXszLH18KD86XFwqICopezMsfSkoPzpcXG4rfCQpLyxcbiAgaGVhZGluZzogL14gezAsM30oI3sxLDZ9KSg/PVxcc3wkKSguKikoPzpcXG4rfCQpLyxcbiAgYmxvY2txdW90ZTogL14oIHswLDN9PiA/KHBhcmFncmFwaHxbXlxcbl0qKSg/OlxcbnwkKSkrLyxcbiAgbGlzdDogL14oIHswLDN9YnVsbCkoIFteXFxuXSs/KT8oPzpcXG58JCkvLFxuICBodG1sOiAnXiB7MCwzfSg/OicgLy8gb3B0aW9uYWwgaW5kZW50YXRpb25cbiAgICArICc8KHNjcmlwdHxwcmV8c3R5bGV8dGV4dGFyZWEpW1xcXFxzPl1bXFxcXHNcXFxcU10qPyg/OjwvXFxcXDE+W15cXFxcbl0qXFxcXG4rfCQpJyAvLyAoMSlcbiAgICArICd8Y29tbWVudFteXFxcXG5dKihcXFxcbit8JCknIC8vICgyKVxuICAgICsgJ3w8XFxcXD9bXFxcXHNcXFxcU10qPyg/OlxcXFw/PlxcXFxuKnwkKScgLy8gKDMpXG4gICAgKyAnfDwhW0EtWl1bXFxcXHNcXFxcU10qPyg/Oj5cXFxcbip8JCknIC8vICg0KVxuICAgICsgJ3w8IVxcXFxbQ0RBVEFcXFxcW1tcXFxcc1xcXFxTXSo/KD86XFxcXF1cXFxcXT5cXFxcbip8JCknIC8vICg1KVxuICAgICsgJ3w8Lz8odGFnKSg/OiArfFxcXFxufC8/PilbXFxcXHNcXFxcU10qPyg/Oig/OlxcXFxuICopK1xcXFxufCQpJyAvLyAoNilcbiAgICArICd8PCg/IXNjcmlwdHxwcmV8c3R5bGV8dGV4dGFyZWEpKFthLXpdW1xcXFx3LV0qKSg/OmF0dHJpYnV0ZSkqPyAqLz8+KD89WyBcXFxcdF0qKD86XFxcXG58JCkpW1xcXFxzXFxcXFNdKj8oPzooPzpcXFxcbiAqKStcXFxcbnwkKScgLy8gKDcpIG9wZW4gdGFnXG4gICAgKyAnfDwvKD8hc2NyaXB0fHByZXxzdHlsZXx0ZXh0YXJlYSlbYS16XVtcXFxcdy1dKlxcXFxzKj4oPz1bIFxcXFx0XSooPzpcXFxcbnwkKSlbXFxcXHNcXFxcU10qPyg/Oig/OlxcXFxuICopK1xcXFxufCQpJyAvLyAoNykgY2xvc2luZyB0YWdcbiAgICArICcpJyxcbiAgZGVmOiAvXiB7MCwzfVxcWyhsYWJlbClcXF06ICpcXG4/ICo8PyhbXlxccz5dKyk+Pyg/Oig/OiArXFxuPyAqfCAqXFxuICopKHRpdGxlKSk/ICooPzpcXG4rfCQpLyxcbiAgdGFibGU6IG5vb3BUZXN0LFxuICBsaGVhZGluZzogL14oW15cXG5dKylcXG4gezAsM30oPSt8LSspICooPzpcXG4rfCQpLyxcbiAgLy8gcmVnZXggdGVtcGxhdGUsIHBsYWNlaG9sZGVycyB3aWxsIGJlIHJlcGxhY2VkIGFjY29yZGluZyB0byBkaWZmZXJlbnQgcGFyYWdyYXBoXG4gIC8vIGludGVycnVwdGlvbiBydWxlcyBvZiBjb21tb25tYXJrIGFuZCB0aGUgb3JpZ2luYWwgbWFya2Rvd24gc3BlYzpcbiAgX3BhcmFncmFwaDogL14oW15cXG5dKyg/Olxcbig/IWhyfGhlYWRpbmd8bGhlYWRpbmd8YmxvY2txdW90ZXxmZW5jZXN8bGlzdHxodG1sfCArXFxuKVteXFxuXSspKikvLFxuICB0ZXh0OiAvXlteXFxuXSsvXG59O1xuXG5ibG9jay5fbGFiZWwgPSAvKD8hXFxzKlxcXSkoPzpcXFxcW1xcW1xcXV18W15cXFtcXF1dKSsvO1xuYmxvY2suX3RpdGxlID0gLyg/OlwiKD86XFxcXFwiP3xbXlwiXFxcXF0pKlwifCdbXidcXG5dKig/OlxcblteJ1xcbl0rKSpcXG4/J3xcXChbXigpXSpcXCkpLztcbmJsb2NrLmRlZiA9IGVkaXQoYmxvY2suZGVmKVxuICAucmVwbGFjZSgnbGFiZWwnLCBibG9jay5fbGFiZWwpXG4gIC5yZXBsYWNlKCd0aXRsZScsIGJsb2NrLl90aXRsZSlcbiAgLmdldFJlZ2V4KCk7XG5cbmJsb2NrLmJ1bGxldCA9IC8oPzpbKistXXxcXGR7MSw5fVsuKV0pLztcbmJsb2NrLmxpc3RJdGVtU3RhcnQgPSBlZGl0KC9eKCAqKShidWxsKSAqLylcbiAgLnJlcGxhY2UoJ2J1bGwnLCBibG9jay5idWxsZXQpXG4gIC5nZXRSZWdleCgpO1xuXG5ibG9jay5saXN0ID0gZWRpdChibG9jay5saXN0KVxuICAucmVwbGFjZSgvYnVsbC9nLCBibG9jay5idWxsZXQpXG4gIC5yZXBsYWNlKCdocicsICdcXFxcbisoPz1cXFxcMT8oPzooPzotICopezMsfXwoPzpfICopezMsfXwoPzpcXFxcKiAqKXszLH0pKD86XFxcXG4rfCQpKScpXG4gIC5yZXBsYWNlKCdkZWYnLCAnXFxcXG4rKD89JyArIGJsb2NrLmRlZi5zb3VyY2UgKyAnKScpXG4gIC5nZXRSZWdleCgpO1xuXG5ibG9jay5fdGFnID0gJ2FkZHJlc3N8YXJ0aWNsZXxhc2lkZXxiYXNlfGJhc2Vmb250fGJsb2NrcXVvdGV8Ym9keXxjYXB0aW9uJ1xuICArICd8Y2VudGVyfGNvbHxjb2xncm91cHxkZHxkZXRhaWxzfGRpYWxvZ3xkaXJ8ZGl2fGRsfGR0fGZpZWxkc2V0fGZpZ2NhcHRpb24nXG4gICsgJ3xmaWd1cmV8Zm9vdGVyfGZvcm18ZnJhbWV8ZnJhbWVzZXR8aFsxLTZdfGhlYWR8aGVhZGVyfGhyfGh0bWx8aWZyYW1lJ1xuICArICd8bGVnZW5kfGxpfGxpbmt8bWFpbnxtZW51fG1lbnVpdGVtfG1ldGF8bmF2fG5vZnJhbWVzfG9sfG9wdGdyb3VwfG9wdGlvbidcbiAgKyAnfHB8cGFyYW18c2VjdGlvbnxzb3VyY2V8c3VtbWFyeXx0YWJsZXx0Ym9keXx0ZHx0Zm9vdHx0aHx0aGVhZHx0aXRsZXx0cidcbiAgKyAnfHRyYWNrfHVsJztcbmJsb2NrLl9jb21tZW50ID0gLzwhLS0oPyEtPz4pW1xcc1xcU10qPyg/Oi0tPnwkKS87XG5ibG9jay5odG1sID0gZWRpdChibG9jay5odG1sLCAnaScpXG4gIC5yZXBsYWNlKCdjb21tZW50JywgYmxvY2suX2NvbW1lbnQpXG4gIC5yZXBsYWNlKCd0YWcnLCBibG9jay5fdGFnKVxuICAucmVwbGFjZSgnYXR0cmlidXRlJywgLyArW2EtekEtWjpfXVtcXHcuOi1dKig/OiAqPSAqXCJbXlwiXFxuXSpcInwgKj0gKidbXidcXG5dKid8ICo9ICpbXlxcc1wiJz08PmBdKyk/LylcbiAgLmdldFJlZ2V4KCk7XG5cbmJsb2NrLnBhcmFncmFwaCA9IGVkaXQoYmxvY2suX3BhcmFncmFwaClcbiAgLnJlcGxhY2UoJ2hyJywgYmxvY2suaHIpXG4gIC5yZXBsYWNlKCdoZWFkaW5nJywgJyB7MCwzfSN7MSw2fSAnKVxuICAucmVwbGFjZSgnfGxoZWFkaW5nJywgJycpIC8vIHNldGV4IGhlYWRpbmdzIGRvbid0IGludGVycnVwdCBjb21tb25tYXJrIHBhcmFncmFwaHNcbiAgLnJlcGxhY2UoJ2Jsb2NrcXVvdGUnLCAnIHswLDN9PicpXG4gIC5yZXBsYWNlKCdmZW5jZXMnLCAnIHswLDN9KD86YHszLH0oPz1bXmBcXFxcbl0qXFxcXG4pfH57Myx9KVteXFxcXG5dKlxcXFxuJylcbiAgLnJlcGxhY2UoJ2xpc3QnLCAnIHswLDN9KD86WyorLV18MVsuKV0pICcpIC8vIG9ubHkgbGlzdHMgc3RhcnRpbmcgZnJvbSAxIGNhbiBpbnRlcnJ1cHRcbiAgLnJlcGxhY2UoJ2h0bWwnLCAnPC8/KD86dGFnKSg/OiArfFxcXFxufC8/Pil8PCg/OnNjcmlwdHxwcmV8c3R5bGV8dGV4dGFyZWF8IS0tKScpXG4gIC5yZXBsYWNlKCd0YWcnLCBibG9jay5fdGFnKSAvLyBwYXJzIGNhbiBiZSBpbnRlcnJ1cHRlZCBieSB0eXBlICg2KSBodG1sIGJsb2Nrc1xuICAuZ2V0UmVnZXgoKTtcblxuYmxvY2suYmxvY2txdW90ZSA9IGVkaXQoYmxvY2suYmxvY2txdW90ZSlcbiAgLnJlcGxhY2UoJ3BhcmFncmFwaCcsIGJsb2NrLnBhcmFncmFwaClcbiAgLmdldFJlZ2V4KCk7XG5cbi8qKlxuICogTm9ybWFsIEJsb2NrIEdyYW1tYXJcbiAqL1xuXG5ibG9jay5ub3JtYWwgPSBtZXJnZSh7fSwgYmxvY2spO1xuXG4vKipcbiAqIEdGTSBCbG9jayBHcmFtbWFyXG4gKi9cblxuYmxvY2suZ2ZtID0gbWVyZ2Uoe30sIGJsb2NrLm5vcm1hbCwge1xuICB0YWJsZTogJ14gKihbXlxcXFxuIF0uKlxcXFx8LiopXFxcXG4nIC8vIEhlYWRlclxuICAgICsgJyB7MCwzfSg/OlxcXFx8ICopPyg6Py0rOj8gKig/OlxcXFx8ICo6Py0rOj8gKikqKSg/OlxcXFx8ICopPycgLy8gQWxpZ25cbiAgICArICcoPzpcXFxcbigoPzooPyEgKlxcXFxufGhyfGhlYWRpbmd8YmxvY2txdW90ZXxjb2RlfGZlbmNlc3xsaXN0fGh0bWwpLiooPzpcXFxcbnwkKSkqKVxcXFxuKnwkKScgLy8gQ2VsbHNcbn0pO1xuXG5ibG9jay5nZm0udGFibGUgPSBlZGl0KGJsb2NrLmdmbS50YWJsZSlcbiAgLnJlcGxhY2UoJ2hyJywgYmxvY2suaHIpXG4gIC5yZXBsYWNlKCdoZWFkaW5nJywgJyB7MCwzfSN7MSw2fSAnKVxuICAucmVwbGFjZSgnYmxvY2txdW90ZScsICcgezAsM30+JylcbiAgLnJlcGxhY2UoJ2NvZGUnLCAnIHs0fVteXFxcXG5dJylcbiAgLnJlcGxhY2UoJ2ZlbmNlcycsICcgezAsM30oPzpgezMsfSg/PVteYFxcXFxuXSpcXFxcbil8fnszLH0pW15cXFxcbl0qXFxcXG4nKVxuICAucmVwbGFjZSgnbGlzdCcsICcgezAsM30oPzpbKistXXwxWy4pXSkgJykgLy8gb25seSBsaXN0cyBzdGFydGluZyBmcm9tIDEgY2FuIGludGVycnVwdFxuICAucmVwbGFjZSgnaHRtbCcsICc8Lz8oPzp0YWcpKD86ICt8XFxcXG58Lz8+KXw8KD86c2NyaXB0fHByZXxzdHlsZXx0ZXh0YXJlYXwhLS0pJylcbiAgLnJlcGxhY2UoJ3RhZycsIGJsb2NrLl90YWcpIC8vIHRhYmxlcyBjYW4gYmUgaW50ZXJydXB0ZWQgYnkgdHlwZSAoNikgaHRtbCBibG9ja3NcbiAgLmdldFJlZ2V4KCk7XG5cbi8qKlxuICogUGVkYW50aWMgZ3JhbW1hciAob3JpZ2luYWwgSm9obiBHcnViZXIncyBsb29zZSBtYXJrZG93biBzcGVjaWZpY2F0aW9uKVxuICovXG5cbmJsb2NrLnBlZGFudGljID0gbWVyZ2Uoe30sIGJsb2NrLm5vcm1hbCwge1xuICBodG1sOiBlZGl0KFxuICAgICdeICooPzpjb21tZW50ICooPzpcXFxcbnxcXFxccyokKSdcbiAgICArICd8PCh0YWcpW1xcXFxzXFxcXFNdKz88L1xcXFwxPiAqKD86XFxcXG57Mix9fFxcXFxzKiQpJyAvLyBjbG9zZWQgdGFnXG4gICAgKyAnfDx0YWcoPzpcIlteXCJdKlwifFxcJ1teXFwnXSpcXCd8XFxcXHNbXlxcJ1wiLz5cXFxcc10qKSo/Lz8+ICooPzpcXFxcbnsyLH18XFxcXHMqJCkpJylcbiAgICAucmVwbGFjZSgnY29tbWVudCcsIGJsb2NrLl9jb21tZW50KVxuICAgIC5yZXBsYWNlKC90YWcvZywgJyg/ISg/OidcbiAgICAgICsgJ2F8ZW18c3Ryb25nfHNtYWxsfHN8Y2l0ZXxxfGRmbnxhYmJyfGRhdGF8dGltZXxjb2RlfHZhcnxzYW1wfGtiZHxzdWInXG4gICAgICArICd8c3VwfGl8Ynx1fG1hcmt8cnVieXxydHxycHxiZGl8YmRvfHNwYW58YnJ8d2JyfGluc3xkZWx8aW1nKSdcbiAgICAgICsgJ1xcXFxiKVxcXFx3Kyg/ITp8W15cXFxcd1xcXFxzQF0qQClcXFxcYicpXG4gICAgLmdldFJlZ2V4KCksXG4gIGRlZjogL14gKlxcWyhbXlxcXV0rKVxcXTogKjw/KFteXFxzPl0rKT4/KD86ICsoW1wiKF1bXlxcbl0rW1wiKV0pKT8gKig/Olxcbit8JCkvLFxuICBoZWFkaW5nOiAvXigjezEsNn0pKC4qKSg/Olxcbit8JCkvLFxuICBmZW5jZXM6IG5vb3BUZXN0LCAvLyBmZW5jZXMgbm90IHN1cHBvcnRlZFxuICBwYXJhZ3JhcGg6IGVkaXQoYmxvY2subm9ybWFsLl9wYXJhZ3JhcGgpXG4gICAgLnJlcGxhY2UoJ2hyJywgYmxvY2suaHIpXG4gICAgLnJlcGxhY2UoJ2hlYWRpbmcnLCAnICojezEsNn0gKlteXFxuXScpXG4gICAgLnJlcGxhY2UoJ2xoZWFkaW5nJywgYmxvY2subGhlYWRpbmcpXG4gICAgLnJlcGxhY2UoJ2Jsb2NrcXVvdGUnLCAnIHswLDN9PicpXG4gICAgLnJlcGxhY2UoJ3xmZW5jZXMnLCAnJylcbiAgICAucmVwbGFjZSgnfGxpc3QnLCAnJylcbiAgICAucmVwbGFjZSgnfGh0bWwnLCAnJylcbiAgICAuZ2V0UmVnZXgoKVxufSk7XG5cbi8qKlxuICogSW5saW5lLUxldmVsIEdyYW1tYXJcbiAqL1xuY29uc3QgaW5saW5lID0ge1xuICBlc2NhcGU6IC9eXFxcXChbIVwiIyQlJicoKSorLFxcLS4vOjs8PT4/QFxcW1xcXVxcXFxeX2B7fH1+XSkvLFxuICBhdXRvbGluazogL148KHNjaGVtZTpbXlxcc1xceDAwLVxceDFmPD5dKnxlbWFpbCk+LyxcbiAgdXJsOiBub29wVGVzdCxcbiAgdGFnOiAnXmNvbW1lbnQnXG4gICAgKyAnfF48L1thLXpBLVpdW1xcXFx3Oi1dKlxcXFxzKj4nIC8vIHNlbGYtY2xvc2luZyB0YWdcbiAgICArICd8XjxbYS16QS1aXVtcXFxcdy1dKig/OmF0dHJpYnV0ZSkqP1xcXFxzKi8/PicgLy8gb3BlbiB0YWdcbiAgICArICd8XjxcXFxcP1tcXFxcc1xcXFxTXSo/XFxcXD8+JyAvLyBwcm9jZXNzaW5nIGluc3RydWN0aW9uLCBlLmcuIDw/cGhwID8+XG4gICAgKyAnfF48IVthLXpBLVpdK1xcXFxzW1xcXFxzXFxcXFNdKj8+JyAvLyBkZWNsYXJhdGlvbiwgZS5nLiA8IURPQ1RZUEUgaHRtbD5cbiAgICArICd8XjwhXFxcXFtDREFUQVxcXFxbW1xcXFxzXFxcXFNdKj9cXFxcXVxcXFxdPicsIC8vIENEQVRBIHNlY3Rpb25cbiAgbGluazogL14hP1xcWyhsYWJlbClcXF1cXChcXHMqKGhyZWYpKD86XFxzKyh0aXRsZSkpP1xccypcXCkvLFxuICByZWZsaW5rOiAvXiE/XFxbKGxhYmVsKVxcXVxcWyg/IVxccypcXF0pKCg/OlxcXFxbXFxbXFxdXT98W15cXFtcXF1cXFxcXSkrKVxcXS8sXG4gIG5vbGluazogL14hP1xcWyg/IVxccypcXF0pKCg/OlxcW1teXFxbXFxdXSpcXF18XFxcXFtcXFtcXF1dfFteXFxbXFxdXSkqKVxcXSg/OlxcW1xcXSk/LyxcbiAgcmVmbGlua1NlYXJjaDogJ3JlZmxpbmt8bm9saW5rKD8hXFxcXCgpJyxcbiAgZW1TdHJvbmc6IHtcbiAgICBsRGVsaW06IC9eKD86XFwqKyg/OihbcHVuY3RfXSl8W15cXHMqXSkpfF5fKyg/OihbcHVuY3QqXSl8KFteXFxzX10pKS8sXG4gICAgLy8gICAgICAgICgxKSBhbmQgKDIpIGNhbiBvbmx5IGJlIGEgUmlnaHQgRGVsaW1pdGVyLiAoMykgYW5kICg0KSBjYW4gb25seSBiZSBMZWZ0LiAgKDUpIGFuZCAoNikgY2FuIGJlIGVpdGhlciBMZWZ0IG9yIFJpZ2h0LlxuICAgIC8vICAgICAgICAoKSBTa2lwIG9ycGhhbiBkZWxpbSBpbnNpZGUgc3Ryb25nICAgICgxKSAjKioqICAgICAgICAgICAgICAgICgyKSBhKioqIywgYSoqKiAgICAgICAgICAgICAgICAgICAoMykgIyoqKmEsICoqKmEgICAgICAgICAgICAgICAgICg0KSAqKiojICAgICAgICAgICAgICAoNSkgIyoqKiMgICAgICAgICAgICAgICAgICg2KSBhKioqYVxuICAgIHJEZWxpbUFzdDogL15bXl8qXSo/XFxfXFxfW15fKl0qP1xcKlteXypdKj8oPz1cXF9cXF8pfFtwdW5jdF9dKFxcKispKD89W1xcc118JCl8W15wdW5jdCpfXFxzXShcXCorKSg/PVtwdW5jdF9cXHNdfCQpfFtwdW5jdF9cXHNdKFxcKispKD89W15wdW5jdCpfXFxzXSl8W1xcc10oXFwqKykoPz1bcHVuY3RfXSl8W3B1bmN0X10oXFwqKykoPz1bcHVuY3RfXSl8W15wdW5jdCpfXFxzXShcXCorKSg/PVtecHVuY3QqX1xcc10pLyxcbiAgICByRGVsaW1VbmQ6IC9eW15fKl0qP1xcKlxcKlteXypdKj9cXF9bXl8qXSo/KD89XFwqXFwqKXxbcHVuY3QqXShcXF8rKSg/PVtcXHNdfCQpfFtecHVuY3QqX1xcc10oXFxfKykoPz1bcHVuY3QqXFxzXXwkKXxbcHVuY3QqXFxzXShcXF8rKSg/PVtecHVuY3QqX1xcc10pfFtcXHNdKFxcXyspKD89W3B1bmN0Kl0pfFtwdW5jdCpdKFxcXyspKD89W3B1bmN0Kl0pLyAvLyBeLSBOb3QgYWxsb3dlZCBmb3IgX1xuICB9LFxuICBjb2RlOiAvXihgKykoW15gXXxbXmBdW1xcc1xcU10qP1teYF0pXFwxKD8hYCkvLFxuICBicjogL14oIHsyLH18XFxcXClcXG4oPyFcXHMqJCkvLFxuICBkZWw6IG5vb3BUZXN0LFxuICB0ZXh0OiAvXihgK3xbXmBdKSg/Oig/PSB7Mix9XFxuKXxbXFxzXFxTXSo/KD86KD89W1xcXFw8IVxcW2AqX118XFxiX3wkKXxbXiBdKD89IHsyLH1cXG4pKSkvLFxuICBwdW5jdHVhdGlvbjogL14oW1xcc3B1bmN0dWF0aW9uXSkvXG59O1xuXG4vLyBsaXN0IG9mIHB1bmN0dWF0aW9uIG1hcmtzIGZyb20gQ29tbW9uTWFyayBzcGVjXG4vLyB3aXRob3V0ICogYW5kIF8gdG8gaGFuZGxlIHRoZSBkaWZmZXJlbnQgZW1waGFzaXMgbWFya2VycyAqIGFuZCBfXG5pbmxpbmUuX3B1bmN0dWF0aW9uID0gJyFcIiMkJSZcXCcoKStcXFxcLS4sLzo7PD0+P0BcXFxcW1xcXFxdYF57fH1+JztcbmlubGluZS5wdW5jdHVhdGlvbiA9IGVkaXQoaW5saW5lLnB1bmN0dWF0aW9uKS5yZXBsYWNlKC9wdW5jdHVhdGlvbi9nLCBpbmxpbmUuX3B1bmN0dWF0aW9uKS5nZXRSZWdleCgpO1xuXG4vLyBzZXF1ZW5jZXMgZW0gc2hvdWxkIHNraXAgb3ZlciBbdGl0bGVdKGxpbmspLCBgY29kZWAsIDxodG1sPlxuaW5saW5lLmJsb2NrU2tpcCA9IC9cXFtbXlxcXV0qP1xcXVxcKFteXFwpXSo/XFwpfGBbXmBdKj9gfDxbXj5dKj8+L2c7XG5pbmxpbmUuZXNjYXBlZEVtU3QgPSAvXFxcXFxcKnxcXFxcXy9nO1xuXG5pbmxpbmUuX2NvbW1lbnQgPSBlZGl0KGJsb2NrLl9jb21tZW50KS5yZXBsYWNlKCcoPzotLT58JCknLCAnLS0+JykuZ2V0UmVnZXgoKTtcblxuaW5saW5lLmVtU3Ryb25nLmxEZWxpbSA9IGVkaXQoaW5saW5lLmVtU3Ryb25nLmxEZWxpbSlcbiAgLnJlcGxhY2UoL3B1bmN0L2csIGlubGluZS5fcHVuY3R1YXRpb24pXG4gIC5nZXRSZWdleCgpO1xuXG5pbmxpbmUuZW1TdHJvbmcuckRlbGltQXN0ID0gZWRpdChpbmxpbmUuZW1TdHJvbmcuckRlbGltQXN0LCAnZycpXG4gIC5yZXBsYWNlKC9wdW5jdC9nLCBpbmxpbmUuX3B1bmN0dWF0aW9uKVxuICAuZ2V0UmVnZXgoKTtcblxuaW5saW5lLmVtU3Ryb25nLnJEZWxpbVVuZCA9IGVkaXQoaW5saW5lLmVtU3Ryb25nLnJEZWxpbVVuZCwgJ2cnKVxuICAucmVwbGFjZSgvcHVuY3QvZywgaW5saW5lLl9wdW5jdHVhdGlvbilcbiAgLmdldFJlZ2V4KCk7XG5cbmlubGluZS5fZXNjYXBlcyA9IC9cXFxcKFshXCIjJCUmJygpKissXFwtLi86Ozw9Pj9AXFxbXFxdXFxcXF5fYHt8fX5dKS9nO1xuXG5pbmxpbmUuX3NjaGVtZSA9IC9bYS16QS1aXVthLXpBLVowLTkrLi1dezEsMzF9LztcbmlubGluZS5fZW1haWwgPSAvW2EtekEtWjAtOS4hIyQlJicqKy89P15fYHt8fX4tXSsoQClbYS16QS1aMC05XSg/OlthLXpBLVowLTktXXswLDYxfVthLXpBLVowLTldKT8oPzpcXC5bYS16QS1aMC05XSg/OlthLXpBLVowLTktXXswLDYxfVthLXpBLVowLTldKT8pKyg/IVstX10pLztcbmlubGluZS5hdXRvbGluayA9IGVkaXQoaW5saW5lLmF1dG9saW5rKVxuICAucmVwbGFjZSgnc2NoZW1lJywgaW5saW5lLl9zY2hlbWUpXG4gIC5yZXBsYWNlKCdlbWFpbCcsIGlubGluZS5fZW1haWwpXG4gIC5nZXRSZWdleCgpO1xuXG5pbmxpbmUuX2F0dHJpYnV0ZSA9IC9cXHMrW2EtekEtWjpfXVtcXHcuOi1dKig/Olxccyo9XFxzKlwiW15cIl0qXCJ8XFxzKj1cXHMqJ1teJ10qJ3xcXHMqPVxccypbXlxcc1wiJz08PmBdKyk/LztcblxuaW5saW5lLnRhZyA9IGVkaXQoaW5saW5lLnRhZylcbiAgLnJlcGxhY2UoJ2NvbW1lbnQnLCBpbmxpbmUuX2NvbW1lbnQpXG4gIC5yZXBsYWNlKCdhdHRyaWJ1dGUnLCBpbmxpbmUuX2F0dHJpYnV0ZSlcbiAgLmdldFJlZ2V4KCk7XG5cbmlubGluZS5fbGFiZWwgPSAvKD86XFxbKD86XFxcXC58W15cXFtcXF1cXFxcXSkqXFxdfFxcXFwufGBbXmBdKmB8W15cXFtcXF1cXFxcYF0pKj8vO1xuaW5saW5lLl9ocmVmID0gLzwoPzpcXFxcLnxbXlxcbjw+XFxcXF0pKz58W15cXHNcXHgwMC1cXHgxZl0qLztcbmlubGluZS5fdGl0bGUgPSAvXCIoPzpcXFxcXCI/fFteXCJcXFxcXSkqXCJ8Jyg/OlxcXFwnP3xbXidcXFxcXSkqJ3xcXCgoPzpcXFxcXFwpP3xbXilcXFxcXSkqXFwpLztcblxuaW5saW5lLmxpbmsgPSBlZGl0KGlubGluZS5saW5rKVxuICAucmVwbGFjZSgnbGFiZWwnLCBpbmxpbmUuX2xhYmVsKVxuICAucmVwbGFjZSgnaHJlZicsIGlubGluZS5faHJlZilcbiAgLnJlcGxhY2UoJ3RpdGxlJywgaW5saW5lLl90aXRsZSlcbiAgLmdldFJlZ2V4KCk7XG5cbmlubGluZS5yZWZsaW5rID0gZWRpdChpbmxpbmUucmVmbGluaylcbiAgLnJlcGxhY2UoJ2xhYmVsJywgaW5saW5lLl9sYWJlbClcbiAgLmdldFJlZ2V4KCk7XG5cbmlubGluZS5yZWZsaW5rU2VhcmNoID0gZWRpdChpbmxpbmUucmVmbGlua1NlYXJjaCwgJ2cnKVxuICAucmVwbGFjZSgncmVmbGluaycsIGlubGluZS5yZWZsaW5rKVxuICAucmVwbGFjZSgnbm9saW5rJywgaW5saW5lLm5vbGluaylcbiAgLmdldFJlZ2V4KCk7XG5cbi8qKlxuICogTm9ybWFsIElubGluZSBHcmFtbWFyXG4gKi9cblxuaW5saW5lLm5vcm1hbCA9IG1lcmdlKHt9LCBpbmxpbmUpO1xuXG4vKipcbiAqIFBlZGFudGljIElubGluZSBHcmFtbWFyXG4gKi9cblxuaW5saW5lLnBlZGFudGljID0gbWVyZ2Uoe30sIGlubGluZS5ub3JtYWwsIHtcbiAgc3Ryb25nOiB7XG4gICAgc3RhcnQ6IC9eX198XFwqXFwqLyxcbiAgICBtaWRkbGU6IC9eX18oPz1cXFMpKFtcXHNcXFNdKj9cXFMpX18oPyFfKXxeXFwqXFwqKD89XFxTKShbXFxzXFxTXSo/XFxTKVxcKlxcKig/IVxcKikvLFxuICAgIGVuZEFzdDogL1xcKlxcKig/IVxcKikvZyxcbiAgICBlbmRVbmQ6IC9fXyg/IV8pL2dcbiAgfSxcbiAgZW06IHtcbiAgICBzdGFydDogL15ffFxcKi8sXG4gICAgbWlkZGxlOiAvXigpXFwqKD89XFxTKShbXFxzXFxTXSo/XFxTKVxcKig/IVxcKil8Xl8oPz1cXFMpKFtcXHNcXFNdKj9cXFMpXyg/IV8pLyxcbiAgICBlbmRBc3Q6IC9cXCooPyFcXCopL2csXG4gICAgZW5kVW5kOiAvXyg/IV8pL2dcbiAgfSxcbiAgbGluazogZWRpdCgvXiE/XFxbKGxhYmVsKVxcXVxcKCguKj8pXFwpLylcbiAgICAucmVwbGFjZSgnbGFiZWwnLCBpbmxpbmUuX2xhYmVsKVxuICAgIC5nZXRSZWdleCgpLFxuICByZWZsaW5rOiBlZGl0KC9eIT9cXFsobGFiZWwpXFxdXFxzKlxcWyhbXlxcXV0qKVxcXS8pXG4gICAgLnJlcGxhY2UoJ2xhYmVsJywgaW5saW5lLl9sYWJlbClcbiAgICAuZ2V0UmVnZXgoKVxufSk7XG5cbi8qKlxuICogR0ZNIElubGluZSBHcmFtbWFyXG4gKi9cblxuaW5saW5lLmdmbSA9IG1lcmdlKHt9LCBpbmxpbmUubm9ybWFsLCB7XG4gIGVzY2FwZTogZWRpdChpbmxpbmUuZXNjYXBlKS5yZXBsYWNlKCddKScsICd+fF0pJykuZ2V0UmVnZXgoKSxcbiAgX2V4dGVuZGVkX2VtYWlsOiAvW0EtWmEtejAtOS5fKy1dKyhAKVthLXpBLVowLTktX10rKD86XFwuW2EtekEtWjAtOS1fXSpbYS16QS1aMC05XSkrKD8hWy1fXSkvLFxuICB1cmw6IC9eKCg/OmZ0cHxodHRwcz8pOlxcL1xcL3x3d3dcXC4pKD86W2EtekEtWjAtOVxcLV0rXFwuPykrW15cXHM8XSp8XmVtYWlsLyxcbiAgX2JhY2twZWRhbDogLyg/OltePyEuLDo7Kl9+KCkmXSt8XFwoW14pXSpcXCl8Jig/IVthLXpBLVowLTldKzskKXxbPyEuLDo7Kl9+KV0rKD8hJCkpKy8sXG4gIGRlbDogL14ofn4/KSg/PVteXFxzfl0pKFtcXHNcXFNdKj9bXlxcc35dKVxcMSg/PVtefl18JCkvLFxuICB0ZXh0OiAvXihbYH5dK3xbXmB+XSkoPzooPz0gezIsfVxcbil8KD89W2EtekEtWjAtOS4hIyQlJicqK1xcLz0/X2B7XFx8fX4tXStAKXxbXFxzXFxTXSo/KD86KD89W1xcXFw8IVxcW2Aqfl9dfFxcYl98aHR0cHM/OlxcL1xcL3xmdHA6XFwvXFwvfHd3d1xcLnwkKXxbXiBdKD89IHsyLH1cXG4pfFteYS16QS1aMC05LiEjJCUmJyorXFwvPT9fYHtcXHx9fi1dKD89W2EtekEtWjAtOS4hIyQlJicqK1xcLz0/X2B7XFx8fX4tXStAKSkpL1xufSk7XG5cbmlubGluZS5nZm0udXJsID0gZWRpdChpbmxpbmUuZ2ZtLnVybCwgJ2knKVxuICAucmVwbGFjZSgnZW1haWwnLCBpbmxpbmUuZ2ZtLl9leHRlbmRlZF9lbWFpbClcbiAgLmdldFJlZ2V4KCk7XG4vKipcbiAqIEdGTSArIExpbmUgQnJlYWtzIElubGluZSBHcmFtbWFyXG4gKi9cblxuaW5saW5lLmJyZWFrcyA9IG1lcmdlKHt9LCBpbmxpbmUuZ2ZtLCB7XG4gIGJyOiBlZGl0KGlubGluZS5icikucmVwbGFjZSgnezIsfScsICcqJykuZ2V0UmVnZXgoKSxcbiAgdGV4dDogZWRpdChpbmxpbmUuZ2ZtLnRleHQpXG4gICAgLnJlcGxhY2UoJ1xcXFxiXycsICdcXFxcYl98IHsyLH1cXFxcbicpXG4gICAgLnJlcGxhY2UoL1xcezIsXFx9L2csICcqJylcbiAgICAuZ2V0UmVnZXgoKVxufSk7XG5cbi8qKlxuICogc21hcnR5cGFudHMgdGV4dCByZXBsYWNlbWVudFxuICovXG5mdW5jdGlvbiBzbWFydHlwYW50cyh0ZXh0KSB7XG4gIHJldHVybiB0ZXh0XG4gICAgLy8gZW0tZGFzaGVzXG4gICAgLnJlcGxhY2UoLy0tLS9nLCAnXFx1MjAxNCcpXG4gICAgLy8gZW4tZGFzaGVzXG4gICAgLnJlcGxhY2UoLy0tL2csICdcXHUyMDEzJylcbiAgICAvLyBvcGVuaW5nIHNpbmdsZXNcbiAgICAucmVwbGFjZSgvKF58Wy1cXHUyMDE0LyhcXFt7XCJcXHNdKScvZywgJyQxXFx1MjAxOCcpXG4gICAgLy8gY2xvc2luZyBzaW5nbGVzICYgYXBvc3Ryb3BoZXNcbiAgICAucmVwbGFjZSgvJy9nLCAnXFx1MjAxOScpXG4gICAgLy8gb3BlbmluZyBkb3VibGVzXG4gICAgLnJlcGxhY2UoLyhefFstXFx1MjAxNC8oXFxbe1xcdTIwMThcXHNdKVwiL2csICckMVxcdTIwMWMnKVxuICAgIC8vIGNsb3NpbmcgZG91Ymxlc1xuICAgIC5yZXBsYWNlKC9cIi9nLCAnXFx1MjAxZCcpXG4gICAgLy8gZWxsaXBzZXNcbiAgICAucmVwbGFjZSgvXFwuezN9L2csICdcXHUyMDI2Jyk7XG59XG5cbi8qKlxuICogbWFuZ2xlIGVtYWlsIGFkZHJlc3Nlc1xuICovXG5mdW5jdGlvbiBtYW5nbGUodGV4dCkge1xuICBsZXQgb3V0ID0gJycsXG4gICAgaSxcbiAgICBjaDtcblxuICBjb25zdCBsID0gdGV4dC5sZW5ndGg7XG4gIGZvciAoaSA9IDA7IGkgPCBsOyBpKyspIHtcbiAgICBjaCA9IHRleHQuY2hhckNvZGVBdChpKTtcbiAgICBpZiAoTWF0aC5yYW5kb20oKSA+IDAuNSkge1xuICAgICAgY2ggPSAneCcgKyBjaC50b1N0cmluZygxNik7XG4gICAgfVxuICAgIG91dCArPSAnJiMnICsgY2ggKyAnOyc7XG4gIH1cblxuICByZXR1cm4gb3V0O1xufVxuXG4vKipcbiAqIEJsb2NrIExleGVyXG4gKi9cbmNsYXNzIExleGVyIHtcbiAgY29uc3RydWN0b3Iob3B0aW9ucykge1xuICAgIHRoaXMudG9rZW5zID0gW107XG4gICAgdGhpcy50b2tlbnMubGlua3MgPSBPYmplY3QuY3JlYXRlKG51bGwpO1xuICAgIHRoaXMub3B0aW9ucyA9IG9wdGlvbnMgfHwgZGVmYXVsdHM7XG4gICAgdGhpcy5vcHRpb25zLnRva2VuaXplciA9IHRoaXMub3B0aW9ucy50b2tlbml6ZXIgfHwgbmV3IFRva2VuaXplcigpO1xuICAgIHRoaXMudG9rZW5pemVyID0gdGhpcy5vcHRpb25zLnRva2VuaXplcjtcbiAgICB0aGlzLnRva2VuaXplci5vcHRpb25zID0gdGhpcy5vcHRpb25zO1xuICAgIHRoaXMudG9rZW5pemVyLmxleGVyID0gdGhpcztcbiAgICB0aGlzLmlubGluZVF1ZXVlID0gW107XG4gICAgdGhpcy5zdGF0ZSA9IHtcbiAgICAgIGluTGluazogZmFsc2UsXG4gICAgICBpblJhd0Jsb2NrOiBmYWxzZSxcbiAgICAgIHRvcDogdHJ1ZVxuICAgIH07XG5cbiAgICBjb25zdCBydWxlcyA9IHtcbiAgICAgIGJsb2NrOiBibG9jay5ub3JtYWwsXG4gICAgICBpbmxpbmU6IGlubGluZS5ub3JtYWxcbiAgICB9O1xuXG4gICAgaWYgKHRoaXMub3B0aW9ucy5wZWRhbnRpYykge1xuICAgICAgcnVsZXMuYmxvY2sgPSBibG9jay5wZWRhbnRpYztcbiAgICAgIHJ1bGVzLmlubGluZSA9IGlubGluZS5wZWRhbnRpYztcbiAgICB9IGVsc2UgaWYgKHRoaXMub3B0aW9ucy5nZm0pIHtcbiAgICAgIHJ1bGVzLmJsb2NrID0gYmxvY2suZ2ZtO1xuICAgICAgaWYgKHRoaXMub3B0aW9ucy5icmVha3MpIHtcbiAgICAgICAgcnVsZXMuaW5saW5lID0gaW5saW5lLmJyZWFrcztcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJ1bGVzLmlubGluZSA9IGlubGluZS5nZm07XG4gICAgICB9XG4gICAgfVxuICAgIHRoaXMudG9rZW5pemVyLnJ1bGVzID0gcnVsZXM7XG4gIH1cblxuICAvKipcbiAgICogRXhwb3NlIFJ1bGVzXG4gICAqL1xuICBzdGF0aWMgZ2V0IHJ1bGVzKCkge1xuICAgIHJldHVybiB7XG4gICAgICBibG9jayxcbiAgICAgIGlubGluZVxuICAgIH07XG4gIH1cblxuICAvKipcbiAgICogU3RhdGljIExleCBNZXRob2RcbiAgICovXG4gIHN0YXRpYyBsZXgoc3JjLCBvcHRpb25zKSB7XG4gICAgY29uc3QgbGV4ZXIgPSBuZXcgTGV4ZXIob3B0aW9ucyk7XG4gICAgcmV0dXJuIGxleGVyLmxleChzcmMpO1xuICB9XG5cbiAgLyoqXG4gICAqIFN0YXRpYyBMZXggSW5saW5lIE1ldGhvZFxuICAgKi9cbiAgc3RhdGljIGxleElubGluZShzcmMsIG9wdGlvbnMpIHtcbiAgICBjb25zdCBsZXhlciA9IG5ldyBMZXhlcihvcHRpb25zKTtcbiAgICByZXR1cm4gbGV4ZXIuaW5saW5lVG9rZW5zKHNyYyk7XG4gIH1cblxuICAvKipcbiAgICogUHJlcHJvY2Vzc2luZ1xuICAgKi9cbiAgbGV4KHNyYykge1xuICAgIHNyYyA9IHNyY1xuICAgICAgLnJlcGxhY2UoL1xcclxcbnxcXHIvZywgJ1xcbicpXG4gICAgICAucmVwbGFjZSgvXFx0L2csICcgICAgJyk7XG5cbiAgICB0aGlzLmJsb2NrVG9rZW5zKHNyYywgdGhpcy50b2tlbnMpO1xuXG4gICAgbGV0IG5leHQ7XG4gICAgd2hpbGUgKG5leHQgPSB0aGlzLmlubGluZVF1ZXVlLnNoaWZ0KCkpIHtcbiAgICAgIHRoaXMuaW5saW5lVG9rZW5zKG5leHQuc3JjLCBuZXh0LnRva2Vucyk7XG4gICAgfVxuXG4gICAgcmV0dXJuIHRoaXMudG9rZW5zO1xuICB9XG5cbiAgLyoqXG4gICAqIExleGluZ1xuICAgKi9cbiAgYmxvY2tUb2tlbnMoc3JjLCB0b2tlbnMgPSBbXSkge1xuICAgIGlmICh0aGlzLm9wdGlvbnMucGVkYW50aWMpIHtcbiAgICAgIHNyYyA9IHNyYy5yZXBsYWNlKC9eICskL2dtLCAnJyk7XG4gICAgfVxuICAgIGxldCB0b2tlbiwgbGFzdFRva2VuLCBjdXRTcmMsIGxhc3RQYXJhZ3JhcGhDbGlwcGVkO1xuXG4gICAgd2hpbGUgKHNyYykge1xuICAgICAgaWYgKHRoaXMub3B0aW9ucy5leHRlbnNpb25zXG4gICAgICAgICYmIHRoaXMub3B0aW9ucy5leHRlbnNpb25zLmJsb2NrXG4gICAgICAgICYmIHRoaXMub3B0aW9ucy5leHRlbnNpb25zLmJsb2NrLnNvbWUoKGV4dFRva2VuaXplcikgPT4ge1xuICAgICAgICAgIGlmICh0b2tlbiA9IGV4dFRva2VuaXplci5jYWxsKHsgbGV4ZXI6IHRoaXMgfSwgc3JjLCB0b2tlbnMpKSB7XG4gICAgICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICAgICAgdG9rZW5zLnB1c2godG9rZW4pO1xuICAgICAgICAgICAgcmV0dXJuIHRydWU7XG4gICAgICAgICAgfVxuICAgICAgICAgIHJldHVybiBmYWxzZTtcbiAgICAgICAgfSkpIHtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIG5ld2xpbmVcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLnNwYWNlKHNyYykpIHtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgaWYgKHRva2VuLnR5cGUpIHtcbiAgICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIH1cbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGNvZGVcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLmNvZGUoc3JjKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICBsYXN0VG9rZW4gPSB0b2tlbnNbdG9rZW5zLmxlbmd0aCAtIDFdO1xuICAgICAgICAvLyBBbiBpbmRlbnRlZCBjb2RlIGJsb2NrIGNhbm5vdCBpbnRlcnJ1cHQgYSBwYXJhZ3JhcGguXG4gICAgICAgIGlmIChsYXN0VG9rZW4gJiYgKGxhc3RUb2tlbi50eXBlID09PSAncGFyYWdyYXBoJyB8fCBsYXN0VG9rZW4udHlwZSA9PT0gJ3RleHQnKSkge1xuICAgICAgICAgIGxhc3RUb2tlbi5yYXcgKz0gJ1xcbicgKyB0b2tlbi5yYXc7XG4gICAgICAgICAgbGFzdFRva2VuLnRleHQgKz0gJ1xcbicgKyB0b2tlbi50ZXh0O1xuICAgICAgICAgIHRoaXMuaW5saW5lUXVldWVbdGhpcy5pbmxpbmVRdWV1ZS5sZW5ndGggLSAxXS5zcmMgPSBsYXN0VG9rZW4udGV4dDtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIH1cbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGZlbmNlc1xuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIuZmVuY2VzKHNyYykpIHtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgdG9rZW5zLnB1c2godG9rZW4pO1xuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgLy8gaGVhZGluZ1xuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIuaGVhZGluZyhzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGhyXG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5ocihzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGJsb2NrcXVvdGVcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLmJsb2NrcXVvdGUoc3JjKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIGNvbnRpbnVlO1xuICAgICAgfVxuXG4gICAgICAvLyBsaXN0XG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5saXN0KHNyYykpIHtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgdG9rZW5zLnB1c2godG9rZW4pO1xuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgLy8gaHRtbFxuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIuaHRtbChzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGRlZlxuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIuZGVmKHNyYykpIHtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgbGFzdFRva2VuID0gdG9rZW5zW3Rva2Vucy5sZW5ndGggLSAxXTtcbiAgICAgICAgaWYgKGxhc3RUb2tlbiAmJiAobGFzdFRva2VuLnR5cGUgPT09ICdwYXJhZ3JhcGgnIHx8IGxhc3RUb2tlbi50eXBlID09PSAndGV4dCcpKSB7XG4gICAgICAgICAgbGFzdFRva2VuLnJhdyArPSAnXFxuJyArIHRva2VuLnJhdztcbiAgICAgICAgICBsYXN0VG9rZW4udGV4dCArPSAnXFxuJyArIHRva2VuLnJhdztcbiAgICAgICAgICB0aGlzLmlubGluZVF1ZXVlW3RoaXMuaW5saW5lUXVldWUubGVuZ3RoIC0gMV0uc3JjID0gbGFzdFRva2VuLnRleHQ7XG4gICAgICAgIH0gZWxzZSBpZiAoIXRoaXMudG9rZW5zLmxpbmtzW3Rva2VuLnRhZ10pIHtcbiAgICAgICAgICB0aGlzLnRva2Vucy5saW5rc1t0b2tlbi50YWddID0ge1xuICAgICAgICAgICAgaHJlZjogdG9rZW4uaHJlZixcbiAgICAgICAgICAgIHRpdGxlOiB0b2tlbi50aXRsZVxuICAgICAgICAgIH07XG4gICAgICAgIH1cbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIHRhYmxlIChnZm0pXG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci50YWJsZShzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGxoZWFkaW5nXG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5saGVhZGluZyhzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIHRvcC1sZXZlbCBwYXJhZ3JhcGhcbiAgICAgIC8vIHByZXZlbnQgcGFyYWdyYXBoIGNvbnN1bWluZyBleHRlbnNpb25zIGJ5IGNsaXBwaW5nICdzcmMnIHRvIGV4dGVuc2lvbiBzdGFydFxuICAgICAgY3V0U3JjID0gc3JjO1xuICAgICAgaWYgKHRoaXMub3B0aW9ucy5leHRlbnNpb25zICYmIHRoaXMub3B0aW9ucy5leHRlbnNpb25zLnN0YXJ0QmxvY2spIHtcbiAgICAgICAgbGV0IHN0YXJ0SW5kZXggPSBJbmZpbml0eTtcbiAgICAgICAgY29uc3QgdGVtcFNyYyA9IHNyYy5zbGljZSgxKTtcbiAgICAgICAgbGV0IHRlbXBTdGFydDtcbiAgICAgICAgdGhpcy5vcHRpb25zLmV4dGVuc2lvbnMuc3RhcnRCbG9jay5mb3JFYWNoKGZ1bmN0aW9uKGdldFN0YXJ0SW5kZXgpIHtcbiAgICAgICAgICB0ZW1wU3RhcnQgPSBnZXRTdGFydEluZGV4LmNhbGwoeyBsZXhlcjogdGhpcyB9LCB0ZW1wU3JjKTtcbiAgICAgICAgICBpZiAodHlwZW9mIHRlbXBTdGFydCA9PT0gJ251bWJlcicgJiYgdGVtcFN0YXJ0ID49IDApIHsgc3RhcnRJbmRleCA9IE1hdGgubWluKHN0YXJ0SW5kZXgsIHRlbXBTdGFydCk7IH1cbiAgICAgICAgfSk7XG4gICAgICAgIGlmIChzdGFydEluZGV4IDwgSW5maW5pdHkgJiYgc3RhcnRJbmRleCA+PSAwKSB7XG4gICAgICAgICAgY3V0U3JjID0gc3JjLnN1YnN0cmluZygwLCBzdGFydEluZGV4ICsgMSk7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICAgIGlmICh0aGlzLnN0YXRlLnRvcCAmJiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5wYXJhZ3JhcGgoY3V0U3JjKSkpIHtcbiAgICAgICAgbGFzdFRva2VuID0gdG9rZW5zW3Rva2Vucy5sZW5ndGggLSAxXTtcbiAgICAgICAgaWYgKGxhc3RQYXJhZ3JhcGhDbGlwcGVkICYmIGxhc3RUb2tlbi50eXBlID09PSAncGFyYWdyYXBoJykge1xuICAgICAgICAgIGxhc3RUb2tlbi5yYXcgKz0gJ1xcbicgKyB0b2tlbi5yYXc7XG4gICAgICAgICAgbGFzdFRva2VuLnRleHQgKz0gJ1xcbicgKyB0b2tlbi50ZXh0O1xuICAgICAgICAgIHRoaXMuaW5saW5lUXVldWUucG9wKCk7XG4gICAgICAgICAgdGhpcy5pbmxpbmVRdWV1ZVt0aGlzLmlubGluZVF1ZXVlLmxlbmd0aCAtIDFdLnNyYyA9IGxhc3RUb2tlbi50ZXh0O1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgfVxuICAgICAgICBsYXN0UGFyYWdyYXBoQ2xpcHBlZCA9IChjdXRTcmMubGVuZ3RoICE9PSBzcmMubGVuZ3RoKTtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIHRleHRcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLnRleHQoc3JjKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICBsYXN0VG9rZW4gPSB0b2tlbnNbdG9rZW5zLmxlbmd0aCAtIDFdO1xuICAgICAgICBpZiAobGFzdFRva2VuICYmIGxhc3RUb2tlbi50eXBlID09PSAndGV4dCcpIHtcbiAgICAgICAgICBsYXN0VG9rZW4ucmF3ICs9ICdcXG4nICsgdG9rZW4ucmF3O1xuICAgICAgICAgIGxhc3RUb2tlbi50ZXh0ICs9ICdcXG4nICsgdG9rZW4udGV4dDtcbiAgICAgICAgICB0aGlzLmlubGluZVF1ZXVlLnBvcCgpO1xuICAgICAgICAgIHRoaXMuaW5saW5lUXVldWVbdGhpcy5pbmxpbmVRdWV1ZS5sZW5ndGggLSAxXS5zcmMgPSBsYXN0VG9rZW4udGV4dDtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIH1cbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIGlmIChzcmMpIHtcbiAgICAgICAgY29uc3QgZXJyTXNnID0gJ0luZmluaXRlIGxvb3Agb24gYnl0ZTogJyArIHNyYy5jaGFyQ29kZUF0KDApO1xuICAgICAgICBpZiAodGhpcy5vcHRpb25zLnNpbGVudCkge1xuICAgICAgICAgIGNvbnNvbGUuZXJyb3IoZXJyTXNnKTtcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoZXJyTXNnKTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cblxuICAgIHRoaXMuc3RhdGUudG9wID0gdHJ1ZTtcbiAgICByZXR1cm4gdG9rZW5zO1xuICB9XG5cbiAgaW5saW5lKHNyYywgdG9rZW5zKSB7XG4gICAgdGhpcy5pbmxpbmVRdWV1ZS5wdXNoKHsgc3JjLCB0b2tlbnMgfSk7XG4gIH1cblxuICAvKipcbiAgICogTGV4aW5nL0NvbXBpbGluZ1xuICAgKi9cbiAgaW5saW5lVG9rZW5zKHNyYywgdG9rZW5zID0gW10pIHtcbiAgICBsZXQgdG9rZW4sIGxhc3RUb2tlbiwgY3V0U3JjO1xuXG4gICAgLy8gU3RyaW5nIHdpdGggbGlua3MgbWFza2VkIHRvIGF2b2lkIGludGVyZmVyZW5jZSB3aXRoIGVtIGFuZCBzdHJvbmdcbiAgICBsZXQgbWFza2VkU3JjID0gc3JjO1xuICAgIGxldCBtYXRjaDtcbiAgICBsZXQga2VlcFByZXZDaGFyLCBwcmV2Q2hhcjtcblxuICAgIC8vIE1hc2sgb3V0IHJlZmxpbmtzXG4gICAgaWYgKHRoaXMudG9rZW5zLmxpbmtzKSB7XG4gICAgICBjb25zdCBsaW5rcyA9IE9iamVjdC5rZXlzKHRoaXMudG9rZW5zLmxpbmtzKTtcbiAgICAgIGlmIChsaW5rcy5sZW5ndGggPiAwKSB7XG4gICAgICAgIHdoaWxlICgobWF0Y2ggPSB0aGlzLnRva2VuaXplci5ydWxlcy5pbmxpbmUucmVmbGlua1NlYXJjaC5leGVjKG1hc2tlZFNyYykpICE9IG51bGwpIHtcbiAgICAgICAgICBpZiAobGlua3MuaW5jbHVkZXMobWF0Y2hbMF0uc2xpY2UobWF0Y2hbMF0ubGFzdEluZGV4T2YoJ1snKSArIDEsIC0xKSkpIHtcbiAgICAgICAgICAgIG1hc2tlZFNyYyA9IG1hc2tlZFNyYy5zbGljZSgwLCBtYXRjaC5pbmRleCkgKyAnWycgKyByZXBlYXRTdHJpbmcoJ2EnLCBtYXRjaFswXS5sZW5ndGggLSAyKSArICddJyArIG1hc2tlZFNyYy5zbGljZSh0aGlzLnRva2VuaXplci5ydWxlcy5pbmxpbmUucmVmbGlua1NlYXJjaC5sYXN0SW5kZXgpO1xuICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cbiAgICAvLyBNYXNrIG91dCBvdGhlciBibG9ja3NcbiAgICB3aGlsZSAoKG1hdGNoID0gdGhpcy50b2tlbml6ZXIucnVsZXMuaW5saW5lLmJsb2NrU2tpcC5leGVjKG1hc2tlZFNyYykpICE9IG51bGwpIHtcbiAgICAgIG1hc2tlZFNyYyA9IG1hc2tlZFNyYy5zbGljZSgwLCBtYXRjaC5pbmRleCkgKyAnWycgKyByZXBlYXRTdHJpbmcoJ2EnLCBtYXRjaFswXS5sZW5ndGggLSAyKSArICddJyArIG1hc2tlZFNyYy5zbGljZSh0aGlzLnRva2VuaXplci5ydWxlcy5pbmxpbmUuYmxvY2tTa2lwLmxhc3RJbmRleCk7XG4gICAgfVxuXG4gICAgLy8gTWFzayBvdXQgZXNjYXBlZCBlbSAmIHN0cm9uZyBkZWxpbWl0ZXJzXG4gICAgd2hpbGUgKChtYXRjaCA9IHRoaXMudG9rZW5pemVyLnJ1bGVzLmlubGluZS5lc2NhcGVkRW1TdC5leGVjKG1hc2tlZFNyYykpICE9IG51bGwpIHtcbiAgICAgIG1hc2tlZFNyYyA9IG1hc2tlZFNyYy5zbGljZSgwLCBtYXRjaC5pbmRleCkgKyAnKysnICsgbWFza2VkU3JjLnNsaWNlKHRoaXMudG9rZW5pemVyLnJ1bGVzLmlubGluZS5lc2NhcGVkRW1TdC5sYXN0SW5kZXgpO1xuICAgIH1cblxuICAgIHdoaWxlIChzcmMpIHtcbiAgICAgIGlmICgha2VlcFByZXZDaGFyKSB7XG4gICAgICAgIHByZXZDaGFyID0gJyc7XG4gICAgICB9XG4gICAgICBrZWVwUHJldkNoYXIgPSBmYWxzZTtcblxuICAgICAgLy8gZXh0ZW5zaW9uc1xuICAgICAgaWYgKHRoaXMub3B0aW9ucy5leHRlbnNpb25zXG4gICAgICAgICYmIHRoaXMub3B0aW9ucy5leHRlbnNpb25zLmlubGluZVxuICAgICAgICAmJiB0aGlzLm9wdGlvbnMuZXh0ZW5zaW9ucy5pbmxpbmUuc29tZSgoZXh0VG9rZW5pemVyKSA9PiB7XG4gICAgICAgICAgaWYgKHRva2VuID0gZXh0VG9rZW5pemVyLmNhbGwoeyBsZXhlcjogdGhpcyB9LCBzcmMsIHRva2VucykpIHtcbiAgICAgICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgICAgICByZXR1cm4gdHJ1ZTtcbiAgICAgICAgICB9XG4gICAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgICB9KSkge1xuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgLy8gZXNjYXBlXG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5lc2NhcGUoc3JjKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIGNvbnRpbnVlO1xuICAgICAgfVxuXG4gICAgICAvLyB0YWdcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLnRhZyhzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIGxhc3RUb2tlbiA9IHRva2Vuc1t0b2tlbnMubGVuZ3RoIC0gMV07XG4gICAgICAgIGlmIChsYXN0VG9rZW4gJiYgdG9rZW4udHlwZSA9PT0gJ3RleHQnICYmIGxhc3RUb2tlbi50eXBlID09PSAndGV4dCcpIHtcbiAgICAgICAgICBsYXN0VG9rZW4ucmF3ICs9IHRva2VuLnJhdztcbiAgICAgICAgICBsYXN0VG9rZW4udGV4dCArPSB0b2tlbi50ZXh0O1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgfVxuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgLy8gbGlua1xuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIubGluayhzcmMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIHJlZmxpbmssIG5vbGlua1xuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIucmVmbGluayhzcmMsIHRoaXMudG9rZW5zLmxpbmtzKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICBsYXN0VG9rZW4gPSB0b2tlbnNbdG9rZW5zLmxlbmd0aCAtIDFdO1xuICAgICAgICBpZiAobGFzdFRva2VuICYmIHRva2VuLnR5cGUgPT09ICd0ZXh0JyAmJiBsYXN0VG9rZW4udHlwZSA9PT0gJ3RleHQnKSB7XG4gICAgICAgICAgbGFzdFRva2VuLnJhdyArPSB0b2tlbi5yYXc7XG4gICAgICAgICAgbGFzdFRva2VuLnRleHQgKz0gdG9rZW4udGV4dDtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIH1cbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGVtICYgc3Ryb25nXG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5lbVN0cm9uZyhzcmMsIG1hc2tlZFNyYywgcHJldkNoYXIpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGNvZGVcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLmNvZGVzcGFuKHNyYykpIHtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgdG9rZW5zLnB1c2godG9rZW4pO1xuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgLy8gYnJcbiAgICAgIGlmICh0b2tlbiA9IHRoaXMudG9rZW5pemVyLmJyKHNyYykpIHtcbiAgICAgICAgc3JjID0gc3JjLnN1YnN0cmluZyh0b2tlbi5yYXcubGVuZ3RoKTtcbiAgICAgICAgdG9rZW5zLnB1c2godG9rZW4pO1xuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgLy8gZGVsIChnZm0pXG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5kZWwoc3JjKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIGNvbnRpbnVlO1xuICAgICAgfVxuXG4gICAgICAvLyBhdXRvbGlua1xuICAgICAgaWYgKHRva2VuID0gdGhpcy50b2tlbml6ZXIuYXV0b2xpbmsoc3JjLCBtYW5nbGUpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIHRva2Vucy5wdXNoKHRva2VuKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIC8vIHVybCAoZ2ZtKVxuICAgICAgaWYgKCF0aGlzLnN0YXRlLmluTGluayAmJiAodG9rZW4gPSB0aGlzLnRva2VuaXplci51cmwoc3JjLCBtYW5nbGUpKSkge1xuICAgICAgICBzcmMgPSBzcmMuc3Vic3RyaW5nKHRva2VuLnJhdy5sZW5ndGgpO1xuICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIGNvbnRpbnVlO1xuICAgICAgfVxuXG4gICAgICAvLyB0ZXh0XG4gICAgICAvLyBwcmV2ZW50IGlubGluZVRleHQgY29uc3VtaW5nIGV4dGVuc2lvbnMgYnkgY2xpcHBpbmcgJ3NyYycgdG8gZXh0ZW5zaW9uIHN0YXJ0XG4gICAgICBjdXRTcmMgPSBzcmM7XG4gICAgICBpZiAodGhpcy5vcHRpb25zLmV4dGVuc2lvbnMgJiYgdGhpcy5vcHRpb25zLmV4dGVuc2lvbnMuc3RhcnRJbmxpbmUpIHtcbiAgICAgICAgbGV0IHN0YXJ0SW5kZXggPSBJbmZpbml0eTtcbiAgICAgICAgY29uc3QgdGVtcFNyYyA9IHNyYy5zbGljZSgxKTtcbiAgICAgICAgbGV0IHRlbXBTdGFydDtcbiAgICAgICAgdGhpcy5vcHRpb25zLmV4dGVuc2lvbnMuc3RhcnRJbmxpbmUuZm9yRWFjaChmdW5jdGlvbihnZXRTdGFydEluZGV4KSB7XG4gICAgICAgICAgdGVtcFN0YXJ0ID0gZ2V0U3RhcnRJbmRleC5jYWxsKHsgbGV4ZXI6IHRoaXMgfSwgdGVtcFNyYyk7XG4gICAgICAgICAgaWYgKHR5cGVvZiB0ZW1wU3RhcnQgPT09ICdudW1iZXInICYmIHRlbXBTdGFydCA+PSAwKSB7IHN0YXJ0SW5kZXggPSBNYXRoLm1pbihzdGFydEluZGV4LCB0ZW1wU3RhcnQpOyB9XG4gICAgICAgIH0pO1xuICAgICAgICBpZiAoc3RhcnRJbmRleCA8IEluZmluaXR5ICYmIHN0YXJ0SW5kZXggPj0gMCkge1xuICAgICAgICAgIGN1dFNyYyA9IHNyYy5zdWJzdHJpbmcoMCwgc3RhcnRJbmRleCArIDEpO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgICBpZiAodG9rZW4gPSB0aGlzLnRva2VuaXplci5pbmxpbmVUZXh0KGN1dFNyYywgc21hcnR5cGFudHMpKSB7XG4gICAgICAgIHNyYyA9IHNyYy5zdWJzdHJpbmcodG9rZW4ucmF3Lmxlbmd0aCk7XG4gICAgICAgIGlmICh0b2tlbi5yYXcuc2xpY2UoLTEpICE9PSAnXycpIHsgLy8gVHJhY2sgcHJldkNoYXIgYmVmb3JlIHN0cmluZyBvZiBfX19fIHN0YXJ0ZWRcbiAgICAgICAgICBwcmV2Q2hhciA9IHRva2VuLnJhdy5zbGljZSgtMSk7XG4gICAgICAgIH1cbiAgICAgICAga2VlcFByZXZDaGFyID0gdHJ1ZTtcbiAgICAgICAgbGFzdFRva2VuID0gdG9rZW5zW3Rva2Vucy5sZW5ndGggLSAxXTtcbiAgICAgICAgaWYgKGxhc3RUb2tlbiAmJiBsYXN0VG9rZW4udHlwZSA9PT0gJ3RleHQnKSB7XG4gICAgICAgICAgbGFzdFRva2VuLnJhdyArPSB0b2tlbi5yYXc7XG4gICAgICAgICAgbGFzdFRva2VuLnRleHQgKz0gdG9rZW4udGV4dDtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB0b2tlbnMucHVzaCh0b2tlbik7XG4gICAgICAgIH1cbiAgICAgICAgY29udGludWU7XG4gICAgICB9XG5cbiAgICAgIGlmIChzcmMpIHtcbiAgICAgICAgY29uc3QgZXJyTXNnID0gJ0luZmluaXRlIGxvb3Agb24gYnl0ZTogJyArIHNyYy5jaGFyQ29kZUF0KDApO1xuICAgICAgICBpZiAodGhpcy5vcHRpb25zLnNpbGVudCkge1xuICAgICAgICAgIGNvbnNvbGUuZXJyb3IoZXJyTXNnKTtcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoZXJyTXNnKTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cblxuICAgIHJldHVybiB0b2tlbnM7XG4gIH1cbn1cblxuLyoqXG4gKiBSZW5kZXJlclxuICovXG5jbGFzcyBSZW5kZXJlciB7XG4gIGNvbnN0cnVjdG9yKG9wdGlvbnMpIHtcbiAgICB0aGlzLm9wdGlvbnMgPSBvcHRpb25zIHx8IGRlZmF1bHRzO1xuICB9XG5cbiAgY29kZShjb2RlLCBpbmZvc3RyaW5nLCBlc2NhcGVkKSB7XG4gICAgY29uc3QgbGFuZyA9IChpbmZvc3RyaW5nIHx8ICcnKS5tYXRjaCgvXFxTKi8pWzBdO1xuICAgIGlmICh0aGlzLm9wdGlvbnMuaGlnaGxpZ2h0KSB7XG4gICAgICBjb25zdCBvdXQgPSB0aGlzLm9wdGlvbnMuaGlnaGxpZ2h0KGNvZGUsIGxhbmcpO1xuICAgICAgaWYgKG91dCAhPSBudWxsICYmIG91dCAhPT0gY29kZSkge1xuICAgICAgICBlc2NhcGVkID0gdHJ1ZTtcbiAgICAgICAgY29kZSA9IG91dDtcbiAgICAgIH1cbiAgICB9XG5cbiAgICBjb2RlID0gY29kZS5yZXBsYWNlKC9cXG4kLywgJycpICsgJ1xcbic7XG5cbiAgICBpZiAoIWxhbmcpIHtcbiAgICAgIHJldHVybiAnPHByZT48Y29kZT4nXG4gICAgICAgICsgKGVzY2FwZWQgPyBjb2RlIDogZXNjYXBlKGNvZGUsIHRydWUpKVxuICAgICAgICArICc8L2NvZGU+PC9wcmU+XFxuJztcbiAgICB9XG5cbiAgICByZXR1cm4gJzxwcmU+PGNvZGUgY2xhc3M9XCInXG4gICAgICArIHRoaXMub3B0aW9ucy5sYW5nUHJlZml4XG4gICAgICArIGVzY2FwZShsYW5nLCB0cnVlKVxuICAgICAgKyAnXCI+J1xuICAgICAgKyAoZXNjYXBlZCA/IGNvZGUgOiBlc2NhcGUoY29kZSwgdHJ1ZSkpXG4gICAgICArICc8L2NvZGU+PC9wcmU+XFxuJztcbiAgfVxuXG4gIGJsb2NrcXVvdGUocXVvdGUpIHtcbiAgICByZXR1cm4gJzxibG9ja3F1b3RlPlxcbicgKyBxdW90ZSArICc8L2Jsb2NrcXVvdGU+XFxuJztcbiAgfVxuXG4gIGh0bWwoaHRtbCkge1xuICAgIHJldHVybiBodG1sO1xuICB9XG5cbiAgaGVhZGluZyh0ZXh0LCBsZXZlbCwgcmF3LCBzbHVnZ2VyKSB7XG4gICAgaWYgKHRoaXMub3B0aW9ucy5oZWFkZXJJZHMpIHtcbiAgICAgIHJldHVybiAnPGgnXG4gICAgICAgICsgbGV2ZWxcbiAgICAgICAgKyAnIGlkPVwiJ1xuICAgICAgICArIHRoaXMub3B0aW9ucy5oZWFkZXJQcmVmaXhcbiAgICAgICAgKyBzbHVnZ2VyLnNsdWcocmF3KVxuICAgICAgICArICdcIj4nXG4gICAgICAgICsgdGV4dFxuICAgICAgICArICc8L2gnXG4gICAgICAgICsgbGV2ZWxcbiAgICAgICAgKyAnPlxcbic7XG4gICAgfVxuICAgIC8vIGlnbm9yZSBJRHNcbiAgICByZXR1cm4gJzxoJyArIGxldmVsICsgJz4nICsgdGV4dCArICc8L2gnICsgbGV2ZWwgKyAnPlxcbic7XG4gIH1cblxuICBocigpIHtcbiAgICByZXR1cm4gdGhpcy5vcHRpb25zLnhodG1sID8gJzxoci8+XFxuJyA6ICc8aHI+XFxuJztcbiAgfVxuXG4gIGxpc3QoYm9keSwgb3JkZXJlZCwgc3RhcnQpIHtcbiAgICBjb25zdCB0eXBlID0gb3JkZXJlZCA/ICdvbCcgOiAndWwnLFxuICAgICAgc3RhcnRhdHQgPSAob3JkZXJlZCAmJiBzdGFydCAhPT0gMSkgPyAoJyBzdGFydD1cIicgKyBzdGFydCArICdcIicpIDogJyc7XG4gICAgcmV0dXJuICc8JyArIHR5cGUgKyBzdGFydGF0dCArICc+XFxuJyArIGJvZHkgKyAnPC8nICsgdHlwZSArICc+XFxuJztcbiAgfVxuXG4gIGxpc3RpdGVtKHRleHQpIHtcbiAgICByZXR1cm4gJzxsaT4nICsgdGV4dCArICc8L2xpPlxcbic7XG4gIH1cblxuICBjaGVja2JveChjaGVja2VkKSB7XG4gICAgcmV0dXJuICc8aW5wdXQgJ1xuICAgICAgKyAoY2hlY2tlZCA/ICdjaGVja2VkPVwiXCIgJyA6ICcnKVxuICAgICAgKyAnZGlzYWJsZWQ9XCJcIiB0eXBlPVwiY2hlY2tib3hcIidcbiAgICAgICsgKHRoaXMub3B0aW9ucy54aHRtbCA/ICcgLycgOiAnJylcbiAgICAgICsgJz4gJztcbiAgfVxuXG4gIHBhcmFncmFwaCh0ZXh0KSB7XG4gICAgcmV0dXJuICc8cD4nICsgdGV4dCArICc8L3A+XFxuJztcbiAgfVxuXG4gIHRhYmxlKGhlYWRlciwgYm9keSkge1xuICAgIGlmIChib2R5KSBib2R5ID0gJzx0Ym9keT4nICsgYm9keSArICc8L3Rib2R5Pic7XG5cbiAgICByZXR1cm4gJzx0YWJsZT5cXG4nXG4gICAgICArICc8dGhlYWQ+XFxuJ1xuICAgICAgKyBoZWFkZXJcbiAgICAgICsgJzwvdGhlYWQ+XFxuJ1xuICAgICAgKyBib2R5XG4gICAgICArICc8L3RhYmxlPlxcbic7XG4gIH1cblxuICB0YWJsZXJvdyhjb250ZW50KSB7XG4gICAgcmV0dXJuICc8dHI+XFxuJyArIGNvbnRlbnQgKyAnPC90cj5cXG4nO1xuICB9XG5cbiAgdGFibGVjZWxsKGNvbnRlbnQsIGZsYWdzKSB7XG4gICAgY29uc3QgdHlwZSA9IGZsYWdzLmhlYWRlciA/ICd0aCcgOiAndGQnO1xuICAgIGNvbnN0IHRhZyA9IGZsYWdzLmFsaWduXG4gICAgICA/ICc8JyArIHR5cGUgKyAnIGFsaWduPVwiJyArIGZsYWdzLmFsaWduICsgJ1wiPidcbiAgICAgIDogJzwnICsgdHlwZSArICc+JztcbiAgICByZXR1cm4gdGFnICsgY29udGVudCArICc8LycgKyB0eXBlICsgJz5cXG4nO1xuICB9XG5cbiAgLy8gc3BhbiBsZXZlbCByZW5kZXJlclxuICBzdHJvbmcodGV4dCkge1xuICAgIHJldHVybiAnPHN0cm9uZz4nICsgdGV4dCArICc8L3N0cm9uZz4nO1xuICB9XG5cbiAgZW0odGV4dCkge1xuICAgIHJldHVybiAnPGVtPicgKyB0ZXh0ICsgJzwvZW0+JztcbiAgfVxuXG4gIGNvZGVzcGFuKHRleHQpIHtcbiAgICByZXR1cm4gJzxjb2RlPicgKyB0ZXh0ICsgJzwvY29kZT4nO1xuICB9XG5cbiAgYnIoKSB7XG4gICAgcmV0dXJuIHRoaXMub3B0aW9ucy54aHRtbCA/ICc8YnIvPicgOiAnPGJyPic7XG4gIH1cblxuICBkZWwodGV4dCkge1xuICAgIHJldHVybiAnPGRlbD4nICsgdGV4dCArICc8L2RlbD4nO1xuICB9XG5cbiAgbGluayhocmVmLCB0aXRsZSwgdGV4dCkge1xuICAgIGhyZWYgPSBjbGVhblVybCh0aGlzLm9wdGlvbnMuc2FuaXRpemUsIHRoaXMub3B0aW9ucy5iYXNlVXJsLCBocmVmKTtcbiAgICBpZiAoaHJlZiA9PT0gbnVsbCkge1xuICAgICAgcmV0dXJuIHRleHQ7XG4gICAgfVxuICAgIGxldCBvdXQgPSAnPGEgaHJlZj1cIicgKyBlc2NhcGUoaHJlZikgKyAnXCInO1xuICAgIGlmICh0aXRsZSkge1xuICAgICAgb3V0ICs9ICcgdGl0bGU9XCInICsgdGl0bGUgKyAnXCInO1xuICAgIH1cbiAgICBvdXQgKz0gJz4nICsgdGV4dCArICc8L2E+JztcbiAgICByZXR1cm4gb3V0O1xuICB9XG5cbiAgaW1hZ2UoaHJlZiwgdGl0bGUsIHRleHQpIHtcbiAgICBocmVmID0gY2xlYW5VcmwodGhpcy5vcHRpb25zLnNhbml0aXplLCB0aGlzLm9wdGlvbnMuYmFzZVVybCwgaHJlZik7XG4gICAgaWYgKGhyZWYgPT09IG51bGwpIHtcbiAgICAgIHJldHVybiB0ZXh0O1xuICAgIH1cblxuICAgIGxldCBvdXQgPSAnPGltZyBzcmM9XCInICsgaHJlZiArICdcIiBhbHQ9XCInICsgdGV4dCArICdcIic7XG4gICAgaWYgKHRpdGxlKSB7XG4gICAgICBvdXQgKz0gJyB0aXRsZT1cIicgKyB0aXRsZSArICdcIic7XG4gICAgfVxuICAgIG91dCArPSB0aGlzLm9wdGlvbnMueGh0bWwgPyAnLz4nIDogJz4nO1xuICAgIHJldHVybiBvdXQ7XG4gIH1cblxuICB0ZXh0KHRleHQpIHtcbiAgICByZXR1cm4gdGV4dDtcbiAgfVxufVxuXG4vKipcbiAqIFRleHRSZW5kZXJlclxuICogcmV0dXJucyBvbmx5IHRoZSB0ZXh0dWFsIHBhcnQgb2YgdGhlIHRva2VuXG4gKi9cbmNsYXNzIFRleHRSZW5kZXJlciB7XG4gIC8vIG5vIG5lZWQgZm9yIGJsb2NrIGxldmVsIHJlbmRlcmVyc1xuICBzdHJvbmcodGV4dCkge1xuICAgIHJldHVybiB0ZXh0O1xuICB9XG5cbiAgZW0odGV4dCkge1xuICAgIHJldHVybiB0ZXh0O1xuICB9XG5cbiAgY29kZXNwYW4odGV4dCkge1xuICAgIHJldHVybiB0ZXh0O1xuICB9XG5cbiAgZGVsKHRleHQpIHtcbiAgICByZXR1cm4gdGV4dDtcbiAgfVxuXG4gIGh0bWwodGV4dCkge1xuICAgIHJldHVybiB0ZXh0O1xuICB9XG5cbiAgdGV4dCh0ZXh0KSB7XG4gICAgcmV0dXJuIHRleHQ7XG4gIH1cblxuICBsaW5rKGhyZWYsIHRpdGxlLCB0ZXh0KSB7XG4gICAgcmV0dXJuICcnICsgdGV4dDtcbiAgfVxuXG4gIGltYWdlKGhyZWYsIHRpdGxlLCB0ZXh0KSB7XG4gICAgcmV0dXJuICcnICsgdGV4dDtcbiAgfVxuXG4gIGJyKCkge1xuICAgIHJldHVybiAnJztcbiAgfVxufVxuXG4vKipcbiAqIFNsdWdnZXIgZ2VuZXJhdGVzIGhlYWRlciBpZFxuICovXG5jbGFzcyBTbHVnZ2VyIHtcbiAgY29uc3RydWN0b3IoKSB7XG4gICAgdGhpcy5zZWVuID0ge307XG4gIH1cblxuICBzZXJpYWxpemUodmFsdWUpIHtcbiAgICByZXR1cm4gdmFsdWVcbiAgICAgIC50b0xvd2VyQ2FzZSgpXG4gICAgICAudHJpbSgpXG4gICAgICAvLyByZW1vdmUgaHRtbCB0YWdzXG4gICAgICAucmVwbGFjZSgvPFshXFwvYS16XS4qPz4vaWcsICcnKVxuICAgICAgLy8gcmVtb3ZlIHVud2FudGVkIGNoYXJzXG4gICAgICAucmVwbGFjZSgvW1xcdTIwMDAtXFx1MjA2RlxcdTJFMDAtXFx1MkU3RlxcXFwnIVwiIyQlJigpKissLi86Ozw9Pj9AW1xcXV5ge3x9fl0vZywgJycpXG4gICAgICAucmVwbGFjZSgvXFxzL2csICctJyk7XG4gIH1cblxuICAvKipcbiAgICogRmluZHMgdGhlIG5leHQgc2FmZSAodW5pcXVlKSBzbHVnIHRvIHVzZVxuICAgKi9cbiAgZ2V0TmV4dFNhZmVTbHVnKG9yaWdpbmFsU2x1ZywgaXNEcnlSdW4pIHtcbiAgICBsZXQgc2x1ZyA9IG9yaWdpbmFsU2x1ZztcbiAgICBsZXQgb2NjdXJlbmNlQWNjdW11bGF0b3IgPSAwO1xuICAgIGlmICh0aGlzLnNlZW4uaGFzT3duUHJvcGVydHkoc2x1ZykpIHtcbiAgICAgIG9jY3VyZW5jZUFjY3VtdWxhdG9yID0gdGhpcy5zZWVuW29yaWdpbmFsU2x1Z107XG4gICAgICBkbyB7XG4gICAgICAgIG9jY3VyZW5jZUFjY3VtdWxhdG9yKys7XG4gICAgICAgIHNsdWcgPSBvcmlnaW5hbFNsdWcgKyAnLScgKyBvY2N1cmVuY2VBY2N1bXVsYXRvcjtcbiAgICAgIH0gd2hpbGUgKHRoaXMuc2Vlbi5oYXNPd25Qcm9wZXJ0eShzbHVnKSk7XG4gICAgfVxuICAgIGlmICghaXNEcnlSdW4pIHtcbiAgICAgIHRoaXMuc2VlbltvcmlnaW5hbFNsdWddID0gb2NjdXJlbmNlQWNjdW11bGF0b3I7XG4gICAgICB0aGlzLnNlZW5bc2x1Z10gPSAwO1xuICAgIH1cbiAgICByZXR1cm4gc2x1ZztcbiAgfVxuXG4gIC8qKlxuICAgKiBDb252ZXJ0IHN0cmluZyB0byB1bmlxdWUgaWRcbiAgICogQHBhcmFtIHtvYmplY3R9IG9wdGlvbnNcbiAgICogQHBhcmFtIHtib29sZWFufSBvcHRpb25zLmRyeXJ1biBHZW5lcmF0ZXMgdGhlIG5leHQgdW5pcXVlIHNsdWcgd2l0aG91dCB1cGRhdGluZyB0aGUgaW50ZXJuYWwgYWNjdW11bGF0b3IuXG4gICAqL1xuICBzbHVnKHZhbHVlLCBvcHRpb25zID0ge30pIHtcbiAgICBjb25zdCBzbHVnID0gdGhpcy5zZXJpYWxpemUodmFsdWUpO1xuICAgIHJldHVybiB0aGlzLmdldE5leHRTYWZlU2x1ZyhzbHVnLCBvcHRpb25zLmRyeXJ1bik7XG4gIH1cbn1cblxuLyoqXG4gKiBQYXJzaW5nICYgQ29tcGlsaW5nXG4gKi9cbmNsYXNzIFBhcnNlciB7XG4gIGNvbnN0cnVjdG9yKG9wdGlvbnMpIHtcbiAgICB0aGlzLm9wdGlvbnMgPSBvcHRpb25zIHx8IGRlZmF1bHRzO1xuICAgIHRoaXMub3B0aW9ucy5yZW5kZXJlciA9IHRoaXMub3B0aW9ucy5yZW5kZXJlciB8fCBuZXcgUmVuZGVyZXIoKTtcbiAgICB0aGlzLnJlbmRlcmVyID0gdGhpcy5vcHRpb25zLnJlbmRlcmVyO1xuICAgIHRoaXMucmVuZGVyZXIub3B0aW9ucyA9IHRoaXMub3B0aW9ucztcbiAgICB0aGlzLnRleHRSZW5kZXJlciA9IG5ldyBUZXh0UmVuZGVyZXIoKTtcbiAgICB0aGlzLnNsdWdnZXIgPSBuZXcgU2x1Z2dlcigpO1xuICB9XG5cbiAgLyoqXG4gICAqIFN0YXRpYyBQYXJzZSBNZXRob2RcbiAgICovXG4gIHN0YXRpYyBwYXJzZSh0b2tlbnMsIG9wdGlvbnMpIHtcbiAgICBjb25zdCBwYXJzZXIgPSBuZXcgUGFyc2VyKG9wdGlvbnMpO1xuICAgIHJldHVybiBwYXJzZXIucGFyc2UodG9rZW5zKTtcbiAgfVxuXG4gIC8qKlxuICAgKiBTdGF0aWMgUGFyc2UgSW5saW5lIE1ldGhvZFxuICAgKi9cbiAgc3RhdGljIHBhcnNlSW5saW5lKHRva2Vucywgb3B0aW9ucykge1xuICAgIGNvbnN0IHBhcnNlciA9IG5ldyBQYXJzZXIob3B0aW9ucyk7XG4gICAgcmV0dXJuIHBhcnNlci5wYXJzZUlubGluZSh0b2tlbnMpO1xuICB9XG5cbiAgLyoqXG4gICAqIFBhcnNlIExvb3BcbiAgICovXG4gIHBhcnNlKHRva2VucywgdG9wID0gdHJ1ZSkge1xuICAgIGxldCBvdXQgPSAnJyxcbiAgICAgIGksXG4gICAgICBqLFxuICAgICAgayxcbiAgICAgIGwyLFxuICAgICAgbDMsXG4gICAgICByb3csXG4gICAgICBjZWxsLFxuICAgICAgaGVhZGVyLFxuICAgICAgYm9keSxcbiAgICAgIHRva2VuLFxuICAgICAgb3JkZXJlZCxcbiAgICAgIHN0YXJ0LFxuICAgICAgbG9vc2UsXG4gICAgICBpdGVtQm9keSxcbiAgICAgIGl0ZW0sXG4gICAgICBjaGVja2VkLFxuICAgICAgdGFzayxcbiAgICAgIGNoZWNrYm94LFxuICAgICAgcmV0O1xuXG4gICAgY29uc3QgbCA9IHRva2Vucy5sZW5ndGg7XG4gICAgZm9yIChpID0gMDsgaSA8IGw7IGkrKykge1xuICAgICAgdG9rZW4gPSB0b2tlbnNbaV07XG5cbiAgICAgIC8vIFJ1biBhbnkgcmVuZGVyZXIgZXh0ZW5zaW9uc1xuICAgICAgaWYgKHRoaXMub3B0aW9ucy5leHRlbnNpb25zICYmIHRoaXMub3B0aW9ucy5leHRlbnNpb25zLnJlbmRlcmVycyAmJiB0aGlzLm9wdGlvbnMuZXh0ZW5zaW9ucy5yZW5kZXJlcnNbdG9rZW4udHlwZV0pIHtcbiAgICAgICAgcmV0ID0gdGhpcy5vcHRpb25zLmV4dGVuc2lvbnMucmVuZGVyZXJzW3Rva2VuLnR5cGVdLmNhbGwoeyBwYXJzZXI6IHRoaXMgfSwgdG9rZW4pO1xuICAgICAgICBpZiAocmV0ICE9PSBmYWxzZSB8fCAhWydzcGFjZScsICdocicsICdoZWFkaW5nJywgJ2NvZGUnLCAndGFibGUnLCAnYmxvY2txdW90ZScsICdsaXN0JywgJ2h0bWwnLCAncGFyYWdyYXBoJywgJ3RleHQnXS5pbmNsdWRlcyh0b2tlbi50eXBlKSkge1xuICAgICAgICAgIG91dCArPSByZXQgfHwgJyc7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH1cbiAgICAgIH1cblxuICAgICAgc3dpdGNoICh0b2tlbi50eXBlKSB7XG4gICAgICAgIGNhc2UgJ3NwYWNlJzoge1xuICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICB9XG4gICAgICAgIGNhc2UgJ2hyJzoge1xuICAgICAgICAgIG91dCArPSB0aGlzLnJlbmRlcmVyLmhyKCk7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAnaGVhZGluZyc6IHtcbiAgICAgICAgICBvdXQgKz0gdGhpcy5yZW5kZXJlci5oZWFkaW5nKFxuICAgICAgICAgICAgdGhpcy5wYXJzZUlubGluZSh0b2tlbi50b2tlbnMpLFxuICAgICAgICAgICAgdG9rZW4uZGVwdGgsXG4gICAgICAgICAgICB1bmVzY2FwZSh0aGlzLnBhcnNlSW5saW5lKHRva2VuLnRva2VucywgdGhpcy50ZXh0UmVuZGVyZXIpKSxcbiAgICAgICAgICAgIHRoaXMuc2x1Z2dlcik7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAnY29kZSc6IHtcbiAgICAgICAgICBvdXQgKz0gdGhpcy5yZW5kZXJlci5jb2RlKHRva2VuLnRleHQsXG4gICAgICAgICAgICB0b2tlbi5sYW5nLFxuICAgICAgICAgICAgdG9rZW4uZXNjYXBlZCk7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAndGFibGUnOiB7XG4gICAgICAgICAgaGVhZGVyID0gJyc7XG5cbiAgICAgICAgICAvLyBoZWFkZXJcbiAgICAgICAgICBjZWxsID0gJyc7XG4gICAgICAgICAgbDIgPSB0b2tlbi5oZWFkZXIubGVuZ3RoO1xuICAgICAgICAgIGZvciAoaiA9IDA7IGogPCBsMjsgaisrKSB7XG4gICAgICAgICAgICBjZWxsICs9IHRoaXMucmVuZGVyZXIudGFibGVjZWxsKFxuICAgICAgICAgICAgICB0aGlzLnBhcnNlSW5saW5lKHRva2VuLmhlYWRlcltqXS50b2tlbnMpLFxuICAgICAgICAgICAgICB7IGhlYWRlcjogdHJ1ZSwgYWxpZ246IHRva2VuLmFsaWduW2pdIH1cbiAgICAgICAgICAgICk7XG4gICAgICAgICAgfVxuICAgICAgICAgIGhlYWRlciArPSB0aGlzLnJlbmRlcmVyLnRhYmxlcm93KGNlbGwpO1xuXG4gICAgICAgICAgYm9keSA9ICcnO1xuICAgICAgICAgIGwyID0gdG9rZW4ucm93cy5sZW5ndGg7XG4gICAgICAgICAgZm9yIChqID0gMDsgaiA8IGwyOyBqKyspIHtcbiAgICAgICAgICAgIHJvdyA9IHRva2VuLnJvd3Nbal07XG5cbiAgICAgICAgICAgIGNlbGwgPSAnJztcbiAgICAgICAgICAgIGwzID0gcm93Lmxlbmd0aDtcbiAgICAgICAgICAgIGZvciAoayA9IDA7IGsgPCBsMzsgaysrKSB7XG4gICAgICAgICAgICAgIGNlbGwgKz0gdGhpcy5yZW5kZXJlci50YWJsZWNlbGwoXG4gICAgICAgICAgICAgICAgdGhpcy5wYXJzZUlubGluZShyb3dba10udG9rZW5zKSxcbiAgICAgICAgICAgICAgICB7IGhlYWRlcjogZmFsc2UsIGFsaWduOiB0b2tlbi5hbGlnbltrXSB9XG4gICAgICAgICAgICAgICk7XG4gICAgICAgICAgICB9XG5cbiAgICAgICAgICAgIGJvZHkgKz0gdGhpcy5yZW5kZXJlci50YWJsZXJvdyhjZWxsKTtcbiAgICAgICAgICB9XG4gICAgICAgICAgb3V0ICs9IHRoaXMucmVuZGVyZXIudGFibGUoaGVhZGVyLCBib2R5KTtcbiAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgfVxuICAgICAgICBjYXNlICdibG9ja3F1b3RlJzoge1xuICAgICAgICAgIGJvZHkgPSB0aGlzLnBhcnNlKHRva2VuLnRva2Vucyk7XG4gICAgICAgICAgb3V0ICs9IHRoaXMucmVuZGVyZXIuYmxvY2txdW90ZShib2R5KTtcbiAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgfVxuICAgICAgICBjYXNlICdsaXN0Jzoge1xuICAgICAgICAgIG9yZGVyZWQgPSB0b2tlbi5vcmRlcmVkO1xuICAgICAgICAgIHN0YXJ0ID0gdG9rZW4uc3RhcnQ7XG4gICAgICAgICAgbG9vc2UgPSB0b2tlbi5sb29zZTtcbiAgICAgICAgICBsMiA9IHRva2VuLml0ZW1zLmxlbmd0aDtcblxuICAgICAgICAgIGJvZHkgPSAnJztcbiAgICAgICAgICBmb3IgKGogPSAwOyBqIDwgbDI7IGorKykge1xuICAgICAgICAgICAgaXRlbSA9IHRva2VuLml0ZW1zW2pdO1xuICAgICAgICAgICAgY2hlY2tlZCA9IGl0ZW0uY2hlY2tlZDtcbiAgICAgICAgICAgIHRhc2sgPSBpdGVtLnRhc2s7XG5cbiAgICAgICAgICAgIGl0ZW1Cb2R5ID0gJyc7XG4gICAgICAgICAgICBpZiAoaXRlbS50YXNrKSB7XG4gICAgICAgICAgICAgIGNoZWNrYm94ID0gdGhpcy5yZW5kZXJlci5jaGVja2JveChjaGVja2VkKTtcbiAgICAgICAgICAgICAgaWYgKGxvb3NlKSB7XG4gICAgICAgICAgICAgICAgaWYgKGl0ZW0udG9rZW5zLmxlbmd0aCA+IDAgJiYgaXRlbS50b2tlbnNbMF0udHlwZSA9PT0gJ3BhcmFncmFwaCcpIHtcbiAgICAgICAgICAgICAgICAgIGl0ZW0udG9rZW5zWzBdLnRleHQgPSBjaGVja2JveCArICcgJyArIGl0ZW0udG9rZW5zWzBdLnRleHQ7XG4gICAgICAgICAgICAgICAgICBpZiAoaXRlbS50b2tlbnNbMF0udG9rZW5zICYmIGl0ZW0udG9rZW5zWzBdLnRva2Vucy5sZW5ndGggPiAwICYmIGl0ZW0udG9rZW5zWzBdLnRva2Vuc1swXS50eXBlID09PSAndGV4dCcpIHtcbiAgICAgICAgICAgICAgICAgICAgaXRlbS50b2tlbnNbMF0udG9rZW5zWzBdLnRleHQgPSBjaGVja2JveCArICcgJyArIGl0ZW0udG9rZW5zWzBdLnRva2Vuc1swXS50ZXh0O1xuICAgICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgICAgICBpdGVtLnRva2Vucy51bnNoaWZ0KHtcbiAgICAgICAgICAgICAgICAgICAgdHlwZTogJ3RleHQnLFxuICAgICAgICAgICAgICAgICAgICB0ZXh0OiBjaGVja2JveFxuICAgICAgICAgICAgICAgICAgfSk7XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICAgIGl0ZW1Cb2R5ICs9IGNoZWNrYm94O1xuICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9XG5cbiAgICAgICAgICAgIGl0ZW1Cb2R5ICs9IHRoaXMucGFyc2UoaXRlbS50b2tlbnMsIGxvb3NlKTtcbiAgICAgICAgICAgIGJvZHkgKz0gdGhpcy5yZW5kZXJlci5saXN0aXRlbShpdGVtQm9keSwgdGFzaywgY2hlY2tlZCk7XG4gICAgICAgICAgfVxuXG4gICAgICAgICAgb3V0ICs9IHRoaXMucmVuZGVyZXIubGlzdChib2R5LCBvcmRlcmVkLCBzdGFydCk7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAnaHRtbCc6IHtcbiAgICAgICAgICAvLyBUT0RPIHBhcnNlIGlubGluZSBjb250ZW50IGlmIHBhcmFtZXRlciBtYXJrZG93bj0xXG4gICAgICAgICAgb3V0ICs9IHRoaXMucmVuZGVyZXIuaHRtbCh0b2tlbi50ZXh0KTtcbiAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgfVxuICAgICAgICBjYXNlICdwYXJhZ3JhcGgnOiB7XG4gICAgICAgICAgb3V0ICs9IHRoaXMucmVuZGVyZXIucGFyYWdyYXBoKHRoaXMucGFyc2VJbmxpbmUodG9rZW4udG9rZW5zKSk7XG4gICAgICAgICAgY29udGludWU7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAndGV4dCc6IHtcbiAgICAgICAgICBib2R5ID0gdG9rZW4udG9rZW5zID8gdGhpcy5wYXJzZUlubGluZSh0b2tlbi50b2tlbnMpIDogdG9rZW4udGV4dDtcbiAgICAgICAgICB3aGlsZSAoaSArIDEgPCBsICYmIHRva2Vuc1tpICsgMV0udHlwZSA9PT0gJ3RleHQnKSB7XG4gICAgICAgICAgICB0b2tlbiA9IHRva2Vuc1srK2ldO1xuICAgICAgICAgICAgYm9keSArPSAnXFxuJyArICh0b2tlbi50b2tlbnMgPyB0aGlzLnBhcnNlSW5saW5lKHRva2VuLnRva2VucykgOiB0b2tlbi50ZXh0KTtcbiAgICAgICAgICB9XG4gICAgICAgICAgb3V0ICs9IHRvcCA/IHRoaXMucmVuZGVyZXIucGFyYWdyYXBoKGJvZHkpIDogYm9keTtcbiAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgfVxuXG4gICAgICAgIGRlZmF1bHQ6IHtcbiAgICAgICAgICBjb25zdCBlcnJNc2cgPSAnVG9rZW4gd2l0aCBcIicgKyB0b2tlbi50eXBlICsgJ1wiIHR5cGUgd2FzIG5vdCBmb3VuZC4nO1xuICAgICAgICAgIGlmICh0aGlzLm9wdGlvbnMuc2lsZW50KSB7XG4gICAgICAgICAgICBjb25zb2xlLmVycm9yKGVyck1zZyk7XG4gICAgICAgICAgICByZXR1cm47XG4gICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIHRocm93IG5ldyBFcnJvcihlcnJNc2cpO1xuICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cblxuICAgIHJldHVybiBvdXQ7XG4gIH1cblxuICAvKipcbiAgICogUGFyc2UgSW5saW5lIFRva2Vuc1xuICAgKi9cbiAgcGFyc2VJbmxpbmUodG9rZW5zLCByZW5kZXJlcikge1xuICAgIHJlbmRlcmVyID0gcmVuZGVyZXIgfHwgdGhpcy5yZW5kZXJlcjtcbiAgICBsZXQgb3V0ID0gJycsXG4gICAgICBpLFxuICAgICAgdG9rZW4sXG4gICAgICByZXQ7XG5cbiAgICBjb25zdCBsID0gdG9rZW5zLmxlbmd0aDtcbiAgICBmb3IgKGkgPSAwOyBpIDwgbDsgaSsrKSB7XG4gICAgICB0b2tlbiA9IHRva2Vuc1tpXTtcblxuICAgICAgLy8gUnVuIGFueSByZW5kZXJlciBleHRlbnNpb25zXG4gICAgICBpZiAodGhpcy5vcHRpb25zLmV4dGVuc2lvbnMgJiYgdGhpcy5vcHRpb25zLmV4dGVuc2lvbnMucmVuZGVyZXJzICYmIHRoaXMub3B0aW9ucy5leHRlbnNpb25zLnJlbmRlcmVyc1t0b2tlbi50eXBlXSkge1xuICAgICAgICByZXQgPSB0aGlzLm9wdGlvbnMuZXh0ZW5zaW9ucy5yZW5kZXJlcnNbdG9rZW4udHlwZV0uY2FsbCh7IHBhcnNlcjogdGhpcyB9LCB0b2tlbik7XG4gICAgICAgIGlmIChyZXQgIT09IGZhbHNlIHx8ICFbJ2VzY2FwZScsICdodG1sJywgJ2xpbmsnLCAnaW1hZ2UnLCAnc3Ryb25nJywgJ2VtJywgJ2NvZGVzcGFuJywgJ2JyJywgJ2RlbCcsICd0ZXh0J10uaW5jbHVkZXModG9rZW4udHlwZSkpIHtcbiAgICAgICAgICBvdXQgKz0gcmV0IHx8ICcnO1xuICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICB9XG4gICAgICB9XG5cbiAgICAgIHN3aXRjaCAodG9rZW4udHlwZSkge1xuICAgICAgICBjYXNlICdlc2NhcGUnOiB7XG4gICAgICAgICAgb3V0ICs9IHJlbmRlcmVyLnRleHQodG9rZW4udGV4dCk7XG4gICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAnaHRtbCc6IHtcbiAgICAgICAgICBvdXQgKz0gcmVuZGVyZXIuaHRtbCh0b2tlbi50ZXh0KTtcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfVxuICAgICAgICBjYXNlICdsaW5rJzoge1xuICAgICAgICAgIG91dCArPSByZW5kZXJlci5saW5rKHRva2VuLmhyZWYsIHRva2VuLnRpdGxlLCB0aGlzLnBhcnNlSW5saW5lKHRva2VuLnRva2VucywgcmVuZGVyZXIpKTtcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfVxuICAgICAgICBjYXNlICdpbWFnZSc6IHtcbiAgICAgICAgICBvdXQgKz0gcmVuZGVyZXIuaW1hZ2UodG9rZW4uaHJlZiwgdG9rZW4udGl0bGUsIHRva2VuLnRleHQpO1xuICAgICAgICAgIGJyZWFrO1xuICAgICAgICB9XG4gICAgICAgIGNhc2UgJ3N0cm9uZyc6IHtcbiAgICAgICAgICBvdXQgKz0gcmVuZGVyZXIuc3Ryb25nKHRoaXMucGFyc2VJbmxpbmUodG9rZW4udG9rZW5zLCByZW5kZXJlcikpO1xuICAgICAgICAgIGJyZWFrO1xuICAgICAgICB9XG4gICAgICAgIGNhc2UgJ2VtJzoge1xuICAgICAgICAgIG91dCArPSByZW5kZXJlci5lbSh0aGlzLnBhcnNlSW5saW5lKHRva2VuLnRva2VucywgcmVuZGVyZXIpKTtcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfVxuICAgICAgICBjYXNlICdjb2Rlc3Bhbic6IHtcbiAgICAgICAgICBvdXQgKz0gcmVuZGVyZXIuY29kZXNwYW4odG9rZW4udGV4dCk7XG4gICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAnYnInOiB7XG4gICAgICAgICAgb3V0ICs9IHJlbmRlcmVyLmJyKCk7XG4gICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAnZGVsJzoge1xuICAgICAgICAgIG91dCArPSByZW5kZXJlci5kZWwodGhpcy5wYXJzZUlubGluZSh0b2tlbi50b2tlbnMsIHJlbmRlcmVyKSk7XG4gICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cbiAgICAgICAgY2FzZSAndGV4dCc6IHtcbiAgICAgICAgICBvdXQgKz0gcmVuZGVyZXIudGV4dCh0b2tlbi50ZXh0KTtcbiAgICAgICAgICBicmVhaztcbiAgICAgICAgfVxuICAgICAgICBkZWZhdWx0OiB7XG4gICAgICAgICAgY29uc3QgZXJyTXNnID0gJ1Rva2VuIHdpdGggXCInICsgdG9rZW4udHlwZSArICdcIiB0eXBlIHdhcyBub3QgZm91bmQuJztcbiAgICAgICAgICBpZiAodGhpcy5vcHRpb25zLnNpbGVudCkge1xuICAgICAgICAgICAgY29uc29sZS5lcnJvcihlcnJNc2cpO1xuICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoZXJyTXNnKTtcbiAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gICAgcmV0dXJuIG91dDtcbiAgfVxufVxuXG4vKipcbiAqIE1hcmtlZFxuICovXG5mdW5jdGlvbiBtYXJrZWQoc3JjLCBvcHQsIGNhbGxiYWNrKSB7XG4gIC8vIHRocm93IGVycm9yIGluIGNhc2Ugb2Ygbm9uIHN0cmluZyBpbnB1dFxuICBpZiAodHlwZW9mIHNyYyA9PT0gJ3VuZGVmaW5lZCcgfHwgc3JjID09PSBudWxsKSB7XG4gICAgdGhyb3cgbmV3IEVycm9yKCdtYXJrZWQoKTogaW5wdXQgcGFyYW1ldGVyIGlzIHVuZGVmaW5lZCBvciBudWxsJyk7XG4gIH1cbiAgaWYgKHR5cGVvZiBzcmMgIT09ICdzdHJpbmcnKSB7XG4gICAgdGhyb3cgbmV3IEVycm9yKCdtYXJrZWQoKTogaW5wdXQgcGFyYW1ldGVyIGlzIG9mIHR5cGUgJ1xuICAgICAgKyBPYmplY3QucHJvdG90eXBlLnRvU3RyaW5nLmNhbGwoc3JjKSArICcsIHN0cmluZyBleHBlY3RlZCcpO1xuICB9XG5cbiAgaWYgKHR5cGVvZiBvcHQgPT09ICdmdW5jdGlvbicpIHtcbiAgICBjYWxsYmFjayA9IG9wdDtcbiAgICBvcHQgPSBudWxsO1xuICB9XG5cbiAgb3B0ID0gbWVyZ2Uoe30sIG1hcmtlZC5kZWZhdWx0cywgb3B0IHx8IHt9KTtcbiAgY2hlY2tTYW5pdGl6ZURlcHJlY2F0aW9uKG9wdCk7XG5cbiAgaWYgKGNhbGxiYWNrKSB7XG4gICAgY29uc3QgaGlnaGxpZ2h0ID0gb3B0LmhpZ2hsaWdodDtcbiAgICBsZXQgdG9rZW5zO1xuXG4gICAgdHJ5IHtcbiAgICAgIHRva2VucyA9IExleGVyLmxleChzcmMsIG9wdCk7XG4gICAgfSBjYXRjaCAoZSkge1xuICAgICAgcmV0dXJuIGNhbGxiYWNrKGUpO1xuICAgIH1cblxuICAgIGNvbnN0IGRvbmUgPSBmdW5jdGlvbihlcnIpIHtcbiAgICAgIGxldCBvdXQ7XG5cbiAgICAgIGlmICghZXJyKSB7XG4gICAgICAgIHRyeSB7XG4gICAgICAgICAgaWYgKG9wdC53YWxrVG9rZW5zKSB7XG4gICAgICAgICAgICBtYXJrZWQud2Fsa1Rva2Vucyh0b2tlbnMsIG9wdC53YWxrVG9rZW5zKTtcbiAgICAgICAgICB9XG4gICAgICAgICAgb3V0ID0gUGFyc2VyLnBhcnNlKHRva2Vucywgb3B0KTtcbiAgICAgICAgfSBjYXRjaCAoZSkge1xuICAgICAgICAgIGVyciA9IGU7XG4gICAgICAgIH1cbiAgICAgIH1cblxuICAgICAgb3B0LmhpZ2hsaWdodCA9IGhpZ2hsaWdodDtcblxuICAgICAgcmV0dXJuIGVyclxuICAgICAgICA/IGNhbGxiYWNrKGVycilcbiAgICAgICAgOiBjYWxsYmFjayhudWxsLCBvdXQpO1xuICAgIH07XG5cbiAgICBpZiAoIWhpZ2hsaWdodCB8fCBoaWdobGlnaHQubGVuZ3RoIDwgMykge1xuICAgICAgcmV0dXJuIGRvbmUoKTtcbiAgICB9XG5cbiAgICBkZWxldGUgb3B0LmhpZ2hsaWdodDtcblxuICAgIGlmICghdG9rZW5zLmxlbmd0aCkgcmV0dXJuIGRvbmUoKTtcblxuICAgIGxldCBwZW5kaW5nID0gMDtcbiAgICBtYXJrZWQud2Fsa1Rva2Vucyh0b2tlbnMsIGZ1bmN0aW9uKHRva2VuKSB7XG4gICAgICBpZiAodG9rZW4udHlwZSA9PT0gJ2NvZGUnKSB7XG4gICAgICAgIHBlbmRpbmcrKztcbiAgICAgICAgc2V0VGltZW91dCgoKSA9PiB7XG4gICAgICAgICAgaGlnaGxpZ2h0KHRva2VuLnRleHQsIHRva2VuLmxhbmcsIGZ1bmN0aW9uKGVyciwgY29kZSkge1xuICAgICAgICAgICAgaWYgKGVycikge1xuICAgICAgICAgICAgICByZXR1cm4gZG9uZShlcnIpO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgaWYgKGNvZGUgIT0gbnVsbCAmJiBjb2RlICE9PSB0b2tlbi50ZXh0KSB7XG4gICAgICAgICAgICAgIHRva2VuLnRleHQgPSBjb2RlO1xuICAgICAgICAgICAgICB0b2tlbi5lc2NhcGVkID0gdHJ1ZTtcbiAgICAgICAgICAgIH1cblxuICAgICAgICAgICAgcGVuZGluZy0tO1xuICAgICAgICAgICAgaWYgKHBlbmRpbmcgPT09IDApIHtcbiAgICAgICAgICAgICAgZG9uZSgpO1xuICAgICAgICAgICAgfVxuICAgICAgICAgIH0pO1xuICAgICAgICB9LCAwKTtcbiAgICAgIH1cbiAgICB9KTtcblxuICAgIGlmIChwZW5kaW5nID09PSAwKSB7XG4gICAgICBkb25lKCk7XG4gICAgfVxuXG4gICAgcmV0dXJuO1xuICB9XG5cbiAgdHJ5IHtcbiAgICBjb25zdCB0b2tlbnMgPSBMZXhlci5sZXgoc3JjLCBvcHQpO1xuICAgIGlmIChvcHQud2Fsa1Rva2Vucykge1xuICAgICAgbWFya2VkLndhbGtUb2tlbnModG9rZW5zLCBvcHQud2Fsa1Rva2Vucyk7XG4gICAgfVxuICAgIHJldHVybiBQYXJzZXIucGFyc2UodG9rZW5zLCBvcHQpO1xuICB9IGNhdGNoIChlKSB7XG4gICAgZS5tZXNzYWdlICs9ICdcXG5QbGVhc2UgcmVwb3J0IHRoaXMgdG8gaHR0cHM6Ly9naXRodWIuY29tL21hcmtlZGpzL21hcmtlZC4nO1xuICAgIGlmIChvcHQuc2lsZW50KSB7XG4gICAgICByZXR1cm4gJzxwPkFuIGVycm9yIG9jY3VycmVkOjwvcD48cHJlPidcbiAgICAgICAgKyBlc2NhcGUoZS5tZXNzYWdlICsgJycsIHRydWUpXG4gICAgICAgICsgJzwvcHJlPic7XG4gICAgfVxuICAgIHRocm93IGU7XG4gIH1cbn1cblxuLyoqXG4gKiBPcHRpb25zXG4gKi9cblxubWFya2VkLm9wdGlvbnMgPVxubWFya2VkLnNldE9wdGlvbnMgPSBmdW5jdGlvbihvcHQpIHtcbiAgbWVyZ2UobWFya2VkLmRlZmF1bHRzLCBvcHQpO1xuICBjaGFuZ2VEZWZhdWx0cyhtYXJrZWQuZGVmYXVsdHMpO1xuICByZXR1cm4gbWFya2VkO1xufTtcblxubWFya2VkLmdldERlZmF1bHRzID0gZ2V0RGVmYXVsdHM7XG5cbm1hcmtlZC5kZWZhdWx0cyA9IGRlZmF1bHRzO1xuXG4vKipcbiAqIFVzZSBFeHRlbnNpb25cbiAqL1xuXG5tYXJrZWQudXNlID0gZnVuY3Rpb24oLi4uYXJncykge1xuICBjb25zdCBvcHRzID0gbWVyZ2Uoe30sIC4uLmFyZ3MpO1xuICBjb25zdCBleHRlbnNpb25zID0gbWFya2VkLmRlZmF1bHRzLmV4dGVuc2lvbnMgfHwgeyByZW5kZXJlcnM6IHt9LCBjaGlsZFRva2Vuczoge30gfTtcbiAgbGV0IGhhc0V4dGVuc2lvbnM7XG5cbiAgYXJncy5mb3JFYWNoKChwYWNrKSA9PiB7XG4gICAgLy8gPT0tLSBQYXJzZSBcImFkZG9uXCIgZXh0ZW5zaW9ucyAtLT09IC8vXG4gICAgaWYgKHBhY2suZXh0ZW5zaW9ucykge1xuICAgICAgaGFzRXh0ZW5zaW9ucyA9IHRydWU7XG4gICAgICBwYWNrLmV4dGVuc2lvbnMuZm9yRWFjaCgoZXh0KSA9PiB7XG4gICAgICAgIGlmICghZXh0Lm5hbWUpIHtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoJ2V4dGVuc2lvbiBuYW1lIHJlcXVpcmVkJyk7XG4gICAgICAgIH1cbiAgICAgICAgaWYgKGV4dC5yZW5kZXJlcikgeyAvLyBSZW5kZXJlciBleHRlbnNpb25zXG4gICAgICAgICAgY29uc3QgcHJldlJlbmRlcmVyID0gZXh0ZW5zaW9ucy5yZW5kZXJlcnMgPyBleHRlbnNpb25zLnJlbmRlcmVyc1tleHQubmFtZV0gOiBudWxsO1xuICAgICAgICAgIGlmIChwcmV2UmVuZGVyZXIpIHtcbiAgICAgICAgICAgIC8vIFJlcGxhY2UgZXh0ZW5zaW9uIHdpdGggZnVuYyB0byBydW4gbmV3IGV4dGVuc2lvbiBidXQgZmFsbCBiYWNrIGlmIGZhbHNlXG4gICAgICAgICAgICBleHRlbnNpb25zLnJlbmRlcmVyc1tleHQubmFtZV0gPSBmdW5jdGlvbiguLi5hcmdzKSB7XG4gICAgICAgICAgICAgIGxldCByZXQgPSBleHQucmVuZGVyZXIuYXBwbHkodGhpcywgYXJncyk7XG4gICAgICAgICAgICAgIGlmIChyZXQgPT09IGZhbHNlKSB7XG4gICAgICAgICAgICAgICAgcmV0ID0gcHJldlJlbmRlcmVyLmFwcGx5KHRoaXMsIGFyZ3MpO1xuICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgIHJldHVybiByZXQ7XG4gICAgICAgICAgICB9O1xuICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICBleHRlbnNpb25zLnJlbmRlcmVyc1tleHQubmFtZV0gPSBleHQucmVuZGVyZXI7XG4gICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICAgIGlmIChleHQudG9rZW5pemVyKSB7IC8vIFRva2VuaXplciBFeHRlbnNpb25zXG4gICAgICAgICAgaWYgKCFleHQubGV2ZWwgfHwgKGV4dC5sZXZlbCAhPT0gJ2Jsb2NrJyAmJiBleHQubGV2ZWwgIT09ICdpbmxpbmUnKSkge1xuICAgICAgICAgICAgdGhyb3cgbmV3IEVycm9yKFwiZXh0ZW5zaW9uIGxldmVsIG11c3QgYmUgJ2Jsb2NrJyBvciAnaW5saW5lJ1wiKTtcbiAgICAgICAgICB9XG4gICAgICAgICAgaWYgKGV4dGVuc2lvbnNbZXh0LmxldmVsXSkge1xuICAgICAgICAgICAgZXh0ZW5zaW9uc1tleHQubGV2ZWxdLnVuc2hpZnQoZXh0LnRva2VuaXplcik7XG4gICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIGV4dGVuc2lvbnNbZXh0LmxldmVsXSA9IFtleHQudG9rZW5pemVyXTtcbiAgICAgICAgICB9XG4gICAgICAgICAgaWYgKGV4dC5zdGFydCkgeyAvLyBGdW5jdGlvbiB0byBjaGVjayBmb3Igc3RhcnQgb2YgdG9rZW5cbiAgICAgICAgICAgIGlmIChleHQubGV2ZWwgPT09ICdibG9jaycpIHtcbiAgICAgICAgICAgICAgaWYgKGV4dGVuc2lvbnMuc3RhcnRCbG9jaykge1xuICAgICAgICAgICAgICAgIGV4dGVuc2lvbnMuc3RhcnRCbG9jay5wdXNoKGV4dC5zdGFydCk7XG4gICAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgICAgZXh0ZW5zaW9ucy5zdGFydEJsb2NrID0gW2V4dC5zdGFydF07XG4gICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH0gZWxzZSBpZiAoZXh0LmxldmVsID09PSAnaW5saW5lJykge1xuICAgICAgICAgICAgICBpZiAoZXh0ZW5zaW9ucy5zdGFydElubGluZSkge1xuICAgICAgICAgICAgICAgIGV4dGVuc2lvbnMuc3RhcnRJbmxpbmUucHVzaChleHQuc3RhcnQpO1xuICAgICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICAgIGV4dGVuc2lvbnMuc3RhcnRJbmxpbmUgPSBbZXh0LnN0YXJ0XTtcbiAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgfVxuICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgICBpZiAoZXh0LmNoaWxkVG9rZW5zKSB7IC8vIENoaWxkIHRva2VucyB0byBiZSB2aXNpdGVkIGJ5IHdhbGtUb2tlbnNcbiAgICAgICAgICBleHRlbnNpb25zLmNoaWxkVG9rZW5zW2V4dC5uYW1lXSA9IGV4dC5jaGlsZFRva2VucztcbiAgICAgICAgfVxuICAgICAgfSk7XG4gICAgfVxuXG4gICAgLy8gPT0tLSBQYXJzZSBcIm92ZXJ3cml0ZVwiIGV4dGVuc2lvbnMgLS09PSAvL1xuICAgIGlmIChwYWNrLnJlbmRlcmVyKSB7XG4gICAgICBjb25zdCByZW5kZXJlciA9IG1hcmtlZC5kZWZhdWx0cy5yZW5kZXJlciB8fCBuZXcgUmVuZGVyZXIoKTtcbiAgICAgIGZvciAoY29uc3QgcHJvcCBpbiBwYWNrLnJlbmRlcmVyKSB7XG4gICAgICAgIGNvbnN0IHByZXZSZW5kZXJlciA9IHJlbmRlcmVyW3Byb3BdO1xuICAgICAgICAvLyBSZXBsYWNlIHJlbmRlcmVyIHdpdGggZnVuYyB0byBydW4gZXh0ZW5zaW9uLCBidXQgZmFsbCBiYWNrIGlmIGZhbHNlXG4gICAgICAgIHJlbmRlcmVyW3Byb3BdID0gKC4uLmFyZ3MpID0+IHtcbiAgICAgICAgICBsZXQgcmV0ID0gcGFjay5yZW5kZXJlcltwcm9wXS5hcHBseShyZW5kZXJlciwgYXJncyk7XG4gICAgICAgICAgaWYgKHJldCA9PT0gZmFsc2UpIHtcbiAgICAgICAgICAgIHJldCA9IHByZXZSZW5kZXJlci5hcHBseShyZW5kZXJlciwgYXJncyk7XG4gICAgICAgICAgfVxuICAgICAgICAgIHJldHVybiByZXQ7XG4gICAgICAgIH07XG4gICAgICB9XG4gICAgICBvcHRzLnJlbmRlcmVyID0gcmVuZGVyZXI7XG4gICAgfVxuICAgIGlmIChwYWNrLnRva2VuaXplcikge1xuICAgICAgY29uc3QgdG9rZW5pemVyID0gbWFya2VkLmRlZmF1bHRzLnRva2VuaXplciB8fCBuZXcgVG9rZW5pemVyKCk7XG4gICAgICBmb3IgKGNvbnN0IHByb3AgaW4gcGFjay50b2tlbml6ZXIpIHtcbiAgICAgICAgY29uc3QgcHJldlRva2VuaXplciA9IHRva2VuaXplcltwcm9wXTtcbiAgICAgICAgLy8gUmVwbGFjZSB0b2tlbml6ZXIgd2l0aCBmdW5jIHRvIHJ1biBleHRlbnNpb24sIGJ1dCBmYWxsIGJhY2sgaWYgZmFsc2VcbiAgICAgICAgdG9rZW5pemVyW3Byb3BdID0gKC4uLmFyZ3MpID0+IHtcbiAgICAgICAgICBsZXQgcmV0ID0gcGFjay50b2tlbml6ZXJbcHJvcF0uYXBwbHkodG9rZW5pemVyLCBhcmdzKTtcbiAgICAgICAgICBpZiAocmV0ID09PSBmYWxzZSkge1xuICAgICAgICAgICAgcmV0ID0gcHJldlRva2VuaXplci5hcHBseSh0b2tlbml6ZXIsIGFyZ3MpO1xuICAgICAgICAgIH1cbiAgICAgICAgICByZXR1cm4gcmV0O1xuICAgICAgICB9O1xuICAgICAgfVxuICAgICAgb3B0cy50b2tlbml6ZXIgPSB0b2tlbml6ZXI7XG4gICAgfVxuXG4gICAgLy8gPT0tLSBQYXJzZSBXYWxrVG9rZW5zIGV4dGVuc2lvbnMgLS09PSAvL1xuICAgIGlmIChwYWNrLndhbGtUb2tlbnMpIHtcbiAgICAgIGNvbnN0IHdhbGtUb2tlbnMgPSBtYXJrZWQuZGVmYXVsdHMud2Fsa1Rva2VucztcbiAgICAgIG9wdHMud2Fsa1Rva2VucyA9IGZ1bmN0aW9uKHRva2VuKSB7XG4gICAgICAgIHBhY2sud2Fsa1Rva2Vucy5jYWxsKHRoaXMsIHRva2VuKTtcbiAgICAgICAgaWYgKHdhbGtUb2tlbnMpIHtcbiAgICAgICAgICB3YWxrVG9rZW5zLmNhbGwodGhpcywgdG9rZW4pO1xuICAgICAgICB9XG4gICAgICB9O1xuICAgIH1cblxuICAgIGlmIChoYXNFeHRlbnNpb25zKSB7XG4gICAgICBvcHRzLmV4dGVuc2lvbnMgPSBleHRlbnNpb25zO1xuICAgIH1cblxuICAgIG1hcmtlZC5zZXRPcHRpb25zKG9wdHMpO1xuICB9KTtcbn07XG5cbi8qKlxuICogUnVuIGNhbGxiYWNrIGZvciBldmVyeSB0b2tlblxuICovXG5cbm1hcmtlZC53YWxrVG9rZW5zID0gZnVuY3Rpb24odG9rZW5zLCBjYWxsYmFjaykge1xuICBmb3IgKGNvbnN0IHRva2VuIG9mIHRva2Vucykge1xuICAgIGNhbGxiYWNrLmNhbGwobWFya2VkLCB0b2tlbik7XG4gICAgc3dpdGNoICh0b2tlbi50eXBlKSB7XG4gICAgICBjYXNlICd0YWJsZSc6IHtcbiAgICAgICAgZm9yIChjb25zdCBjZWxsIG9mIHRva2VuLmhlYWRlcikge1xuICAgICAgICAgIG1hcmtlZC53YWxrVG9rZW5zKGNlbGwudG9rZW5zLCBjYWxsYmFjayk7XG4gICAgICAgIH1cbiAgICAgICAgZm9yIChjb25zdCByb3cgb2YgdG9rZW4ucm93cykge1xuICAgICAgICAgIGZvciAoY29uc3QgY2VsbCBvZiByb3cpIHtcbiAgICAgICAgICAgIG1hcmtlZC53YWxrVG9rZW5zKGNlbGwudG9rZW5zLCBjYWxsYmFjayk7XG4gICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICAgIGJyZWFrO1xuICAgICAgfVxuICAgICAgY2FzZSAnbGlzdCc6IHtcbiAgICAgICAgbWFya2VkLndhbGtUb2tlbnModG9rZW4uaXRlbXMsIGNhbGxiYWNrKTtcbiAgICAgICAgYnJlYWs7XG4gICAgICB9XG4gICAgICBkZWZhdWx0OiB7XG4gICAgICAgIGlmIChtYXJrZWQuZGVmYXVsdHMuZXh0ZW5zaW9ucyAmJiBtYXJrZWQuZGVmYXVsdHMuZXh0ZW5zaW9ucy5jaGlsZFRva2VucyAmJiBtYXJrZWQuZGVmYXVsdHMuZXh0ZW5zaW9ucy5jaGlsZFRva2Vuc1t0b2tlbi50eXBlXSkgeyAvLyBXYWxrIGFueSBleHRlbnNpb25zXG4gICAgICAgICAgbWFya2VkLmRlZmF1bHRzLmV4dGVuc2lvbnMuY2hpbGRUb2tlbnNbdG9rZW4udHlwZV0uZm9yRWFjaChmdW5jdGlvbihjaGlsZFRva2Vucykge1xuICAgICAgICAgICAgbWFya2VkLndhbGtUb2tlbnModG9rZW5bY2hpbGRUb2tlbnNdLCBjYWxsYmFjayk7XG4gICAgICAgICAgfSk7XG4gICAgICAgIH0gZWxzZSBpZiAodG9rZW4udG9rZW5zKSB7XG4gICAgICAgICAgbWFya2VkLndhbGtUb2tlbnModG9rZW4udG9rZW5zLCBjYWxsYmFjayk7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gIH1cbn07XG5cbi8qKlxuICogUGFyc2UgSW5saW5lXG4gKi9cbm1hcmtlZC5wYXJzZUlubGluZSA9IGZ1bmN0aW9uKHNyYywgb3B0KSB7XG4gIC8vIHRocm93IGVycm9yIGluIGNhc2Ugb2Ygbm9uIHN0cmluZyBpbnB1dFxuICBpZiAodHlwZW9mIHNyYyA9PT0gJ3VuZGVmaW5lZCcgfHwgc3JjID09PSBudWxsKSB7XG4gICAgdGhyb3cgbmV3IEVycm9yKCdtYXJrZWQucGFyc2VJbmxpbmUoKTogaW5wdXQgcGFyYW1ldGVyIGlzIHVuZGVmaW5lZCBvciBudWxsJyk7XG4gIH1cbiAgaWYgKHR5cGVvZiBzcmMgIT09ICdzdHJpbmcnKSB7XG4gICAgdGhyb3cgbmV3IEVycm9yKCdtYXJrZWQucGFyc2VJbmxpbmUoKTogaW5wdXQgcGFyYW1ldGVyIGlzIG9mIHR5cGUgJ1xuICAgICAgKyBPYmplY3QucHJvdG90eXBlLnRvU3RyaW5nLmNhbGwoc3JjKSArICcsIHN0cmluZyBleHBlY3RlZCcpO1xuICB9XG5cbiAgb3B0ID0gbWVyZ2Uoe30sIG1hcmtlZC5kZWZhdWx0cywgb3B0IHx8IHt9KTtcbiAgY2hlY2tTYW5pdGl6ZURlcHJlY2F0aW9uKG9wdCk7XG5cbiAgdHJ5IHtcbiAgICBjb25zdCB0b2tlbnMgPSBMZXhlci5sZXhJbmxpbmUoc3JjLCBvcHQpO1xuICAgIGlmIChvcHQud2Fsa1Rva2Vucykge1xuICAgICAgbWFya2VkLndhbGtUb2tlbnModG9rZW5zLCBvcHQud2Fsa1Rva2Vucyk7XG4gICAgfVxuICAgIHJldHVybiBQYXJzZXIucGFyc2VJbmxpbmUodG9rZW5zLCBvcHQpO1xuICB9IGNhdGNoIChlKSB7XG4gICAgZS5tZXNzYWdlICs9ICdcXG5QbGVhc2UgcmVwb3J0IHRoaXMgdG8gaHR0cHM6Ly9naXRodWIuY29tL21hcmtlZGpzL21hcmtlZC4nO1xuICAgIGlmIChvcHQuc2lsZW50KSB7XG4gICAgICByZXR1cm4gJzxwPkFuIGVycm9yIG9jY3VycmVkOjwvcD48cHJlPidcbiAgICAgICAgKyBlc2NhcGUoZS5tZXNzYWdlICsgJycsIHRydWUpXG4gICAgICAgICsgJzwvcHJlPic7XG4gICAgfVxuICAgIHRocm93IGU7XG4gIH1cbn07XG5cbi8qKlxuICogRXhwb3NlXG4gKi9cbm1hcmtlZC5QYXJzZXIgPSBQYXJzZXI7XG5tYXJrZWQucGFyc2VyID0gUGFyc2VyLnBhcnNlO1xubWFya2VkLlJlbmRlcmVyID0gUmVuZGVyZXI7XG5tYXJrZWQuVGV4dFJlbmRlcmVyID0gVGV4dFJlbmRlcmVyO1xubWFya2VkLkxleGVyID0gTGV4ZXI7XG5tYXJrZWQubGV4ZXIgPSBMZXhlci5sZXg7XG5tYXJrZWQuVG9rZW5pemVyID0gVG9rZW5pemVyO1xubWFya2VkLlNsdWdnZXIgPSBTbHVnZ2VyO1xubWFya2VkLnBhcnNlID0gbWFya2VkO1xuXG5jb25zdCBvcHRpb25zID0gbWFya2VkLm9wdGlvbnM7XG5jb25zdCBzZXRPcHRpb25zID0gbWFya2VkLnNldE9wdGlvbnM7XG5jb25zdCB1c2UgPSBtYXJrZWQudXNlO1xuY29uc3Qgd2Fsa1Rva2VucyA9IG1hcmtlZC53YWxrVG9rZW5zO1xuY29uc3QgcGFyc2VJbmxpbmUgPSBtYXJrZWQucGFyc2VJbmxpbmU7XG5jb25zdCBwYXJzZSA9IG1hcmtlZDtcbmNvbnN0IHBhcnNlciA9IFBhcnNlci5wYXJzZTtcbmNvbnN0IGxleGVyID0gTGV4ZXIubGV4O1xuXG5leHBvcnQgeyBMZXhlciwgUGFyc2VyLCBSZW5kZXJlciwgU2x1Z2dlciwgVGV4dFJlbmRlcmVyLCBUb2tlbml6ZXIsIGRlZmF1bHRzLCBnZXREZWZhdWx0cywgbGV4ZXIsIG1hcmtlZCwgb3B0aW9ucywgcGFyc2UsIHBhcnNlSW5saW5lLCBwYXJzZXIsIHNldE9wdGlvbnMsIHVzZSwgd2Fsa1Rva2VucyB9O1xuIiwiLy8gVGhlIG1vZHVsZSBjYWNoZVxudmFyIF9fd2VicGFja19tb2R1bGVfY2FjaGVfXyA9IHt9O1xuXG4vLyBUaGUgcmVxdWlyZSBmdW5jdGlvblxuZnVuY3Rpb24gX193ZWJwYWNrX3JlcXVpcmVfXyhtb2R1bGVJZCkge1xuXHQvLyBDaGVjayBpZiBtb2R1bGUgaXMgaW4gY2FjaGVcblx0dmFyIGNhY2hlZE1vZHVsZSA9IF9fd2VicGFja19tb2R1bGVfY2FjaGVfX1ttb2R1bGVJZF07XG5cdGlmIChjYWNoZWRNb2R1bGUgIT09IHVuZGVmaW5lZCkge1xuXHRcdHJldHVybiBjYWNoZWRNb2R1bGUuZXhwb3J0cztcblx0fVxuXHQvLyBDcmVhdGUgYSBuZXcgbW9kdWxlIChhbmQgcHV0IGl0IGludG8gdGhlIGNhY2hlKVxuXHR2YXIgbW9kdWxlID0gX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fW21vZHVsZUlkXSA9IHtcblx0XHQvLyBubyBtb2R1bGUuaWQgbmVlZGVkXG5cdFx0Ly8gbm8gbW9kdWxlLmxvYWRlZCBuZWVkZWRcblx0XHRleHBvcnRzOiB7fVxuXHR9O1xuXG5cdC8vIEV4ZWN1dGUgdGhlIG1vZHVsZSBmdW5jdGlvblxuXHRfX3dlYnBhY2tfbW9kdWxlc19fW21vZHVsZUlkXShtb2R1bGUsIG1vZHVsZS5leHBvcnRzLCBfX3dlYnBhY2tfcmVxdWlyZV9fKTtcblxuXHQvLyBSZXR1cm4gdGhlIGV4cG9ydHMgb2YgdGhlIG1vZHVsZVxuXHRyZXR1cm4gbW9kdWxlLmV4cG9ydHM7XG59XG5cbiIsIi8vIGRlZmluZSBnZXR0ZXIgZnVuY3Rpb25zIGZvciBoYXJtb255IGV4cG9ydHNcbl9fd2VicGFja19yZXF1aXJlX18uZCA9IChleHBvcnRzLCBkZWZpbml0aW9uKSA9PiB7XG5cdGZvcih2YXIga2V5IGluIGRlZmluaXRpb24pIHtcblx0XHRpZihfX3dlYnBhY2tfcmVxdWlyZV9fLm8oZGVmaW5pdGlvbiwga2V5KSAmJiAhX193ZWJwYWNrX3JlcXVpcmVfXy5vKGV4cG9ydHMsIGtleSkpIHtcblx0XHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBrZXksIHsgZW51bWVyYWJsZTogdHJ1ZSwgZ2V0OiBkZWZpbml0aW9uW2tleV0gfSk7XG5cdFx0fVxuXHR9XG59OyIsIl9fd2VicGFja19yZXF1aXJlX18ubyA9IChvYmosIHByb3ApID0+IChPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5LmNhbGwob2JqLCBwcm9wKSkiLCIvLyBkZWZpbmUgX19lc01vZHVsZSBvbiBleHBvcnRzXG5fX3dlYnBhY2tfcmVxdWlyZV9fLnIgPSAoZXhwb3J0cykgPT4ge1xuXHRpZih0eXBlb2YgU3ltYm9sICE9PSAndW5kZWZpbmVkJyAmJiBTeW1ib2wudG9TdHJpbmdUYWcpIHtcblx0XHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgU3ltYm9sLnRvU3RyaW5nVGFnLCB7IHZhbHVlOiAnTW9kdWxlJyB9KTtcblx0fVxuXHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7IHZhbHVlOiB0cnVlIH0pO1xufTsiLCJpbXBvcnQgRWRpdG9yIGZyb20gJy4vZWRpdG9yJ1xuY3VzdG9tRWxlbWVudHMuZGVmaW5lKCAneWFuY3ktZWRpdG9yJywgRWRpdG9yICk7XG4iXSwibmFtZXMiOltdLCJzb3VyY2VSb290IjoiIn0=