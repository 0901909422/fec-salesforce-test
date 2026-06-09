/**
 * @description  Folder List View – displays folder contents (sub-folders + templates)
 *               in a datatable, matching the Salesforce standard folder drill-down pattern.
 *               - Root view shows top-level folders only.
 *               - Clicking a folder name drills into it; clicking a template name opens detail.
 *               - Folder rows display a folder icon before the Name.
 *               - Columns: Name (clickable), Description, Folder, Last Modified By, Last Modified Date.
 *               - Row actions: Open (folder), Edit, Delete.
 *               Apex-backed via FEC_FolderController + FEC_TemplateController.
 * @component    fec_folderListView
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/* ── Apex ── */
import getTopLevelFolders from '@salesforce/apex/FEC_FolderController.getTopLevelFolders';
import getFolderContents  from '@salesforce/apex/FEC_FolderController.getFolderContents';
import getFolder          from '@salesforce/apex/FEC_FolderController.getFolder';
import deleteFolder       from '@salesforce/apex/FEC_FolderController.deleteFolder';
import deleteTemplate     from '@salesforce/apex/FEC_TemplateController.deleteTemplate';

/* ── Custom Labels (i18n) ── */
import FEC_Col_Folder_Name        from '@salesforce/label/c.FEC_Col_Folder_Name';
import FEC_Col_Description        from '@salesforce/label/c.FEC_Col_Description';
import FEC_Col_Folder             from '@salesforce/label/c.FEC_Col_Folder';
import FEC_Col_Last_Modified_By   from '@salesforce/label/c.FEC_Col_Last_Modified_By';
import FEC_Col_Last_Modified_Date from '@salesforce/label/c.FEC_Col_Last_Modified_Date';
import FEC_No_Folders_Found       from '@salesforce/label/c.FEC_No_Folders_Found';
import FEC_Action_Edit            from '@salesforce/label/c.FEC_Action_Edit';
import FEC_Action_Delete          from '@salesforce/label/c.FEC_Action_Delete';

/* ── Constants ── */
import { ACTION_EDIT, ACTION_DELETE } from 'c/fec_TemplateConstants';

/** Row type identifier for distinguishing folder vs template rows */
const ROW_TYPE_FOLDER   = 'folder';
const ROW_TYPE_TEMPLATE = 'template';

/** Open action name (used for folder drill-down) */
const ACTION_OPEN = 'open';

export default class Fec_folderListView extends LightningElement {

    /** Search text from parent console */
    @api searchText = '';

    /** Labels exposed to template */
    label = {
        FEC_No_Folders_Found
    };

    /** Current parent folder id – null = root level (show top-level folders) */
    @track currentFolderId = null;

    /** Breadcrumb path for folder drill-down navigation */
    @track breadcrumbs = [];

    /** Internal data state */
    @track _rows     = [];
    @track _isLoading = true;
    @track _error     = null;

    /** Sort state */
    @track sortedBy        = 'displayName';
    @track sortedDirection = 'asc';

    @track isDeleteModalOpen = false;
    @track currentSelectedId = '';
    @track currentSelectedName = '';
    @track currentSelectedRowType = '';

    /** Cache folder names for breadcrumb lookups */
    _folderNameCache = {};

    /* ═══════════════════════════════════════════ */
    /*  LIFECYCLE                                  */
    /* ═══════════════════════════════════════════ */

    connectedCallback() {
        this._loadData();
    }

    /* ═══════════════════════════════════════════ */
    /*  PUBLIC API                                 */
    /* ═══════════════════════════════════════════ */

    /** Expose total count for parent to read */
    @api
    get totalCount() {
        return this._rows ? this._rows.length : 0;
    }

    /** Allow parent to trigger data refresh */
    @api
    refreshData() {
        return this._loadData();
    }

