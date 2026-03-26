/**
 * @description  Template Management Console – root LWC component.
 *               Layout:
 *               ┌─────────────────────────────────────────────────────┐
 *               │  [icon] Email Templates  ·  8 items  [New Folder][New Template] │
 *               ├──────────┬──────────────────────────────────────────┤
 *               │ EMAIL    │  Search ▸ [Folder filter] [Active filter] │
 *               │ TEMPLATES│  ─────────────────────────────────────── │
 *               │  All     │  Datatable rows …                       │
 *               │          │                                         │
 *               │ FOLDERS  │                                         │
 *               │  All     │                                         │
 *               └──────────┴──────────────────────────────────────────┘
 *               Modes: list view | editor | detail page
 *               Apex-backed via child component wire calls.
 * @component    fec_templateManagementConsole
 */
import { LightningElement, track } from 'lwc';

/* ── Apex ── */
import getAllFolders from '@salesforce/apex/FEC_FolderController.getAllFolders';
import getTemplate  from '@salesforce/apex/FEC_TemplateController.getTemplate';

/* ── Custom Labels (i18n) ── */
import FEC_Template_Management_Title from '@salesforce/label/c.FEC_Template_Management_Title';
import FEC_Search_Templates          from '@salesforce/label/c.FEC_Search_Templates';
import FEC_Filter_Active             from '@salesforce/label/c.FEC_Filter_Active';
import FEC_New_Template              from '@salesforce/label/c.FEC_New_Template';
import FEC_New_Folder                from '@salesforce/label/c.FEC_New_Folder';
import FEC_Items_Count               from '@salesforce/label/c.FEC_Items_Count';
import FEC_Item_Count                from '@salesforce/label/c.FEC_Item_Count';
import FEC_Col_Folder                from '@salesforce/label/c.FEC_Col_Folder';

/* ── Constants ── */
import {
    TAB_TEMPLATES,
    TAB_FOLDERS,
    FILTER_ALL,
    ACTIVE_OPTIONS
} from 'c/fec_TemplateConstants';

export default class Fec_templateManagementConsole extends LightningElement {

    /* ── Labels ── */
    label = {
        FEC_Template_Management_Title,
        FEC_Search_Templates,
        FEC_Filter_Active,
        FEC_New_Template,
        FEC_New_Folder,
        FEC_Col_Folder
    };

    /* ── State ── */
    @track selectedFolderId = null;
    @track activeView       = TAB_TEMPLATES;   // 'templates' | 'folders'
    @track searchText       = '';
    @track filterActive     = FILTER_ALL;
    @track filterFolderId   = null;            // Folder filter for templates toolbar

    /** Editor state – shows the template editor instead of the list */
    @track showEditor       = false;
    @track editorRecordId   = null;  // null = New, string = Edit
    @track editorCloneData  = null;  // populated when cloning

    /** Tracks where the edit was initiated from: 'list' | 'detail' */
    _editOrigin = 'list';

    /** Detail page state – shows the template detail page */
    @track showDetail       = false;
    @track detailRecordId   = null;

    /** Folder editor modal state */
    @track showFolderEditor    = false;
    @track folderEditorRecordId = null;

    /* ── Filter options ── */
    activeOptions  = ACTIVE_OPTIONS;

    /* ── Folder options for filter dropdown ── */
    @track _folderOptions = [];

    @track itemCountLabel = '';

    /* ═══════════════════════════════════════════ */
    /*  LIFECYCLE                                  */
    /* ═══════════════════════════════════════════ */

    connectedCallback() {
        this._loadFolderOptions();
    }

    /** Load folder options imperatively (for the filter dropdown) */
    async _loadFolderOptions() {
        try {
            const data = await getAllFolders();
            this._folderOptions = (data || []).map(f => ({
                label: f.Name,
                value: f.Id
            }));
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[console] Error loading folders for filter:', error);
        }
    }

    /** Folder filter dropdown options (with "All Folders" option at top) */
    get folderFilterOptions() {
        return [
            { label: 'All Folders', value: '' },
            ...this._folderOptions
        ];
    }

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED PROPERTIES                        */
    /* ═══════════════════════════════════════════ */

    /** Dynamic page title based on active view */
    get pageTitle() {
        if (this.activeView === TAB_FOLDERS) return 'All Folders';
        return FEC_Template_Management_Title;
    }

    /**
     * Item count shown next to the title.
     * Reads totalCount @api property from the currently-visible child list component.
     */
    // get itemCountLabel() {
    //     let count = 0;
    //     if (this.activeView === TAB_TEMPLATES) {
    //         const listView = this.template.querySelector('c-fec_template-list-view');
    //         count = listView ? listView.totalCount : 0;
    //     }
    //     if (this.activeView === TAB_FOLDERS) {
    //         const listView = this.template.querySelector('c-fec_folder-list-view');
    //         count = listView ? listView.totalCount : 0;
    //     }
    //     const suffix = count === 1 ? FEC_Item_Count : FEC_Items_Count;
    //     return `\u00B7 ${count} ${suffix}`;
    // }

    /** View-switcher booleans */
    get isTemplatesView() { return this.activeView === TAB_TEMPLATES; }
    get isFoldersView()   { return this.activeView === TAB_FOLDERS; }

    /** Show the main list view (hide when editor or detail is open) */
    get showListView() { return !this.showEditor && !this.showDetail; }

    /** Current folder context – used to pre-fill Folder field in editor */
    get currentFolderId() {
        return this.selectedFolderId || this.filterFolderId || null;
    }

    /* ═══════════════════════════════════════════ */
    /*  EVENT HANDLERS                             */
    /* ═══════════════════════════════════════════ */

