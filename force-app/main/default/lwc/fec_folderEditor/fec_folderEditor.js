/**
 * fec_folderEditor
 * Modal for creating / editing an email template folder.
 * Fields: Folder Label (required), Folder Unique Name (auto-gen),
 *         Parent Folder (flat dropdown).
 * Dispatches: save (with folder record detail), cancel.
 * Apex-backed via FEC_FolderController.
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex
import getAllFolders from '@salesforce/apex/FEC_FolderController.getAllFolders';
import getFolder    from '@salesforce/apex/FEC_FolderController.getFolder';
import saveFolder   from '@salesforce/apex/FEC_FolderController.saveFolder';

// Labels
import folderLabel       from '@salesforce/label/c.FEC_Col_Folder_Label';
import parentFolderLabel from '@salesforce/label/c.FEC_Col_Parent_Folder';
import folderCreateSuccessMsg from '@salesforce/label/c.FEC_Folder_Create_Success';
import folderUpdatedSuccessMsg from '@salesforce/label/c.FEC_Folder_Updated_Success';

// Utils
import { generateApiName } from 'c/fec_TemplateUtils';

export default class Fec_folderEditor extends LightningElement {

    /** Optional: existing folder ID for edit mode */
    @api recordId;
    @api parentFolderId;

    label = {
        folderLabel,
        parentFolderLabel,
        folderCreateSuccessMsg,
        folderUpdatedSuccessMsg
    };

    @track folderName  = '';
    @track uniqueName  = '';
    @track parentId    = '';
    @track description = '';
    @track isDuplicated = false;
    @track errorDuplicate = '';
    @track _isSaving   = false;

    _uniqueNameManuallySet = false;

    /** Folder options from Apex */
    @track _allFolders = [];

    // ─── Lifecycle ───────────────────────────────────────

    connectedCallback() {
        // this._loadAllFolders();
        if (this.recordId) {
            this._loadRecord();
        }
    }

    // ─── Imperative: load all folders for parent dropdown ──────

    async _loadAllFolders() {
        try {
            const data = await getAllFolders();
            this._allFolders = data || [];
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[folderEditor] Error loading folders:', error);
        }
    }

    // ─── Computed ────────────────────────────────────────

    get modalTitle() {
        return this.recordId ? 'Edit Folder' : 'New Folder';
    }

    // get parentFolderOptions() {
    //     const opts = [{ label: '— None —', value: '' }];
    //     (this._allFolders || []).forEach(f => {
    //         // Exclude self when editing
    //         if (f.Id !== this.recordId) {
    //             opts.push({ label: f.FEC_Folder_Label__c, value: f.Id });
    //         }
    //     });
    //     return opts;
    // }

    // ─── Handlers ────────────────────────────────────────

    handleNameChange(event) {
        this.folderName = event.detail.value;
        if (!this._uniqueNameManuallySet) {
            this.uniqueName = generateApiName(this.folderName);
        }
    }

    handleUniqueNameChange(event) {
        this.uniqueName = event.detail.value;
        this._uniqueNameManuallySet = true;
    }

    handleParentChange(event) {
        this.parentId = event.detail.value;
    }

    // handleDescriptionChange(event) {
    //     this.description = event.detail.value;
    // }

    async handleSave() {
        if (!this._validate()) return;

        this._isSaving = true;
        this.isDuplicated = false;
        try {
            const sObj = {
                FEC_Folder_Label__c:       this.folderName,
                FEC_Folder_Unique_Name__c: this.uniqueName,
                FEC_Parent_Folder__c:      this.parentFolderId || null
            };
            if (this.recordId) {
                sObj.Id = this.recordId;
            }

            const folderJson = JSON.stringify(sObj);
            await saveFolder({ folderJson: folderJson });

            this.dispatchEvent(new ShowToastEvent({
                title: '',
                message: this.recordId ?  this.label.folderUpdatedSuccessMsg.replace('MERGE_FIELD_NAME', this.folderName) : this.label.folderCreateSuccessMsg.replace('MERGE_FIELD_NAME', this.folderName),
                variant: 'success'
            }));

            this.dispatchEvent(new CustomEvent('save'));
        } catch (error) {
            let msg = error.body?.message || ''
            const cleanMessage = msg.split(', ').pop().split(': [')[0];
            this.errorDuplicate = cleanMessage;
            this.isDuplicated = true;
        } finally {
            this._isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleCloseModal() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // ─── Private helpers ─────────────────────────────────

    _validate() {
        const nameInput = this.template.querySelector('.folder-name-input');
        if (nameInput) {
            nameInput.reportValidity();
        }

        const uniqueNameInput = this.template.querySelector('.folder-unique-name-input');
        if (uniqueNameInput) {
            uniqueNameInput.reportValidity();
        }
        if (!this.folderName || !this.folderName.trim() || !this.uniqueName || !this.uniqueName.trim()) {
            return false;
        }
        return true;
    }

    async _loadRecord() {
        try {
            const rec = await getFolder({ folderId: this.recordId });
            if (rec) {
                this.folderName  = rec.FEC_Folder_Label__c || '';
                this.uniqueName  = rec.FEC_Folder_Unique_Name__c || generateApiName(rec.FEC_Folder_Label__c);
                this.parentId    = rec.FEC_Parent_Folder__c || '';
                this.description = '';
                this._uniqueNameManuallySet = true;
            }
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[folderEditor] Error loading folder:', error);
        }
    }

    // Function to clean the DML error message
    _getCleanErrorMessage(fullErrorMessage) {
        // Regex breakdown:
        // .+, : Matches everything up to the first comma and space (e.g., "FIELD_CUSTOM_VALIDATION_EXCEPTION, ")
        // (.+) : Captures the actual message into Group 1
        // : \[(.+)\] : Matches the trailing colon, space, and brackets at the end
        const regex = /.+,\s*(.+):\s*\[.+\]/;
        const match = fullErrorMessage.match(regex);

        if (match && match[1]) {
            return match[1];
        }
        
        // Fallback: If regex fails, return the original or a generic slice
        return fullErrorMessage;
    }
}