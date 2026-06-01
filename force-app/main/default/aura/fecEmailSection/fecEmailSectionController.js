({
    doInit: function(component, event, helper) {
        helper.loadCaseData(component);
        helper.loadTemplates(component, null);
        helper.loadEmails(component);
    },

    onRecordUpdated: function(component, event, helper) {
        var rec = component.get('v.caseRecord');
        if (rec) {
            var mode = rec.FEC_Interaction_View_Mode__c;
            component.set('v.isHandling', mode === 'handling');
        }
    },

    onModeMessage: function(component, event, helper) {
        var params = event.getParam('payload') || event.getParam('message') || event;
        var isModeEdit = params && params.isModeEdit;
        component.set('v.isHandling', isModeEdit === true);
        if (!isModeEdit) {
            // Reset compose khi về review
            component.set('v.showCompose', false);
        }
    },

    loadEmails: function(component, event, helper) {
        helper.loadEmails(component);
    },

    refreshPage: function(component, event, helper) {
        // Nếu đang compose thì đóng compose và reset về trạng thái ban đầu
        if (component.get('v.showCompose')) {
            component.set('v.showCompose', false);
            component.set('v.subject', '');
            component.set('v.body', '');
            component.set('v.ccEmail', '');
            component.set('v.toTags', []);
            component.set('v.toInput', '');
            component.set('v.errorMsg', '');
            if (window._fecQuill) { window._fecQuill.root.innerHTML = ''; }
        }
        helper.loadEmails(component);
    },

    onTitleChange: function(component, event, helper) {
        var title = event.getSource().get('v.value');
        component.set('v.titleReply', title);
        helper.applyTitleToBody(component, title);
    },

    onTemplateChange: function(component, event, helper) {
        var templateId = event.getSource().get('v.value');
        component.set('v.replyTemplate', templateId);
        if (templateId) {
            var bodies = component.get('v.templateBodies');
            var subjects = component.get('v.templateSubjects');
            var headers = component.get('v.templateHeaders') || {};
            var footers = component.get('v.templateFooters') || {};
            var rawBody = bodies[templateId] || '';
            var header = headers[templateId] || '';
            var footer = footers[templateId] || '';
            var title = component.get('v.titleReply') || '';
            var body = helper.replaceDanhXung(rawBody, title);
            // Ghép header + body + footer
            var fullBody = (header ? header : '') + body + (footer ? footer : '');
            var templateSubject = subjects && subjects[templateId] ? subjects[templateId] : '';

            var renderResolvedTemplate = function(resolvedSubject, resolvedBody) {
                component.set('v.body', resolvedBody);
                component.set('v.rawBody', resolvedBody); // lưu HTML đã resolve để gửi email
                if (window._fecQuill) {
                    var _q = window._fecQuill;
                    var _body = helper.cleanBody(resolvedBody);
                    window.setTimeout(function() {
                        if (_q.scroll && _q.scroll.observer) {
                            _q.scroll.observer.disconnect();
                        }
                        _q.root.innerHTML = _body;
                        _q.root.classList.remove('ql-blank');
                        // tungnm37 thêm: đảm bảo td/th từ template có contenteditable
                        helper._makeTableCellsEditable(_q.root);
                        window.setTimeout(function() {
                            if (_q.scroll && _q.scroll.observer) {
                                _q.scroll.observer.observe(_q.root, _q.scroll.observer._options || { childList: true, subtree: true, characterData: true });
                            }
                        }, 100);
                    }, 50);
                }
                if (resolvedSubject) {
                    component.set('v.subject', resolvedSubject);
                }
            };

            var resolveAction = component.get('c.resolveEmailTemplate');
            resolveAction.setParams({
                caseId: component.get('v.recordId'),
                subject: templateSubject,
                body: fullBody
            });
            resolveAction.setCallback(this, function(resp) {
                if (resp.getState() === 'SUCCESS') {
                    var resolved = resp.getReturnValue() || {};
                    renderResolvedTemplate(resolved.subject || templateSubject, resolved.body || fullBody);
                } else {
                    renderResolvedTemplate(templateSubject, fullBody);
                }
            });
            $A.enqueueAction(resolveAction);
            // Load attachments từ template (pre-loaded in templateAttachments cache)
            var allAtts = component.get('v.templateAttachments') || {};
            var tmplAtts = allAtts[templateId] || [];
            component.set('v.attachments', tmplAtts.map(function(a) {
                return { name: a.fileName, size: 0, _fromTemplate: true, _base64: a.base64Data, _mime: a.mimeType };
            }));
        } else {
            component.set('v.body', '');
            component.set('v.subject', '');
            component.set('v.attachments', []);
            if (window._fecQuill) { window._fecQuill.root.innerHTML = ''; }
            // Khi bỏ chọn template, khôi phục subject gốc (RE:/FW: + originalSubject)
            var prefix2 = component.get('v.replyPrefix') || '';
            var orig = component.get('v.originalSubject') || '';
            if (prefix2 && orig) {
                component.set('v.subject', prefix2 + '<' + orig + '>');
            }
        }
    },

    openCompose: function(component, event, helper) {
        var orig = component.get('v.originalSubject');
        component.set('v.replyPrefix', 'RE: ');
        component.set('v.subject', orig ? 'RE: <' + orig + '>' : '');
        component.set('v.errorMsg', '');
        component.set('v.serviceCaseToError', '');
        var isServiceCase = component.get('v.isServiceCase');
        if (!isServiceCase) {
            var toEmail = component.get('v.toEmail');
            if (toEmail && component.get('v.toTags').length === 0) {
                component.set('v.toTags', [toEmail]);
            }
        }
        component.set('v.showCompose', true);
        var body = component.get('v.body') || '';
        window.setTimeout($A.getCallback(function() {
            helper.initQuill(component, body);
        }), 150);
    },

    handleReply: function(component, event, helper) {
        var isServiceCase = component.get('v.isServiceCase');
        var emailSubject = event.currentTarget ? event.currentTarget.dataset.subject : null;
        var emailFrom = event.currentTarget ? event.currentTarget.dataset.from : null;
        var orig = emailSubject || component.get('v.originalSubject');
        component.set('v.replyPrefix', 'RE: ');
        component.set('v.subject', orig ? 'RE: <' + orig + '>' : '');
        component.set('v.errorMsg', '');
        component.set('v.serviceCaseToError', '');
        if (isServiceCase) {
            if (emailFrom) component.set('v.serviceCaseToEmail', emailFrom);
        } else {
            var toEmail = component.get('v.toEmail');
            if (toEmail && component.get('v.toTags').length === 0) {
                component.set('v.toTags', [toEmail]);
            }
        }
        component.set('v.showCompose', true);
        var body = component.get('v.body') || '';
        window.setTimeout($A.getCallback(function() { helper.initQuill(component, body); }), 150);
    },

    handleReplyAll: function(component, event, helper) {
        var isServiceCase = component.get('v.isServiceCase');
        var emailSubject = event.currentTarget ? event.currentTarget.dataset.subject : null;
        var emailFrom = event.currentTarget ? event.currentTarget.dataset.from : null;
        var orig = emailSubject || component.get('v.originalSubject');
        component.set('v.replyPrefix', 'RE: ');
        component.set('v.subject', orig ? 'RE: <' + orig + '>' : '');
        component.set('v.errorMsg', '');
        component.set('v.serviceCaseToError', '');
        if (isServiceCase) {
            if (emailFrom) component.set('v.serviceCaseToEmail', emailFrom);
        } else {
            var toEmail = component.get('v.toEmail');
            if (toEmail && component.get('v.toTags').length === 0) {
                component.set('v.toTags', [toEmail]);
            }
        }
        component.set('v.showCompose', true);
        var body = component.get('v.body') || '';
        window.setTimeout($A.getCallback(function() { helper.initQuill(component, body); }), 150);
    },

    handleForward: function(component, event, helper) {
        var emailSubject = event.currentTarget ? event.currentTarget.dataset.subject : null;
        var orig = emailSubject || component.get('v.originalSubject');
        component.set('v.replyPrefix', 'FW: ');
        component.set('v.subject', orig ? 'FW: <' + orig + '>' : '');
        component.set('v.errorMsg', '');
        component.set('v.serviceCaseToError', '');
        component.set('v.toTags', []);
        component.set('v.serviceCaseToEmail', '');
        component.set('v.showCompose', true);
        var body = component.get('v.body') || '';
        window.setTimeout($A.getCallback(function() { helper.initQuill(component, body); }), 150);
    },

    onToKeydown: function(component, event, helper) {
        var key = event.keyCode || event.which;
        if (key === 13 || key === 188 || key === 9 || key === 32) {
            event.preventDefault();
            helper.addToTag(component);
        }
        if (key === 8) {
            var val = component.get('v.toInput') || '';
            if (!val) {
                var tags = component.get('v.toTags');
                if (tags.length > 0) {
                    component.set('v.toTags', tags.slice(0, tags.length - 1));
                }
            }
        }
    },

    onToInputChange: function(component, event, helper) {
        component.set('v.toInput', event.target.value);
    },

    onToBlur: function(component, event, helper) {
        helper.addToTag(component);
    },

    removeToTag: function(component, event, helper) {
        var tag = event.currentTarget.dataset.tag;
        component.set('v.toTags', component.get('v.toTags').filter(function(t) { return t !== tag; }));
    },

    onCcChange: function(component, event, helper) {
        component.set('v.ccEmail', event.target.value);
    },

    onFromChange: function(component, event, helper) {
        var newFrom = event.target.value;
        component.set('v.fromEmail', newFrom);
        // Reload templates filtered by new From address
        helper.loadTemplates(component, newFrom);
    },

    onServiceCaseToChange: function(component, event, helper) {
        component.set('v.serviceCaseToEmail', event.target.value);
        component.set('v.serviceCaseToError', '');
    },

    onFromInputChange: function(component, event, helper) {
        component.set('v.fromEmail', event.target.value);
    },

    onSubjectChange: function(component, event, helper) {
        component.set('v.subject', event.target.value);
    },

    onSearchChange: function(component, event, helper) {
        component.set('v.searchKeyword', event.target.value);
    },

    toggleSortDD: function(component, event, helper) {
        component.set('v.showSortDD', !component.get('v.showSortDD'));
    },

    setSortLatest: function(component, event, helper) {
        component.set('v.sortOrder', 'latest');
        component.set('v.showSortDD', false);
        helper.loadEmails(component);
    },

    setSortRecent: function(component, event, helper) {
        component.set('v.sortOrder', 'recent');
        component.set('v.showSortDD', false);
        helper.loadEmails(component);
    },

    setSortOldest: function(component, event, helper) {
        component.set('v.sortOrder', 'oldest');
        component.set('v.showSortDD', false);
        helper.loadEmails(component);
    },

    toggleItemDD: function(component, event, helper) {
        event.stopPropagation();
        var emailId = event.currentTarget.dataset.id;
        var current = component.get('v.activeItemId');
        component.set('v.activeItemId', current === emailId ? '' : emailId);
    },

    toggleAll: function(component, event, helper) {
        var allExpanded = !component.get('v.allExpanded');
        component.set('v.allExpanded', allExpanded);
        component.set('v.emailList', component.get('v.emailList').map(function(e) {
            return Object.assign({}, e, { expanded: allExpanded });
        }));
    },

    toggleExpand: function(component, event, helper) {
        var emailId = event.currentTarget.dataset.id;
        component.set('v.emailList', component.get('v.emailList').map(function(e) {
            if (e.Id === emailId) return Object.assign({}, e, { expanded: !e.expanded });
            return e;
        }));
    },

    onAttachChange: function(component, event, helper) {
        var files = event.target.files;
        if (!files || files.length === 0) return;
        // tungnm37 sửa: lưu ref trước khi Aura re-render
        var inputTarget = event.target;
        var MAX_SIZE = 25 * 1024 * 1024; // 25MB - chỉ áp dụng cho file không phải ảnh
        var existing = component.get('v.attachments') || [];
        var newList = existing.slice();
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            var isImage = f.type && f.type.indexOf('image/') === 0;
            // tungnm37 sửa: ảnh không giới hạn size, chỉ check 25MB với file thường
            if (!isImage && f.size > MAX_SIZE) {
                try {
                    var t = $A.get('e.force:showToast');
                    if (t) { t.setParams({ title: component.get('v.lblFileTooLargeTitle'), message: f.name + ' ' + component.get('v.lblFileTooLargeMsg'), type: 'error', duration: 6000 }); t.fire(); }
                } catch(e) {}
            } else {
                newList.push({ name: f.name, size: f.size, file: f });
            }
        }
        component.set('v.attachments', newList);
        // tungnm37 sửa: reset sau setTimeout để lần 2 vẫn trigger onchange
        window.setTimeout(function() {
            try { if (inputTarget) inputTarget.value = ''; } catch(ex) {}
        }, 0);
    },

    removeAttachment: function(component, event, helper) {
        var idx = parseInt(event.currentTarget.dataset.idx, 10);
        var list = (component.get('v.attachments') || []).slice();
        list.splice(idx, 1);
        component.set('v.attachments', list);
    },

    previewEmail: function(component, event, helper) {
        var body = '';
        if (window._fecQuill) {
            body = window._fecQuill.root.innerHTML;
            var text = window._fecQuill.getText().trim();
            if (!text && !window._fecQuill.root.querySelector('table,img')) {
                body = component.get('v.body') || '';
            }
        } else {
            body = component.get('v.body') || '';
        }
        helper.showPreviewModal(body);
    },

    closePreview: function(component, event, helper) {
        component.set('v.showPreview', false);
    },

    stopPropagation: function(component, event, helper) {
        event.stopPropagation();
    },

    previewFeedEmail: function(component, event, helper) {
        var body = event.currentTarget ? (event.currentTarget.getAttribute('data-body') || '') : '';
        if (!body) return;
        helper.showPreviewModal(body);
    },

    discardEmail: function(component, event, helper) {
        // tungnm37 sửa: hiện popup xác nhận qua JS (append to body để tránh stacking context của Aura)
        var existing = document.getElementById('fec-discard-popup');
        if (existing) return;
        var lblTitle = component.get('v.lblDiscardTitle') || 'Discard Draft?';
        var lblMsg = component.get('v.lblDiscardMsg') || 'Recipients, subject, body text, and attachments are removed.';
        var lblDiscard = component.get('v.lblDiscardBtn') || 'Discard';
        var lblCancel = component.get('v.lblCancelBtn') || 'Cancel';

        var overlay = document.createElement('div');
        overlay.id = 'fec-discard-popup';
        overlay.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,.5);z-index:99999;';

        var modal = document.createElement('div');
        modal.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:#fff;border-radius:12px;padding:32px 28px 24px;width:420px;max-width:92vw;box-shadow:0 8px 32px rgba(0,0,0,.25);z-index:100000;text-align:center;';
        modal.innerHTML = '<div id="fec-discard-close" style="position:absolute;top:14px;right:18px;font-size:20px;cursor:pointer;color:#706e6b;line-height:1;">&#x2715;</div>'
            + '<div style="font-size:20px;font-weight:700;color:#16325c;margin-bottom:12px;">' + lblTitle + '</div>'
            + '<div style="font-size:14px;color:#555;margin-bottom:24px;line-height:1.5;">' + lblMsg + '</div>'
            + '<div style="display:flex;justify-content:flex-end;gap:8px;border-top:1px solid #e5e5e5;padding-top:16px;">'
            + '<button id="fec-discard-cancel" style="padding:7px 18px;border:1px solid #c8c8c8;border-radius:20px;background:#fff;cursor:pointer;font-size:13px;color:#333;">' + lblCancel + '</button>'
            + '<button id="fec-discard-confirm" style="padding:7px 18px;border:none;border-radius:20px;background:#0070d2;color:#fff;cursor:pointer;font-size:13px;">' + lblDiscard + '</button>'
            + '</div>';

        document.body.appendChild(overlay);
        document.body.appendChild(modal);

        function closePopup() {
            var o = document.getElementById('fec-discard-popup');
            var m = document.getElementById('fec-discard-modal-box');
            if (o && o.parentNode) o.parentNode.removeChild(o);
            if (m && m.parentNode) m.parentNode.removeChild(m);
            // remove modal by finding it
            if (modal.parentNode) modal.parentNode.removeChild(modal);
        }
        modal.id = 'fec-discard-modal-box';

        overlay.addEventListener('click', closePopup);
        document.getElementById('fec-discard-close').addEventListener('click', closePopup);
        document.getElementById('fec-discard-cancel').addEventListener('click', closePopup);
        document.getElementById('fec-discard-confirm').addEventListener('click', $A.getCallback(function() {
            closePopup();
            component.set('v.body', '');
            component.set('v.rawBody', '');
            component.set('v.subject', '');
            component.set('v.ccEmail', '');
            component.set('v.toTags', []);
            component.set('v.toInput', '');
            component.set('v.attachments', []);
            component.set('v.replyTemplate', '');
            component.set('v.errorMsg', '');
            if (window._fecQuill) { window._fecQuill.root.innerHTML = ''; }
        }));
    },

    confirmDiscard: function(component, event, helper) {},
    cancelDiscard: function(component, event, helper) {
        component.set('v.showDiscardConfirm', false);
    },

    sendEmail: function(component, event, helper) {
        // Service Case: dùng serviceCaseToEmail; Interaction: dùng toEmail/toTags
        var isServiceCase = component.get('v.isServiceCase');
        // tungnm37 sửa: dùng custom labels thay hardcode
        var lblSnag = component.get('v.lblWeHitASnag');
        var lblToReq = component.get('v.lblToRequired') || 'To email is required.';
        var lblInvalidFmt = component.get('v.lblInvalidFormatTitle');
        var finalToEmail;
        if (isServiceCase) {
            finalToEmail = (component.get('v.serviceCaseToEmail') || '').trim();
            if (!finalToEmail) {
                component.set('v.serviceCaseToError', lblToReq);
                try {
                    var t1 = $A.get('e.force:showToast');
                    if (t1) { t1.setParams({ title: lblSnag, message: 'Review the errors on this page. ' + lblToReq, type: 'error', duration: 4000 }); t1.fire(); }
                } catch(e) {}
                return;
            }
            var emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            var normalizedInput = finalToEmail.replace(/;/g, ',').replace(/,\s*/g, ',');
            var emailList = normalizedInput.split(',').map(function(e) { return e.trim().replace(/\.+$/, ''); }).filter(function(e) { return e && e.indexOf('@') > -1; });
            var invalidEmail = null;
            for (var i = 0; i < emailList.length; i++) {
                if (!emailRe.test(emailList[i])) { invalidEmail = emailList[i]; break; }
            }
            if (invalidEmail) {
                component.set('v.serviceCaseToError', '"' + invalidEmail + '" is not a valid To email address.');
                try {
                    var t2 = $A.get('e.force:showToast');
                    if (t2) { t2.setParams({ title: lblInvalidFmt, message: '"' + invalidEmail + '" is not a valid To email address.', type: 'error', duration: 4000 }); t2.fire(); }
                } catch(e) {}
                return;
            }
        } else {
            var toEmail = component.get('v.toEmail');
            var tags = component.get('v.toTags');
            finalToEmail = toEmail || (tags && tags.length > 0 ? tags.join(',') : '');
            if (!finalToEmail) {
                component.set('v.errorMsg', lblToReq);
                try {
                    var t3 = $A.get('e.force:showToast');
                    if (t3) { t3.setParams({ title: lblSnag, message: 'Review the errors on this page. ' + lblToReq, type: 'error', duration: 4000 }); t3.fire(); }
                } catch(e) {}
                return;
            }
        }
        var subject = component.get('v.subject');
        var body = window._fecQuill ? window._fecQuill.root.innerHTML : component.get('v.body');
        // If v.body has table HTML but quill stripped it, use rawBody or v.body directly
        var storedBody = component.get('v.rawBody') || component.get('v.body') || '';
        if (storedBody.indexOf('<table') !== -1 && body.indexOf('<table') === -1) {
            body = storedBody;
        }
        var lblSubjReq = component.get('v.lblSubjectRequired');
        if (!subject) {
            component.set('v.errorMsg', lblSubjReq);
            try { var ts=$A.get('e.force:showToast'); if(ts){ts.setParams({title:lblSnag,message:'Review the errors on this page. '+lblSubjReq,type:'error',duration:4000});ts.fire();} } catch(e){}
            return;
        }
        // Validate CC format
        var ccRaw = (component.get('v.ccEmail') || '').trim();
        if (ccRaw) {
            var emailReCC = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            var ccNormalized = ccRaw.replace(/;/g, ',').replace(/,\s*/g, ',');
            var ccList = ccNormalized.split(',').map(function(e) { return e.trim().replace(/\.+$/, ''); }).filter(function(e) { return e; });
            var invalidCC = null;
            for (var ci = 0; ci < ccList.length; ci++) {
                if (!emailReCC.test(ccList[ci])) { invalidCC = ccList[ci]; break; }
            }
            if (invalidCC) {
                component.set('v.errorMsg', '"' + invalidCC + '" is not a valid CC email address.');
                try { var tcc=$A.get('e.force:showToast'); if(tcc){tcc.setParams({title:lblInvalidFmt,message:'"' + invalidCC + '" is not a valid CC email address.',type:'error',duration:4000});tcc.fire();} } catch(e){}
                return;
            }
        }
        var bodyText = window._fecQuill ? window._fecQuill.getText().trim() : (body || '').replace(/<[^>]+>/g,'').trim();
        if (!bodyText && window._fecQuill) {
            // tungnm37 sửa: check cả img (ảnh insert) không chỉ table
            var hasTable = window._fecQuill.root.querySelector('table') !== null;
            var hasImg = window._fecQuill.root.querySelector('img') !== null;
            if (hasTable || hasImg) bodyText = 'content';
        }
        // tungnm37 sửa: nếu body HTML có img tag thì cũng coi là có nội dung
        if (!bodyText && body && body.indexOf('<img') !== -1) {
            bodyText = 'content';
        }
        var lblBodyReq = component.get('v.lblBodyRequired');
        if (!bodyText) {
            component.set('v.errorMsg', lblBodyReq);
            try { var tb=$A.get('e.force:showToast'); if(tb){tb.setParams({title:lblSnag,message:'Review the errors on this page. '+lblBodyReq,type:'error',duration:4000});tb.fire();} } catch(e){}
            return;
        }
        // Normalize: đổi ". " thành "," rồi split, trim trailing dots
        if (isServiceCase) {
            var normalizedInput2 = finalToEmail.replace(/;/g, ',').replace(/,\s*/g, ',');
            var normalizedEmails = normalizedInput2.split(',').map(function(e) { return e.trim().replace(/\.+$/, ''); }).filter(function(e) { return e && e.indexOf('@') > -1; });
            finalToEmail = normalizedEmails.join(',');
        }

        component.set('v.isSending', true);
        component.set('v.errorMsg', '');

        // Read attachments as base64 then send
        var attachments = component.get('v.attachments') || [];
        if (attachments.length === 0) {
            helper.doSendEmail(component, finalToEmail, subject, body, []);
            return;
        }
        var converted = [];
        var pending = 0;
        var MAX_SIZE = 25 * 1024 * 1024; // 25MB - chỉ áp dụng cho file không phải ảnh
        // tungnm37 sửa: ảnh insert vào body (_isInlineImg) không gửi kèm attachment
        // chỉ strip blob URL khỏi body. File đính kèm thường mới convert base64.
        var templateAtts = [];
        var fileAtts = [];
        for (var i = 0; i < attachments.length; i++) {
            if (attachments[i]._fromTemplate) {
                templateAtts.push({ fileName: attachments[i].name, base64Data: attachments[i]._base64, mimeType: attachments[i]._mime });
            } else if (attachments[i]._isInlineImg) {
                // Ảnh insert vào body — không gửi kèm, đã strip blob URL khỏi bodyToSend
            } else {
                // tungnm37 sửa: ảnh không giới hạn size, chỉ check 25MB với file thường
                var attFile = attachments[i].file;
                var isImg = attFile && attFile.type && attFile.type.indexOf('image/') === 0;
                if (!isImg && attachments[i].size > MAX_SIZE) {
                    component.set('v.isSending', false);
                    var toastSize = $A.get('e.force:showToast');
                    if (toastSize) {
                        toastSize.setParams({ title: component.get('v.lblFileTooLargeTitle'), message: attachments[i].name + ' ' + component.get('v.lblFileTooLargeMsg'), type: 'error', duration: 6000 });
                        toastSize.fire();
                    }
                    return;
                }
                fileAtts.push(attachments[i]);
            }
        }
        if (fileAtts.length === 0) {
            helper.doSendEmail(component, finalToEmail, subject, body, templateAtts);
            return;
        }
        pending = fileAtts.length;
        var fileConverted = [];
        fileAtts.forEach(function(att, idx) {
            var reader = new FileReader();
            reader.onload = $A.getCallback(function(e) {
                var dataUrl = e.target.result;
                var parts = dataUrl.split(',');
                var mimeMatch = parts[0].match(/:(.*?);/);
                fileConverted[idx] = {
                    fileName: att.name,
                    base64Data: parts[1],
                    mimeType: mimeMatch ? mimeMatch[1] : 'application/octet-stream'
                };
                pending--;
                if (pending === 0) {
                    helper.doSendEmail(component, finalToEmail, subject, body, templateAtts.concat(fileConverted));
                }
            });
            reader.onerror = $A.getCallback(function() {
                component.set('v.isSending', false);
                component.set('v.errorMsg', 'Error reading attachment: ' + att.name);
            });
            reader.readAsDataURL(att.file);
        });
    }
})