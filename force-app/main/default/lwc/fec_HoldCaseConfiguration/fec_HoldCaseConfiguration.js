/****************************************************************************************
 * File Name    : Fec_HoldCaseConfiguration.js
 * Author       : Quangdv7
 * Date         : 2026-05-11
 * Description  : Call data object Hold Case Config
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-05-11    Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';
import { STR_EMPTY } from 'c/fec_CommonConst';

import saveHoldCaseConfig from '@salesforce/apex/Fec_HoldCaseConfigurationController.saveHoldCaseConfig';
import getHoldCaseConfigurations from '@salesforce/apex/Fec_HoldCaseConfigurationController.getHoldCaseConfigurations';
import getParentHoldCaseConfigurations from '@salesforce/apex/Fec_HoldCaseConfigurationController.getParentHoldCaseConfigurations';
import searchChannels from '@salesforce/apex/Fec_HoldCaseConfigurationController.searchChannels';
import searchCaseStatus from '@salesforce/apex/Fec_HoldCaseConfigurationController.searchCaseStatus';
import getNfuCodes from '@salesforce/apex/Fec_HoldCaseConfigurationController.getNfuCodes';
import { getFocusedTabInfo, openSubtab } from 'lightning/platformWorkspaceApi';
import LBL_Channel_Col from '@salesforce/label/c.LBL_Channel_Col';
import FEC_NFU_Code from '@salesforce/label/c.FEC_NFU_Code';
import FEC_Tab_Case_Stage from '@salesforce/label/c.FEC_Tab_Case_Stage';
import FEC_Col_Active from '@salesforce/label/c.FEC_Col_Active';
import FEC_Required_Information from '@salesforce/label/c.FEC_Required_Information';
import FEC_Information from '@salesforce/label/c.FEC_Information';

import FEC_HCC_Name from '@salesforce/label/c.FEC_HCC_Name';
import FEC_Hold_Case_Type from '@salesforce/label/c.FEC_Hold_Case_Type';
import FEC_Current_Status from '@salesforce/label/c.FEC_Current_Status';
import FEC_Changed_Status from '@salesforce/label/c.FEC_Changed_Status';
import FEC_NFU_Reason_VN from '@salesforce/label/c.FEC_NFU_Reason_VN';
import FEC_Auto from '@salesforce/label/c.FEC_Auto';
import FEC_Manual from '@salesforce/label/c.FEC_Manual';
import FEC_Error_MessageError_For_Hold_Case from '@salesforce/label/c.FEC_Error_MessageError_For_Hold_Case';
import FEC_NFU_Modal_Error from '@salesforce/label/c.FEC_NFU_Modal_Error';
import FEC_NFU_Modal_Save_Error from '@salesforce/label/c.FEC_NFU_Modal_Save_Error';
import FEC_Hold_Case_Save_Success from '@salesforce/label/c.FEC_Hold_Case_Save_Success'; 
import FEC_Error_Manual from '@salesforce/label/c.FEC_Error_Manual'; 
import FEC_Hold_Case_Config from '@salesforce/label/c.FEC_Hold_Case_Config'; 
import FEC_New_Hold_Case_Config from '@salesforce/label/c.FEC_New_Hold_Case_Config';
import FEC_List_Of_NFU_Code from '@salesforce/label/c.FEC_List_Of_NFU_Code'; 

export default class Fec_HoldCaseConfiguration extends NavigationMixin(LightningElement) {

    @api recordId;

    @track holdCase = [];
    @track nfuOptions = [];
    @track selectedNfuRowsManual = [];
    @track parentHoldCase = [];
    @track isShowModal = false;
    @track isShowNfuModal = false;

    isLoading = false;

    // ================= LOOKUP DATA =================

    channelSearch = STR_EMPTY;
    channelOptions = [];
    showChannelDropdown = false;

    currentStatusSearch = STR_EMPTY;
    currentStatusOptions = [];
    showCurrentStatusDropdown = false;

    changedStatusSearch = STR_EMPTY;
    changedStatusOptions = [];
    showChangedStatusDropdown = false;

    channelSearchManual = STR_EMPTY;
    channelSelectedManual = [];

    showDropdownManual = false;

    nfuSearch = STR_EMPTY;
    nfuSearchManual = STR_EMPTY;
    nfuModalError = STR_EMPTY;
    caseStageName = STR_EMPTY;
    selectedNfuRow = null;

    activeSections = ['holdCase'];

    /* ================= LABEL ================= */
    customLabel = {
        hccName : FEC_HCC_Name,
        holdCaseType: FEC_Hold_Case_Type,
        channel: LBL_Channel_Col,
        currentStatus:FEC_Current_Status,
        changedStatus: FEC_Changed_Status,
        nfuCode: FEC_NFU_Code,
        caseStage: FEC_Tab_Case_Stage,
        active: FEC_Col_Active,
        nfuReasonVN: FEC_NFU_Reason_VN,
        auto: FEC_Auto,
        manual: FEC_Manual,
        errorMessageErrorForHoldCase: FEC_Error_MessageError_For_Hold_Case,
        nfuModalError: FEC_NFU_Modal_Error,
        nfuModalSaveError: FEC_NFU_Modal_Save_Error,
        holdCaseSaveSuccess: FEC_Hold_Case_Save_Success,
        errorManual: FEC_Error_Manual,
        holdCaseConfig: FEC_Hold_Case_Config,
        newHoldCaseConfig: FEC_New_Hold_Case_Config,
        requiredInformation: FEC_Required_Information,
        information: FEC_Information,
        listOfNFUCode: FEC_List_Of_NFU_Code
    }

    // ================= TABLE COLUMNS =================

    holdCaseColumns = [
        { label: this.customLabel.hccName, fieldName: 'name', type: 'link', recordIdField: 'Id' },
        { label: this.customLabel.holdCaseType, fieldName: 'holdCaseType' },
        { label: this.customLabel.channel, fieldName: 'channel' },
        { label: this.customLabel.currentStatus, fieldName: 'currentStatus' },
        { label: this.customLabel.changedStatus, fieldName: 'changedStatus' },
        { label: this.customLabel.nfuCode, fieldName: 'nfuCode' },
        { label: this.customLabel.caseStage, fieldName: 'caseStage' },
        { label: this.customLabel.active, fieldName: 'active' }
    ];

    nfuCodeColumns = [
        { label: this.customLabel.nfuCode, fieldName: 'FEC_NFU_Code__c' },
        { label: this.customLabel.nfuReasonVN, fieldName: 'FEC_NFU_Reason_VN__c' }
    ];

    // ================= FORM =================

    @track formData = {
        holdCaseType: STR_EMPTY,
        channels: STR_EMPTY,
        caseStage: STR_EMPTY,
        currentStatus: STR_EMPTY,
        changedStatus: STR_EMPTY,
        nfuCode: STR_EMPTY,
        active: false
    };

    // ================= OPTIONS =================

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
        nfuCode: this.customLabel.errorMessageErrorForHoldCase,
    };

    // ================= LIFECYCLE =================

    connectedCallback() {
        loadStyle(this, COMMON_STYLES)
            .then(() => {
                this.loadData();
            });
    }

    // ================= GETTERS =================

    get isAuto() {
        return this.formData.holdCaseType ===  this.customLabel.auto;
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

    get holdCaseDisplay() {
        return this.holdCase && this.holdCase.length > 0
            ? this.holdCase
            : [{}];
    }

    // ================= LOAD DATA =================

    loadData() {
        this.isLoading = true;

        Promise.all([
            getHoldCaseConfigurations({ recordId: this.recordId }),
            getParentHoldCaseConfigurations({ recordId: this.recordId })
        ])
        .then(([childResult, parentResult]) => {
            this.holdCase = childResult;
            this.parentHoldCase = parentResult;
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // ================= MAIN MODAL =================

    handleNew() {
        this.isShowModal = true;
    }

    handleCloseModal() {
        this.isShowModal = false;
        this.resetForm();
    }

    // ================= TYPE / ACTIVE =================

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
        this.channelSearch = STR_EMPTY;
        this.currentStatusSearch = STR_EMPTY;
        this.changedStatusSearch = STR_EMPTY;
        this.nfuSearch = STR_EMPTY;
        this.errors = { channel: STR_EMPTY, currentStatus: STR_EMPTY, changedStatus: STR_EMPTY, nfuCode: STR_EMPTY };
    }

    handleActiveChange(event) {
        this.formData.active = event.detail.checked;
    }

    handleStageChange(event) {

        this.formData.caseStage = event.detail.recordId;

        this.caseStageName = event.detail.value?.fields?.Name?.value || STR_EMPTY;
        
        const field = this.template.querySelector('[data-id="caseStage"]');

        if (field) {
            field.setCustomValidity(STR_EMPTY);
            field.reportValidity();
        }
    }

    // ================= CHANNEL =================

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
        this.showChannelDropdown = true;

        searchChannels({ keyword: this.channelSearch || STR_EMPTY })
            .then(result => {
                this.channelOptions = result;
            })
            .catch(error => console.error(error));
    }

    handleSelectChannel(event) {
        const el = event.target.closest('[data-id]');
        if (!el) return;

        this.formData.channels = el.dataset.id;
        this.channelSearch = el.dataset.name;
        this.showChannelDropdown = false;
        this.channelOptions = [];
        this.setLookupError('channel', false);
    }

    // ================= CURRENT STATUS =================

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
        this.formData.currentStatus = el.dataset.name;
        this.currentStatusSearch = el.dataset.name;
        this.showCurrentStatusDropdown = false;
        this.currentStatusOptions = [];
        this.setLookupError('currentStatus', false);
    }

    // ================= CHANGED STATUS =================

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

        this.formData.changedStatus = el.dataset.name;
        this.changedStatusSearch = el.dataset.name;
        this.showChangedStatusDropdown = false;
        this.changedStatusOptions = [];
        this.setLookupError('changedStatus', false);
    }

    // ================= NFU MODAL =================

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

        const selectedRow = this.nfuOptions.find(
            r => String(r.Id) === selectedId
        );

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

    // ================= VALIDATE =================

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

            if (!this.formData.channels) {
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

            if (!this.channelSelectedManual.length) {
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

    // ================= SAVE =================

    handleSave() {
        const isValid = this.validateForm();
        if (!isValid) return;

        const payload = {
            natureOfCaseId: this.recordId,
            holdCaseType: this.formData.holdCaseType,
            channel: this.isManual ? this.channelSelectedManual.map(i => i.name).join(', ') : this.channelSearch,
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
                this.loadData();
            })
            .catch(error => {
                console.error(error);
                const message = error?.body?.message;
                this.showError(message);
            });
    }

    handleSelectChannelManual(event) {
        const el = event.target.closest('[data-id]');
        if (!el) return;

        const id = el.dataset.id;
        const name = el.dataset.name;

        const exists = this.channelSelectedManual.find(i => i.id === id);

        if (!exists) {
            this.channelSelectedManual = [
                ...this.channelSelectedManual,
                { id, name }
            ];
        } else {
            this.channelSelectedManual = this.channelSelectedManual.filter(
                i => i.id !== id
            );
        }

        this.channelSearchManual = this.channelSelectedManual
            .map(i => i.name)
            .join(', ');

        this.showDropdownManual = false;
        this.setLookupError('channel', false);
    }

    handleChannelSearchManual(event) {
        this.channelSearchManual = event.target.value;

        if (!this.channelSearchManual) {
            this.channelOptions = [];
            this.showDropdownManual = false;
            return;
        }

        searchChannels({ keyword: this.channelSearchManual })
            .then(result => {
                this.channelOptions = result;
                this.showDropdownManual = result.length > 0;
            });
    }

    handleFocusManual() {
        searchChannels({ keyword: this.channelSearchManual || STR_EMPTY })
            .then(result => {
                this.channelOptions = result;
                this.showDropdownManual = result.length > 0;
            });
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

    // ================= RESET =================

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
        this.currentStatusSearch = STR_EMPTY;
        this.changedStatusSearch = STR_EMPTY;
        this.nfuSearch = STR_EMPTY;
        this.channelSearchManual = STR_EMPTY;
        this.channelSelectedManual = [];
        this.nfuSearchManual = STR_EMPTY;
        this.selectedNfuRowsManual = [];
        this.errors = { channel: STR_EMPTY, currentStatus: STR_EMPTY, changedStatus: STR_EMPTY, nfuCode: STR_EMPTY };
    }

    async handleHoldCaseConfigurationSelect(event) {

    const recordId = event.detail.recordId;

    const row = this.holdCase.find(
        r => r.Id === recordId
    );

    if (!row) {
        console.error('Hold Case not found:', recordId);
        return;
    }

    try {

        const tabInfo = await getFocusedTabInfo();

        const parentTabId = tabInfo.isSubtab
            ? tabInfo.parentTabId
            : tabInfo.tabId;

        await openSubtab(parentTabId, {

            pageReference: {
                type: 'standard__navItemPage',

                attributes: {
                    apiName: 'FEC_HoldCaseConfiguration'
                },

                state: {
                    c__recordId: row.Id,
                    uid: row.Id + '_' + Date.now()
                }
            },

            focus: true,
            label: row.name
        });

    } catch (error) {
        console.error(error);
    }
}

    // ================= TOAST =================

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