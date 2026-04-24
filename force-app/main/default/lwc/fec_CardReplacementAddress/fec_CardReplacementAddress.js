import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, createRecord, updateRecord, deleteRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import ACCOUNT_OR_CONTRACT_FIELD from "@salesforce/schema/Case.FEC_Account_or_Contract__c";
import SELECTED_ADDRESS_FIELD from "@salesforce/schema/Case.FEC_Selected_Address__c";

import FEC_LBL_ContractClosure_Add_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Add_Temp_Address';
import FEC_LBL_ContractClosure_Modal_New_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Modal_New_Temp_Address';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Btn_Cancel from '@salesforce/label/c.FEC_Btn_Cancel';
import FEC_LBL_Province_City from '@salesforce/label/c.FEC_LBL_Province_City';
import FEC_LBL_ContractClosure_Ward from '@salesforce/label/c.FEC_LBL_ContractClosure_Ward';
import FEC_LBL_ContractClosure_Address_Type from '@salesforce/label/c.FEC_LBL_ContractClosure_Address_Type';
import FEC_LBL_ContractClosure_Building from '@salesforce/label/c.FEC_LBL_ContractClosure_Building';
import FEC_LBL_ContractClosure_Street from '@salesforce/label/c.FEC_LBL_ContractClosure_Street';
import FEC_LBL_ContractClosure_Street_Number from '@salesforce/label/c.FEC_LBL_ContractClosure_Street_Number';

import getProvinceOptionsForAddress from '@salesforce/apex/FEC_CardReplacementAddressController.getProvinceOptionsForAddress';
import getWardOptionsForProvinceCode from '@salesforce/apex/FEC_CardReplacementAddressController.getWardOptionsForProvinceCode';
import getAddressInfos from '@salesforce/apex/FEC_CardReplacementAddressController.getAddressInfos';
import getCountryId from '@salesforce/apex/FEC_CardReplacementAddressController.getCountryId';

export default class Fec_CardReplacementAddress extends LightningElement {
    @api recordId;
    @track addressInfos = [];
    @api isEdit;
    @api isHiddenLwc;

    isModalOpen = false;
    provinceOptions = [];
    wardOptions = [];
    mailingCity;
    mailingWard;
    isLoading = false;
    isDisableBtnAddTempAddress = false;
    addressType = 'Temporary Address';
    addressTypeOptions = [
        { label: 'Temporary Address', value: 'Temporary Address' },
    ];
    newTempAddressOptions;
    newAddressInfoId;
    building;
    numberValue;
    street;
    selectedRows = [];
    newSelectedAddressId;

    customLabel = {
        btnAddTempAddress: FEC_LBL_ContractClosure_Add_Temp_Address,
        modalHeader: FEC_LBL_ContractClosure_Modal_New_Temp_Address,
        btnSave: FEC_Button_Save,
        btnCancel: FEC_Btn_Cancel,
        provinceCity: FEC_LBL_Province_City,
        ward: FEC_LBL_ContractClosure_Ward,
        addressType: FEC_LBL_ContractClosure_Address_Type,
        building: FEC_LBL_ContractClosure_Building,
        street: FEC_LBL_ContractClosure_Street,
        number: FEC_LBL_ContractClosure_Street_Number,
        newTempAddress: FEC_LBL_ContractClosure_Modal_New_Temp_Address,
    }

    columns = [
        { label: this.customLabel.addressType, fieldName: 'FEC_Address_Type__c' },
        { label: 'Address', fieldName: 'FEC_Full_Address__c' },
        { label: 'Mailing Address', fieldName: 'mailingAddressLabel' },
    ];

    @wire(getRecord, { recordId: "$recordId", fields: [ACCOUNT_OR_CONTRACT_FIELD, SELECTED_ADDRESS_FIELD] })
    objCase;

    get customerHistoryId() {
        return getFieldValue(this.objCase.data, ACCOUNT_OR_CONTRACT_FIELD);
    }

    get selectedAddressId() {
        return getFieldValue(this.objCase.data, SELECTED_ADDRESS_FIELD);
    }

    get isDisable() {
        return !this.isEdit || this.isDisableBtnAddTempAddress;
    }

    get disabledRows() {
        let rows = [];
        if (this.isDisable && this.addressInfos && this.addressInfos.length) {
            this.addressInfos.forEach(info => {
                rows.push(info.Id);
            });
        }
        return rows;
    }

    connectedCallback() {
        this.handleGetAddressInfos();

        getProvinceOptionsForAddress()
        .then((provinces) => {
            const mapped = (provinces || []).map((o) => ({
                label: o.label != null ? o.label : o.Label,
                value: o.value != null ? o.value : o.Value
            }));
            this.provinceOptions = mapped;
        })
        .catch((error) => {
            console.log(error);
        });
    }

