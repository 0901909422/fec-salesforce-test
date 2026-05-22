import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import HOLD_CASE_CONFIG_OBJECT from '@salesforce/schema/FEC_Hold_Case_Config__c';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';
import { STR_EMPTY } from 'c/fec_CommonConst';
import { setConsoleTab } from 'c/fec_CommonUtils';

import getHoldCaseConfigurationDetail from '@salesforce/apex/Fec_HoldCaseConfigurationController.getHoldCaseConfigurationDetail';
import getHoldCaseConfigHistory from '@salesforce/apex/Fec_HoldCaseConfigurationController.getHoldCaseConfigHistory';
import saveHoldCaseConfig from '@salesforce/apex/Fec_HoldCaseConfigurationController.saveHoldCaseConfig';
import searchChannels from '@salesforce/apex/Fec_HoldCaseConfigurationController.searchChannels';
import searchCaseStatus from '@salesforce/apex/Fec_HoldCaseConfigurationController.searchCaseStatus';
import getNfuCodes from '@salesforce/apex/Fec_HoldCaseConfigurationController.getNfuCodes';

import FEC_HCC_Name from '@salesforce/label/c.FEC_HCC_Name';
import FEC_Hold_Case_Type from '@salesforce/label/c.FEC_Hold_Case_Type';
import FEC_Current_Status from '@salesforce/label/c.FEC_Current_Status';
import FEC_Changed_Status from '@salesforce/label/c.FEC_Changed_Status';
import FEC_Manual from '@salesforce/label/c.FEC_Manual';
import FEC_Col_Active from '@salesforce/label/c.FEC_Col_Active';
import FEC_Tab_Case_Stage from '@salesforce/label/c.FEC_Tab_Case_Stage';
import FEC_LABEL_USER from '@salesforce/label/c.FEC_LABEL_USER';
import LBL_Channel_Col from '@salesforce/label/c.LBL_Channel_Col';
import FEC_Date from '@salesforce/label/c.FEC_Date';
import FEC_Field from '@salesforce/label/c.FEC_Field';
import FEC_Original_Value from '@salesforce/label/c.FEC_Original_Value';
import FEC_New_Value from '@salesforce/label/c.FEC_New_Value';
import FEC_Detail_Information from '@salesforce/label/c.FEC_Detail_Information';
import FEC_NFU_Code from '@salesforce/label/c.FEC_NFU_Code';
import FEC_NFU_Reason_VN from '@salesforce/label/c.FEC_NFU_Reason_VN';
import FEC_Auto from '@salesforce/label/c.FEC_Auto';
import FEC_Error_MessageError_For_Hold_Case from '@salesforce/label/c.FEC_Error_MessageError_For_Hold_Case';
import FEC_NFU_Modal_Error from '@salesforce/label/c.FEC_NFU_Modal_Error';
import FEC_NFU_Modal_Save_Error from '@salesforce/label/c.FEC_NFU_Modal_Save_Error';
import FEC_Hold_Case_Save_Success from '@salesforce/label/c.FEC_Hold_Case_Save_Success';
import FEC_Error_Manual from '@salesforce/label/c.FEC_Error_Manual';
import FEC_Hold_Case_Config from '@salesforce/label/c.FEC_Hold_Case_Config';
import FEC_Required_Information from '@salesforce/label/c.FEC_Required_Information';
import FEC_Information from '@salesforce/label/c.FEC_Information';
import FEC_List_Of_NFU_Code from '@salesforce/label/c.FEC_List_Of_NFU_Code';

export default class Fec_HoldCaseConfigurationTabView extends NavigationMixin(LightningElement) {

    @track record = null;
    @track historyRecords = [];
    @track nfuOptions = [];
    @track selectedNfuRowsManual = [];
    @track isShowModal = false;
    @track isShowNfuModal = false;

    isLoading = false;
    canEdit = false;

    holdCaseConfigurationId;
    activeSections = ['holaCaseConfigHistory'];

    channelSearch = STR_EMPTY;
    channelOptions = [];
    showChannelDropdown = false;

    currentStatusSearch = STR_EMPTY;
    currentStatusOptions = [];
    showCurrentStatusDropdown = false;

    changedStatusSearch = STR_EMPTY;
    changedStatusOptions = [];
    showChangedStatusDropdown = false;

    nfuSearch = STR_EMPTY;
    nfuSearchManual = STR_EMPTY;
    nfuModalError = STR_EMPTY;
    selectedNfuRow = null;

