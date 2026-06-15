({
    showEmailToast: function(component, type, title, message) {
        try {
            var t = $A.get('e.force:showToast');
            if (t) {
                t.setParams({ title: title || '', message: message || '', type: type || 'info', duration: 5000 });
                t.fire();
            } else if (message) {
                component.set('v.errorMsg', message);
            }
        } catch (e) {
            if (message) component.set('v.errorMsg', message);
        }
    },
    watchStandardUploadFailure: function(component) {
        var self = this;
        if (window._fecUploadFailWatch) {
            try { document.removeEventListener('click', window._fecUploadFailWatch, true); } catch (e) {}
        }
        window._fecUploadFailWatch = $A.getCallback(function(evt) {
            var target = evt.target;
            var txt = (target && (target.innerText || target.textContent) || '').trim();
            if (txt !== 'Got It') return;
            var bodyText = (document.body && (document.body.innerText || document.body.textContent) || '');
            if (bodyText.indexOf('1 file is already in email') === -1 && bodyText.indexOf("Can't upload") === -1) return;
            window.setTimeout($A.getCallback(function() {
                component.set('v.showUploadModal', false);
                component.set('v.selectedCaseFileIds', []);
                self.showEmailToast(component, 'error', 'Error', component.get('v.lblFileAlreadyInEmail') || '1 file is already in email.');
                try { document.removeEventListener('click', window._fecUploadFailWatch, true); } catch (e) {}
                window._fecUploadFailWatch = null;
            }), 250);
        });
        document.addEventListener('click', window._fecUploadFailWatch, true);
    },
    FONTS: [
        {v:'',l:'(Default)',f:'inherit'},
        {v:'arial',l:'Arial',f:'Arial,sans-serif'},
        {v:'arial-black',l:'Arial Black',f:'"Arial Black",sans-serif'},
        {v:'arial-narrow',l:'Arial Narrow',f:'"Arial Narrow",sans-serif'},
        {v:'book-antiqua',l:'Book Antiqua',f:'"Book Antiqua",serif'},
        {v:'calibri',l:'Calibri',f:'Calibri,sans-serif'},
        {v:'cambria',l:'Cambria',f:'Cambria,serif'},
        {v:'comic-sans',l:'Comic Sans MS',f:'"Comic Sans MS",cursive'},
        {v:'courier-new',l:'Courier New',f:'"Courier New",monospace'},
        {v:'garamond',l:'Garamond',f:'Garamond,serif'},
        {v:'georgia',l:'Georgia',f:'Georgia,serif'},
        {v:'helvetica',l:'Helvetica',f:'Helvetica,sans-serif'},
        {v:'impact',l:'Impact',f:'Impact,sans-serif'},
        {v:'lucida',l:'Lucida Sans',f:'"Lucida Sans Unicode",sans-serif'},
        {v:'palatino',l:'Palatino',f:'"Palatino Linotype",serif'},
        {v:'tahoma',l:'Tahoma',f:'Tahoma,sans-serif'},
        {v:'times-new-roman',l:'Times New Roman',f:'"Times New Roman",serif'},
        {v:'trebuchet',l:'Trebuchet MS',f:'"Trebuchet MS",sans-serif'},
        {v:'verdana',l:'Verdana',f:'Verdana,sans-serif'}
    ],
    SIZES: [
        {v:'',l:'(Default)'},{v:'8px',l:'8'},{v:'9px',l:'9'},{v:'10px',l:'10'},
        {v:'11px',l:'11'},{v:'12px',l:'12'},{v:'14px',l:'14'},{v:'16px',l:'16'},
        {v:'18px',l:'18'},{v:'20px',l:'20'},{v:'24px',l:'24'},{v:'28px',l:'28'},
        {v:'36px',l:'36'},{v:'48px',l:'48'},{v:'72px',l:'72'}
    ],
    HEADERS: [
        {v:'',l:'Normal'},{v:'1',l:'Heading 1',sz:'2em',b:true},
        {v:'2',l:'Heading 2',sz:'1.5em',b:true},{v:'3',l:'Heading 3',sz:'1.17em',b:true},
        {v:'4',l:'Heading 4',sz:'1em',b:true},{v:'5',l:'Heading 5',sz:'.83em',b:false},
        {v:'6',l:'Heading 6',sz:'.67em',b:false}
    ],

    initQuill: function(component, bodyHtml) {
        var self = this;
        var run = function() {
            if (window.Quill) { self._buildEditor(component, bodyHtml); return; }
            var base = $A.get('$Resource.QuillEditor');
            if (!document.querySelector('link[data-fec-q]')) {
                var lnk = document.createElement('link');
                lnk.rel='stylesheet'; lnk.href=base+'/quill.snow.css';
                lnk.setAttribute('data-fec-q','1'); document.head.appendChild(lnk);
            }
            if (!document.querySelector('script[data-fec-q]')) {
                var scr = document.createElement('script');
                scr.src=base+'/quill.min.js'; scr.setAttribute('data-fec-q','1');
                scr.onload=$A.getCallback(function(){ self._buildEditor(component, bodyHtml); });
                document.head.appendChild(scr);
            } else {
                window.setTimeout($A.getCallback(function(){ if(window.Quill) self._buildEditor(component,bodyHtml); }),400);
            }
        };
        window.setTimeout($A.getCallback(run), 120);
    },

    _buildEditor: function(component, bodyHtml) {
        var wrapper = component.find('quillWrapper');
        if (!wrapper) return;
        var wrapEl = wrapper.getElement();
        if (!wrapEl) return;
        if (window._fecQuill) { window._fecQuill = null; }
        wrapEl.innerHTML = '';
        var self = this;
        if (!window._fecQReg) {
            var FA = window.Quill.import('formats/font');
            FA.whitelist = self.FONTS.filter(function(f){return f.v;}).map(function(f){return f.v;});
            window.Quill.register(FA, true);
            var SA = window.Quill.import('attributors/style/size');
            SA.whitelist = self.SIZES.filter(function(s){return s.v;}).map(function(s){return s.v;});
            window.Quill.register(SA, true);
            // Allow http/https image src (Quill strips non-data URLs by default)
            var ImageBlot = window.Quill.import('formats/image');
            var origSanitize = ImageBlot.sanitize;
            ImageBlot.sanitize = function(url) {
                var httpRe = new RegExp('^https?:\\/\\/','i');
                var dataRe = new RegExp('^data:image\\/','i');
                if (httpRe.test(url) || dataRe.test(url)) return url;
                return origSanitize ? origSanitize(url) : url;
            };
            window.Quill.register(ImageBlot, true);
            // Register quill-better-table
            if (window.quillBetterTable) {
                window.Quill.register({'modules/better-table': window.quillBetterTable}, true);
            }
            window._fecQReg = true;        }
        if (!window._fecQCss) {
            var st = document.createElement('style');
            st.setAttribute('data-fec-qcss','1');
            st.innerHTML = self._css();
            document.head.appendChild(st);
            // Inject table border override riÃªng vá»›i priority cao nháº¥t
            var stTbl = document.createElement('style');
            stTbl.setAttribute('data-fec-qtbl','1');
            stTbl.innerHTML = [
                '.ql-editor table{border-collapse:collapse!important;width:100%!important}',
                '.ql-editor table tr td,.ql-editor table tr th{border:1px solid #999!important;padding:6px 10px!important;min-width:40px!important}',
                '.ql-editor table{border:1px solid #999!important}'
            ].join('');
            document.head.appendChild(stTbl);
            window._fecQCss = true;
        } else {
            // Update existing style with latest CSS
            var existSt = document.querySelector('style[data-fec-qcss]');
            if (existSt) existSt.innerHTML = self._css();
        }
        // Shared fixed dropdown container (appended to body)
        if (!window._fecQDD) {
            var dd = document.createElement('div');
            dd.id = 'fec-q-dd';
            dd.style.cssText = 'display:none;position:fixed;z-index:999999;background:#fff;border:1px solid #c8c8c8;border-radius:4px;box-shadow:0 4px 12px rgba(0,0,0,.18);min-width:160px;max-height:240px;overflow-y:auto;';
            document.body.appendChild(dd);
            window._fecQDD = dd;
        }
        var tbEl = document.createElement('div');
        tbEl.className = 'fec-tb';
        tbEl.innerHTML = self._tbHtml();
        wrapEl.appendChild(tbEl);
        var edEl = document.createElement('div');
        edEl.className = 'fec-ed';
        wrapEl.appendChild(edEl);
        var quill = new window.Quill(edEl, {
            theme: 'snow', placeholder: 'Write your email...',
            modules: { toolbar: { container: [], handlers: { image: function() {} } } }
        });
        var body = bodyHtml || component.get('v.body') || '';
        if (body) {
            window.setTimeout(function() {
                self._setEditorHtml(component, quill, body);
            }, 50);
        }
        // Set default font Times New Roman
        quill.root.style.fontFamily = '"Times New Roman",serif';
        quill.root.style.fontSize = '14px';
        window._fecQuill = quill;
        // Template HTML is written directly to the editor DOM, so use a native paste
        // handler to keep pasted content at the real browser caret position.
        quill.root.addEventListener('paste', function(e) {
            var sel = window.getSelection && window.getSelection();
            if (!sel || sel.rangeCount === 0) return;
            var range = sel.getRangeAt(0);
            if (!quill.root.contains(range.commonAncestorContainer)) return;

            e.preventDefault();
            e.stopImmediatePropagation();

            var cd = e.clipboardData || window.clipboardData;
            var text = cd ? cd.getData('text/plain') : '';
            var html = cd ? cd.getData('text/html') : '';

            window._fecPasteUndoHtml = quill.root.innerHTML;
            // Prefer browser editing commands so paste is added to the native undo stack
            // and Ctrl+Z can undo it. Plain text keeps insertion inline at the caret.
            sel.removeAllRanges();
            sel.addRange(range);
            if (text) {
                document.execCommand('insertText', false, text);
            } else if (html) {
                document.execCommand('insertHTML', false, self.cleanBody(html));
            }
            self._makeTableCellsEditable(quill.root);
            component.set('v.body', quill.root.innerHTML);
            component.set('v.rawBody', quill.root.innerHTML);
        }, true);
        // Override Quill's built-in image handler (uses window.prompt by default)
        var tbMod = quill.getModule('toolbar');
        if (tbMod) tbMod.addHandler('image', function() {});
        self._wire(tbEl, quill, component);
        quill.on('text-change', function() { self._syncEditorBody(component, quill); });
        quill.root.addEventListener('keydown', function(e) {
            var key = e && e.key;
            if (key && key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
                self._applyActiveToolbarFormats(tbEl, quill);
            }
        }, true);
        quill.root.addEventListener('input', function() { self._saveNativeSelection(quill); self._syncEditorBody(component, quill); });
        quill.root.addEventListener('keyup', function() { self._saveNativeSelection(quill); self._syncEditorBody(component, quill); });
        quill.root.addEventListener('mouseup', function() { self._saveNativeSelection(quill); self._syncEditorBody(component, quill); });
        // tungnm37 thÃªm: láº¯ng nghe event thÃªm áº£nh vÃ o attachments list
        // KhÃ´ng thÃªm vÃ o attachments list â€” áº£nh chá»‰ hiá»ƒn thá»‹ inline trong editor
        // (blob URL sáº½ bá»‹ strip khi gá»­i, khÃ´ng gá»­i kÃ¨m attachment)
    },


    _tbHtml: function() {
        var self = this;
        // SVG icons
        var ic = {
            bold:'<svg viewBox="0 0 18 18"><path d="M5,4H9.5A2.5,2.5,0,0,1,12,6.5v0A2.5,2.5,0,0,1,9.5,9H5ZM5,9h5.5A2.5,2.5,0,0,1,13,11.5v0A2.5,2.5,0,0,1,10.5,14H5Z" style="fill:none;stroke:#333;stroke-width:1.5"/></svg>',
            italic:'<svg viewBox="0 0 18 18"><line x1="7" x2="13" y1="4" y2="4" style="stroke:#333;stroke-width:1.5"/><line x1="5" x2="11" y1="14" y2="14" style="stroke:#333;stroke-width:1.5"/><line x1="11" x2="7" y1="4" y2="14" style="stroke:#333;stroke-width:1.5"/></svg>',
            underline:'<svg viewBox="0 0 18 18"><path d="M5,3V9a4,4,0,0,0,8,0V3" style="fill:none;stroke:#333;stroke-width:1.5"/><rect x="3" y="15" width="12" height="1.5" rx="0.75" style="fill:#333"/></svg>',
            strike:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><path d="M5.5,4.5A3.5,2,0,0,1,12.5,4.5" style="fill:none;stroke:#333;stroke-width:1.5"/><path d="M5.5,13.5A3.5,2,0,0,0,12.5,13.5" style="fill:none;stroke:#333;stroke-width:1.5"/></svg>',
            ol:'<svg viewBox="0 0 18 18"><line x1="7" x2="15" y1="4" y2="4" style="stroke:#333;stroke-width:1.5"/><line x1="7" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><line x1="7" x2="15" y1="14" y2="14" style="stroke:#333;stroke-width:1.5"/><text x="2.5" y="5.5" style="font-size:5px;fill:#333">1</text><text x="2.5" y="10.5" style="font-size:5px;fill:#333">2</text><text x="2.5" y="15.5" style="font-size:5px;fill:#333">3</text></svg>',
            ul:'<svg viewBox="0 0 18 18"><line x1="7" x2="15" y1="4" y2="4" style="stroke:#333;stroke-width:1.5"/><line x1="7" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><line x1="7" x2="15" y1="14" y2="14" style="stroke:#333;stroke-width:1.5"/><circle cx="3.5" cy="4" r="1.5" style="fill:#333"/><circle cx="3.5" cy="9" r="1.5" style="fill:#333"/><circle cx="3.5" cy="14" r="1.5" style="fill:#333"/></svg>',
            indent_dec:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="14" y2="14" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="4" y2="4" style="stroke:#333;stroke-width:1.5"/><line x1="7" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><polyline points="5,7 3,9 5,11" style="fill:none;stroke:#333;stroke-width:1.5"/></svg>',
            indent_inc:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="14" y2="14" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="4" y2="4" style="stroke:#333;stroke-width:1.5"/><line x1="7" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><polyline points="3,7 5,9 3,11" style="fill:none;stroke:#333;stroke-width:1.5"/></svg>',
            align_l:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="5" y2="5" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="13" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="13" y2="13" style="stroke:#333;stroke-width:1.5"/></svg>',
            align_c:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="5" y2="5" style="stroke:#333;stroke-width:1.5"/><line x1="5" x2="13" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="13" y2="13" style="stroke:#333;stroke-width:1.5"/></svg>',
            align_r:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="5" y2="5" style="stroke:#333;stroke-width:1.5"/><line x1="5" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="13" y2="13" style="stroke:#333;stroke-width:1.5"/></svg>',
            align_j:'<svg viewBox="0 0 18 18"><line x1="3" x2="15" y1="5" y2="5" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="9" y2="9" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="15" y1="13" y2="13" style="stroke:#333;stroke-width:1.5"/></svg>',
            link:'<svg viewBox="0 0 18 18"><path d="M7,9a4,4,0,0,0,5.66,0l1.41-1.41a4,4,0,0,0-5.66-5.66L7,3.34" style="fill:none;stroke:#333;stroke-width:1.5"/><path d="M11,9a4,4,0,0,0-5.66,0L3.93,10.41a4,4,0,0,0,5.66,5.66L11,14.66" style="fill:none;stroke:#333;stroke-width:1.5"/></svg>',
            image:'<svg viewBox="0 0 18 18"><rect x="2" y="3" width="14" height="12" rx="1" style="fill:none;stroke:#333;stroke-width:1.5"/><circle cx="6.5" cy="7.5" r="1.5" style="fill:#333"/><polyline points="2,13 6,9 9,12 12,8 16,13" style="fill:none;stroke:#333;stroke-width:1.5"/></svg>',
            code:'<svg viewBox="0 0 18 18"><polyline points="5,7 2,9 5,11" style="fill:none;stroke:#333;stroke-width:1.5"/><polyline points="13,7 16,9 13,11" style="fill:none;stroke:#333;stroke-width:1.5"/><line x1="11" x2="7" y1="4" y2="14" style="stroke:#333;stroke-width:1.5"/></svg>',
            quote:'<svg viewBox="0 0 18 18"><path d="M6,7H3A1,1,0,0,0,2,8v3a1,1,0,0,0,1,1H5l-1,2H6l1-2V8A1,1,0,0,0,6,7Z" style="fill:#333"/><path d="M13,7H10A1,1,0,0,0,9,8v3a1,1,0,0,0,1,1h2l-1,2h2l1-2V8A1,1,0,0,0,13,7Z" style="fill:#333"/></svg>',
            table:'<svg viewBox="0 0 18 18"><rect x="2" y="2" width="14" height="14" rx="1" style="fill:none;stroke:#333;stroke-width:1.5"/><line x1="2" x2="16" y1="7" y2="7" style="stroke:#333;stroke-width:1.2"/><line x1="2" x2="16" y1="12" y2="12" style="stroke:#333;stroke-width:1.2"/><line x1="7" x2="7" y1="2" y2="16" style="stroke:#333;stroke-width:1.2"/><line x1="12" x2="12" y1="2" y2="16" style="stroke:#333;stroke-width:1.2"/></svg>',
            clean:'<svg viewBox="0 0 18 18"><line x1="5" x2="13" y1="3" y2="3" style="stroke:#333;stroke-width:1.5"/><line x1="9" x2="9" y1="3" y2="13" style="stroke:#333;stroke-width:1.5"/><line x1="5" x2="13" y1="15" y2="15" style="stroke:#333;stroke-width:1.5"/><line x1="3" x2="6" y1="12" y2="15" style="stroke:#c23934;stroke-width:1.5"/></svg>'
        };
        function btn(cmd, val, icon, title) {
            return '<button class="fec-btn" data-cmd="'+cmd+'" data-val="'+(val||'')+'" title="'+title+'">'+icon+'</button>';
        }
        function sep() { return '<span class="fec-sep"></span>'; }
        function picker(type, label) {
            return '<div class="fec-pk" data-pk="'+type+'"><button class="fec-pk-btn" type="button">'+label+' <svg width="8" height="5" viewBox="0 0 8 5"><path d="M0,0 L4,5 L8,0Z" fill="#555"/></svg></button></div>';
        }
        function grp(content) { return '<div class="fec-grp">' + content + '</div>'; }
        return '<div class="fec-tb-r1">'
            + picker('font','Font') + picker('size','Size') + picker('header','Format')
            + grp(btn('bold','',ic.bold,'Bold') + btn('italic','',ic.italic,'Italic')
                + btn('underline','',ic.underline,'Underline') + btn('strike','',ic.strike,'Strikethrough'))
            + grp('<button class="fec-clr-btn" data-cmd="color" title="Text Color"><span class="fec-clr-a" id="fec-clr-ind" style="border-bottom:3px solid #000">A</span><svg width="6" height="4" viewBox="0 0 6 4"><path d="M0,0 L3,4 L6,0Z" fill="#555"/></svg></button>'
                + '<button class="fec-clr-btn" data-cmd="background" title="Highlight"><span class="fec-clr-a fec-clr-bg" id="fec-bg-ind" style="background:#ffff00">A</span><svg width="6" height="4" viewBox="0 0 6 4"><path d="M0,0 L3,4 L6,0Z" fill="#555"/></svg></button>')
            + grp(btn('list','bullet',ic.ul,'Bullet List') + btn('list','ordered',ic.ol,'Numbered List')
                + btn('indent','-1',ic.indent_dec,'Decrease Indent') + btn('indent','+1',ic.indent_inc,'Increase Indent'))
            + grp(btn('align','',ic.align_l,'Align Left') + btn('align','center',ic.align_c,'Center')
                + btn('align','right',ic.align_r,'Align Right') + btn('align','justify',ic.align_j,'Justify'))
            + grp(btn('link','',ic.link,'Insert Link') + btn('image','',ic.image,'Insert Image') + btn('table','',ic.table,'Insert Table')
                + btn('blockquote','',ic.quote,'Blockquote')
                + btn('clean','',ic.clean,'Remove Formatting'))
            + '</div>';
    },


    _setEditorHtml: function(component, quill, html) {
        if (!quill || !quill.root) return;
        var cleaned = this.cleanBody(html || '');
        try {
            if (quill.scroll && quill.scroll.observer) {
                quill.scroll.observer.disconnect();
            }
            quill.setText('', 'silent');
            quill.clipboard.dangerouslyPasteHTML(0, cleaned, 'silent');
        } catch (e) {
            quill.root.innerHTML = cleaned;
        }
        quill.root.classList.remove('ql-blank');
        this._makeTableCellsEditable(quill.root);
        this._syncEditorBody(component, quill);
        var self = this;
        window.setTimeout(function() {
            if (quill.scroll && quill.scroll.observer) {
                quill.scroll.observer.observe(quill.root, quill.scroll.observer._options || { childList: true, subtree: true, characterData: true });
            }
            self._syncEditorBody(component, quill);
        }, 100);
    },

    _formatQuillSelection: function(component, quill, name, value) {
        if (!quill || !quill.root) return;
        this._focusRestoreSelection(quill);
        var range = quill.getSelection(true);
        if (!range) return;
        quill.format(name, value, 'user');
        quill.root.classList.remove('ql-blank');
        this._makeTableCellsEditable(quill.root);
        this._syncEditorBody(component, quill);
    },
    _syncEditorBody: function(component, quill) {
        if (!quill || !quill.root) return;
        component.set('v.body', quill.root.innerHTML);
        component.set('v.rawBody', quill.root.innerHTML);
    },

    _applyActiveToolbarFormats: function(tbEl, quill) {
        if (!tbEl || !quill) return;
        try {
            var range = quill.getSelection(true);
            if (!range || range.length !== 0) return;
            ['bold', 'italic', 'underline', 'strike'].forEach(function(cmd) {
                var btn = tbEl.querySelector('.fec-btn[data-cmd="' + cmd + '"]');
                if (btn && btn.classList.contains('fec-active')) {
                    quill.format(cmd, true, 'silent');
                }
            });
        } catch (e) {}
    },

    _saveNativeSelection: function(quill) {
        try {
            if (!quill || !quill.root) return null;
            var sel = window.getSelection && window.getSelection();
            if (!sel || sel.rangeCount === 0) return null;
            var range = sel.getRangeAt(0);
            if (!quill.root.contains(range.commonAncestorContainer)) return null;
            window._fecEmailSavedRange = range.cloneRange();
            return window._fecEmailSavedRange;
        } catch (e) {
            return null;
        }
    },
    _focusRestoreSelection: function(quill) {
        if (!quill || !quill.root) return false;
        try {
            var sel = window.getSelection && window.getSelection();
            var saved = window._fecEmailSavedRange;

            quill.root.focus();

            if (sel && saved && quill.root.contains(saved.commonAncestorContainer)) {
                sel.removeAllRanges();
                sel.addRange(saved);
                return true;
            }

            if (sel && sel.rangeCount > 0 && quill.root.contains(sel.getRangeAt(0).commonAncestorContainer)) {
                window._fecEmailSavedRange = sel.getRangeAt(0).cloneRange();
                return true;
            }

            return false;
        } catch (e) { return false; }
    },

    _nativeFormat: function(component, quill, command, value) {
        if (!quill || !quill.root) return;
        // tungnm37 fix: chi chay khi co selection hop le trong editor
        var sel = window.getSelection && window.getSelection();
        var inEditor = sel && sel.rangeCount > 0 && quill.root.contains(sel.getRangeAt(0).commonAncestorContainer);
        var saved = window._fecEmailSavedRange;
        var savedOk = saved && quill.root.contains(saved.commonAncestorContainer);
        if (!inEditor && !savedOk) { return; }
        this._focusRestoreSelection(quill);
        try { document.execCommand(command, false, value); } catch (e) {}
        if (quill.root) quill.root.classList.remove('ql-blank');
        this._makeTableCellsEditable(quill.root);
        this._syncEditorBody(component, quill);
    },

    _applyHeaderStyleUsingFontTags: function(component, quill, headerConfig) {
        // Avoid formatBlock and Range.extractContents: both can corrupt complex email templates.
        // Reuse the same browser command path as Size picker, then convert generated font tags to inline styles.
        this._focusRestoreSelection(quill);
        try { document.execCommand('fontSize', false, '3'); } catch (e) {}
        if (quill && quill.root) {
            var sz = (headerConfig && headerConfig.sz) ? headerConfig.sz : '14px';
            var fw = (headerConfig && headerConfig.b) ? '700' : '400';
            quill.root.querySelectorAll('font[size="3"]').forEach(function(n) {
                n.removeAttribute('size');
                n.style.fontSize = sz;
                n.style.fontWeight = fw;
                n.style.lineHeight = '1.25';
            });
            quill.root.classList.remove('ql-blank');
            this._makeTableCellsEditable(quill.root);
        }
        this._syncEditorBody(component, quill);
    },
    _applyInlineStyleToSelection: function(component, quill, styleMap) {
        this._focusRestoreSelection(quill);
        try {
            var sel = window.getSelection && window.getSelection();
            if (!sel || sel.rangeCount === 0 || !quill || !quill.root) return;
            var range = sel.getRangeAt(0);
            if (!quill.root.contains(range.commonAncestorContainer)) return;

            // Do not use formatBlock for templates/images/tables. It can restructure the editor DOM
            // and drop content after the selected block. Wrap only the selected fragment inline.
            if (range.collapsed) return;

            var span = document.createElement('span');
            Object.keys(styleMap || {}).forEach(function(k) {
                if (styleMap[k] !== null && styleMap[k] !== undefined && styleMap[k] !== '') {
                    span.style[k] = styleMap[k];
                }
            });

            var frag = range.extractContents();
            span.appendChild(frag);
            range.insertNode(span);

            var newRange = document.createRange();
            newRange.selectNodeContents(span);
            sel.removeAllRanges();
            sel.addRange(newRange);
            window._fecEmailSavedRange = newRange.cloneRange();
        } catch (e) {}
        if (quill && quill.root) quill.root.classList.remove('ql-blank');
        this._makeTableCellsEditable(quill.root);
        this._syncEditorBody(component, quill);
    },
    // tungnm37 fix v2: dung Quill API, khong cham DOM truc tiep
    _indentBlocks: function(component, quill, direction) {
        if (!quill || !quill.root) return;
        // Buoc 1: dam bao co native selection trong editor
        var nsel = window.getSelection && window.getSelection();
        var savedNative = window._fecEmailSavedRange;
        var hasNative = nsel && nsel.rangeCount > 0 && quill.root.contains(nsel.getRangeAt(0).commonAncestorContainer);
        var hasSaved = savedNative && quill.root.contains(savedNative.commonAncestorContainer);
        if (!hasNative && !hasSaved) {
            // Dat caret vao cuoi noi dung de van indent duoc
            quill.focus();
            var len = quill.getLength();
            quill.setSelection(Math.max(0, len - 1), 0, 'silent');
        } else {
            this._focusRestoreSelection(quill);
        }
        // Buoc 2: lay Quill range tu native selection
        var qRange = quill.getSelection(true);
        if (!qRange) {
            qRange = { index: Math.max(0, quill.getLength() - 1), length: 0 };
        }
        // Buoc 3: tim cac line/block ma range bao trum, apply format indent qua Quill API
        var lines = quill.getLines(qRange.index, Math.max(qRange.length, 1));
        if (!lines || !lines.length) {
            // Fallback: chi line tai vi tri caret
            try { lines = [quill.getLine(qRange.index)[0]]; } catch (e) {}
        }
        if (!lines || !lines.length) return;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (!line || !line.format) continue;
            try {
                var fmt = line.formats ? line.formats() : {};
                var current = parseInt(fmt && fmt.indent, 10) || 0;
                var next = current + direction;
                if (next < 0) next = 0;
                if (next > 8) next = 8;
                line.format('indent', next || false);
            } catch (e2) {}
        }
        quill.root.classList.remove('ql-blank');
        this._makeTableCellsEditable(quill.root);
        // Sync v.body sau khi format
        component.set('v.body', quill.root.innerHTML);
        component.set('v.rawBody', quill.root.innerHTML);
        // Luu lai native range moi
        try {
            var ns = window.getSelection && window.getSelection();
            if (ns && ns.rangeCount > 0) {
                window._fecEmailSavedRange = ns.getRangeAt(0).cloneRange();
            }
        } catch (e3) {}
    },

    _applyBlockTag: function(component, quill, tagName) {
        this._focusRestoreSelection(quill);
        try { document.execCommand('formatBlock', false, tagName || 'p'); } catch (e) {}
        this._syncEditorBody(component, quill);
    },
    _wire: function(tbEl, quill, component) {
        var self = this;
        var ddEl = window._fecQDD;
        var activePk = null;

        function closeDD() {
            if (ddEl) { ddEl.style.display='none'; ddEl.innerHTML=''; }
            activePk = null;
        }

        // Picker buttons â€” open fixed dropdown
        tbEl.querySelectorAll('.fec-pk').forEach(function(pk) {
            pk.querySelector('.fec-pk-btn').addEventListener('mousedown', function(e) {
                e.preventDefault();
                self._saveNativeSelection(quill);
                var type = pk.getAttribute('data-pk');
                if (activePk === pk) { closeDD(); return; }
                closeDD();
                activePk = pk;
                // Build items
                var items = [];
                if (type === 'font') { items = self.FONTS; }
                else if (type === 'size') { items = self.SIZES; }
                else { items = self.HEADERS; }
                var headers = {font:'Font Name',size:'Font Size',header:'Paragraph Format'};
                var html = '<div style="padding:5px 10px;font-size:11px;font-weight:700;color:#444;background:#ebebeb;border-bottom:1px solid #ddd;position:sticky;top:0">'+headers[type]+'</div>';
                items.forEach(function(it) {
                    var style = '';
                    if (type==='font' && it.f && it.f!=='inherit') style='font-family:'+it.f+';';
                    if (type==='header' && it.sz) style='font-size:'+it.sz+';'+(it.b?'font-weight:bold;':'');
                    html += '<div class="fec-dd-it" data-val="'+(it.v||'')+'" style="'+style+'">'+it.l+'</div>';
                });
                ddEl.innerHTML = html;
                // Position using fixed coords
                var rect = pk.getBoundingClientRect();
                ddEl.style.display = 'block';
                ddEl.style.left = rect.left + 'px';
                ddEl.style.top = (rect.bottom + 2) + 'px';
                ddEl.style.minWidth = Math.max(rect.width, 160) + 'px';
                // Flip up if off screen
                var ddH = ddEl.offsetHeight;
                if (rect.bottom + ddH + 2 > window.innerHeight) {
                    ddEl.style.top = (rect.top - ddH - 2) + 'px';
                }
                // Item click
                ddEl.querySelectorAll('.fec-dd-it').forEach(function(it) {
                    it.addEventListener('mousedown', function(e2) {
                        e2.preventDefault();
                        self._focusRestoreSelection(quill);
                        var val = it.getAttribute('data-val');
                        // Update button label
                        pk.querySelector('.fec-pk-btn').childNodes[0].textContent = it.textContent + ' ';
                        closeDD();
                        if (type==='font') {
                            var ff = (items.filter(function(x){return x.v===val;})[0] || {}).f || '';
                            self._formatQuillSelection(component, quill, 'font', val || false);
                        } else if (type==='size') {
                            var px = val || '';
                            self._formatQuillSelection(component, quill, 'size', px || false);
                        } else {
                            var hd = (items.filter(function(x){return x.v===val;})[0] || {});
                            self._formatQuillSelection(component, quill, 'header', val ? parseInt(val, 10) : false);
                        }
                    });
                });
            });
        });

        // Format buttons
        tbEl.querySelectorAll('.fec-btn').forEach(function(btn) {
            btn.addEventListener('mousedown', function(e) {
                e.preventDefault();
                closeDD();
                var cmd = btn.getAttribute('data-cmd');
                var val = btn.getAttribute('data-val');
                if (cmd==='bold'||cmd==='italic'||cmd==='underline'||cmd==='strike') {
                    var qCmd = cmd === 'strike' ? 'strike' : cmd;
                    self._focusRestoreSelection(quill);
                    var nextValue = !btn.classList.contains('fec-active');
                    self._formatQuillSelection(component, quill, qCmd, nextValue);
                    btn.classList.toggle('fec-active', nextValue);
                } else if (cmd==='list') {
                    self._nativeFormat(component, quill, val === 'ordered' ? 'insertOrderedList' : 'insertUnorderedList', null);
                } else if (cmd==='indent') {
                    // tungnm37 fix: dung DOM thuan thay vi execCommand de tranh Quill wipe template
                    self._indentBlocks(component, quill, val === '-1' ? -1 : 1);
                } else if (cmd==='align') {
                    var ac = val === 'center' ? 'justifyCenter' : (val === 'right' ? 'justifyRight' : (val === 'justify' ? 'justifyFull' : 'justifyLeft'));
                    self._nativeFormat(component, quill, ac, null);
                } else if (cmd==='blockquote') {
                    self._applyBlockTag(component, quill, 'blockquote');
                } else if (cmd==='code-block') {
                    self._applyBlockTag(component, quill, 'pre');
                } else if (cmd==='table') {
                    // LÆ°u selection trÆ°á»›c khi má»Ÿ modal
                    var savedRange = null;
                    try {
                        var selNow = window.getSelection();
                        if (selNow && selNow.rangeCount > 0) savedRange = selNow.getRangeAt(0).cloneRange();
                    } catch(e) {}

                    // Show table size picker (rows x cols)
                    var tblOverlay = document.createElement('div');
                    tblOverlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:999998;display:flex;align-items:center;justify-content:center;';
                    var tblModal = document.createElement('div');
                    tblModal.style.cssText = 'background:#fff;border-radius:8px;padding:24px;width:320px;max-width:90vw;box-shadow:0 8px 32px rgba(0,0,0,.25);';
                    tblModal.innerHTML = '<div style="font-size:17px;font-weight:600;margin-bottom:16px;color:#16325c">Insert Table</div>'
                        +'<div style="display:flex;gap:12px;margin-bottom:16px;">'
                        +'<div style="flex:1"><label style="font-size:13px;font-weight:600;color:#444;display:block;margin-bottom:4px">Rows</label>'
                        +'<input id="fec-tbl-rows" type="number" min="1" max="20" value="3" style="width:100%;box-sizing:border-box;border:1px solid #c8c8c8;border-radius:4px;padding:8px 10px;font-size:13px;outline:none;" /></div>'
                        +'<div style="flex:1"><label style="font-size:13px;font-weight:600;color:#444;display:block;margin-bottom:4px">Columns</label>'
                        +'<input id="fec-tbl-cols" type="number" min="1" max="20" value="3" style="width:100%;box-sizing:border-box;border:1px solid #c8c8c8;border-radius:4px;padding:8px 10px;font-size:13px;outline:none;" /></div>'
                        +'</div>'
                        +'<div style="display:flex;justify-content:flex-end;gap:8px;">'
                        +'<button id="fec-tbl-cancel" style="padding:7px 18px;border:1px solid #c8c8c8;border-radius:20px;background:#fff;cursor:pointer;font-size:13px;color:#333;">Cancel</button>'
                        +'<button id="fec-tbl-insert" style="padding:7px 18px;border:none;border-radius:20px;background:#0070d2;color:#fff;cursor:pointer;font-size:13px;">Insert</button>'
                        +'</div>';
                    tblOverlay.appendChild(tblModal);
                    document.body.appendChild(tblOverlay);
                    document.getElementById('fec-tbl-rows').focus();
                    document.getElementById('fec-tbl-cancel').addEventListener('click', function() { document.body.removeChild(tblOverlay); });
                    document.getElementById('fec-tbl-insert').addEventListener('click', function() {
                        var rows = Math.max(1, Math.min(20, parseInt(document.getElementById('fec-tbl-rows').value, 10) || 3));
                        var cols = Math.max(1, Math.min(20, parseInt(document.getElementById('fec-tbl-cols').value, 10) || 3));
                        document.body.removeChild(tblOverlay);

                        // Build table node trá»±c tiáº¿p
                        var tbl = document.createElement('table');
                        tbl.style.cssText = 'border-collapse:collapse;width:100%;margin:8px 0;';
                        for (var r = 0; r < rows; r++) {
                            var tr = document.createElement('tr');
                            for (var c = 0; c < cols; c++) {
                                var td = document.createElement('td');
                                td.style.cssText = 'border:1px solid #999;padding:6px 10px;min-width:60px;';
                                td.setAttribute('contenteditable', 'true');
                                td.innerHTML = '\u00a0';
                                tr.appendChild(td);
                            }
                            tbl.appendChild(tr);
                        }
                        var br = document.createElement('p');
                        br.innerHTML = '<br>';

                        // Láº¥y selection hiá»‡n táº¡i trong quill.root
                        var editorEl = quill.root;
                        var sel = window.getSelection();
                        var inserted = false;
                        // DÃ¹ng savedRange náº¿u cÃ³ (selection trÆ°á»›c khi má»Ÿ modal)
                        var insertRange = savedRange;
                        if (!insertRange && sel && sel.rangeCount > 0) {
                            insertRange = sel.getRangeAt(0);
                        }
                        if (insertRange && editorEl.contains(insertRange.commonAncestorContainer)) {
                            insertRange.deleteContents();
                            insertRange.insertNode(br);
                            insertRange.insertNode(tbl);
                            var newRange = document.createRange();
                            newRange.setStartAfter(br);
                            newRange.collapse(true);
                            sel.removeAllRanges();
                            sel.addRange(newRange);
                            inserted = true;
                        }
                        if (!inserted) {
                            editorEl.appendChild(tbl);
                            editorEl.appendChild(br);
                        }

                        // DÃ¹ng setTimeout Ä‘á»ƒ Ä‘áº£m báº£o Quill khÃ´ng reset sau insert
                        window.setTimeout(function() {
                            // XÃ³a class ql-blank Ä‘á»ƒ áº©n placeholder
                            editorEl.classList.remove('ql-blank');
                            // Náº¿u table bá»‹ Quill xÃ³a, append láº¡i
                            if (!editorEl.contains(tbl)) {
                                editorEl.appendChild(tbl);
                                editorEl.appendChild(br);
                            }
                            // Focus vÃ o cell Ä‘áº§u tiÃªn
                            var firstTd = tbl.querySelector('td');
                            if (firstTd) {
                                firstTd.focus();
                                var r2 = document.createRange();
                                r2.selectNodeContents(firstTd);
                                r2.collapse(false);
                                var s2 = window.getSelection();
                                if (s2) { s2.removeAllRanges(); s2.addRange(r2); }
                            }
                        }, 100);                    });
                    tblOverlay.addEventListener('click', function(ev) { if(ev.target===tblOverlay) document.body.removeChild(tblOverlay); });
                } else if (cmd==='clean') {
                    var r=quill.getSelection(); if(r) quill.removeFormat(r.index,r.length);
                } else if (cmd==='link') {
                    var linkSel = quill.getSelection(true);
                    var existingUrl = (linkSel && linkSel.length > 0) ? (quill.getFormat(linkSel.index, linkSel.length).link || '') : '';
                    var linkOverlay = document.createElement('div');
                    linkOverlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:999998;display:flex;align-items:center;justify-content:center;';
                    var linkModal = document.createElement('div');
                    linkModal.style.cssText = 'background:#fff;border-radius:8px;padding:24px;width:400px;max-width:90vw;box-shadow:0 8px 32px rgba(0,0,0,.25);';
                    linkModal.innerHTML = '<div style="font-size:17px;font-weight:600;margin-bottom:16px;color:#16325c">Insert Link</div>'
                        +'<label style="font-size:13px;font-weight:600;color:#444;display:block;margin-bottom:4px">Link Text</label>'
                        +'<input id="fec-lnk-text" type="text" placeholder="Display text" style="width:100%;box-sizing:border-box;border:1px solid #c8c8c8;border-radius:4px;padding:8px 10px;font-size:13px;margin-bottom:12px;outline:none;" />'
                        +'<label style="font-size:13px;font-weight:600;color:#444;display:block;margin-bottom:4px">Link URL</label>'
                        +'<input id="fec-lnk-url" type="text" placeholder="https://" style="width:100%;box-sizing:border-box;border:1px solid #c8c8c8;border-radius:4px;padding:8px 10px;font-size:13px;margin-bottom:20px;outline:none;" />'
                        +'<div style="display:flex;justify-content:flex-end;gap:8px;">'
                        +'<button id="fec-lnk-cancel" style="padding:7px 18px;border:1px solid #c8c8c8;border-radius:20px;background:#fff;cursor:pointer;font-size:13px;color:#333;">Cancel</button>'
                        +'<button id="fec-lnk-save" style="padding:7px 18px;border:none;border-radius:20px;background:#0070d2;color:#fff;cursor:pointer;font-size:13px;">Save</button>'
                        +'</div>';
                    linkOverlay.appendChild(linkModal);
                    document.body.appendChild(linkOverlay);
                    // Pre-fill if text selected
                    var selText = (linkSel && linkSel.length > 0) ? quill.getText(linkSel.index, linkSel.length) : '';
                    document.getElementById('fec-lnk-text').value = selText;
                    document.getElementById('fec-lnk-url').value = existingUrl;
                    (existingUrl ? document.getElementById('fec-lnk-url') : document.getElementById('fec-lnk-text')).focus();
                    document.getElementById('fec-lnk-cancel').addEventListener('click', function() { document.body.removeChild(linkOverlay); });
                    document.getElementById('fec-lnk-save').addEventListener('click', function() {
                        var lUrl = (document.getElementById('fec-lnk-url').value || '').trim();
                        var lText = (document.getElementById('fec-lnk-text').value || '').trim();
                        if (lUrl) {
                            var sel3 = quill.getSelection(true);
                            if (sel3 && sel3.length > 0) {
                                quill.format('link', lUrl);
                            } else {
                                var insertIdx = sel3 ? sel3.index : quill.getLength();
                                quill.insertText(insertIdx, lText || lUrl, 'link', lUrl);
                            }
                        }
                        document.body.removeChild(linkOverlay);
                    });
                    linkOverlay.addEventListener('click', function(ev4) { if(ev4.target===linkOverlay) document.body.removeChild(linkOverlay); });
                } else if (cmd==='image') {
                    // Show image dropdown: Browse or Upload / Web Image
                    var imgBtn = btn;
                    var existDD = document.getElementById('fec-img-dd');
                    if (existDD) { existDD.parentNode.removeChild(existDD); return; }
                    var imgDD = document.createElement('div');
                    imgDD.id = 'fec-img-dd';
                    imgDD.style.cssText = 'position:fixed;z-index:999999;background:#fff;border:1px solid #c8c8c8;border-radius:4px;box-shadow:0 4px 12px rgba(0,0,0,.18);min-width:160px;overflow:hidden;';
                    imgDD.innerHTML = '<div class="fec-img-dd-item" id="fec-img-browse">Browse or Upload</div><div class="fec-img-dd-item" id="fec-img-url">Web Image</div>';
                    document.body.appendChild(imgDD);
                    if (!document.getElementById('fec-img-dd-css')) {
                        var s2 = document.createElement('style'); s2.id='fec-img-dd-css';
                        s2.innerHTML = '.fec-img-dd-item{padding:9px 16px;font-size:13px;color:#333;cursor:pointer;}.fec-img-dd-item:hover{background:#f0f7ff;color:#0070d2;}';
                        document.head.appendChild(s2);
                    }
                    var rr = imgBtn.getBoundingClientRect();
                    imgDD.style.left = rr.left + 'px';
                    imgDD.style.top = (rr.bottom + 2) + 'px';
                    function closeImgDD() { var d=document.getElementById('fec-img-dd'); if(d&&d.parentNode) d.parentNode.removeChild(d); }
                    // Browse or Upload â†’ file picker â†’ base64 náº¿u â‰¤3MB, Object URL náº¿u lá»›n hÆ¡n
                    document.getElementById('fec-img-browse').addEventListener('mousedown', function(ev2) {
                        ev2.preventDefault(); closeImgDD();
                        var fi = document.createElement('input');
                        fi.type='file'; fi.accept='image/*';
                        fi.style.cssText='position:fixed;opacity:0;width:0;height:0;';
                        document.body.appendChild(fi);
                        fi.addEventListener('change', function() {
                            var f = fi.files[0];
                            if (!f) { document.body.removeChild(fi); return; }
                            var MAX_IMG = 3 * 1024 * 1024; // 3MB
                            if (f.size > MAX_IMG) {
                                // tungnm37 sá»­a: áº£nh quÃ¡ lá»›n â†’ bÃ¡o lá»—i, khÃ´ng insert
                                try {
                                    var toastBig = $A.get('e.force:showToast');
                                    // tungnm37 sá»­a: dÃ¹ng custom labels
                                    if (toastBig) { toastBig.setParams({ title: component.get('v.lblImgTooLargeTitle'), message: component.get('v.lblImgTooLargeMsg'), type: 'error', duration: 6000 }); toastBig.fire(); }
                                } catch(ex) {}
                                document.body.removeChild(fi);
                                return;
                            }
                            // â‰¤3MB â†’ dÃ¹ng base64 Ä‘á»ƒ lÆ°u Ä‘Æ°á»£c vÃ o EmailMessage
                            var rd = new FileReader();
                            rd.onload = function(ev3) {
                                var sel = quill.getSelection(true);
                                var idx = sel ? sel.index : quill.getLength();
                                quill.insertEmbed(idx, 'image', ev3.target.result);
                                document.body.removeChild(fi);
                            };
                            rd.readAsDataURL(f);
                        });
                        fi.click();
                    });
                    // Web Image â†’ modal nháº­p URL â†’ insert trá»±c tiáº¿p (browser render Ä‘Æ°á»£c)
                    document.getElementById('fec-img-url').addEventListener('mousedown', function(ev2) {
                        ev2.preventDefault(); closeImgDD();
                        var overlay = document.createElement('div');
                        overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:999998;display:flex;align-items:center;justify-content:center;';
                        var modal = document.createElement('div');
                        modal.style.cssText = 'background:#fff;border-radius:8px;padding:24px;width:420px;max-width:90vw;box-shadow:0 8px 32px rgba(0,0,0,.25);';
                        modal.innerHTML = '<div style="font-size:18px;font-weight:600;margin-bottom:16px;color:#16325c">Insert Image from URL</div>'
                            +'<label style="font-size:13px;font-weight:600;color:#444;display:block;margin-bottom:4px">Enter Image URL</label>'
                            +'<input id="fec-url-inp" type="text" placeholder="https://" style="width:100%;box-sizing:border-box;border:1px solid #c8c8c8;border-radius:4px;padding:8px 10px;font-size:13px;margin-bottom:20px;outline:none;" />'
                            +'<div style="display:flex;justify-content:flex-end;gap:8px;">'
                            +'<button id="fec-url-cancel" style="padding:7px 18px;border:1px solid #c8c8c8;border-radius:20px;background:#fff;cursor:pointer;font-size:13px;color:#333;">Cancel</button>'
                            +'<button id="fec-url-insert" style="padding:7px 18px;border:none;border-radius:20px;background:#0070d2;color:#fff;cursor:pointer;font-size:13px;">Insert</button>'
                            +'</div>';
                        overlay.appendChild(modal);
                        document.body.appendChild(overlay);
                        document.getElementById('fec-url-inp').focus();
                        document.getElementById('fec-url-cancel').addEventListener('click', function() { document.body.removeChild(overlay); });
                        document.getElementById('fec-url-insert').addEventListener('click', function() {
                            var imgUrl = (document.getElementById('fec-url-inp').value||'').trim();
                            if (imgUrl) {
                                // Insert as raw img tag to bypass Quill sanitizer
                                var sel2 = quill.getSelection(true);
                                var idx = sel2 ? sel2.index : quill.getLength();
                                quill.insertEmbed(idx, 'image', imgUrl, 'user');
                            }
                            if (overlay.parentNode) document.body.removeChild(overlay);
                        });
                        overlay.addEventListener('click', function(ev3) { if(ev3.target===overlay) document.body.removeChild(overlay); });
                    });
                    setTimeout(function() {
                        document.addEventListener('mousedown', function onOut(ev2) {
                            var d = document.getElementById('fec-img-dd');
                            // tungnm37 sá»­a: khÃ´ng Ä‘Ã³ng náº¿u click vÃ o chÃ­nh button áº£nh (trÃ¡nh toggle conflict)
                            if (d && !d.contains(ev2.target) && !imgBtn.contains(ev2.target)) {
                                closeImgDD();
                                document.removeEventListener('mousedown', onOut);
                            }
                        });
                    }, 50);
                }
            });
        });

        // Color palette buttons
        var COLORS = [
            '#1abc9c','#2ecc71','#3498db','#9b59b6','#34495e','#f1c40f','#e67e22',
            '#16a085','#27ae60','#2980b9','#8e44ad','#2c3e50','#d35400','#e74c3c',
            '#ecf0f1','#bdc3c7','#95a5a6','#7f8c8d','#ffffff','#000000','#c0392b'
        ];
        var activeClrCmd = null;
        var clrDDEl = null;

        function buildColorDD(cmd) {
            var dd = document.createElement('div');
            dd.style.cssText = 'position:fixed;z-index:999999;background:#fff;border:1px solid #c8c8c8;border-radius:4px;box-shadow:0 4px 12px rgba(0,0,0,.18);padding:6px;width:180px;';
            var autoRow = document.createElement('div');
            autoRow.style.cssText = 'display:flex;align-items:center;gap:6px;padding:3px 2px 6px;border-bottom:1px solid #eee;margin-bottom:6px;cursor:pointer;border-radius:3px;';
            autoRow.innerHTML = '<span style="width:18px;height:18px;border:1px solid #ccc;background:#fff;display:inline-block;flex-shrink:0;border-radius:2px"></span><span style="font-size:13px;color:#333">Automatic</span>';
            autoRow.addEventListener('mousedown', function(e) {
                e.preventDefault();
                self._formatQuillSelection(component, quill, cmd, false);
                var ind = tbEl.querySelector('.fec-clr-btn[data-cmd="'+cmd+'"] .fec-clr-a');
                if (ind) { if(cmd==='color') ind.style.borderBottomColor='#000'; else ind.style.background='transparent'; }
                closeClrDD();
            });
            dd.appendChild(autoRow);
            var grid = document.createElement('div');
            grid.style.cssText = 'display:grid;grid-template-columns:repeat(7,1fr);gap:3px;';
            COLORS.forEach(function(c) {
                var sw = document.createElement('div');
                sw.style.cssText = 'width:20px;height:20px;background:'+c+';border:1px solid rgba(0,0,0,.15);border-radius:2px;cursor:pointer;';
                sw.title = c;
                sw.addEventListener('mousedown', function(e) {
                    e.preventDefault();
                    self._formatQuillSelection(component, quill, cmd, c);
                    var ind = tbEl.querySelector('.fec-clr-btn[data-cmd="'+cmd+'"] .fec-clr-a');
                    if (ind) { if(cmd==='color') ind.style.borderBottomColor=c; else ind.style.background=c; }
                    closeClrDD();
                });
                grid.appendChild(sw);
            });
            dd.appendChild(grid);
            var more = document.createElement('div');
            more.style.cssText = 'margin-top:6px;padding-top:6px;border-top:1px solid #eee;text-align:center;cursor:pointer;font-size:13px;color:#0070d2;';
            more.textContent = 'More Colors...';
            more.addEventListener('mousedown', function(e) {
                e.preventDefault();
                closeClrDD();
                var inp = document.createElement('input');
                inp.type='color'; inp.style.cssText='position:fixed;opacity:0;width:0;height:0;';
                document.body.appendChild(inp);
                inp.addEventListener('input', function() {
                    self._formatQuillSelection(component, quill, cmd, inp.value);
                    var ind = tbEl.querySelector('.fec-clr-btn[data-cmd="'+cmd+'"] .fec-clr-a');
                    if (ind) { if(cmd==='color') ind.style.borderBottomColor=inp.value; else ind.style.background=inp.value; }
                });
                inp.addEventListener('change', function() { if(inp.parentNode) inp.parentNode.removeChild(inp); });
                inp.click();
            });
            dd.appendChild(more);
            return dd;
        }

        function closeClrDD() {
            if (clrDDEl && clrDDEl.parentNode) clrDDEl.parentNode.removeChild(clrDDEl);
            clrDDEl = null; activeClrCmd = null;
        }

        tbEl.querySelectorAll('.fec-clr-btn').forEach(function(btn) {
            btn.addEventListener('mousedown', function(e) {
                e.preventDefault();
                var cmd = btn.getAttribute('data-cmd');
                if (activeClrCmd === cmd) { closeClrDD(); return; }
                closeClrDD();
                activeClrCmd = cmd;
                clrDDEl = buildColorDD(cmd);
                document.body.appendChild(clrDDEl);
                var rect = btn.getBoundingClientRect();
                clrDDEl.style.left = rect.left + 'px';
                clrDDEl.style.top = (rect.bottom + 2) + 'px';
                var ddH = clrDDEl.offsetHeight;
                if (rect.bottom + ddH + 2 > window.innerHeight) {
                    clrDDEl.style.top = (rect.top - ddH - 2) + 'px';
                }
            });
        });

        // Close dropdown on scroll (reposition or close)
        function onScroll() {
            if (activePk) {
                var rect2 = activePk.getBoundingClientRect();
                ddEl.style.left = rect2.left + 'px';
                ddEl.style.top = (rect2.bottom + 2) + 'px';
                var ddH2 = ddEl.offsetHeight;
                if (rect2.bottom + ddH2 + 2 > window.innerHeight) {
                    ddEl.style.top = (rect2.top - ddH2 - 2) + 'px';
                }
            }
        }
        window.addEventListener('scroll', onScroll, true);

        // Keyboard handler: xá»­ lÃ½ table + Backspace/Delete
        quill.root.addEventListener('keydown', function(e) {
            // Quill history does not know about native DOM paste into template HTML.
            // Route undo/redo to the browser edit stack so Ctrl+Z can undo pasted text.
            if ((e.ctrlKey || e.metaKey) && !e.altKey) {
                var key = (e.key || '').toLowerCase();
                if (key === 'z' || e.keyCode === 90) {
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    var beforeUndoHtml = quill.root.innerHTML;
                    var undoOk = document.execCommand(e.shiftKey ? 'redo' : 'undo', false, null);
                    if (!e.shiftKey && window._fecPasteUndoHtml && quill.root.innerHTML === beforeUndoHtml) {
                        quill.root.innerHTML = window._fecPasteUndoHtml;
                        quill.root.classList.remove('ql-blank');
                        self._makeTableCellsEditable(quill.root);
                        window._fecPasteUndoHtml = null;
                    }
                    component.set('v.body', quill.root.innerHTML);
                    component.set('v.rawBody', quill.root.innerHTML);
                    return;
                }
                if (key === 'y' || e.keyCode === 89) {
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    document.execCommand('redo', false, null);
                    component.set('v.body', quill.root.innerHTML);
                    component.set('v.rawBody', quill.root.innerHTML);
                    return;
                }
            }
            var sel = window.getSelection();
            if (!sel || sel.rangeCount === 0) return;
            var range = sel.getRangeAt(0);
            var editorEl = quill.root;

            // Handle Enter through Quill so line breaks are persisted and toolbar state remains stable.
            if (e.keyCode === 13) {
                e.preventDefault();
                e.stopImmediatePropagation();
                var qRange = quill.getSelection(true);
                if (qRange) {
                    quill.insertText(qRange.index, '\n', 'user');
                    quill.setSelection(qRange.index + 1, 0, 'silent');
                    self._syncEditorBody(component, quill);
                }
                return;
            }

            // Template HTML is injected directly into the editor, so Quill's internal delta
            // may not know about all nodes. For Backspace/Delete, bypass Quill keyboard
            // handlers and let the browser edit the real DOM natively.
            if (e.keyCode === 8 || e.keyCode === 46) {
                e.stopImmediatePropagation();
                return;
            }

            // Kiá»ƒm tra cursor/selection cÃ³ trong table khÃ´ng
            var anchorNode = range.commonAncestorContainer;
            var cur = anchorNode.nodeType === 3 ? anchorNode.parentNode : anchorNode;
            var inTable = false;
            var tmp = cur;
            while (tmp && tmp !== editorEl) {
                if (tmp.tagName === 'TABLE' || tmp.tagName === 'TD' || tmp.tagName === 'TH') {
                    inTable = true; break;
                }
                tmp = tmp.parentNode;
            }

            if (inTable) {
                // Stop Quill from intercepting table editing, but DO NOT prevent default.
                // Let the browser handle Backspace/Delete natively so template text inside
                // td/th can be removed. execCommand('delete') is unreliable in Lightning.
                e.stopImmediatePropagation();
                return;
            }

            // NgoÃ i table, chá»‰ xá»­ lÃ½ Backspace/Delete
            if (e.keyCode !== 8 && e.keyCode !== 46) return;

            // Case A: cÃ³ selection (bÃ´i Ä‘en) chá»©a table â†’ xÃ³a table trÆ°á»›c, Ä‘á»ƒ browser xÃ³a text
            if (!range.collapsed) {
                var frag = range.cloneContents();
                if (frag.querySelector('table')) {
                    editorEl.querySelectorAll('table').forEach(function(t) {
                        if (range.intersectsNode(t)) t.parentNode.removeChild(t);
                    });
                    // KhÃ´ng preventDefault â†’ browser xÃ³a pháº§n text cÃ²n láº¡i trong selection
                }
                return; // luÃ´n Ä‘á»ƒ browser xá»­ lÃ½ pháº§n text
            }

            // Case B: cursor collapsed, liá»n ká» table
            var startEl = range.startContainer.nodeType === 3 ? range.startContainer.parentNode : range.startContainer;
            // TÃ¬m sibling trá»±c tiáº¿p hoáº·c qua parent
            var sib = e.keyCode === 8 ? startEl.previousSibling : startEl.nextSibling;
            if (!sib && startEl.parentNode && startEl.parentNode !== editorEl) {
                sib = e.keyCode === 8 ? startEl.parentNode.previousSibling : startEl.parentNode.nextSibling;
            }
            if (sib && sib.tagName === 'TABLE') {
                e.preventDefault();
                sib.parentNode.removeChild(sib);
            }
        }, true);
        // Close on outside click
        document.addEventListener('mousedown', function(e) {
            if (clrDDEl && !clrDDEl.contains(e.target) && !tbEl.contains(e.target)) closeClrDD();
            if (!tbEl.contains(e.target) && e.target!==ddEl && !ddEl.contains(e.target)) closeDD();
        });
    },


    _css: function() {
        var fontCss = this.FONTS.filter(function(f){return f.v;}).map(function(f){
            return '.ql-font-'+f.v+'{font-family:'+f.f+'!important}';
        }).join('');
        return fontCss + [
            '.fec-quill-wrapper{border:none;background:#fff;width:100%;box-sizing:border-box}',
            '.fec-tb{background:#f8f8f8;border-bottom:1px solid #e0e0e0;padding:5px 8px}',
            '.fec-tb-r1{display:flex;align-items:center;flex-wrap:wrap;gap:4px}',
            '.fec-grp{display:inline-flex;align-items:center;gap:2px;border:1.5px solid #1a1a1a;border-radius:4px;padding:0 4px;height:26px;background:#fff;box-sizing:border-box}',
            '.fec-grp:hover{border-color:#0070d2}',
            // Hide Quill native toolbar (we use custom fec-tb)
            '.ql-toolbar.ql-snow{display:none!important;height:0!important;padding:0!important;border:none!important;overflow:hidden!important}',
            // Picker
            '.fec-pk{position:relative;display:inline-flex}',
            '.fec-pk-btn{display:inline-flex;align-items:center;gap:4px;height:26px;padding:0 8px;border:1.5px solid #1a1a1a;border-radius:4px;background:#fff;cursor:pointer;font-size:12px;color:#333;white-space:nowrap;min-width:65px;justify-content:space-between}',
            '.fec-pk-btn:hover{border-color:#0070d2;background:#f0f7ff}',
            // Toolbar buttons
            '.fec-btn{width:22px;height:22px;padding:0;border:1px solid transparent;border-radius:3px;background:transparent;cursor:pointer;display:inline-flex;align-items:center;justify-content:center}',
            '.fec-btn svg{width:14px;height:14px;display:block}',
            '.fec-btn:hover{background:#e8f0fe;border-color:#c5d0e6}',
            '.fec-btn.fec-active{background:#d2e3fc;border-color:#1a73e8}',
            // Color
            '.fec-clr-btn{display:inline-flex;align-items:center;justify-content:center;gap:2px;height:22px;padding:0 5px;border:1px solid transparent;border-radius:3px;background:transparent;cursor:pointer;}',
            '.fec-clr-btn:hover{background:#e8f0fe;border-color:#c5d0e6}',
            '.fec-clr-a{font-size:13px;font-weight:700;color:#333;line-height:1;padding-bottom:1px}',
            // Editor
            '.fec-ed .ql-container.ql-snow{border:none;font-size:14px}',
            '.fec-ed .ql-editor{min-height:200px;max-height:500px;overflow-y:auto;overflow-x:hidden;padding:10px calc(100% - 500px) 10px 12px!important;line-height:1.5;resize:vertical;font-family:"Times New Roman",serif;font-size:14px;color:#000;width:100%!important;max-width:none!important;margin:0;box-sizing:border-box;white-space:normal!important;overflow-wrap:anywhere!important;word-break:break-word!important}',
            '.fec-ed .ql-editor img{display:block!important;width:500px!important;max-width:500px!important;height:auto!important;box-sizing:border-box}',
            '.fec-ed .ql-editor > *,.fec-ed .ql-editor p,.fec-ed .ql-editor div,.fec-ed .ql-editor table,.fec-ed .ql-editor ul,.fec-ed .ql-editor ol,.fec-ed .ql-editor li{width:500px!important;max-width:500px!important;box-sizing:border-box;overflow-wrap:anywhere!important;word-break:break-word!important;white-space:normal!important}',
            '.fec-ed .ql-editor span,.fec-ed .ql-editor a{overflow-wrap:anywhere!important;word-break:break-word!important;white-space:normal!important}',
            '.fec-ed .ql-editor p{margin:0!important;padding:0!important;line-height:1.5!important}',
            '.fec-ed .ql-editor p+p{margin-top:0!important}',
            '.fec-ed .ql-editor.ql-blank::before{color:#aaa;font-style:normal}',
            // áº¨n placeholder khi editor cÃ³ table (table náº±m ngoÃ i Quill delta)
            '.fec-ed .ql-editor:has(table)::before{display:none!important}',
            // Table borders
            '.fec-ed .ql-editor table{border-collapse:collapse!important;width:100%!important;margin:8px 0!important}',
            '.fec-ed .ql-editor table td,.fec-ed .ql-editor table th{border:1px solid #999!important;padding:6px 10px!important;min-width:60px!important}',
            // tungnm37 fix: indent CSS classes (Quill format indent)
            '.fec-ed .ql-editor .ql-indent-1{padding-left:3em!important}',
            '.fec-ed .ql-editor .ql-indent-2{padding-left:6em!important}',
            '.fec-ed .ql-editor .ql-indent-3{padding-left:9em!important}',
            '.fec-ed .ql-editor .ql-indent-4{padding-left:12em!important}',
            '.fec-ed .ql-editor .ql-indent-5{padding-left:15em!important}',
            '.fec-ed .ql-editor .ql-indent-6{padding-left:18em!important}',
            '.fec-ed .ql-editor .ql-indent-7{padding-left:21em!important}',
            '.fec-ed .ql-editor .ql-indent-8{padding-left:24em!important}',
            // Dropdown item hover
            '.fec-dd-it{padding:5px 12px;font-size:13px;color:#333;cursor:pointer;white-space:nowrap}',
            '.fec-dd-it:hover{background:#e8f0fe;color:#1a73e8}'
        ].join('');
    },

    addToTag: function(component) {
        var val = (component.get('v.toInput')||'').trim().replace(/,/g,'');
        if (!val) return;
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val)) return;
        var tags = component.get('v.toTags')||[];
        if (tags.indexOf(val)===-1) { tags=tags.concat([val]); component.set('v.toTags',tags); }
        component.set('v.toInput','');
    },

    loadCaseData: function(component) {
        var caseId = component.get('v.recordId');
        var self = this;
        // Detect record type Ä‘á»ƒ biáº¿t Interaction hay Service Case
        var aRT = component.get('c.getCaseRecordTypeName');
        aRT.setParams({ caseId: caseId });
        aRT.setCallback(this, function(r) {
            if (r.getState() === 'SUCCESS') {
                var rtName = r.getReturnValue() || '';
                var isServiceCase = (rtName !== 'Interaction');
                component.set('v.isServiceCase', isServiceCase);
                if (isServiceCase) {
                    // Service Case: load from picklist theo queue owner
                    self.loadFromAddresses(component, '');
                    // Pre-fill To tá»« outgoing email gáº§n nháº¥t
                    var emails = component.get('v.emailList') || [];
                    var lastOutgoing = emails.find(function(e) { return !e.incoming; });
                    if (lastOutgoing && lastOutgoing.toAddress) {
                        component.set('v.serviceCaseToEmail', lastOutgoing.toAddress);
                    }
                }
            }
        });
        $A.enqueueAction(aRT);

        var a1 = component.get('c.getInteractionEmail');
        a1.setParams({caseId:caseId});
        a1.setCallback(this, function(r) {
            if (r.getState()==='SUCCESS') {
                var d=r.getReturnValue()||{};
                var isManualInteraction = d.isManual === 'true';
                component.set('v.fromEmail', d.fromEmail||'');
                component.set('v.fromDisplay', d.fromDisplay||d.fromEmail||'');
                component.set('v.toEmail', d.toEmail||'');
                component.set('v.isManualInteraction', isManualInteraction);
                component.set('v.incomingToAddress', d.fromEmail||'');

                if (isManualInteraction) {
                    // Manual Interaction: allow selecting From from configured outbound emails.
                    self.loadFromAddresses(component, d.fromEmail || '');
                } else {
                    // Non-manual Interaction: From is original inbound ToAddress/FEC_Send_To__c and read-only.
                    component.set('v.fromOptions', []);
                    component.set('v.hasFromOptions', false);
                    self.loadTemplates(component, d.fromEmail || '');
                }
            }
        });
        $A.enqueueAction(a1);
        var a2 = component.get('c.getCaseSubject');
        a2.setParams({caseId:caseId});
        a2.setCallback(this, function(r) {
            if (r.getState()==='SUCCESS') component.set('v.originalSubject',r.getReturnValue()||'');
        });
        $A.enqueueAction(a2);
    },

    loadFromAddresses: function(component, incomingToAddress) {
        var self = this;
        var a = component.get('c.getFromAddresses');
        a.setParams({ caseId: component.get('v.recordId') });
        a.setCallback(this, function(r) {
            if (r.getState() === 'SUCCESS') {
                var res = r.getReturnValue() || {};
                var opts = res.options || [];
                var queueDefault = res.defaultFrom || (opts.length > 0 ? opts[0].value : '');
                component.set('v.fromOptions', opts);
                component.set('v.hasFromOptions', opts.length > 0);
                if (opts.length === 0) return;

                // Æ¯u tiÃªn: incoming ToAddress (mailbox nháº­n email khÃ¡ch) â†’ Queue default â†’ option Ä‘áº§u
                var incomingLower = (incomingToAddress || '').toLowerCase();
                var matchIncoming = opts.filter(function(o) {
                    return o.value && o.value.toLowerCase() === incomingLower;
                });
                var toSelect = matchIncoming.length > 0 ? matchIncoming[0].value : queueDefault;
                component.set('v.fromEmail', toSelect);

                // Reload templates filtered by selected from address
                self.loadTemplates(component, toSelect);

                // Sync native <select>
                function syncSelect() {
                    try {
                        var el = component && component.isValid && component.isValid() ? component.getElement() : null;
                        if (!el || typeof el.querySelector !== 'function') return;
                        var sel = el.querySelector('.fec-from-select');
                        if (sel) {
                            sel.value = toSelect;
                            if (sel.value !== toSelect) {
                                window.setTimeout($A.getCallback(syncSelect), 150);
                            }
                        }
                    } catch (e) {
                        return;
                    }
                }
                window.setTimeout($A.getCallback(syncSelect), 100);
            }
        });
        $A.enqueueAction(a);
    },


    loadCaseFiles: function(component, delayMs) {
        var run = function() {
            var action = component.get('c.getCaseFileInfos');
            action.setParams({ caseId: component.get('v.recordId') });
            action.setCallback(this, function(resp) {
                if (resp.getState() === 'SUCCESS') {
                    component.set('v.caseFileList', resp.getReturnValue() || []);
                }
            });
            $A.enqueueAction(action);
        };
        if (delayMs && delayMs > 0) {
            window.setTimeout($A.getCallback(run), delayMs);
        } else {
            run();
        }
    },
    showPreviewModal: function(body) {
        var existing = document.getElementById('fec-preview-overlay');
        if (existing) existing.parentNode.removeChild(existing);

        var overlay = document.createElement('div');
        overlay.id = 'fec-preview-overlay';
        overlay.setAttribute('style', [
            'position:fixed','top:0','left:0','right:0','bottom:0',
            'width:100vw','height:100vh',
            'background:rgba(0,0,0,.55)',
            'z-index:2147483647',
            'display:flex','align-items:center','justify-content:center'
        ].join('!important;') + '!important;');

        var modal = document.createElement('div');
        modal.setAttribute('style', [
            'background:#fff','border-radius:8px',
            'width:560px','max-width:92vw','max-height:88vh',
            'display:flex','flex-direction:column',
            'box-shadow:0 8px 32px rgba(0,0,0,.35)',
            'overflow:hidden','position:relative'
        ].join('!important;') + '!important;');

        var header = document.createElement('div');
        header.setAttribute('style','display:flex;align-items:center;justify-content:space-between;padding:16px 24px;border-bottom:1px solid #e5e5e5;flex-shrink:0;');
        var title = document.createElement('span');
        title.textContent = 'Preview email';
        title.setAttribute('style','font-size:17px;font-weight:600;color:#16325c;flex:1;text-align:center;');
        var closeBtn = document.createElement('span');
        closeBtn.innerHTML = '&#x2715;';
        closeBtn.setAttribute('style','cursor:pointer;font-size:20px;color:#706e6b;line-height:1;padding:2px 6px;position:absolute;right:16px;top:14px;');
        header.appendChild(title);
        header.appendChild(closeBtn);

        var bodyDiv = document.createElement('div');
        bodyDiv.setAttribute('style','flex:1;overflow-y:auto;overflow-x:hidden;padding:16px 20px;font-family:"Times New Roman",serif;font-size:14px;line-height:1.5;color:#333;box-sizing:border-box;');

        var previewContent = document.createElement('div');
        previewContent.setAttribute('style','max-width:500px;width:500px;margin:0;box-sizing:border-box;overflow-wrap:anywhere;word-break:break-word;');
        previewContent.innerHTML = body || '';

        var previewImgs = previewContent.getElementsByTagName('img');
        for (var pi = 0; pi < previewImgs.length; pi++) {
            previewImgs[pi].style.maxWidth = '500px';
            previewImgs[pi].style.width = '500px';
            previewImgs[pi].style.height = 'auto';
            previewImgs[pi].style.boxSizing = 'border-box';
        }

        var previewTables = previewContent.getElementsByTagName('table');
        for (var pt = 0; pt < previewTables.length; pt++) {
            previewTables[pt].style.maxWidth = '500px';
            previewTables[pt].style.width = '100%';
            previewTables[pt].style.boxSizing = 'border-box';
        }

        bodyDiv.appendChild(previewContent);

        var footer = document.createElement('div');
        footer.setAttribute('style','padding:12px 24px;border-top:1px solid #e5e5e5;display:flex;justify-content:flex-end;flex-shrink:0;');
        var footCloseBtn = document.createElement('button');
        footCloseBtn.textContent = 'Close';
        footCloseBtn.setAttribute('style','padding:8px 24px;border:none;border-radius:20px;background:#0070d2;color:#fff;font-size:14px;cursor:pointer;font-weight:500;');
        footer.appendChild(footCloseBtn);

        modal.appendChild(header);
        modal.appendChild(bodyDiv);
        modal.appendChild(footer);
        overlay.appendChild(modal);
        document.body.appendChild(overlay);

        function closeModal() {
            var el = document.getElementById('fec-preview-overlay');
            if (el && el.parentNode) el.parentNode.removeChild(el);
        }
        closeBtn.addEventListener('click', closeModal);
        footCloseBtn.addEventListener('click', closeModal);
        overlay.addEventListener('click', function(e) { if (e.target === overlay) closeModal(); });
    },

    loadTemplates: function(component, mailboxAddress) {
        var self = this;
        var actionName = mailboxAddress ? 'c.getEmailTemplatesByMailbox' : 'c.getEmailTemplates';
        var a = component.get(actionName);
        if (mailboxAddress) {
            a.setParams({ mailboxAddress: mailboxAddress });
        }
        a.setCallback(this, function(r) {
            if (r.getState()==='SUCCESS') {
                var data=r.getReturnValue()||[], opts=[], bodies={}, subjects={}, headers={}, footers={};
                var templateIds = [];
                data.forEach(function(t){
                    opts.push({label:t.Name, value:t.Id});
                    bodies[t.Id] = t.FEC_Body__c || '';
                    subjects[t.Id] = t.FEC_Subject_Line__c || '';
                    var lh = t.FEC_Enhanced_Letterhead__r;
                    headers[t.Id] = (lh && lh.FEC_Header__c) ? lh.FEC_Header__c : '';
                    footers[t.Id] = (lh && lh.FEC_Footer__c) ? lh.FEC_Footer__c : '';
                    templateIds.push(t.Id);
                });
                component.set('v.templateOptions',opts);
                component.set('v.templateBodies',bodies);
                component.set('v.templateSubjects',subjects);
                component.set('v.templateHeaders',headers);
                component.set('v.templateFooters',footers);
                // Reset template selection náº¿u template hiá»‡n táº¡i khÃ´ng cÃ²n trong list
                var currentTemplate = component.get('v.replyTemplate');
                if (currentTemplate && !bodies[currentTemplate]) {
                    component.set('v.replyTemplate', '');
                    component.set('v.body', '');
                    if (window._fecQuill) window._fecQuill.root.innerHTML = '';
                }
                // Pre-load attachments cho táº¥t cáº£ templates
                if (templateIds.length > 0) {
                    var attAction = component.get('c.getTemplateAttachmentsBulk');
                    attAction.setParams({ templateIds: templateIds });
                    attAction.setCallback(self, function(ar) {
                        if (ar.getState() === 'SUCCESS') {
                            component.set('v.templateAttachments', ar.getReturnValue() || {});
                        }
                    });
                    $A.enqueueAction(attAction);
                }
            }
        });
        $A.enqueueAction(a);
    },

    replaceDanhXung: function(html, title) {
        // DÃ¹ng split/join thay vÃ¬ regex Unicode Ä‘á»ƒ trÃ¡nh lá»—i Aura JS compiler
        var markers = [
            'Anh/ Ch\u1ECB', 'Anh/Ch\u1ECB', 'Anh / Ch\u1ECB',
            'Anh/ Chi', 'Anh/Chi', 'Anh / Chi',
            '{danh_xung}', '{DANH_XUNG}',
            'QuÃ½ khÃ¡ch hÃ ng', 'QuÃ½ KhÃ¡ch hÃ ng', 'QuÃ½ KhÃ¡ch HÃ ng',
            'QuÃ½ khÃ¡ch', 'QuÃ½ KhÃ¡ch',
            'Ch\u1ECB', 'Chi', 'Anh'
        ];
        var result = html;
        markers.forEach(function(m) {
            result = result.split(m).join('\x00T\x00');
        });
        return result.split('\x00T\x00').join(title);
    },

    // tungnm37 thÃªm: Ä‘áº£m báº£o táº¥t cáº£ td/th trong editor cÃ³ contenteditable Ä‘á»ƒ xÃ³a/sá»­a Ä‘Æ°á»£c
    _makeTableCellsEditable: function(rootEl) {
        if (!rootEl) return;
        var cells = rootEl.querySelectorAll('td, th');
        for (var i = 0; i < cells.length; i++) {
            cells[i].setAttribute('contenteditable', 'true');
            // Náº¿u cell rá»—ng hoáº·c chá»‰ cÃ³ &nbsp;, Ä‘áº·t ná»™i dung lÃ  khoáº£ng tráº¯ng Ä‘á»ƒ cursor vÃ o Ä‘Æ°á»£c
            if (!cells[i].textContent.trim() || cells[i].innerHTML === '&nbsp;') {
                cells[i].innerHTML = '\u00a0';
            }
        }
    },


    normalizeIncomingBodyHtml: function(html, isPlainText) {
        var value = html || '';
        value = value
            .replace(/\\r\\n/g, '\n')
            .replace(/\\n/g, '\n')
            .replace(/\\r/g, '\n')
            .replace(/\r\n/g, '\n')
            .replace(/\n/g, '\n')
            .replace(/\r/g, '\n');
        if (isPlainText) {
            return value
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/\n/g, '<br/>');
        }
        return this.sanitizeIncomingEmailBody(value);
    },

    sanitizeIncomingEmailBody: function(html) {
        //tugnnm37 - Gmail/Genesys cÃ³ thá»ƒ tráº£ video/drive chip trong HtmlBody; khÃ´ng render block chip xáº¥u, convert thÃ nh link gá»n
        if (!html || html.indexOf('gmail_drive_chip') === -1) {
            return html || '';
        }
        try {
            var holder = document.createElement('div');
            holder.innerHTML = html;
            var chips = holder.querySelectorAll('.gmail_drive_chip');
            for (var i = 0; i < chips.length; i++) {
                var chip = chips[i];
                var link = chip.querySelector('a[href]');
                var href = link ? link.getAttribute('href') : '';
                var titleEl = chip.querySelector('[title]');
                var textEl = chip.querySelector('span');
                var fileName = (titleEl && titleEl.getAttribute('title')) || (textEl && textEl.textContent) || (link && link.textContent) || 'Attached file';
                fileName = (fileName || 'Attached file').trim();
                var p = document.createElement('p');
                p.className = 'fec-email-drive-link';
                if (href) {
                    var a = document.createElement('a');
                    a.href = href;
                    a.target = '_blank';
                    a.rel = 'noopener noreferrer';
                    a.textContent = fileName;
                    p.appendChild(a);
                } else {
                    p.textContent = fileName;
                }
                chip.parentNode.replaceChild(p, chip);
            }
            return holder.innerHTML;
        } catch (e) {
            return html;
        }
    },
    cleanBody: function(html) {
        var result = html
            // Strip any <p> tag containing only br/whitespace/nbsp (with or without attributes)
            .replace(/<p[^>]*>(\s|&nbsp;|<br\s*\/?>)*<\/p>/gi, '')
            // Collapse 3+ consecutive <br> into single
            .replace(/(<br\s*\/?>\s*){3,}/gi, '<br><br>');
        // Strip leading whitespace/empty lines
        result = result.replace(/^(\s*<p[^>]*>\s*(<br\s*\/?>\s*)?<\/p>\s*)+/i, '');
        return result.trim();
    },

    applyTitleToBody: function(component, title) {
        var baseBody = component.get('v.titleBaseBody') || component.get('v.body') || '';
        if (!baseBody) return;
        var updated = title ? this.replaceDanhXung(baseBody, title) : baseBody;
        component.set('v.body', updated);
        component.set('v.rawBody', updated);
        if (window._fecQuill) {
            this._setEditorHtml(component, window._fecQuill, updated);
        }
    },

    doSendEmail: function(component, toEmail, subject, body, attachments) {
        var isServiceCase = component.get('v.isServiceCase');
        var actionName = isServiceCase ? 'c.sendEmailForServiceCase' : 'c.sendEmailV2';
        var action = component.get(actionName);
        action.setParams({
            caseId: component.get('v.recordId'),
            fromEmail: component.get('v.fromEmail'),
            toEmail: toEmail,
            ccEmail: component.get('v.ccEmail') || null,
            subject: subject,
            body: body,
            attachments: attachments,
            titleReply: component.get('v.titleReply') || null
        });
        action.setCallback(this, function(response) {
            component.set('v.isSending', false);
            var state = response.getState();
            console.log('sendEmail state:', state, response.getError());
            if (state === 'SUCCESS') {
                // Reset compose
                component.set('v.showCompose', false);
                var sentSubject = subject;
                var sentTo = toEmail;
                var sentFrom = component.get('v.fromEmail');
                component.set('v.subject', '');
                component.set('v.body', '');
                component.set('v.ccEmail', '');
                component.set('v.toTags', []);
                component.set('v.toInput', '');
                component.set('v.attachments', []);
                if (window._fecQuill) { window._fecQuill.root.innerHTML = ''; }

                // ThÃªm email vá»«a gá»­i vÃ o feed ngay láº­p tá»©c
                var now = new Date();
                var MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
                var h = now.getHours(), min = now.getMinutes(), ampm = h >= 12 ? 'pm' : 'am';
                var h12 = h % 12 || 12, minStr = min < 10 ? '0' + min : min;
                var ds = now.getDate() + ' ' + MONTHS[now.getMonth()] + ' ' + now.getFullYear() + ' at ' + h12 + ':' + minStr + ' ' + ampm;
                var sentItem = {
                    Id: 'sent_' + now.getTime(),
                    fromName: sentFrom,
                    toAddress: sentTo,
                    ccAddress: component.get('v.ccEmail') || '',
                    subject: sentSubject.replace(/\s*\[\s*ref:[^\]]*:ref\s*\]/gi,'').trim(),
                    subjectPreview: sentSubject.replace(/\s*\[\s*ref:[^\]]*:ref\s*\]/gi,'').trim(),
                    bodyFull: body.replace(/<[^>]+>/g, '').replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').trim(),
                    bodyHtml: body,
                    messageDate: ds,
                    messageRawDate: now.toISOString(),
                    expanded: false,
                    showDD: false
                };
                var currentList = component.get('v.emailList') || [];
                component.set('v.emailList', [sentItem].concat(currentList));

                // Toast success
                try {
                    var toast = $A.get('e.force:showToast');
                    if (toast) {
                        // tungnm37 sá»­a: dÃ¹ng custom labels
                        toast.setParams({ title: component.get('v.lblSuccessTitle'), message: component.get('v.lblSuccessSentMsg'), type: 'success', duration: 4000 });
                        toast.fire();
                    }
                } catch(te) { console.log('toast error', te); }
                this.loadEmails(component);
            } else {
                var errors = response.getError();
                var msg = 'Failed to send email.';
                if (state === 'INCOMPLETE') {
                    msg = 'Communication error, please retry or reload the page.';
                } else if (errors && errors[0]) {
                    msg = errors[0].message || (errors[0].pageErrors && errors[0].pageErrors[0] && errors[0].pageErrors[0].message) || msg;
                }
                console.error('sendEmail error state=' + state + ' msg=' + msg, errors);
                component.set('v.errorMsg', msg);
                // Toast error - tungnm37 sá»­a: dÃ¹ng custom label
                try {
                    var toastErr = $A.get('e.force:showToast');
                    if (toastErr) {
                        toastErr.setParams({ title: component.get('v.lblWeHitASnag') || 'Lá»—i gá»­i email', message: msg, type: 'error', duration: 8000 });
                        toastErr.fire();
                    }
                } catch(te2) { console.log('toast error2', te2); }
            }
        });
        $A.enqueueAction(action);
    },

    loadEmails: function(component) {
        var self = this;
        component.set('v.isLoading',true);
        var a = component.get('c.getEmailMessages');
        a.setParams({caseId:component.get('v.recordId')});
        a.setCallback(this, function(r) {
            component.set('v.isLoading',false);
            if (r.getState()==='SUCCESS') {
                var sortOrder = component.get('v.sortOrder') || 'recent';
                var MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
                var list=(r.getReturnValue()||[]).map(function(m) {
                    var d=m.MessageDate?new Date(m.MessageDate):null, ds='';
                    if (d) {
                        var h=d.getHours(), min=d.getMinutes(), ampm=h>=12?'pm':'am';
                        var h12=h%12||12, minStr=min<10?'0'+min:min;
                        ds = d.getDate()+' '+MONTHS[d.getMonth()]+' '+d.getFullYear()+' at '+h12+':'+minStr+' '+ampm;
                    }
                    var rb=(m.HtmlBody||m.TextBody||'').replace(/<[^>]+>/g,'').replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').trim();
                    var subj=m.Subject||'';
                    var subjDisplay = subj.replace(/\s*\[\s*ref:[^\]]*:ref\s*\]/gi,'').trim();
                    var rawBody = m.HtmlBody || m.TextBody || '';
                    var bodyHtml = self.normalizeIncomingBodyHtml(rawBody, !m.HtmlBody);
                    return {Id:m.Id,fromName:m.FromName||m.FromAddress||'Unknown',fromAddress:m.FromAddress||'',toAddress:m.ToAddress||'',ccAddress:m.CcAddress||'',subject:subjDisplay,subjectPreview:subjDisplay||rb,bodyFull:rb,bodyHtml:bodyHtml,messageDate:ds,messageRawDate:m.MessageDate||'',incoming:m.Incoming,expanded:false,showDD:false,attachments:[]};
                });
                list.sort(function(a,b){
                    if (sortOrder==='oldest') return (a.messageRawDate||'') < (b.messageRawDate||'') ? -1 : 1;
                    if (sortOrder==='latest') return (a.messageRawDate||'') > (b.messageRawDate||'') ? -1 : 1;
                    return (a.messageRawDate||'') > (b.messageRawDate||'') ? -1 : 1;
                });
                var finalizeList = function(finalList) {
                    component.set('v.emailList', finalList);
                    if (component.get('v.isServiceCase') && !component.get('v.serviceCaseToEmail')) {
                        var outgoing = finalList.filter(function(e) { return e.incoming === false; });
                        if (outgoing.length > 0 && outgoing[0].toAddress) {
                            component.set('v.serviceCaseToEmail', outgoing[0].toAddress);
                        }
                    }
                };
                var emailIds = list.map(function(e) { return e.Id; });
                if (!emailIds.length) { finalizeList(list); return; }
                var attAction = component.get('c.getEmailMessageAttachments');
                attAction.setParams({ emailMessageIds: emailIds });
                attAction.setCallback(self, function(ar) {
                    if (ar.getState() === 'SUCCESS') {
                        var mapAtt = ar.getReturnValue() || {};
                        list = list.map(function(e) {
                            e.attachments = mapAtt[e.Id] || [];
                            return e;
                        });
                    }
                    finalizeList(list);
                });
                $A.enqueueAction(attAction);
            }
        });
        $A.enqueueAction(a);
    }
})