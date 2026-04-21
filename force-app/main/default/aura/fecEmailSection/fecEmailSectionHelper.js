({
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
            // Inject table border override riêng với priority cao nhất
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
            var cleanedBody = self.cleanBody(body);
            // Disconnect Quill's MutationObserver to prevent table stripping
            window.setTimeout(function() {
                if (quill.scroll && quill.scroll.observer) {
                    quill.scroll.observer.disconnect();
                }
                quill.root.innerHTML = cleanedBody;
                quill.root.classList.remove('ql-blank');
                // Reconnect after DOM is stable
                window.setTimeout(function() {
                    if (quill.scroll && quill.scroll.observer) {
                        quill.scroll.observer.observe(quill.root, quill.scroll.observer._options || { childList: true, subtree: true, characterData: true });
                    }
                }, 100);
            }, 50);
        }
        // Set default font Times New Roman
        quill.root.style.fontFamily = '"Times New Roman",serif';
        quill.root.style.fontSize = '14px';
        window._fecQuill = quill;
        // Override Quill's built-in image handler (uses window.prompt by default)
        var tbMod = quill.getModule('toolbar');
        if (tbMod) tbMod.addHandler('image', function() {});
        self._wire(tbEl, quill, component);
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
            + grp(btn('link','',ic.link,'Insert Link') + btn('image','',ic.image,'Insert Image')
                + btn('blockquote','',ic.quote,'Blockquote')
                + btn('clean','',ic.clean,'Remove Formatting'))
            + '</div>';
    },


    _wire: function(tbEl, quill, component) {
        var self = this;
        var ddEl = window._fecQDD;
        var activePk = null;

        function closeDD() {
            if (ddEl) { ddEl.style.display='none'; ddEl.innerHTML=''; }
            activePk = null;
        }

        // Picker buttons — open fixed dropdown
        tbEl.querySelectorAll('.fec-pk').forEach(function(pk) {
            pk.querySelector('.fec-pk-btn').addEventListener('mousedown', function(e) {
                e.preventDefault();
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
                        var val = it.getAttribute('data-val');
                        // Update button label
                        pk.querySelector('.fec-pk-btn').childNodes[0].textContent = it.textContent + ' ';
                        closeDD();
                        if (type==='font') quill.format('font', val||false);
                        else if (type==='size') quill.format('size', val||false);
                        else quill.format('header', val ? parseInt(val,10) : false);
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
                    var cur = quill.getFormat(); quill.format(cmd, !cur[cmd]);
                    btn.classList.toggle('fec-active', !cur[cmd]);
                } else if (cmd==='list') {
                    var cf = quill.getFormat(); quill.format('list', cf.list===val ? false : val);
                } else if (cmd==='indent') {
                    quill.format('indent', val);
                } else if (cmd==='align') {
                    quill.format('align', val||false);
                } else if (cmd==='blockquote') {
                    var cf2=quill.getFormat(); quill.format('blockquote',!cf2.blockquote);
                } else if (cmd==='code-block') {
                    var cf3=quill.getFormat(); quill.format('code-block',!cf3['code-block']);
                } else if (cmd==='table') {
                    // Lưu selection trước khi mở modal
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

                        // Build table node trực tiếp
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

                        // Lấy selection hiện tại trong quill.root
                        var editorEl = quill.root;
                        var sel = window.getSelection();
                        var inserted = false;
                        // Dùng savedRange nếu có (selection trước khi mở modal)
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

                        // Dùng setTimeout để đảm bảo Quill không reset sau insert
                        window.setTimeout(function() {
                            // Xóa class ql-blank để ẩn placeholder
                            editorEl.classList.remove('ql-blank');
                            // Nếu table bị Quill xóa, append lại
                            if (!editorEl.contains(tbl)) {
                                editorEl.appendChild(tbl);
                                editorEl.appendChild(br);
                            }
                            // Focus vào cell đầu tiên
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
                    // Browse or Upload → file picker → base64
                    document.getElementById('fec-img-browse').addEventListener('mousedown', function(ev2) {
                        ev2.preventDefault(); closeImgDD();
                        var fi = document.createElement('input');
                        fi.type='file'; fi.accept='image/*';
                        fi.style.cssText='position:fixed;opacity:0;width:0;height:0;';
                        document.body.appendChild(fi);
                        fi.addEventListener('change', function() {
                            var f = fi.files[0];
                            if (!f) { document.body.removeChild(fi); return; }
                            var rd = new FileReader();
                            rd.onload = function(ev3) {
                                var sel = quill.getSelection(true);
                                quill.insertEmbed(sel.index, 'image', ev3.target.result);
                                document.body.removeChild(fi);
                            };
                            rd.readAsDataURL(f);
                        });
                        fi.click();
                    });
                    // Web Image → modal nhập URL → insert trực tiếp (browser render được)
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
                            if (d && !d.contains(ev2.target)) { closeImgDD(); document.removeEventListener('mousedown', onOut); }
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
                quill.format(cmd, false);
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
                    quill.format(cmd, c);
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
                    quill.format(cmd, inp.value);
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

        // Keyboard handler: xử lý table + Backspace/Delete
        quill.root.addEventListener('keydown', function(e) {
            var sel = window.getSelection();
            if (!sel || sel.rangeCount === 0) return;
            var range = sel.getRangeAt(0);
            var editorEl = quill.root;

            // Kiểm tra cursor/selection có trong table không
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
                // Trong table: stop Quill intercept tất cả key trừ Backspace/Delete (để native xử lý)
                if (e.keyCode !== 8 && e.keyCode !== 46) {
                    e.stopImmediatePropagation();
                }
                // Backspace/Delete trong table → native browser xử lý bình thường
                return;
            }

            // Ngoài table, chỉ xử lý Backspace/Delete
            if (e.keyCode !== 8 && e.keyCode !== 46) return;

            // Case A: có selection (bôi đen) chứa table → xóa table trước, để browser xóa text
            if (!range.collapsed) {
                var frag = range.cloneContents();
                if (frag.querySelector('table')) {
                    editorEl.querySelectorAll('table').forEach(function(t) {
                        if (range.intersectsNode(t)) t.parentNode.removeChild(t);
                    });
                    // Không preventDefault → browser xóa phần text còn lại trong selection
                }
                return; // luôn để browser xử lý phần text
            }

            // Case B: cursor collapsed, liền kề table
            var startEl = range.startContainer.nodeType === 3 ? range.startContainer.parentNode : range.startContainer;
            // Tìm sibling trực tiếp hoặc qua parent
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
            '.fec-ed .ql-editor{min-height:200px;max-height:500px;overflow-y:auto;padding:10px 12px;line-height:1.5;resize:vertical;font-family:"Times New Roman",serif;font-size:14px;color:#000}',
            '.fec-ed .ql-editor p{margin:0!important;padding:0!important;line-height:1.5!important}',
            '.fec-ed .ql-editor p+p{margin-top:0!important}',
            '.fec-ed .ql-editor.ql-blank::before{color:#aaa;font-style:normal}',
            // Ẩn placeholder khi editor có table (table nằm ngoài Quill delta)
            '.fec-ed .ql-editor:has(table)::before{display:none!important}',
            // Table borders
            '.fec-ed .ql-editor table{border-collapse:collapse!important;width:100%!important;margin:8px 0!important}',
            '.fec-ed .ql-editor table td,.fec-ed .ql-editor table th{border:1px solid #999!important;padding:6px 10px!important;min-width:60px!important}',
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
        // Detect record type để biết Interaction hay Service Case
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
                    // Pre-fill To từ outgoing email gần nhất
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
                component.set('v.fromEmail', d.fromEmail||'');
                component.set('v.fromDisplay', d.fromDisplay||d.fromEmail||'');
                component.set('v.toEmail', d.toEmail||'');
                component.set('v.incomingToAddress', d.fromEmail||'');
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

                // Ưu tiên: incoming ToAddress (mailbox nhận email khách) → Queue default → option đầu
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
                    var el = component.getElement();
                    if (!el) return;
                    var sel = el.querySelector('.fec-from-select');
                    if (sel) {
                        sel.value = toSelect;
                        if (sel.value !== toSelect) {
                            window.setTimeout($A.getCallback(syncSelect), 150);
                        }
                    }
                }
                window.setTimeout($A.getCallback(syncSelect), 100);
            }
        });
        $A.enqueueAction(a);
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
            'width:760px','max-width:92vw','max-height:88vh',
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
        bodyDiv.setAttribute('style','flex:1;overflow-y:auto;padding:24px 32px;font-family:"Times New Roman",serif;font-size:14px;line-height:1.5;color:#333;');
        bodyDiv.innerHTML = body || '';

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
                // Reset template selection nếu template hiện tại không còn trong list
                var currentTemplate = component.get('v.replyTemplate');
                if (currentTemplate && !bodies[currentTemplate]) {
                    component.set('v.replyTemplate', '');
                    component.set('v.body', '');
                    if (window._fecQuill) window._fecQuill.root.innerHTML = '';
                }
                // Pre-load attachments cho tất cả templates
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
        // Dùng split/join thay vì regex Unicode để tránh lỗi Aura JS compiler
        var markers = [
            'Anh/ Ch\u1ECB', 'Anh/Ch\u1ECB', 'Anh / Ch\u1ECB',
            'Anh/ Chi', 'Anh/Chi', 'Anh / Chi',
            '{danh_xung}', '{DANH_XUNG}',
            'Ch\u1ECB', 'Chi', 'Anh'
        ];
        var result = html;
        markers.forEach(function(m) {
            result = result.split(m).join('\x00T\x00');
        });
        return result.split('\x00T\x00').join(title);
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
        var body = component.get('v.body') || '';
        if (!body) return;
        var updated = this.replaceDanhXung(body, title);
        component.set('v.body', updated);
        if (window._fecQuill) window._fecQuill.clipboard.dangerouslyPasteHTML(this.cleanBody(updated));
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

                // Thêm email vừa gửi vào feed ngay lập tức
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
                        toast.setParams({ title: 'Thành công', message: 'Email was sent.', type: 'success', duration: 4000 });
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
                // Toast error
                try {
                    var toastErr = $A.get('e.force:showToast');
                    if (toastErr) {
                        toastErr.setParams({ title: 'Lỗi gửi email', message: msg, type: 'error', duration: 8000 });
                        toastErr.fire();
                    }
                } catch(te2) { console.log('toast error2', te2); }
            }
        });
        $A.enqueueAction(action);
    },

    loadEmails: function(component) {
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
                    return {Id:m.Id,fromName:m.FromName||m.FromAddress||'Unknown',fromAddress:m.FromAddress||'',toAddress:m.ToAddress||'',ccAddress:m.CcAddress||'',subject:subjDisplay,subjectPreview:subjDisplay||rb.substring(0,80),bodyFull:rb,bodyHtml:m.HtmlBody||'',messageDate:ds,messageRawDate:m.MessageDate||'',incoming:m.Incoming,expanded:false,showDD:false};
                });
                // Sort
                list.sort(function(a,b){
                    if (sortOrder==='oldest') return (a.messageRawDate||'') < (b.messageRawDate||'') ? -1 : 1;
                    if (sortOrder==='latest') return (a.messageRawDate||'') > (b.messageRawDate||'') ? -1 : 1;
                    return (a.messageRawDate||'') > (b.messageRawDate||'') ? -1 : 1; // recent = newest first
                });
                component.set('v.emailList',list);
                // Pre-fill To cho Service Case từ outgoing email gần nhất
                if (component.get('v.isServiceCase') && !component.get('v.serviceCaseToEmail')) {
                    var outgoing = list.filter(function(e) { return e.incoming === false; });
                    if (outgoing.length > 0 && outgoing[0].toAddress) {
                        component.set('v.serviceCaseToEmail', outgoing[0].toAddress);
                    }
                }
            }
        });
        $A.enqueueAction(a);
    }
})