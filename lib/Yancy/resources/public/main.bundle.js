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

/***/ "./lib/Yancy/resources/src/schemafield.ts":
/*!************************************************!*\
  !*** ./lib/Yancy/resources/src/schemafield.ts ***!
  \************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "SchemaField": () => (/* binding */ SchemaField)
/* harmony export */ });
class SchemaField extends HTMLElement {
    static handles(field) {
        return false;
    }
}


/***/ }),

/***/ "./lib/Yancy/resources/src/schemafield/textinput.ts":
/*!**********************************************************!*\
  !*** ./lib/Yancy/resources/src/schemafield/textinput.ts ***!
  \**********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ TextInput)
/* harmony export */ });
/* harmony import */ var _schemafield__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../schemafield */ "./lib/Yancy/resources/src/schemafield.ts");

class TextInput extends _schemafield__WEBPACK_IMPORTED_MODULE_0__.SchemaField {
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
        let fieldType = 'text';
        let inputMode = 'text';
        let pattern = newSchema.pattern;
        if (newSchema.type === 'string') {
            if (newSchema.format === 'email') {
                fieldType = 'email';
                inputMode = 'email';
            }
            else if (newSchema.format === 'url') {
                fieldType = 'url';
                inputMode = 'url';
            }
            else if (newSchema.format === 'tel') {
                fieldType = 'tel';
                inputMode = 'tel';
            }
        }
        else if (newSchema.type === 'integer' || newSchema.type === 'number') {
            fieldType = 'number';
            inputMode = 'decimal';
            if (newSchema.type === 'integer') {
                // Use pattern to show numeric input on iOS
                // https://css-tricks.com/finger-friendly-numerical-inputs-with-inputmode/
                pattern = pattern || '[0-9]*';
                inputMode = 'numeric';
            }
        }
        this.input.setAttribute('type', fieldType);
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
    static handles(field) {
        return true;
    }
    static register() {
        const tagName = 'schema-text-input';
        window.customElements.define(tagName, TextInput);
        return tagName;
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
/* harmony import */ var _schemafield_textinput__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./schemafield/textinput */ "./lib/Yancy/resources/src/schemafield/textinput.ts");
class SchemaForm extends HTMLElement {
    constructor() {
        super();
        // This document fragment allows us to build the form before
        // anything is added to the page DOM
        this._root = document.createDocumentFragment();
    }
    static addFieldType(ft) {
        const tagName = ft.register();
        SchemaForm._fieldOrder.unshift(tagName);
        SchemaForm._fieldTypes[tagName] = ft;
    }
    set schema(newSchema) {
        if (this._schema) {
            // Remove existing fields
        }
        if (newSchema.properties) {
            for (const propName in newSchema.properties) {
                const prop = newSchema.properties[propName];
                const fieldTag = SchemaForm._fieldOrder.find(tagName => SchemaForm._fieldTypes[tagName].handles(prop));
                if (!fieldTag) {
                    throw new Error(`Could not find field to handle prop: ${JSON.stringify(prop)}`);
                }
                const field = document.createElement(fieldTag);
                field.setAttribute("name", propName);
                field.schema = prop;
                this._root.appendChild(field);
            }
        }
        // XXX: Handle array types
        this._schema = newSchema;
    }
    set value(newValue) {
        for (let propName in newValue) {
            let field = this.querySelector(`[name=${propName}]`);
            field.value = newValue[propName];
        }
    }
    get value() {
        let val = {};
        for (const el of this._root.children) {
            const field = el;
            val[field.name] = field.value;
        }
        return val;
    }
    connectedCallback() {
        this.appendChild(this._root);
    }
}
SchemaForm._fieldTypes = {};
SchemaForm._fieldOrder = [];

SchemaForm.addFieldType(_schemafield_textinput__WEBPACK_IMPORTED_MODULE_0__["default"]);


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
//# sourceMappingURL=data:application/json;charset=utf-8;base64,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QjtBQUM3QixjQUFjLENBQUMsTUFBTSxDQUFFLGNBQWMsRUFBRSwrQ0FBTSxDQUFFLENBQUMiLCJzb3VyY2VzIjpbIndlYnBhY2s6Ly9ZYW5jeS8uL2xpYi9ZYW5jeS9yZXNvdXJjZXMvc3JjL2VkaXRvci5odG1sIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvdGFidmlldy5odG1sIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvZWRpdG9yLnRzIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvc2NoZW1hZmllbGQudHMiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9zY2hlbWFmaWVsZC90ZXh0aW5wdXQudHMiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9zY2hlbWFmb3JtLnRzIiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvdGFidmlldy50cyIsIndlYnBhY2s6Ly9ZYW5jeS93ZWJwYWNrL2Jvb3RzdHJhcCIsIndlYnBhY2s6Ly9ZYW5jeS93ZWJwYWNrL3J1bnRpbWUvZGVmaW5lIHByb3BlcnR5IGdldHRlcnMiLCJ3ZWJwYWNrOi8vWWFuY3kvd2VicGFjay9ydW50aW1lL2hhc093blByb3BlcnR5IHNob3J0aGFuZCIsIndlYnBhY2s6Ly9ZYW5jeS93ZWJwYWNrL3J1bnRpbWUvbWFrZSBuYW1lc3BhY2Ugb2JqZWN0Iiwid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvaW5kZXgudHMiXSwic291cmNlc0NvbnRlbnQiOlsiLy8gTW9kdWxlXG52YXIgY29kZSA9IFwiPG5hdj5cXG4gIDx1bCBpZD1cXFwic2NoZW1hLWxpc3RcXFwiPlxcbiAgPC91bD5cXG48L25hdj5cXG48dGFiLXZpZXc+XFxuPC90YWItdmlldz5cXG5cIjtcbi8vIEV4cG9ydHNcbmV4cG9ydCBkZWZhdWx0IGNvZGU7IiwiLy8gTW9kdWxlXG52YXIgY29kZSA9IFwiPHN0eWxlPlxcbiN0YWItcGFuZSA+ICoge1xcbiAgZGlzcGxheTogbm9uZTtcXG59XFxuI3RhYi1wYW5lID4gLmFjdGl2ZSB7XFxuICBkaXNwbGF5OiBibG9jaztcXG59XFxuPC9zdHlsZT5cXG48ZGl2PlxcbiAgPHVsIGlkPVxcXCJ0YWItYmFyXFxcIj48L3VsPlxcbiAgPGRpdiBpZD1cXFwidGFiLXBhbmVcXFwiPjwvZGl2PlxcbjwvZGl2PlxcblwiO1xuLy8gRXhwb3J0c1xuZXhwb3J0IGRlZmF1bHQgY29kZTsiLCJcbmltcG9ydCBUYWJWaWV3IGZyb20gJy4vdGFidmlldyc7XG5pbXBvcnQgU2NoZW1hRm9ybSBmcm9tICcuL3NjaGVtYWZvcm0nO1xuaW1wb3J0IGh0bWwgZnJvbSAnLi9lZGl0b3IuaHRtbCc7XG5leHBvcnQgZGVmYXVsdCBjbGFzcyBFZGl0b3IgZXh0ZW5kcyBIVE1MRWxlbWVudCB7XG5cbiAgc2NoZW1hOiBhbnlcbiAgY29uc3RydWN0b3IoKSB7XG4gICAgc3VwZXIoKTtcblxuICAgIHdpbmRvdy5jdXN0b21FbGVtZW50cy5kZWZpbmUoICd0YWItdmlldycsIFRhYlZpZXcgKTtcbiAgICB3aW5kb3cuY3VzdG9tRWxlbWVudHMuZGVmaW5lKCAnc2NoZW1hLWZvcm0nLCBTY2hlbWFGb3JtICk7XG4gIH1cblxuICBnZXQgdGFiVmlldygpIHtcbiAgICByZXR1cm4gdGhpcy5xdWVyeVNlbGVjdG9yKCd0YWItdmlldycpIGFzIFRhYlZpZXc7XG4gIH1cblxuICBnZXQgc2NoZW1hTGlzdCgpIHtcbiAgICByZXR1cm4gdGhpcy5xdWVyeVNlbGVjdG9yKCcjc2NoZW1hLWxpc3QnKTtcbiAgfVxuXG4gIGNvbm5lY3RlZENhbGxiYWNrKCkge1xuICAgIHRoaXMuaW5uZXJIVE1MID0gaHRtbC50cmltKCk7XG4gICAgdGhpcy5zY2hlbWFMaXN0LmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgKGUpID0+IHRoaXMuY2xpY2tTY2hlbWEoZSkpO1xuXG4gICAgLy8gU2hvdyB3ZWxjb21lIHBhbmVcbiAgICBsZXQgaGVsbG8gPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCdkaXYnKTtcbiAgICBoZWxsby5hcHBlbmRDaGlsZCggZG9jdW1lbnQuY3JlYXRlVGV4dE5vZGUoICdIZWxsbywgV29ybGQhJyApICk7XG4gICAgdGhpcy50YWJWaWV3LmFkZFRhYihcIkhlbGxvXCIsIGhlbGxvKTtcblxuICAgIC8vIEFkZCBzY2hlbWEgbGlzdFxuICAgIGZvciAoIGxldCBzY2hlbWFOYW1lIG9mIE9iamVjdC5rZXlzKHRoaXMuc2NoZW1hKS5zb3J0KCkgKSB7XG4gICAgICBsZXQgbGkgPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCAnbGknICk7XG4gICAgICBsaS5kYXRhc2V0W1wic2NoZW1hXCJdID0gc2NoZW1hTmFtZTtcbiAgICAgIGxpLmFwcGVuZENoaWxkKCBkb2N1bWVudC5jcmVhdGVUZXh0Tm9kZSggc2NoZW1hTmFtZSApICk7XG4gICAgICB0aGlzLnNjaGVtYUxpc3QuYXBwZW5kQ2hpbGQoIGxpICk7XG4gICAgfVxuICB9XG5cbiAgY2xpY2tTY2hlbWEoZTpFdmVudCkge1xuICAgIGxldCBzY2hlbWFOYW1lID0gKDxIVE1MRWxlbWVudD5lLnRhcmdldCkuZGF0YXNldFtcInNjaGVtYVwiXTtcbiAgICAvLyBGaW5kIHRoZSBzY2hlbWEncyB0YWIgb3Igb3BlbiBvbmVcbiAgICBpZiAoIHRoaXMudGFiVmlldy5zaG93VGFiKCBzY2hlbWFOYW1lICkgKSB7XG4gICAgICByZXR1cm47XG4gICAgfVxuICAgIGxldCBlZGl0Rm9ybSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdzY2hlbWEtZm9ybScgKSBhcyBTY2hlbWFGb3JtO1xuICAgIGVkaXRGb3JtLnNjaGVtYSA9IHRoaXMuc2NoZW1hWyBzY2hlbWFOYW1lIF07XG4gICAgdGhpcy50YWJWaWV3LmFkZFRhYiggc2NoZW1hTmFtZSwgZWRpdEZvcm0gKTtcbiAgfVxufVxuXG4iLCJpbXBvcnQgeyBTY2hlbWFQcm9wZXJ0eSB9IGZyb20gJy4vc2NoZW1hJ1xuXG5leHBvcnQgYWJzdHJhY3QgY2xhc3MgU2NoZW1hRmllbGQgZXh0ZW5kcyBIVE1MRWxlbWVudCB7XG4gIG5hbWU6IHN0cmluZztcbiAgYWJzdHJhY3Qgc2NoZW1hOiBTY2hlbWFQcm9wZXJ0eTtcbiAgYWJzdHJhY3QgdmFsdWU6IGFueTtcbiAgc3RhdGljIGhhbmRsZXMoIGZpZWxkOiBTY2hlbWFQcm9wZXJ0eSApOiBib29sZWFuIHtcbiAgICByZXR1cm4gZmFsc2U7XG4gIH1cbn1cblxuZXhwb3J0IHR5cGUgU2NoZW1hRmllbGRDbGFzcyA9IHtcbiAgbmV3KCAuLi5hcmdzOiBhbnlbXSApOiBTY2hlbWFGaWVsZDtcbiAgaGFuZGxlcyhmaWVsZDogU2NoZW1hUHJvcGVydHkpOiBib29sZWFuO1xuICByZWdpc3RlcigpOiBzdHJpbmc7XG59XG5cbiIsImltcG9ydCB7IFNjaGVtYVByb3BlcnR5IH0gZnJvbSAnLi4vc2NoZW1hJ1xuaW1wb3J0IHsgU2NoZW1hRmllbGQsIFNjaGVtYUZpZWxkQ2xhc3MgfSBmcm9tICcuLi9zY2hlbWFmaWVsZCc7XG5cbmV4cG9ydCBkZWZhdWx0IGNsYXNzIFRleHRJbnB1dCBleHRlbmRzIFNjaGVtYUZpZWxkIHtcbiAgaW5wdXQ6IEhUTUxJbnB1dEVsZW1lbnQ7XG5cbiAgY29uc3RydWN0b3IoKSB7XG4gICAgc3VwZXIoKTtcbiAgICB0aGlzLmlucHV0ID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCggJ2lucHV0JyApO1xuICB9XG5cbiAgZ2V0IHZhbHVlKCk6IGFueSB7XG4gICAgcmV0dXJuIHRoaXMuaW5wdXQudmFsdWU7XG4gIH1cbiAgc2V0IHZhbHVlKCBuZXdWYWx1ZTogYW55ICkge1xuICAgIHRoaXMuaW5wdXQudmFsdWUgPSBuZXdWYWx1ZTtcbiAgfVxuXG4gIHNldCBzY2hlbWEoIG5ld1NjaGVtYTogU2NoZW1hUHJvcGVydHkgKSB7XG4gICAgY29uc29sZS5sb2coIFwiU2V0dGluZyBzY2hlbWEgZm9yIHRleHRpbnB1dFwiLCBuZXdTY2hlbWEgKTtcbiAgICBsZXQgZmllbGRUeXBlID0gJ3RleHQnO1xuICAgIGxldCBpbnB1dE1vZGUgPSAndGV4dCc7XG4gICAgbGV0IHBhdHRlcm4gPSBuZXdTY2hlbWEucGF0dGVybjtcblxuICAgIGlmICggbmV3U2NoZW1hLnR5cGUgPT09ICdzdHJpbmcnICkge1xuICAgICAgaWYgKCBuZXdTY2hlbWEuZm9ybWF0ID09PSAnZW1haWwnICkge1xuICAgICAgICBmaWVsZFR5cGUgPSAnZW1haWwnO1xuICAgICAgICBpbnB1dE1vZGUgPSAnZW1haWwnO1xuICAgICAgfVxuICAgICAgZWxzZSBpZiAoIG5ld1NjaGVtYS5mb3JtYXQgPT09ICd1cmwnICkge1xuICAgICAgICBmaWVsZFR5cGUgPSAndXJsJztcbiAgICAgICAgaW5wdXRNb2RlID0gJ3VybCc7XG4gICAgICB9XG4gICAgICBlbHNlIGlmICggbmV3U2NoZW1hLmZvcm1hdCA9PT0gJ3RlbCcgKSB7XG4gICAgICAgIGZpZWxkVHlwZSA9ICd0ZWwnO1xuICAgICAgICBpbnB1dE1vZGUgPSAndGVsJztcbiAgICAgIH1cbiAgICB9XG4gICAgZWxzZSBpZiAoIG5ld1NjaGVtYS50eXBlID09PSAnaW50ZWdlcicgfHwgbmV3U2NoZW1hLnR5cGUgPT09ICdudW1iZXInICkge1xuICAgICAgZmllbGRUeXBlID0gJ251bWJlcic7XG4gICAgICBpbnB1dE1vZGUgPSAnZGVjaW1hbCc7XG4gICAgICBpZiAoIG5ld1NjaGVtYS50eXBlICA9PT0gJ2ludGVnZXInICkge1xuICAgICAgICAvLyBVc2UgcGF0dGVybiB0byBzaG93IG51bWVyaWMgaW5wdXQgb24gaU9TXG4gICAgICAgIC8vIGh0dHBzOi8vY3NzLXRyaWNrcy5jb20vZmluZ2VyLWZyaWVuZGx5LW51bWVyaWNhbC1pbnB1dHMtd2l0aC1pbnB1dG1vZGUvXG4gICAgICAgIHBhdHRlcm4gPSBwYXR0ZXJuIHx8ICdbMC05XSonO1xuICAgICAgICBpbnB1dE1vZGUgPSAnbnVtZXJpYyc7XG4gICAgICB9XG4gICAgfVxuXG4gICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICd0eXBlJywgZmllbGRUeXBlICk7XG4gICAgdGhpcy5pbnB1dC5zZXRBdHRyaWJ1dGUoICdpbnB1dG1vZGUnLCBpbnB1dE1vZGUgKTtcbiAgICBpZiAoIHBhdHRlcm4gKSB7XG4gICAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ3BhdHRlcm4nLCBwYXR0ZXJuICk7XG4gICAgfVxuICAgIGlmICggbmV3U2NoZW1hLm1pbkxlbmd0aCApIHtcbiAgICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAnbWlubGVuZ3RoJywgbmV3U2NoZW1hLm1pbkxlbmd0aC50b1N0cmluZygpICk7XG4gICAgfVxuICAgIGlmICggbmV3U2NoZW1hLm1heExlbmd0aCApIHtcbiAgICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAnbWF4bGVuZ3RoJywgbmV3U2NoZW1hLm1heExlbmd0aC50b1N0cmluZygpICk7XG4gICAgfVxuICAgIGlmICggbmV3U2NoZW1hLm1pbmltdW0gKSB7XG4gICAgICB0aGlzLmlucHV0LnNldEF0dHJpYnV0ZSggJ21pbicsIG5ld1NjaGVtYS5taW5pbXVtLnRvU3RyaW5nKCkgKTtcbiAgICB9XG4gICAgaWYgKCBuZXdTY2hlbWEubWF4aW11bSApIHtcbiAgICAgIHRoaXMuaW5wdXQuc2V0QXR0cmlidXRlKCAnbWF4JywgbmV3U2NoZW1hLm1heGltdW0udG9TdHJpbmcoKSApO1xuICAgIH1cbiAgfVxuXG4gIGNvbm5lY3RlZENhbGxiYWNrKCkge1xuICAgIHRoaXMuYXBwZW5kQ2hpbGQoIHRoaXMuaW5wdXQgKTtcbiAgfVxuXG4gIHN0YXRpYyBoYW5kbGVzKCBmaWVsZDogU2NoZW1hUHJvcGVydHkgKTogYm9vbGVhbiB7XG4gICAgcmV0dXJuIHRydWU7XG4gIH1cblxuICBzdGF0aWMgcmVnaXN0ZXIoKTpzdHJpbmcge1xuICAgIGNvbnN0IHRhZ05hbWUgPSAnc2NoZW1hLXRleHQtaW5wdXQnO1xuICAgIHdpbmRvdy5jdXN0b21FbGVtZW50cy5kZWZpbmUoIHRhZ05hbWUsIFRleHRJbnB1dCApO1xuICAgIHJldHVybiB0YWdOYW1lO1xuICB9XG59XG4iLCJpbXBvcnQgeyBTY2hlbWFQcm9wZXJ0eSB9IGZyb20gJy4vc2NoZW1hJ1xuaW1wb3J0IHsgU2NoZW1hRmllbGQsIFNjaGVtYUZpZWxkQ2xhc3MgfSBmcm9tICcuL3NjaGVtYWZpZWxkJztcblxuZXhwb3J0IGRlZmF1bHQgY2xhc3MgU2NoZW1hRm9ybSBleHRlbmRzIEhUTUxFbGVtZW50IHtcblxuICBzdGF0aWMgX2ZpZWxkVHlwZXM6IHsgW2luZGV4OiBzdHJpbmddOiBTY2hlbWFGaWVsZENsYXNzIH0gPSB7fTtcbiAgc3RhdGljIF9maWVsZE9yZGVyOiBzdHJpbmdbXSA9IFtdO1xuICBfc2NoZW1hOiBPYmplY3Q7XG4gIF9yb290OiBEb2N1bWVudEZyYWdtZW50O1xuXG4gIGNvbnN0cnVjdG9yKCkge1xuICAgIHN1cGVyKCk7XG4gICAgLy8gVGhpcyBkb2N1bWVudCBmcmFnbWVudCBhbGxvd3MgdXMgdG8gYnVpbGQgdGhlIGZvcm0gYmVmb3JlXG4gICAgLy8gYW55dGhpbmcgaXMgYWRkZWQgdG8gdGhlIHBhZ2UgRE9NXG4gICAgdGhpcy5fcm9vdCA9IGRvY3VtZW50LmNyZWF0ZURvY3VtZW50RnJhZ21lbnQoKTtcbiAgfVxuXG4gIHN0YXRpYyBhZGRGaWVsZFR5cGUoIGZ0OiBTY2hlbWFGaWVsZENsYXNzICkge1xuICAgIGNvbnN0IHRhZ05hbWUgPSBmdC5yZWdpc3RlcigpO1xuICAgIFNjaGVtYUZvcm0uX2ZpZWxkT3JkZXIudW5zaGlmdCggdGFnTmFtZSApO1xuICAgIFNjaGVtYUZvcm0uX2ZpZWxkVHlwZXNbIHRhZ05hbWUgXSA9IGZ0O1xuICB9XG5cbiAgc2V0IHNjaGVtYShuZXdTY2hlbWE6IGFueSkge1xuICAgIGlmICggdGhpcy5fc2NoZW1hICkge1xuICAgICAgLy8gUmVtb3ZlIGV4aXN0aW5nIGZpZWxkc1xuICAgIH1cbiAgICBpZiAoIG5ld1NjaGVtYS5wcm9wZXJ0aWVzICkge1xuICAgICAgZm9yICggY29uc3QgcHJvcE5hbWUgaW4gbmV3U2NoZW1hLnByb3BlcnRpZXMgKSB7XG4gICAgICAgIGNvbnN0IHByb3AgPSBuZXdTY2hlbWEucHJvcGVydGllc1sgcHJvcE5hbWUgXTtcbiAgICAgICAgY29uc3QgZmllbGRUYWcgPSBTY2hlbWFGb3JtLl9maWVsZE9yZGVyLmZpbmQoXG4gICAgICAgICAgdGFnTmFtZSA9PiBTY2hlbWFGb3JtLl9maWVsZFR5cGVzWyB0YWdOYW1lIF0uaGFuZGxlcyggcHJvcCApXG4gICAgICAgICk7XG4gICAgICAgIGlmICggIWZpZWxkVGFnICkge1xuICAgICAgICAgIHRocm93IG5ldyBFcnJvciggYENvdWxkIG5vdCBmaW5kIGZpZWxkIHRvIGhhbmRsZSBwcm9wOiAke0pTT04uc3RyaW5naWZ5KHByb3ApfWAgKTtcbiAgICAgICAgfVxuICAgICAgICBjb25zdCBmaWVsZCA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoIGZpZWxkVGFnICkgYXMgU2NoZW1hRmllbGQ7XG4gICAgICAgIGZpZWxkLnNldEF0dHJpYnV0ZSggXCJuYW1lXCIsIHByb3BOYW1lICk7XG4gICAgICAgIGZpZWxkLnNjaGVtYSA9IHByb3A7XG4gICAgICAgIHRoaXMuX3Jvb3QuYXBwZW5kQ2hpbGQoIGZpZWxkICk7XG4gICAgICB9XG4gICAgfVxuICAgIC8vIFhYWDogSGFuZGxlIGFycmF5IHR5cGVzXG4gICAgdGhpcy5fc2NoZW1hID0gbmV3U2NoZW1hO1xuICB9XG5cbiAgc2V0IHZhbHVlKG5ld1ZhbHVlOiBhbnkpIHtcbiAgICBmb3IgKCBsZXQgcHJvcE5hbWUgaW4gbmV3VmFsdWUgKSB7XG4gICAgICBsZXQgZmllbGQgPSB0aGlzLnF1ZXJ5U2VsZWN0b3IoIGBbbmFtZT0ke3Byb3BOYW1lfV1gICkgYXMgU2NoZW1hRmllbGQ7XG4gICAgICBmaWVsZC52YWx1ZSA9IG5ld1ZhbHVlWyBwcm9wTmFtZSBdO1xuICAgIH1cbiAgfVxuXG4gIGdldCB2YWx1ZSgpOiBhbnkge1xuICAgIGxldCB2YWwgPSB7fSBhcyBhbnk7XG4gICAgZm9yICggY29uc3QgZWwgb2YgdGhpcy5fcm9vdC5jaGlsZHJlbiApIHtcbiAgICAgIGNvbnN0IGZpZWxkID0gZWwgYXMgU2NoZW1hRmllbGQ7XG4gICAgICB2YWxbIGZpZWxkLm5hbWUgXSA9IGZpZWxkLnZhbHVlO1xuICAgIH1cbiAgICByZXR1cm4gdmFsO1xuICB9XG5cbiAgY29ubmVjdGVkQ2FsbGJhY2soKSB7XG4gICAgdGhpcy5hcHBlbmRDaGlsZCggdGhpcy5fcm9vdCApO1xuICB9XG5cbn1cblxuaW1wb3J0IFRleHRJbnB1dCBmcm9tICcuL3NjaGVtYWZpZWxkL3RleHRpbnB1dCc7XG5TY2hlbWFGb3JtLmFkZEZpZWxkVHlwZSggVGV4dElucHV0ICk7XG5cbiIsIlxuaW1wb3J0IGh0bWwgZnJvbSAnLi90YWJ2aWV3Lmh0bWwnO1xuZXhwb3J0IGRlZmF1bHQgY2xhc3MgVGFiVmlldyBleHRlbmRzIEhUTUxFbGVtZW50IHtcblxuICBnZXQgdGFiQmFyKCkge1xuICAgIHJldHVybiB0aGlzLnF1ZXJ5U2VsZWN0b3IoICcjdGFiLWJhcicgKTtcbiAgfVxuICBnZXQgdGFiUGFuZXMoKSB7XG4gICAgcmV0dXJuIHRoaXMucXVlcnlTZWxlY3RvciggJyN0YWItcGFuZScgKTtcbiAgfVxuICBnZXQgdGFicygpOiBBcnJheTxIVE1MRWxlbWVudD4ge1xuICAgIHJldHVybiBBcnJheS5mcm9tKHRoaXMudGFiQmFyLmNoaWxkcmVuKSBhcyBBcnJheTxIVE1MRWxlbWVudD47XG4gIH1cblxuICBjb25uZWN0ZWRDYWxsYmFjaygpIHtcbiAgICB0aGlzLmlubmVySFRNTCA9IGh0bWwudHJpbSgpO1xuICAgIHRoaXMudGFiQmFyLmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgKGUpID0+IHRoaXMuY2xpY2tUYWIoZSkpO1xuICB9XG5cbiAgYWRkVGFiKCBsYWJlbDogc3RyaW5nLCBjb250ZW50OiBIVE1MRWxlbWVudCApIHtcbiAgICBjb25zdCBsaSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdsaScgKTtcbiAgICBsaS5hcHBlbmRDaGlsZCggZG9jdW1lbnQuY3JlYXRlVGV4dE5vZGUoIGxhYmVsICkgKTtcbiAgICB0aGlzLnRhYkJhci5hcHBlbmRDaGlsZCggbGkgKTtcbiAgICB0aGlzLnRhYlBhbmVzLmFwcGVuZENoaWxkKCBjb250ZW50ICk7XG4gICAgdGhpcy5zaG93VGFiKGxhYmVsKTtcbiAgfVxuXG4gIHNob3dUYWIoIGxhYmVsOiBzdHJpbmcgKSA6IGJvb2xlYW4ge1xuICAgIGxldCBpZHggPSB0aGlzLnRhYnMuZmluZEluZGV4KCBlbCA9PiBlbC5pbm5lclRleHQgPT0gbGFiZWwgKTtcbiAgICBpZiAoIGlkeCA8IDAgKSB7XG4gICAgICBjb25zb2xlLmxvZyggYENvdWxkIG5vdCBmaW5kIHRhYiB3aXRoIGxhYmVsICR7bGFiZWx9YCApO1xuICAgICAgcmV0dXJuIGZhbHNlO1xuICAgIH1cbiAgICBpZiAoIHRoaXMudGFiQmFyLnF1ZXJ5U2VsZWN0b3IoICcuYWN0aXZlJyApICkge1xuICAgICAgdGhpcy50YWJCYXIucXVlcnlTZWxlY3RvciggJy5hY3RpdmUnICkuY2xhc3NMaXN0LnJlbW92ZSggJ2FjdGl2ZScgKTtcbiAgICAgIHRoaXMudGFiUGFuZXMucXVlcnlTZWxlY3RvciggJy5hY3RpdmUnICkuY2xhc3NMaXN0LnJlbW92ZSggJ2FjdGl2ZScgKTtcbiAgICB9XG4gICAgdGhpcy50YWJCYXIuY2hpbGRyZW5baWR4XS5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTtcbiAgICB0aGlzLnRhYlBhbmVzLmNoaWxkcmVuW2lkeF0uY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7XG4gICAgcmV0dXJuIHRydWU7XG4gIH1cblxuICBjbGlja1RhYiggZTogRXZlbnQgKSB7XG4gIH1cbn1cblxuIiwiLy8gVGhlIG1vZHVsZSBjYWNoZVxudmFyIF9fd2VicGFja19tb2R1bGVfY2FjaGVfXyA9IHt9O1xuXG4vLyBUaGUgcmVxdWlyZSBmdW5jdGlvblxuZnVuY3Rpb24gX193ZWJwYWNrX3JlcXVpcmVfXyhtb2R1bGVJZCkge1xuXHQvLyBDaGVjayBpZiBtb2R1bGUgaXMgaW4gY2FjaGVcblx0dmFyIGNhY2hlZE1vZHVsZSA9IF9fd2VicGFja19tb2R1bGVfY2FjaGVfX1ttb2R1bGVJZF07XG5cdGlmIChjYWNoZWRNb2R1bGUgIT09IHVuZGVmaW5lZCkge1xuXHRcdHJldHVybiBjYWNoZWRNb2R1bGUuZXhwb3J0cztcblx0fVxuXHQvLyBDcmVhdGUgYSBuZXcgbW9kdWxlIChhbmQgcHV0IGl0IGludG8gdGhlIGNhY2hlKVxuXHR2YXIgbW9kdWxlID0gX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fW21vZHVsZUlkXSA9IHtcblx0XHQvLyBubyBtb2R1bGUuaWQgbmVlZGVkXG5cdFx0Ly8gbm8gbW9kdWxlLmxvYWRlZCBuZWVkZWRcblx0XHRleHBvcnRzOiB7fVxuXHR9O1xuXG5cdC8vIEV4ZWN1dGUgdGhlIG1vZHVsZSBmdW5jdGlvblxuXHRfX3dlYnBhY2tfbW9kdWxlc19fW21vZHVsZUlkXShtb2R1bGUsIG1vZHVsZS5leHBvcnRzLCBfX3dlYnBhY2tfcmVxdWlyZV9fKTtcblxuXHQvLyBSZXR1cm4gdGhlIGV4cG9ydHMgb2YgdGhlIG1vZHVsZVxuXHRyZXR1cm4gbW9kdWxlLmV4cG9ydHM7XG59XG5cbiIsIi8vIGRlZmluZSBnZXR0ZXIgZnVuY3Rpb25zIGZvciBoYXJtb255IGV4cG9ydHNcbl9fd2VicGFja19yZXF1aXJlX18uZCA9IChleHBvcnRzLCBkZWZpbml0aW9uKSA9PiB7XG5cdGZvcih2YXIga2V5IGluIGRlZmluaXRpb24pIHtcblx0XHRpZihfX3dlYnBhY2tfcmVxdWlyZV9fLm8oZGVmaW5pdGlvbiwga2V5KSAmJiAhX193ZWJwYWNrX3JlcXVpcmVfXy5vKGV4cG9ydHMsIGtleSkpIHtcblx0XHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBrZXksIHsgZW51bWVyYWJsZTogdHJ1ZSwgZ2V0OiBkZWZpbml0aW9uW2tleV0gfSk7XG5cdFx0fVxuXHR9XG59OyIsIl9fd2VicGFja19yZXF1aXJlX18ubyA9IChvYmosIHByb3ApID0+IChPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5LmNhbGwob2JqLCBwcm9wKSkiLCIvLyBkZWZpbmUgX19lc01vZHVsZSBvbiBleHBvcnRzXG5fX3dlYnBhY2tfcmVxdWlyZV9fLnIgPSAoZXhwb3J0cykgPT4ge1xuXHRpZih0eXBlb2YgU3ltYm9sICE9PSAndW5kZWZpbmVkJyAmJiBTeW1ib2wudG9TdHJpbmdUYWcpIHtcblx0XHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgU3ltYm9sLnRvU3RyaW5nVGFnLCB7IHZhbHVlOiAnTW9kdWxlJyB9KTtcblx0fVxuXHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7IHZhbHVlOiB0cnVlIH0pO1xufTsiLCJpbXBvcnQgRWRpdG9yIGZyb20gJy4vZWRpdG9yJ1xuY3VzdG9tRWxlbWVudHMuZGVmaW5lKCAneWFuY3ktZWRpdG9yJywgRWRpdG9yICk7XG4iXSwibmFtZXMiOltdLCJzb3VyY2VSb290IjoiIn0=