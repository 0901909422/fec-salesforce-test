import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_MSG_ContractClosure_Required_Fields from '@salesforce/label/c.FEC_MSG_ContractClosure_Required_Fields';
import FEC_MSG_ContractClosure_Phone_Invalid from '@salesforce/label/c.FEC_MSG_ContractClosure_Phone_Invalid';
import FEC_MSG_ContractClosure_Delivery_Invalid from '@salesforce/label/c.FEC_MSG_ContractClosure_Delivery_Invalid';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Email_Label from '@salesforce/label/c.FEC_Email_Label';
import FEC_LBL_Province_City from '@salesforce/label/c.FEC_LBL_Province_City';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Button_Cancel from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_Alt_Edit from '@salesforce/label/c.FEC_Alt_Edit';
import FEC_Alt_Remove from '@salesforce/label/c.FEC_Alt_Remove';
import LBL_SortBy from '@salesforce/label/c.LBL_SortBy';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';
import FEC_LBL_ContractClosure_Add_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Add_Temp_Address';
import FEC_LBL_ContractClosure_Add_Temp_Email from '@salesforce/label/c.FEC_LBL_ContractClosure_Add_Temp_Email';
import FEC_LBL_ContractClosure_Address_Col from '@salesforce/label/c.FEC_LBL_ContractClosure_Address_Col';
import FEC_LBL_ContractClosure_Address_Type from '@salesforce/label/c.FEC_LBL_ContractClosure_Address_Type';
import FEC_LBL_ContractClosure_Building from '@salesforce/label/c.FEC_LBL_ContractClosure_Building';
import FEC_LBL_ContractClosure_Delivery_Option from '@salesforce/label/c.FEC_LBL_ContractClosure_Delivery_Option';
import FEC_LBL_ContractClosure_Mailing_Address_Col from '@salesforce/label/c.FEC_LBL_ContractClosure_Mailing_Address_Col';
import FEC_LBL_ContractClosure_Modal_Edit_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Modal_Edit_Temp_Address';
import FEC_LBL_ContractClosure_Modal_New_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Modal_New_Temp_Address';
import FEC_LBL_ContractClosure_New_Temp_Email from '@salesforce/label/c.FEC_LBL_ContractClosure_New_Temp_Email';
import FEC_LBL_ContractClosure_Recipient_Name from '@salesforce/label/c.FEC_LBL_ContractClosure_Recipient_Name';
import FEC_LBL_ContractClosure_Recipient_Phone from '@salesforce/label/c.FEC_LBL_ContractClosure_Recipient_Phone';
import FEC_LBL_ContractClosure_Street from '@salesforce/label/c.FEC_LBL_ContractClosure_Street';
import FEC_LBL_ContractClosure_Street_Number from '@salesforce/label/c.FEC_LBL_ContractClosure_Street_Number';
import FEC_LBL_ContractClosure_Ward from '@salesforce/label/c.FEC_LBL_ContractClosure_Ward';
import FEC_MSG_ContractClosure_No_C360_Email from '@salesforce/label/c.FEC_MSG_ContractClosure_No_C360_Email';
import FEC_Placeholder_ContractClosure_Select_Delivery from '@salesforce/label/c.FEC_Placeholder_ContractClosure_Select_Delivery';
import FEC_Placeholder_ContractClosure_Select_Admin from '@salesforce/label/c.FEC_Placeholder_ContractClosure_Select_Admin';

import getInitData from '@salesforce/apex/FEC_ContractClosureController.getInitData';
import validateForComplete from '@salesforce/apex/FEC_ContractClosureController.validateForComplete';
import saveForm from '@salesforce/apex/FEC_ContractClosureController.saveForm';
import saveFormDraft from '@salesforce/apex/FEC_ContractClosureController.saveFormDraft';
import upsertTemporaryAddress from '@salesforce/apex/FEC_ContractClosureController.upsertTemporaryAddress';
import deleteTemporaryAddressRecord from '@salesforce/apex/FEC_ContractClosureController.deleteTemporaryAddressRecord';
import searchAdministrativeUnits from '@salesforce/apex/FEC_ContractClosureController.searchAdministrativeUnits';

import {
    STR_EMPTY,
    PATTERN_PHONE_VN_FEC,
    CONTRACT_CLOSURE_EMAIL_CHANNEL_C360,
    CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
    CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
    CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT,
    CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT
} from 'c/fec_CommonConst';
import { normalizePhone } from 'c/fec_CommonUtils';

