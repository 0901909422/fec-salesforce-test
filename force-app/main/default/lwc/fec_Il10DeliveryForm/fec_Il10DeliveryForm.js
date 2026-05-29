import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_MSG_ContractClosure_Required_Fields from '@salesforce/label/c.FEC_MSG_ContractClosure_Required_Fields';
import FEC_MSG_ContractClosure_Phone_Invalid from '@salesforce/label/c.FEC_MSG_ContractClosure_Phone_Invalid';
import FEC_MSG_ContractClosure_Delivery_Invalid from '@salesforce/label/c.FEC_MSG_ContractClosure_Delivery_Invalid';
import FEC_MSG_ContractClosure_Address_Required from '@salesforce/label/c.FEC_MSG_ContractClosure_Address_Required';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import FEC_MSG_ContractClosure_Address_Row_Empty from '@salesforce/label/c.FEC_MSG_ContractClosure_Address_Row_Empty';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_LBL_Province_City from '@salesforce/label/c.FEC_LBL_Province_City';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Button_Cancel from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_Alt_Edit from '@salesforce/label/c.FEC_Alt_Edit';
import FEC_Alt_Remove from '@salesforce/label/c.FEC_Alt_Remove';
import LBL_SortBy from '@salesforce/label/c.LBL_SortBy';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';
import FEC_LBL_ContractClosure_Add_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Add_Temp_Address';
import FEC_LBL_ContractClosure_Address_Col from '@salesforce/label/c.FEC_LBL_ContractClosure_Address_Col';
import FEC_LBL_ContractClosure_Address_Type from '@salesforce/label/c.FEC_LBL_ContractClosure_Address_Type';
import FEC_LBL_ContractClosure_Building from '@salesforce/label/c.FEC_LBL_ContractClosure_Building';
import FEC_LBL_ContractClosure_Delivery_Option from '@salesforce/label/c.FEC_LBL_ContractClosure_Delivery_Option';
import FEC_LBL_ContractClosure_Mailing_Address_Col from '@salesforce/label/c.FEC_LBL_ContractClosure_Mailing_Address_Col';
import FEC_LBL_ContractClosure_Modal_Edit_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Modal_Edit_Temp_Address';
import FEC_LBL_ContractClosure_Modal_New_Temp_Address from '@salesforce/label/c.FEC_LBL_ContractClosure_Modal_New_Temp_Address';
import FEC_LBL_ContractClosure_Recipient_Name from '@salesforce/label/c.FEC_LBL_ContractClosure_Recipient_Name';
import FEC_LBL_ContractClosure_Recipient_Phone from '@salesforce/label/c.FEC_LBL_ContractClosure_Recipient_Phone';
import FEC_LBL_ContractClosure_Street from '@salesforce/label/c.FEC_LBL_ContractClosure_Street';
import FEC_LBL_ContractClosure_Street_Number from '@salesforce/label/c.FEC_LBL_ContractClosure_Street_Number';
import FEC_LBL_ContractClosure_Ward from '@salesforce/label/c.FEC_LBL_ContractClosure_Ward';
import FEC_Placeholder_ContractClosure_Select_Delivery from '@salesforce/label/c.FEC_Placeholder_ContractClosure_Select_Delivery';
import FEC_Placeholder_ContractClosure_Select_Admin from '@salesforce/label/c.FEC_Placeholder_ContractClosure_Select_Admin';

import getInitData from '@salesforce/apex/FEC_Il10DeliveryController.getInitData';
import validateForComplete from '@salesforce/apex/FEC_ContractClosureController.validateForComplete';
import saveForm from '@salesforce/apex/FEC_ContractClosureController.saveForm';
import saveFormDraft from '@salesforce/apex/FEC_ContractClosureController.saveFormDraft';
import upsertTemporaryAddress from '@salesforce/apex/FEC_ContractClosureController.upsertTemporaryAddress';
import deleteTemporaryAddressRecord from '@salesforce/apex/FEC_ContractClosureController.deleteTemporaryAddressRecord';
import searchAdministrativeUnits from '@salesforce/apex/FEC_ContractClosureController.searchAdministrativeUnits';

