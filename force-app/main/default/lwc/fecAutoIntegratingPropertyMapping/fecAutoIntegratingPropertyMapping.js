import { LightningElement, track, api } from 'lwc';
import getRecords from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.getRecords';
import createRecord from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.createRecord';
import updateRecord from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.updateRecord';
import deleteRecord from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.deleteRecord';

import getChannels from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.getChannels';
import getAdditionalFieldByUniqueID from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.getAdditionalFieldByUniqueID';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Custom Labels
import LBL_CARD_TITLE from '@salesforce/label/c.FEC_Auto_Integrating_Card_Title';
import LBL_COL_INTEGRATING_CHANNEL from '@salesforce/label/c.FEC_Auto_Integrating_Col_Integrating_Channel';
import LBL_COL_INTEGRATING_PROPERTY_ID from '@salesforce/label/c.FEC_Auto_Integrating_Col_Integrating_Property_ID';
import LBL_ADD_ITEM from '@salesforce/label/c.FEC_Auto_Integrating_Add_Item';
import LBL_BTN_HUY from '@salesforce/label/c.FEC_Auto_Integrating_Btn_Huy';
import LBL_BTN_LUU from '@salesforce/label/c.FEC_Auto_Integrating_Btn_Luu';
import LBL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Auto_Integrating_Toast_Success';
import LBL_TOAST_ERROR from '@salesforce/label/c.FEC_Auto_Integrating_Toast_Error';
import LBL_MSG_RECORD_CREATED from '@salesforce/label/c.FEC_Auto_Integrating_Msg_Record_Created';
import LBL_MSG_RECORD_UPDATED from '@salesforce/label/c.FEC_Auto_Integrating_Msg_Record_Updated';
import LBL_MSG_RECORD_DELETED from '@salesforce/label/c.FEC_Auto_Integrating_Msg_Record_Deleted';
import LBL_MSG_REQUIRED_FIELDS from '@salesforce/label/c.FEC_Auto_Integrating_Msg_Required_Fields';
import LBL_CONFIRM_DELETE_TITLE from '@salesforce/label/c.FEC_Auto_Integrating_Confirm_Delete_Title';
import LBL_CONFIRM_DELETE_MSG from '@salesforce/label/c.FEC_Auto_Integrating_Confirm_Delete_Msg';
import LBL_BTN_CANCEL from '@salesforce/label/c.FEC_Auto_Integrating_Btn_Cancel';
import LBL_BTN_DELETE from '@salesforce/label/c.FEC_Auto_Integrating_Btn_Delete';
import LBL_PICKLIST_DEFAULT from '@salesforce/label/c.FEC_Auto_Integrating_Picklist_Default';
import LBL_LOADING from '@salesforce/label/c.FEC_Auto_Integrating_Loading';
import LBL_NO_RECORDS from '@salesforce/label/c.FEC_Auto_Integrating_No_Records';
import LBL_COL_STATUS from '@salesforce/label/c.FEC_Auto_Integrating_Col_Status';
import LBL_BTN_APPLY from '@salesforce/label/c.FEC_Btn_Apply';
import LBL_BTN_CLEAR_FILTER from '@salesforce/label/c.FEC_Btn_Clear_Filter';
import LBL_SEARCH_TEXT from '@salesforce/label/c.FEC_Auto_Integrating_Search_Text';

// Sync Status constants (mirrors FEC_FraudConstantCommon)
const SYNC_STATUS_SYNCED  = 'Synced';
const SYNC_STATUS_UPDATED = 'Updated';
const SYNC_STATUS_NEW     = 'New';
const SYNC_STATUS_DELETED = 'Deleted';

export default class FecAutoIntetgratingPropertyMapping extends LightningElement {
    @api recordId;

