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
/* harmony import */ var _editor_html__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./editor.html */ "./lib/Yancy/resources/src/editor.html");


class Editor extends HTMLElement {
    constructor() {
        super();
        customElements.define('tab-view', _tabview__WEBPACK_IMPORTED_MODULE_0__["default"]);
        const shadow = this.attachShadow({ mode: 'open' });
        shadow.innerHTML = _editor_html__WEBPACK_IMPORTED_MODULE_1__["default"].trim();
        this.schemaList.addEventListener('click', (e) => this.clickSchema(e));
    }
    get tabView() {
        return this.shadowRoot.querySelector('tab-view');
    }
    get schemaList() {
        return this.shadowRoot.querySelector('#schema-list');
    }
    connectedCallback() {
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
        console.log(`Clicked schema ${schemaName}`);
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
    constructor() {
        super();
        const shadow = this.attachShadow({ mode: 'open' });
        shadow.innerHTML = _tabview_html__WEBPACK_IMPORTED_MODULE_0__["default"].trim();
        this.tabBar.addEventListener('click', (e) => this.clickTab(e));
    }
    get tabBar() {
        return this.shadowRoot.querySelector('#tab-bar');
    }
    get tabPanes() {
        return this.shadowRoot.querySelector('#tab-pane');
    }
    addTab(label, content) {
        const li = document.createElement('li');
        li.appendChild(document.createTextNode(label));
        this.tabBar.appendChild(li);
        this.tabPanes.appendChild(content);
        console.log("Activating...");
        this.showTab(this.tabBar.children.length - 1);
    }
    showTab(tabIndex) {
        if (this.tabBar.querySelector('.active')) {
            this.tabBar.querySelector('.active').classList.remove('active');
            this.tabPanes.querySelector('.active').classList.remove('active');
        }
        this.tabBar.children[tabIndex].classList.add('active');
        this.tabPanes.children[tabIndex].classList.add('active');
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
//# sourceMappingURL=data:application/json;charset=utf-8;base64,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QUM7SUFDM0QsQ0FBQztJQUVELFFBQVEsQ0FBRSxDQUFRO0lBQ2xCLENBQUM7Q0FDRjs7Ozs7OztVQ3hDRDtVQUNBOztVQUVBO1VBQ0E7VUFDQTtVQUNBO1VBQ0E7VUFDQTtVQUNBO1VBQ0E7VUFDQTtVQUNBO1VBQ0E7VUFDQTtVQUNBOztVQUVBO1VBQ0E7O1VBRUE7VUFDQTtVQUNBOzs7OztXQ3RCQTtXQUNBO1dBQ0E7V0FDQTtXQUNBLHlDQUF5Qyx3Q0FBd0M7V0FDakY7V0FDQTtXQUNBOzs7OztXQ1BBOzs7OztXQ0FBO1dBQ0E7V0FDQTtXQUNBLHVEQUF1RCxpQkFBaUI7V0FDeEU7V0FDQSxnREFBZ0QsYUFBYTtXQUM3RDs7Ozs7Ozs7Ozs7O0FDTjZCO0FBQzdCLGNBQWMsQ0FBQyxNQUFNLENBQUUsY0FBYyxFQUFFLCtDQUFNLENBQUUsQ0FBQyIsInNvdXJjZXMiOlsid2VicGFjazovL1lhbmN5Ly4vbGliL1lhbmN5L3Jlc291cmNlcy9zcmMvZWRpdG9yLmh0bWwiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy90YWJ2aWV3Lmh0bWwiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9lZGl0b3IudHMiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy90YWJ2aWV3LnRzIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svYm9vdHN0cmFwIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svcnVudGltZS9kZWZpbmUgcHJvcGVydHkgZ2V0dGVycyIsIndlYnBhY2s6Ly9ZYW5jeS93ZWJwYWNrL3J1bnRpbWUvaGFzT3duUHJvcGVydHkgc2hvcnRoYW5kIiwid2VicGFjazovL1lhbmN5L3dlYnBhY2svcnVudGltZS9tYWtlIG5hbWVzcGFjZSBvYmplY3QiLCJ3ZWJwYWNrOi8vWWFuY3kvLi9saWIvWWFuY3kvcmVzb3VyY2VzL3NyYy9pbmRleC50cyJdLCJzb3VyY2VzQ29udGVudCI6WyIvLyBNb2R1bGVcbnZhciBjb2RlID0gXCI8bmF2PlxcbiAgPHVsIGlkPVxcXCJzY2hlbWEtbGlzdFxcXCI+XFxuICA8L3VsPlxcbjwvbmF2Plxcbjx0YWItdmlldz5cXG48L3RhYi12aWV3PlxcblwiO1xuLy8gRXhwb3J0c1xuZXhwb3J0IGRlZmF1bHQgY29kZTsiLCIvLyBNb2R1bGVcbnZhciBjb2RlID0gXCI8c3R5bGU+XFxuI3RhYi1wYW5lID4gKiB7XFxuICBkaXNwbGF5OiBub25lO1xcbn1cXG4jdGFiLXBhbmUgPiAuYWN0aXZlIHtcXG4gIGRpc3BsYXk6IGJsb2NrO1xcbn1cXG48L3N0eWxlPlxcbjxkaXY+XFxuICA8dWwgaWQ9XFxcInRhYi1iYXJcXFwiPjwvdWw+XFxuICA8ZGl2IGlkPVxcXCJ0YWItcGFuZVxcXCI+PC9kaXY+XFxuPC9kaXY+XFxuXCI7XG4vLyBFeHBvcnRzXG5leHBvcnQgZGVmYXVsdCBjb2RlOyIsIlxuaW1wb3J0IFRhYlZpZXcgZnJvbSAnLi90YWJ2aWV3JztcbmltcG9ydCBodG1sIGZyb20gJy4vZWRpdG9yLmh0bWwnO1xuZXhwb3J0IGRlZmF1bHQgY2xhc3MgRWRpdG9yIGV4dGVuZHMgSFRNTEVsZW1lbnQge1xuXG4gIHNjaGVtYTogT2JqZWN0XG4gIGNvbnN0cnVjdG9yKCkge1xuICAgIHN1cGVyKCk7XG5cbiAgICBjdXN0b21FbGVtZW50cy5kZWZpbmUoICd0YWItdmlldycsIFRhYlZpZXcgKTtcblxuICAgIGNvbnN0IHNoYWRvdyA9IHRoaXMuYXR0YWNoU2hhZG93KHttb2RlOiAnb3Blbid9KTtcbiAgICBzaGFkb3cuaW5uZXJIVE1MID0gaHRtbC50cmltKCk7XG5cbiAgICB0aGlzLnNjaGVtYUxpc3QuYWRkRXZlbnRMaXN0ZW5lcignY2xpY2snLCAoZSkgPT4gdGhpcy5jbGlja1NjaGVtYShlKSk7XG4gIH1cblxuICBnZXQgdGFiVmlldygpIHtcbiAgICByZXR1cm4gdGhpcy5zaGFkb3dSb290LnF1ZXJ5U2VsZWN0b3IoJ3RhYi12aWV3JykgYXMgVGFiVmlldztcbiAgfVxuXG4gIGdldCBzY2hlbWFMaXN0KCkge1xuICAgIHJldHVybiB0aGlzLnNoYWRvd1Jvb3QucXVlcnlTZWxlY3RvcignI3NjaGVtYS1saXN0Jyk7XG4gIH1cblxuICBjb25uZWN0ZWRDYWxsYmFjaygpIHtcbiAgICAvLyBTaG93IHdlbGNvbWUgcGFuZVxuICAgIGxldCBoZWxsbyA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2RpdicpO1xuICAgIGhlbGxvLmFwcGVuZENoaWxkKCBkb2N1bWVudC5jcmVhdGVUZXh0Tm9kZSggJ0hlbGxvLCBXb3JsZCEnICkgKTtcbiAgICB0aGlzLnRhYlZpZXcuYWRkVGFiKFwiSGVsbG9cIiwgaGVsbG8pO1xuXG4gICAgLy8gQWRkIHNjaGVtYSBsaXN0XG4gICAgZm9yICggbGV0IHNjaGVtYU5hbWUgb2YgT2JqZWN0LmtleXModGhpcy5zY2hlbWEpLnNvcnQoKSApIHtcbiAgICAgIGxldCBsaSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoICdsaScgKTtcbiAgICAgIGxpLmRhdGFzZXRbXCJzY2hlbWFcIl0gPSBzY2hlbWFOYW1lO1xuICAgICAgbGkuYXBwZW5kQ2hpbGQoIGRvY3VtZW50LmNyZWF0ZVRleHROb2RlKCBzY2hlbWFOYW1lICkgKTtcbiAgICAgIHRoaXMuc2NoZW1hTGlzdC5hcHBlbmRDaGlsZCggbGkgKTtcbiAgICB9XG4gIH1cblxuICBjbGlja1NjaGVtYShlOkV2ZW50KSB7XG4gICAgbGV0IHNjaGVtYU5hbWUgPSAoPEhUTUxFbGVtZW50PmUudGFyZ2V0KS5kYXRhc2V0W1wic2NoZW1hXCJdO1xuICAgIGNvbnNvbGUubG9nKCBgQ2xpY2tlZCBzY2hlbWEgJHtzY2hlbWFOYW1lfWAgKTtcbiAgfVxufVxuXG4iLCJcbmltcG9ydCBodG1sIGZyb20gJy4vdGFidmlldy5odG1sJztcbmV4cG9ydCBkZWZhdWx0IGNsYXNzIFRhYlZpZXcgZXh0ZW5kcyBIVE1MRWxlbWVudCB7XG5cbiAgY29uc3RydWN0b3IoKSB7XG4gICAgc3VwZXIoKTtcblxuICAgIGNvbnN0IHNoYWRvdyA9IHRoaXMuYXR0YWNoU2hhZG93KHttb2RlOiAnb3Blbid9KTtcbiAgICBzaGFkb3cuaW5uZXJIVE1MID0gaHRtbC50cmltKCk7XG5cbiAgICB0aGlzLnRhYkJhci5hZGRFdmVudExpc3RlbmVyKCdjbGljaycsIChlKSA9PiB0aGlzLmNsaWNrVGFiKGUpKTtcbiAgfVxuXG4gIGdldCB0YWJCYXIoKSB7XG4gICAgcmV0dXJuIHRoaXMuc2hhZG93Um9vdC5xdWVyeVNlbGVjdG9yKCAnI3RhYi1iYXInICk7XG4gIH1cbiAgZ2V0IHRhYlBhbmVzKCkge1xuICAgIHJldHVybiB0aGlzLnNoYWRvd1Jvb3QucXVlcnlTZWxlY3RvciggJyN0YWItcGFuZScgKTtcbiAgfVxuXG4gIGFkZFRhYiggbGFiZWw6IHN0cmluZywgY29udGVudDogSFRNTEVsZW1lbnQgKSB7XG4gICAgY29uc3QgbGkgPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCAnbGknICk7XG4gICAgbGkuYXBwZW5kQ2hpbGQoIGRvY3VtZW50LmNyZWF0ZVRleHROb2RlKCBsYWJlbCApICk7XG4gICAgdGhpcy50YWJCYXIuYXBwZW5kQ2hpbGQoIGxpICk7XG4gICAgdGhpcy50YWJQYW5lcy5hcHBlbmRDaGlsZCggY29udGVudCApO1xuICAgIGNvbnNvbGUubG9nKCBcIkFjdGl2YXRpbmcuLi5cIiApO1xuICAgIHRoaXMuc2hvd1RhYih0aGlzLnRhYkJhci5jaGlsZHJlbi5sZW5ndGgtMSk7XG4gIH1cblxuICBzaG93VGFiKCB0YWJJbmRleDogbnVtYmVyICkge1xuICAgIGlmICggdGhpcy50YWJCYXIucXVlcnlTZWxlY3RvciggJy5hY3RpdmUnICkgKSB7XG4gICAgICB0aGlzLnRhYkJhci5xdWVyeVNlbGVjdG9yKCAnLmFjdGl2ZScgKS5jbGFzc0xpc3QucmVtb3ZlKCAnYWN0aXZlJyApO1xuICAgICAgdGhpcy50YWJQYW5lcy5xdWVyeVNlbGVjdG9yKCAnLmFjdGl2ZScgKS5jbGFzc0xpc3QucmVtb3ZlKCAnYWN0aXZlJyApO1xuICAgIH1cbiAgICB0aGlzLnRhYkJhci5jaGlsZHJlblt0YWJJbmRleF0uY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7XG4gICAgdGhpcy50YWJQYW5lcy5jaGlsZHJlblt0YWJJbmRleF0uY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7XG4gIH1cblxuICBjbGlja1RhYiggZTogRXZlbnQgKSB7XG4gIH1cbn1cblxuIiwiLy8gVGhlIG1vZHVsZSBjYWNoZVxudmFyIF9fd2VicGFja19tb2R1bGVfY2FjaGVfXyA9IHt9O1xuXG4vLyBUaGUgcmVxdWlyZSBmdW5jdGlvblxuZnVuY3Rpb24gX193ZWJwYWNrX3JlcXVpcmVfXyhtb2R1bGVJZCkge1xuXHQvLyBDaGVjayBpZiBtb2R1bGUgaXMgaW4gY2FjaGVcblx0dmFyIGNhY2hlZE1vZHVsZSA9IF9fd2VicGFja19tb2R1bGVfY2FjaGVfX1ttb2R1bGVJZF07XG5cdGlmIChjYWNoZWRNb2R1bGUgIT09IHVuZGVmaW5lZCkge1xuXHRcdHJldHVybiBjYWNoZWRNb2R1bGUuZXhwb3J0cztcblx0fVxuXHQvLyBDcmVhdGUgYSBuZXcgbW9kdWxlIChhbmQgcHV0IGl0IGludG8gdGhlIGNhY2hlKVxuXHR2YXIgbW9kdWxlID0gX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fW21vZHVsZUlkXSA9IHtcblx0XHQvLyBubyBtb2R1bGUuaWQgbmVlZGVkXG5cdFx0Ly8gbm8gbW9kdWxlLmxvYWRlZCBuZWVkZWRcblx0XHRleHBvcnRzOiB7fVxuXHR9O1xuXG5cdC8vIEV4ZWN1dGUgdGhlIG1vZHVsZSBmdW5jdGlvblxuXHRfX3dlYnBhY2tfbW9kdWxlc19fW21vZHVsZUlkXShtb2R1bGUsIG1vZHVsZS5leHBvcnRzLCBfX3dlYnBhY2tfcmVxdWlyZV9fKTtcblxuXHQvLyBSZXR1cm4gdGhlIGV4cG9ydHMgb2YgdGhlIG1vZHVsZVxuXHRyZXR1cm4gbW9kdWxlLmV4cG9ydHM7XG59XG5cbiIsIi8vIGRlZmluZSBnZXR0ZXIgZnVuY3Rpb25zIGZvciBoYXJtb255IGV4cG9ydHNcbl9fd2VicGFja19yZXF1aXJlX18uZCA9IChleHBvcnRzLCBkZWZpbml0aW9uKSA9PiB7XG5cdGZvcih2YXIga2V5IGluIGRlZmluaXRpb24pIHtcblx0XHRpZihfX3dlYnBhY2tfcmVxdWlyZV9fLm8oZGVmaW5pdGlvbiwga2V5KSAmJiAhX193ZWJwYWNrX3JlcXVpcmVfXy5vKGV4cG9ydHMsIGtleSkpIHtcblx0XHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBrZXksIHsgZW51bWVyYWJsZTogdHJ1ZSwgZ2V0OiBkZWZpbml0aW9uW2tleV0gfSk7XG5cdFx0fVxuXHR9XG59OyIsIl9fd2VicGFja19yZXF1aXJlX18ubyA9IChvYmosIHByb3ApID0+IChPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5LmNhbGwob2JqLCBwcm9wKSkiLCIvLyBkZWZpbmUgX19lc01vZHVsZSBvbiBleHBvcnRzXG5fX3dlYnBhY2tfcmVxdWlyZV9fLnIgPSAoZXhwb3J0cykgPT4ge1xuXHRpZih0eXBlb2YgU3ltYm9sICE9PSAndW5kZWZpbmVkJyAmJiBTeW1ib2wudG9TdHJpbmdUYWcpIHtcblx0XHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgU3ltYm9sLnRvU3RyaW5nVGFnLCB7IHZhbHVlOiAnTW9kdWxlJyB9KTtcblx0fVxuXHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7IHZhbHVlOiB0cnVlIH0pO1xufTsiLCJpbXBvcnQgRWRpdG9yIGZyb20gJy4vZWRpdG9yJ1xuY3VzdG9tRWxlbWVudHMuZGVmaW5lKCAneWFuY3ktZWRpdG9yJywgRWRpdG9yICk7XG4iXSwibmFtZXMiOltdLCJzb3VyY2VSb290IjoiIn0=