    /**
     * Navigate directly into a specific folder (called by parent).
     * Builds the ancestor breadcrumb path by walking up FEC_Parent_Folder__c,
     * then loads the folder contents — exactly as if the user had clicked through.
     * @param {String} folderId  The target folder Id to drill into.
     */
    @api
    async navigateToFolder(folderId) {
        if (!folderId) return;
        try {
            /* Build ancestor chain by walking up parent references */
            const ancestors = [];
            let currentId = folderId;
            let folderRec = await getFolder({ folderId: currentId });

            /* Cache the target folder name */
            if (folderRec) {
                this._folderNameCache[folderRec.Id] = folderRec.Name;
            }

            /* Walk up the parent chain to build breadcrumbs */
            while (folderRec && folderRec.FEC_Parent_Folder__c) {
                const parentId = folderRec.FEC_Parent_Folder__c;
                const parentName = folderRec.FEC_Parent_Folder__r
                    ? folderRec.FEC_Parent_Folder__r.Name
                    : '';
                ancestors.unshift({ id: parentId, name: parentName });
                this._folderNameCache[parentId] = parentName;
                // Move up one level
                folderRec = await getFolder({ folderId: parentId });
            }

            /* Set state and load data */
            this.breadcrumbs = ancestors;
            this.currentFolderId = folderId;
            await this._loadData();
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[folderListView] Error navigating to folder:', error);
        }
    }

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED                                   */
    /* ═══════════════════════════════════════════ */