    labels = {
        cardTitle: LBL_CARD_TITLE,
        colIntegratingChannel: LBL_COL_INTEGRATING_CHANNEL,
        colIntegratingPropertyId: LBL_COL_INTEGRATING_PROPERTY_ID,
        colStatus: LBL_COL_STATUS,
        addItem: LBL_ADD_ITEM,
        btnHuy: LBL_BTN_HUY,
        btnLuu: LBL_BTN_LUU,
        toastSuccess: LBL_TOAST_SUCCESS,
        toastError: LBL_TOAST_ERROR,
        msgRecordCreated: LBL_MSG_RECORD_CREATED,
        msgRecordUpdated: LBL_MSG_RECORD_UPDATED,
        msgRecordDeleted: LBL_MSG_RECORD_DELETED,
        msgRequiredFields: LBL_MSG_REQUIRED_FIELDS,
        confirmDeleteTitle: LBL_CONFIRM_DELETE_TITLE,
        confirmDeleteMsg: LBL_CONFIRM_DELETE_MSG,
        btnCancel: LBL_BTN_CANCEL,
        btnDelete: LBL_BTN_DELETE,
        picklistDefault: LBL_PICKLIST_DEFAULT,
        loading: LBL_LOADING,
        noRecords: LBL_NO_RECORDS,
        btnApply: LBL_BTN_APPLY,
        btnClearFilter: LBL_BTN_CLEAR_FILTER,
        searchText: LBL_SEARCH_TEXT
    };

    @track records = [];
    @track isLoading = true;
    @track sectionOpen = true;
    @track newRows = [];

    // Channel
    @track channelOptions = [];
    channelMap = {};

    // Additional Field data from recordId
    additionalFieldData = null;

    // Dirty tracking
    _originalRecords = {};

    // Delete
    @track showDeleteModal = false;
    @track deleteRecordId = null;

    // Selected row for editing
    @track selectedRowId = null;

    // Filter state
    @track showChannelFilter = false;
    @track showPropertyIdFilter = false;
    @track channelFilterSearch = '';
    @track propertyIdFilterSearch = '';
    @track selectedChannelFilters = [];
    @track selectedPropertyIdFilters = [];
    _allRecords = [];
    

    connectedCallback() {
        //this.recordId = 'AppIDs';
        const initPromises = [this.loadChannels()];
        if (this.recordId) {
            initPromises.push(this.loadAdditionalField());
        }
        Promise.all(initPromises)
            .then(() => {
                this.loadRecords();
            })
            .catch(err => {
                console.error('[connectedCallback] Init error:', err);
            });
    }

    loadAdditionalField() {
        return getAdditionalFieldByUniqueID({ uniqueID: this.recordId })
            .then(result => {
                if (result) {
                    console.log('getAdditionalFieldById-result: ', result);
                    this.additionalFieldData = {
                        FEC_Soure_Property_ID__c: result.FEC_Unique_ID__c || '',
                        FEC_Property_Name_VN__c: result.FEC_Name_VN__c || '',
                        FEC_Property_Type__c: result.FEC_Type__c || '',
                        FEC_Is_Mandatory__c: result.FEC_Field_Mandatory__c || false,
                        Name: result.Name
                    };
                }
            })
            .catch(error => {
                console.error('Load additional field error:', JSON.stringify(error));
            });
    }

    get sectionClass() {
        return this.sectionOpen ? 'slds-section slds-is-open' : 'slds-section';
    }