    handleGetAddressInfos() {
        getAddressInfos({ caseId: this.recordId })
        .then((addressInfos) => {
            this.addressInfos = addressInfos.map(item => {
                return {
                    ...item,
                    mailingAddressLabel: item.FEC_Mailing_Address__c ? 'Yes' : 'No'
                };
            });
            if (this.selectedAddressId) {
                this.selectedRows = [this.selectedAddressId];
                this.newSelectedAddressId = this.selectedAddressId;
            }
        })
        .catch((error) => {
            console.log(error);
        });
    }

    handleMailingProvinceChange(e) {
        const val = e.detail.value;
        this.mailingCity = val;
        this.mailingWard = '';
        this.wardOptions = [];
        if (!val) {
            return;
        }
        getWardOptionsForProvinceCode({ provinceId: val })
        .then((wards) => {
            const opts = (wards || []).map((w) => ({
                label: w.label,
                value: w.value
            }));
            this.wardOptions = opts;
        })
        .catch((error) => {
            console.log(error);
        });
    }
    
    handleMailingWardChange(e) {
        this.mailingWard = e.detail.value;
    }

    handleAddTempAddress() {
        this.isModalOpen = true;
        this.building = '';
        this.numberValue = '';
        this.street = '';
        this.mailingWard = '';
        this.mailingCity = '';
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    newAddressFormReportValidity() {
        const root = this.template.querySelector('.case-info__new-address-form');
        if (!root) {
            return true;
        }
        const fields = [
            ...root.querySelectorAll('lightning-input'),
            ...root.querySelectorAll('c-fec_searchable-combobox')
        ];
        let valid = true;
        fields.forEach((f) => {
            if (typeof f.reportValidity === 'function' && !f.reportValidity()) {
                valid = false;
            }
        });
        return valid;
    }

    async handleSave() {
        if (!this.newAddressFormReportValidity()) {
            return;
        }
        this.isLoading = true;
        const root = this.template.querySelector('.case-info__new-address-form');
        this.building = root.querySelector('lightning-input[data-id="building"]').value;
        this.numberValue = root.querySelector('lightning-input[data-id="number"]').value;
        this.street = root.querySelector('lightning-input[data-id="street"]').value;
        const ward = this.wardOptions.find(w => w.value === this.mailingWard)?.label;
        const province = this.provinceOptions.find(p => p.value === this.mailingCity)?.label;
        const address = this.building + ', ' + this.numberValue + ' ' + this.street + ', ' + ward + ', ' + province;
        const countryId = await getCountryId();
        const fields = {
            'FEC_Case__c': this.recordId,
            'FEC_Customer_History__c': this.customerHistoryId,
            'FEC_Address_Type__c': this.addressType,
            'FEC_Address__c': address,
            'FEC_Mailing_Address__c': true,
            'FEC_Country__c': countryId,
            'FEC_Province__c': this.mailingCity,
            'FEC_District__c': this.mailingWard,
            'FEC_Building__c': this.building,
            'FEC_Number__c': this.numberValue,
            'FEC_Street__c': this.street,
        };
        try {
            if (this.newAddressInfoId) {
                delete fields['FEC_Customer_History__c'];
                fields['Id'] = this.newAddressInfoId;
                const recordUpdate = { fields };
                await updateRecord(recordUpdate);
            } else {
                const recordInput = { apiName: 'FEC_Address_Info__c', fields };
                const addressInfo = await createRecord(recordInput);
                this.newAddressInfoId = addressInfo.id;
            }
            this.isModalOpen = false;
            this.isDisableBtnAddTempAddress = true;
            this.newTempAddressOptions = [
                { label: address, value: this.newAddressInfoId }
            ];
            this.selectedRows = [];
            this.newSelectedAddressId = this.newAddressInfoId;
        } catch (error) {
            this.showToast('Error', this.handleError(error), 'error');
            console.log(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleEditTempAddress() {
        this.isModalOpen = true;
    }

    async handleDeleteTempAddress() {
        this.isLoading = true;
        try {
            await deleteRecord(this.newAddressInfoId);
            this.isDisableBtnAddTempAddress = false;
            this.newAddressInfoId = '';
            this.newSelectedAddressId = '';
        } catch (error) {
            this.showToast('Error', this.handleError(error), 'error');
            console.log(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleError(error) {
        let msg = '';
        if (Array.isArray(error?.body)) {
            msg = error.body.map(e => e.message).join(', ');
        } else if (typeof error?.body?.message === 'string') {
            msg = error.body.message;
        }
        return msg;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    @api getAddressSelectedId() {
        return this.newSelectedAddressId;
    }

    handleRowSelect(event) {
        const selectedRows = event.detail.selectedRows;
        this.newSelectedAddressId = selectedRows[0].Id;
    }
}