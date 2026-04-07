import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import loadMainInfo from '@salesforce/apex/FEC_MainInfoController.loadMainInfo';
import clearMainInfoCache from '@salesforce/apex/FEC_MainInfoController.clearMainInfoCache';
import getMailingAddressUpdateContext from '@salesforce/apex/FEC_MainInfoController.getMailingAddressUpdateContext';
import getProvinceOptionsForAddress from '@salesforce/apex/FEC_MainInfoController.getProvinceOptionsForAddress';
import getWardOptionsForProvinceCode from '@salesforce/apex/FEC_MainInfoController.getWardOptionsForProvinceCode';
import updateCustomerAddressParams from '@salesforce/apex/FEC_UpdateCustomerAddress.updateCustomerAddressParams';

import FEC_Permanent_Address from '@salesforce/label/c.FEC_Permanent_Address';
import FEC_Office_Address from '@salesforce/label/c.FEC_Office_Address';
import LBL_UpdateSuccessfully from '@salesforce/label/c.LBL_UpdateSuccessfully';
import LBL_Error from '@salesforce/label/c.LBL_Error';

const TYPE_PERMANENT = 'Permanent Address';
const TYPE_OFFICE = 'Office Address';
/** Địa chỉ hiện tại (API CURRES) — không trùng Permanent Address. */
const TYPE_CURRENT = 'Current Address';

function cloneAddressesSnapshot(addresses) {
    if (!Array.isArray(addresses)) {
        return [];
    }
    return addresses.map((a) => ({
        addressType: a.addressType,
        address: a.address,
        mailingAddress: a.mailingAddress
    }));
}

function addressesHaveDisplayText(addresses) {
    if (!Array.isArray(addresses)) {
        return false;
    }
    return addresses.some(
        (a) =>
            a &&
            a.address != null &&
            String(a.address).trim() !== ''
    );
}

/**
 * Gộp option trùng mã tỉnh (value / FEC_Code__c). Master có thể có hai bản ghi cùng mã → chỉ một dòng.
 * Trùng cùng tên nhưng khác mã: không gộp ở đây (tránh chọn nhầm mã).
 */
function dedupeProvincePicklistOptions(options) {
    if (!Array.isArray(options) || options.length === 0) {
        return [];
    }
    const byValue = new Map();
    for (const o of options) {
        if (!o) {
            continue;
        }
        const v = o.value != null ? o.value : o.Value;
        if (v == null || String(v).trim() === '') {
            continue;
        }
        const key = String(v).trim();
        if (!byValue.has(key)) {
            byValue.set(key, {
                label: o.label != null ? o.label : o.Label,
                value: key
            });
        }
    }
    return [...byValue.values()].sort((a, b) =>
        String(a.label || '').localeCompare(String(b.label || ''), 'vi')
    );
}