    get sectionIcon() {
        return this.sectionOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    toggleSection() {
        this.sectionOpen = !this.sectionOpen;
    }

    loadChannels() {
        return getChannels()
            .then(result => {
                this.channelOptions = [
                    { label: this.labels.picklistDefault, value: '' },
                    ...result.map(ch => ({
                        label: ch.FEC_Channel_Vietnamese_name__c,
                        value: ch.Id
                    }))
                ];
                this.channelMap = {};
                result.forEach(ch => {
                    this.channelMap[ch.Id] = ch.FEC_Channel_Vietnamese_name__c;
                });
            })
            .catch(error => {
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
            });
    }

    loadRecords() {
        if (!this.additionalFieldData) {
            console.warn('[loadRecords] additionalFieldData not loaded yet');
            return;
        }
        this.isLoading = true;
        //console.log('additionalFieldData: ', JSON.stringify(this.additionalFieldData));
        getRecords({ sourePropertyId: this.additionalFieldData.FEC_Soure_Property_ID__c })
            .then(result => {
                //console.log('getRecords: ', result);
                this._originalRecords = {};
                this._allRecords = result.records.map(rec => {
                    this._originalRecords[rec.Id] = {
                        FEC_Channel__c: rec.FEC_Channel__c,
                        FEC_Property_ID__c: rec.FEC_Property_ID__c,
                        FEC_Status__c: rec.FEC_Status__c
                    };
                    return {
                        ...rec,
                        channelName: this.channelMap[rec.FEC_Channel__c] || rec.FEC_Channel__c || '',
                        isActive: rec.FEC_Status__c === true,
                        syncStatus: rec.FEC_Sync_Status__c || '',
                        isSynced: rec.FEC_Sync_Status__c === SYNC_STATUS_SYNCED,
                        isUpdatedStatus: rec.FEC_Sync_Status__c === SYNC_STATUS_UPDATED,
                        isNewStatus: rec.FEC_Sync_Status__c === SYNC_STATUS_NEW,
                        isDirty: false,
                        isEditing: false
                    };
                });
                this.applyFilters();
            })
            .catch(error => {
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    get hasNewRows() {
        return this.newRows && this.newRows.length > 0;
    }

    get hasDirtyRecords() {
        return this._allRecords.some(r => r.isDirty);
    }

    get hasChanges() {
        return this.hasNewRows || this.hasDirtyRecords;
    }

    // ===== FILTER =====
    get channelFilterOptions() {
        const channels = [...new Set(this._allRecords.map(r => r.channelName).filter(Boolean))].sort();
        const search = (this.channelFilterSearch || '').toLowerCase();
        return channels
            .filter(ch => !search || ch.toLowerCase().includes(search))
            .map(ch => ({
                label: ch,
                value: ch,
                checked: this.selectedChannelFilters.includes(ch)
            }));
    }

    get propertyIdFilterOptions() {
        const ids = [...new Set(this._allRecords.map(r => r.FEC_Property_ID__c).filter(Boolean))].sort();
        const search = (this.propertyIdFilterSearch || '').toLowerCase();
        return ids
            .filter(id => !search || id.toLowerCase().includes(search))
            .map(id => ({
                label: id,
                value: id,
                checked: this.selectedPropertyIdFilters.includes(id)
            }));
    }

    get isChannelFilterActive() {
        return this.selectedChannelFilters.length > 0;
    }

    get isPropertyIdFilterActive() {
        return this.selectedPropertyIdFilters.length > 0;
    }

    get channelFilterIconClass() {
        return this.isChannelFilterActive ? 'filter-icon filter-icon-active' : 'filter-icon';
    }

    get propertyIdFilterIconClass() {
        return this.isPropertyIdFilterActive ? 'filter-icon filter-icon-active' : 'filter-icon';
    }

    toggleChannelFilter(event) {
        event.stopPropagation();
        this.showChannelFilter = !this.showChannelFilter;
        this.showPropertyIdFilter = false;
        this.channelFilterSearch = '';
    }

    togglePropertyIdFilter(event) {
        event.stopPropagation();
        this.showPropertyIdFilter = !this.showPropertyIdFilter;
        this.showChannelFilter = false;
        this.propertyIdFilterSearch = '';
    }

    handleChannelFilterSearch(event) {
        this.channelFilterSearch = event.target.value;
    }

    handlePropertyIdFilterSearch(event) {
        this.propertyIdFilterSearch = event.target.value;
    }

    handleChannelCheckboxChange(event) {
        const value = event.target.dataset.value;
        const checked = event.target.checked;
        if (checked) {
            this.selectedChannelFilters = [...this.selectedChannelFilters, value];
        } else {
            this.selectedChannelFilters = this.selectedChannelFilters.filter(v => v !== value);
        }
    }

    handlePropertyIdCheckboxChange(event) {
        const value = event.target.dataset.value;
        const checked = event.target.checked;
        if (checked) {
            this.selectedPropertyIdFilters = [...this.selectedPropertyIdFilters, value];
        } else {
            this.selectedPropertyIdFilters = this.selectedPropertyIdFilters.filter(v => v !== value);
        }
    }

    handleChannelFilterApply() {
        this.showChannelFilter = false;
        this.applyFilters();
    }

    handlePropertyIdFilterApply() {
        this.showPropertyIdFilter = false;
        this.applyFilters();
    }

    handleChannelFilterCancel() {
        this.showChannelFilter = false;
        this.channelFilterSearch = '';
    }

    handlePropertyIdFilterCancel() {
        this.showPropertyIdFilter = false;
        this.propertyIdFilterSearch = '';
    }

    handleClearChannelFilter() {
        this.selectedChannelFilters = [];
        this.channelFilterSearch = '';
        this.showChannelFilter = false;
        this.applyFilters();
    }

    handleClearPropertyIdFilter() {
        this.selectedPropertyIdFilters = [];
        this.propertyIdFilterSearch = '';
        this.showPropertyIdFilter = false;
        this.applyFilters();
    }

    applyFilters() {
        let filtered = [...this._allRecords];
        if (this.selectedChannelFilters.length > 0) {
            filtered = filtered.filter(r => this.selectedChannelFilters.includes(r.channelName));
        }
        if (this.selectedPropertyIdFilters.length > 0) {
            filtered = filtered.filter(r => this.selectedPropertyIdFilters.includes(r.FEC_Property_ID__c));
        }
        this.records = filtered;
    }

    // ===== EXISTING ROW INLINE EDIT =====
    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedRowId = id;
        const updateRec = (rec) => ({
            ...rec,
            isEditing: rec.Id === id,
            isDirty: rec.Id === id ? true : rec.isDirty
        });
        this._allRecords = this._allRecords.map(updateRec);
        this.records = this.records.map(updateRec);
    }

    handleExistingRowChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        let value;
        if (field === 'FEC_Channel__c') {
            value = event.detail.value;
        } else if (field === 'FEC_Status__c') {
            value = event.target.checked;
        } else {
            value = event.target.value;
        }

        const updateRec = (rec) => {
            if (rec.Id !== id) return rec;
            const updated = { ...rec, [field]: value };
            if (field === 'FEC_Channel__c') {
                updated.channelName = this.channelMap[value] || value || '';
            }
            const orig = this._originalRecords[id];
            updated.isDirty = orig.FEC_Channel__c !== updated.FEC_Channel__c ||
                              orig.FEC_Property_ID__c !== updated.FEC_Property_ID__c ||
                              orig.FEC_Status__c !== updated.FEC_Status__c;
            return updated;
        };

        this._allRecords = this._allRecords.map(updateRec);
        this.records = this.records.map(updateRec);
    }

    // ===== ADD NEW ROW =====
    handleAddItem() {
        const fieldData = this.additionalFieldData || {};
        this.newRows = [...this.newRows, {
            key: Date.now(),
            FEC_Channel__c: '',
            FEC_Property_ID__c: '',
            FEC_Soure_Property_ID__c: fieldData.FEC_Soure_Property_ID__c || '',
            FEC_Property_Name_VN__c: fieldData.FEC_Property_Name_VN__c || '',
            FEC_Property_Type__c: fieldData.FEC_Property_Type__c || '',
            Name: fieldData.Name || '',
            FEC_Is_Mandatory__c: fieldData.FEC_Is_Mandatory__c || false,
            FEC_Status__c: false
        }];
    }

    handleNewRowChannelChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value;
        this.newRows = this.newRows.map((row, i) =>
            i === idx ? { ...row, FEC_Channel__c: value } : row
        );
    }

    handleNewRowPropertyIdChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const value = event.target.value;
        this.newRows = this.newRows.map((row, i) =>
            i === idx ? { ...row, FEC_Property_ID__c: value } : row
        );
    }

