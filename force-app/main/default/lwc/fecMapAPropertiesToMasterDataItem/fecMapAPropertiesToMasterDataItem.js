import { LightningElement, track, api } from 'lwc';
import getRecords from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.getRecords';
import createRecord from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.createRecord';
import updateRecord from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.updateRecord';
import deleteRecord from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.deleteRecord';
import getChannels from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.getChannels';
import getUserTypes from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.getUserTypes';
import searchAdditionalFields from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.searchAdditionalFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Custom Labels
import LBL_CARD_TITLE from '@salesforce/label/c.FEC_Map_Properties_Card_Title';
import LBL_COL_CHANNEL from '@salesforce/label/c.FEC_Map_Properties_Col_Channel';
import LBL_COL_USER_TYPE from '@salesforce/label/c.FEC_Map_Properties_Col_User_Type';
import LBL_COL_PROPERTY_ID from '@salesforce/label/c.FEC_Map_Properties_Col_Property_ID';
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

export default class FecMapAPropertiesToMasterDataItem extends LightningElement {
    @api natureOfCaseCode;

    labels = {
        cardTitle: LBL_CARD_TITLE,
        colChannel: LBL_COL_CHANNEL,
        colUserType: LBL_COL_USER_TYPE,
        colPropertyId: LBL_COL_PROPERTY_ID,
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

    // User Type
    @track userTypeOptions = [];
    userTypeMap = {};

    // Additional Field autocomplete
    @track additionalFieldResults = [];
    _searchTimeout = null;

    // Dirty tracking
    _originalRecords = {};

    // Delete
    @track showDeleteModal = false;
    @track deleteRecordId = null;

    // Selected row
    @track selectedRowId = null;

    // Filter state
    @track showChannelFilter = false;
    @track showUserTypeFilter = false;
    @track showPropertyIdFilter = false;
    @track channelFilterSearch = '';
    @track userTypeFilterSearch = '';
    @track propertyIdFilterSearch = '';
    @track selectedChannelFilters = [];
    @track selectedUserTypeFilters = [];
    @track selectedPropertyIdFilters = [];
    _allRecords = [];

    connectedCallback() {
        Promise.all([this.loadChannels(), this.loadUserTypes()]).then(() => {
            this.loadRecords();
        });
    }

    // ===== DATA LOADING =====
    loadChannels() {
        return getChannels()
            .then(result => {
                this.channelOptions = [
                    { label: this.labels.picklistDefault, value: '' },
                    ...result.map(ch => ({ label: ch.FEC_Channel_Vietnamese_name__c, value: ch.Id }))
                ];
                this.channelMap = {};
                result.forEach(ch => { this.channelMap[ch.Id] = ch.FEC_Channel_Vietnamese_name__c; });
            })
            .catch(error => {
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
            });
    }

    loadUserTypes() {
        return getUserTypes()
            .then(result => {
                this.userTypeOptions = [
                    { label: this.labels.picklistDefault, value: '' },
                    ...result.map(ut => ({ label: ut.FEC_Name_VN__c, value: ut.Id }))
                ];
                this.userTypeMap = {};
                result.forEach(ut => { this.userTypeMap[ut.Id] = ut.FEC_Name_VN__c; });
            })
            .catch(error => {
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
            });
    }

    loadRecords() {
        this.isLoading = true;
        getRecords({ natureOfCaseCode: this.natureOfCaseCode })
            .then(result => {
                this._originalRecords = {};
                this._allRecords = result.records.map(rec => {
                    this._originalRecords[rec.Id] = {
                        FEC_Channel__c: rec.FEC_Channel__c,
                        FEC_User_Type__c: rec.FEC_User_Type__c,
                        FEC_Additional_Field__c: rec.FEC_Additional_Field__c,
                        FEC_Additional_Field__r: rec.FEC_Additional_Field__r,
                        FEC_Additional_Field_Unique_ID__c: rec.FEC_Additional_Field_Unique_ID__c,
                        FEC_Status__c: rec.FEC_Status__c
                    };
                    return {
                        ...rec,
                        channelName: this.channelMap[rec.FEC_Channel__c] || rec.FEC_Channel__c || '',
                        userTypeName: this.userTypeMap[rec.FEC_User_Type__c] || rec.FEC_User_Type__c || '',
                        additionalFieldName: rec.FEC_Additional_Field_Unique_ID__c || (rec.FEC_Additional_Field__r && rec.FEC_Additional_Field__r.FEC_Unique_ID__c) || '',
                        additionalFieldSearch: rec.FEC_Additional_Field_Unique_ID__c || (rec.FEC_Additional_Field__r && rec.FEC_Additional_Field__r.FEC_Unique_ID__c) || '',
                        showFieldResults: false,
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
            .finally(() => { this.isLoading = false; });
    }

    // ===== GETTERS =====
    get sectionClass() { return this.sectionOpen ? 'slds-section slds-is-open' : 'slds-section'; }
    get sectionIcon() { return this.sectionOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get hasRecords() { return this.records && this.records.length > 0; }
    get hasNewRows() { return this.newRows && this.newRows.length > 0; }
    get hasDirtyRecords() { return this._allRecords.some(r => r.isDirty); }
    get hasChanges() { return this.hasNewRows || this.hasDirtyRecords; }

    toggleSection() { this.sectionOpen = !this.sectionOpen; }

    // ===== FILTER GETTERS =====
    get channelFilterOptions() {
        const channels = [...new Set(this._allRecords.map(r => r.channelName).filter(Boolean))].sort();
        const search = (this.channelFilterSearch || '').toLowerCase();
        return channels.filter(ch => !search || ch.toLowerCase().includes(search))
            .map(ch => ({ label: ch, value: ch, checked: this.selectedChannelFilters.includes(ch) }));
    }

    get userTypeFilterOptions() {
        const types = [...new Set(this._allRecords.map(r => r.userTypeName).filter(Boolean))].sort();
        const search = (this.userTypeFilterSearch || '').toLowerCase();
        return types.filter(t => !search || t.toLowerCase().includes(search))
            .map(t => ({ label: t, value: t, checked: this.selectedUserTypeFilters.includes(t) }));
    }

    get propertyIdFilterOptions() {
        const ids = [...new Set(this._allRecords.map(r => r.additionalFieldName).filter(Boolean))].sort();
        const search = (this.propertyIdFilterSearch || '').toLowerCase();
        return ids.filter(id => !search || id.toLowerCase().includes(search))
            .map(id => ({ label: id, value: id, checked: this.selectedPropertyIdFilters.includes(id) }));
    }

    get channelFilterIconClass() { return this.selectedChannelFilters.length > 0 ? 'filter-icon filter-icon-active' : 'filter-icon'; }
    get userTypeFilterIconClass() { return this.selectedUserTypeFilters.length > 0 ? 'filter-icon filter-icon-active' : 'filter-icon'; }
    get propertyIdFilterIconClass() { return this.selectedPropertyIdFilters.length > 0 ? 'filter-icon filter-icon-active' : 'filter-icon'; }

    // ===== FILTER HANDLERS =====
    toggleChannelFilter(event) { event.stopPropagation(); this.showChannelFilter = !this.showChannelFilter; this.showUserTypeFilter = false; this.showPropertyIdFilter = false; this.channelFilterSearch = ''; }
    toggleUserTypeFilter(event) { event.stopPropagation(); this.showUserTypeFilter = !this.showUserTypeFilter; this.showChannelFilter = false; this.showPropertyIdFilter = false; this.userTypeFilterSearch = ''; }
    togglePropertyIdFilter(event) { event.stopPropagation(); this.showPropertyIdFilter = !this.showPropertyIdFilter; this.showChannelFilter = false; this.showUserTypeFilter = false; this.propertyIdFilterSearch = ''; }

    handleChannelFilterSearch(event) { this.channelFilterSearch = event.target.value; }
    handleUserTypeFilterSearch(event) { this.userTypeFilterSearch = event.target.value; }
    handlePropertyIdFilterSearch(event) { this.propertyIdFilterSearch = event.target.value; }

    handleChannelCheckboxChange(event) {
        const value = event.target.dataset.value;
        this.selectedChannelFilters = event.target.checked
            ? [...this.selectedChannelFilters, value]
            : this.selectedChannelFilters.filter(v => v !== value);
    }
    handleUserTypeCheckboxChange(event) {
        const value = event.target.dataset.value;
        this.selectedUserTypeFilters = event.target.checked
            ? [...this.selectedUserTypeFilters, value]
            : this.selectedUserTypeFilters.filter(v => v !== value);
    }
    handlePropertyIdCheckboxChange(event) {
        const value = event.target.dataset.value;
        this.selectedPropertyIdFilters = event.target.checked
            ? [...this.selectedPropertyIdFilters, value]
            : this.selectedPropertyIdFilters.filter(v => v !== value);
    }

    handleChannelFilterApply() { this.showChannelFilter = false; this.applyFilters(); }
    handleUserTypeFilterApply() { this.showUserTypeFilter = false; this.applyFilters(); }
    handlePropertyIdFilterApply() { this.showPropertyIdFilter = false; this.applyFilters(); }

    handleChannelFilterCancel() { this.showChannelFilter = false; this.channelFilterSearch = ''; }
    handleUserTypeFilterCancel() { this.showUserTypeFilter = false; this.userTypeFilterSearch = ''; }
    handlePropertyIdFilterCancel() { this.showPropertyIdFilter = false; this.propertyIdFilterSearch = ''; }

    handleClearChannelFilter() { this.selectedChannelFilters = []; this.channelFilterSearch = ''; this.showChannelFilter = false; this.applyFilters(); }
    handleClearUserTypeFilter() { this.selectedUserTypeFilters = []; this.userTypeFilterSearch = ''; this.showUserTypeFilter = false; this.applyFilters(); }
    handleClearPropertyIdFilter() { this.selectedPropertyIdFilters = []; this.propertyIdFilterSearch = ''; this.showPropertyIdFilter = false; this.applyFilters(); }

    applyFilters() {
        let filtered = [...this._allRecords];
        if (this.selectedChannelFilters.length > 0) {
            filtered = filtered.filter(r => this.selectedChannelFilters.includes(r.channelName));
        }
        if (this.selectedUserTypeFilters.length > 0) {
            filtered = filtered.filter(r => this.selectedUserTypeFilters.includes(r.userTypeName));
        }
        if (this.selectedPropertyIdFilters.length > 0) {
            filtered = filtered.filter(r => this.selectedPropertyIdFilters.includes(r.additionalFieldName));
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
        if (field === 'FEC_Channel__c' || field === 'FEC_User_Type__c') {
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
            if (field === 'FEC_User_Type__c') {
                updated.userTypeName = this.userTypeMap[value] || value || '';
            }
            const orig = this._originalRecords[id];
            updated.isDirty = orig.FEC_Channel__c !== updated.FEC_Channel__c ||
                              orig.FEC_User_Type__c !== updated.FEC_User_Type__c ||
                              orig.FEC_Additional_Field__c !== updated.FEC_Additional_Field__c ||
                              orig.FEC_Status__c !== updated.FEC_Status__c;
            return updated;
        };
        this._allRecords = this._allRecords.map(updateRec);
        this.records = this.records.map(updateRec);
    }

    // ===== ADDITIONAL FIELD AUTOCOMPLETE =====
    handleExistingRowFieldSearch(event) {
        const id = event.target.dataset.id;
        const searchTerm = event.target.value;

        const updateRec = (rec) => {
            if (rec.Id !== id) return rec;
            return { ...rec, additionalFieldSearch: searchTerm, showFieldResults: false };
        };
        this._allRecords = this._allRecords.map(updateRec);
        this.records = this.records.map(updateRec);

        clearTimeout(this._searchTimeout);
        if (searchTerm && searchTerm.length >= 2) {
            this._searchTimeout = setTimeout(() => {
                searchAdditionalFields({ searchTerm })
                    .then(result => {
                        this.additionalFieldResults = result;
                        const showResults = (rec) => {
                            if (rec.Id !== id) return rec;
                            return { ...rec, showFieldResults: result.length > 0 };
                        };
                        this._allRecords = this._allRecords.map(showResults);
                        this.records = this.records.map(showResults);
                    })
                    .catch(error => {
                        console.error('Search error:', JSON.stringify(error));
                    });
            }, 300);
        }
    }

    handleSelectAdditionalField(event) {
        const id = event.currentTarget.dataset.id;
        const fieldId = event.currentTarget.dataset.fieldId;
        const fieldName = event.currentTarget.dataset.fieldName;
        const mandatory = event.currentTarget.dataset.mandatory === 'true';

        const updateRec = (rec) => {
            if (rec.Id !== id) return rec;
            const updated = {
                ...rec,
                FEC_Additional_Field__c: fieldId,
                FEC_Additional_Field_Unique_ID__c: fieldName,
                FEC_Is_Mandatory__c: mandatory,
                additionalFieldName: fieldName,
                additionalFieldSearch: fieldName,
                showFieldResults: false
            };
            const orig = this._originalRecords[id];
            updated.isDirty = orig.FEC_Channel__c !== updated.FEC_Channel__c ||
                              orig.FEC_User_Type__c !== updated.FEC_User_Type__c ||
                              orig.FEC_Additional_Field__c !== updated.FEC_Additional_Field__c ||
                              orig.FEC_Additional_Field_Unique_ID__c !== updated.FEC_Additional_Field_Unique_ID__c ||
                              orig.FEC_Status__c !== updated.FEC_Status__c;
            return updated;
        };
        this._allRecords = this._allRecords.map(updateRec);
        this.records = this.records.map(updateRec);
        this.additionalFieldResults = [];
    }

    handleNewRowFieldSearch(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const searchTerm = event.target.value;

        this.newRows = this.newRows.map((row, i) =>
            i === idx ? { ...row, additionalFieldSearch: searchTerm, showFieldResults: false } : row
        );

        clearTimeout(this._searchTimeout);
        if (searchTerm && searchTerm.length >= 2) {
            this._searchTimeout = setTimeout(() => {
                searchAdditionalFields({ searchTerm })
                    .then(result => {
                        this.additionalFieldResults = result;
                        this.newRows = this.newRows.map((row, i) =>
                            i === idx ? { ...row, showFieldResults: result.length > 0 } : row
                        );
                    })
                    .catch(error => {
                        console.error('Search error:', JSON.stringify(error));
                    });
            }, 300);
        }
    }

    handleSelectNewRowAdditionalField(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const fieldId = event.currentTarget.dataset.fieldId;
        const fieldName = event.currentTarget.dataset.fieldName;
        const mandatory = event.currentTarget.dataset.mandatory === 'true';

        this.newRows = this.newRows.map((row, i) =>
            i === idx ? {
                ...row,
                FEC_Additional_Field__c: fieldId,
                FEC_Additional_Field_Unique_ID__c: fieldName,
                FEC_Is_Mandatory__c: mandatory,
                additionalFieldSearch: fieldName,
                showFieldResults: false
            } : row
        );
        this.additionalFieldResults = [];
    }

    // ===== ADD NEW ROW =====
    handleAddItem() {
        this.newRows = [...this.newRows, {
            key: Date.now(),
            FEC_Channel__c: '',
            FEC_User_Type__c: '',
            FEC_Additional_Field__c: '',
            FEC_Additional_Field_Unique_ID__c: '',
            FEC_Is_Mandatory__c: false,
            FEC_Status__c: false,
            additionalFieldSearch: '',
            showFieldResults: false
        }];
    }

    handleNewRowChannelChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value;
        this.newRows = this.newRows.map((row, i) =>
            i === idx ? { ...row, FEC_Channel__c: value } : row
        );
    }

    handleNewRowUserTypeChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value;
        this.newRows = this.newRows.map((row, i) =>
            i === idx ? { ...row, FEC_User_Type__c: value } : row
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
                this._notifyDataChanged();
                this.loadRecords();
            })
            .catch(error => {
                this.showToast(this.labels.toastError, this.reduceErrors(error), 'error');
            })
            .finally(() => { this.isLoading = false; });
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
                FEC_User_Type__c: orig.FEC_User_Type__c,
                FEC_Additional_Field__c: orig.FEC_Additional_Field__c,
                FEC_Additional_Field_Unique_ID__c: orig.FEC_Additional_Field_Unique_ID__c,
                FEC_Status__c: orig.FEC_Status__c,
                channelName: this.channelMap[orig.FEC_Channel__c] || orig.FEC_Channel__c || '',
                userTypeName: this.userTypeMap[orig.FEC_User_Type__c] || orig.FEC_User_Type__c || '',
                additionalFieldName: orig.FEC_Additional_Field_Unique_ID__c || (orig.FEC_Additional_Field__r && orig.FEC_Additional_Field__r.FEC_Unique_ID__c) || '',
                additionalFieldSearch: orig.FEC_Additional_Field_Unique_ID__c || (orig.FEC_Additional_Field__r && orig.FEC_Additional_Field__r.FEC_Unique_ID__c) || '',
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
            const rec = {
                FEC_Channel__c: row.FEC_Channel__c || null,
                FEC_User_Type__c: row.FEC_User_Type__c || null,
                FEC_Additional_Field__c: row.FEC_Additional_Field__c || null,
                FEC_Additional_Field_Unique_ID__c: row.FEC_Additional_Field_Unique_ID__c || null,
                FEC_Is_Mandatory__c: row.FEC_Is_Mandatory__c || false,
                FEC_Status__c: row.FEC_Status__c || false,
                FEC_Sync_Status__c: SYNC_STATUS_NEW,
                FEC_Nature_of_Case_Code__c: this.natureOfCaseCode || null
            };
            console.log('handleSave: ', JSON.stringify(rec));
            promises.push(createRecord({ record: rec }));
        });

        // Update dirty existing records
        this._allRecords.filter(r => r.isDirty).forEach(rec => {
            const recordToSave = {
                Id: rec.Id,
                FEC_Channel__c: rec.FEC_Channel__c || null,
                FEC_User_Type__c: rec.FEC_User_Type__c || null,
                FEC_Additional_Field__c: rec.FEC_Additional_Field__c || null,
                FEC_Additional_Field_Unique_ID__c: rec.FEC_Additional_Field_Unique_ID__c || null,
                FEC_Is_Mandatory__c: rec.FEC_Is_Mandatory__c || false,
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
                this._notifyDataChanged();
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

    _notifyDataChanged() {
        this.dispatchEvent(new CustomEvent('datachanged', { bubbles: true, composed: true }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.body?.fieldErrors) {
            return Object.values(error.body.fieldErrors).flat().map(e => e.message).join(', ');
        }
        if (error?.body?.pageErrors) {
            return error.body.pageErrors.map(e => e.message).join(', ');
        }
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        if (error?.message) return error.message;
        return JSON.stringify(error);
    }
}