import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import loadMainInfo from '@salesforce/apex/FEC_MainInfoController.loadMainInfo';
import clearMainInfoCache from '@salesforce/apex/FEC_MainInfoController.clearMainInfoCache';
import getMailingAddressUpdateContext from '@salesforce/apex/FEC_MainInfoController.getMailingAddressUpdateContext';
import getProvinceOptionsForAddress from '@salesforce/apex/FEC_MainInfoController.getProvinceOptionsForAddress';
import getProvinceOptionsForCountryFecCode from '@salesforce/apex/FEC_MainInfoController.getProvinceOptionsForCountryFecCode';
import normalizeProvinceCodeForAddressUi from '@salesforce/apex/FEC_MainInfoController.normalizeProvinceCodeForAddressUi';
import getDistrictOptionsForProvinceCode from '@salesforce/apex/FEC_MainInfoController.getDistrictOptionsForProvinceCode';
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
import FEC_LBL_UpdateAddress_Ward_Search_Placeholder from '@salesforce/label/c.FEC_LBL_UpdateAddress_Ward_Search_Placeholder';
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
/** Add New Address: chỉ dùng master tỉnh/TP thuộc FEC_Country__c.FEC_Code__c = 2 (khớp API CIF). */
const FEC_COUNTRY_FEC_CODE_FOR_NEW_ADDRESS = '2';
/**
 * Tạm thời: bật icon edit mailing + Add New Address dù parent không set isEdit=true.
 * Đặt false (hoặc xóa nhánh) trước khi merge production.
 */
const TEMP_FORCE_CAN_EDIT = true;

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
 * Gộp option trùng mã tỉnh (value). Sau đó gộp trùng nhãn (cùng tên khác mã trong master).
 * Khi gộp theo nhãn: ưu tiên giữ dòng có value === preferredProvinceCode (mã CIF trên form)
 * để lightning-combobox vẫn resolve được nhãn thay vì hiện raw "93".
 * @param {Array} options
 * @param {string} [preferredProvinceCode] mã tỉnh đang chọn (ctx.city / pending.city)
 */
