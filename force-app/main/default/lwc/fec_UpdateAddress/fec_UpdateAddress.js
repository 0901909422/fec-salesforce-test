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
import run from '@salesforce/apex/FEC_CaseBusinessService.run';
import savePendingAddress from '@salesforce/apex/FEC_MainInfoController.savePendingAddress';

import FEC_Permanent_Address from '@salesforce/label/c.FEC_Permanent_Address';
import FEC_Office_Address from '@salesforce/label/c.FEC_Office_Address';
import FEC_Current_Address from '@salesforce/label/c.FEC_Current_Address';
import FEC_Button_Cancel from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_LBL_ContractClosure_Mailing_Address_Col from '@salesforce/label/c.FEC_LBL_ContractClosure_Mailing_Address_Col';
import FEC_LBL_ContractClosure_Building from '@salesforce/label/c.FEC_LBL_ContractClosure_Building';
import FEC_LBL_ContractClosure_Street_Number from '@salesforce/label/c.FEC_LBL_ContractClosure_Street_Number';
import FEC_LBL_ContractClosure_Street from '@salesforce/label/c.FEC_LBL_ContractClosure_Street';
import FEC_LBL_ContractClosure_Ward from '@salesforce/label/c.FEC_LBL_ContractClosure_Ward';
import FEC_LBL_ContractClosure_Address_Type from '@salesforce/label/c.FEC_LBL_ContractClosure_Address_Type';
import FEC_LBL_Province_City from '@salesforce/label/c.FEC_LBL_Province_City';
import FEC_LBL_UpdateAddress_Add_New_Address from '@salesforce/label/c.FEC_LBL_UpdateAddress_Add_New_Address';
import FEC_LBL_UpdateAddress_Edit_Mailing from '@salesforce/label/c.FEC_LBL_UpdateAddress_Edit_Mailing';
import FEC_LBL_UpdateAddress_New_Address from '@salesforce/label/c.FEC_LBL_UpdateAddress_New_Address';
import FEC_LBL_UpdateAddress_Province_Search_Placeholder from '@salesforce/label/c.FEC_LBL_UpdateAddress_Province_Search_Placeholder';
import FEC_LBL_UpdateAddress_Original_Information from '@salesforce/label/c.FEC_LBL_UpdateAddress_Original_Information';
import FEC_LBL_UpdateAddress_Updated_Information from '@salesforce/label/c.FEC_LBL_UpdateAddress_Updated_Information';
import Loading from '@salesforce/label/c.Loading';
import LBL_UpdateSuccessfully from '@salesforce/label/c.LBL_UpdateSuccessfully';
import LBL_Error from '@salesforce/label/c.LBL_Error';

const TYPE_PERMANENT = FEC_Permanent_Address;
const TYPE_OFFICE = FEC_Office_Address;
/** Địa chỉ hiện tại (API CURRES) — không trùng Permanent Address. */
const TYPE_CURRENT = FEC_Current_Address;

