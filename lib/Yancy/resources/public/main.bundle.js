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
/* harmony import */ var _schemainput_textinput__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./schemainput/textinput */ "./lib/Yancy/resources/src/schemainput/textinput.ts");
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
                input.setAttribute("name", propName);
                input.schema = prop;
                this._root.appendChild(input);
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

SchemaForm.addInputType(_schemainput_textinput__WEBPACK_IMPORTED_MODULE_0__["default"]);


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
//# sourceMappingURL=data:application/json;charset=utf-8;base64,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TjZCO0FBQzdCLGNBQWMsQ0FBQyxNQUFNLENBQUUsY0FBYyxFQUFFLCtDQUFNLENBQUUsQ0FBQyIsInNvdXJjZXMiOlsid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvZWRpdG9yLmh0bWwiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy90YWJ2aWV3Lmh0bWwiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9lZGl0b3IudHMiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9zY2hlbWFmb3JtLnRzIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvc2NoZW1haW5wdXQudHMiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9zY2hlbWFpbnB1dC90ZXh0aW5wdXQudHMiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy90YWJ2aWV3LnRzIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svYm9vdHN0cmFwIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svcnVudGltZS9kZWZpbmUgcHJvcGVydHkgZ2V0dGVycyIsIndlYnBhY2s6Ly9ZYW5jeS93ZWJwYWNrL3J1bnRpbWUvaGFzT3duUHJvcGVydHkgc2hvcnRoYW5kIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svcnVudGltZS9tYWtlIG5hbWVzcGFjZSBvYmplY3QiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9pbmRleC50cyJdLCJzb3VyY2VzQ29udGVudCI6WyIvLyBNb2R1bGVcbnZhciBjb2RlID0gXCI8bmF2PlxcbiAgPHVsIGlkPVxcXCJzY2hlbWEtbGlzdFxcXCI+XFxuICA8L3VsPlxcbjwvbmF2Plxcbjx0YWItdmlldz5cXG48L3RhYi12aWV3PlxcblwiO1xuLy8gRXhwb3J0c1xuZXhwb3J0IGRlZmF1bHQgY29kZTsiLCIvLyBNb2R1bGVcbnZhciBjb2RlID0gXCI8c3R5bGU+XFxuI3RhYi1wYW5lID4gKiB7XFxuICBkaXNwbGF5OiBub25lO1xcbn1cXG4jdGFiLXBhbmUgPiAuYWN0aXZlIHtcXG4gIGRpc3BsYXk6IGJsb2NrO1xcbn1cXG48L3N0eWxlPlxcbjxkaXY+XFxuICA8dWwgaWQ9XFxcInRhYi1iYXJcXFwiPjwvdWw+XFxuICA8ZGl2IGlkPVxcXCJ0YWItcGFuZVxcXCI+PC9kaXY+XFxuPC9kaXY+XFxuXCI7XG4vLyBFeHBvcnRzXG5leHBvcnQgZGVmYXVsdCBjb2RlOyIsIlxuaW1wb3J0IFRhYlZpZXcgZnJvbSAnLi90YWJ2aWV3JztcbmltcG9ydCBTY2hlbWFGb3JtIGZyb20gJy4vc2NoZW1hZm9ybSc7XG5pbXBvcnQgaHRtbCBmcm9tICcuL2VkaXRvci5odG1sJztcbmV4cG9ydCBkZWZhdWx0IGNsYXNzIEVkaXRvciBleHRlbmRzIEhUTUxFbGVtZW50IHtcblxuICBzY2hlbWE6IGFueVxuICBjb25zdHJ1Y3RvcigpIHtcbiAgICBzdXBlcigpO1xuXG4gICAgd2luZG93LmN1c3RvbUVsZW1lbnRzLmRlZmluZSggJ3RhYi12aWV3JywgVGFiVmlldyApO1xuICAgIHdpbmRvdy5jdXN0b21FbGVtZW50cy5kZWZpbmUoICdzY2hlbWEtZm9ybScsIFNjaGVtYUZvcm0gKTtcbiAgfVxuXG4gIGdldCB0YWJWaWV3KCkge1xuICAgIHJldHVybiB0aGlzLnF1ZXJ5U2VsZWN0b3IoJ3RhYi12aWV3JykgYXMgVGFiVmlldztcbiAgfVxuXG4gIGdldCBzY2hlbWFMaXN0KCkge1xuICAgIHJldHVybiB0aGlzLnF1ZXJ5U2VsZWN0b3IoJyNzY2hlbWEtbGlzdCcpO1xuICB9XG5cbiAgY29ubmVjdGVkQ2FsbGJhY2soKSB7XG4gICAgdGhpcy5pbm5lckhUTUwgPSBodG1sLnRyaW0oKTtcbiAgICB0aGlzLnNjaGVtYUxpc3QuYWRkRXZlbnRMaXN0ZW5lcignY2xpY2snLCAoZSkgPT4gdGhpcy5jbGlja1NjaGVtYShlKSk7XG5cbiAgICAvLyBTaG93IHdlbGNvbWUgcGFuZVxuICAgIGxldCBoZWxsbyA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2RpdicpO1xuICAgIGhlbGxvLmFwcGVuZENoaWxkKCBkb2N1bWVudC5jcmVhdGVUZXh0Tm9kZSggJ0hlbGxvLCBXb3JsZCEnICkgKTtcbiAgICB0aGlzLnRhYlZpZXcuYWRkVGFiKFwiSGVsbG9cIiwgaGVsbG8pO1xuXG4gICAgLy8gQWRkIHNjaGVtYSBsaXN0XG4gICAgZm9yICggbGV0IHNjaGVtYU5hbWUgb2YgT2JqZWN0LmtleXModGhpcy5zY2hlbWEpLnNvcnQoKSApIHtcbiAgICAgIGxldCBsaSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdsaScgKTtcbiAgICAgIGxpLmRhdGFzZXRbXCJzY2hlbWFcIl0gPSBzY2hlbWFOYW1lO1xuICAgICAgbGkuYXBwZW5kQ2hpbGQoIGRvY3VtZW50LmNyZWF0ZVRleHROb2RlKCBzY2hlbWFOYW1lICkgKTtcbiAgICAgIHRoaXMuc2NoZW1hTGlzdC5hcHBlbmRDaGlsZCggbGkgKTtcbiAgICB9XG4gIH1cblxuICBjbGlja1NjaGVtYShlOkV2ZW50KSB7XG4gICAgbGV0IHNjaGVtYU5hbWUgPSAoPEhUTUxFbGVtZW50PmUudGFyZ2V0KS5kYXRhc2V0W1wic2NoZW1hXCJdO1xuICAgIC8vIEZpbmQgdGhlIHNjaGVtYSdzIHRhYiBvciBvcGVuIG9uZVxuICAgIGlmICggdGhpcy50YWJWaWV3LnNob3dUYWIoIHNjaGVtYU5hbWUgKSApIHtcbiAgICAgIHJldHVybjtcbiAgICB9XG4gICAgbGV0IGVkaXRGb3JtID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggJ3NjaGVtYS1mb3JtJyApIGFzIFNjaGVtYUZvcm07XG4gICAgZWRpdEZvcm0uc2NoZW1hID0gdGhpcy5zY2hlbWFbIHNjaGVtYU5hbWUgXTtcbiAgICB0aGlzLnRhYlZpZXcuYWRkVGFiKCBzY2hlbWFOYW1lLCBlZGl0Rm9ybSApO1xuICB9XG59XG5cbiIsImltcG9ydCB7IFNjaGVtYVByb3BlcnR5IH0gZnJvbSAnLi9zY2hlbWEnXG5pbXBvcnQgeyBTY2hlbWFJbnB1dCwgU2NoZW1hSW5wdXRDbGFzcyB9IGZyb20gJy4vc2NoZW1haW5wdXQnO1xuXG5leHBvcnQgZGVmYXVsdCBjbGFzcyBTY2hlbWFGb3JtIGV4dGVuZHMgSFRNTEVsZW1lbnQge1xuXG4gIHN0YXRpYyBfaW5wdXRUeXBlczogeyBbaW5kZXg6IHN0cmluZ106IFNjaGVtYUlucHV0Q2xhc3MgfSA9IHt9O1xuICBzdGF0aWMgX2lucHV0T3JkZXI6IHN0cmluZ1tdID0gW107XG4gIF9zY2hlbWE6IE9iamVjdDtcbiAgX3Jvb3Q6IERvY3VtZW50RnJhZ21lbnQ7XG5cbiAgY29uc3RydWN0b3IoKSB7XG4gICAgc3VwZXIoKTtcbiAgICAvLyBUaGlzIGRvY3VtZW50IGZyYWdtZW50IGFsbG93cyB1cyB0byBidWlsZCB0aGUgZm9ybSBiZWZvcmVcbiAgICAvLyBhbnl0aGluZyBpcyBhZGRlZCB0byB0aGUgcGFnZSBET01cbiAgICB0aGlzLl9yb290ID0gZG9jdW1lbnQuY3JlYXRlRG9jdW1lbnRGcmFnbWVudCgpO1xuICB9XG5cbiAgc3RhdGljIGFkZElucHV0VHlwZSggZnQ6IFNjaGVtYUlucHV0Q2xhc3MgKSB7XG4gICAgY29uc3QgdGFnTmFtZSA9IGZ0LnJlZ2lzdGVyKCk7XG4gICAgU2NoZW1hRm9ybS5faW5wdXRPcmRlci51bnNoaWZ0KCB0YWdOYW1lICk7XG4gICAgU2NoZW1hRm9ybS5faW5wdXRUeXBlc1sgdGFnTmFtZSBdID0gZnQ7XG4gIH1cblxuICBzZXQgc2NoZW1hKG5ld1NjaGVtYTogYW55KSB7XG4gICAgaWYgKCB0aGlzLl9zY2hlbWEgKSB7XG4gICAgICAvLyBSZW1vdmUgZXhpc3RpbmcgaW5wdXRzXG4gICAgfVxuICAgIGlmICggbmV3U2NoZW1hLnByb3BlcnRpZXMgKSB7XG4gICAgICBmb3IgKCBjb25zdCBwcm9wTmFtZSBpbiBuZXdTY2hlbWEucHJvcGVydGllcyApIHtcbiAgICAgICAgY29uc3QgcHJvcCA9IG5ld1NjaGVtYS5wcm9wZXJ0aWVzWyBwcm9wTmFtZSBdO1xuICAgICAgICBjb25zdCBpbnB1dFRhZyA9IFNjaGVtYUZvcm0uX2lucHV0T3JkZXIuZmluZChcbiAgICAgICAgICB0YWdOYW1lID0+IFNjaGVtYUZvcm0uX2lucHV0VHlwZXNbIHRhZ05hbWUgXS5oYW5kbGVzKCBwcm9wIClcbiAgICAgICAgKTtcbiAgICAgICAgaWYgKCAhaW5wdXRUYWcgKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCBgQ291bGQgbm90IGZpbmQgaW5wdXQgdG8gaGFuZGxlIHByb3A6ICR7SlNPTi5zdHJpbmdpZnkocHJvcCl9YCApO1xuICAgICAgICB9XG4gICAgICAgIGNvbnN0IGlucHV0ID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggaW5wdXRUYWcgKSBhcyBTY2hlbWFJbnB1dDtcbiAgICAgICAgaW5wdXQuc2V0QXR0cmlidXRlKCBcIm5hbWVcIiwgcHJvcE5hbWUgKTtcbiAgICAgICAgaW5wdXQuc2NoZW1hID0gcHJvcDtcbiAgICAgICAgdGhpcy5fcm9vdC5hcHBlbmRDaGlsZCggaW5wdXQgKTtcbiAgICAgIH1cbiAgICB9XG4gICAgLy8gWFhYOiBIYW5kbGUgYXJyYXkgdHlwZXNcbiAgICB0aGlzLl9zY2hlbWEgPSBuZXdTY2hlbWE7XG4gIH1cblxuICBzZXQgdmFsdWUobmV3VmFsdWU6IGFueSkge1xuICAgIGZvciAoIGxldCBwcm9wTmFtZSBpbiBuZXdWYWx1ZSApIHtcbiAgICAgIGxldCBpbnB1dCA9IHRoaXMucXVlcnlTZWxlY3RvciggYFtuYW1lPSR7cHJvcE5hbWV9XWAgKSBhcyBTY2hlbWFJbnB1dDtcbiAgICAgIGlucHV0LnZhbHVlID0gbmV3VmFsdWVbIHByb3BOYW1lIF07XG4gICAgfVxuICB9XG5cbiAgZ2V0IHZhbHVlKCk6IGFueSB7XG4gICAgbGV0IHZhbCA9IHt9IGFzIGFueTtcbiAgICBmb3IgKCBjb25zdCBlbCBvZiB0aGlzLl9yb290LmNoaWxkcmVuICkge1xuICAgICAgY29uc3QgaW5wdXQgPSBlbCBhcyBTY2hlbWFJbnB1dDtcbiAgICAgIHZhbFsgaW5wdXQubmFtZSBdID0gaW5wdXQudmFsdWU7XG4gICAgfVxuICAgIHJldHVybiB2YWw7XG4gIH1cblxuICBjb25uZWN0ZWRDYWxsYmFjaygpIHtcbiAgICB0aGlzLmFwcGVuZENoaWxkKCB0aGlzLl9yb290ICk7XG4gIH1cblxufVxuXG5pbXBvcnQgVGV4dElucHV0IGZyb20gJy4vc2NoZW1haW5wdXQvdGV4dGlucHV0JztcblNjaGVtYUZvcm0uYWRkSW5wdXRUeXBlKCBUZXh0SW5wdXQgKTtcblxuIiwiaW1wb3J0IHsgU2NoZW1hUHJvcGVydHkgfSBmcm9tICcuL3NjaGVtYSdcblxuZXhwb3J0IGFic3RyYWN0IGNsYXNzIFNjaGVtYUlucHV0IGV4dGVuZHMgSFRNTEVsZW1lbnQge1xuICBuYW1lOiBzdHJpbmc7XG4gIGFic3RyYWN0IHNjaGVtYTogU2NoZW1hUHJvcGVydHk7XG4gIGFic3RyYWN0IHZhbHVlOiBhbnk7XG4gIHN0YXRpYyBoYW5kbGVzKCBpbnB1dDogU2NoZW1hUHJvcGVydHkgKTogYm9vbGVhbiB7XG4gICAgcmV0dXJuIGZhbHNlO1xuICB9XG59XG5cbmV4cG9ydCB0eXBlIFNjaGVtYUlucHV0Q2xhc3MgPSB7XG4gIG5ldyggLi4uYXJnczogYW55W10gKTogU2NoZW1hSW5wdXQ7XG4gIGhhbmRsZXMoaW5wdXQ6IFNjaGVtYVByb3BlcnR5KTogYm9vbGVhbjtcbiAgcmVnaXN0ZXIoKTogc3RyaW5nO1xufVxuXG4iLCJpbXBvcnQgeyBTY2hlbWFQcm9wZXJ0eSB9IGZyb20gJy4uL3NjaGVtYSdcbmltcG9ydCB7IFNjaGVtYUlucHV0LCBTY2hlbWFJbnB1dENsYXNzIH0gZnJvbSAnLi4vc2NoZW1haW5wdXQnO1xuXG5leHBvcnQgZGVmYXVsdCBjbGFzcyBUZXh0SW5wdXQgZXh0ZW5kcyBTY2hlbWFJbnB1dCB7XG4gIGlucHV0OiBIVE1MSW5wdXRFbGVtZW50O1xuXG4gIGNvbnN0cnVjdG9yKCkge1xuICAgIHN1cGVyKCk7XG4gICAgdGhpcy5pbnB1dCA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdpbnB1dCcgKTtcbiAgfVxuXG4gIGdldCB2YWx1ZSgpOiBhbnkge1xuICAgIHJldHVybiB0aGlzLmlucHV0LnZhbHVlO1xuICB9XG4gIHNldCB2YWx1ZSggbmV3VmFsdWU6IGFueSApIHtcbiAgICB0aGlzLmlucHV0LnZhbHVlID0gbmV3VmFsdWU7XG4gIH1cblxuICBzZXQgc2NoZW1hKCBuZXdTY2hlbWE6IFNjaGVtYVByb3BlcnR5ICkge1xuICAgIGNvbnNvbGUubG9nKCBcIlNldHRpbmcgc2NoZW1hIGZvciB0ZXh0aW5wdXRcIiwgbmV3U2NoZW1hICk7XG4gICAgbGV0IGlucHV0VHlwZSA9ICd0ZXh0JztcbiAgICBsZXQgaW5wdXRNb2RlID0gJ3RleHQnO1xuICAgIGxldCBwYXR0ZXJuID0gbmV3U2NoZW1hLnBhdHRlcm47XG5cbiAgICBpZiAoIG5ld1NjaGVtYS50eXBlID09PSAnc3RyaW5nJyApIHtcbiAgICAgIGlmICggbmV3U2NoZW1hLmZvcm1hdCA9PT0gJ2VtYWlsJyApIHtcbiAgICAgICAgaW5wdXRUeXBlID0gJ2VtYWlsJztcbiAgICAgICAgaW5wdXRNb2RlID0gJ2VtYWlsJztcbiAgICAgIH1cbiAgICAgIGVsc2UgaWYgKCBuZXdTY2hlbWEuZm9ybWF0ID09PSAndXJsJyApIHtcbiAgICAgICAgaW5wdXRUeXBlID0gJ3VybCc7XG4gICAgICAgIGlucHV0TW9kZSA9ICd1cmwnO1xuICAgICAgfVxuICAgICAgZWxzZSBpZiAoIG5ld1NjaGVtYS5mb3JtYXQgPT09ICd0ZWwnICkge1xuICAgICAgICBpbnB1dFR5cGUgPSAndGVsJztcbiAgICAgICAgaW5wdXRNb2RlID0gJ3RlbCc7XG4gICAgICB9XG4gICAgfVxuICAgIGVsc2UgaWYgKCBuZXdTY2hlbWEudHlwZSA9PT0gJ2ludGVnZXInIHx8IG5ld1NjaGVtYS50eXBlID09PSAnbnVtYmVyJyApIHtcbiAgICAgIGlucHV0VHlwZSA9ICdudW1iZXInO1xuICAgICAgaW5wdXRNb2RlID0gJ2RlY2ltYWwnO1xuICAgICAgaWYgKCBuZXdTY2hlbWEudHlwZSAgPT09ICdpbnRlZ2VyJyApIHtcbiAgICAgICAgLy8gVXNlIHBhdHRlcm4gdG8gc2hvdyBudW1lcmljIGlucHV0IG9uIGlPU1xuICAgICAgICAvLyBodHRwczovL2Nzcy10cmlja3MuY29tL2Zpbmdlci1mcmllbmRseS1udW1lcmljYWwtaW5wdXRzLXdpdGgtaW5wdXRtb2RlL1xuICAgICAgICBwYXR0ZXJuID0gcGF0dGVybiB8fCAnWzAtOV0qJztcbiAgICAgICAgaW5wdXRNb2RlID0gJ251bWVyaWMnO1xuICAgICAgfVxuICAgIH1cblxuICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAndHlwZScsIGlucHV0VHlwZSApO1xuICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAnaW5wdXRtb2RlJywgaW5wdXRNb2RlICk7XG4gICAgaWYgKCBwYXR0ZXJuICkge1xuICAgICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICdwYXR0ZXJuJywgcGF0dGVybiApO1xuICAgIH1cbiAgICBpZiAoIG5ld1NjaGVtYS5taW5MZW5ndGggKSB7XG4gICAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ21pbmxlbmd0aCcsIG5ld1NjaGVtYS5taW5MZW5ndGgudG9TdHJpbmcoKSApO1xuICAgIH1cbiAgICBpZiAoIG5ld1NjaGVtYS5tYXhMZW5ndGggKSB7XG4gICAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ21heGxlbmd0aCcsIG5ld1NjaGVtYS5tYXhMZW5ndGgudG9TdHJpbmcoKSApO1xuICAgIH1cbiAgICBpZiAoIG5ld1NjaGVtYS5taW5pbXVtICkge1xuICAgICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICdtaW4nLCBuZXdTY2hlbWEubWluaW11bS50b1N0cmluZygpICk7XG4gICAgfVxuICAgIGlmICggbmV3U2NoZW1hLm1heGltdW0gKSB7XG4gICAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ21heCcsIG5ld1NjaGVtYS5tYXhpbXVtLnRvU3RyaW5nKCkgKTtcbiAgICB9XG4gIH1cblxuICBjb25uZWN0ZWRDYWxsYmFjaygpIHtcbiAgICB0aGlzLmFwcGVuZENoaWxkKCB0aGlzLmlucHV0ICk7XG4gIH1cblxuICBzdGF0aWMgaGFuZGxlcyggaW5wdXQ6IFNjaGVtYVByb3BlcnR5ICk6IGJvb2xlYW4ge1xuICAgIHJldHVybiB0cnVlO1xuICB9XG5cbiAgc3RhdGljIHJlZ2lzdGVyKCk6c3RyaW5nIHtcbiAgICBjb25zdCB0YWdOYW1lID0gJ3NjaGVtYS10ZXh0LWlucHV0JztcbiAgICB3aW5kb3cuY3VzdG9tRWxlbWVudHMuZGVmaW5lKCB0YWdOYW1lLCBUZXh0SW5wdXQgKTtcbiAgICByZXR1cm4gdGFnTmFtZTtcbiAgfVxufVxuIiwiXG5pbXBvcnQgaHRtbCBmcm9tICcuL3RhYnZpZXcuaHRtbCc7XG5leHBvcnQgZGVmYXVsdCBjbGFzcyBUYWJWaWV3IGV4dGVuZHMgSFRNTEVsZW1lbnQge1xuXG4gIGdldCB0YWJCYXIoKSB7XG4gICAgcmV0dXJuIHRoaXMucXVlcnlTZWxlY3RvciggJyN0YWItYmFyJyApO1xuICB9XG4gIGdldCB0YWJQYW5lcygpIHtcbiAgICByZXR1cm4gdGhpcy5xdWVyeVNlbGVjdG9yKCAnI3RhYi1wYW5lJyApO1xuICB9XG4gIGdldCB0YWJzKCk6IEFycmF5PEhUTUxFbGVtZW50PiB7XG4gICAgcmV0dXJuIEFycmF5LmZyb20odGhpcy50YWJCYXIuY2hpbGRyZW4pIGFzIEFycmF5PEhUTUxFbGVtZW50PjtcbiAgfVxuXG4gIGNvbm5lY3RlZENhbGxiYWNrKCkge1xuICAgIHRoaXMuaW5uZXJIVE1MID0gaHRtbC50cmltKCk7XG4gICAgdGhpcy50YWJCYXIuYWRkRXZlbnRMaXN0ZW5lcignY2xpY2snLCAoZSkgPT4gdGhpcy5jbGlja1RhYihlKSk7XG4gIH1cblxuICBhZGRUYWIoIGxhYmVsOiBzdHJpbmcsIGNvbnRlbnQ6IEhUTUxFbGVtZW50ICkge1xuICAgIGNvbnN0IGxpID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggJ2xpJyApO1xuICAgIGxpLmFwcGVuZENoaWxkKCBkb2N1bWVudC5jcmVhdGVUZXh0Tm9kZSggbGFiZWwgKSApO1xuICAgIHRoaXMudGFiQmFyLmFwcGVuZENoaWxkKCBsaSApO1xuICAgIHRoaXMudGFiUGFuZXMuYXBwZW5kQ2hpbGQoIGNvbnRlbnQgKTtcbiAgICB0aGlzLnNob3dUYWIobGFiZWwpO1xuICB9XG5cbiAgc2hvd1RhYiggbGFiZWw6IHN0cmluZyApIDogYm9vbGVhbiB7XG4gICAgbGV0IGlkeCA9IHRoaXMudGFicy5maW5kSW5kZXgoIGVsID0+IGVsLmlubmVyVGV4dCA9PSBsYWJlbCApO1xuICAgIGlmICggaWR4IDwgMCApIHtcbiAgICAgIGNvbnNvbGUubG9nKCBgQ291bGQgbm90IGZpbmQgdGFiIHdpdGggbGFiZWwgJHtsYWJlbH1gICk7XG4gICAgICByZXR1cm4gZmFsc2U7XG4gICAgfVxuICAgIGlmICggdGhpcy50YWJCYXIucXVlcnlTZWxlY3RvciggJy5hY3RpdmUnICkgKSB7XG4gICAgICB0aGlzLnRhYkJhci5xdWVyeVNlbGVjdG9yKCAnLmFjdGl2ZScgKS5jbGFzc0xpc3QucmVtb3ZlKCAnYWN0aXZlJyApO1xuICAgICAgdGhpcy50YWJQYW5lcy5xdWVyeVNlbGVjdG9yKCAnLmFjdGl2ZScgKS5jbGFzc0xpc3QucmVtb3ZlKCAnYWN0aXZlJyApO1xuICAgIH1cbiAgICB0aGlzLnRhYkJhci5jaGlsZHJlbltpZHhdLmNsYXNzTGlzdC5hZGQoJ2FjdGl2ZScpO1xuICAgIHRoaXMudGFiUGFuZXMuY2hpbGRyZW5baWR4XS5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTtcbiAgICByZXR1cm4gdHJ1ZTtcbiAgfVxuXG4gIGNsaWNrVGFiKCBlOiBFdmVudCApIHtcbiAgfVxufVxuXG4iLCIvLyBUaGUgbW9kdWxlIGNhY2hlXG52YXIgX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fID0ge307XG5cbi8vIFRoZSByZXF1aXJlIGZ1bmN0aW9uXG5mdW5jdGlvbiBfX3dlYnBhY2tfcmVxdWlyZV9fKG1vZHVsZUlkKSB7XG5cdC8vIENoZWNrIGlmIG1vZHVsZSBpcyBpbiBjYWNoZVxuXHR2YXIgY2FjaGVkTW9kdWxlID0gX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fW21vZHVsZUlkXTtcblx0aWYgKGNhY2hlZE1vZHVsZSAhPT0gdW5kZWZpbmVkKSB7XG5cdFx0cmV0dXJuIGNhY2hlZE1vZHVsZS5leHBvcnRzO1xuXHR9XG5cdC8vIENyZWF0ZSBhIG5ldyBtb2R1bGUgKGFuZCBwdXQgaXQgaW50byB0aGUgY2FjaGUpXG5cdHZhciBtb2R1bGUgPSBfX3dlYnBhY2tfbW9kdWxlX2NhY2hlX19bbW9kdWxlSWRdID0ge1xuXHRcdC8vIG5vIG1vZHVsZS5pZCBuZWVkZWRcblx0XHQvLyBubyBtb2R1bGUubG9hZGVkIG5lZWRlZFxuXHRcdGV4cG9ydHM6IHt9XG5cdH07XG5cblx0Ly8gRXhlY3V0ZSB0aGUgbW9kdWxlIGZ1bmN0aW9uXG5cdF9fd2VicGFja19tb2R1bGVzX19bbW9kdWxlSWRdKG1vZHVsZSwgbW9kdWxlLmV4cG9ydHMsIF9fd2VicGFja19yZXF1aXJlX18pO1xuXG5cdC8vIFJldHVybiB0aGUgZXhwb3J0cyBvZiB0aGUgbW9kdWxlXG5cdHJldHVybiBtb2R1bGUuZXhwb3J0cztcbn1cblxuIiwiLy8gZGVmaW5lIGdldHRlciBmdW5jdGlvbnMgZm9yIGhhcm1vbnkgZXhwb3J0c1xuX193ZWJwYWNrX3JlcXVpcmVfXy5kID0gKGV4cG9ydHMsIGRlZmluaXRpb24pID0+IHtcblx0Zm9yKHZhciBrZXkgaW4gZGVmaW5pdGlvbikge1xuXHRcdGlmKF9fd2VicGFja19yZXF1aXJlX18ubyhkZWZpbml0aW9uLCBrZXkpICYmICFfX3dlYnBhY2tfcmVxdWlyZV9fLm8oZXhwb3J0cywga2V5KSkge1xuXHRcdFx0T2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsIGtleSwgeyBlbnVtZXJhYmxlOiB0cnVlLCBnZXQ6IGRlZmluaXRpb25ba2V5XSB9KTtcblx0XHR9XG5cdH1cbn07IiwiX193ZWJwYWNrX3JlcXVpcmVfXy5vID0gKG9iaiwgcHJvcCkgPT4gKE9iamVjdC5wcm90b3R5cGUuaGFzT3duUHJvcGVydHkuY2FsbChvYmosIHByb3ApKSIsIi8vIGRlZmluZSBfX2VzTW9kdWxlIG9uIGV4cG9ydHNcbl9fd2VicGFja19yZXF1aXJlX18uciA9IChleHBvcnRzKSA9PiB7XG5cdGlmKHR5cGVvZiBTeW1ib2wgIT09ICd1bmRlZmluZWQnICYmIFN5bWJvbC50b1N0cmluZ1RhZykge1xuXHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBTeW1ib2wudG9TdHJpbmdUYWcsIHsgdmFsdWU6ICdNb2R1bGUnIH0pO1xuXHR9XG5cdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCAnX19lc01vZHVsZScsIHsgdmFsdWU6IHRydWUgfSk7XG59OyIsImltcG9ydCBFZGl0b3IgZnJvbSAnLi9lZGl0b3InXG5jdXN0b21FbGVtZW50cy5kZWZpbmUoICd5YW5jeS1lZGl0b3InLCBFZGl0b3IgKTtcbiJdLCJuYW1lcyI6W10sInNvdXJjZVJvb3QiOiIifQ==