    currentStatusSelected = [];
    changedStatusSelected = [];
    channelSelected = [];

    customLabel = {
        hccName: FEC_HCC_Name,
        holdCaseType: FEC_Hold_Case_Type,
        channel: LBL_Channel_Col,
        currentStatus: FEC_Current_Status,
        changedStatus: FEC_Changed_Status,
        nfuCode: FEC_NFU_Code,
        caseStage: FEC_Tab_Case_Stage,
        active: FEC_Col_Active,
        manual: FEC_Manual,
        date: FEC_Date,
        user: FEC_LABEL_USER,
        field: FEC_Field,
        OriginalValue: FEC_Original_Value,
        newValue: FEC_New_Value,
        detailInformation: FEC_Detail_Information,
        nfuReasonVN: FEC_NFU_Reason_VN,
        auto: FEC_Auto,
        errorMessageErrorForHoldCase: FEC_Error_MessageError_For_Hold_Case,
        nfuModalError: FEC_NFU_Modal_Error,
        nfuModalSaveError: FEC_NFU_Modal_Save_Error,
        holdCaseSaveSuccess: FEC_Hold_Case_Save_Success,
        errorManual: FEC_Error_Manual,
        holdCaseConfig: FEC_Hold_Case_Config,
        requiredInformation: FEC_Required_Information,
        information: FEC_Information,
        listOfNFUCode: FEC_List_Of_NFU_Code
    };

    holdCaseFields = [
        { label: this.customLabel.hccName, fieldName: 'Name' },
        { label: this.customLabel.holdCaseType, fieldName: 'Hold_Case_Type__c' },
        { label: this.customLabel.channel, fieldName: 'FEC_Channel__c' },
        { label: this.customLabel.currentStatus, fieldName: 'FEC_Current_Status__c' },
        { label: this.customLabel.changedStatus, fieldName: 'FEC_Changed_Status__c' },
        { label: this.customLabel.caseStage, fieldName: 'caseStageName' },
        { label: this.customLabel.nfuCode, fieldName: 'FEC_NFU_Code__c' },
        { label: this.customLabel.active, fieldName: 'activeText' }
    ];

    holdCaseConfigHistoryColumns = [
        { label: this.customLabel.date, fieldName: 'modifiedDate' },
        { label: this.customLabel.user, fieldName: 'userLabel', type: 'link', recordIdField: 'userId' },
        { label: this.customLabel.field, fieldName: 'field' },
        { label: this.customLabel.OriginalValue, fieldName: 'originalValue' },
        { label: this.customLabel.newValue, fieldName: 'newValue' }
    ];

    nfuCodeColumns = [
        { label: this.customLabel.nfuCode, fieldName: 'FEC_NFU_Code__c' },
        { label: this.customLabel.nfuReasonVN, fieldName: 'FEC_NFU_Reason_VN__c' }
    ];

    @track formData = {
        holdCaseType: STR_EMPTY,
        channels: STR_EMPTY,
        caseStage: STR_EMPTY,
        currentStatus: STR_EMPTY,
        changedStatus: STR_EMPTY,
        nfuCode: STR_EMPTY,
        active: false
    };

    holdCaseTypeOptions = [
        { label: this.customLabel.auto, value: 'Auto' },
        { label: this.customLabel.manual, value: 'Manual' }
    ];

    @track errors = {
        channel: STR_EMPTY,
        currentStatus: STR_EMPTY,
        changedStatus: STR_EMPTY,
        nfuCode: STR_EMPTY
    };

    errorMessages = {
        channel: this.customLabel.errorMessageErrorForHoldCase,
        currentStatus: this.customLabel.errorMessageErrorForHoldCase,
        changedStatus: this.customLabel.errorMessageErrorForHoldCase,
        nfuCode: this.customLabel.errorMessageErrorForHoldCase
    };

    connectedCallback() {
        loadStyle(this, COMMON_STYLES);
    }

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const holdCaseConfigurationId = pageRef?.state?.c__recordId;

