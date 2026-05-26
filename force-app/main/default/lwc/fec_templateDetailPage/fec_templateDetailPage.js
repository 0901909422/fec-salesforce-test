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
import previewLabel      from '@salesforce/label/c.FEC_Action_Preview';
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
import templateHistoryTabLabel from '@salesforce/label/c.FEC_Template_History_Tab';
import contentHistoryTabLabel  from '@salesforce/label/c.FEC_Content_History_Tab';

import { formatFileSize } from 'c/fec_TemplateUtils';
import { formatDateTime } from 'c/fec_CommonUtils';

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
        previewLabel,
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
        lastModByLabel,
        templateHistoryTabLabel,
        contentHistoryTabLabel
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

    /* ── Preview modal state ── */
    @track _isPreviewOpen = false;

    /* ── View All flags for history tabs ── */
    @track _showAllTemplateHistory = false;
    @track _showAllContentHistory  = false;

    /** Max rows shown before "View All" is required */
    _HISTORY_PAGE_SIZE = 5;

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
                id:              h.Id,
                date:            formatDateTime(h.FEC_Date__c),
                user:            h.FEC_User__r ? h.FEC_User__r.Name : '',
                userUrl:         h.FEC_User__c ? `/lightning/r/User/${h.FEC_User__c}/view` : null,
                description:     h.FEC_Merge_Fields_Used__c || 'Body content changed',
                mergeFieldsUsed: this._truncate(h.FEC_Merge_Fields_Used__c, 255),
                oldValue:        this._truncate(h.FEC_Original_Value__c, 255),
                newValue:        this._truncate(h.FEC_New_Value__c, 255),
                fullOldValue:    h.FEC_Original_Value__c || '',
                fullNewValue:    h.FEC_New_Value__c || '',
                templateId:      h.FEC_Template__c
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
                date:          formatDateTime(h.CreatedDate),
                field:         h.Field || '',
                user:          h.CreatedBy ? h.CreatedBy.Name : '',
                userUrl:       h.CreatedById ? `/lightning/r/User/${h.CreatedById}/view` : null,
                originalValue: h.OldValue != null ? String(h.OldValue) : '',
                newValue:      h.NewValue != null ? String(h.NewValue) : ''
            }));
        } else {
            this._templateHistory = [];
            // eslint-disable-next-line no-console
            console.error('[templateDetailPage] Error loading template history:', tmplHistResult.reason);
        }

        this._bodyRendered = false;
        this._showAllTemplateHistory = false;
        this._showAllContentHistory  = false;
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

    get isZNSTemplate() {
        return Boolean(this._record?.isZNSTemplate);
    }

    // ─── Content History ─────────────────────────────────

    get contentHistoryData() {
        return this._contentHistory;
    }

    /** Paginated content history: first N rows or all */
    get contentHistoryDisplayData() {
        if (this._showAllContentHistory) return this._contentHistory;
        return this._contentHistory.slice(0, this._HISTORY_PAGE_SIZE);
    }

    /** Show "View All" when there are more rows than the page size */
    get showContentHistoryViewAll() {
        return !this._showAllContentHistory
            && this._contentHistory.length > this._HISTORY_PAGE_SIZE;
    }

    get contentHistoryColumns() {
        return [
            { label: 'Date',              fieldName: 'date',            type: 'text' },
            {
                label: 'User',
                fieldName: 'userUrl',
                type: 'url',
                typeAttributes: { label: { fieldName: 'user' }, target: '_blank' }
            },
            { label: 'Original Value',    fieldName: 'oldValue',        type: 'text', wrapText: true },
            { label: 'New Value',         fieldName: 'newValue',        type: 'text', wrapText: true },
            { label: 'Merge Fields Used', fieldName: 'mergeFieldsUsed', type: 'text', wrapText: true },
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

    /** Paginated template history: first N rows or all */
    get templateHistoryDisplayData() {
        if (this._showAllTemplateHistory) return this._templateHistory;
        return this._templateHistory.slice(0, this._HISTORY_PAGE_SIZE);
    }

    /** Show "View All" when there are more rows than the page size */
    get showTemplateHistoryViewAll() {
        return !this._showAllTemplateHistory
            && this._templateHistory.length > this._HISTORY_PAGE_SIZE;
    }

    get templateHistoryColumns() {
        return [
            { label: 'Date',           fieldName: 'date',          type: 'text' },
            { label: 'Field',          fieldName: 'field',         type: 'text' },
            {
                label: 'User',
                fieldName: 'userUrl',
                type: 'url',
                typeAttributes: { label: { fieldName: 'user' }, target: '_blank' }
            },
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

    handlePreview() {
        if(this.isZNSTemplate) {
            const znsComponent = this.template.querySelector('c-fec_-z-n-s-template-param-mapping');
            if (znsComponent) znsComponent.handleOpenPreview();
        } else {
            this._isPreviewOpen = true;
        }
    }

    handleClosePreview() {
        this._isPreviewOpen = false;
    }

    /**
     * Content History "View Diff" – opens the diff viewer modal.
     */
    handleViewDiff(event) {
        const row = event.detail.row;
        this._diffOldValue    = row.fullOldValue || '';
        this._diffNewValue    = row.fullNewValue || '';
        this._diffChangedBy   = row.user || '';
        this._diffChangedDate = row.date || '';
        this._showDiffViewer  = true;
    }

    handleCloseDiffViewer() {
        this._showDiffViewer = false;
    }

    handleViewAllTemplateHistory() {
        this._showAllTemplateHistory = true;
    }

    handleViewAllContentHistory() {
        this._showAllContentHistory = true;
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE HELPERS                            */
    /* ═══════════════════════════════════════════ */

    /**
     * Map FEC_Template__c SObject to a flat UI-friendly object.
     */
    _mapTemplate(rec) {
        const lh = rec.FEC_Enhanced_Letterhead__r;
        return {
            id:                     rec.Id,
            name:                   rec.Name || '',
            apiName:                rec.FEC_API_Name__c || '',
            description:            rec.FEC_Description__c || '',
            folderName:             rec.FEC_Folder__r ? rec.FEC_Folder__r.Name : '',
            isActive:               rec.FEC_Active__c,
            enhancedLetterheadName: lh ? lh.Name : '',
            letterheadHeaderHtml:   lh ? (lh.FEC_Header__c || '') : '',
            letterheadFooterHtml:   lh ? (lh.FEC_Footer__c || '') : '',
            applicableMailbox:      rec.FEC_Applicable_for_Mailbox__c
                ? rec.FEC_Applicable_for_Mailbox__c.split(';')
                : [],
            subject:                rec.FEC_Subject_Line__c || '',
            emailBody:              rec.FEC_Body__c || '',
            lastModifiedBy:         rec.LastModifiedBy ? rec.LastModifiedBy.Name : '',
            lastModifiedById:       rec.LastModifiedById || '',
            lastModifiedDate:       rec.LastModifiedDate,
            isZNSTemplate:          rec.FEC_Is_ZNS_Template__c,
            previewZNSUrl:          rec.FEC_Preview_ZNS_Url__c,
            templateZNSStatus:      rec.FEC_Template_ZNS_Status__c
        };
    }

    /**
     * Truncate a string to maxLen characters, appending '…' if exceeded.
     * @param {String} value    The source string
     * @param {Number} maxLen   Maximum visible characters (default 255)
     * @returns {String}
     */
    _truncate(value, maxLen = 255) {
        if (!value) return '';
        return value.length > maxLen
            ? value.substring(0, maxLen) + '…'
            : value;
    }
}