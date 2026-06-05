/**
 * @description  Template Editor – full-page form for creating or editing an
 *               email template record.
 *
 *               Fields (per design):
 *               Folder, Template Name*, API Name (auto), Description,
 *               Enhanced Letterhead, Applicable for Mailbox (multi-select),
 *               Active, Attachment (multi-file upload), Subject, Body (rich text).
 *
 *               Buttons: Back to List, Save, Save & New, Preview
 *
 *               Merge fields inserted at cursor position (not appended).
 *
 *               Apex-backed via FEC_TemplateController + FEC_FolderController.
 * @component    fec_templateEditor
 */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/* ── Apex ── */
import getTemplate        from '@salesforce/apex/FEC_TemplateController.getTemplate';
import saveTemplate       from '@salesforce/apex/FEC_TemplateController.saveTemplate';
import getAttachments     from '@salesforce/apex/FEC_TemplateController.getAttachments';
import getAllLetterheads   from '@salesforce/apex/FEC_TemplateController.getAllLetterheads';
import getAllFolders       from '@salesforce/apex/FEC_FolderController.getAllFolders';
import createDraftTemplate from '@salesforce/apex/FEC_TemplateController.createDraftTemplate';
import deleteDraftTemplate from '@salesforce/apex/FEC_TemplateController.deleteDraftTemplate';
// tungnm37 thêm: lấy mailbox options từ picklist metadata thay vì hardcode
import getMailboxOptions  from '@salesforce/apex/FEC_TemplateController.getMailboxOptions';

/* ── Custom Labels (i18n) ── */
import FEC_New_Template               from '@salesforce/label/c.FEC_New_Template';
import FEC_Col_Template_Name          from '@salesforce/label/c.FEC_Col_Template_Name';
import FEC_Col_Description            from '@salesforce/label/c.FEC_Col_Description';
import FEC_Col_Folder                 from '@salesforce/label/c.FEC_Col_Folder';
import FEC_Col_Active                 from '@salesforce/label/c.FEC_Col_Active';

import buttonSave                     from '@salesforce/label/c.FEC_Button_Save';
import requireInfoLabel               from '@salesforce/label/c.FEC_Required_Information';
import reviewErrorLabel               from '@salesforce/label/c.FEC_Review_Error';
import completeThisFieldLabel         from '@salesforce/label/c.FEC_Complete_This_Field';

import templateSettingsLabel          from '@salesforce/label/c.FEC_Template_Settings';
import messageContentLabel            from '@salesforce/label/c.FEC_Message_Content';
import subjectLineLabel               from '@salesforce/label/c.FEC_Subject_Line';
import emailBodyInfoLabel             from '@salesforce/label/c.FEC_Template_Email_Body_Info';
import requiredFieldsMsg              from '@salesforce/label/c.FEC_Template_Required_Fields_Msg';
import templateSavedMsg               from '@salesforce/label/c.FEC_Template_Saved_Success';
import editTemplateTitle              from '@salesforce/label/c.FEC_Template_Edit_Title';

import apiNameLabel                   from '@salesforce/label/c.FEC_Template_API_Name';
import letterheadLabel                from '@salesforce/label/c.FEC_Template_Enhanced_Letterhead';
import mailboxLabel                   from '@salesforce/label/c.FEC_Template_Applicable_Mailbox';
import attachmentLabel                from '@salesforce/label/c.FEC_Template_Attachment';
import backToListLabel                from '@salesforce/label/c.FEC_Template_Back_To_List';
import saveAndCloseLabel              from '@salesforce/label/c.FEC_Template_Save_And_Close';
import bodyLabel                      from '@salesforce/label/c.FEC_Template_Body';
import previewLabel                   from '@salesforce/label/c.FEC_Action_Preview';

/* ── Constants & Utils ── */
import { generateApiName, formatFileSize } from 'c/fec_TemplateUtils';

export default class Fec_templateEditor extends LightningElement {