import {
    STR_EMPTY,
    PATTERN_PHONE_VN_FEC,
    CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
    CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT,
    CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT,
    CONTRACT_CLOSURE_DELIVERY_VALUE_POS_DEFAULT
} from 'c/fec_CommonConst';
import { normalizePhone } from 'c/fec_CommonUtils';

const CC_ADDRESS_TABLE_ITEM = 'item';
const CC_ADDRESS_TABLE_ITEMS = 'items';
const CC_ADDRESS_TABLE_SORTED_SUFFIX = ' • Sorted by Address Type';
const CC_ASSISTIVE_TABLE_SELECTION = 'Selection';
const CC_MSG_LOAD_FAILED = 'Load failed';

/**
 * IL10.03 — Delivery Option: Address / Office / POS (không Email).
 */
export default class Fec_Il10DeliveryForm extends LightningElement {
    @api recordId;
    @api isEdit;

    loading = true;
    loadError;
    deliveryOptions = [];
    savedDeliveryOption = STR_EMPTY;

    deliveryAddressSelected = false;
    deliveryOfficeSelected = false;
    deliveryPosSelected = false;

    resolvedAddressValue;
    resolvedOfficeValue;
    resolvedPosValue;

    demographicCustomerName;
    demographicPrimaryPhone;
    recipientName = STR_EMPTY;
    recipientPhone = STR_EMPTY;
    recipientNameDirty = false;
    recipientPhoneDirty = false;
    addresses = [];
    selectedAddressRowId;
    addrRenderKey = 0;
    addressSortAsc = true;
    showSelectedAddressOnly = false;
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
    lastTempAddressParts;
    tempAddressModalIsEdit = false;
    pendingSelectTemporaryAddress = false;
    caseTemporaryAddressRow;
    _modalListsLoadedOnce = false;

    wiredInitResult;
    lastValidationMessages = [];
    showValidateBanner = false;

    customLabel = {
        errorTitle: FEC_Error_Title,
        successTitle: FEC_Success_Title,
        loadingAlt: FEC_Termination_Loading_Alt,
        deliveryOption: FEC_LBL_ContractClosure_Delivery_Option,
        placeholderDelivery: FEC_Placeholder_ContractClosure_Select_Delivery,
        toastSaveSuccess: FEC_Toast_Save_Success,
        saveBtn: FEC_Button_Save,
        cancelBtn: FEC_Button_Cancel,
        altEdit: FEC_Alt_Edit,
        altRemove: FEC_Alt_Remove,
        addTempAddress: FEC_LBL_ContractClosure_Add_Temp_Address,
        addressCol: FEC_LBL_ContractClosure_Address_Col,
        addressType: FEC_LBL_ContractClosure_Address_Type,
        building: FEC_LBL_ContractClosure_Building,
        mailingAddressCol: FEC_LBL_ContractClosure_Mailing_Address_Col,
        modalEditTempAddress: FEC_LBL_ContractClosure_Modal_Edit_Temp_Address,
        modalNewTempAddress: FEC_LBL_ContractClosure_Modal_New_Temp_Address,
        recipientName: FEC_LBL_ContractClosure_Recipient_Name,
        recipientPhone: FEC_LBL_ContractClosure_Recipient_Phone,
        street: FEC_LBL_ContractClosure_Street,
        streetNumber: FEC_LBL_ContractClosure_Street_Number,
        ward: FEC_LBL_ContractClosure_Ward,
        provinceCityLabel: FEC_LBL_Province_City,
        placeholderAdmin: FEC_Placeholder_ContractClosure_Select_Admin
    };

    validationLabels = {
        requiredFields: FEC_MSG_ContractClosure_Required_Fields,
        phoneInvalid: FEC_MSG_ContractClosure_Phone_Invalid,
        deliveryRequired: FEC_MSG_ContractClosure_Delivery_Invalid,
        addressRequired: FEC_MSG_ContractClosure_Address_Required,
        addressRowEmpty: FEC_MSG_ContractClosure_Address_Row_Empty,
        completeThisField: FEC_Complete_This_Field
    };

