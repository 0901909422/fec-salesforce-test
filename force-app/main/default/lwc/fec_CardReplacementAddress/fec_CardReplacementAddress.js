import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, createRecord } from "lightning/uiRecordApi";

import ACCOUNT_OR_CONTRACT_FIELD from "@salesforce/schema/Case.FEC_Account_or_Contract__c";

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

import getProvinceOptionsForAddress from '@salesforce/apex/FEC_MainInfoController.getProvinceOptionsForAddress';
import getWardOptionsForProvinceCode from '@salesforce/apex/FEC_MainInfoController.getWardOptionsForProvinceCode';
import getAddressInfos from '@salesforce/apex/FEC_CardReplacementAddressController.getAddressInfos';

export default class Fec_CardReplacementAddress extends LightningElement {
    @api recordId;
    @track addressInfos = [];

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
    }

    columns = [
        { label: this.customLabel.addressType, fieldName: 'FEC_Address_Type__c' },
        { label: 'Address', fieldName: 'FEC_Address__c' },
        { label: 'Mailing Address', fieldName: 'FEC_Mailing_Address__c' },
    ];

    @wire(getRecord, { recordId: "$recordId", fields: [ACCOUNT_OR_CONTRACT_FIELD] })
    objCase;

    get customerHistoryId() {
        return getFieldValue(this.objCase.data, ACCOUNT_OR_CONTRACT_FIELD);
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
            this.addressInfos = addressInfos;
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
        getWardOptionsForProvinceCode({ provinceCode: val })
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

    handleClick() {
        this.isModalOpen = true;
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
        const building = root.querySelector('lightning-input[data-id="building"]').value;
        const number = root.querySelector('lightning-input[data-id="number"]').value;
        const street = root.querySelector('lightning-input[data-id="street"]').value;
        const ward = this.wardOptions.find(w => w.value === this.mailingWard)?.label;
        const province = this.provinceOptions.find(p => p.value === this.mailingCity)?.label;
        const address = building + ', ' + number + ' ' + street + ', ' + ward + ', ' + province;
        const fields = {
            'FEC_Customer_History__c': this.customerHistoryId,
            'FEC_Address_Type__c': this.addressType,
            'FEC_Address__c': address,
            'FEC_Mailing_Address__c': true,
        };
        const recordInput = { apiName: 'FEC_Address_Info__c', fields };
        try {
            // Invoke createRecord
            const addressInfo = await createRecord(recordInput);
            console.log(JSON.stringify(addressInfo));
            this.handleGetAddressInfos();
            this.isModalOpen = false;
            this.isDisableBtnAddTempAddress = true;
        } catch (error) {
            console.log(error);
        } finally {
            this.isLoading = false;
        }
    }

}