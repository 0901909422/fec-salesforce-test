import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkEligibility from '@salesforce/apex/FEC_RemovePhoneController.checkEligibility';
import saveRemovePhoneSelections from '@salesforce/apex/FEC_RemovePhoneController.saveRemovePhoneSelections';
import loadRemovePhoneDraft from '@salesforce/apex/FEC_RemovePhoneController.loadRemovePhoneDraft';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CASE_FEC_IS_SUBMITED from '@salesforce/schema/Case.FEC_Is_Submited__c';
import CASE_FEC_STAGE_NAME from '@salesforce/schema/Case.FEC_Stage_Name__c';
import FEC_Customer_Name_Label from '@salesforce/label/c.FEC_Customer_Name_Label';
import FEC_Account_Contract_Number from '@salesforce/label/c.FEC_Account_Contract_Number';
import FEC_Account_Contract_Status from '@salesforce/label/c.FEC_Account_Contract_Status';
import FEC_LBL_Remove_Phone_Phone_Type from '@salesforce/label/c.FEC_LBL_Remove_Phone_Phone_Type';
import FEC_LBL_Remove_Phone_Removable from '@salesforce/label/c.FEC_LBL_Remove_Phone_Removable';
import FEC_Reason_Label from '@salesforce/label/c.FEC_Reason_Label';
import FEC_MSG_Remove_Phone_Invalid_Format from '@salesforce/label/c.FEC_MSG_Remove_Phone_Invalid_Format';
import FEC_MSG_Remove_Phone_Service_Failed from '@salesforce/label/c.FEC_MSG_Remove_Phone_Service_Failed';
import FEC_LBL_Remove_Phone_Section_Title from '@salesforce/label/c.FEC_LBL_Remove_Phone_Section_Title';
import FEC_LBL_Remove_Phone_Input_Label from '@salesforce/label/c.FEC_LBL_Remove_Phone_Input_Label';
import FEC_Btn_Remove_Phone_Check_Eligibility from '@salesforce/label/c.FEC_Btn_Remove_Phone_Check_Eligibility';
import FEC_Btn_Previous from '@salesforce/label/c.FEC_Btn_Previous';
import FEC_Btn_Next from '@salesforce/label/c.FEC_Btn_Next';
import FEC_BCH_PageSize from '@salesforce/label/c.FEC_BCH_PageSize';
import FEC_Go_to_page_label from '@salesforce/label/c.FEC_Go_to_page_label';
import FEC_Go_Button_Label from '@salesforce/label/c.FEC_Go_Button_Label';
import Loading from '@salesforce/label/c.Loading';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import { STR_EMPTY, RESULT_ERROR } from 'c/fec_CommonConst';
import { validateUpdatedInfoPhone } from 'c/fec_CommonUtils';

const DT_SELECT_ALL = 'selectallrows';
const DT_DESELECT_ALL = 'deselectallrows';

const REMOVE_PHONE_PAGE_SIZE_OPTIONS = [10, 20, 30, 40, 50];

const REMOVE_PHONE_TABLE_COLUMNS = [
    { label: FEC_Customer_Name_Label, fieldName: 'customerName', type: 'text' },
    { label: FEC_Account_Contract_Number, fieldName: 'contractNumber', type: 'text' },
    { label: FEC_Account_Contract_Status, fieldName: 'contractStatus', type: 'text' },
    { label: FEC_LBL_Remove_Phone_Phone_Type, fieldName: 'phoneType', type: 'text' },
    { label: FEC_LBL_Remove_Phone_Removable, fieldName: 'removable', type: 'text' },
    { label: FEC_Reason_Label, fieldName: 'reason', type: 'text' }
];

export default class Fec_RemovePhoneForm extends LightningElement {

