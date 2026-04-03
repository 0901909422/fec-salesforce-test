({
    doInit: function(component, event, helper) {
        helper.loadCaseData(component);
        helper.loadTemplates(component);
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
            var rawBody = bodies[templateId] || '';
            var title = component.get('v.titleReply') || '';
            var body = helper.replaceDanhXung(rawBody, title);
            component.set('v.body', body);
            if (window._fecQuill) {
                window._fecQuill.root.innerHTML = helper.cleanBody(body);
            }
            // Apply subject từ template nếu có
            var templateSubject = subjects && subjects[templateId] ? subjects[templateId] : '';
            if (templateSubject) {
                component.set('v.subject', templateSubject);
            }
        } else {
            component.set('v.body', '');
            if (window._fecQuill) { window._fecQuill.root.innerHTML = ''; }
        }
    },

    openCompose: function(component, event, helper) {
        var orig = component.get('v.originalSubject');
        component.set('v.subject', orig ? 'RE: ' + orig : '');
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
        component.set('v.subject', orig ? 'RE: ' + orig : '');
        component.set('v.errorMsg', '');
        component.set('v.serviceCaseToError', '');
        if (isServiceCase) {
            // Pre-fill To = fromAddress của email khách (người gửi email đó)
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
        component.set('v.subject', orig ? 'RE: ' + orig : '');
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
        component.set('v.subject', orig ? 'FW: ' + orig : '');
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
        component.set('v.fromEmail', event.target.value);
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
        var existing = component.get('v.attachments') || [];
        var newList = existing.slice();
        for (var i = 0; i < files.length; i++) {
            newList.push({ name: files[i].name, size: files[i].size, file: files[i] });
        }
        component.set('v.attachments', newList);
    },

    removeAttachment: function(component, event, helper) {
        var idx = parseInt(event.currentTarget.dataset.idx, 10);
        var list = (component.get('v.attachments') || []).slice();
        list.splice(idx, 1);
        component.set('v.attachments', list);
    },

    previewEmail: function(component, event, helper) {
        var body = window._fecQuill ? window._fecQuill.root.innerHTML : component.get('v.body');

        // Remove existing preview if any
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

        // Header
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

        // Body
        var bodyDiv = document.createElement('div');
        bodyDiv.setAttribute('style','flex:1;overflow-y:auto;padding:24px 32px;font-family:"Times New Roman",serif;font-size:14px;line-height:1.5;color:#333;');
        bodyDiv.innerHTML = body;

        // Footer
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

        // Append to body
        document.body.appendChild(overlay);

        function closeModal() {
            var el = document.getElementById('fec-preview-overlay');
            if (el && el.parentNode) el.parentNode.removeChild(el);
        }
        closeBtn.addEventListener('click', closeModal);
        footCloseBtn.addEventListener('click', closeModal);
        overlay.addEventListener('click', function(e) { if (e.target === overlay) closeModal(); });
    },

    closePreview: function(component, event, helper) {
        component.set('v.showPreview', false);
    },

    stopPropagation: function(component, event, helper) {
        event.stopPropagation();
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
                component.set('v.serviceCaseToError', $A.get('$Label.c.FEC_Email_Error_To_Required') || 'To email không được để trống.');
                return;
            }
            var emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRe.test(finalToEmail)) {
                component.set('v.serviceCaseToError', 'To ' + ($A.get('$Label.c.FEC_Email_Error_Invalid') || 'email không hợp lệ: "') + finalToEmail + '"');
                return;
            }
            component.set('v.serviceCaseToError', '');
        } else {
            var toEmail = component.get('v.toEmail');
            var tags = component.get('v.toTags');
            finalToEmail = toEmail || (tags && tags.length > 0 ? tags.join(',') : '');
            if (!finalToEmail) { component.set('v.errorMsg', $A.get('$Label.c.FEC_Email_Error_Empty') || 'To email is required.'); return; }
        }
        var subject = component.get('v.subject');
        var body = window._fecQuill ? window._fecQuill.root.innerHTML : component.get('v.body');
        if (!subject) { component.set('v.errorMsg', 'Subject is required.'); return; }
        var bodyText = window._fecQuill ? window._fecQuill.getText().trim() : (body || '').replace(/<[^>]+>/g,'').trim();
        if (!bodyText) { component.set('v.errorMsg', 'Body is required.'); return; }
        console.log('sendEmail: calling doSendEmail, fromEmail=', component.get('v.fromEmail'), 'toEmail=', finalToEmail);

        component.set('v.isSending', true);
        component.set('v.errorMsg', '');

        // Read attachments as base64 then send
        var attachments = component.get('v.attachments') || [];
        if (attachments.length === 0) {
            helper.doSendEmail(component, finalToEmail, subject, body, []);
            return;
        }

        // Convert File objects to base64
        var converted = [];
        var pending = attachments.length;
        attachments.forEach(function(att, idx) {
            var reader = new FileReader();
            reader.onload = $A.getCallback(function(e) {
                var dataUrl = e.target.result; // data:<mime>;base64,<data>
                var parts = dataUrl.split(',');
                var mimeMatch = parts[0].match(/:(.*?);/);
                converted[idx] = {
                    fileName: att.name,
                    base64Data: parts[1],
                    mimeType: mimeMatch ? mimeMatch[1] : 'application/octet-stream'
                };
                pending--;
                if (pending === 0) {
                    helper.doSendEmail(component, finalToEmail, subject, body, converted);
                }
            });
            reader.onerror = $A.getCallback(function() {
                component.set('v.isSending', false);
                component.set('v.errorMsg', 'Lỗi đọc file đính kèm: ' + att.name);
            });
            reader.readAsDataURL(att.file);
        });
    }
})