    addressTypeTemporaryLabel = CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY;

    get isClosureEditable() {
        return this.isEdit !== false;
    }

    get closureFieldsReadonly() {
        return this.isEdit === false;
    }

    get closureFieldRequired() {
        return this.isClosureEditable;
    }

    get showRecipientSection() {
        return this.deliveryAddressSelected === true;
    }

    get showAddressSection() {
        return this.deliveryAddressSelected === true;
    }

    get lockAddTempAddrBtn() {
        return this.disableAddTempAddress || this.closureFieldsReadonly;
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
        const visibleRows =
            this.showSelectedAddressOnly && sel
                ? rows.filter((r) => r.id === sel)
                : rows;
        return visibleRows.map((r) => ({
            ...r,
            selected: r.id === sel
        }));
    }

    get tempAddressModalTitle() {
        return this.tempAddressModalIsEdit
            ? this.customLabel.modalEditTempAddress
            : this.customLabel.modalNewTempAddress;
    }

    get deliveryPicklistOptions() {
        const rows = [];
        const av = this.resolvedAddressValue;
        const ov = this.resolvedOfficeValue;
        const pv = this.resolvedPosValue;
        if (av) {
            rows.push({ label: this.labelAddress, value: av });
        }
        if (ov) {
            rows.push({ label: this.labelOffice, value: ov });
        }
        if (pv) {
            rows.push({ label: this.labelPos, value: pv });
        }
        return rows;
    }

    get selectedDeliveryValues() {
        const vals = [];
        if (this.deliveryAddressSelected && this.resolvedAddressValue) {
            vals.push(this.resolvedAddressValue);
        }
        if (this.deliveryOfficeSelected && this.resolvedOfficeValue) {
            vals.push(this.resolvedOfficeValue);
        }
        if (this.deliveryPosSelected && this.resolvedPosValue) {
            vals.push(this.resolvedPosValue);
        }
        return vals;
    }

    get validationMessageItems() {
        return (this.lastValidationMessages || []).map((text, index) => ({
            key: 'v' + index,
            text
        }));
    }

    get labelAddress() {
        const o = this.pickDeliveryMeta('ADDRESS');
        return o ? o.label : CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT;
    }

    get labelOffice() {
        const o = this.pickDeliveryMeta('OFFICE');
        return o ? o.label : CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT;
    }

    get labelPos() {
        const o = this.pickDeliveryMeta('POS');
        return o ? o.label : CONTRACT_CLOSURE_DELIVERY_VALUE_POS_DEFAULT;
    }

    @wire(getInitData, { caseId: '$recordId' })
    wiredInit(result) {
        this.wiredInitResult = result;
        this.loading = false;
        const { data, error } = result;
        if (data) {
            const init = data.initData;
            if (!init || !init.success) {
                this.loadError = (init && init.errorMessage) || CC_MSG_LOAD_FAILED;
                return;
            }
            this.loadError = undefined;
            this.demographicCustomerName = init.demographicCustomerName || STR_EMPTY;
            this.demographicPrimaryPhone = init.demographicPrimaryPhone || STR_EMPTY;
            this.deliveryOptions = init.deliveryOptions || [];
            this.savedDeliveryOption = init.savedDeliveryOption || STR_EMPTY;
            this.addresses = init.addresses || [];
            this.caseTemporaryAddressRow = data.caseTemporaryAddressRow || null;
            const serverSelectedAddressId = init.savedSelectedAddressId || STR_EMPTY;
            if (serverSelectedAddressId) {
                this.selectedAddressRowId = serverSelectedAddressId;
                this.addrRenderKey++;
            }
            this.resolveDeliveryMeta();
            this.applySavedDelivery();
            const serverRecipientName =
                init.savedRecipientName || this.demographicCustomerName || STR_EMPTY;
            const serverRecipientPhone =
                init.savedRecipientPhone || this.demographicPrimaryPhone || STR_EMPTY;
            this.syncRecipientNameFromServer(serverRecipientName);
            this.syncRecipientPhoneFromServer(serverRecipientPhone);
            this.syncTemporaryAddressFromAddressRows();
            this._emitDeliveryChange();
        } else if (error) {
            this.loadError = error.body ? error.body.message : String(error);
        }
    }