const CC_ADDRESS_TABLE_ITEM = 'item';
const CC_ADDRESS_TABLE_ITEMS = 'items';
const CC_ADDRESS_TABLE_SORTED_SUFFIX = ' • Sorted by Address Type';
const CC_ASSISTIVE_TABLE_SELECTION = 'Selection';
const CC_TEMP_EMAIL_RADIO_FALLBACK = 'Temporary email';
const CC_MSG_LOAD_FAILED = 'Load failed';

export default class Fec_ContractClosureForm extends LightningElement {
    @api recordId;
    /** Từ cha (vd. fec_CaseBussiness lwc:component is-edit). undefined = hiển thị như cũ (Record Page). */
    @api isEdit;

    /** false = chế độ xem: vẫn render form + dữ liệu; không validate/gọi save từ đây. */
    get isClosureEditable() {
        return this.isEdit !== false;
    }

    get closureFieldsReadonly() {
        return this.isEdit === false;
    }

    get closureFieldRequired() {
        return this.isClosureEditable;
    }

    loading = true;
    loadError;
    demographicEmail;
    demographicCustomerName;
    demographicPrimaryPhone;
    deliveryOptions = [];
    savedDeliveryOption;

    deliveryEmailSelected = false;
    deliveryAddressSelected = false;
    deliveryOfficeSelected = false;

    useExistingEmail = false;
    showTempEmailRow = false;
    temporaryEmail = STR_EMPTY;

    recipientName = STR_EMPTY;
    recipientPhone = STR_EMPTY;

    addresses = [];

    wiredInitResult;
    selectedAddressRowId;
    addrRenderKey = 0;

    addressSortAsc = true;

    temporaryAddressDisplay = STR_EMPTY;
    tempAddressRecordId;
    disableAddTempAddress = false;

    showTempAddressModal = false;
    modalBuilding = STR_EMPTY;
    modalNumber = STR_EMPTY;
    modalStreet = STR_EMPTY;
    modalWardId = STR_EMPTY;
    modalWardLabel = STR_EMPTY;
    modalProvinceId = STR_EMPTY;
    modalProvinceLabel = STR_EMPTY;
    wardOptions = [];
    provinceOptions = [];

    lastValidationMessages = [];
    showValidateBanner = false;

    lastTempAddressParts;
    tempAddressModalIsEdit = false;

    customLabel = {
        errorTitle: FEC_Error_Title,
        successTitle: FEC_Success_Title,
        loadingAlt: FEC_Termination_Loading_Alt,
        emailLabel: FEC_Email_Label,
        provinceCityLabel: FEC_LBL_Province_City,
        saveBtn: FEC_Button_Save,
        cancelBtn: FEC_Button_Cancel,
        toastSaveSuccess: FEC_Toast_Save_Success,
        altEdit: FEC_Alt_Edit,
        altRemove: FEC_Alt_Remove,
        addTempAddress: FEC_LBL_ContractClosure_Add_Temp_Address,
        addTempEmail: FEC_LBL_ContractClosure_Add_Temp_Email,
        addressCol: FEC_LBL_ContractClosure_Address_Col,
        addressType: FEC_LBL_ContractClosure_Address_Type,
        building: FEC_LBL_ContractClosure_Building,
        deliveryOption: FEC_LBL_ContractClosure_Delivery_Option,
        mailingAddressCol: FEC_LBL_ContractClosure_Mailing_Address_Col,
        modalEditTempAddress: FEC_LBL_ContractClosure_Modal_Edit_Temp_Address,
        modalNewTempAddress: FEC_LBL_ContractClosure_Modal_New_Temp_Address,
        newTempEmail: FEC_LBL_ContractClosure_New_Temp_Email,
        recipientName: FEC_LBL_ContractClosure_Recipient_Name,
        recipientPhone: FEC_LBL_ContractClosure_Recipient_Phone,
        street: FEC_LBL_ContractClosure_Street,
        streetNumber: FEC_LBL_ContractClosure_Street_Number,
        ward: FEC_LBL_ContractClosure_Ward,
        msgNoC360Email: FEC_MSG_ContractClosure_No_C360_Email,
        placeholderDelivery: FEC_Placeholder_ContractClosure_Select_Delivery,
        placeholderAdmin: FEC_Placeholder_ContractClosure_Select_Admin
    };