    /**
     * Column definitions.
     * Name column is a clickable button – folders drill-down, templates open detail.
     * Actions are dynamic per row.
     */
    get columns() {
        return [
            {
                label: FEC_Col_Folder_Name,
                fieldName: 'displayName',
                type: 'button',
                sortable: true,
                wrapText: true,
                typeAttributes: {
                    label: { fieldName: 'displayName' },
                    variant: 'base',
                    name: 'name_click'
                }
            },
            // { label: FEC_Col_Description,        fieldName: 'description',      type: 'text', sortable: false, wrapText: true },
            // { label: FEC_Col_Folder,             fieldName: 'folderName',       type: 'text', sortable: true,  wrapText: true },
            {
                label: FEC_Col_Last_Modified_By,
                fieldName: 'userUrl', // This points to the URL string
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'lastModifiedBy' }, // This displays the actual Name
                    target: '_blank'
                },
                sortable: true,  wrapText: true
            },
            // { label: FEC_Col_Last_Modified_By,   fieldName: 'lastModifiedBy',   type: 'text', sortable: true,  wrapText: true },
            { label: FEC_Col_Last_Modified_Date,  fieldName: 'lastModifiedDate', type: 'date', sortable: true,
                typeAttributes: {
                    year: 'numeric', month: '2-digit', day: '2-digit',
                    hour: '2-digit', minute: '2-digit'
                }
            },
            {
                type: 'action',
                typeAttributes: { rowActions: { fieldName: 'availableActions' } }
            }
        ];
    }

    /**
     * Build the rows for the datatable, applying client-side search filter.
     */
    get folderData() {
        const search = (this.searchText || '').toLowerCase().trim();
        if (!search) return this._rows;
        return this._rows.filter(
            row => row.displayName.toLowerCase().includes(search) ||
                   (row.description || '').toLowerCase().includes(search)
        );
    }

    /** Show/hide empty-state */
    get hasItems() {
        return this.folderData && this.folderData.length > 0;
    }

    /** Is the user inside a folder (show breadcrumb "Back" button) */
    get isInsideFolder() {
        return this.currentFolderId !== null;
    }

    /** Current folder name for the breadcrumb header */
    get currentFolderName() {
        if (!this.currentFolderId) return '';
        return this._folderNameCache[this.currentFolderId] || '';
    }

    get isLoading() {
        return this._isLoading;
    }

    /* ═══════════════════════════════════════════ */
    /*  DATA LOADING                               */
    /* ═══════════════════════════════════════════ */

    /**
     * Load data from Apex based on current folder context.
     * - Root → getTopLevelFolders()
     * - Inside a folder → getFolderContents(parentFolderId)
     */
    async _loadData() {
        this._isLoading = true;
        this._error = null;

        try {
            if (!this.currentFolderId) {
                /* Root level – show only top-level folders */
                const folders = await getTopLevelFolders();
                this._rows = this._mapFolderRows(folders);
                /* Cache folder names */
                folders.forEach(f => {
                    this._folderNameCache[f.Id] = f.Name;
                });

                // Dispatch event to parent
                this.dispatchEvent(new CustomEvent('loaddata', {
                    detail: { itemCountLabel: folders?.length }
                }));
            } else {
                /* Inside a folder – show sub-folders + templates */
                const result = await getFolderContents({ parentFolderId: this.currentFolderId });
                const childFolders  = result.folders  || [];
                const childTemplates = result.templates || [];

                /* Cache folder names */
                childFolders.forEach(f => {
                    this._folderNameCache[f.Id] = f.Name;
                });

                const folderRows   = this._mapFolderRows(childFolders);
                const templateRows = this._mapTemplateRows(childTemplates);
                this._rows = [...folderRows, ...templateRows];
                // Dispatch event to parent
                this.dispatchEvent(new CustomEvent('loaddata', {
                    detail: { itemCountLabel: this._rows?.length, currentFolderId: this.currentFolderId }
                }));
            }
        } catch (error) {
            this._error = error;
            this._rows = [];
            // eslint-disable-next-line no-console
            console.error('[folderListView] Error loading data:', error);
        } finally {
            this._isLoading = false;
        }
    }

    /* ═══════════════════════════════════════════ */
    /*  EVENT HANDLERS                             */
    /* ═══════════════════════════════════════════ */

    /**
     * Row action handler.
     * "name_click" → folder drill-down or template detail.
     * "open"       → folder drill-down (from actions menu).
     * "edit"       → dispatch edit event to parent.
     * "delete"     → confirm → Apex delete → refresh.
     */
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        /* ── Name click or Open → navigate ── */
        if (actionName === 'name_click' || actionName === ACTION_OPEN) {
            if (row.rowType === ROW_TYPE_FOLDER) {
                this._drillInto(row.id);
            } else if (row.rowType === ROW_TYPE_TEMPLATE) {
                this.dispatchEvent(new CustomEvent('viewtemplate', {
                    detail: { recordId: row.id }
                }));
            }

            if (row.rowType == 'folder') {
                this.dispatchEvent(new CustomEvent('clickfolder', {
                    detail: { recordId: row.id }
                }));
            }
            return;
        }

        /* ── Edit ── */
        if (actionName === ACTION_EDIT) {
            if (row.rowType === ROW_TYPE_FOLDER) {
                this.dispatchEvent(new CustomEvent('editfolder', {
                    detail: { recordId: row.id }
                }));
            } else if (row.rowType === ROW_TYPE_TEMPLATE) {
                this.dispatchEvent(new CustomEvent('edittemplate', {
                    detail: { recordId: row.id }
                }));
            }
            return;
        }

        /* ── Delete ── */
        if (actionName === ACTION_DELETE) {
            // this._handleDelete(row);
            this.currentSelectedName = row.label;
            this.currentSelectedId = row.id;
            this.currentSelectedRowType = row.rowType;
            this.isDeleteModalOpen = true;
            
            return;
        }
    }

    /**
     * Navigate back one level in the folder hierarchy.
     */
    handleBackClick() {
        if (this.breadcrumbs.length > 0) {
            const prev = this.breadcrumbs[this.breadcrumbs.length - 1];
            this.breadcrumbs = this.breadcrumbs.slice(0, -1);
            this.currentFolderId = prev.id;
        } else {
            this.currentFolderId = null;
        }
        this._loadData();
    }

    /**
     * Handle breadcrumb navigation – jump to a specific level.
     */
    handleBreadcrumbClick(event) {
        event.preventDefault();
        const targetId = event.currentTarget.dataset.id;

        if (targetId === 'root') {
            this.currentFolderId = null;
            this.breadcrumbs = [];
        } else {
            const idx = this.breadcrumbs.findIndex((b) => b.id === targetId);
            if (idx >= 0) {
                this.currentFolderId = targetId;
                this.breadcrumbs = this.breadcrumbs.slice(0, idx);
            }
        }
        this._loadData();
    }

    /**
     * Sort handler – sorts data client-side for all sortable columns.
     * For the "userUrl" column (Last Modified By rendered as url type),
     * sort by the underlying "lastModifiedBy" text value.
     */
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy        = fieldName;
        this.sortedDirection = sortDirection;
        // "userUrl" column displays lastModifiedBy text – sort by that instead
        const sortField = fieldName === 'userUrl' ? 'lastModifiedBy' : fieldName;
        this._rows = this._sortData(this._rows, sortField, sortDirection);
    }

    /**
     * Generic client-side sort utility.
     * Handles string, date, and null/undefined values.
     */
    _sortData(data, fieldName, direction) {
        const cloned = [...data];
        const reverse = direction === 'desc' ? -1 : 1;
        cloned.sort((a, b) => {
            let valA = a[fieldName];
            let valB = b[fieldName];
            // Nulls / undefined always sort to bottom
            if (valA == null && valB == null) return 0;
            if (valA == null) return 1;
            if (valB == null) return -1;
            // String comparison (case-insensitive)
            if (typeof valA === 'string') valA = valA.toLowerCase();
            if (typeof valB === 'string') valB = valB.toLowerCase();
            if (valA < valB) return -1 * reverse;
            if (valA > valB) return  1 * reverse;
            return 0;
        });
        return cloned;
    }

    /* ═══════════════════════════════════════════ */
    /*  DELETE                                     */
    /* ═══════════════════════════════════════════ */

    /**
     * Confirm and delete a folder or template row.
     */
    async _handleDelete(row) {
        const typeName = row.rowType === ROW_TYPE_FOLDER ? 'folder' : 'template';
        // eslint-disable-next-line no-alert
        const confirmed = confirm(`Are you sure you want to delete this ${typeName} "${row.displayName}"?`);
        if (!confirmed) return;

        this._isLoading = true;
        try {
            if (row.rowType === ROW_TYPE_FOLDER) {
                await deleteFolder({ folderId: row.id });
            } else {
                await deleteTemplate({ templateId: row.id });
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `${typeName.charAt(0).toUpperCase() + typeName.slice(1)} deleted successfully.`,
                variant: 'success'
            }));
            await this._loadData();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
            this._isLoading = false;
        }
    }

    handleModalClose() {
        this.isDeleteModalOpen = false;
        this.currentSelectedName = '';
        this.currentSelectedId = '';
        this.currentSelectedRowType = '';
    }

    async handleDeleteSuccess(event) {
        this.handleModalClose();
        await this._loadData();
    }

    /* ═══════════════════════════════════════════ */
    /*  PRIVATE HELPERS                            */
    /* ═══════════════════════════════════════════ */

    /**
     * Drill into a folder: push current to breadcrumbs, set new current.
     */
    _drillInto(folderId) {
        if (this.currentFolderId) {
            this.breadcrumbs = [
                ...this.breadcrumbs,
                { id: this.currentFolderId, name: this._folderNameCache[this.currentFolderId] || '' }
            ];
        }
        this.currentFolderId = folderId;
        this._loadData();
    }

    /** Folder row actions include "Open" for drill-down */
    get _folderActions() {
        return [
            { label: FEC_Action_Edit,    name: ACTION_EDIT },
            { label: FEC_Action_Delete,  name: ACTION_DELETE }
        ];
    }

    /** Template row actions */
    get _templateActions() {
        return [
            { label: FEC_Action_Edit,    name: ACTION_EDIT },
            { label: FEC_Action_Delete,  name: ACTION_DELETE }
        ];
    }

    /**
     * Map FEC_Folder__c SObjects to datatable rows.
     */
    _mapFolderRows(folders) {
        return (folders || []).map(f => ({
            id:               f.Id,
            rowType:          ROW_TYPE_FOLDER,
            displayName:      `📁  ${f.Name || ''}`,
            label:      `${f.Name || ''}`,
            description:      '',
            folderName:       f.FEC_Parent_Folder__r ? f.FEC_Parent_Folder__r.Name : '',
            userUrl:          f.LastModifiedBy ? `/lightning/r/User/${f.LastModifiedBy.Id}/view` : '',
            lastModifiedBy:   f.LastModifiedBy ? f.LastModifiedBy.Name : '',
            lastModifiedDate: f.LastModifiedDate,
            availableActions: this._folderActions
        }));
    }

    /**
     * Map FEC_Template__c SObjects to datatable rows.
     */
    _mapTemplateRows(templates) {
        return (templates || []).map(t => ({
            id:               t.Id,
            rowType:          ROW_TYPE_TEMPLATE,
            displayName:      t.Name || '',
            label:            t.Name || '',
            description:      t.FEC_Description__c || '',
            folderName:       t.FEC_Folder__r ? t.FEC_Folder__r.Name : '',
            lastModifiedBy:   t.LastModifiedBy ? t.LastModifiedBy.Name : '',
            userUrl:          t.LastModifiedBy ? `/lightning/r/User/${t.LastModifiedBy.Id}/view` : '',
            lastModifiedDate: t.LastModifiedDate,
            availableActions: this._templateActions
        }));
    }
}