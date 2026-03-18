/**
 * @description  Template List View – renders a datatable of template records.
 *               Columns: Template Name (clickable link), Description, Folder,
 *               Last Modified By, Last Modified Date.
 *               Clicking the template name opens the detail page.
 *               Row actions: Edit, Clone, Delete.
 *               Apex-backed via FEC_TemplateController.getTemplates (imperative).
 * @component    fec_templateListView
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/* ── Apex ── */
import getTemplates    from '@salesforce/apex/FEC_TemplateController.getTemplates';
import deleteTemplate  from '@salesforce/apex/FEC_TemplateController.deleteTemplate';

/* ── Custom Labels (i18n) ── */
import FEC_Col_Template_Name      from '@salesforce/label/c.FEC_Col_Template_Name';
import FEC_Col_Description        from '@salesforce/label/c.FEC_Col_Description';
import FEC_Col_Folder             from '@salesforce/label/c.FEC_Col_Folder';
import FEC_Col_Last_Modified_By   from '@salesforce/label/c.FEC_Col_Last_Modified_By';
import FEC_Col_Last_Modified_Date from '@salesforce/label/c.FEC_Col_Last_Modified_Date';
import FEC_No_Templates_Found     from '@salesforce/label/c.FEC_No_Templates_Found';
import FEC_Action_Edit            from '@salesforce/label/c.FEC_Action_Edit';
import FEC_Action_Clone           from '@salesforce/label/c.FEC_Action_Clone';
import FEC_Action_Delete          from '@salesforce/label/c.FEC_Action_Delete';

/* ── Constants ── */
import {
    ACTION_EDIT,
    ACTION_CLONE,
    ACTION_DELETE
} from 'c/fec_TemplateConstants';

export default class Fec_templateListView extends LightningElement {

    /* ── Public API (set by parent console) ── */
    _selectedFolderId = null;
    _searchText       = '';
    _filterActive     = 'All';

    @api
    get selectedFolderId() { return this._selectedFolderId; }
    set selectedFolderId(value) {
        this._selectedFolderId = value;
        if (this._connected) this._fetchTemplates();
    }

    @api
    get searchText() { return this._searchText; }
    set searchText(value) {
        this._searchText = value;
        if (this._connected) this._debouncedFetch();
    }

    @api
    get filterActive() { return this._filterActive; }
    set filterActive(value) {
        this._filterActive = value;
        if (this._connected) this._fetchTemplates();
    }

    /** Labels exposed to template */
    label = {
        FEC_No_Templates_Found
    };

    /* ── Tracked state ── */
    @track _templates = [];
    @track _isLoading = true;
    @track _error     = null;

    /** Lifecycle flag – prevents setter-triggered fetch before connectedCallback */
    _connected = false;

    /** Debounce timer for search */
    _debounceTimer;

    /** Row-level actions (Edit/Clone temporarily removed) */
    rowActions = [
        { label: FEC_Action_Delete,  name: ACTION_DELETE }
    ];

    /* ═══════════════════════════════════════════ */
    /*  LIFECYCLE                                  */
    /* ═══════════════════════════════════════════ */

    connectedCallback() {
        this._connected = true;
        this._fetchTemplates();
    }

    /* ═══════════════════════════════════════════ */
    /*  DATA FETCHING (imperative Apex)            */
    /* ═══════════════════════════════════════════ */

    /** Derive activeOnly boolean from filterActive string */
    _resolveActiveOnly() {
        if (this._filterActive === 'Yes') return true;
        if (this._filterActive === 'No')  return false;
        return null; // 'All' → no filter
    }