/** Khóa hàng mailing/radio — khớp `data-row` trên template. */
const ROW_PERMANENT = 'permanent';
const ROW_CURRENT = 'current';
const ROW_OFFICE = 'office';
/** Thứ tự hàng. */
const MAILING_ROW_ORDER = [ROW_PERMANENT, ROW_OFFICE, ROW_CURRENT];
const ADDRESS_TYPE_DISPLAY_ORDER = [TYPE_PERMANENT, TYPE_OFFICE, TYPE_CURRENT];
const ACTION_ADDRESS_UPDATE = 'Address Update';

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
        const prev = this._recordId;
        const next =
            value === null || value === undefined || value === ''
                ? undefined
                : value;
        if (
            prev &&
            next &&
            String(prev) !== String(next)
        ) {
            this.clearPendingAddressPayloads();
        }
        this._recordId = next;
        this._triggerLoadAfterCaseIdChange();
    }

    _isEditRaw;
    @api get isEdit() { return this._isEditRaw; }
    set isEdit(value) {
        this._isEditRaw = value;
    }

    /**
     * Luôn cho phép edit (hiện icon bút chì, handler, Add New Address).
     * fec_UpdateAddress tự quản lý quyền edit nội bộ; isEdit từ parent chỉ
     * dùng cho field-level readonly, không dùng để ẩn pencil icon.
     */
    get canEdit() {
        return true;
    }

    /**
     * Gọi từ fec_CaseBussiness khi Process Action "Update customer info" thất bại
     * (FEC_MSG_ACTION_PHONE_UPDATE_ERROR): khôi phục cột Updated Information về snapshot
     * địa chỉ lúc load Case (cùng dữ liệu với cột Original) và đóng form sửa.
     */
    @api revertUpdatedInformationToOriginal() {
        if (!this.mainInfoData) {
            return;
        }
        const snap = this.originalAddressesSnapshot;
        if (!Array.isArray(snap)) {
            return;
        }
        this.mainInfoData = {
            ...this.mainInfoData,
            addresses: cloneAddressesSnapshot(snap)
        };
        this.syncMailingSelectionFromData();
        this.mailingEditRow = undefined;
        this.resetMailingForm();
        this.newAddressModalOpen = false;
        this.resetNewAddressForm();
        this.clearPendingAddressPayloads();
    }

    /**
     * Gọi từ fec_CaseBussiness khi Process Action thành công (FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS):
     * xóa cache Main Info, load lại địa chỉ + mailing từ server và gán lại snapshot Original
     * theo dữ liệu mới (Updated Information = trạng thái đã commit).
     */
    @api refreshUpdatedInformationAfterProcessSuccess() {
        const caseId = this.resolvedCaseId;
        if (!caseId) {
            return Promise.resolve();
        }
        this.mailingEditRow = undefined;
        this.resetMailingForm();
        this.newAddressModalOpen = false;
        this.resetNewAddressForm();
        this.clearPendingAddressPayloads();
        this.originalSnapshotInitialized = false;
        this.originalAddressesSnapshot = undefined;
        return clearMainInfoCache({ caseId })
            .catch(() => {
                /* vẫn load lại địa chỉ */
            })
            .then(() => this.loadAddressData());
    }

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
        const prevPage = this._caseIdFromPage;
        if (
            prevPage &&
            next &&
            String(prevPage) !== String(next)
        ) {
            this.clearPendingAddressPayloads();
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
            this.originalSnapshotInitialized = false;
            this.loadAddressData();
        } else {
            this.isLoading = false;
            this.mainInfoData = null;
            this.originalAddressesSnapshot = undefined;
            this.originalSnapshotInitialized = false;
            this.clearPendingAddressPayloads();
            this.loadError = undefined;
        }
    }

    @track mainInfoData;
    /** Snapshot địa chỉ lần load đầu theo recordId — cột Original không đổi khi user sửa qua Updated. */
    @track originalAddressesSnapshot;
    @track originalSnapshotInitialized = false;
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
    /** Dòng được chọn làm mailing (`permanent` / `current` / `office`), hoặc `null` nếu không chọn. */
    @track mailingSelectedRow = null;

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
    /** Payload pending: chỉ submit API khi user bấm Process Action / Submit Case. */
    _pendingAddressUpdateMap = {};
    /** Flag: có dữ liệu địa chỉ pending đang được lưu trên Case DB (Case.FEC_Updated_Info_*_Address__c). */
    _hasPendingDbDraft = false;

    labels = {
        mailingAddress: FEC_LBL_ContractClosure_Mailing_Address_Col,
        permanentAddress: FEC_Permanent_Address,
        officeAddress: FEC_Office_Address,
        editMailing: FEC_LBL_UpdateAddress_Edit_Mailing,
        addNewAddress: FEC_LBL_UpdateAddress_Add_New_Address,
        building: FEC_LBL_ContractClosure_Building,
        number: FEC_LBL_ContractClosure_Street_Number,
        street: FEC_LBL_ContractClosure_Street,
        provinceCity: FEC_LBL_Province_City,
        provinceSearchPlaceholder: FEC_LBL_UpdateAddress_Province_Search_Placeholder,
        ward: FEC_LBL_ContractClosure_Ward,
        cancel: FEC_Button_Cancel,
        save: FEC_Button_Save,
        loading: Loading,
        newAddressTitle: FEC_LBL_UpdateAddress_New_Address,
        addressTypeLabel: FEC_LBL_ContractClosure_Address_Type,
        currentAddressOption: FEC_Current_Address,
        originalInformation: FEC_LBL_UpdateAddress_Original_Information,
        updatedInformation: FEC_LBL_UpdateAddress_Updated_Information
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
            this.originalSnapshotInitialized = false;
            return Promise.resolve();
        }

        this.isLoading = true;
        this.loadError = undefined;

        return loadMainInfo({ caseId: this.resolvedCaseId })
            .then((data) => {
                /* Không gộp addresses từ lần load trước: dễ giữ bản sai / nhầm Case khi server trả [] hoặc sau khi xóa cache. */
                this.mainInfoData = data;
                this.loadError = undefined;
                this.syncMailingSelectionFromData();
                this._hasPendingDbDraft = !!(
                    data?.pendingPermanentAddressJson ||
                    data?.pendingOfficeAddressJson ||
                    data?.pendingCurrentAddressJson
                );

                if (!this.originalSnapshotInitialized) {
                    this.originalAddressesSnapshot = cloneAddressesSnapshot(
                        data?.addresses
                    );
                    this.originalSnapshotInitialized = true;
                }

                if (this._hasPendingDbDraft) {
                    this._applyPendingAddressTextsToDisplay(data);
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

    /**
     * Sau khi loadMainInfo trả về dữ liệu, mainInfoData.addresses vẫn chứa dữ liệu cũ
     * từ FEC_Full_Address__c (CIF cache). Nếu Case có pending address JSON đã được save
     * vào FEC_Updated_Info_*_Address__c, parse và cập nhật phần address text tương ứng
     * trong mainInfoData.addresses để cột "Updated Information" hiển thị đúng.
     * Không thay đổi mailingAddress flag (đã được xử lý bởi syncMailingSelectionFromData).
     */
    _applyPendingAddressTextsToDisplay(data) {
        const pendingEntries = [
            { json: data?.pendingPermanentAddressJson, sfType: TYPE_PERMANENT },
            { json: data?.pendingOfficeAddressJson,    sfType: TYPE_OFFICE    },
            { json: data?.pendingCurrentAddressJson,   sfType: TYPE_CURRENT   }
        ];
        const addresses = Array.isArray(this.mainInfoData?.addresses)
            ? this.mainInfoData.addresses.map((a) => ({ ...a }))
            : [];
        let dirty = false;
        for (const { json, sfType } of pendingEntries) {
            if (!json) {
                continue;
            }
            let p;
            try {
                p = JSON.parse(json);
            } catch (e) {
                continue;
            }
            if (!p) {
                continue;
            }
            const composed = this.composeAddressText(
                p.building, p.number_x, p.street, p.ward, p.city
            );
            if (!composed) {
                continue;
            }
            const idx = addresses.findIndex((a) => a && a.addressType === sfType);
            if (idx >= 0) {
                addresses[idx] = { ...addresses[idx], address: composed };
            } else {
                addresses.push({ addressType: sfType, address: composed, mailingAddress: '' });
            }
            dirty = true;
        }
        if (dirty) {
            this.mainInfoData = { ...(this.mainInfoData || {}), addresses };
        }
    }

    get isLoaded() {
        return !this.isLoading;
    }

    get showAddressEligibilityBlock() {
        const t = this.mainInfoData?.addressUpdateNotEligibleTitle;
        return t != null && String(t).trim() !== '';
    }

    get addressEligibilityTitle() {
        return this.mainInfoData?.addressUpdateNotEligibleTitle ?? '';
    }

    get addressEligibilityReasonLines() {
        const reasons = this.mainInfoData?.addressUpdateNotEligibleReasons;
        if (!Array.isArray(reasons) || reasons.length === 0) {
            return [];
        }
        return reasons.map((text, index) => ({
            key: `addr-elig-${index}`,
            text: text != null ? String(text) : ''
        }));
    }

    get wardComboboxDisabled() {
        return !this.mailingCity;
    }

    get mailingRadiosDisabled() {
        return this.mailingSaveLoading || this.isLoading;
    }

    /**
     * Checkbox mailing: chỉ bật trên đúng dòng đang edit (tránh đổi mailing sang
     * type khác giữa lúc mở form). Lưu server khi bấm Save, không auto-save.
     */
    get permanentMailingCheckboxDisabled() {
        return (
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== ROW_PERMANENT
        );
    }

    get currentMailingCheckboxDisabled() {
        return (
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== ROW_CURRENT
        );
    }

    get officeMailingCheckboxDisabled() {
        return (
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== ROW_OFFICE
        );
    }

    get permanentMailingRadioChecked() {
        return this.mailingSelectedRow === ROW_PERMANENT;
    }

    get officeMailingRadioChecked() {
        return this.mailingSelectedRow === ROW_OFFICE;
    }

    get currentMailingRadioChecked() {
        return this.mailingSelectedRow === ROW_CURRENT;
    }

    get mailingSaveOrFormBusy() {
        return this.mailingModalLoading || this.mailingSaveLoading;
    }

    get mailingSaveButtonDisabled() {
        return this.mailingSaveOrFormBusy;
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

    get newAddrWardComboboxDisabled() {
        return !this.newAddrCity || this.newAddressSaveLoading;
    }

    get newAddressFormBusy() {
        return this.newAddressModalLoading || this.newAddressSaveLoading;
    }

    get newAddressSubmitDisabled() {
        return this.newAddressFormBusy;
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
        return this.mailingEditRow === ROW_PERMANENT;
    }

    get isEditingOfficeMailing() {
        return this.mailingEditRow === ROW_OFFICE;
    }

    get isEditingCurrentMailing() {
        return this.mailingEditRow === ROW_CURRENT;
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

    /** Mảng địa chỉ cho cột Original — snapshot lần load; nếu chưa có thì dùng addresses từ Main Info (cùng nguồn GetAddressesList). */
    get originalAddressesSourceList() {
        if (this.originalSnapshotInitialized) {
            return Array.isArray(this.originalAddressesSnapshot)
                ? this.originalAddressesSnapshot
                : [];
        }
        if (Array.isArray(this.originalAddressesSnapshot)) {
            return this.originalAddressesSnapshot;
        }
        const live = this.mainInfoData?.addresses;
        return Array.isArray(live) ? live : [];
    }

    /** Một hàng / phần tử DTO addresses; không có addressType thì bỏ qua. */
    get originalInformationRows() {
        const list = this.originalAddressesSourceList;
        if (!Array.isArray(list) || list.length === 0) {
            return [];
        }
        return list
            .filter((a) => a && a.addressType)
            .sort((a, b) => {
                const idxA = ADDRESS_TYPE_DISPLAY_ORDER.indexOf(a.addressType);
                const idxB = ADDRESS_TYPE_DISPLAY_ORDER.indexOf(b.addressType);
                const rankA = idxA >= 0 ? idxA : Number.MAX_SAFE_INTEGER;
                const rankB = idxB >= 0 ? idxB : Number.MAX_SAFE_INTEGER;
                if (rankA !== rankB) {
                    return rankA - rankB;
                }
                return String(a.addressType || '').localeCompare(
                    String(b.addressType || ''),
                    'vi'
                );
            })
            .map((a, index) => ({
                key: `fec-orig-${index}-${a.addressType}`,
                typeLabel: a.addressType,
                addressDisplay: this.formatAddress(a),
                mailingChecked: this.isMailingFlagYes(a)
            }));
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
        return this.isLoading || this.hasAllStandardAddressTypes;
    }

    formatAddress(addr) {
        if (!addr || !addr.address) {
            return '';
        }
        return addr.address;
    }

    /** Cờ địa chỉ giao phát (DTO map từ SF: có giá trị, thường là "Yes"). */
    isMailingFlagYes(addr) {
        if (!addr || addr.mailingAddress == null || addr.mailingAddress === '') {
            return false;
        }
        return true;
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
            this.mailingSelectedRow = ROW_PERMANENT;
        } else if (off) {
            this.mailingSelectedRow = ROW_OFFICE;
        } else if (cur) {
            this.mailingSelectedRow = ROW_CURRENT;
        } else {
            this.mailingSelectedRow = null;
        }
    }

    buildInfoPayloadFromContext(ctx, sfAddressType, isMailingYn) {
        return {
            caseId: this.resolvedCaseId,
            sfAddressType,
            cifNumber:
                ctx.cifNumber != null && String(ctx.cifNumber).trim() !== ''
                    ? String(ctx.cifNumber).trim()
                    : '',
            addressId:
                ctx.addressId != null && String(ctx.addressId).trim() !== ''
                    ? String(ctx.addressId).trim()
                    : '',
            addressType:
                ctx.addressType != null && String(ctx.addressType).trim() !== ''
                    ? String(ctx.addressType).trim()
                    : '',
            number_x: ctx.number_x || '',
            building: ctx.building || '',
            street: ctx.street || '',
            ward: ctx.ward || '',
            city: ctx.city || '',
            isMailingAddress: isMailingYn
        };
    }

    rowFromSfAddressType(sfAddressType) {
        if (sfAddressType === TYPE_OFFICE) {
            return ROW_OFFICE;
        }
        if (sfAddressType === TYPE_CURRENT) {
            return ROW_CURRENT;
        }
        return ROW_PERMANENT;
    }

    composeAddressText(building, number_x, street, ward, city) {
        return [building, number_x, street, ward, city]
            .filter((p) => p != null && String(p).trim() !== '')
            .join(', ');
    }

    queuePendingAddressPayload(info) {
        if (!info || !info.sfAddressType) {
            return;
        }
        const sfType = info.sfAddressType;
        this._pendingAddressUpdateMap = {
            ...(this._pendingAddressUpdateMap || {}),
            [sfType]: {
                ...info,
                caseId: this.resolvedCaseId
            }
        };
    }

    hasPendingAddressUpdates() {
        return this._hasPendingDbDraft;
    }

    clearPendingAddressPayloads() {
        this._hasPendingDbDraft = false;
        this._pendingAddressUpdateMap = {};
    }

    applyLocalAddressAndMailing(sfAddressType, addressText, selectedRow) {
        const list = Array.isArray(this.mainInfoData?.addresses)
            ? this.mainInfoData.addresses
            : [];
        const finalSelectedRow = selectedRow || null;
        const next = [];
        let found = false;
        list.forEach((item) => {
            if (!item) {
                return;
            }
            const isSameType = item.addressType === sfAddressType;
            const row = this.rowFromSfAddressType(item.addressType);
            const nextItem = {
                ...item,
                address: isSameType && String(addressText || '').trim() !== ''
                    ? addressText
                    : item.address,
                mailingAddress: row === finalSelectedRow ? 'Y' : ''
            };
            found = found || isSameType;
            next.push(nextItem);
        });
        if (!found && String(addressText || '').trim() !== '') {
            next.push({
                addressType: sfAddressType,
                address: addressText,
                mailingAddress:
                    this.rowFromSfAddressType(sfAddressType) === finalSelectedRow
                        ? 'Y'
                        : ''
            });
        }
        this.mainInfoData = {
            ...(this.mainInfoData || {}),
            addresses: next
        };
        this.mailingSelectedRow = finalSelectedRow;
    }

    /**
     * Chỉ được gọi khi user bấm Process Action.
     * Lúc này mới thực hiện API update địa chỉ theo các payload đã Save tạm trên UI.
     */
    @api
    async commitPendingAddressUpdatesForProcessAction() {
        if (!this.hasPendingAddressUpdates()) {
            return {
                success: false,
                actionCount: 0,
                errorMessage: LBL_Error
            };
        }
        const res = await run({
            method: ACTION_ADDRESS_UPDATE,
            params: { caseId: this.resolvedCaseId }
        });
        if (res?.success) {
            this._hasPendingDbDraft = false;
        }
        return res || { success: false };
    }

    sfTypeFromRow(row) {
        if (row === ROW_OFFICE) {
            return TYPE_OFFICE;
        }
        if (row === ROW_CURRENT) {
            return TYPE_CURRENT;
        }
        return TYPE_PERMANENT;
    }

    getAddressByRow(row) {
        if (row === ROW_OFFICE) {
            return this.officeAddr;
        }
        if (row === ROW_CURRENT) {
            return this.currentAddr;
        }
        return this.permanentAddr;
    }

    isRowMailingInData(row) {
        return this.isMailingFlagYes(this.getAddressByRow(row));
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
        const row = event.currentTarget.dataset.row;
        if (!this.resolvedCaseId || !row || !this.canEdit) {
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
        if (
            !MAILING_ROW_ORDER.includes(row) ||
            this.mailingRadiosDisabled ||
            !this.mailingEditRow ||
            this.mailingEditRow !== row
        ) {
            return;
        }
        if (checked) {
            if (this.mailingSelectedRow !== row) {
                this.mailingSelectedRow = row;
            }
            return;
        }
        if (this.mailingSelectedRow === row) {
            this.mailingSelectedRow = null;
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
            const selectedRow = this.mailingSelectedRow;
            const primarySfAddressType = this.sfTypeFromRow(row);
            const primaryInfo = {
                caseId: this.resolvedCaseId,
                sfAddressType: primarySfAddressType,
                cifNumber:
                    this.mailingCifNumber != null
                        ? String(this.mailingCifNumber).trim()
                        : '',
                addressId:
                    this.mailingAddressId != null
                        ? String(this.mailingAddressId).trim()
                        : '',
                addressType:
                    this.mailingAddressTypeApi != null
                        ? String(this.mailingAddressTypeApi).trim()
                        : '',
                number_x: this.mailingNumber,
                building: this.mailingBuilding,
                street: this.mailingStreet,
                ward: this.mailingWard,
                city: this.mailingCity,
                isMailingAddress:
                    selectedRow === row ? 'Y' : 'N'
            };
            // eslint-disable-next-line no-await-in-loop
            await savePendingAddress({
                caseId: this.resolvedCaseId,
                sfAddressType: primarySfAddressType,
                jsonPayload: JSON.stringify(primaryInfo)
            });
            this._hasPendingDbDraft = true;

            const allRows = [
                { row: ROW_PERMANENT, sf: TYPE_PERMANENT },
                { row: ROW_OFFICE, sf: TYPE_OFFICE },
                { row: ROW_CURRENT, sf: TYPE_CURRENT }
            ];
            for (const { row: r, sf } of allRows) {
                if (r === row) {
                    continue;
                }
                const desiredYn = selectedRow === r ? 'Y' : 'N';
                const currentYn = this.isRowMailingInData(r) ? 'Y' : 'N';
                if (desiredYn === currentYn) {
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
                    desiredYn
                );
                // eslint-disable-next-line no-await-in-loop
                await savePendingAddress({
                    caseId: this.resolvedCaseId,
                    sfAddressType: sf,
                    jsonPayload: JSON.stringify(infoOther)
                });
            }

            const composedAddress = this.composeAddressText(
                this.mailingBuilding,
                this.mailingNumber,
                this.mailingStreet,
                this.mailingWard,
                this.mailingCity
            );
            this.applyLocalAddressAndMailing(
                primarySfAddressType,
                composedAddress,
                selectedRow
            );
            this.showToast(LBL_UpdateSuccessfully, LBL_UpdateSuccessfully, 'success');
            this.mailingEditRow = undefined;
            this.resetMailingForm();
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
            this.mailingSelectedRow === ROW_PERMANENT ||
            this.mailingSelectedRow === ROW_CURRENT;
    }

    handleAddNewAddress() {
        if (!this.resolvedCaseId) {
            this.showToast(LBL_Error, LBL_Error, 'error');
            return;
        }
        if (this.hasAllStandardAddressTypes || !this.canEdit) {
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
            this.newAddrIsMailing = this.mailingSelectedRow === ROW_OFFICE;
        } else if (this.newAddrAddressType === TYPE_CURRENT) {
            this.newAddrIsMailing = this.mailingSelectedRow === ROW_CURRENT;
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
        if (this.newAddressSaveLoading) {
            return;
        }
        if (!this.newAddressFormReportValidity()) {
            return;
        }
        const isOffice = this.newAddrAddressType === TYPE_OFFICE;
        const isCurrent = this.newAddrAddressType === TYPE_CURRENT;
        const primaryRow = isOffice ? ROW_OFFICE : ROW_CURRENT;
        if (!this.resolvedCaseId) {
            this.showToast(LBL_Error, LBL_Error, 'error');
            return;
        }

        this.newAddressSaveLoading = true;
        try {
            let nextSelectedRow = this.mailingSelectedRow;
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
            this.queuePendingAddressPayload(primaryInfo);

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
                this.queuePendingAddressPayload(infoOther);
            }

            if (this.newAddrIsMailing) {
                nextSelectedRow = primaryRow;
            } else if (isOffice) {
                nextSelectedRow = ROW_PERMANENT;
            } else if (isCurrent) {
                nextSelectedRow = ROW_OFFICE;
            }
            const composedAddress = this.composeAddressText(
                this.newAddrBuilding,
                this.newAddrNumber,
                this.newAddrStreet,
                this.newAddrWard,
                this.newAddrCity
            );
            this.applyLocalAddressAndMailing(
                this.newAddrAddressType,
                composedAddress,
                nextSelectedRow
            );
            this.showToast(LBL_UpdateSuccessfully, LBL_UpdateSuccessfully, 'success');
            this.newAddressModalOpen = false;
            this.resetNewAddressForm();
        } catch (err) {
            const msg =
                err?.body?.message || err?.message || String(err);
            this.showToast(LBL_Error, msg, 'error');
        } finally {
            this.newAddressSaveLoading = false;
        }
    }
}