    /** Sidebar view change (All Templates / All Folders) */
    handleViewChange(event) {
        this.activeView       = event.detail.view;
        this.selectedFolderId = null;
        this.searchText       = '';
        this.filterFolderId   = null;
    }

    /** Search input */
    handleSearchChange(event) {
        this.searchText = event.target.value;
    }

    /** Active filter */
    handleActiveChange(event) { this.filterActive = event.detail.value; }

    /** Folder filter */
    handleFolderFilterChange(event) {
        this.filterFolderId = event.detail.value || null;
    }

    /** New Template button → open editor in create mode */
    handleNewTemplate() {
        this.editorRecordId = null;
        this.editorCloneData = null;
        this._editOrigin = 'list';
        this.showEditor = true;
    }

    /** New Folder button → open folder editor modal */
    handleNewFolder() {
        this.folderEditorRecordId = null;
        this.showFolderEditor = true;
    }

    /** Edit Template from list view row action */
    handleEditTemplate(event) {
        this.editorRecordId = event.detail.recordId;
        this.editorCloneData = null;
        this._editOrigin = 'list';
        this.showEditor = true;
    }

     /** Edit Template from list view row action */
    handleClickFolder(event) {
        this.selectedFolderId = event.detail?.recordId;
    }

    /** View Template detail from list view (click on template name) */
    handleViewTemplate(event) {
        this.detailRecordId = event.detail.recordId;
        this.showDetail = true;
    }

    /**
     * Clone Template from list view row action.
     * Loads the source template, then opens the editor in create mode
     * with pre-filled data and "Copy of …" name.
     */
    async handleCloneTemplate(event) {
        try {
            const sourceId = event.detail.recordId;
            const rec = await getTemplate({ templateId: sourceId });
            if (!rec) return;

            this.editorCloneData = {
                name:                 'Copy of ' + (rec.Name || ''),
                description:          rec.FEC_Description__c || '',
                subject:              rec.FEC_Subject_Line__c || '',
                folderId:             rec.FEC_Folder__c || '',
                enhancedLetterheadId: rec.FEC_Enhanced_Letterhead__c || '',
                applicableMailbox:    rec.FEC_Applicable_for_Mailbox__c
                    ? rec.FEC_Applicable_for_Mailbox__c.split(';')
                    : [],
                isActive:             rec.FEC_Active__c !== undefined ? rec.FEC_Active__c : true,
                emailBody:            rec.FEC_Body__c || ''
            };
            this.editorRecordId = null;   // create mode (no Id)
            this.showEditor = true;
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[console] Error cloning template:', error);
        }
    }

    /** Edit Folder from folder list view row action */
    handleEditFolder(event) {
        this.folderEditorRecordId = event.detail.recordId;
        this.showFolderEditor = true;
    }

    /**
     * Editor save handler.
     * - Create (new template) → always navigate to the detail page of the new record.
     * - Edit from detail page → navigate back to detail page (refresh).
     * - Edit from list view   → return to list view (refresh).
     */
    handleEditorSave(event) {
        const savedId = event.detail ? event.detail.recordId : null;
        const wasCreate = !this.editorRecordId; // editorRecordId was null → create mode

        this.showEditor = false;
        this.editorRecordId = null;
        this.editorCloneData = null;

        if (wasCreate && savedId) {
            // Create → always go to detail page of the new record
            this.detailRecordId = savedId;
            this.showDetail = true;
        } else if (this._editOrigin === 'detail' && savedId) {
            // Edit from detail → go back to detail page (refresh)
            this.detailRecordId = savedId;
            this.showDetail = true;
        } else {
            // Edit from list → stay on list view
            this._refreshAllViews();
        }

        this._editOrigin = 'list';
    }

    /** Editor cancel / back → close editor, return to previous view */
    handleEditorCancel() {
        const origin = this._editOrigin;
        const returnToId = this.editorRecordId;

        this.showEditor = false;
        this.editorRecordId = null;
        this.editorCloneData = null;
        this._editOrigin = 'list';

        // If cancelled from detail edit, go back to detail page
        if (origin === 'detail' && returnToId) {
            this.detailRecordId = returnToId;
            this.showDetail = true;
        }
    }

    /** Detail page back → return to list */
    handleDetailBack() {
        this.showDetail = false;
        this.detailRecordId = null;
    }

    /** Detail page → open editor for this template */
    handleDetailEdit(event) {
        this.showDetail = false;
        this.detailRecordId = null;
        this.editorRecordId = event.detail.recordId;
        this.editorCloneData = null;
        this._editOrigin = 'detail';
        this.showEditor = true;
    }

    /** Folder editor save / cancel */
    handleFolderEditorSave() {
        this.showFolderEditor = false;
        this.folderEditorRecordId = null;
        this._refreshAllViews();
    }
    handleFolderEditorCancel() {
        this.showFolderEditor = false;
        this.folderEditorRecordId = null;
    }

    handleOnLoadData(event) {
        const count = event.detail?.itemCountLabel;
        const suffix = count <= 1 ? FEC_Item_Count : FEC_Items_Count;
        this.itemCountLabel = `\u00B7 ${count} ${suffix}`;
        this.selectedFolderId = event.detail?.currentFolderId;
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE HELPERS                            */
    /* ═══════════════════════════════════════════ */

    /**
     * Refresh ALL list views (both templates and folders).
     * Called after any save/delete operation since changes may affect both views.
     */
    _refreshAllViews() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const templateList = this.template.querySelector('c-fec_template-list-view');
            if (templateList) templateList.refreshData();

            const folderList = this.template.querySelector('c-fec_folder-list-view');
            if (folderList) folderList.refreshData();
        }, 0);

        // Also refresh folder filter dropdown
        this._loadFolderOptions();
    }
}