    /** Debounced fetch – used for search text changes */
    _debouncedFetch() {
        clearTimeout(this._debounceTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._debounceTimer = setTimeout(() => {
            this._fetchTemplates();
        }, 300);
    }

    /** Fetch templates from Apex */
    async _fetchTemplates() {
        this._isLoading = true;
        try {
            const data = await getTemplates({
                folderId:   this._selectedFolderId || null,
                searchText: this._searchText || '',
                activeOnly: this._resolveActiveOnly()
            });
            this._templates = (data || []).map(rec => this._mapSObjectToRow(rec));
            this._error = null;
        } catch (error) {
            this._error = error;
            this._templates = [];
            // eslint-disable-next-line no-console
            console.error('[templateListView] Error fetching templates:', error);
        } finally {
            this._isLoading = false;
        }
    }

    /** Expose a public method so parent can trigger a data refresh */
    @api
    refreshData() {
        return this._fetchTemplates();
    }

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED                                   */
    /* ═══════════════════════════════════════════ */

    /**
     * Column definitions – Template Name is a clickable button (url-like)
     * that navigates to the detail page.
     */
    get columns() {
        return [
            {
                label: FEC_Col_Template_Name,
                fieldName: 'name',
                type: 'button',
                sortable: true,
                wrapText: true,
                typeAttributes: {
                    label: { fieldName: 'name' },
                    variant: 'base',
                    name: 'view_detail'
                }
            },
            { label: FEC_Col_Description,        fieldName: 'description',       type: 'text',  sortable: false, wrapText: true },
            { label: FEC_Col_Folder,             fieldName: 'folderName',        type: 'text',  sortable: true, wrapText: true },
            { label: FEC_Col_Last_Modified_By,   fieldName: 'lastModifiedBy',    type: 'text',  sortable: true, wrapText: true },
            { label: FEC_Col_Last_Modified_Date,  fieldName: 'lastModifiedDate', type: 'date',  sortable: true,
                typeAttributes: {
                    year: 'numeric', month: '2-digit', day: '2-digit',
                    hour: '2-digit', minute: '2-digit'
                }
            },
            { type: 'action', typeAttributes: { rowActions: this.rowActions } }
        ];
    }

    /** Data for the datatable – mapped from Apex result */
    get filteredTemplates() {
        return this._templates;
    }

    /** Total count – exposed for parent to read */
    @api
    get totalCount() {
        return this._templates ? this._templates.length : 0;
    }

    /** Show/hide empty-state illustration */
    get hasTemplates() {
        return this._templates && this._templates.length > 0;
    }

    get isLoading() {
        return this._isLoading;
    }

    /* ═══════════════════════════════════════════ */
    /*  ROW ACTION HANDLER                         */
    /* ═══════════════════════════════════════════ */

    /**
     * Row action handler.
     * "edit"        → dispatch edittemplate event to parent console.
     * "view_detail" → dispatch viewtemplate event.
     * "clone"       → dispatch clonetemplate event.
     * "delete"      → confirm, call Apex deleteTemplate, refresh.
     */
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_detail') {
            this.dispatchEvent(new CustomEvent('viewtemplate', {
                detail: { recordId: row.id }
            }));
            return;
        }

        if (actionName === ACTION_EDIT) {
            this.dispatchEvent(new CustomEvent('edittemplate', {
                detail: { recordId: row.id }
            }));
            return;
        }

        if (actionName === ACTION_CLONE) {
            this.dispatchEvent(new CustomEvent('clonetemplate', {
                detail: { recordId: row.id }
            }));
            return;
        }

        if (actionName === ACTION_DELETE) {
            this._handleDelete(row);
            return;
        }
    }

    /* ═══════════════════════════════════════════ */
    /*  DELETE                                     */
    /* ═══════════════════════════════════════════ */

    /**
     * Confirm and delete a template row.
     */
    async _handleDelete(row) {
        // eslint-disable-next-line no-alert
        const confirmed = confirm(`Are you sure you want to delete template "${row.name}"?`);
        if (!confirmed) return;

        this._isLoading = true;
        try {
            await deleteTemplate({ templateId: row.id });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `Template "${row.name}" deleted.`,
                variant: 'success'
            }));
            await this._fetchTemplates();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
            this._isLoading = false;
        }
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE: SObject → datatable row mapping   */
    /* ═══════════════════════════════════════════ */

    /**
     * Map a FEC_Template__c SObject to a flat datatable row.
     */
    _mapSObjectToRow(rec) {
        return {
            id:               rec.Id,
            name:             rec.FEC_Template_Name__c || '',
            description:      rec.FEC_Description__c || '',
            folderName:       rec.FEC_Folder__r ? rec.FEC_Folder__r.FEC_Folder_Label__c : '',
            lastModifiedBy:   rec.LastModifiedBy ? rec.LastModifiedBy.Name : '',
            lastModifiedDate: rec.LastModifiedDate
        };
    }
}