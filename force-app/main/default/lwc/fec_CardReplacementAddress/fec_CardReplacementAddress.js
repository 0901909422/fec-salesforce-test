import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
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
import getAddressInfo from '@salesforce/apex/FEC_CardReplacementAddressController.getAddressInfo';
import getCaseTemporaryAddressInfo from '@salesforce/apex/FEC_CardReplacementAddressController.getCaseTemporaryAddressInfo';
import createAddressInfo from '@salesforce/apex/FEC_CardReplacementAddressController.createAddressInfo';
import updateAddressInfo from '@salesforce/apex/FEC_CardReplacementAddressController.updateAddressInfo';
import deleteAddressInfo from '@salesforce/apex/FEC_CardReplacementAddressController.deleteAddressInfo';
import updateCaseSelectedAddress from '@salesforce/apex/FEC_CardReplacementAddressController.updateCaseSelectedAddress';

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
    addressInfoValue;

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
    wiredCase(result) {
        this.objCase = result;
        if (result?.data) {
            this.loadAddressData();
        }
    }

    objCase;

    get customerHistoryId() {
        return getFieldValue(this.objCase?.data, ACCOUNT_OR_CONTRACT_FIELD);
    }

    get selectedAddressId() {
        return getFieldValue(this.objCase?.data, SELECTED_ADDRESS_FIELD);
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
        if (this.recordId) {
            this.loadAddressData();
        }
    }

    formatAddressLabel(addressInfo) {
        if (!addressInfo) {
            return '';
        }
        return (
            addressInfo.FEC_Full_Address__c ||
            addressInfo.FEC_Address__c ||
            ''
        );
    }

    applyTemporaryAddressDisplay(addressInfo) {
        if (!addressInfo?.Id) {
            return;
        }
        this.isDisableBtnAddTempAddress = true;
        this.newAddressInfoId = addressInfo.Id;
        this.addressInfoValue = addressInfo.Id;
        this.newSelectedAddressId = addressInfo.Id;
        this.newTempAddressOptions = [
            {
                label: this.formatAddressLabel(addressInfo),
                value: addressInfo.Id,
            },
        ];
    }

    async hydrateTemporaryAddressDisplay(addressInfos) {
        const list = addressInfos || [];
        const selectedId = this.selectedAddressId;
        if (selectedId && list.some((address) => address.Id === selectedId)) {
            this.selectedRows = [selectedId];
            this.newSelectedAddressId = selectedId;
            return;
        }

        let tempRecord = null;
        try {
            if (selectedId) {
                tempRecord = await getAddressInfo({ addressId: selectedId });
            } else {
                tempRecord = await getCaseTemporaryAddressInfo({
                    caseId: this.recordId,
                });
            }
        } catch (err) {
            console.log(err);
            return;
        }

        if (tempRecord?.Id) {
            this.applyTemporaryAddressDisplay(tempRecord);
            if (!this.isEdit) {
                this.selectedRows = [tempRecord.Id];
            }
        }
    }

    loadAddressData() {
        if (!this.recordId) {
            return;
        }
        getAddressInfos({ caseId: this.recordId })
            .then(async (addressInfos) => {
                this.addressInfos = (addressInfos || []).map((item) => ({
                    ...item,
                    mailingAddressLabel: item.FEC_Mailing_Address__c ? 'Yes' : 'No',
                }));
                await this.hydrateTemporaryAddressDisplay(this.addressInfos);
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
        const addressInput = {
            caseId: this.recordId,
            customerHistoryId: this.customerHistoryId,
            addressType: this.addressType,
            address,
            countryId,
            provinceId: this.mailingCity,
            districtId: this.mailingWard,
            building: this.building,
            numberValue: this.numberValue,
            street: this.street
        };
        try {
            if (this.newAddressInfoId) {
                await updateAddressInfo({
                    input: {
                        ...addressInput,
                        addressInfoId: this.newAddressInfoId
                    }
                });
            } else {
                this.newAddressInfoId = await createAddressInfo({ input: addressInput });
            }
            await updateCaseSelectedAddress({
                caseId: this.recordId,
                selectedAddressId: this.newAddressInfoId,
            });
            this.isModalOpen = false;
            this.applyTemporaryAddressDisplay({
                Id: this.newAddressInfoId,
                FEC_Address__c: address,
                FEC_Full_Address__c: address,
            });
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
            await deleteAddressInfo({ addressInfoId: this.newAddressInfoId });
            await updateCaseSelectedAddress({
                caseId: this.recordId,
                selectedAddressId: null,
            });
            this.isDisableBtnAddTempAddress = false;
            this.newAddressInfoId = '';
            this.newSelectedAddressId = '';
            this.newTempAddressOptions = undefined;
            this.addressInfoValue = undefined;
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