export default class Fec_UpdateAddress extends LightningElement {
    /**
     * Giống fec_CardClosureRefundForm: setter gọi load ngay khi parent (fec_CaseBussiness / lwc:component)
     * gán record-id — tránh chỉ dựa renderedCallback (component động có thể gán recordId muộn).
     */
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this._triggerLoadAfterCaseIdChange();
    }

    // is-edit từ fec_CaseBussiness (giống fec_IPPClosureForm: không khởi tạo boolean @api)
    @api isEdit;

    /** Fallback khi LWC nằm trong parent không truyền record-id (trang Case vẫn có Id trên URL). */
    @track _caseIdFromPage;

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        const rid =
            pageRef?.attributes?.recordId ||
            pageRef?.state?.recordId;
        const next = rid || undefined;
        if (next === this._caseIdFromPage) {
            return;
        }
        this._caseIdFromPage = next;
        this._triggerLoadAfterCaseIdChange();
    }

    /** Id Case dùng cho Apex: ưu tiên @api recordId, không có thì lấy từ trang hiện tại. */
    get resolvedCaseId() {
        return this._recordId || this._caseIdFromPage;
    }

    _triggerLoadAfterCaseIdChange() {
        const rid = this.resolvedCaseId;
        const key = rid || 'fec-null';
        if (key === this._lastFetchKey) {
            return;
        }
        this._lastFetchKey = key;
        if (rid) {
            this.originalAddressesSnapshot = undefined;
            this.loadAddressData();
        } else {
            this.isLoading = false;
            this.mainInfoData = null;
            this.originalAddressesSnapshot = undefined;
            this.loadError = undefined;
        }
    }

    @track mainInfoData;
    /** Snapshot địa chỉ lần load đầu theo recordId — cột Original không đổi khi user sửa qua Updated. */
    @track originalAddressesSnapshot;
    @track loadError;
    @track isLoading = true;

    @track mailingModalLoading = false;
    @track mailingSaveLoading = false;

    @track mailingEditRow;
    @track mailingBuilding = '';
    @track mailingNumber = '';
    @track mailingStreet = '';
    @track mailingCity = '';
    @track mailingWard = '';

    @track provinceOptions = [];
    @track wardOptions = [];

    @track mailingCifNumber;
    @track mailingAddressId;
    @track mailingAddressTypeApi;
    /** Một trong hai địa chỉ được chọn làm giao phát (radio). */
    @track mailingSelectedRow = 'permanent';
    @track mailingSelectionBusy = false;

    /** Popup thêm/sửa địa chỉ (Original > Add New Address). */
    @track newAddressModalOpen = false;
    @track newAddressModalLoading = false;
    @track newAddressSaveLoading = false;
    @track newAddrAddressType = TYPE_CURRENT;
    @track newAddrBuilding = '';
    @track newAddrNumber = '';
    @track newAddrStreet = '';
    @track newAddrCity = '';
    @track newAddrWard = '';
    @track newAddrWardOptions = [];
    @track newAddrIsMailing = false;

    _lastFetchKey = 'fec-update-address-unset';

    labels = {
        mailingAddress: 'Mailing Address',
        permanentAddress: FEC_Permanent_Address,
        officeAddress: FEC_Office_Address,
        editMailing: 'Chỉnh sửa địa chỉ giao phát',
        addNewAddress: 'Add New Address',
        building: 'Building',
        number: 'Number',
        street: 'Street',
        provinceCity: 'Province/City',
        provinceSearchPlaceholder: 'Nhập để tìm tỉnh/thành...',
        ward: 'Ward',
        cancel: 'Cancel',
        save: 'Save',
        loading: 'Loading',
        newAddressTitle: 'New Address',
        addressTypeLabel: 'Address Type',
        currentAddressOption: 'Current Address'
    };

    connectedCallback() {
        loadStyle(this, COMMON_STYLES).catch((e) => {
            console.error('FEC_CommonCss load failed', e);
        });
    }

    /**
     * Nạp danh sách tỉnh/thành sớm (cacheable) để ô tìm kiếm có dữ liệu trước khi mở form sửa.
     */
    preloadProvinceOptions() {
        getProvinceOptionsForAddress()
            .then((provinces) => {
                const mapped = (provinces || []).map((o) => ({
                    label: o.label != null ? o.label : o.Label,
                    value: o.value != null ? o.value : o.Value
                }));
                this.provinceOptions = dedupeProvincePicklistOptions(mapped);
            })
            .catch(() => {
                /* im lặng: form sửa vẫn gọi lại getProvinceOptionsForAddress */
            });
    }

    loadAddressData() {
        if (!this.resolvedCaseId) {
            this.isLoading = false;
            this.mainInfoData = null;
            this.originalAddressesSnapshot = undefined;
            return;
        }

        this.isLoading = true;
        this.loadError = undefined;

        loadMainInfo({ caseId: this.resolvedCaseId })
            .then((data) => {
                /* Không gộp addresses từ lần load trước: dễ giữ bản sai / nhầm Case khi server trả [] hoặc sau khi xóa cache. */
                this.mainInfoData = data;
                this.loadError = undefined;
                this.syncMailingSelectionFromData();

                const dataHasText = addressesHaveDisplayText(data?.addresses);
                const snap = this.originalAddressesSnapshot;
                const snapHasText = addressesHaveDisplayText(snap);

                if (dataHasText) {
                    if (snap == null) {
                        this.originalAddressesSnapshot = cloneAddressesSnapshot(
                            data.addresses
                        );
                    } else if (!snapHasText) {
                        this.originalAddressesSnapshot = cloneAddressesSnapshot(
                            data.addresses
                        );
                    }
                }
                this.preloadProvinceOptions();
            })
            .catch((err) => {
                this.loadError =
                    err?.body?.message || err?.message || String(err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get isLoaded() {
        return !this.isLoading;
    }

    get wardComboboxDisabled() {
        return !this.mailingCity;
    }

    get mailingRadiosDisabled() {
        return (
            this.isEdit === false ||
            this.mailingSelectionBusy ||
            this.mailingSaveLoading ||
            this.isLoading
        );
    }

    /**
     * Checkbox mailing: chỉ bật trên đúng dòng đang edit (tránh gọi API đổi mailing
     * sang type khác giữa lúc mở form — dễ lỗi / toast lệch).
     */
    get permanentMailingCheckboxDisabled() {
        return (
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== 'permanent'
        );
    }

    get currentMailingCheckboxDisabled() {
        return (
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== 'current'
        );
    }

    get officeMailingCheckboxDisabled() {
        return (
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== 'office'
        );
    }

    get permanentMailingRadioChecked() {
        return this.mailingSelectedRow === 'permanent';
    }

    get officeMailingRadioChecked() {
        return this.mailingSelectedRow === 'office';
    }

    get currentMailingRadioChecked() {
        return this.mailingSelectedRow === 'current';
    }

    get mailingSaveOrFormBusy() {
        return this.mailingModalLoading || this.mailingSaveLoading;
    }

    get mailingSaveButtonDisabled() {
        return this.mailingSaveOrFormBusy || this.isEdit === false;
    }

    get newAddressTypeOptions() {
        return [
            {
                label: this.labels.currentAddressOption,
                value: TYPE_CURRENT
            },
            { label: this.labels.officeAddress, value: TYPE_OFFICE }
        ];
    }

    get newAddrProvinceOptionsForModal() {
        return this.provinceOptions;
    }

    get newAddrWardComboboxDisabled() {
        return !this.newAddrCity || this.newAddressSaveLoading;
    }

    get newAddressFormBusy() {
        return this.newAddressModalLoading || this.newAddressSaveLoading;
    }

    get newAddressSubmitDisabled() {
        return this.newAddressFormBusy || this.isEdit === false;
    }

    /** Chỉ cho sửa một dòng; ẩn tương tác bút chì dòng còn lại khi đang edit. */
    get permanentEditPencilDisabled() {
        return (
            this.mailingRadiosDisabled ||
            this.isEditingOfficeMailing ||
            this.isEditingCurrentMailing
        );
    }

    get officeEditPencilDisabled() {
        return (
            this.mailingRadiosDisabled ||
            this.isEditingPermanentMailing ||
            this.isEditingCurrentMailing
        );
    }

    get currentEditPencilDisabled() {
        return (
            this.mailingRadiosDisabled ||
            this.isEditingPermanentMailing ||
            this.isEditingOfficeMailing
        );
    }

    get isEditingPermanentMailing() {
        return this.mailingEditRow === 'permanent';
    }

    get isEditingOfficeMailing() {
        return this.mailingEditRow === 'office';
    }

    get isEditingCurrentMailing() {
        return this.mailingEditRow === 'current';
    }

    findAddress(typeLabel, addressList) {
        const list =
            addressList !== undefined
                ? addressList
                : this.mainInfoData?.addresses;
        if (!Array.isArray(list)) {
            return null;
        }
        return list.find((a) => a.addressType === typeLabel) || null;
    }

    /** Đủ 3 loại trong danh sách địa chỉ Main Info — không cho Add New Address. */
    get hasAllStandardAddressTypes() {
        const list = this.mainInfoData?.addresses;
        if (!Array.isArray(list)) {
            return false;
        }
        const types = new Set();
        for (const a of list) {
            if (a && a.addressType) {
                types.add(a.addressType);
            }
        }
        return (
            types.has(TYPE_PERMANENT) &&
            types.has(TYPE_CURRENT) &&
            types.has(TYPE_OFFICE)
        );
    }

    get addNewAddressDisabled() {
        return (
            this.isEdit === false ||
            this.isLoading ||
            this.hasAllStandardAddressTypes
        );
    }

    formatAddress(addr) {
        if (!addr || !addr.address) {
            return '';
        }
        return addr.address;
    }

    formatMailing(addr) {
        if (!addr || addr.mailingAddress == null || addr.mailingAddress === '') {
            return '';
        }
        return addr.mailingAddress;
    }

    /** Cờ địa chỉ giao phát (DTO map từ SF: có giá trị, thường là "Yes"). */
    isMailingFlagYes(addr) {
        return this.formatMailing(addr) !== '';
    }

    /** Địa chỉ hiện tại (DTO); cột Updated ưu tiên DTO, sau đó preview form, cuối cùng đồng bộ với Original. */
    get permanentAddr() {
        return this.findAddress(TYPE_PERMANENT);
    }

    get officeAddr() {
        return this.findAddress(TYPE_OFFICE);
    }

    get currentAddr() {
        return this.findAddress(TYPE_CURRENT);
    }

    get permanentAddrOriginal() {
        return this.findAddress(
            TYPE_PERMANENT,
            this.originalAddressesSnapshot
        );
    }

    get officeAddrOriginal() {
        return this.findAddress(TYPE_OFFICE, this.originalAddressesSnapshot);
    }

    get currentAddrOriginal() {
        return this.findAddress(TYPE_CURRENT, this.originalAddressesSnapshot);
    }

    get permanentOriginalDisplay() {
        return (
            this.formatAddress(this.permanentAddrOriginal) ||
            this.emptyDisplay
        );
    }

    get officeOriginalDisplay() {
        return (
            this.formatAddress(this.officeAddrOriginal) || this.emptyDisplay
        );
    }

    get permanentUpdatedDisplay() {
        const fromDto = this.formatAddress(this.permanentAddr);
        if (fromDto) {
            return fromDto;
        }
        if (this.isEditingPermanentMailing) {
            const preview = this.composeMailingFieldsPreview();
            if (preview) {
                return preview;
            }
        }
        // Khớp yêu cầu: cột Updated lấy cùng Address với Original (Main Info > Address List).
        return (
            this.formatAddress(this.permanentAddrOriginal) ||
            this.emptyDisplay
        );
    }

    get officeUpdatedDisplay() {
        const fromDto = this.formatAddress(this.officeAddr);
        if (fromDto) {
            return fromDto;
        }
        if (this.isEditingOfficeMailing) {
            const preview = this.composeMailingFieldsPreview();
            if (preview) {
                return preview;
            }
        }
        return (
            this.formatAddress(this.officeAddrOriginal) ||
            this.emptyDisplay
        );
    }

    get currentUpdatedDisplay() {
        const fromDto = this.formatAddress(this.currentAddr);
        if (fromDto) {
            return fromDto;
        }
        if (this.isEditingCurrentMailing) {
            const preview = this.composeMailingFieldsPreview();
            if (preview) {
                return preview;
            }
        }
        return (
            this.formatAddress(this.currentAddrOriginal) ||
            this.emptyDisplay
        );
    }

    /** Khi DTO chưa có chuỗi đầy đủ, ghép tạm từ form mailing (cùng nguồn GetAddressesList). */
    composeMailingFieldsPreview() {
        const parts = [
            this.mailingBuilding,
            this.mailingNumber,
            this.mailingStreet,
            this.mailingWard,
            this.mailingCity
        ].filter((p) => p != null && String(p).trim() !== '');
        return parts.length ? parts.join(', ') : '';
    }

    get permanentMailingCheckedOriginal() {
        return this.isMailingFlagYes(this.permanentAddrOriginal);
    }

    get officeMailingCheckedOriginal() {
        return this.isMailingFlagYes(this.officeAddrOriginal);
    }

    /** Cột Original: checkbox mailing chỉ hiển thị (template không dùng literal {true}). */
    get originalMailingCheckboxDisabled() {
        return true;
    }

    get emptyDisplay() {
        return '—';
    }

    syncMailingSelectionFromData() {
        const perm = this.isMailingFlagYes(this.permanentAddr);
        const cur = this.isMailingFlagYes(this.currentAddr);
        const off = this.isMailingFlagYes(this.officeAddr);
        if (perm) {
            this.mailingSelectedRow = 'permanent';
        } else if (cur) {
            this.mailingSelectedRow = 'current';
        } else if (off) {
            this.mailingSelectedRow = 'office';
        } else {
            this.mailingSelectedRow = 'permanent';
        }
    }

    buildInfoPayloadFromContext(ctx, sfAddressType, isMailingYn) {
        return {
            caseId: this.resolvedCaseId,
            sfAddressType,
            number_x: ctx.number_x || '',
            building: ctx.building || '',
            street: ctx.street || '',
            ward: ctx.ward || '',
            city: ctx.city || '',
            isMailingAddress: isMailingYn
        };
    }

    /** Gọi Apex bằng tham số primitive — tránh deserialize object lồng thành rỗng. */
    callUpdateCustomerAddress(info) {
        const x = info || {};
        return updateCustomerAddressParams({
            caseId: x.caseId != null ? String(x.caseId) : '',
            sfAddressType: x.sfAddressType ?? '',
            cifNumber: x.cifNumber ?? '',
            addressId: x.addressId ?? '',
            addressType: x.addressType ?? '',
            number_x: x.number_x ?? '',
            building: x.building ?? '',
            street: x.street ?? '',
            ward: x.ward ?? '',
            city: x.city ?? '',
            propertyStatus: x.propertyStatus ?? '',
            years: x.years ?? '',
            months: x.months ?? '',
            isMailingAddress: x.isMailingAddress ?? '',
            isPrimary: x.isPrimary ?? '',
            receiveStatement: x.receiveStatement ?? '',
            cardDelivery: x.cardDelivery ?? ''
        });
    }

    /** Trace CIF merge: client gửi caseId+sfAddressType; Apex merge cif/addressId từ getMailingAddressUpdateContext. */
    debugAddressUpdatePayload(phase, info) {
        // eslint-disable-next-line no-console
        console.debug('[fec_UpdateAddress] updateCustomerAddress', phase, {
            caseId: info?.caseId,
            sfAddressType: info?.sfAddressType,
            hasCif: Boolean(info?.cifNumber),
            hasAddressId: Boolean(info?.addressId),
            hasAddressType: Boolean(info?.addressType)
        });
    }

    sfTypeFromRow(row) {
        if (row === 'office') {
            return TYPE_OFFICE;
        }
        if (row === 'current') {
            return TYPE_CURRENT;
        }
        return TYPE_PERMANENT;
    }

    ensurePicklistValue(options, value) {
        if (!value) {
            return options || [];
        }
        const list = options || [];
        const v = String(value).trim();
        const exists = list.some((o) => {
            if (!o) {
                return false;
            }
            const ov = o.value != null ? String(o.value).trim() : '';
            const ol = o.label != null ? String(o.label).trim() : '';
            return ov === v || ol === v;
        });
        if (exists) {
            return list;
        }
        return [...list, { label: value, value: v }];
    }

    resetMailingForm() {
        this.mailingBuilding = '';
        this.mailingNumber = '';
        this.mailingStreet = '';
        this.mailingCity = '';
        this.mailingWard = '';
        this.wardOptions = [];
        this.mailingCifNumber = null;
        this.mailingAddressId = null;
        this.mailingAddressTypeApi = null;
    }

    handleEditMailing(event) {
        if (this.isEdit === false) {
            return;
        }
        const row = event.currentTarget.dataset.row;
        if (!this.resolvedCaseId || !row) {
            return;
        }
        this.mailingEditRow = row;
        this.resetMailingForm();
        this.mailingModalLoading = true;

        const sfAddressType = this.sfTypeFromRow(row);

        Promise.all([
            getProvinceOptionsForAddress(),
            getMailingAddressUpdateContext({
                caseId: this.resolvedCaseId,
                sfAddressType
            })
        ])
            .then(([provinces, ctx]) => {
                const mapped = (provinces || []).map((o) => ({
                    label: o.label != null ? o.label : o.Label,
                    value: o.value != null ? o.value : o.Value
                }));
                this.provinceOptions = dedupeProvincePicklistOptions(mapped);

                if (!ctx || !ctx.found) {
                    this.showToast(LBL_Error, ctx?.message || LBL_Error, 'error');
                    this.mailingEditRow = undefined;
                    return;
                }

                this.mailingCifNumber =
                    ctx.cifNumber != null && ctx.cifNumber !== ''
                        ? String(ctx.cifNumber).trim()
                        : null;
                this.mailingAddressId =
                    ctx.addressId != null && ctx.addressId !== ''
                        ? String(ctx.addressId).trim()
                        : null;
                this.mailingAddressTypeApi =
                    ctx.addressType != null && ctx.addressType !== ''
                        ? String(ctx.addressType).trim()
                        : null;

                this.mailingBuilding = ctx.building || '';
                this.mailingNumber = ctx.number_x || '';
                this.mailingStreet = ctx.street || '';
                this.mailingCity = ctx.city || '';
                this.mailingWard = ctx.ward || '';

                this.provinceOptions = dedupeProvincePicklistOptions(
                    this.ensurePicklistValue(
                        this.provinceOptions,
                        this.mailingCity
                    )
                );

                if (this.mailingCity) {
                    return getWardOptionsForProvinceCode({
                        provinceCode: this.mailingCity
                    }).then((wards) => {
                        const opts = (wards || []).map((w) => ({
                            label: w.label,
                            value: w.value
                        }));
                        this.wardOptions = this.ensurePicklistValue(
                            opts,
                            this.mailingWard
                        );
                    });
                }
                this.wardOptions = [];
                return undefined;
            })
            .catch((err) => {
                const msg =
                    err?.body?.message || err?.message || String(err);
                this.showToast(LBL_Error, msg, 'error');
                this.mailingEditRow = undefined;
            })
            .finally(() => {
                this.mailingModalLoading = false;
            });
    }

    handleCancelMailingEdit() {
        if (this.mailingSaveLoading) {
            return;
        }
        this.mailingEditRow = undefined;
        this.resetMailingForm();
    }

    handleMailingBuildingChange(e) {
        this.mailingBuilding = e.target.value;
    }

    handleMailingNumberChange(e) {
        this.mailingNumber = e.target.value;
    }

    handleMailingStreetChange(e) {
        this.mailingStreet = e.target.value;
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
            .catch(() => {
                this.wardOptions = [];
            });
    }

    handleMailingWardChange(e) {
        this.mailingWard = e.detail.value;
    }

    handleMailingCheckboxChange(event) {
        const row = event.currentTarget?.dataset?.row;
        const checked = event.detail?.checked === true;
        const validRows = ['permanent', 'current', 'office'];
        if (
            !validRows.includes(row) ||
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== row
        ) {
            return;
        }
        if (checked) {
            if (this.mailingSelectedRow !== row) {
                this.mailingSelectedRow = row;
                this.persistMailingSelectionOnly();
            }
            return;
        }
        if (this.mailingSelectedRow === row) {
            const order = ['permanent', 'current', 'office'];
            const idx = order.indexOf(row);
            this.mailingSelectedRow = order[(idx + 1) % order.length];
            this.persistMailingSelectionOnly();
        }
    }

    async persistMailingSelectionOnly() {
        if (this.isEdit === false) {
            return;
        }
        if (!this.resolvedCaseId || this.mailingSelectionBusy) {
            return;
        }
        this.mailingSelectionBusy = true;
        const rowTypes = [
            { row: 'permanent', sf: TYPE_PERMANENT },
            { row: 'current', sf: TYPE_CURRENT },
            { row: 'office', sf: TYPE_OFFICE }
        ];
        try {
            const contexts = await Promise.all(
                rowTypes.map((t) =>
                    getMailingAddressUpdateContext({
                        caseId: this.resolvedCaseId,
                        sfAddressType: t.sf
                    })
                )
            );
            const selected = this.mailingSelectedRow;
            const selectedIdx = rowTypes.findIndex((t) => t.row === selected);
            if (
                selectedIdx < 0 ||
                !contexts[selectedIdx] ||
                !contexts[selectedIdx].found
            ) {
                this.syncMailingSelectionFromData();
                this.showToast(
                    LBL_Error,
                    contexts[selectedIdx]?.message || LBL_Error,
                    'error'
                );
                return;
            }
            for (let i = 0; i < rowTypes.length; i++) {
                const ctx = contexts[i];
                if (!ctx?.found) {
                    continue;
                }
                const yn = rowTypes[i].row === selected ? 'Y' : 'N';
                const info = this.buildInfoPayloadFromContext(
                    ctx,
                    rowTypes[i].sf,
                    yn
                );
                this.debugAddressUpdatePayload(
                    'persistMailingSelection ' + rowTypes[i].row,
                    info
                );
                const r = await this.callUpdateCustomerAddress(info);
                if (!r?.success) {
                    this.syncMailingSelectionFromData();
                    this.showToast(
                        LBL_Error,
                        r?.errorMessage || r?.description || LBL_Error,
                        'error'
                    );
                    return;
                }
            }
            await clearMainInfoCache({ caseId: this.resolvedCaseId });
            this.showToast(LBL_UpdateSuccessfully, LBL_UpdateSuccessfully, 'success');
            this.loadAddressData();
        } catch (err) {
            this.syncMailingSelectionFromData();
            const msg =
                err?.body?.message || err?.message || String(err);
            this.showToast(LBL_Error, msg, 'error');
        } finally {
            this.mailingSelectionBusy = false;
        }
    }

    mailingFormReportValidity() {
        const root = this.template.querySelector(
            '.case-info__mailing-inline-form'
        );
        if (!root) {
            return true;
        }
        const fields = [
            ...root.querySelectorAll('lightning-input'),
            ...root.querySelectorAll('lightning-combobox'),
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

    async handleSaveMailing() {
        if (this.isEdit === false) {
            return;
        }
        if (this.mailingSaveLoading) {
            return;
        }
        if (!this.mailingFormReportValidity()) {
            return;
        }
        const row = this.mailingEditRow;
        if (!this.resolvedCaseId || !row) {
            this.showToast(LBL_Error, LBL_Error, 'error');
            return;
        }

        this.mailingSaveLoading = true;
        try {
            const primaryInfo = {
                caseId: this.resolvedCaseId,
                sfAddressType: this.sfTypeFromRow(row),
                number_x: this.mailingNumber,
                building: this.mailingBuilding,
                street: this.mailingStreet,
                ward: this.mailingWard,
                city: this.mailingCity,
                isMailingAddress:
                    this.mailingSelectedRow === row ? 'Y' : 'N'
            };

            this.debugAddressUpdatePayload('handleSaveMailing primary', primaryInfo);
            const result = await this.callUpdateCustomerAddress(primaryInfo);
            if (!result?.success) {
                const msg =
                    result?.errorMessage ||
                    result?.description ||
                    LBL_Error;
                this.showToast(LBL_Error, msg, 'error');
                return;
            }

            const allRows = [
                { row: 'permanent', sf: TYPE_PERMANENT },
                { row: 'current', sf: TYPE_CURRENT },
                { row: 'office', sf: TYPE_OFFICE }
            ];
            for (const { row: r, sf } of allRows) {
                if (r === row) {
                    continue;
                }
                const ctxOther = await getMailingAddressUpdateContext({
                    caseId: this.resolvedCaseId,
                    sfAddressType: sf
                });
                if (!ctxOther?.found) {
                    continue;
                }
                const infoOther = this.buildInfoPayloadFromContext(
                    ctxOther,
                    sf,
                    this.mailingSelectedRow === r ? 'Y' : 'N'
                );
                this.debugAddressUpdatePayload(
                    'handleSaveMailing other ' + r,
                    infoOther
                );
                const resultOther = await this.callUpdateCustomerAddress(
                    infoOther
                );
                if (!resultOther?.success) {
                    const msg =
                        resultOther?.errorMessage ||
                        resultOther?.description ||
                        LBL_Error;
                    this.showToast(LBL_Error, msg, 'error');
                    return;
                }
            }

            await clearMainInfoCache({ caseId: this.resolvedCaseId });
            this.showToast(LBL_UpdateSuccessfully, LBL_UpdateSuccessfully, 'success');
            this.mailingEditRow = undefined;
            this.resetMailingForm();
            this.loadAddressData();
        } catch (err) {
            const msg =
                err?.body?.message || err?.message || String(err);
            this.showToast(LBL_Error, msg, 'error');
        } finally {
            this.mailingSaveLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    resetNewAddressForm() {
        this.newAddrAddressType = TYPE_CURRENT;
        this.newAddrBuilding = '';
        this.newAddrNumber = '';
        this.newAddrStreet = '';
        this.newAddrCity = '';
        this.newAddrWard = '';
        this.newAddrWardOptions = [];
        this.newAddrIsMailing =
            this.mailingSelectedRow === 'permanent' ||
            this.mailingSelectedRow === 'current';
    }

    handleAddNewAddress() {
        if (this.isEdit === false) {
            return;
        }
        if (!this.resolvedCaseId) {
            this.showToast(LBL_Error, LBL_Error, 'error');
            return;
        }
        if (this.hasAllStandardAddressTypes) {
            return;
        }
        this.resetNewAddressForm();
        this.newAddressModalOpen = true;
        this.newAddressModalLoading = true;
        getProvinceOptionsForAddress()
            .then((provinces) => {
                const mapped = (provinces || []).map((o) => ({
                    label: o.label != null ? o.label : o.Label,
                    value: o.value != null ? o.value : o.Value
                }));
                this.provinceOptions = dedupeProvincePicklistOptions(mapped);
            })
            .catch(() => {
                this.showToast(LBL_Error, LBL_Error, 'error');
            })
            .finally(() => {
                this.newAddressModalLoading = false;
            });
    }

    handleCancelNewAddress() {
        if (this.newAddressSaveLoading) {
            return;
        }
        this.newAddressModalOpen = false;
        this.resetNewAddressForm();
    }

    /** Tránh click trong form đóng modal (bubble lên overlay). */
    handleNewAddressPanelClick(event) {
        event.stopPropagation();
    }

    handleNewAddressTypeChange(e) {
        const val = e.detail.value;
        this.newAddrAddressType = val || TYPE_CURRENT;
        if (this.newAddrAddressType === TYPE_OFFICE) {
            this.newAddrIsMailing = this.mailingSelectedRow === 'office';
        } else if (this.newAddrAddressType === TYPE_CURRENT) {
            this.newAddrIsMailing = this.mailingSelectedRow === 'current';
        }
    }

    handleNewAddrBuildingChange(e) {
        this.newAddrBuilding = e.target.value;
    }

    handleNewAddrNumberChange(e) {
        this.newAddrNumber = e.target.value;
    }

    handleNewAddrStreetChange(e) {
        this.newAddrStreet = e.target.value;
    }

    handleNewAddrProvinceChange(e) {
        const val = e.detail.value;
        this.newAddrCity = val;
        this.newAddrWard = '';
        this.newAddrWardOptions = [];
        if (!val) {
            return;
        }
        getWardOptionsForProvinceCode({ provinceCode: val })
            .then((wards) => {
                const opts = (wards || []).map((w) => ({
                    label: w.label,
                    value: w.value
                }));
                this.newAddrWardOptions = opts;
            })
            .catch(() => {
                this.newAddrWardOptions = [];
            });
    }

    handleNewAddrWardChange(e) {
        this.newAddrWard = e.detail.value;
    }

    handleNewAddrMailingChange(e) {
        this.newAddrIsMailing = e.detail.checked === true;
    }

    newAddressFormReportValidity() {
        const root = this.template.querySelector(
            '.case-info__new-address-form'
        );
        if (!root) {
            return true;
        }
        const fields = [
            ...root.querySelectorAll('lightning-input'),
            ...root.querySelectorAll('lightning-combobox'),
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

    async handleSaveNewAddress() {
        if (this.isEdit === false) {
            return;
        }
        if (this.newAddressSaveLoading) {
            return;
        }
        if (!this.newAddressFormReportValidity()) {
            return;
        }
        const isOffice = this.newAddrAddressType === TYPE_OFFICE;
        const isCurrent = this.newAddrAddressType === TYPE_CURRENT;
        const primaryRow = isOffice ? 'office' : 'current';
        if (!this.resolvedCaseId) {
            this.showToast(LBL_Error, LBL_Error, 'error');
            return;
        }

        this.newAddressSaveLoading = true;
        try {
            const primaryInfo = {
                caseId: this.resolvedCaseId,
                sfAddressType: this.newAddrAddressType,
                number_x: this.newAddrNumber,
                building: this.newAddrBuilding,
                street: this.newAddrStreet,
                ward: this.newAddrWard,
                city: this.newAddrCity,
                isMailingAddress: this.newAddrIsMailing ? 'Y' : 'N'
            };

            this.debugAddressUpdatePayload('handleSaveNewAddress primary', primaryInfo);
            const result = await this.callUpdateCustomerAddress(primaryInfo);
            if (!result?.success) {
                const msg =
                    result?.errorMessage ||
                    result?.description ||
                    LBL_Error;
                this.showToast(LBL_Error, msg, 'error');
                return;
            }

            const primarySf = this.newAddrAddressType;
            const otherTypes = [
                TYPE_PERMANENT,
                TYPE_CURRENT,
                TYPE_OFFICE
            ].filter((t) => t !== primarySf);
            let preferredYSf = null;
            if (!this.newAddrIsMailing) {
                if (primarySf === TYPE_CURRENT) {
                    preferredYSf = TYPE_OFFICE;
                } else if (primarySf === TYPE_OFFICE) {
                    preferredYSf = TYPE_PERMANENT;
                } else {
                    preferredYSf = TYPE_OFFICE;
                }
            }
            for (const sf of otherTypes) {
                const ctxOther = await getMailingAddressUpdateContext({
                    caseId: this.resolvedCaseId,
                    sfAddressType: sf
                });
                if (!ctxOther?.found) {
                    continue;
                }
                let yn;
                if (this.newAddrIsMailing) {
                    yn = 'N';
                } else {
                    yn = sf === preferredYSf ? 'Y' : 'N';
                }
                const infoOther = this.buildInfoPayloadFromContext(
                    ctxOther,
                    sf,
                    yn
                );
                this.debugAddressUpdatePayload(
                    'handleSaveNewAddress other ' + sf,
                    infoOther
                );
                const resultOther = await this.callUpdateCustomerAddress(
                    infoOther
                );
                if (!resultOther?.success) {
                    const msg =
                        resultOther?.errorMessage ||
                        resultOther?.description ||
                        LBL_Error;
                    this.showToast(LBL_Error, msg, 'error');
                    return;
                }
            }

            if (this.newAddrIsMailing) {
                this.mailingSelectedRow = primaryRow;
            } else if (isOffice) {
                this.mailingSelectedRow = 'permanent';
            } else if (isCurrent) {
                this.mailingSelectedRow = 'office';
            }
            await clearMainInfoCache({ caseId: this.resolvedCaseId });
            this.showToast(LBL_UpdateSuccessfully, LBL_UpdateSuccessfully, 'success');
            this.newAddressModalOpen = false;
            this.resetNewAddressForm();
            this.loadAddressData();
        } catch (err) {
            const msg =
                err?.body?.message || err?.message || String(err);
            this.showToast(LBL_Error, msg, 'error');
        } finally {
            this.newAddressSaveLoading = false;
        }
    }
}