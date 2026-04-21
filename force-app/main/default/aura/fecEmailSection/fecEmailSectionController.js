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
            component.set('v.body', fullBody);
            component.set('v.rawBody', fullBody); // tungnm37: lưu raw HTML để gửi email
            if (window._fecQuill) {
                var _q = window._fecQuill;
                var _body = helper.cleanBody(fullBody);
                window.setTimeout(function() {
                    if (_q.scroll && _q.scroll.observer) {
                        _q.scroll.observer.disconnect();
                    }
                    _q.root.innerHTML = _body;
                    _q.root.classList.remove('ql-blank');
                    window.setTimeout(function() {
                        if (_q.scroll && _q.scroll.observer) {
                            _q.scroll.observer.observe(_q.root, _q.scroll.observer._options || { childList: true, subtree: true, characterData: true });
                        }
                    }, 100);
                }, 50);
            }
            // Apply subject từ template, giữ prefix RE:/FW: nếu đang reply/forward
            var templateSubject = subjects && subjects[templateId] ? subjects[templateId] : '';
            if (templateSubject) {
                component.set('v.subject', templateSubject);
            }
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
        var MAX_SIZE = 25 * 1024 * 1024; // 25MB
        var existing = component.get('v.attachments') || [];
        var newList = existing.slice();
        var hasError = false;
        for (var i = 0; i < files.length; i++) {
            if (files[i].size > MAX_SIZE) {
                hasError = true;
                try {
                    var t = $A.get('e.force:showToast');
                    if (t) { t.setParams({ title: 'File too large', message: files[i].name + ' exceeds the 25 MB limit.', type: 'error', duration: 6000 }); t.fire(); }
                } catch(e) {}
            } else {
                newList.push({ name: files[i].name, size: files[i].size, file: files[i] });
            }
        }
        component.set('v.attachments', newList);
        // Reset input so same file can be re-selected
        event.target.value = '';
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
        // Chỉ xóa nội dung text trong editor, không đóng compose
        component.set('v.body', '');
        if (window._fecQuill) { window._fecQuill.root.innerHTML = ''; }
        component.set('v.errorMsg', '');
    },

    sendEmail: function(component, event, helper) {
        // Service Case: dùng serviceCaseToEmail; Interaction: dùng toEmail/toTags
        var isServiceCase = component.get('v.isServiceCase');
        var finalToEmail;
        if (isServiceCase) {
            finalToEmail = (component.get('v.serviceCaseToEmail') || '').trim();
            if (!finalToEmail) {
                component.set('v.serviceCaseToError', 'To email is required.');
                try {
                    var t1 = $A.get('e.force:showToast');
                    if (t1) { t1.setParams({ title: 'We hit a snag', message: 'Review the errors on this page. To email is required.', type: 'error', duration: 4000 }); t1.fire(); }
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
                    if (t2) { t2.setParams({ title: 'Invalid format', message: '"' + invalidEmail + '" is not a valid To email address.', type: 'error', duration: 4000 }); t2.fire(); }
                } catch(e) {}
                return;
            }
        } else {
            var toEmail = component.get('v.toEmail');
            var tags = component.get('v.toTags');
            finalToEmail = toEmail || (tags && tags.length > 0 ? tags.join(',') : '');
            if (!finalToEmail) {
                component.set('v.errorMsg', 'To email is required.');
                try {
                    var t3 = $A.get('e.force:showToast');
                    if (t3) { t3.setParams({ title: 'We hit a snag', message: 'Review the errors on this page. To email is required.', type: 'error', duration: 4000 }); t3.fire(); }
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
        if (!subject) {
            component.set('v.errorMsg', 'Subject is required.');
            try { var ts=$A.get('e.force:showToast'); if(ts){ts.setParams({title:'We hit a snag',message:'Review the errors on this page. Subject is required.',type:'error',duration:4000});ts.fire();} } catch(e){}
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
                try { var tcc=$A.get('e.force:showToast'); if(tcc){tcc.setParams({title:'Invalid format',message:'"' + invalidCC + '" is not a valid CC email address.',type:'error',duration:4000});tcc.fire();} } catch(e){}
                return;
            }
        }
        var bodyText = window._fecQuill ? window._fecQuill.getText().trim() : (body || '').replace(/<[^>]+>/g,'').trim();
        if (!bodyText && window._fecQuill) {
            var hasTable = window._fecQuill.root.querySelector('table') !== null;
            if (hasTable) bodyText = 'table';
        }
        if (!bodyText) {
            component.set('v.errorMsg', 'Email body is required.');
            try { var tb=$A.get('e.force:showToast'); if(tb){tb.setParams({title:'We hit a snag',message:'Review the errors on this page. Email body is required.',type:'error',duration:4000});tb.fire();} } catch(e){}
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
        var MAX_SIZE = 25 * 1024 * 1024; // 25MB
        // Separate template attachments (already base64) from user-uploaded files
        var templateAtts = [];
        var fileAtts = [];
        for (var i = 0; i < attachments.length; i++) {
            if (attachments[i]._fromTemplate) {
                templateAtts.push({ fileName: attachments[i].name, base64Data: attachments[i]._base64, mimeType: attachments[i]._mime });
            } else {
                if (attachments[i].size > MAX_SIZE) {
                    component.set('v.isSending', false);
                    var toastSize = $A.get('e.force:showToast');
                    if (toastSize) {
                        toastSize.setParams({ title: 'File too large', message: attachments[i].name + ' exceeds the 25 MB limit.', type: 'error', duration: 6000 });
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