    _recordId;
    _draftLoadSeq = 0;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        const prev = this._recordId;
        this._recordId = value;
        if (value && String(value) !== String(prev || '')) {
            this._loadRemovePhoneDraftFromServer();
        }
    }

    @api caseSubmitted;

    _lockAfterRevertToDefaultStage = false;

    @api
    get lockAfterRevertToDefaultStage() {
        return this._lockAfterRevertToDefaultStage;
    }
    set lockAfterRevertToDefaultStage(value) {
        const next = value === true;
        if (this._lockAfterRevertToDefaultStage === next) {
            return;
        }
        const wasReadOnly = this.readOnlyRemovePhone;
        this._lockAfterRevertToDefaultStage = next;
        if (this.readOnlyRemovePhone && !wasReadOnly) {
            this._syncSelectedRowIdsFromCheckRemovePhone();
            this._bumpTableKey();
        }
    }

    @track _caseIsSubmited = false;

    @track _caseIsPastStage1 = false;

    @wire(getRecord, { recordId: '$recordId', fields: [CASE_FEC_IS_SUBMITED, CASE_FEC_STAGE_NAME] })
    wiredCaseForSubmitted({ data, error }) {
        if (!this._recordId) {
            this._caseIsSubmited = false;
            this._caseIsPastStage1 = false;
            return;
        }
        if (data) {
            const wasReadOnly = this.readOnlyRemovePhone;
            this._caseIsSubmited = getFieldValue(data, CASE_FEC_IS_SUBMITED) === true;
            const stageName = getFieldValue(data, CASE_FEC_STAGE_NAME) || STR_EMPTY;
            this._caseIsPastStage1 = stageName.length > 0 && !stageName.includes('Stage 1');
            if (this.readOnlyRemovePhone && !wasReadOnly) {
                this._syncSelectedRowIdsFromCheckRemovePhone();
                this._bumpTableKey();
            }
        } else if (error) {
            this._caseIsSubmited = false;
            this._caseIsPastStage1 = false;
        }
    }

    get readOnlyRemovePhone() {
        if (this.caseSubmitted === true) {
            return true;
        }
        if (this.caseSubmitted === false) {
            return false;
        }
        if (this._lockAfterRevertToDefaultStage === true) {
            return true;
        }
        if (this._caseIsSubmited === true) {
            return true;
        }
        return this._caseIsPastStage1 === true;
    }

    @api notifyCaseSubmitted() {
        this._caseIsSubmited = true;
        this._syncSelectedRowIdsFromCheckRemovePhone();
        this._bumpTableKey();
    }

    @track phone = STR_EMPTY;
    @track rows = [];
    @track selectedRowIds = [];
    @track pagedRows = [];
    @track currentPage = 1;
    @track resultMessage = STR_EMPTY;
    @track resultClass = RESULT_ERROR;
    @track isLoading = false;

    @track tableKey = 0;

    lastCheckedPhone = STR_EMPTY;

    pageSize = 10;

    goToPageValue = 1;

    paginationLabels = {
        pageSizeLabel: FEC_BCH_PageSize,
        goToPageLabel: FEC_Go_to_page_label,
        goBtnLabel: FEC_Go_Button_Label,
        prevLabel: FEC_Btn_Previous,
        nextLabel: FEC_Btn_Next
    };

    columns = REMOVE_PHONE_TABLE_COLUMNS;

    customLabel = {
        sectionTitle: FEC_LBL_Remove_Phone_Section_Title,
        removedPhoneLabel: FEC_LBL_Remove_Phone_Input_Label,
        checkEligibility: FEC_Btn_Remove_Phone_Check_Eligibility,
        loading: Loading
    };

    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    _syncPhoneFromInput() {
        const phoneInput = this.template.querySelector('lightning-input');
        const fromInput = phoneInput && phoneInput.value != null
            ? String(phoneInput.value).trim()
            : STR_EMPTY;
        const fromTrack = (this.phone || STR_EMPTY).trim();
        this.phone = fromInput || fromTrack;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    _getPhoneValidationError(phoneValue) {
        const p = (phoneValue != null ? String(phoneValue) : (this.phone || STR_EMPTY)).trim();
        if (!p) {
            return null;
        }
        return validateUpdatedInfoPhone(p) || null;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    _applyPhoneInputValidity(reportNow) {
        const phoneInput = this.template.querySelector('lightning-input');
        if (!phoneInput) {
            return;
        }
        const err = this._getPhoneValidationError(this.phone);
        phoneInput.setCustomValidity(err || '');
        if (reportNow) {
            phoneInput.reportValidity();
        }
    }

    _removePhoneCellText(v) {
        if (v === undefined || v === null) {
            return STR_EMPTY;
        }
        return String(v).trim();
    }

    _pickApiField(source, keys) {
        if (!source || !keys || !keys.length) {
            return null;
        }
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (Object.prototype.hasOwnProperty.call(source, k) && source[k] !== undefined && source[k] !== null) {
                return source[k];
            }
        }
        return null;
    }

    /**
     * Table row shape matches RemovePhoneRowSaveDTO -> FEC_Contract_List_for_Remove_Phone__c text fields; FEC_Check_Remove_Phone__c is derived from row selection when saving (not shown in datatable).
     */
    _normalizeRemovePhoneRowForTable(source, index, checkRemovePhoneInitial) {
        if (!source) {
            return null;
        }
        const cell = (keys) => this._removePhoneCellText(this._pickApiField(source, keys));
        return {
            id: String(index),
            checkRemovePhone: checkRemovePhoneInitial === true,
            customerName: cell(['customerName', 'CustomerName', 'Customer_Name', 'CusName']),
            contractNumber: cell(['contractNumber', 'ContractNumber', 'AccountNumber', 'Contract_No', 'ContractNo']),
            contractStatus: cell(['contractStatus', 'ContractStatus', 'Status']),
            phoneType: cell(['phoneType', 'PhoneType', 'Type']),
            removable: cell(['removable', 'Removable', 'RemovableStatus']),
            reason: cell(['reason', 'Reason', 'Description', 'Message'])
        };
    }

    _mapTableRowToSaveDto(r, selectedSet) {
        if (!r) {
            return null;
        }
        const toApexText = (v) => {
            if (v === undefined || v === null) {
                return null;
            }
            const s = String(v).trim();
            return s.length ? s : null;
        };
        return {
            customerName: toApexText(r.customerName),
            contractNumber: toApexText(r.contractNumber),
            contractStatus: toApexText(r.contractStatus),
            phoneType: toApexText(r.phoneType),
            removable: toApexText(r.removable),
            reason: toApexText(r.reason),
            checkRemovePhone: selectedSet.has(String(r.id)) || r.checkRemovePhone === true
        };
    }

    _bumpTableKey() {
        this.tableKey = (this.tableKey || 0) + 1;
    }

    _syncSelectedRowIdsFromCheckRemovePhone() {
        const ids = (this.rows || [])
            .filter((r) => r && r.checkRemovePhone === true)
            .map((r) => String(r.id));
        this.selectedRowIds = [...ids];
    }

    _syncCheckRemovePhoneFromSelection() {
        const sel = new Set((this.selectedRowIds || []).map((id) => String(id)));
        this.rows = (this.rows || []).map((r) => {
            if (!r) {
                return r;
            }
            const next = Object.assign({}, r);
            next.checkRemovePhone = sel.has(String(next.id));
            return next;
        });
        this._recomputePagedRows();
    }

    _loadRemovePhoneDraftFromServer() {
        if (!this._recordId) {
            return;
        }
        const seq = ++this._draftLoadSeq;
        loadRemovePhoneDraft({ caseId: this._recordId })
            .then((draft) => {
                if (seq !== this._draftLoadSeq) {
                    return;
                }
                if (!draft) {
                    return;
                }
                const phone = (draft.phone || STR_EMPTY).trim();
                const raw = draft.rows || [];
                if (!phone || !raw.length) {
                    return;
                }
                this.rows = raw.map((r, i) => this._normalizeRemovePhoneRowForTable(r, i, r && r.checkRemovePhone === true)).filter((row) => row != null);
                this.selectedRowIds = raw
                    .map((r, i) => (r && r.checkRemovePhone === true ? String(i) : null))
                    .filter((id) => id !== null);
                this.phone = phone;
                this.lastCheckedPhone = phone;
                this.currentPage = 1;
                this._recomputePagedRows();
                this._bumpTableKey();
            })
            .catch(() => {
                /* ignore load errors, show empty form */
            });
    }

    _collectSelectedIds() {
        const selected = new Set((this.selectedRowIds || []).map((id) => String(id)));
        const dt = this.template.querySelector('lightning-datatable');
        if (dt && typeof dt.getSelectedRows === 'function') {
            try {
                (dt.getSelectedRows() || []).forEach((row) => {
                    if (row && row.id != null && row.id !== STR_EMPTY) {
                        selected.add(String(row.id));
                    }
                });
            } catch (e) {
                /* datatable API not available */
            }
        }
        return selected;
    }

    handlePhoneChange(event) {
        if (this.readOnlyRemovePhone) {
            return;
        }
        const nextPhone = (event.target.value || STR_EMPTY).trim();
        this.phone = nextPhone;
        //linhdev fix jira FECREDIT_CSM_2025_KH-1368
        this._applyPhoneInputValidity(true);
        if (this.phone !== this.lastCheckedPhone) {
            this.rows = [];
            this.selectedRowIds = [];
            this.currentPage = 1;
            this._recomputePagedRows();
        }
        this.resultMessage = STR_EMPTY;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    get disableCheckButton() {
        if (this.isLoading || this.readOnlyRemovePhone) {
            return true;
        }
        const p = (this.phone || STR_EMPTY).trim();
        if (!p) {
            return false;
        }
        if (this._getPhoneValidationError(p)) {
            return true;
        }
        return this.isEligibilityChecked;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    get isEligibilityChecked() {
        const p = (this.phone || STR_EMPTY).trim();
        return p.length > 0
            && p === (this.lastCheckedPhone || STR_EMPTY).trim()
            && (this.rows || []).length > 0;
    }

    get phoneReadOnlyDisplay() {
        const p = (this.phone || STR_EMPTY).trim();
        return p.length > 0 ? p : '—';
    }

    get phoneInputDisplayValue() {
        if (this.readOnlyRemovePhone) {
            return this.phoneReadOnlyDisplay;
        }
        return this.phone;
    }

    get showDataTable() {
        return (this.rows || []).length > 0;
    }

    get datatableMountRows() {
        const ro = this.readOnlyRemovePhone ? '1' : '0';
        return [{ mountKey: String(this.tableKey || 0) + '_' + ro }];
    }

    get disabledRowIds() {
        if (!this.readOnlyRemovePhone) {
            return [];
        }
        return (this.rows || [])
            .filter((r) => r && r.id != null)
            .map((r) => String(r.id));
    }

    get totalPages() {
        const len = (this.rows || []).length;
        if (!len) {
            return 1;
        }
        return Math.ceil(len / this.pageSize);
    }

    _recomputePagedRows() {
        const all = this.rows || [];
        if (!all.length) {
            this.pagedRows = [];
            return;
        }
        const tp = Math.ceil(all.length / this.pageSize);
        const safePage = Math.min(Math.max(1, this.currentPage), Math.max(1, tp));
        if (this.currentPage !== safePage) {
            this.currentPage = safePage;
        }
        const start = (this.currentPage - 1) * this.pageSize;
        this.pagedRows = all.slice(start, start + this.pageSize);
    }

    get showPagination() {
        return (this.rows || []).length > 0;
    }

    get pageSizeStr() {
        return String(this.pageSize);
    }

    get pageSizeOptions() {
        return REMOVE_PHONE_PAGE_SIZE_OPTIONS.map((size) => ({
            label: String(size),
            value: String(size)
        }));
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get disablePaginationPrevPage() {
        return this.isFirstPage;
    }

    get disablePaginationNextPage() {
        return this.isLastPage;
    }

    handleRowSelection(event) {
        if (this.readOnlyRemovePhone) {
            const ids = (this.rows || [])
                .filter((r) => r && r.checkRemovePhone === true)
                .map((r) => String(r.id));
            this.selectedRowIds = [...ids];
            return;
        }
        const config = event.detail.config || {};
        const actionRaw = config.action != null ? String(config.action) : STR_EMPTY;
        const action = actionRaw.toLowerCase();
        if (action === DT_SELECT_ALL) {
            const merged = new Set((this.selectedRowIds || []).map((id) => String(id)));
            (this.rows || []).forEach((item) => {
                if (item && item.id != null && item.id !== STR_EMPTY) {
                    merged.add(String(item.id));
                }
            });
            this.selectedRowIds = Array.from(merged);
            this._syncCheckRemovePhoneFromSelection();
            return;
        }
        if (action === DT_DESELECT_ALL) {
            const pageData = this.pagedRows || [];
            const pageIds = new Set(pageData.map((item) => String(item.id)));
            const merged = new Set((this.selectedRowIds || []).map((id) => String(id)));
            pageIds.forEach((id) => {
                merged.delete(id);
            });
            this.selectedRowIds = Array.from(merged);
            this._syncCheckRemovePhoneFromSelection();
            return;
        }
        const pageData = this.pagedRows || [];
        const pageIds = new Set(pageData.map((item) => String(item.id)));
        const selectedFromTable = new Set((event.detail.selectedRows || []).map((item) => String(item.id)));
        const merged = new Set((this.selectedRowIds || []).map((id) => String(id)));
        pageIds.forEach((id) => {
            merged.delete(id);
        });
        selectedFromTable.forEach((id) => {
            merged.add(id);
        });
        this.selectedRowIds = Array.from(merged);
        this._syncCheckRemovePhoneFromSelection();
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
        this.goToPageValue = 1;
        this._recomputePagedRows();
        this._bumpTableKey();
    }

    handlePrevPage() {
        if (this.isFirstPage) {
            return;
        }
        this.currentPage -= 1;
        this.goToPageValue = this.currentPage;
        this._recomputePagedRows();
        this._bumpTableKey();
    }

    handleNextPage() {
        if (this.isLastPage) {
            return;
        }
        this.currentPage += 1;
        this.goToPageValue = this.currentPage;
        this._recomputePagedRows();
        this._bumpTableKey();
    }

    handleGoToPageInput(event) {
        this.goToPageValue = parseInt(event.detail.value, 10);
    }

    handleGoToPage() {
        let targetPage = this.goToPageValue;
        if (!targetPage || isNaN(targetPage)) {
            targetPage = 1;
        }
        if (targetPage < 1) {
            targetPage = 1;
        }
        if (targetPage > this.totalPages) {
            targetPage = this.totalPages;
        }
        if (this.currentPage === targetPage) {
            return;
        }
        this.currentPage = targetPage;
        this.goToPageValue = targetPage;
        this._recomputePagedRows();
        this._bumpTableKey();
    }

    handleCheckEligibility() {
        if (this.readOnlyRemovePhone) {
            return;
        }
        //linhdev fix jira FECREDIT_CSM_2025_KH-1368
        const phoneErr = this.phone ? this._getPhoneValidationError(this.phone) : FEC_MSG_Remove_Phone_Invalid_Format;
        if (phoneErr) {
            this._applyPhoneInputValidity(true);
            this.resultMessage = STR_EMPTY;
            this.rows = [];
            this.selectedRowIds = [];
            this.currentPage = 1;
            this._recomputePagedRows();
            return;
        }
        this._applyPhoneInputValidity(false);
        this.isLoading = true;
        this.resultMessage = STR_EMPTY;
        this.rows = [];
        this.selectedRowIds = [];
        this.currentPage = 1;
        this._recomputePagedRows();

        checkEligibility({ phone: this.phone })
            .then((res) => {
                if (res && res.success) {
                    const raw = res.rows || [];
                    this.rows = raw.map((r, i) => this._normalizeRemovePhoneRowForTable(r, i, false)).filter((row) => row != null);
                    this.lastCheckedPhone = (this.phone || STR_EMPTY).trim();
                    this.currentPage = 1;
                    this.resultMessage = STR_EMPTY;
                    this._recomputePagedRows();
                    this._bumpTableKey();
                    return;
                }
                //linhdev fix jira FECREDIT_CSM_2025_KH-1368
                this.resultMessage = FEC_MSG_Remove_Phone_Service_Failed;
                this.resultClass = RESULT_ERROR;
            })
            .catch(() => {
                //linhdev fix jira FECREDIT_CSM_2025_KH-1368
                this.resultMessage = FEC_MSG_Remove_Phone_Service_Failed;
                this.resultClass = RESULT_ERROR;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _buildRemovePhoneSavePayload() {
        if (this.readOnlyRemovePhone) {
            return null;
        }
        this._syncPhoneFromInput();
        this._syncCheckRemovePhoneFromSelection();
        const phone = (this.phone || STR_EMPTY).trim();
        const recordId = this._recordId || this.recordId;
        const rowSnapshot = (this.rows || []).map((r) => (r ? Object.assign({}, r) : r));
        if (!recordId || !phone || !rowSnapshot.length) {
            return null;
        }
        const selected = this._collectSelectedIds();
        const rowPayload = rowSnapshot
            .map((r) => this._mapTableRowToSaveDto(r, selected))
            .filter((row) => row != null);
        if (!rowPayload.length) {
            return null;
        }
        return { recordId, phone, rowPayload };
    }

    _persistRemovePhoneSavePayload(payload) {
        if (!payload) {
            return Promise.resolve();
        }
        return saveRemovePhoneSelections({
            caseId: payload.recordId,
            removedPhoneNumber: payload.phone,
            rowsJson: JSON.stringify(payload.rowPayload)
        });
    }

    _hasRemovePhoneTableData() {
        return (this.rows || []).length > 0;
    }

    _hasRemovePhoneRowSelection() {
        const selected = this._collectSelectedIds();
        if (selected.size > 0) {
            return true;
        }
        return (this.rows || []).some((r) => r && r.checkRemovePhone === true);
    }

    _showRemovePhoneValidationToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: FEC_Toast_Validation_Title,
            message: message || FEC_Complete_This_Field,
            variant: 'warning'
        }));
    }

    /** Submit: validate trước khi parent gọi submit(). */
    @api validateForSubmit() {
        if (this.readOnlyRemovePhone) {
            return true;
        }
        this._syncPhoneFromInput();
        const phone = (this.phone || STR_EMPTY).trim();
        if (!phone && !this._hasRemovePhoneTableData()) {
            return true;
        }
        if (phone && this._getPhoneValidationError(phone)) {
            this._applyPhoneInputValidity(true);
            this._showRemovePhoneValidationToast(FEC_MSG_Remove_Phone_Invalid_Format);
            return false;
        }
        if (phone && !this._hasRemovePhoneTableData()) {
            this._showRemovePhoneValidationToast(FEC_Btn_Remove_Phone_Check_Eligibility);
            return false;
        }
        if (this._hasRemovePhoneTableData() && !this._hasRemovePhoneRowSelection()) {
            this._showRemovePhoneValidationToast(FEC_Complete_This_Field);
            return false;
        }
        return true;
    }

    /** Save & Close: lưu nháp khi đã Check Eligibility và có bảng; không bắt buộc chọn dòng. */
    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    @api saveDraftIfApplicable() {
        return this._persistRemovePhoneSavePayload(this._buildRemovePhoneSavePayload());
    }

    /** Submit: lưu sau khi validateForSubmit; cùng Apex nhưng gọi từ luồng submit. */
    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    @api saveForSubmitIfApplicable() {
        if (this.readOnlyRemovePhone) {
            return Promise.resolve();
        }
        return this._persistRemovePhoneSavePayload(this._buildRemovePhoneSavePayload());
    }

    connectedCallback() {
        if (this._recordId) {
            this._loadRemovePhoneDraftFromServer();
        }
    }
}