    /** Thông báo validate / toast — đồng bộ Custom Label, dễ tra trong template. */
    validationLabels = {
        requiredFields: FEC_MSG_ContractClosure_Required_Fields,
        phoneInvalid: FEC_MSG_ContractClosure_Phone_Invalid,
        deliveryRequired: FEC_MSG_ContractClosure_Delivery_Invalid
    };

    resolvedEmailValue;
    resolvedAddressValue;
    resolvedOfficeValue;

    addressTypeTemporaryLabel = CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY;

    get emailRadioOptions() {
        const opts = [];
        if (this.hasDemographicEmail) {
            opts.push({
                label: this.demographicEmail,
                value: 'c360'
            });
        }
        if (this.showTempEmailRow) {
            const t = (this.temporaryEmail || STR_EMPTY).trim();
            opts.push({
                label: t || CC_TEMP_EMAIL_RADIO_FALLBACK,
                value: 'temp'
            });
        }
        return opts;
    }

    get hasEmailRadioOptions() {
        return (this.emailRadioOptions || []).length > 0;
    }

    get showNoC360EmailHint() {
        return !this.hasDemographicEmail && !this.showTempEmailRow;
    }

    get emailRadioValue() {
        if (this.showTempEmailRow && !this.useExistingEmail) {
            return 'temp';
        }
        if (this.hasDemographicEmail && this.useExistingEmail) {
            return 'c360';
        }
        if (this.hasDemographicEmail && !this.showTempEmailRow) {
            return 'c360';
        }
        if (this.showTempEmailRow) {
            return 'temp';
        }
        return STR_EMPTY;
    }

    get addressTableMeta() {
        const n = (this.addresses || []).length;
        const unit = n === 1 ? CC_ADDRESS_TABLE_ITEM : CC_ADDRESS_TABLE_ITEMS;
        return n + ' ' + unit + CC_ADDRESS_TABLE_SORTED_SUFFIX;
    }