    handleRemoveNewRow(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        this.newRows = this.newRows.filter((_, i) => i !== idx);
    }

    handleNewRowStatusChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const checked = event.target.checked;
        this.newRows = this.newRows.map((row, i) =>
            i === idx ? { ...row, FEC_Status__c: checked } : row
        );
    }

    // ===== DELETE =====
    handleDelete(event) {
        this.deleteRecordId = event.target.dataset.id;
        if (!this.deleteRecordId) return;
        this.showDeleteModal = true;
    }

    closeDeleteModal() {
        this.showDeleteModal = false;
        this.deleteRecordId = null;
    }

    confirmDelete() {
        this.showDeleteModal = false;
        this.isLoading = true;
        deleteRecord({ recordId: this.deleteRecordId })
            .then(() => {
                this.showToast(this.labels.toastSuccess, this.labels.msgRecordDeleted, 'success');
                this.deleteRecordId = null;
                this.loadRecords();
            })
            .catch(error => {
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ===== CANCEL =====
    handleCancel() {
        this.newRows = [];
        const resetRec = (rec) => {
            if (!rec.isDirty) return rec;
            const orig = this._originalRecords[rec.Id];
            return {
                ...rec,
                FEC_Channel__c: orig.FEC_Channel__c,
                FEC_Property_ID__c: orig.FEC_Property_ID__c,
                FEC_Status__c: orig.FEC_Status__c,
                channelName: this.channelMap[orig.FEC_Channel__c] || orig.FEC_Channel__c || '',
                isDirty: false
            };
        };
        this._allRecords = this._allRecords.map(resetRec);
        this.records = this.records.map(resetRec);
    }

    // ===== SAVE =====
    handleSave() {
        if (!this.hasChanges) return;

        const allValid = [...this.template.querySelectorAll('[data-validate]')]
            .reduce((valid, input) => {
                input.reportValidity();
                return valid && input.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast(this.labels.toastError, this.labels.msgRequiredFields, 'error');
            return;
        }

        this.isLoading = true;
        const promises = [];

        // Create new rows
        this.newRows.forEach(row => {
            const recordToSave = {
                FEC_Channel__c: row.FEC_Channel__c,
                FEC_Property_ID__c: row.FEC_Property_ID__c,
                FEC_Soure_Property_ID__c: row.FEC_Soure_Property_ID__c,
                FEC_Property_Name_VN__c: row.FEC_Property_Name_VN__c,
                Name: row.Name,
                FEC_Property_Type__c: row.FEC_Property_Type__c,
                FEC_Is_Mandatory__c: row.FEC_Is_Mandatory__c || false,
                FEC_Status__c: row.FEC_Status__c || false,
                FEC_Sync_Status__c: SYNC_STATUS_NEW
            };
            console.log("recordToSave: ", JSON.stringify(recordToSave));
            promises.push(createRecord({ record: recordToSave }));
        });

        // Update dirty existing records
        this._allRecords.filter(r => r.isDirty).forEach(rec => {
            const recordToSave = {
                Id: rec.Id,
                FEC_Channel__c: rec.FEC_Channel__c,
                FEC_Property_ID__c: rec.FEC_Property_ID__c,
                FEC_Status__c: rec.FEC_Status__c || false,
                FEC_Sync_Status__c: SYNC_STATUS_UPDATED
            };
            promises.push(updateRecord({ record: recordToSave }));
        });

        const hasNew = this.newRows.length > 0;
        const hasDirty = this._allRecords.some(r => r.isDirty);

        Promise.all(promises)
            .then(() => {
                let msg = '';
                if (hasNew && hasDirty) {
                    msg = this.labels.msgRecordCreated + ' & ' + this.labels.msgRecordUpdated;
                } else if (hasNew) {
                    msg = this.labels.msgRecordCreated;
                } else {
                    msg = this.labels.msgRecordUpdated;
                }
                this.showToast(this.labels.toastSuccess, msg, 'success');
                this.newRows = [];
                this.selectedRowId = null;
                return this.loadRecords();
            })
            .catch(error => {
                console.error('Save error:', JSON.stringify(error));
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
                this.isLoading = false;
            });
    }

    // ===== UTILS =====
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.body?.fieldErrors) {
            const fieldErrors = Object.values(error.body.fieldErrors).flat();
            return fieldErrors.map(e => e.message).join(', ');
        }
        if (error?.body?.pageErrors) {
            return error.body.pageErrors.map(e => e.message).join(', ');
        }
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        if (error?.message) return error.message;
        return JSON.stringify(error);
    }
}