    resolveDeliveryMeta() {
        const addrO = this.pickDeliveryMeta('ADDRESS');
        const offO = this.pickDeliveryMeta('OFFICE');
        const posO = this.pickDeliveryMeta('POS');
        this.resolvedAddressValue = addrO
            ? addrO.value
            : CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT;
        this.resolvedOfficeValue = offO
            ? offO.value
            : CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT;
        this.resolvedPosValue = posO ? posO.value : null;
    }

    pickDeliveryMeta(kind) {
        const opts = this.deliveryOptions || [];
        if (kind === 'ADDRESS') {
            return opts.find((o) => this.isDeliveryAddressOption(o));
        }
        if (kind === 'OFFICE') {
            return opts.find((o) => this.isDeliveryOfficeOption(o));
        }
        if (kind === 'POS') {
            return opts.find(
                (o) =>
                    /^pos$/i.test((o.label || STR_EMPTY).trim()) ||
                    /^pos$/i.test((o.value || STR_EMPTY).trim()) ||
                    /^rl05_pos$/i.test((o.value || STR_EMPTY).trim())
            );
        }
        return undefined;
    }

    isDeliveryAddressOption(o) {
        const lbl = (o.label || STR_EMPTY).toLowerCase();
        const val = (o.value || STR_EMPTY).toLowerCase();
        return (
            /^address$/i.test((o.value || STR_EMPTY).trim()) ||
            /địa\s*chỉ|dia\s*chi/i.test(lbl) ||
            /địa\s*chỉ|dia\s*chi/i.test(val) ||
            /\baddress\b/i.test(lbl)
        );
    }

    isDeliveryOfficeOption(o) {
        const lbl = (o.label || STR_EMPTY).toLowerCase();
        const val = (o.value || STR_EMPTY).toLowerCase();
        return (
            /^office$/i.test((o.value || STR_EMPTY).trim()) ||
            /văn\s*phòng|van\s*phong/i.test(lbl) ||
            /văn\s*phòng|van\s*phong/i.test(val) ||
            /\boffice\b/i.test(lbl)
        );
    }

    applySavedDelivery() {
        const s = this.savedDeliveryOption;
        if (!s) {
            return;
        }
        this.deliveryAddressSelected = false;
        this.deliveryOfficeSelected = false;
        this.deliveryPosSelected = false;
        const parts = s.split(';').map((x) => x.trim()).filter(Boolean);
        parts.forEach((p) => {
            if (this.resolvedAddressValue && p === this.resolvedAddressValue) {
                this.deliveryAddressSelected = true;
            }
            if (this.resolvedOfficeValue && p === this.resolvedOfficeValue) {
                this.deliveryOfficeSelected = true;
            }
            if (this.resolvedPosValue && p === this.resolvedPosValue) {
                this.deliveryPosSelected = true;
            }
        });
    }

    syncTemporaryAddressFromAddressRows() {
        const rows = this.addresses || [];
        const tempRow =
            this.caseTemporaryAddressRow ||
            rows.find((a) => /temporary/i.test((a && a.addressType) || STR_EMPTY));
        const hasSelectedRow =
            !!rows.find((r) => r && r.id === this.selectedAddressRowId) ||
            (tempRow && tempRow.id === this.selectedAddressRowId);
        if (
            this.selectedAddressRowId &&
            !hasSelectedRow &&
            !this.pendingSelectTemporaryAddress
        ) {
            this.selectedAddressRowId = undefined;
            this.addrRenderKey++;
        }
        if (!tempRow) {
            this.tempAddressRecordId = undefined;
            this.temporaryAddressDisplay = STR_EMPTY;
            this.disableAddTempAddress = false;
            this.lastTempAddressParts = undefined;
            this.pendingSelectTemporaryAddress = false;
            return;
        }
        this.tempAddressRecordId = tempRow.id;
        this.temporaryAddressDisplay = tempRow.address || STR_EMPTY;
        this.lastTempAddressParts =
            this.resolveTemporaryAddressPartsFromRow(tempRow) ||
            this.parseTemporaryAddressDisplay(tempRow.address);
        this.disableAddTempAddress = true;
        if (this.pendingSelectTemporaryAddress === true || !this.selectedAddressRowId) {
            this.selectedAddressRowId = tempRow.id;
            this.addrRenderKey++;
        }
        this.pendingSelectTemporaryAddress = false;
    }

