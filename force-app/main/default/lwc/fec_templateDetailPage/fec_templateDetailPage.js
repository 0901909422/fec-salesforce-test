/**
 * fec_templateDetailPage
 * Read-only detail view for a single template.
 * Three tabs: Details · Template History · Content History.
 * Uses imperative Apex so parent can trigger refresh via @api refreshData().
 * Body field is rendered as HTML via lwc:dom="manual".
 * Content History "View Diff" opens the fec_contentDiffViewer modal.
 * Apex-backed via FEC_TemplateController.
 */
import { LightningElement, api, track } from 'lwc';

/* ── Apex ── */
import getTemplate        from '@salesforce/apex/FEC_TemplateController.getTemplate';
import getAttachments     from '@salesforce/apex/FEC_TemplateController.getAttachments';
import getContentHistory  from '@salesforce/apex/FEC_TemplateController.getContentHistory';
import getTemplateHistory from '@salesforce/apex/FEC_TemplateController.getTemplateHistory';

// Custom Labels
import detailPageTitle   from '@salesforce/label/c.FEC_Template_Management_Title';
import editLabel         from '@salesforce/label/c.FEC_Action_Edit';
import backToListLabel   from '@salesforce/label/c.FEC_Template_Back_To_List';
import templateNameLabel from '@salesforce/label/c.FEC_Col_Template_Name';
import apiNameLabel      from '@salesforce/label/c.FEC_Template_API_Name';
import folderLabel       from '@salesforce/label/c.FEC_Col_Folder';
import descriptionLabel  from '@salesforce/label/c.FEC_Col_Description';
import activeLabel       from '@salesforce/label/c.FEC_Col_Active';
import letterheadLabel   from '@salesforce/label/c.FEC_Template_Enhanced_Letterhead';
import mailboxLabel      from '@salesforce/label/c.FEC_Template_Applicable_Mailbox';
import attachmentLabel   from '@salesforce/label/c.FEC_Template_Attachment';
import subjectLabel      from '@salesforce/label/c.FEC_Template_Subject';
import emailBodyLabel    from '@salesforce/label/c.FEC_Template_Email_Body';
import lastModLabel      from '@salesforce/label/c.FEC_Col_Last_Modified_Date';
import lastModByLabel    from '@salesforce/label/c.FEC_Col_Last_Modified_By';

import { formatFileSize } from 'c/fec_TemplateUtils';

export default class Fec_templateDetailPage extends LightningElement {

