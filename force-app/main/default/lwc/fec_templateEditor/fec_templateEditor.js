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
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/* ── Apex ── */
import getTemplate      from '@salesforce/apex/FEC_TemplateController.getTemplate';
import saveTemplate     from '@salesforce/apex/FEC_TemplateController.saveTemplate';
import getAttachments   from '@salesforce/apex/FEC_TemplateController.getAttachments';
import getAllLetterheads from '@salesforce/apex/FEC_TemplateController.getAllLetterheads';
import getAllFolders     from '@salesforce/apex/FEC_FolderController.getAllFolders';

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
import saveAndNewLabel                from '@salesforce/label/c.FEC_Template_Save_And_New';

/* ── Constants & Utils ── */
import { MAILBOX_OPTIONS } from 'c/fec_TemplateConstants';
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

    /* Merge-field picker */
    @track isPickerOpen = false;

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
        saveAndNewLabel
    };

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED PROPERTIES                        */
    /* ═══════════════════════════════════════════ */

    get pageHeading() {
        return this._recordId ? editTemplateTitle : FEC_New_Template;
    }

    get isEditMode() { return !!this._recordId; }

    get isNewMode() { return !this._recordId; }

    get mergeFieldLabel() { return '{ }'; }

    /* ── Wire: load all folders for the dropdown ── */
    connectedCallback() {
        this._loadFolderOptions();
        this._loadLetterheadOptions();
        // Pre-fill folder for new templates (not edit, not clone)
        if (!this._recordId && !this._cloneData && this.defaultFolderId) {
            this.folderId = this.defaultFolderId;
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
            this._letterheadOptions = (data || [])
                .filter(lh => lh.Name)
                .map(lh => ({
                    label: lh.Name,
                    value: lh.Id
                }));
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

    get mailboxOptions() { return MAILBOX_OPTIONS; }

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
        /* Auto-generate API name from template name (only if not manually overridden) */
        if (!this._apiNameManuallySet) {
            this.apiName = generateApiName(this.name);
        }
        if (this.name) { this.hasErrors = false; }
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
     * Uses lightning-file-upload's onuploadfinished event (only works in edit mode
     * with a real recordId). For new templates, files will be uploaded after save.
     */
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            /* Reload attachments from server after upload */
            this._loadAttachments(this._recordId);
        }
    }

    handleRemoveAttachment(event) {
        const attId = event.currentTarget.dataset.id;
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

        if (this._savedRange) {
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

            const editorEl = this.template.querySelector('.body-editor');
            if (editorEl) { this.emailBody = editorEl.value; }
        } else {
            this.emailBody = (this.emailBody || '') + mergeTag;
        }

        this._savedRange = null;
        this.handleClosePicker();
    }

    handleClosePicker() {
        this.isPickerOpen = false;
    }

    /* ═══════════════════════════════════════════ */
    /*  SAVE / SAVE & NEW / BACK / PREVIEW         */
    /* ═══════════════════════════════════════════ */

    async handleSave() {
        if (!this._validate()) return;
        await this._performSave(false);
    }

    async handleSaveAndNew() {
        if (!this._validate()) return;
        await this._performSave(true);
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE HELPERS                            */
    /* ═══════════════════════════════════════════ */

    /**
     * Core save logic – calls Apex saveTemplate, handles response.
     * @param {Boolean} andNew  If true, reset form after save.
     */
    async _performSave(andNew) {
        this._isSaving = true;
        try {
            const sObj = this._buildSObject();
            const templateJson = JSON.stringify(sObj);
            const savedId = await saveTemplate({
                templateJson: templateJson,
                oldBody: this._originalBody || ''
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: templateSavedMsg,
                variant: 'success'
            }));

            if (andNew) {
                this._resetForm();
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

        /* Validate Template Name (required) */
        const nameInput = this.template.querySelector('.name-input');
        if (!nameInput || !nameInput.value || nameInput.value.trim() === '') {
            if (nameInput) {
                nameInput.setCustomValidity(completeThisFieldLabel);
                nameInput.reportValidity();
            }
            isValid = false;
        } else {
            nameInput.setCustomValidity('');
            nameInput.reportValidity();
        }

        /* Validate Folder (required) */
        if (!this.folderId) {
            isValid = false;
        }

        if (!isValid) {
            this.errorMessage = requiredFieldsMsg;
            this.hasErrors = true;
        }

        return isValid;
    }

    /**
     * Build a serialisable FEC_Template__c SObject for Apex.
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
        if (this._recordId) {
            sObj.Id = this._recordId;
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
        this.hasErrors = false;
        this.errorMessage = '';
        this._apiNameManuallySet = false;
        this._originalBody = '';
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