    resolveTemporaryAddressPartsFromRow(row) {
        if (!row) {
            return undefined;
        }
        const building = (row.building || STR_EMPTY).trim();
        const streetNumber = (row.streetNumber || STR_EMPTY).trim();
        const street = (row.street || STR_EMPTY).trim();
        const wardLabel = (row.wardLabel || STR_EMPTY).trim();
        const provinceLabel = (row.provinceLabel || STR_EMPTY).trim();
        if (!building || !streetNumber || !street || !wardLabel || !provinceLabel) {
            return undefined;
        }
        return {
            building,
            streetNumber,
            street,
            wardRecordId: row.wardRecordId || wardLabel,
            provinceRecordId: row.provinceRecordId || provinceLabel,
            wardLabel,
            provinceLabel
        };
    }

    parseTemporaryAddressDisplay(line) {
        const raw = (line || STR_EMPTY).trim();
        if (!raw) {
            return undefined;
        }
        const chunks = raw
            .split(',')
            .map((s) => (s || STR_EMPTY).trim())
            .filter((s) => !!s);
        if (chunks.length < 5) {
            return undefined;
        }
        const building = chunks[0] || STR_EMPTY;
        const streetNumber = chunks[1] || STR_EMPTY;
        const provinceLabel = chunks[chunks.length - 1] || STR_EMPTY;
        const wardLabel = chunks[chunks.length - 2] || STR_EMPTY;
        const streetChunks = chunks.slice(2, chunks.length - 2);
        if (
            streetChunks.length > 0 &&
            wardLabel &&
            ((streetChunks[streetChunks.length - 1] || STR_EMPTY).trim().toLowerCase() ===
                wardLabel.toLowerCase())
        ) {
            streetChunks.pop();
        }
        const street = streetChunks.join(', ');
        if (!building || !streetNumber || !street || !wardLabel || !provinceLabel) {
            return undefined;
        }
        return {
            building,
            streetNumber,
            street,
            wardRecordId: wardLabel,
            provinceRecordId: provinceLabel,
            wardLabel,
            provinceLabel
        };
    }

    handleRecipientNameChange(event) {
        this.recipientNameDirty = true;
        this.recipientName = event.target.value;
    }

    handleRecipientPhoneChange(event) {
        this.recipientPhoneDirty = true;
        this.recipientPhone = event.target.value;
        const inp = this.template.querySelector('lightning-input[data-fec-field="recipientPhone"]');
        if (inp) {
            inp.setCustomValidity(STR_EMPTY);
        }
    }

    applyRecipientPhoneCustomValidity() {
        const inp = this.template.querySelector('lightning-input[data-fec-field="recipientPhone"]');
        if (!inp) {
            return null;
        }
        const n = normalizePhone(this.recipientPhone);
        if (!n) {
            inp.setCustomValidity(STR_EMPTY);
        } else if (!PATTERN_PHONE_VN_FEC.test(n)) {
            inp.setCustomValidity(this.validationLabels.phoneInvalid);
        } else {
            inp.setCustomValidity(STR_EMPTY);
        }
        return inp;
    }

    handleRecipientPhoneBlur() {
        const inp = this.applyRecipientPhoneCustomValidity();
        if (inp) {
            inp.reportValidity();
        }
    }