    /** Template record ID passed from the console */
    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        this._bodyRendered = false;
        if (value && this._connected) {
            this._loadAllData(value);
        }
    }
    _recordId = null;

    /** Lifecycle flag – prevents setter-triggered fetch before connectedCallback */
    _connected = false;

    // Labels exposed to template
    label = {
        detailPageTitle,
        editLabel,
        backToListLabel,
        templateNameLabel,
        apiNameLabel,
        folderLabel,
        descriptionLabel,
        activeLabel,
        letterheadLabel,
        mailboxLabel,
        attachmentLabel,
        subjectLabel,
        emailBodyLabel,
        lastModLabel,
        lastModByLabel
    };

    @track activeTab = 'details';
    @track _isLoading = true;

    /* ── Internal data ── */
    @track _record          = null;
    @track _attachments     = [];
    @track _contentHistory  = [];
    @track _templateHistory = [];

    /* ── Body render flag ── */
    _bodyRendered = false;

    /* ── Diff viewer state ── */
    @track _showDiffViewer     = false;
    @track _diffOldValue       = '';
    @track _diffNewValue       = '';
    @track _diffChangedBy      = '';
    @track _diffChangedDate    = '';

    /* ═══════════════════════════════════════════ */
    /*  LIFECYCLE                                  */
    /* ═══════════════════════════════════════════ */

    connectedCallback() {
        this._connected = true;
        if (this._recordId) {
            this._loadAllData(this._recordId);
        }
    }

    renderedCallback() {
        this._renderBodyHtml();
    }

    /* ═══════════════════════════════════════════ */
    /*  PUBLIC API                                 */
    /* ═══════════════════════════════════════════ */

    /** Allow parent to trigger full data refresh */
    @api
    refreshData() {
        if (this._recordId) {
            this._bodyRendered = false;
            return this._loadAllData(this._recordId);
        }
        return Promise.resolve();
    }

    /* ═══════════════════════════════════════════ */
    /*  DATA LOADING (imperative Apex)             */
    /* ═══════════════════════════════════════════ */

    async _loadAllData(templateId) {
        this._isLoading = true;

        // Use Promise.allSettled so one failing call doesn't block the others.
        const [recResult, attsResult, contentHistResult, tmplHistResult] = await Promise.allSettled([
            getTemplate({ templateId }),
            getAttachments({ templateId }),
            getContentHistory({ templateId }),
            getTemplateHistory({ templateId })
        ]);

        // ── Template record ──
        if (recResult.status === 'fulfilled') {
            const rec = recResult.value;
            this._record = rec ? this._mapTemplate(rec) : null;
        } else {
            this._record = null;
            // eslint-disable-next-line no-console
            console.error('[templateDetailPage] Error loading template:', recResult.reason);
        }

        // ── Attachments ──
        if (attsResult.status === 'fulfilled') {
            this._attachments = (attsResult.value || []).map(cdl => ({
                id:          cdl.ContentDocumentId,
                name:        cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension,
                size:        cdl.ContentDocument.ContentSize,
                sizeDisplay: formatFileSize(cdl.ContentDocument.ContentSize)
            }));
        } else {
            this._attachments = [];
            // eslint-disable-next-line no-console
            console.error('[templateDetailPage] Error loading attachments:', attsResult.reason);
        }

        // ── Content History (FEC_Content_History_Tracking__c) ──
        if (contentHistResult.status === 'fulfilled') {
            this._contentHistory = (contentHistResult.value || []).map(h => ({
                id:           h.Id,
                date:         h.FEC_Date__c,
                user:         h.FEC_User__r ? h.FEC_User__r.Name : '',
                description:  h.FEC_Merge_Fields_Used__c || 'Body content changed',
                oldValue:     h.FEC_Original_Value__c || '',
                newValue:     h.FEC_New_Value__c || '',
                templateId:   h.FEC_Template__c
            }));
        } else {
            this._contentHistory = [];
            // eslint-disable-next-line no-console
            console.error('[templateDetailPage] Error loading content history:', contentHistResult.reason);
        }

        // ── Template History (FEC_Template__History) ──
        if (tmplHistResult.status === 'fulfilled') {
            this._templateHistory = (tmplHistResult.value || []).map(h => ({
                id:            h.Id,
                date:          h.CreatedDate,
                field:         h.Field || '',
                user:          h.CreatedBy ? h.CreatedBy.Name : '',
                originalValue: h.OldValue != null ? String(h.OldValue) : '',
                newValue:      h.NewValue != null ? String(h.NewValue) : ''
            }));
        } else {
            this._templateHistory = [];
            // eslint-disable-next-line no-console
            console.error('[templateDetailPage] Error loading template history:', tmplHistResult.reason);
        }

        this._bodyRendered = false;
        this._isLoading = false;
    }

    /* ═══════════════════════════════════════════ */
    /*  BODY HTML RENDERING                        */
    /* ═══════════════════════════════════════════ */

    /**
     * Render the email Body as HTML into the lwc:dom="manual" container.
     * Called in renderedCallback after data loads.
     */
    _renderBodyHtml() {
        if (this._bodyRendered || !this._record) return;
        const container = this.template.querySelector('.td-body-preview');
        if (!container) return;

        container.innerHTML = this._record.emailBody || '<p style="color:#706e6b;">No body content.</p>';
        this._bodyRendered = true;
    }

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED                                   */
    /* ═══════════════════════════════════════════ */

    get record() {
        return this._record;
    }

    get pageTitle() {
        return this._record ? this._record.name : 'Template Detail';
    }

    get folderName() {
        return this._record ? (this._record.folderName || '—') : '—';
    }

    get activeDisplay() {
        return this._record && this._record.isActive ? 'Yes' : 'No';
    }

    get mailboxDisplay() {
        if (!this._record || !this._record.applicableMailbox) return '—';
        return this._record.applicableMailbox.join(', ') || '—';
    }

    get hasAttachments() {
        return this._attachments && this._attachments.length > 0;
    }

    get attachmentList() {
        return this._attachments;
    }

    get letterheadDisplay() {
        return this._record ? (this._record.enhancedLetterheadName || '—') : '—';
    }

    get descriptionDisplay() {
        return this._record ? (this._record.description || '—') : '—';
    }

    get apiNameDisplay() {
        return this._record ? (this._record.apiName || '—') : '—';
    }

    get lastModifiedByDisplay() {
        return this._record ? (this._record.lastModifiedBy || '—') : '—';
    }

    get lastModifiedByUrl() {
        return this._record && this._record.lastModifiedById
            ? `/lightning/r/User/${this._record.lastModifiedById}/view`
            : null;
    }

    get lastModifiedDateDisplay() {
        if (!this._record || !this._record.lastModifiedDate) return '—';
        try {
            return new Date(this._record.lastModifiedDate).toLocaleString();
        } catch (e) {
            return this._record.lastModifiedDate;
        }
    }

    get isLoading() {
        return this._isLoading;
    }

    // ─── Content History ─────────────────────────────────

    get contentHistoryData() {
        return this._contentHistory;
    }

    get contentHistoryColumns() {
        return [
            { label: 'Date',        fieldName: 'date',        type: 'text' },
            { label: 'User',        fieldName: 'user',        type: 'text' },
            { label: 'Description', fieldName: 'description', type: 'text', wrapText: true },
            {
                label: 'Action',
                type: 'button',
                typeAttributes: {
                    label: 'View Diff',
                    name: 'view_diff',
                    variant: 'base'
                }
            }
        ];
    }

    get hasContentHistory() {
        return this._contentHistory && this._contentHistory.length > 0;
    }

    // ─── Template History (FEC_Template__History) ────────

    get templateHistoryData() {
        return this._templateHistory;
    }

    get templateHistoryColumns() {
        return [
            { label: 'Date',           fieldName: 'date',          type: 'text' },
            { label: 'Field',          fieldName: 'field',         type: 'text' },
            { label: 'User',           fieldName: 'user',          type: 'text' },
            { label: 'Original Value', fieldName: 'originalValue', type: 'text' },
            { label: 'New Value',      fieldName: 'newValue',      type: 'text' }
        ];
    }

    get hasTemplateHistory() {
        return this._templateHistory && this._templateHistory.length > 0;
    }

    /* ═══════════════════════════════════════════ */
    /*  HANDLERS                                   */
    /* ═══════════════════════════════════════════ */

    handleTabActive(event) {
        this.activeTab = event.target.value;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleEdit() {
        this.dispatchEvent(new CustomEvent('edit', {
            detail: { recordId: this._recordId }
        }));
    }

    /**
     * Content History "View Diff" – opens the diff viewer modal.
     */
    handleViewDiff(event) {
        const row = event.detail.row;
        this._diffOldValue    = row.oldValue || '';
        this._diffNewValue    = row.newValue || '';
        this._diffChangedBy   = row.user || '';
        this._diffChangedDate = row.date || '';
        this._showDiffViewer  = true;
    }

    handleCloseDiffViewer() {
        this._showDiffViewer = false;
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE HELPERS                            */
    /* ═══════════════════════════════════════════ */

    /**
     * Map FEC_Template__c SObject to a flat UI-friendly object.
     */
    _mapTemplate(rec) {
        return {
            id:                     rec.Id,
            name:                   rec.Name || '',
            apiName:                rec.FEC_API_Name__c || '',
            description:            rec.FEC_Description__c || '',
            folderName:             rec.FEC_Folder__r ? rec.FEC_Folder__r.Name : '',
            isActive:               rec.FEC_Active__c,
            enhancedLetterheadName: rec.FEC_Enhanced_Letterhead__r ? rec.FEC_Enhanced_Letterhead__r.Name : '',
            applicableMailbox:      rec.FEC_Applicable_for_Mailbox__c
                ? rec.FEC_Applicable_for_Mailbox__c.split(';')
                : [],
            subject:                rec.FEC_Subject_Line__c || '',
            emailBody:              rec.FEC_Body__c || '',
            lastModifiedBy:         rec.LastModifiedBy ? rec.LastModifiedBy.Name : '',
            lastModifiedById:       rec.LastModifiedById || '',
            lastModifiedDate:       rec.LastModifiedDate
        };
    }
}