function dedupeProvincePicklistOptions(options, preferredProvinceCode) {
    if (!Array.isArray(options) || options.length === 0) {
        return [];
    }
    const pref =
        preferredProvinceCode != null &&
        String(preferredProvinceCode).trim() !== ''
            ? String(preferredProvinceCode).trim()
            : null;

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
    const sorted = [...byValue.values()].sort((a, b) =>
        String(a.label || '').localeCompare(String(b.label || ''), 'vi')
    );

    const groupKey = (row) => {
        const raw = String(row.label || '').trim();
        if (raw === '') {
            return `__empty__${String(row.value || '').trim()}`;
        }
        return raw.toLowerCase();
    };

    const groups = new Map();
    for (const row of sorted) {
        const gk = groupKey(row);
        if (!groups.has(gk)) {
            groups.set(gk, []);
        }
        groups.get(gk).push(row);
    }

    const out = [];
    for (const rows of groups.values()) {
        if (rows.length === 1) {
            out.push(rows[0]);
            continue;
        }
        let chosen = rows[0];
        if (pref != null) {
            const hit = rows.find((r) => String(r.value).trim() === pref);
            if (hit) {
                chosen = hit;
            }
        }
        out.push(chosen);
    }
    return out.sort((a, b) =>
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

    get canEdit() {
        return this._isEditRaw === true || this._isEditRaw === 'true';
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
    @track mailingDistrict = '';

    @track provinceOptions = [];
    @track districtOptions = [];

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
    @track newAddrDistrict = '';
    @track newAddrDistrictOptions = [];
    /** Tỉnh/TP cho popup Add New — chỉ bộ quốc gia FEC_Code__c = 2. */
    @track newAddrProvinceOptions = [];
    @track newAddrIsMailing = false;

    _lastFetchKey = 'fec-update-address-unset';

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
        wardSearchPlaceholder: FEC_LBL_UpdateAddress_Ward_Search_Placeholder,
        /** Nhãn "Ward" trên UI cho combobox chọn mã quận/huyện (lưu DB/API: `district` / FEC_District__c). */
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
     * vào FEC_Updated_Info_*_Address__c, parse và cập nhật address text lẫn mailingAddress
     * tương ứng trong mainInfoData.addresses để cột "Updated Information" hiển thị đúng.
     * Sau khi áp dụng, gọi lại syncMailingSelectionFromData để cập nhật trạng thái checkbox.
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
            const distDisp =
                p.districtLabel != null && String(p.districtLabel).trim() !== ''
                    ? String(p.districtLabel).trim()
                    : p.district;
            const cityDisp =
                p.cityLabel != null && String(p.cityLabel).trim() !== ''
                    ? String(p.cityLabel).trim()
                    : p.city;
            const composed = this.composeAddressText(
                p.building,
                p.number_x,
                p.street,
                distDisp,
                cityDisp
            );
            if (!composed) {
                continue;
            }
            const mailingFlag = p.isMailingAddress === 'Y' ? 'Y' : '';
            const idx = addresses.findIndex((a) => a && a.addressType === sfType);
            if (idx >= 0) {
                addresses[idx] = { ...addresses[idx], address: composed, mailingAddress: mailingFlag };
            } else {
                addresses.push({ addressType: sfType, address: composed, mailingAddress: mailingFlag });
            }
            dirty = true;
        }
        if (dirty) {
            this.mainInfoData = { ...(this.mainInfoData || {}), addresses };
            this.syncMailingSelectionFromData();
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

    get districtComboboxDisabled() {
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

    /**
     * Chỉ các loại chưa có trong `mainInfoData.addresses` (sau merge pending).
     */
    get newAddressTypeOptions() {
        const present = new Set();
        const list = this.mainInfoData?.addresses;
        if (Array.isArray(list)) {
            for (const a of list) {
                if (a && a.addressType) {
                    present.add(a.addressType);
                }
            }
        }
        const all = [
            { label: this.labels.permanentAddress, value: TYPE_PERMANENT },
            { label: this.labels.officeAddress, value: TYPE_OFFICE },
            { label: this.labels.currentAddressOption, value: TYPE_CURRENT }
        ];
        return all.filter((o) => !present.has(o.value));
    }

    _syncNewAddrMailingDefaultForType() {
        if (this.newAddrAddressType === TYPE_OFFICE) {
            this.newAddrIsMailing = this.mailingSelectedRow === ROW_OFFICE;
        } else if (this.newAddrAddressType === TYPE_CURRENT) {
            this.newAddrIsMailing = this.mailingSelectedRow === ROW_CURRENT;
        } else {
            this.newAddrIsMailing = this.mailingSelectedRow === ROW_PERMANENT;
        }
    }

    get newAddrDistrictComboboxDisabled() {
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

    /** Id FEC_Address_Info__c gốc (CIF, không gắn Case) để set FEC_Parent_Address__c khi lưu pending. */
    _parentAddressIdForSfType(sfAddressType) {
        const fromSnap = this.findAddress(
            sfAddressType,
            this.originalAddressesSourceList
        );
        if (fromSnap?.addressInfoId) {
            return fromSnap.addressInfoId;
        }
        const live = this.findAddress(sfAddressType, this.mainInfoData?.addresses);
        return live?.addressInfoId || null;
    }

    _savePendingAddressRecord(p) {
        const {
            sfAddressType,
            deletePending,
            parentAddressInfoId,
            building,
            number_x,
            street,
            district,
            city,
            isMailingAddress
        } = p;
        return savePendingAddress({
            caseId: this.resolvedCaseId,
            sfAddressType,
            deletePending: deletePending === true,
            parentAddressInfoId: parentAddressInfoId || null,
            building: building ?? '',
            number_x: number_x ?? '',
            street: street ?? '',
            districtCode: district ?? '',
            provinceCode: city ?? '',
            isMailingAddress: isMailingAddress === true
        });
    }

    /** Mảng địa chỉ cho cột Original — snapshot lần load; nếu chưa có thì dùng addresses từ Main Info (cùng nguồn GetAddressesList). */
    get originalAddressesSourceList() {
        if (this.originalSnapshotInitialized) {
            return Array.isArray(this.originalAddressesSnapshot)
                ? this.originalAddressesSnapshot
                : [];
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
            .filter(
                (a) => a && a.addressType && this.hasAddressData(a)
            )
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
                wardDisplay: a.ward != null && String(a.ward).trim() !== '' ? String(a.ward).trim() : '',
                mailingChecked: this.isMailingFlagYes(a)
            }));
    }

    /** Đủ 3 loại trong `mainInfoData.addresses` (sau gộp pending) — không cho Add New Address. */
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
        return this.isLoading || this.hasAllStandardAddressTypes || !this.canEdit;
    }

    /**
     * Bỏ hậu tố quốc gia (ví dụ ", VIETNAM") khi hiển thị Original / Updated — không sửa dữ liệu gốc.
     */
    stripTrailingCountryForDisplay(raw) {
        if (raw == null || String(raw).trim() === '') {
            return '';
        }
        let s = String(raw).trim();
        // Lặp để gỡ nhiều lần nếu chuỗi lạ; khớp VIETNAM / VIET NAM (không phân biệt hoa thường)
        for (;;) {
            const next = s.replace(/,\s*VIET\s*NAM\s*$/i, '').trim();
            if (next === s) {
                return s;
            }
            s = next;
        }
    }

    formatAddress(addr) {
        if (!addr || !addr.address) {
            return '';
        }
        return this.stripTrailingCountryForDisplay(addr.address);
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

    hasAddressData(addr) {
        return this.formatAddress(addr) !== '';
    }

    get showPermanentUpdatedRow() {
        return (
            this.isEditingPermanentMailing ||
            this.hasAddressData(this.permanentAddr) ||
            this.hasAddressData(this.permanentAddrOriginal)
        );
    }

    get showOfficeUpdatedRow() {
        return (
            this.isEditingOfficeMailing ||
            this.hasAddressData(this.officeAddr) ||
            this.hasAddressData(this.officeAddrOriginal)
        );
    }

    get showCurrentUpdatedRow() {
        return (
            this.isEditingCurrentMailing ||
            this.hasAddressData(this.currentAddr) ||
            this.hasAddressData(this.currentAddrOriginal)
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
            this.mailingDistrict,
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
            district:
                ctx.district != null && String(ctx.district).trim() !== ''
                    ? String(ctx.district).trim()
                    : '',
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

    composeAddressText(building, number_x, street, district, city) {
        return [building, number_x, street, district, city]
            .filter((p) => p != null && String(p).trim() !== '')
            .join(', ');
    }

    /** Lấy label hiển thị từ lightning-combobox / searchable options (value = mã master). */
    _labelFromOptions(options, value) {
        if (value == null || String(value).trim() === '') {
            return '';
        }
        const v = String(value).trim();
        const list = Array.isArray(options) ? options : [];
        for (const o of list) {
            if (!o) {
                continue;
            }
            const ov = o.value != null ? String(o.value).trim() : '';
            if (ov === v) {
                const lab = o.label != null ? String(o.label).trim() : '';
                return lab || v;
            }
        }
        return v;
    }

    hasPendingAddressUpdates() {
        return this._hasPendingDbDraft;
    }

    clearPendingAddressPayloads() {
        this._hasPendingDbDraft = false;
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
        this.mailingDistrict = '';
        this.districtOptions = [];
        this.mailingCifNumber = null;
        this.mailingAddressId = null;
        this.mailingAddressTypeApi = null;
    }

    /** Trả về key field pending JSON trong mainInfoData tương ứng với sfAddressType. */
    _pendingJsonFieldKey(sfAddressType) {
        if (sfAddressType === TYPE_PERMANENT) {
            return 'pendingPermanentAddressJson';
        }
        if (sfAddressType === TYPE_OFFICE) {
            return 'pendingOfficeAddressJson';
        }
        if (sfAddressType === TYPE_CURRENT) {
            return 'pendingCurrentAddressJson';
        }
        return null;
    }

    /**
     * Parse pending JSON cho sfAddressType từ mainInfoData.
     * Trả về object (building, number_x, street, district, city, ...) hoặc null nếu chưa có.
     * Trả về null nếu _hasPendingDbDraft = false (đã revert hoặc đã commit thành công)
     * để form edit quay về lấy dữ liệu gốc từ CIF qua getMailingAddressUpdateContext.
     */
    _parsePendingJsonForType(sfAddressType) {
        if (!this._hasPendingDbDraft) {
            return null;
        }
        const key = this._pendingJsonFieldKey(sfAddressType);
        if (!key) {
            return null;
        }
        const json = this.mainInfoData?.[key];
        if (!json) {
            return null;
        }
        try {
            return JSON.parse(json);
        } catch (e) {
            return null;
        }
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
        const pendingData = this._parsePendingJsonForType(sfAddressType);

        if (pendingData) {
            // Lần 2+: lấy dữ liệu từ pending JSON đã lưu vào Case (chuẩn hóa mã tỉnh legacy → bộ picklist UI)
            const rawCity =
                pendingData.city != null && String(pendingData.city).trim() !== ''
                    ? String(pendingData.city).trim()
                    : '';
            normalizeProvinceCodeForAddressUi({ cityCode: rawCity })
                .then((norm) => {
                    const cityCode =
                        norm != null && String(norm).trim() !== ''
                            ? String(norm).trim()
                            : rawCity;
                    return Promise.all([
                        getProvinceOptionsForAddress(),
                        cityCode
                            ? getDistrictOptionsForProvinceCode({
                                  provinceCode: cityCode
                              })
                            : Promise.resolve([])
                    ]).then(([provinces, districts]) => {
                    const mapped = (provinces || []).map((o) => ({
                        label: o.label != null ? o.label : o.Label,
                        value: o.value != null ? o.value : o.Value
                    }));
                    this.provinceOptions = dedupeProvincePicklistOptions(mapped);

                    this.mailingCifNumber =
                        pendingData.cifNumber != null && pendingData.cifNumber !== ''
                            ? String(pendingData.cifNumber).trim()
                            : null;
                    this.mailingAddressId =
                        pendingData.addressId != null && pendingData.addressId !== ''
                            ? String(pendingData.addressId).trim()
                            : null;
                    this.mailingAddressTypeApi =
                        pendingData.addressType != null && pendingData.addressType !== ''
                            ? String(pendingData.addressType).trim()
                            : null;

                    this.mailingBuilding = pendingData.building || '';
                    this.mailingNumber = pendingData.number_x || '';
                    this.mailingStreet = pendingData.street || '';

                    const cityInOptsPending = cityCode !== '' && this.provinceOptions.some(
                        (o) => String(o.value != null ? o.value : '').trim() === cityCode
                    );
                    this.mailingCity = cityInOptsPending ? cityCode : '';
                    this.mailingDistrict = cityInOptsPending ? (pendingData.district || '') : '';
                    this.provinceOptions = dedupeProvincePicklistOptions(this.provinceOptions);

                    if (this.mailingCity && Array.isArray(districts) && districts.length > 0) {
                        const dOpts = districts.map((d) => ({
                            label: d.label,
                            value: d.value
                        }));
                        this.districtOptions = this.ensurePicklistValue(
                            dOpts,
                            this.mailingDistrict
                        );
                    } else {
                        this.districtOptions = [];
                    }

                    const hadDistrictInJson =
                        pendingData.district != null &&
                        String(pendingData.district).trim() !== '';
                    const hasCity = String(this.mailingCity || '').trim() !== '';
                    if (!hadDistrictInJson && hasCity) {
                        return getMailingAddressUpdateContext({
                            caseId: this.resolvedCaseId,
                            sfAddressType
                        }).then((ctx) => {
                            const d =
                                ctx?.found &&
                                ctx.district != null &&
                                String(ctx.district).trim() !== ''
                                    ? String(ctx.district).trim()
                                    : '';
                            if (!d) {
                                return undefined;
                            }
                            this.mailingDistrict = d;
                            this.districtOptions = this.ensurePicklistValue(
                                this.districtOptions,
                                this.mailingDistrict
                            );
                            const pendingSanitized = { ...pendingData };
                            delete pendingSanitized.ward;
                            const enriched = {
                                ...pendingSanitized,
                                district: d,
                                city: String(this.mailingCity || '').trim() || pendingSanitized.city
                            };
                            return this._savePendingAddressRecord({
                                sfAddressType,
                                deletePending: false,
                                parentAddressInfoId:
                                    this._parentAddressIdForSfType(sfAddressType),
                                building: enriched.building ?? '',
                                number_x: enriched.number_x ?? '',
                                street: enriched.street ?? '',
                                district: enriched.district ?? '',
                                city: enriched.city ?? '',
                                isMailingAddress: enriched.isMailingAddress === 'Y'
                            }).then(() => {
                                const pk = this._pendingJsonFieldKey(sfAddressType);
                                if (pk) {
                                    this.mainInfoData = {
                                        ...(this.mainInfoData || {}),
                                        [pk]: JSON.stringify(enriched)
                                    };
                                }
                            });
                        });
                    }
                    return undefined;
                    });
                })
                .catch((err) => {
                    const msg = err?.body?.message || err?.message || String(err);
                    this.showToast(LBL_Error, msg, 'error');
                    this.mailingEditRow = undefined;
                })
                .finally(() => {
                    this.mailingModalLoading = false;
                });
        } else {
            // Lần đầu tiên: lấy dữ liệu từ CIF qua getMailingAddressUpdateContext
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

                    const rawCity = ctx.city || '';
                    const cityInOptsFirst = rawCity !== '' && this.provinceOptions.some(
                        (o) => String(o.value != null ? o.value : '').trim() === rawCity
                    );
                    this.mailingCity = cityInOptsFirst ? rawCity : '';
                    this.mailingDistrict = cityInOptsFirst ? (ctx.district || '') : '';
                    this.provinceOptions = dedupeProvincePicklistOptions(this.provinceOptions);

                    if (this.mailingCity) {
                        return getDistrictOptionsForProvinceCode({
                            provinceCode: this.mailingCity
                        }).then((districts) => {
                            const dOpts = (districts || []).map((d) => ({
                                label: d.label,
                                value: d.value
                            }));
                            this.districtOptions = this.ensurePicklistValue(
                                dOpts,
                                this.mailingDistrict
                            );
                        });
                    }
                    this.districtOptions = [];
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
        this.mailingDistrict = '';
        this.districtOptions = [];
        if (!val) {
            return;
        }
        getDistrictOptionsForProvinceCode({ provinceCode: val })
            .then((districts) => {
                this.districtOptions = (districts || []).map((d) => ({
                    label: d.label,
                    value: d.value
                }));
            })
            .catch(() => {
                this.districtOptions = [];
            });
    }

    handleMailingDistrictChange(e) {
        this.mailingDistrict = e.detail.value;
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
                district:
                    this.mailingDistrict != null &&
                    String(this.mailingDistrict).trim() !== ''
                        ? String(this.mailingDistrict).trim()
                        : '',
                city:
                    this.mailingCity != null &&
                    String(this.mailingCity).trim() !== ''
                        ? String(this.mailingCity).trim()
                        : '',
                /* Chỉ phục vụ hiển thị / compose; Apex Update chỉ đọc city, district (mã). */
                cityLabel: this._labelFromOptions(
                    this.provinceOptions,
                    this.mailingCity
                ),
                districtLabel: this._labelFromOptions(
                    this.districtOptions,
                    this.mailingDistrict
                ),
                isMailingAddress:
                    selectedRow === row ? 'Y' : 'N'
            };
            // eslint-disable-next-line no-await-in-loop
            await this._savePendingAddressRecord({
                sfAddressType: primarySfAddressType,
                deletePending: false,
                parentAddressInfoId:
                    this._parentAddressIdForSfType(primarySfAddressType),
                building: primaryInfo.building,
                number_x: primaryInfo.number_x,
                street: primaryInfo.street,
                district: primaryInfo.district,
                city: primaryInfo.city,
                isMailingAddress: primaryInfo.isMailingAddress === 'Y'
            });
            this._hasPendingDbDraft = true;
            // Cập nhật mainInfoData với JSON vừa lưu để lần edit tiếp theo lấy đúng dữ liệu
            const primaryPendingKey = this._pendingJsonFieldKey(primarySfAddressType);
            if (primaryPendingKey) {
                this.mainInfoData = {
                    ...(this.mainInfoData || {}),
                    [primaryPendingKey]: JSON.stringify(primaryInfo)
                };
            }

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
                await this._savePendingAddressRecord({
                    sfAddressType: sf,
                    deletePending: false,
                    parentAddressInfoId: this._parentAddressIdForSfType(sf),
                    building: infoOther.building,
                    number_x: infoOther.number_x,
                    street: infoOther.street,
                    district: infoOther.district,
                    city: infoOther.city,
                    isMailingAddress: infoOther.isMailingAddress === 'Y'
                });
                // Cập nhật mainInfoData để lần edit sau lấy đúng dữ liệu cho row này
                const otherPendingKey = this._pendingJsonFieldKey(sf);
                if (otherPendingKey) {
                    this.mainInfoData = {
                        ...(this.mainInfoData || {}),
                        [otherPendingKey]: JSON.stringify(infoOther)
                    };
                }
            }

            const composedAddress = this.composeAddressText(
                this.mailingBuilding,
                this.mailingNumber,
                this.mailingStreet,
                this._labelFromOptions(this.districtOptions, this.mailingDistrict),
                this._labelFromOptions(this.provinceOptions, this.mailingCity)
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
        this.newAddrDistrict = '';
        this.newAddrDistrictOptions = [];
        this.newAddrProvinceOptions = [];
        this.newAddrIsMailing = false;
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
        const typeOpts = this.newAddressTypeOptions;
        if (Array.isArray(typeOpts) && typeOpts.length > 0) {
            this.newAddrAddressType = typeOpts[0].value;
            this._syncNewAddrMailingDefaultForType();
        }
        this.newAddressModalOpen = true;
        this.newAddressModalLoading = true;
        getProvinceOptionsForCountryFecCode({
            fecCountryCode: FEC_COUNTRY_FEC_CODE_FOR_NEW_ADDRESS
        })
            .then((provinces) => {
                const mapped = (provinces || []).map((o) => ({
                    label: o.label != null ? o.label : o.Label,
                    value: o.value != null ? o.value : o.Value
                }));
                this.newAddrProvinceOptions = dedupeProvincePicklistOptions(mapped);
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
        const opts = this.newAddressTypeOptions;
        const fallback =
            Array.isArray(opts) && opts.length > 0 ? opts[0].value : TYPE_CURRENT;
        this.newAddrAddressType = val || fallback;
        this._syncNewAddrMailingDefaultForType();
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
        this.newAddrDistrict = '';
        this.newAddrDistrictOptions = [];
        if (!val) {
            return;
        }
        getDistrictOptionsForProvinceCode({ provinceCode: val })
            .then((districts) => {
                const dOpts = (districts || []).map((d) => ({
                    label: d.label,
                    value: d.value
                }));
                this.newAddrDistrictOptions = dOpts;
            })
            .catch(() => {
                this.newAddrDistrictOptions = [];
            });
    }

    handleNewAddrDistrictChange(e) {
        this.newAddrDistrict = e.detail.value;
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

    /**
     * Lấy context CIF cho một loại địa chỉ; nếu loại đó chưa có trên CIF thì lấy CIF từ loại khác (để pending JSON có cifNumber).
     */
    async _getCifContextForNewAddress(sfType) {
        let ctx = await getMailingAddressUpdateContext({
            caseId: this.resolvedCaseId,
            sfAddressType: sfType
        });
        if (ctx?.found && ctx.cifNumber) {
            return ctx;
        }
        /* eslint-disable no-await-in-loop */
        for (const sf of [TYPE_PERMANENT, TYPE_CURRENT, TYPE_OFFICE]) {
            if (sf === sfType) {
                continue;
            }
            const c = await getMailingAddressUpdateContext({
                caseId: this.resolvedCaseId,
                sfAddressType: sf
            });
            if (c?.found && c.cifNumber) {
                return {
                    found: false,
                    cifNumber: c.cifNumber,
                    addressId: '',
                    addressType: '',
                    building: '',
                    number_x: '',
                    street: '',
                    district: '',
                    city: ''
                };
            }
        }
        /* eslint-enable no-await-in-loop */
        return ctx;
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
        const primaryRow = isOffice
            ? ROW_OFFICE
            : isCurrent
              ? ROW_CURRENT
              : ROW_PERMANENT;
        if (!this.resolvedCaseId) {
            this.showToast(LBL_Error, LBL_Error, 'error');
            return;
        }

        this.newAddressSaveLoading = true;
        try {
            let nextSelectedRow = this.mailingSelectedRow;
            if (this.newAddrIsMailing) {
                nextSelectedRow = primaryRow;
            }

            const ctxBase = await this._getCifContextForNewAddress(
                this.newAddrAddressType
            );
            if (!ctxBase?.cifNumber) {
                this.showToast(LBL_Error, LBL_Error, 'error');
                return;
            }
            const primarySfAddressType = this.newAddrAddressType;
            const primaryInfo = {
                caseId: this.resolvedCaseId,
                sfAddressType: primarySfAddressType,
                cifNumber: String(ctxBase.cifNumber || '').trim(),
                addressId:
                    ctxBase.found === true &&
                    ctxBase.addressId != null &&
                    String(ctxBase.addressId).trim() !== ''
                        ? String(ctxBase.addressId).trim()
                        : '',
                addressType:
                    ctxBase.found === true &&
                    ctxBase.addressType != null &&
                    String(ctxBase.addressType).trim() !== ''
                        ? String(ctxBase.addressType).trim()
                        : '',
                number_x: this.newAddrNumber,
                building: this.newAddrBuilding,
                street: this.newAddrStreet,
                district:
                    this.newAddrDistrict != null &&
                    String(this.newAddrDistrict).trim() !== ''
                        ? String(this.newAddrDistrict).trim()
                        : '',
                city:
                    this.newAddrCity != null &&
                    String(this.newAddrCity).trim() !== ''
                        ? String(this.newAddrCity).trim()
                        : '',
                cityLabel: this._labelFromOptions(
                    this.newAddrProvinceOptions,
                    this.newAddrCity
                ),
                districtLabel: this._labelFromOptions(
                    this.newAddrDistrictOptions,
                    this.newAddrDistrict
                ),
                isMailingAddress: this.newAddrIsMailing ? 'Y' : 'N'
            };

            const parentIdForNew = ctxBase.found
                ? this._parentAddressIdForSfType(primarySfAddressType)
                : null;

            await this._savePendingAddressRecord({
                sfAddressType: primarySfAddressType,
                deletePending: false,
                parentAddressInfoId: parentIdForNew,
                building: primaryInfo.building,
                number_x: primaryInfo.number_x,
                street: primaryInfo.street,
                district: primaryInfo.district,
                city: primaryInfo.city,
                isMailingAddress: primaryInfo.isMailingAddress === 'Y'
            });
            this._hasPendingDbDraft = true;
            const primaryPendingKey =
                this._pendingJsonFieldKey(primarySfAddressType);
            if (primaryPendingKey) {
                this.mainInfoData = {
                    ...(this.mainInfoData || {}),
                    [primaryPendingKey]: JSON.stringify(primaryInfo)
                };
            }

            const allRows = [
                { row: ROW_PERMANENT, sf: TYPE_PERMANENT },
                { row: ROW_OFFICE, sf: TYPE_OFFICE },
                { row: ROW_CURRENT, sf: TYPE_CURRENT }
            ];
            for (const { row: r, sf } of allRows) {
                if (r === primaryRow) {
                    continue;
                }
                const desiredYn = nextSelectedRow === r ? 'Y' : 'N';
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
                await this._savePendingAddressRecord({
                    sfAddressType: sf,
                    deletePending: false,
                    parentAddressInfoId: this._parentAddressIdForSfType(sf),
                    building: infoOther.building,
                    number_x: infoOther.number_x,
                    street: infoOther.street,
                    district: infoOther.district,
                    city: infoOther.city,
                    isMailingAddress: infoOther.isMailingAddress === 'Y'
                });
                const otherPendingKey = this._pendingJsonFieldKey(sf);
                if (otherPendingKey) {
                    this.mainInfoData = {
                        ...(this.mainInfoData || {}),
                        [otherPendingKey]: JSON.stringify(infoOther)
                    };
                }
            }

            const composedAddress = this.composeAddressText(
                this.newAddrBuilding,
                this.newAddrNumber,
                this.newAddrStreet,
                this._labelFromOptions(
                    this.newAddrDistrictOptions,
                    this.newAddrDistrict
                ),
                this._labelFromOptions(
                    this.newAddrProvinceOptions,
                    this.newAddrCity
                )
            );
            this.applyLocalAddressAndMailing(
                this.newAddrAddressType,
                composedAddress,
                nextSelectedRow
            );
            this._applyPendingAddressTextsToDisplay(this.mainInfoData);
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