        if (holdCaseConfigurationId) {
            this.holdCaseConfigurationId = holdCaseConfigurationId;
            this.loadDetail();
        }
    }

    @wire(getObjectInfo, { objectApiName: HOLD_CASE_CONFIG_OBJECT })
    wiredHoldCaseConfigObjectInfo({ data }) {
        if (data) {
            this.canEdit = data.updateable;
        }
    }

    get isAuto() {
        return this.formData.holdCaseType === this.customLabel.auto;
    }

    get isManual() {
        return this.formData.holdCaseType === this.customLabel.manual;
    }

    get showDropdown() {
        return this.showChannelDropdown && this.channelOptions.length > 0;
    }

    get showCurrentStatusLookup() {
        return this.showCurrentStatusDropdown && this.currentStatusOptions.length > 0;
    }

    get showChangedStatusLookup() {
        return this.showChangedStatusDropdown && this.changedStatusOptions.length > 0;
    }

    get channelWrapperClass() {
        return this.errors.channel
            ? 'slds-combobox_container slds-has-error'
            : 'slds-combobox_container';
    }

    get currentStatusWrapperClass() {
        return this.errors.currentStatus
            ? 'slds-combobox_container slds-has-error'
            : 'slds-combobox_container';
    }

    get changedStatusWrapperClass() {
        return this.errors.changedStatus
            ? 'slds-combobox_container slds-has-error'
            : 'slds-combobox_container';
    }

    get nfuWrapperClass() {
        return this.errors.nfuCode
            ? 'slds-combobox_container slds-has-error'
            : 'slds-combobox_container';
    }

    get channelError() { return this.errors.channel; }
    get currentStatusError() { return this.errors.currentStatus; }
    get changedStatusError() { return this.errors.changedStatus; }
    get nfuError() { return this.errors.nfuCode; }

    get sections() {
        if (!this.record) {
            return null;
        }

        return [
            {
                name: 'detail',
                label: this.customLabel.detailInformation,
                fields: this.buildFields(this.filteredHoldCaseFields)
            }
        ];
    }

    get filteredHoldCaseFields() {
        if (!this.record) {
            return [];
        }

        const isManual =
            this.record.Hold_Case_Type__c === this.customLabel.manual;

        if (isManual) {
            return this.holdCaseFields.filter(field =>
                field.fieldName !== 'FEC_Current_Status__c' &&
                field.fieldName !== 'FEC_Changed_Status__c'
            );
        }

        return this.holdCaseFields;
    }

    loadDetail() {
        if (!this.holdCaseConfigurationId) {
            return;
        }

        this.isLoading = true;

        getHoldCaseConfigurationDetail({
            recordId: this.holdCaseConfigurationId
        })
            .then(result => {
                this.record = {
                    ...result,
                    caseStageName: result?.FEC_Case_Stage__r?.Name || '-',
                    activeText: result?.FEC_Active__c ? 'Yes' : 'No'
                };

                setConsoleTab(this.record.Name, 'standard:orders');

                return getHoldCaseConfigHistory({
                    recordId: this.holdCaseConfigurationId
                });
            })
            .then(data => {
                this.historyRecords = data.map(item => ({
                    ...item,
                    userLabel: item.userName
                }));
            })
            .catch(error => {
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleEdit() {
        if (!this.canEdit || !this.record) {
            return;
        }
        this.populateFormForEdit();
        this.isShowModal = true;
    }

    populateFormForEdit() {
        const nfuCode = this.record.FEC_NFU_Code__c || STR_EMPTY;

        this.formData = {
            holdCaseType: this.record.Hold_Case_Type__c || STR_EMPTY,
            channels: this.record.FEC_Channel__c || STR_EMPTY,
            caseStage: this.record.FEC_Case_Stage__c || STR_EMPTY,
            currentStatus: this.record.FEC_Current_Status__c || STR_EMPTY,
            changedStatus: this.record.FEC_Changed_Status__c || STR_EMPTY,
            nfuCode,
            active: !!this.record.FEC_Active__c
        };

        this.channelSelected = this.parseMultiSelect(this.record.FEC_Channel__c);
        this.currentStatusSelected = this.parseMultiSelect(this.record.FEC_Current_Status__c);
        this.changedStatusSelected = this.parseMultiSelect(this.record.FEC_Changed_Status__c);
        this.nfuSearch = nfuCode;
        this.nfuSearchManual = nfuCode;
        this.channelSearch = STR_EMPTY;
        this.currentStatusSearch = STR_EMPTY;
        this.changedStatusSearch = STR_EMPTY;
        this.errors = {
            channel: STR_EMPTY,
            currentStatus: STR_EMPTY,
            changedStatus: STR_EMPTY,
            nfuCode: STR_EMPTY
        };
    }

    parseMultiSelect(value) {
        if (!value) {
            return [];
        }

        return value
            .split(',')
            .map(item => item.trim())
            .filter(Boolean)
            .map(name => ({ id: name, name }));
    }

    handleCloseModal() {
        this.isShowModal = false;
        this.resetForm();
    }

    handleTypeChange(event) {
        this.formData.holdCaseType = event.detail.value;

        const field = this.template.querySelector('[data-id="holdCaseType"]');
        if (field) {
            field.setCustomValidity(STR_EMPTY);
            field.reportValidity();
        }

        this.formData = {
            ...this.formData,
            channels: STR_EMPTY,
            caseStage: STR_EMPTY,
            currentStatus: STR_EMPTY,
            changedStatus: STR_EMPTY,
            nfuCode: STR_EMPTY
        };
        this.channelSelected = [];
        this.currentStatusSelected = [];
        this.changedStatusSelected = [];
        this.channelSearch = STR_EMPTY;
        this.currentStatusSearch = STR_EMPTY;
        this.changedStatusSearch = STR_EMPTY;
        this.nfuSearch = STR_EMPTY;
        this.nfuSearchManual = STR_EMPTY;
        this.errors = {
            channel: STR_EMPTY,
            currentStatus: STR_EMPTY,
            changedStatus: STR_EMPTY,
            nfuCode: STR_EMPTY
        };
    }

    handleActiveChange(event) {
        this.formData.active = event.detail.checked;
    }

    handleStageChange(event) {
        this.formData.caseStage = event.detail.recordId;

        const field = this.template.querySelector('[data-id="caseStage"]');
        if (field) {
            field.setCustomValidity(STR_EMPTY);
            field.reportValidity();
        }
    }

    handleChannelSearch(event) {
        this.channelSearch = event.target.value;
        if (!this.channelSearch) {
            this.channelOptions = [];
            this.showChannelDropdown = false;
            return;
        }
        searchChannels({ keyword: this.channelSearch })
            .then(result => {
                this.channelOptions = result;
                this.showChannelDropdown = result.length > 0;
            })
            .catch(error => console.error(error));
    }

    handleFocus() {
        searchChannels({ keyword: this.channelSearch || STR_EMPTY })
            .then(result => {
                this.channelOptions = result;
                this.showChannelDropdown = result.length > 0;
            })
            .catch(error => console.error(error));
    }

    handleSelectChannel(event) {
        const el = event.target.closest('[data-id]');
        if (!el) return;

        const id = el.dataset.id;
        const name = el.dataset.name;

        const exists = this.channelSelected.find(i => i.id === id);
        if (!exists) {
            this.channelSelected = [...this.channelSelected, { id, name }];
        }

        this.channelSearch = STR_EMPTY;
        this.showChannelDropdown = false;
        this.channelOptions = [];
        this.formData.channels = this.channelSelected.map(i => i.name).join(', ');
        this.setLookupError('channel', false);
    }

    handleRemoveChannel(event) {
        const id = event.currentTarget.dataset.id;
        this.channelSelected = this.channelSelected.filter(i => i.id !== id);
        this.formData.channels = this.channelSelected.map(i => i.name).join(', ');
    }

    handleCurrentStatusSearch(event) {
        this.currentStatusSearch = event.target.value;

        if (!this.currentStatusSearch) {
            this.currentStatusOptions = [];
            this.showCurrentStatusDropdown = false;
            return;
        }

        searchCaseStatus({ keyword: this.currentStatusSearch })
            .then(result => {
                this.currentStatusOptions = result;
                this.showCurrentStatusDropdown = result.length > 0;
            })
            .catch(error => console.error(error));
    }

    handleCurrentStatusFocus() {
        if (this.currentStatusOptions.length > 0) {
            this.showCurrentStatusDropdown = true;
        }
    }

    handleSelectCurrentStatus(event) {
        const el = event.target.closest('[data-id]');
        if (!el) return;

        const id = el.dataset.id;
        const name = el.dataset.name;

        const exists = this.currentStatusSelected.find(i => i.id === id);
        if (!exists) {
            this.currentStatusSelected = [...this.currentStatusSelected, { id, name }];
        }

        this.currentStatusSearch = STR_EMPTY;
        this.showCurrentStatusDropdown = false;
        this.currentStatusOptions = [];
        this.formData.currentStatus = this.currentStatusSelected.map(i => i.name).join(', ');
        this.setLookupError('currentStatus', false);
    }

    handleRemoveCurrentStatus(event) {
        const id = event.currentTarget.dataset.id;
        this.currentStatusSelected = this.currentStatusSelected.filter(i => i.id !== id);
        this.formData.currentStatus = this.currentStatusSelected.map(i => i.name).join(', ');
    }

    handleChangedStatusSearch(event) {
        this.changedStatusSearch = event.target.value;

        if (!this.changedStatusSearch) {
            this.changedStatusOptions = [];
            this.showChangedStatusDropdown = false;
            return;
        }

        searchCaseStatus({ keyword: this.changedStatusSearch })
            .then(result => {
                this.changedStatusOptions = result;
                this.showChangedStatusDropdown = result.length > 0;
            })
            .catch(error => console.error(error));
    }

    handleChangedStatusFocus() {
        if (this.changedStatusOptions.length > 0) {
            this.showChangedStatusDropdown = true;
        }
    }

    handleSelectChangedStatus(event) {
        const el = event.target.closest('[data-id]');
        if (!el) return;

        const id = el.dataset.id;
        const name = el.dataset.name;

        const exists = this.changedStatusSelected.find(i => i.id === id);
        if (!exists) {
            this.changedStatusSelected = [...this.changedStatusSelected, { id, name }];
        }

        this.changedStatusSearch = STR_EMPTY;
        this.showChangedStatusDropdown = false;
        this.changedStatusOptions = [];
        this.formData.changedStatus = this.changedStatusSelected.map(i => i.name).join(', ');
        this.setLookupError('changedStatus', false);
    }

    handleRemoveChangedStatus(event) {
        const id = event.currentTarget.dataset.id;
        this.changedStatusSelected = this.changedStatusSelected.filter(i => i.id !== id);
        this.formData.changedStatus = this.changedStatusSelected.map(i => i.name).join(', ');
    }

    handleOpenNfuModal() {
        this.nfuModalError = STR_EMPTY;

        if (this.isManual) {
            this.selectedNfuRowsManual = [];
        } else {
            this.selectedNfuRow = null;
        }

        getNfuCodes()
            .then(result => {
                this.nfuOptions = result;
                this.isShowNfuModal = true;
            })
            .catch(error => console.error(error));
    }

    handleCloseNfuModal() {
        this.isShowNfuModal = false;
        this.nfuModalError = STR_EMPTY;
        this.selectedNfuRow = null;
    }

    handleNfuRowSelect(event) {
        let selectedIds = event.detail.selectedRecordIds || [];
        selectedIds = Array.from(selectedIds);

        if (selectedIds.length === 0) {
            this.selectedNfuRow = null;
            return;
        }

        if (this.isAuto && selectedIds.length > 1) {
            this.nfuModalError = this.customLabel.nfuModalError;
            this.selectedNfuRow = null;
            return;
        }

        const selectedId = String(selectedIds[0]);
        const selectedRow = this.nfuOptions.find(r => String(r.Id) === selectedId);
        this.selectedNfuRow = selectedRow || null;
    }

    handleSaveNfuByType() {
        if (this.isManual) {
            this.handleSaveNfuManual();
        } else {
            this.handleSaveNfu();
        }
    }

    handleSaveNfu() {
        if (!this.selectedNfuRow) {
            this.nfuModalError = this.customLabel.nfuModalSaveError;
            return;
        }

        this.formData.nfuCode = this.selectedNfuRow.FEC_NFU_Code__c;
        this.nfuSearch = this.selectedNfuRow?.FEC_NFU_Code__c || STR_EMPTY;
        this.setLookupError('nfuCode', false);
        this.isShowNfuModal = false;
        this.nfuModalError = STR_EMPTY;
        this.selectedNfuRow = null;
    }

    handleNfuRowSelectManual(event) {
        let selectedIds = event.detail.selectedRecordIds || [];
        selectedIds = Array.from(selectedIds);

        if (!selectedIds.length) {
            this.selectedNfuRowsManual = [];
            return;
        }

        this.selectedNfuRowsManual = this.nfuOptions.filter(r =>
            selectedIds.includes(r.Id)
        );
    }

    handleSaveNfuManual() {
        if (!this.selectedNfuRowsManual.length) {
            this.nfuModalError = this.customLabel.errorManual;
            return;
        }

        this.formData.nfuCode = this.selectedNfuRowsManual
            .map(i => i.FEC_NFU_Code__c)
            .join(', ');

        this.nfuSearchManual = this.selectedNfuRowsManual
            .map(i => i.FEC_NFU_Code__c)
            .join(', ');

        this.setLookupError('nfuCode', false);
        this.isShowNfuModal = false;
        this.nfuModalError = STR_EMPTY;
    }

    handleNfuSelection(event) {
        if (this.isManual) {
            this.handleNfuRowSelectManual(event);
        } else {
            this.handleNfuRowSelect(event);
        }
    }

    validateForm() {
        let isValid = true;

        const typeField = this.template.querySelector('[data-id="holdCaseType"]');
        if (!this.formData.holdCaseType) {
            typeField.setCustomValidity(this.customLabel.errorMessageErrorForHoldCase);
            typeField.reportValidity();
            isValid = false;
        } else {
            typeField.setCustomValidity(STR_EMPTY);
            typeField.reportValidity();
        }

        const stageField = this.template.querySelector('[data-id="caseStage"]');
        if (!this.formData.caseStage) {
            stageField.setCustomValidity(this.customLabel.errorMessageErrorForHoldCase);
            stageField.reportValidity();
            isValid = false;
        } else {
            stageField.setCustomValidity(STR_EMPTY);
            stageField.reportValidity();
        }

        if (this.isAuto) {
            if (!this.channelSelected.length) {
                this.setLookupError('channel', true);
                isValid = false;
            } else {
                this.setLookupError('channel', false);
            }

            if (!this.formData.currentStatus) {
                this.setLookupError('currentStatus', true);
                isValid = false;
            } else {
                this.setLookupError('currentStatus', false);
            }

            if (!this.formData.changedStatus) {
                this.setLookupError('changedStatus', true);
                isValid = false;
            } else {
                this.setLookupError('changedStatus', false);
            }

            if (!this.formData.nfuCode) {
                this.setLookupError('nfuCode', true);
                isValid = false;
            } else {
                this.setLookupError('nfuCode', false);
            }
        }

        if (this.isManual) {
            if (!this.channelSelected.length) {
                this.setLookupError('channel', true);
                isValid = false;
            } else {
                this.setLookupError('channel', false);
            }

            if (!this.formData.nfuCode) {
                this.setLookupError('nfuCode', true);
                isValid = false;
            } else {
                this.setLookupError('nfuCode', false);
            }
        }

        return isValid;
    }

    setLookupError(field, isError) {
        this.errors = {
            ...this.errors,
            [field]: isError ? this.errorMessages[field] : STR_EMPTY
        };
    }

    handleSave() {
        if (!this.canEdit) {
            return;
        }

        const isValid = this.validateForm();
        if (!isValid) {
            return;
        }

        const payload = {
            id: this.holdCaseConfigurationId,
            natureOfCaseId: this.record.FEC_Nature_of_Cases__c,
            holdCaseType: this.formData.holdCaseType,
            channel: this.channelSelected.map(i => i.name).join(', '),
            caseStage: this.formData.caseStage,
            currentStatus: this.formData.currentStatus,
            changedStatus: this.formData.changedStatus,
            nfuCode: this.formData.nfuCode,
            active: this.formData.active
        };

        saveHoldCaseConfig({ payload: JSON.stringify(payload) })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: this.customLabel.holdCaseSaveSuccess,
                        variant: 'success'
                    })
                );
                this.isShowModal = false;
                this.resetForm();
                this.loadDetail();
            })
            .catch(error => {
                console.error(error);
                const message = error?.body?.message;
                this.showError(message);
            });
    }

    resetForm() {
        this.formData = {
            holdCaseType: STR_EMPTY,
            channels: STR_EMPTY,
            caseStage: STR_EMPTY,
            currentStatus: STR_EMPTY,
            changedStatus: STR_EMPTY,
            nfuCode: STR_EMPTY,
            active: false
        };
        this.channelSearch = STR_EMPTY;
        this.channelSelected = [];
        this.currentStatusSelected = [];
        this.changedStatusSelected = [];
        this.currentStatusSearch = STR_EMPTY;
        this.changedStatusSearch = STR_EMPTY;
        this.nfuSearch = STR_EMPTY;
        this.nfuSearchManual = STR_EMPTY;
        this.selectedNfuRowsManual = [];
        this.errors = {
            channel: STR_EMPTY,
            currentStatus: STR_EMPTY,
            changedStatus: STR_EMPTY,
            nfuCode: STR_EMPTY
        };
    }

    handleUserSelect(event) {
        const recordId = event.detail.recordId;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'User',
                actionName: 'view'
            }
        });
    }

    buildFields(configs) {
        if (!this.record) {
            return [];
        }

        return configs.map(cfg => {
            let value = this.record?.[cfg.fieldName];

            if (value === null || value === undefined || value === '') {
                value = '-';
            }

            return {
                label: cfg.label,
                value,
                fieldName: cfg.fieldName
            };
        });
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }
}