    get addressSortIconName() {
        return this.addressSortAsc ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get sortAddressTypeAlt() {
        return LBL_SortBy + ' ' + this.customLabel.addressType;
    }

    get selectionAssistiveText() {
        return CC_ASSISTIVE_TABLE_SELECTION;
    }

    get tempAddressFieldLabel() {
        return CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY;
    }

    handleEmailRadioChange(event) {
        if (this.closureFieldsReadonly) {
            return;
        }
        const v = event.detail.value;
        if (v === 'c360') {
            this.useExistingEmail = true;
            this.showTempEmailRow = false;
            this.temporaryEmail = STR_EMPTY;
        } else if (v === 'temp') {
            this.useExistingEmail = false;
            this.showTempEmailRow = true;
        }
    }

    handleToggleAddressSort() {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.addressSortAsc = !this.addressSortAsc;
    }

    @wire(getInitData, { caseId: '$recordId' })
    wiredInit(result) {
        this.wiredInitResult = result;
        this.loading = false;
        const { data, error } = result;
        if (data) {
            if (!data.success) {
                this.loadError = data.errorMessage || CC_MSG_LOAD_FAILED;
                return;
            }
            this.loadError = undefined;
            this.demographicEmail = data.demographicEmail || STR_EMPTY;
            this.demographicCustomerName = data.demographicCustomerName || STR_EMPTY;
            this.demographicPrimaryPhone = data.demographicPrimaryPhone || STR_EMPTY;
            this.deliveryOptions = data.deliveryOptions || [];
            this.savedDeliveryOption = data.savedDeliveryOption || STR_EMPTY;
            this.addresses = data.addresses || [];
            this.resolveDeliveryMeta();
            this.applySavedDelivery();
            this.recipientName =
                data.savedRecipientName || this.demographicCustomerName || STR_EMPTY;
            this.recipientPhone =
                data.savedRecipientPhone || this.demographicPrimaryPhone || STR_EMPTY;
            if (data.savedTemporaryEmail) {
                this.temporaryEmail = data.savedTemporaryEmail;
                this.showTempEmailRow = true;
                this.useExistingEmail = false;
            } else if ((data.demographicEmail || STR_EMPTY).trim()) {
                this.useExistingEmail = true;
            }
            this.syncTemporaryAddressFromAddressRows();
        } else if (error) {
            this.loadError = error.body ? error.body.message : String(error);
        }
    }

    resolveDeliveryMeta() {
        const emailO = this.pickDeliveryMeta('EMAIL');
        const addrO = this.pickDeliveryMeta('ADDRESS');
        const offO = this.pickDeliveryMeta('OFFICE');
        this.resolvedEmailValue = emailO ? emailO.value : this.customLabel.emailLabel;
        this.resolvedAddressValue = addrO ? addrO.value : CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT;
        this.resolvedOfficeValue = offO ? offO.value : CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT;
    }

    pickDeliveryMeta(kind) {
        const opts = this.deliveryOptions || [];
        if (kind === 'EMAIL') {
            return opts.find(
                (o) =>
                    /email/i.test(o.label || STR_EMPTY) ||
                    /^email$/i.test(o.value || STR_EMPTY)
            );
        }
        if (kind === 'ADDRESS') {
            return opts.find(
                (o) =>
                    /địa\s*chỉ|dia\s*chi/i.test((o.label || STR_EMPTY).toLowerCase()) ||
                    /địa\s*chỉ|dia\s*chi/i.test((o.value || STR_EMPTY).toLowerCase())
            );
        }
        if (kind === 'OFFICE') {
            return opts.find(
                (o) =>
                    /văn\s*phòng|van\s*phong/i.test((o.label || STR_EMPTY).toLowerCase()) ||
                    /văn\s*phòng|van\s*phong/i.test((o.value || STR_EMPTY).toLowerCase())
            );
        }
        return undefined;
    }

    applySavedDelivery() {
        const s = this.savedDeliveryOption;
        if (!s) {
            return;
        }
        const parts = s.split(';').map((x) => x.trim()).filter(Boolean);
        parts.forEach((p) => {
            if (this.resolvedEmailValue && p === this.resolvedEmailValue) {
                this.deliveryEmailSelected = true;
            }
            if (this.resolvedAddressValue && p === this.resolvedAddressValue) {
                this.deliveryAddressSelected = true;
            }
            if (this.resolvedOfficeValue && p === this.resolvedOfficeValue) {
                this.deliveryOfficeSelected = true;
            }
        });
    }

    get deliveryPicklistOptions() {
        const rows = [];
        const ev = this.resolvedEmailValue;
        const av = this.resolvedAddressValue;
        const ov = this.resolvedOfficeValue;
        if (ev) {
            rows.push({ label: this.labelEmail, value: ev });
        }
        if (av) {
            rows.push({ label: this.labelAddress, value: av });
        }
        if (ov) {
            rows.push({ label: this.labelOffice, value: ov });
        }
        return rows;
    }

    get selectedDeliveryValues() {
        const vals = [];
        if (this.deliveryEmailSelected && this.resolvedEmailValue) {
            vals.push(this.resolvedEmailValue);
        }
        if (this.deliveryAddressSelected && this.resolvedAddressValue) {
            vals.push(this.resolvedAddressValue);
        }
        if (this.deliveryOfficeSelected && this.resolvedOfficeValue) {
            vals.push(this.resolvedOfficeValue);
        }
        return vals;
    }

    handlePicklistChange(event) {
        if (this.closureFieldsReadonly) {
            return;
        }
        let ids = event.detail && event.detail.ids ? [...event.detail.ids] : [];
        const av = this.resolvedAddressValue;
        const ov = this.resolvedOfficeValue;
        const hasA = av && ids.includes(av);
        const hasO = ov && ids.includes(ov);
        if (hasA && hasO) {
            const hadA = this.deliveryAddressSelected;
            const hadO = this.deliveryOfficeSelected;
            if (hadA && !hadO) {
                ids = ids.filter((v) => v !== av);
            } else if (hadO && !hadA) {
                ids = ids.filter((v) => v !== ov);
            } else {
                ids = ids.filter((v) => v !== ov);
            }
        }
        const ev = this.resolvedEmailValue;
        this.deliveryEmailSelected = !!(ev && ids.includes(ev));
        this.deliveryAddressSelected = !!(av && ids.includes(av));
        this.deliveryOfficeSelected = !!(ov && ids.includes(ov));
    }

    get labelEmail() {
        const o = this.pickDeliveryMeta('EMAIL');
        return o ? o.label : this.customLabel.emailLabel;
    }

    get labelAddress() {
        const o = this.pickDeliveryMeta('ADDRESS');
        return o ? o.label : CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT;
    }

    get labelOffice() {
        const o = this.pickDeliveryMeta('OFFICE');
        return o ? o.label : CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT;
    }

    get lockAddTempEmailBtn() {
        return this.disableAddTempEmail || this.closureFieldsReadonly;
    }

    get lockAddTempAddrBtn() {
        return this.disableAddTempAddress || this.closureFieldsReadonly;
    }

    get validationMessageItems() {
        return (this.lastValidationMessages || []).map((text, index) => ({
            key: 'v' + index,
            text
        }));
    }

    get showEmailSection() {
        return this.deliveryEmailSelected === true;
    }

    get showAddressSection() {
        return (
            this.deliveryAddressSelected === true ||
            (this.deliveryEmailSelected === true &&
                this.deliveryOfficeSelected === true)
        );
    }

    get hasDemographicEmail() {
        return !!(this.demographicEmail && String(this.demographicEmail).trim());
    }

    get disableAddTempEmail() {
        return this.showTempEmailRow === true;
    }

    get addressRows() {
        const sel = this.selectedAddressRowId;
        const rows = [...(this.addresses || [])];
        const asc = this.addressSortAsc;
        rows.sort((a, b) => {
            const cmp = (a.addressType || STR_EMPTY).localeCompare(
                b.addressType || STR_EMPTY,
                undefined,
                { sensitivity: 'base' }
            );
            return asc ? cmp : -cmp;
        });
        return rows.map((r) => ({
            ...r,
            selected: r.id === sel
        }));
    }

    get tempAddressModalTitle() {
        return this.tempAddressModalIsEdit
            ? this.customLabel.modalEditTempAddress
            : this.customLabel.modalNewTempAddress;
    }

    syncTemporaryAddressFromAddressRows() {
        const rows = this.addresses || [];
        const tempRow = rows.find((a) => /temporary/i.test(a.addressType || STR_EMPTY));
        if (!tempRow) {
            this.tempAddressRecordId = undefined;
            this.temporaryAddressDisplay = STR_EMPTY;
            this.disableAddTempAddress = false;
            this.lastTempAddressParts = undefined;
            return;
        }
        this.tempAddressRecordId = tempRow.id;
        this.temporaryAddressDisplay = tempRow.address || STR_EMPTY;
        this.disableAddTempAddress = true;
    }

    resolveEmailDeliveryChannel() {
        if (!this.deliveryEmailSelected) {
            return STR_EMPTY;
        }
        const tempMail = (this.temporaryEmail || STR_EMPTY).trim();
        if ((this.demographicEmail || STR_EMPTY).trim()) {
            if (this.useExistingEmail) {
                return CONTRACT_CLOSURE_EMAIL_CHANNEL_C360;
            }
            return tempMail ? CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY : STR_EMPTY;
        }
        return tempMail ? CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY : STR_EMPTY;
    }

    handleAddTempEmail() {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.useExistingEmail = false;
        this.showTempEmailRow = true;
    }

    handleRemoveTempEmail() {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.showTempEmailRow = false;
        this.temporaryEmail = STR_EMPTY;
        if (this.hasDemographicEmail) {
            this.useExistingEmail = true;
        }
    }

    handleTempEmailChange(event) {
        this.temporaryEmail = event.target.value;
    }

    handleRecipientNameChange(event) {
        this.recipientName = event.target.value;
    }

    handleRecipientPhoneChange(event) {
        this.recipientPhone = event.target.value;
        const inp = this.template.querySelector('lightning-input[data-fec-field="recipientPhone"]');
        if (inp) {
            inp.setCustomValidity('');
        }
    }

    applyRecipientPhoneCustomValidity() {
        const inp = this.template.querySelector('lightning-input[data-fec-field="recipientPhone"]');
        if (!inp) {
            return null;
        }
        const n = normalizePhone(this.recipientPhone);
        if (!n) {
            inp.setCustomValidity('');
        } else if (!PATTERN_PHONE_VN_FEC.test(n)) {
            inp.setCustomValidity(this.validationLabels.phoneInvalid);
        } else {
            inp.setCustomValidity('');
        }
        return inp;
    }

    handleRecipientPhoneBlur() {
        const inp = this.applyRecipientPhoneCustomValidity();
        if (inp) {
            inp.reportValidity();
        }
    }

    assertRecipientPhoneInputValid() {
        if (!this.showAddressSection) {
            return true;
        }
        const inp = this.applyRecipientPhoneCustomValidity();
        if (!inp) {
            return true;
        }
        if (!inp.checkValidity()) {
            inp.reportValidity();
            return false;
        }
        return true;
    }

    assertDeliveryPicklistValid() {
        const el = this.template.querySelector('[data-fec-field="deliveryPicklist"]');
        let ok = true;
        if (el && typeof el.checkValidity === 'function') {
            ok = el.checkValidity();
        } else {
            ok =
                this.deliveryEmailSelected === true ||
                this.deliveryAddressSelected === true ||
                this.deliveryOfficeSelected === true;
        }
        if (!ok && this.isClosureEditable) {
            this.showToast(this.customLabel.errorTitle, this.validationLabels.deliveryRequired, 'error');
        }
        return ok;
    }

    @api
    validateForSubmit() {
        if (!this.isClosureEditable) {
            return true;
        }
        if (this.loading === true) {
            return true;
        }
        if (this.loadError) {
            return false;
        }
        if (!this.assertDeliveryPicklistValid()) {
            return false;
        }
        if (!this.assertRecipientPhoneInputValid()) {
            return false;
        }
        return true;
    }

    ensureSelectedComboboxOption(optionRows, selectedValue, selectedLabel) {
        const v = (selectedValue || STR_EMPTY).trim();
        const list = [...(optionRows || [])];
        if (!v) {
            return list;
        }
        if (!list.some((o) => o.value === v)) {
            const lbl = (selectedLabel || STR_EMPTY).trim() || v;
            list.unshift({ label: lbl, value: v });
        }
        return list;
    }

    handlePickAddr(event) {
        if (this.closureFieldsReadonly) {
            return;
        }
        const id = event.target.dataset.rowId;
        this.selectedAddressRowId = id;
        this.addrRenderKey++;
    }

    handleOpenTempAddressModal() {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.tempAddressModalIsEdit = false;
        this.modalBuilding = STR_EMPTY;
        this.modalNumber = STR_EMPTY;
        this.modalStreet = STR_EMPTY;
        this.modalWardId = STR_EMPTY;
        this.modalWardLabel = STR_EMPTY;
        this.modalProvinceId = STR_EMPTY;
        this.modalProvinceLabel = STR_EMPTY;
        this.wardOptions = [];
        this.provinceOptions = [];
        this.showTempAddressModal = true;
    }

    handleEditTempAddress() {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.tempAddressModalIsEdit = true;
        const p = this.lastTempAddressParts;
        if (p) {
            this.modalBuilding = p.building || STR_EMPTY;
            this.modalNumber = p.streetNumber || STR_EMPTY;
            this.modalStreet = p.street || STR_EMPTY;
            this.modalWardId = p.wardRecordId || STR_EMPTY;
            this.modalWardLabel = p.wardLabel || STR_EMPTY;
            this.modalProvinceId = p.provinceRecordId || STR_EMPTY;
            this.modalProvinceLabel = p.provinceLabel || STR_EMPTY;
        } else {
            this.modalBuilding = STR_EMPTY;
            this.modalNumber = STR_EMPTY;
            this.modalStreet = STR_EMPTY;
            this.modalWardId = STR_EMPTY;
            this.modalWardLabel = STR_EMPTY;
            this.modalProvinceId = STR_EMPTY;
            this.modalProvinceLabel = STR_EMPTY;
        }
        this.wardOptions = [];
        this.provinceOptions = [];
        this.showTempAddressModal = true;
    }

    handleModalCancel() {
        this.showTempAddressModal = false;
    }

    handleModalBuilding(event) {
        this.modalBuilding = event.target.value;
    }

    handleModalNumber(event) {
        this.modalNumber = event.target.value;
    }

    handleModalStreet(event) {
        this.modalStreet = event.target.value;
    }

    async loadProvinceOptions() {
        try {
            const rows = await searchAdministrativeUnits({
                objectApiName: 'FEC_Province__c',
                searchKey: STR_EMPTY
            });
            const mapped = (rows || []).map((r) => ({
                label: r.label,
                value: r.value
            }));
            this.provinceOptions = this.ensureSelectedComboboxOption(
                mapped,
                this.modalProvinceId,
                this.modalProvinceLabel
            );
        } catch (e) {
            this.provinceOptions = this.ensureSelectedComboboxOption(
                [],
                this.modalProvinceId,
                this.modalProvinceLabel
            );
        }
    }

    async loadWardOptions() {
        try {
            const rows = await searchAdministrativeUnits({
                objectApiName: 'FEC_Ward__c',
                searchKey: STR_EMPTY
            });
            const mapped = (rows || []).map((r) => ({
                label: r.label,
                value: r.value
            }));
            this.wardOptions = this.ensureSelectedComboboxOption(
                mapped,
                this.modalWardId,
                this.modalWardLabel
            );
        } catch (e) {
            this.wardOptions = this.ensureSelectedComboboxOption(
                [],
                this.modalWardId,
                this.modalWardLabel
            );
        }
    }

    handleModalProvincePick(event) {
        this.modalProvinceId = event.detail.value;
        const opt = this.provinceOptions.find((o) => o.value === this.modalProvinceId);
        this.modalProvinceLabel = opt ? opt.label : STR_EMPTY;
    }

    handleModalWardPick(event) {
        this.modalWardId = event.detail.value;
        const opt = this.wardOptions.find((o) => o.value === this.modalWardId);
        this.modalWardLabel = opt ? opt.label : STR_EMPTY;
    }

    async handleModalSave() {
        if (this.closureFieldsReadonly) {
            return;
        }
        if (
            !this.modalBuilding ||
            !this.modalNumber ||
            !this.modalStreet ||
            !this.modalWardId ||
            !this.modalProvinceId
        ) {
            this.showToast(this.customLabel.errorTitle, this.validationLabels.requiredFields, 'error');
            return;
        }
        const parts = {
            building: this.modalBuilding,
            streetNumber: this.modalNumber,
            street: this.modalStreet,
            wardRecordId: this.modalWardId,
            provinceRecordId: this.modalProvinceId,
            wardLabel: this.modalWardLabel,
            provinceLabel: this.modalProvinceLabel
        };
        const payload = { tempAddressParts: parts };
        if (this.tempAddressModalIsEdit && this.tempAddressRecordId) {
            payload.tempAddressRecordId = this.tempAddressRecordId;
        }
        try {
            const newId = await upsertTemporaryAddress({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            this.tempAddressRecordId = newId;
            this.lastTempAddressParts = { ...parts };
            this.temporaryAddressDisplay = [
                parts.building,
                parts.streetNumber,
                parts.street,
                parts.wardLabel,
                parts.provinceLabel
            ].join(', ');
            this.disableAddTempAddress = true;
            this.showTempAddressModal = false;
            await this.refreshAddresses();
            this.showToast(this.customLabel.successTitle, this.customLabel.toastSaveSuccess, 'success');
        } catch (e) {
            this.showToast(this.customLabel.errorTitle, this.handleError(e), 'error');
        }
    }

    async refreshAddresses() {
        if (!this.wiredInitResult) {
            return;
        }
        try {
            await refreshApex(this.wiredInitResult);
        } catch (ignore) {
        }
    }

    async handleRemoveTempAddress() {
        if (this.closureFieldsReadonly) {
            return;
        }
        if (this.tempAddressRecordId) {
            try {
                await deleteTemporaryAddressRecord({
                    addressInfoId: this.tempAddressRecordId
                });
            } catch (ignore) {
            }
        }
        this.tempAddressRecordId = undefined;
        this.temporaryAddressDisplay = STR_EMPTY;
        this.lastTempAddressParts = undefined;
        this.disableAddTempAddress = false;
        await this.refreshAddresses();
    }

    buildPayload() {
        const parts = [];
        if (this.deliveryEmailSelected) {
            parts.push(this.resolvedEmailValue);
        }
        if (this.deliveryAddressSelected) {
            parts.push(this.resolvedAddressValue);
        }
        if (this.deliveryOfficeSelected) {
            parts.push(this.resolvedOfficeValue);
        }
        return {
            deliveryOptionCombined: parts.join(';'),
            deliveryEmailSelected: this.deliveryEmailSelected,
            deliveryAddressSelected: this.deliveryAddressSelected,
            deliveryOfficeSelected: this.deliveryOfficeSelected,
            useExistingEmail: this.useExistingEmail,
            emailDeliveryChannel: this.resolveEmailDeliveryChannel(),
            temporaryEmail: this.temporaryEmail,
            recipientName: this.recipientName,
            recipientPhone: this.recipientPhone,
            selectedAddressId: this.selectedAddressRowId || STR_EMPTY,
            temporaryAddressDisplay: this.temporaryAddressDisplay || STR_EMPTY
        };
    }

    @api
    async validateBeforeComplete() {
        this.showValidateBanner = false;
        this.lastValidationMessages = [];
        if (!this.isClosureEditable) {
            return { valid: true, messages: [] };
        }
        if (!this.assertDeliveryPicklistValid()) {
            return { valid: false, messages: [] };
        }
        if (!this.assertRecipientPhoneInputValid()) {
            return { valid: false, messages: [] };
        }
        const payload = this.buildPayload();
        try {
            const r = await validateForComplete({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            if (!r.valid) {
                this.lastValidationMessages = r.messages || [];
                this.showValidateBanner = true;
            }
            return r;
        } catch (e) {
            const msg = e.body && e.body.message ? e.body.message : String(e);
            this.lastValidationMessages = [msg];
            this.showValidateBanner = true;
            return { valid: false, messages: [msg] };
        }
    }

    @api
    async saveToCase() {
        if (!this.isClosureEditable) {
            return { valid: true, messages: [] };
        }
        if (!this.assertDeliveryPicklistValid()) {
            return { valid: false, messages: [] };
        }
        if (!this.assertRecipientPhoneInputValid()) {
            return { valid: false, messages: [] };
        }
        const payload = this.buildPayload();
        try {
            const r = await saveForm({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            if (!r.valid) {
                this.lastValidationMessages = r.messages || [];
                this.showValidateBanner = true;
            } else {
                this.showToast(this.customLabel.successTitle, this.customLabel.toastSaveSuccess, 'success');
            }
            return r;
        } catch (e) {
            const msg = this.handleError(e);
            this.showToast(this.customLabel.errorTitle, msg, 'error');
            return { valid: false, messages: [msg] };
        }
    }

    _shouldRunContractClosureDraftSave() {
        if (this.deliveryEmailSelected || this.deliveryAddressSelected || this.deliveryOfficeSelected) {
            return true;
        }
        if ((this.recipientName || STR_EMPTY).trim()) {
            return true;
        }
        if ((this.recipientPhone || STR_EMPTY).trim()) {
            return true;
        }
        if ((this.temporaryEmail || STR_EMPTY).trim()) {
            return true;
        }
        if (this.selectedAddressRowId) {
            return true;
        }
        if ((this.temporaryAddressDisplay || STR_EMPTY).trim()) {
            return true;
        }
        if (this.showTempEmailRow === true) {
            return true;
        }
        return false;
    }

    @api
    async saveDraftIfApplicable() {
        if (!this.isClosureEditable) {
            return { valid: true, messages: [] };
        }
        if (this.loading === true) {
            return { valid: true, messages: [] };
        }
        if (!this._shouldRunContractClosureDraftSave()) {
            return { valid: true, messages: [] };
        }
        if (this.loadError) {
            return { valid: false, messages: [] };
        }
        if (!this.assertRecipientPhoneInputValid()) {
            return { valid: false, messages: [] };
        }
        const payload = this.buildPayload();
        try {
            const r = await saveFormDraft({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            if (!r.valid) {
                this.lastValidationMessages = r.messages || [];
                this.showValidateBanner = true;
                const msgs = r.messages || [];
                const m =
                    msgs.length > 0 ? msgs.join(', ') : this.customLabel.errorTitle;
                this.showToast(this.customLabel.errorTitle, m, 'error');
            }
            return r;
        } catch (e) {
            const msg = this.handleError(e);
            this.showToast(this.customLabel.errorTitle, msg, 'error');
            return { valid: false, messages: [msg] };
        }
    }

    renderedCallback() {
        if (this.showTempAddressModal && !this._modalListsLoadedOnce) {
            this._modalListsLoadedOnce = true;
            this.loadWardOptions();
            this.loadProvinceOptions();
        }
        if (!this.showTempAddressModal) {
            this._modalListsLoadedOnce = false;
        }
    }

    handleError(error) {
        let msg = STR_EMPTY;
        if (Array.isArray(error?.body)) {
            msg = error.body.map((e) => e.message).join(', ');
        } else if (typeof error?.body?.message === 'string') {
            msg = error.body.message;
        } else if (error && error.message) {
            msg = error.message;
        } else {
            msg = String(error);
        }
        return msg;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant || 'info'
            })
        );
    }
}