    syncRecipientNameFromServer(serverValue) {
        const nextValue = serverValue || STR_EMPTY;
        if (!this.recipientNameDirty) {
            this.recipientName = nextValue;
            return;
        }
        if ((this.recipientName || STR_EMPTY).trim() === nextValue.trim()) {
            this.recipientNameDirty = false;
        }
    }

    syncRecipientPhoneFromServer(serverValue) {
        const nextValue = serverValue || STR_EMPTY;
        if (!this.recipientPhoneDirty) {
            this.recipientPhone = nextValue;
            return;
        }
        if (normalizePhone(this.recipientPhone) === normalizePhone(nextValue)) {
            this.recipientPhoneDirty = false;
        }
    }

    assertRecipientNameInputValid() {
        if (!this.showRecipientSection) {
            return true;
        }
        const inp = this.template.querySelector('lightning-input[data-fec-field="recipientName"]');
        if (!inp) {
            return true;
        }
        if (!inp.checkValidity()) {
            inp.reportValidity();
            return false;
        }
        return true;
    }

    assertRecipientPhoneInputValid() {
        if (!this.showRecipientSection) {
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

    assertClosureAddressSelectionRequiredValid() {
        if (!this.isClosureEditable) {
            return true;
        }
        if (!this.showAddressSection) {
            return true;
        }
        const hasTempLine = this.hasUsableTemporaryAddressLine();
        const selId = this.selectedAddressRowId;
        if (!selId) {
            if (!hasTempLine) {
                this.showToast(
                    this.customLabel.errorTitle,
                    this.validationLabels.addressRequired,
                    'error'
                );
                return false;
            }
            return true;
        }
        return true;
    }

    hasUsableTemporaryAddressLine() {
        const normalize = (value) => (value || STR_EMPTY).trim().toLowerCase();
        const tempType = normalize(this.addressTypeTemporaryLabel);
        const displayLine = normalize(this.temporaryAddressDisplay);
        if (displayLine && displayLine !== tempType) {
            return true;
        }
        const rows = this.addresses || [];
        const tempRows = rows.filter((row) =>
            normalize(row && row.addressType).includes('temporary')
        );
        return tempRows.some((row) => {
            const line = normalize(row && row.address);
            return !!line && line !== tempType;
        });
    }

    assertClosureAddressRowLineValid() {
        if (!this.isClosureEditable) {
            return true;
        }
        if (!this.showAddressSection) {
            return true;
        }
        const selId = this.selectedAddressRowId;
        if (!selId) {
            return true;
        }
        const rows = this.addresses || [];
        const row = rows.find((r) => r && r.id === selId);
        const line = row ? (row.address || STR_EMPTY).trim() : STR_EMPTY;
        if (!line) {
            this.showToast(
                this.customLabel.errorTitle,
                this.validationLabels.addressRowEmpty,
                'error'
            );
            return false;
        }
        return true;
    }

    handleToggleAddressSort() {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.addressSortAsc = !this.addressSortAsc;
    }

    handlePickAddr(event) {
        if (this.closureFieldsReadonly) {
            return;
        }
        this.selectedAddressRowId = event.target.dataset.rowId;
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
            this.modalWardId = p.wardRecordId || p.wardLabel || STR_EMPTY;
            this.modalWardLabel = p.wardLabel || STR_EMPTY;
            this.modalProvinceId = p.provinceRecordId || p.provinceLabel || STR_EMPTY;
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

    async loadProvinceOptions() {
        try {
            const rows = await searchAdministrativeUnits({
                objectApiName: 'FEC_Province__c',
                searchKey: STR_EMPTY,
                provinceId: null
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
                objectApiName: 'FEC_District__c',
                searchKey: STR_EMPTY,
                provinceId: this.modalProvinceId || null
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
        this.modalWardId = STR_EMPTY;
        this.modalWardLabel = STR_EMPTY;
        this.wardOptions = [];
        this.loadWardOptions();
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
            this.showToast(
                this.customLabel.errorTitle,
                this.validationLabels.requiredFields,
                'error'
            );
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
            this.pendingSelectTemporaryAddress = true;
            this.selectedAddressRowId = newId;
            this.addrRenderKey++;
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
            this.showToast(
                this.customLabel.successTitle,
                this.customLabel.toastSaveSuccess,
                'success'
            );
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
            /* optional */
        }
    }

    async handleRemoveTempAddress() {
        if (this.closureFieldsReadonly) {
            return;
        }
        const removedTempId = this.tempAddressRecordId;
        if (this.tempAddressRecordId) {
            try {
                await deleteTemporaryAddressRecord({
                    addressInfoId: this.tempAddressRecordId
                });
            } catch (ignore) {
                /* optional */
            }
        }
        this.tempAddressRecordId = undefined;
        this.temporaryAddressDisplay = STR_EMPTY;
        this.lastTempAddressParts = undefined;
        this.disableAddTempAddress = false;
        this.pendingSelectTemporaryAddress = false;
        if (
            this.selectedAddressRowId &&
            removedTempId &&
            this.selectedAddressRowId === removedTempId
        ) {
            this.selectedAddressRowId = undefined;
            this.addrRenderKey++;
        }
        await this.refreshAddresses();
    }

    _resolvePhysicalDeliveryConflict(ids, av, ov, pv) {
        let next = [...ids];
        const physical = [av, ov, pv].filter(Boolean);
        const selectedPhysical = physical.filter((v) => next.includes(v));
        if (selectedPhysical.length <= 1) {
            return next;
        }
        const prev = {
            address: this.deliveryAddressSelected,
            office: this.deliveryOfficeSelected,
            pos: this.deliveryPosSelected
        };
        const newlyAdded = physical.find(
            (v) =>
                next.includes(v) &&
                !(
                    (v === av && prev.address) ||
                    (v === ov && prev.office) ||
                    (v === pv && prev.pos)
                )
        );
        const keep = newlyAdded || selectedPhysical[selectedPhysical.length - 1];
        return next.filter((v) => !physical.includes(v) || v === keep);
    }

    handlePicklistChange(event) {
        if (this.closureFieldsReadonly) {
            return;
        }
        let ids = event.detail && event.detail.ids ? [...event.detail.ids] : [];
        const av = this.resolvedAddressValue;
        const ov = this.resolvedOfficeValue;
        const pv = this.resolvedPosValue;
        ids = this._resolvePhysicalDeliveryConflict(ids, av, ov, pv);
        this.deliveryAddressSelected = !!(av && ids.includes(av));
        this.deliveryOfficeSelected = !!(ov && ids.includes(ov));
        this.deliveryPosSelected = !!(pv && ids.includes(pv));
        this._emitDeliveryChange();
    }

    _hasAnyDeliverySelected() {
        return (
            this.deliveryAddressSelected === true ||
            this.deliveryOfficeSelected === true ||
            this.deliveryPosSelected === true
        );
    }

    _emitDeliveryChange() {
        this.dispatchEvent(
            new CustomEvent('deliveryoptionchange', {
                bubbles: true,
                composed: true,
                detail: {
                    deliveryOptionCombined:
                        this.buildPayload().deliveryOptionCombined || STR_EMPTY
                }
            })
        );
    }

    buildPayload() {
        const parts = [];
        if (this.deliveryAddressSelected && this.resolvedAddressValue) {
            parts.push(this.resolvedAddressValue);
        }
        if (this.deliveryOfficeSelected && this.resolvedOfficeValue) {
            parts.push(this.resolvedOfficeValue);
        }
        if (this.deliveryPosSelected && this.resolvedPosValue) {
            parts.push(this.resolvedPosValue);
        }
        return {
            deliveryOptionCombined: parts.join(';'),
            deliveryEmailSelected: false,
            deliveryAddressSelected: this.deliveryAddressSelected,
            deliveryOfficeSelected: this.deliveryOfficeSelected,
            deliveryPosSelected: this.deliveryPosSelected,
            useExistingEmail: false,
            emailDeliveryChannel: STR_EMPTY,
            temporaryEmail: STR_EMPTY,
            recipientName: this.recipientName,
            recipientPhone: this.recipientPhone,
            selectedAddressId: this.selectedAddressRowId || STR_EMPTY,
            temporaryAddressDisplay: this.temporaryAddressDisplay || STR_EMPTY
        };
    }

    _assertAllClientValidations() {
        if (!this.assertDeliveryPicklistValid()) {
            return false;
        }
        if (!this.assertRecipientNameInputValid()) {
            return false;
        }
        if (!this.assertRecipientPhoneInputValid()) {
            return false;
        }
        if (!this.assertClosureAddressSelectionRequiredValid()) {
            return false;
        }
        if (!this.assertClosureAddressRowLineValid()) {
            return false;
        }
        return true;
    }

    _shouldRunIl10DraftSave() {
        if (
            this.deliveryAddressSelected ||
            this.deliveryOfficeSelected ||
            this.deliveryPosSelected
        ) {
            return true;
        }
        if ((this.recipientName || STR_EMPTY).trim()) {
            return true;
        }
        if ((this.recipientPhone || STR_EMPTY).trim()) {
            return true;
        }
        if (this.selectedAddressRowId) {
            return true;
        }
        if ((this.temporaryAddressDisplay || STR_EMPTY).trim()) {
            return true;
        }
        return false;
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

    assertDeliveryPicklistValid() {
        const el = this.template.querySelector('[data-fec-field="deliveryPicklist"]');
        let ok = true;
        if (el && typeof el.checkValidity === 'function') {
            ok = el.checkValidity();
        } else {
            ok = this._hasAnyDeliverySelected();
        }
        if (!ok && this.isClosureEditable) {
            this.showToast(
                this.customLabel.errorTitle,
                this.validationLabels.deliveryRequired,
                'error'
            );
        }
        return ok;
    }

    @api
    getDeliveryOptionForRouting() {
        return this.buildPayload().deliveryOptionCombined || STR_EMPTY;
    }

    @api
    validateForSubmit() {
        if (!this.isClosureEditable || this.loading || this.loadError) {
            return !this.loadError;
        }
        return this._assertAllClientValidations();
    }

    @api
    async validateBeforeComplete() {
        this.showValidateBanner = false;
        this.lastValidationMessages = [];
        if (!this.isClosureEditable) {
            return { valid: true, messages: [] };
        }
        if (!this._assertAllClientValidations()) {
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
        if (!this._assertAllClientValidations()) {
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
                this.recipientNameDirty = false;
                this.recipientPhoneDirty = false;
                this.showSelectedAddressOnly = true;
                this.savedDeliveryOption = payload.deliveryOptionCombined || STR_EMPTY;
                this.applySavedDelivery();
                try {
                    if (this.wiredInitResult) {
                        await refreshApex(this.wiredInitResult);
                    }
                } catch (ignore) {
                    /* refresh optional */
                }
                this.showToast(
                    this.customLabel.successTitle,
                    this.customLabel.toastSaveSuccess,
                    'success'
                );
            }
            return r;
        } catch (e) {
            const msg = this.handleError(e);
            this.showToast(this.customLabel.errorTitle, msg, 'error');
            return { valid: false, messages: [msg] };
        }
    }

    @api
    async saveDraftIfApplicable() {
        if (!this.isClosureEditable || this.loading || this.loadError) {
            return { valid: true, messages: [] };
        }
        if (!this._shouldRunIl10DraftSave()) {
            return { valid: true, messages: [] };
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
            } else {
                this.recipientNameDirty = false;
                this.recipientPhoneDirty = false;
                this.savedDeliveryOption = payload.deliveryOptionCombined || STR_EMPTY;
                this.applySavedDelivery();
                try {
                    if (this.wiredInitResult) {
                        await refreshApex(this.wiredInitResult);
                    }
                } catch (ignore) {
                    /* refresh optional */
                }
            }
            return r;
        } catch (e) {
            const msg = this.handleError(e);
            this.showToast(this.customLabel.errorTitle, msg, 'error');
            return { valid: false, messages: [msg] };
        }
    }

    handleError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return String(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info'
            })
        );
    }
}
