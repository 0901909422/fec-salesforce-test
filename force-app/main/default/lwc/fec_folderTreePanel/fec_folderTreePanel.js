/**
 * @description  Left Navigation Panel – static sidebar for Template Management.
 *               Final structure per design:
 *               ┌─────────────────┐
 *               │ EMAIL TEMPLATES  │
 *               │   All Templates  │
 *               │                  │
 *               │ FOLDERS          │
 *               │   All Folders    │
 *               └─────────────────┘
 *               No folder tree. No expand/collapse.
 *               Clicking an item loads the corresponding list view.
 *               V1: static  |  V2: same (static by design).
 * @component    fec_folderTreePanel
 */
import { LightningElement, api, track } from 'lwc';

/* ── Custom Labels (i18n) ── */
import FEC_Template_Management_Title from '@salesforce/label/c.FEC_Template_Management_Title';
import FEC_All_Templates_Tab         from '@salesforce/label/c.FEC_All_Templates_Tab';
import FEC_Folder_Tree_Title         from '@salesforce/label/c.FEC_Folder_Tree_Title';
import FEC_All_Folders_Tab           from '@salesforce/label/c.FEC_All_Folders_Tab';

/* ── Constants ── */
import { TAB_TEMPLATES, TAB_FOLDERS } from 'c/fec_TemplateConstants';

/** Map navigation item names → view constants */
const VIEW_MAP = {
    all_templates: TAB_TEMPLATES,
    all_folders:   TAB_FOLDERS
};

/** Reverse map: view constant → nav item name */
const REVERSE_VIEW_MAP = {
    [TAB_TEMPLATES]: 'all_templates',
    [TAB_FOLDERS]:   'all_folders'
};

export default class Fec_folderTreePanel extends LightningElement {

    /** Current active view (from parent) – syncs sidebar highlight */
    _activeView;
    @api
    get activeView() { return this._activeView; }
    set activeView(value) {
        this._activeView = value;
        /* Keep sidebar highlight in sync when parent changes the view programmatically */
        const navItem = REVERSE_VIEW_MAP[value];
        if (navItem) {
            this.selectedNavItem = navItem;
        }
    }

    /** Labels */
    label = {
        FEC_Template_Management_Title,
        FEC_All_Templates_Tab,
        FEC_Folder_Tree_Title,
        FEC_All_Folders_Tab
    };

    /** Currently highlighted nav item */
    @track selectedNavItem = 'all_templates';

    /**
     * Navigation item selection handler.
     * Dispatches a viewchange event to the parent console.
     */
    handleNavSelect(event) {
        const itemName = event.detail.name;
        this.selectedNavItem = itemName;

        const view = VIEW_MAP[itemName];
        if (view) {
            this.dispatchEvent(
                new CustomEvent('viewchange', {
                    detail: { view }
                })
            );
        }
    }
}