    /* ═══════════════════════════════════════════ */
    /*  PUBLIC API                                 */
    /* ═══════════════════════════════════════════ */

    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value) { this._loadRecord(value); }
    }

    /** Clone data – pre-fill form fields when cloning a template (create mode) */
    @api
    get cloneData() { return this._cloneData; }
    set cloneData(value) {
        this._cloneData = value;
        if (value && !this._recordId) {
            this._applyCloneData(value);
        }
    }
    _cloneData = null;

    /** Default folder ID – pre-fill Folder field when creating a new template */
    @api defaultFolderId = null;

    /* ═══════════════════════════════════════════ */
    /*  TRACKED STATE                              */
    /* ═══════════════════════════════════════════ */

    @track _recordId = null;
    @track hasErrors = false;
    @track errorMessage = '';
    @track _isSaving = false;

    /* Form fields */
    @track name                  = '';
    @track apiName               = '';
    @track description           = '';
    @track subject               = '';
    @track folderId              = '';
    @track enhancedLetterheadId  = '';
    @track applicableMailbox     = [];
    @track isActive              = false;
    @track emailBody             = '';
    @track attachments           = [];     // { id, name, size, type }
    _deletedAttachmentIds        = [];

    /* Merge-field picker */
    @track isPickerOpen = false;

    /* Preview modal */
    @track isPreviewOpen = false;

    /* Cursor position for merge field insert */
    _savedRange = null;

    /* Flag to prevent auto API name overwrite in edit mode */
    _apiNameManuallySet = false;

    /* Store original body for content-history tracking on save */
    _originalBody = '';

    /* Folder options from Apex */
    @track _folderOptions = [];

    /* Letterhead options – placeholder for future EnhancedLetterhead query */
    @track _letterheadOptions = [];

    // tungnm37 thêm: mailbox options từ picklist metadata
    @track _mailboxOptions = [];
    @wire(getMailboxOptions)
    wiredMailboxOptions({ data, error }) {
        if (data) this._mailboxOptions = data;
        else if (error) console.error('[fec_templateEditor] getMailboxOptions error', error);
    }

    /** Raw letterhead records keyed by Id for header/footer lookup */
    _letterheadMap = {};

    /** Draft record Id created on New Template load for file uploads */
    @track _draftId = null;

    /** True while the draft is being initialised — disables file upload */
    @track _isDraftLoading = false;

    /* ═══════════════════════════════════════════ */
    /*  LABELS                                     */
    /* ═══════════════════════════════════════════ */

    label = {
        FEC_New_Template,
        FEC_Col_Template_Name,
        FEC_Col_Description,
        FEC_Col_Folder,
        FEC_Col_Active,
        buttonSave,
        requireInfoLabel,
        reviewErrorLabel,
        completeThisFieldLabel,
        templateSettingsLabel,
        messageContentLabel,
        subjectLineLabel,
        emailBodyInfoLabel,
        requiredFieldsMsg,
        templateSavedMsg,
        editTemplateTitle,
        apiNameLabel,
        letterheadLabel,
        mailboxLabel,
        attachmentLabel,
        backToListLabel,
        saveAndCloseLabel,
        bodyLabel,
        previewLabel
    };

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED PROPERTIES                        */
    /* ═══════════════════════════════════════════ */

    get pageHeading() {
        return this._recordId ? editTemplateTitle : FEC_New_Template;
    }

    get isEditMode() { return !!this._recordId; }

    get isNewMode() { return !this._recordId; }

    /** Record Id used by lightning-file-upload: real Id in edit, draft in new */
    get uploadRecordId() {
        return this._recordId || this._draftId;
    }

    /** File upload is ready when we have a valid record Id to link files to */
    get isUploadReady() {
        return !!this.uploadRecordId;
    }

    get mergeFieldLabel() { return 'Merge Fields { }'; }

    /* ── Wire: load all folders for the dropdown ── */
    connectedCallback() {
        this._loadFolderOptions();
        this._loadLetterheadOptions();
        // Pre-fill folder for new templates (not edit, not clone)
        if (!this._recordId && !this._cloneData && this.defaultFolderId) {
            this.folderId = this.defaultFolderId;
        }
        // Create a draft record for new templates so file upload works immediately
        if (!this._recordId) {
            this._initDraft();
        }
    }

    /**
     * Create a draft FEC_Template__c so that lightning-file-upload
     * has a valid record-id in New mode.
     */
    async _initDraft() {
        this._isDraftLoading = true;
        try {
            this._draftId = await createDraftTemplate();
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[templateEditor] Error creating draft:', error);
        } finally {
            this._isDraftLoading = false;
        }
    }

    async _loadFolderOptions() {
        try {
            const data = await getAllFolders();
            this._folderOptions = (data || [])
                .filter(f => f.Name)
                .map(f => ({
                    label: f.Name,
                    value: f.Id
                }));
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[templateEditor] Error loading folders:', error);
        }
    }

    async _loadLetterheadOptions() {
        try {
            const data = await getAllLetterheads();
            const filtered = (data || []).filter(lh => lh.Name);
            this._letterheadOptions = filtered.map(lh => ({
                label: lh.Name,
                value: lh.Id
            }));
            // Build a map for header/footer lookup in Preview
            this._letterheadMap = {};
            filtered.forEach(lh => {
                this._letterheadMap[lh.Id] = {
                    headerHtml: lh.FEC_Header__c || '',
                    footerHtml: lh.FEC_Footer__c || ''
                };
            });
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[templateEditor] Error loading letterheads:', error);
        }
    }

    get folderOptions() {
        return [
            { label: '-- None --', value: '' },
            ...this._folderOptions
        ];
    }

    get letterheadOptions() {
        return [
            { label: '-- None --', value: '' },
            ...this._letterheadOptions
        ];
    }

    // tungnm37 sửa: lấy từ picklist metadata thay vì hardcode
    get mailboxOptions() { return this._mailboxOptions; }

    /** Comma-separated display of selected mailboxes for the dual listbox */
    get selectedMailboxDisplay() {
        return this.applicableMailbox.join(', ');
    }

    /** Format attachments for display */
    get attachmentList() {
        return this.attachments.map((att) => ({
            ...att,
            sizeDisplay: formatFileSize(att.size),
            iconName: this._getFileIcon(att.type)
        }));
    }

    get hasAttachments() {
        return this.attachments && this.attachments.length > 0;
    }

    /* ═══════════════════════════════════════════ */
    /*  INPUT CHANGE HANDLERS                      */
    /* ═══════════════════════════════════════════ */

    handleNameChange(event) {
        this.name = event.target.value;
        if (this.name) { this.hasErrors = false; }
    }

    /**
     * Auto-generate API name when user tabs out of Template Name,
     * but only if API Name is still empty (not manually set).
     */
    handleNameBlur() {
        if (!this.apiName && this.name) {
            this.apiName = generateApiName(this.name);
        }
    }

    handleApiNameChange(event) {
        this.apiName = event.target.value;
        this._apiNameManuallySet = true;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleFolderChange(event) {
        this.folderId = event.detail.value;
    }

    handleLetterheadChange(event) {
        this.enhancedLetterheadId = event.detail.value;
    }

    handleMailboxChange(event) {
        this.applicableMailbox = event.detail.value;
    }

    handleActiveChange(event) {
        this.isActive = event.target.checked;
    }

    handleBodyChange(event) {
        this.emailBody = event.target.value;
    }

    /* ═══════════════════════════════════════════ */
    /*  ATTACHMENT HANDLERS                        */
    /* ═══════════════════════════════════════════ */

    /**
     * Handle file upload finish.
     * Works in both edit mode (real recordId) and new mode (draftId).
     */
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            /* Reload attachments from server after upload */
            this._loadAttachments(this.uploadRecordId);
        }
    }

    handleRemoveAttachment(event) {
        const attId = event.currentTarget.dataset.id;
        this._deletedAttachmentIds.push(attId);
        this.attachments = this.attachments.filter((a) => a.id !== attId);
    }

    /* ═══════════════════════════════════════════ */
    /*  MERGE FIELD – CURSOR-AWARE INSERT          */
    /* ═══════════════════════════════════════════ */

    openMergePicker() {
        const sel = window.getSelection();
        if (sel && sel.rangeCount > 0) {
            this._savedRange = sel.getRangeAt(0).cloneRange();
        } else {
            this._savedRange = null;
        }
        this.isPickerOpen = true;
    }

    handleMergeFieldInsert(event) {
        const mergeTag = event.detail;
        const editorEl = this.template.querySelector('.body-editor');

        // Nếu không có editor => fallback
        if (!editorEl) {
            this.emailBody = (this.emailBody || '') + mergeTag;
            this._savedRange = null;
            this.handleClosePicker();
            return;
        }

        // Nếu có savedRange nhưng nó nằm ngoài editor => KHÔNG restore selection ngoài editor
        const canUseRange = this._savedRange && this._isRangeInsideRichText(this._savedRange, editorEl);

        if (canUseRange) {
            // Force focus về editor trước khi thao tác selection (giảm rủi ro selection "nhảy")
            editorEl.focus?.();

            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(this._savedRange);

            const textNode = document.createTextNode(mergeTag);
            this._savedRange.deleteContents();
            this._savedRange.insertNode(textNode);

            this._savedRange.setStartAfter(textNode);
            this._savedRange.collapse(true);
            sel.removeAllRanges();
            sel.addRange(this._savedRange);

            // Sync model
            // Nếu editor là textarea/input => value; nếu contenteditable => textContent/innerHTML
            this.emailBody = editorEl.value ?? editorEl.innerHTML ?? this.emailBody;
        } else {
            // Fallback: insert vào cuối body (hoặc append string)
            // Nếu editor là textarea/input:
            if (editorEl.value !== undefined) {
                const start = editorEl.selectionStart ?? editorEl.value.length;
                const end = editorEl.selectionEnd ?? editorEl.value.length;
                const v = editorEl.value;

                editorEl.value = v.slice(0, start) + mergeTag + v.slice(end);
                // put cursor after inserted text
                const pos = start + mergeTag.length;
                editorEl.setSelectionRange?.(pos, pos);

                this.emailBody = editorEl.value;
            } else {
                // Nếu là contenteditable div:
                editorEl.focus?.();
                editorEl.insertAdjacentText('beforeend', mergeTag);
                this.emailBody = editorEl.innerHTML;
            }
        }

        this._savedRange = null;
        this.handleClosePicker();
    }

    _isNodeInsideHostShadow(node, hostEl) {
        if (!node || !hostEl) return false;

        // Nếu node là Text node thì chuyển lên parent
        let cur = (node.nodeType === Node.TEXT_NODE) ? node.parentNode : node;

        // Đi ngược qua các shadow boundary bằng getRootNode().host
        while (cur) {
            if (cur === hostEl) return true; // trường hợp node ở light DOM của host (hiếm)
            const root = cur.getRootNode?.();
            if (!root) return false;

            // Nếu root là ShadowRoot và host khớp => thuộc hostEl
            if (root.host) {
                if (root.host === hostEl) return true;
                cur = root.host; // nhảy lên host để tiếp tục climb
            } else {
                // root không có host => Document
                return false;
            }
        }
        return false;
    }

    _isRangeInsideRichText(range, richTextHostEl) {
        if (!range || !richTextHostEl) return false;
        const container = range.commonAncestorContainer;
        return this._isNodeInsideHostShadow(container, richTextHostEl);
    }
    handleClosePicker() {
        this.isPickerOpen = false;
    }

    /* ═══════════════════════════════════════════ */
    /*  PREVIEW MODAL                              */
    /* ═══════════════════════════════════════════ */

    /** Letterhead header HTML for the currently selected letterhead (or empty) */
    get selectedLetterheadHeaderHtml() {
        const lh = this._letterheadMap[this.enhancedLetterheadId];
        return lh ? lh.headerHtml : '';
    }

    /** Letterhead footer HTML for the currently selected letterhead (or empty) */
    get selectedLetterheadFooterHtml() {
        const lh = this._letterheadMap[this.enhancedLetterheadId];
        return lh ? lh.footerHtml : '';
    }

    handlePreview() {
        this.isPreviewOpen = true;
    }

    handleClosePreview() {
        this.isPreviewOpen = false;
    }

    /* ═══════════════════════════════════════════ */
    /*  SAVE / SAVE & CLOSE / BACK                 */
    /* ═══════════════════════════════════════════ */

    async handleSave() {
        if (!this._validate()) return;
        await this._performSave(false);
    }

    async handleSaveAndClose() {
        if (!this._validate()) return;
        await this._performSave(true);
    }

    /**
     * Cancel / Back to List — clean up draft record + files if in new mode.
     */
    async handleBack() {
        await this._cleanupDraft();
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE HELPERS                            */
    /* ═══════════════════════════════════════════ */

    /**
     * Core save logic – calls Apex saveTemplate, handles response.
     * In new mode the draft record is updated with the real field values
     * (the draftId becomes the permanent Id, keeping uploaded files linked).
     * @param {Boolean} andClose  If true, navigate back to list view after save.
     */
    async _performSave(andClose) {
        this._isSaving = true;
        try {
            const sObj = this._buildSObject();
            const templateJson = JSON.stringify(sObj);
            // Pass null oldBody for new templates (draft→real) to skip content history
            const savedId = await saveTemplate({
                templateJson: templateJson,
                oldBody: this.isNewMode ? null : (this._originalBody || ''),
                deletedAttachmentIds: this._deletedAttachmentIds
            });

            // Draft is now the real record — clear the draft reference
            this._draftId = null;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: templateSavedMsg,
                variant: 'success'
            }));

            if (andClose) {
                /* Save & Close → return to list view */
                this.dispatchEvent(new CustomEvent('saveandclose', { detail: { recordId: savedId } }));
            } else {
                this.dispatchEvent(new CustomEvent('save', { detail: { recordId: savedId } }));
            }
        } catch (error) {
            this.hasErrors = true;
            this.errorMessage = error.body ? error.body.message : error.message;
        } finally {
            this._isSaving = false;
        }
    }

    _validate() {
        let isValid = true;
        const missingFields = [];

        /* Validate Template Name (required) */
        const nameInput = this.template.querySelector('.name-input');
        if (!nameInput || !nameInput.value || nameInput.value.trim() === '') {
            if (nameInput) {
                nameInput.setCustomValidity(completeThisFieldLabel);
                nameInput.reportValidity();
            }
            missingFields.push(FEC_Col_Template_Name);
            isValid = false;
        } else {
            nameInput.setCustomValidity('');
            nameInput.reportValidity();
        }

        /* Validate API Name (required) */
        const apiInput = this.template.querySelector('.api-name-input');
        if (!apiInput || !apiInput.value || apiInput.value.trim() === '') {
            if (apiInput) {
                apiInput.setCustomValidity(completeThisFieldLabel);
                apiInput.reportValidity();
            }
            missingFields.push(apiNameLabel);
            isValid = false;
        } else {
            apiInput.setCustomValidity('');
            apiInput.reportValidity();
        }

        /* Validate Folder (required) – uses searchable combobox @api */
        const folderCmp = this.template.querySelector('.folder-combobox');
        if (!this.folderId) {
            if (folderCmp) {
                folderCmp.setCustomValidity(completeThisFieldLabel);
                folderCmp.reportValidity();
            }
            missingFields.push(FEC_Col_Folder);
            isValid = false;
        } else if (folderCmp) {
            folderCmp.setCustomValidity('');
            folderCmp.reportValidity();
        }

        if (!isValid) {
            this.errorMessage = requiredFieldsMsg.replace('{0}', missingFields.join(', '));
            this.hasErrors = true;
        }

        return isValid;
    }

    /**
     * Build a serialisable FEC_Template__c SObject for Apex.
     * In new mode we set Id = _draftId so Apex performs an UPDATE
     * on the draft record (keeping uploaded files linked).
     */
    _buildSObject() {
        const sObj = {
            Name:                       this.name,
            FEC_API_Name__c:            this.apiName,
            FEC_Description__c:         this.description,
            FEC_Subject_Line__c:        this.subject,
            FEC_Folder__c:              this.folderId || null,
            FEC_Enhanced_Letterhead__c: this.enhancedLetterheadId || null,
            FEC_Applicable_for_Mailbox__c: this.applicableMailbox.join(';'),
            FEC_Active__c:              this.isActive,
            FEC_Body__c:                this.emailBody
        };
        // In edit mode use the real Id; in new mode use the draft Id
        if (this._recordId) {
            sObj.Id = this._recordId;
        } else if (this._draftId) {
            sObj.Id = this._draftId;
        }
        return sObj;
    }

    _resetForm() {
        this._recordId = null;
        this.name = '';
        this.apiName = '';
        this.description = '';
        this.subject = '';
        this.folderId = '';
        this.enhancedLetterheadId = '';
        this.applicableMailbox = [];
        this.isActive = false;
        this.emailBody = '';
        this.attachments = [];
        this._deletedAttachmentIds = [];
        this.hasErrors = false;
        this.errorMessage = '';
        this._apiNameManuallySet = false;
        this._originalBody = '';
        this._draftId = null;
    }

    /**
     * Delete the draft record and its uploaded files.
     * Only fires when in new mode and a draft exists.
     */
    async _cleanupDraft() {
        if (!this._draftId) return;
        try {
            await deleteDraftTemplate({ draftId: this._draftId });
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[templateEditor] Error cleaning up draft:', error);
        } finally {
            this._draftId = null;
        }
    }

    /**
     * Apply clone data to form fields (create mode with pre-filled data).
     */
    _applyCloneData(data) {
        this.name                 = data.name || '';
        this.apiName              = '';
        this.description          = data.description || '';
        this.subject              = data.subject || '';
        this.folderId             = data.folderId || '';
        this.enhancedLetterheadId = data.enhancedLetterheadId || '';
        this.applicableMailbox    = data.applicableMailbox || [];
        this.isActive             = data.isActive !== undefined ? data.isActive : false;
        this.emailBody            = data.emailBody || '';
        this._originalBody        = '';
        this._apiNameManuallySet  = false;
        if (this.name) {
            this.apiName = generateApiName(this.name);
        }
    }

    /**
     * Load an existing template from Apex for edit mode.
     */
    async _loadRecord(templateId) {
        try {
            const rec = await getTemplate({ templateId: templateId });
            if (!rec) return;

            this.name                 = rec.Name || '';
            this.apiName              = rec.FEC_API_Name__c || generateApiName(rec.Name);
            this.description          = rec.FEC_Description__c || '';
            this.subject              = rec.FEC_Subject_Line__c || '';
            this.folderId             = rec.FEC_Folder__c || '';
            this.enhancedLetterheadId = rec.FEC_Enhanced_Letterhead__c || '';
            this.applicableMailbox    = rec.FEC_Applicable_for_Mailbox__c
                ? rec.FEC_Applicable_for_Mailbox__c.split(';')
                : [];
            this.isActive             = rec.FEC_Active__c !== undefined ? rec.FEC_Active__c : true;
            this.emailBody            = rec.FEC_Body__c || '';
            this._originalBody        = rec.FEC_Body__c || '';
            this._apiNameManuallySet  = true;

            /* Load attachments */
            this._loadAttachments(templateId);
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[templateEditor] Error loading record:', error);
        }
    }

    /**
     * Load ContentDocumentLinks for the template.
     */
    async _loadAttachments(templateId) {
        if (!templateId) return;
        try {
            const cdLinks = await getAttachments({ templateId: templateId });
            this.attachments = (cdLinks || []).map(cdl => ({
                id:   cdl.ContentDocumentId,
                name: cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension,
                size: cdl.ContentDocument.ContentSize,
                type: cdl.ContentDocument.FileType
            }));
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[templateEditor] Error loading attachments:', error);
        }
    }

    _getFileIcon(mimeType) {
        if (!mimeType) return 'doctype:unknown';
        const t = (mimeType || '').toLowerCase();
        if (t.includes('pdf')) return 'doctype:pdf';
        if (t.includes('image') || t.includes('png') || t.includes('jpg') || t.includes('jpeg')) return 'doctype:image';
        if (t.includes('word') || t.includes('document') || t.includes('doc')) return 'doctype:word';
        if (t.includes('excel') || t.includes('sheet') || t.includes('xls')) return 'doctype:excel';
        return 'doctype:attachment';
    }
}