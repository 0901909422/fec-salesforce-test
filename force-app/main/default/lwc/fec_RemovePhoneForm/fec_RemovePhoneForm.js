import { LightningElement, api, track, wire } from 'lwc';
import checkEligibility from '@salesforce/apex/FEC_RemovePhoneController.checkEligibility';
import saveRemovePhoneSelections from '@salesforce/apex/FEC_RemovePhoneController.saveRemovePhoneSelections';
import loadRemovePhoneDraft from '@salesforce/apex/FEC_RemovePhoneController.loadRemovePhoneDraft';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CASE_FEC_IS_SUBMITED from '@salesforce/schema/Case.FEC_Is_Submited__c';
import FEC_Customer_Name_Label from '@salesforce/label/c.FEC_Customer_Name_Label';
import FEC_MainInfo_Contract_Number_Label from '@salesforce/label/c.FEC_MainInfo_Contract_Number_Label';
import FEC_MainInfo_Contract_Status_Label from '@salesforce/label/c.FEC_MainInfo_Contract_Status_Label';
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
import Pagination_Page_Of_Label from '@salesforce/label/c.Pagination_Page_Of_Label';
import Loading from '@salesforce/label/c.Loading';
import { STR_EMPTY, RESULT_ERROR } from 'c/fec_CommonConst';
import { validateUpdatedInfoPhone } from 'c/fec_CommonUtils';

const DT_SELECT_ALL = 'selectallrows';
const DT_DESELECT_ALL = 'deselectallrows';

const REMOVE_PHONE_TABLE_COLUMNS = [
    { label: FEC_Customer_Name_Label, fieldName: 'customerName', type: 'text' },
    { label: FEC_MainInfo_Contract_Number_Label, fieldName: 'contractNumber', type: 'text' },
    { label: FEC_MainInfo_Contract_Status_Label, fieldName: 'contractStatus', type: 'text' },
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

    @track _caseIsSubmited = false;

    @wire(getRecord, { recordId: '$recordId', fields: [CASE_FEC_IS_SUBMITED] })
    wiredCaseForSubmitted({ data, error }) {
        if (!this._recordId) {
            this._caseIsSubmited = false;
            return;
        }
        if (data) {
            this._caseIsSubmited = getFieldValue(data, CASE_FEC_IS_SUBMITED) === true;
        } else if (error) {
            this._caseIsSubmited = false;
        }
    }

    get readOnlyRemovePhone() {
        if (this.caseSubmitted === true) {
            return true;
        }
        if (this.caseSubmitted === false) {
            return false;
        }
        return this._caseIsSubmited === true;
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

    paginationPrevLabel = FEC_Btn_Previous;

    paginationNextLabel = FEC_Btn_Next;

    columns = REMOVE_PHONE_TABLE_COLUMNS;

    customLabel = {
        sectionTitle: FEC_LBL_Remove_Phone_Section_Title,
        removedPhoneLabel: FEC_LBL_Remove_Phone_Input_Label,
        checkEligibility: FEC_Btn_Remove_Phone_Check_Eligibility,
        loading: Loading
    };

    _syncPhoneFromInput() {
        const phoneInput = this.template.querySelector('lightning-input');
        if (!phoneInput || typeof phoneInput.value !== 'string') {
            return;
        }
        const nextPhone = (phoneInput.value || STR_EMPTY).trim();
        this.phone = nextPhone;
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
        const phoneInput = this.template.querySelector('lightning-input');
        if (phoneInput) {
            phoneInput.setCustomValidity('');
        }
        if (this.phone !== this.lastCheckedPhone) {
            this.rows = [];
            this.selectedRowIds = [];
            this.currentPage = 1;
            this._recomputePagedRows();
        }
        this.resultMessage = STR_EMPTY;
    }

    get disableCheckButton() {
        return this.isLoading || !this.phone || this.readOnlyRemovePhone;
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
        return [{ mountKey: String(this.tableKey || 0) }];
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
        return (this.rows || []).length > this.pageSize;
    }

    get paginationPageOfText() {
        return Pagination_Page_Of_Label.replace('{0}', String(this.currentPage)).replace('{1}', String(this.totalPages));
    }

    get disablePrevPage() {
        return this.currentPage <= 1;
    }

    get disableNextPage() {
        return this.currentPage >= this.totalPages;
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

    handlePrevPage() {
        if (this.disablePrevPage) {
            return;
        }
        this.currentPage -= 1;
        this._recomputePagedRows();
        this._bumpTableKey();
    }

    handleNextPage() {
        if (this.disableNextPage) {
            return;
        }
        this.currentPage += 1;
        this._recomputePagedRows();
        this._bumpTableKey();
    }

    handleCheckEligibility() {
        if (this.readOnlyRemovePhone) {
            return;
        }
        const phoneErr = this.phone ? validateUpdatedInfoPhone(this.phone) : FEC_MSG_Remove_Phone_Invalid_Format;
        if (phoneErr) {
            const phoneInput = this.template.querySelector('lightning-input');
            if (phoneInput) {
                phoneInput.setCustomValidity(phoneErr);
                phoneInput.reportValidity();
            }
            this.resultMessage = STR_EMPTY;
            this.rows = [];
            this.selectedRowIds = [];
            this.currentPage = 1;
            this._recomputePagedRows();
            return;
        }
        const phoneInputClear = this.template.querySelector('lightning-input');
        if (phoneInputClear) {
            phoneInputClear.setCustomValidity('');
        }
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
                this.resultMessage = (res && res.errorMessage) ? res.errorMessage : FEC_MSG_Remove_Phone_Service_Failed;
                this.resultClass = RESULT_ERROR;
            })
            .catch(() => {
                this.resultMessage = FEC_MSG_Remove_Phone_Service_Failed;
                this.resultClass = RESULT_ERROR;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    @api saveDraftIfApplicable() {
        if (this.readOnlyRemovePhone) {
            return Promise.resolve();
        }
        this._syncPhoneFromInput();
        const phone = (this.phone || STR_EMPTY).trim();
        const recordId = this._recordId;
        const rowSnapshot = (this.rows || []).map((r) => (r ? Object.assign({}, r) : r));
        if (!recordId || !phone || !rowSnapshot.length) {
            return Promise.resolve();
        }
        const selected = this._collectSelectedIds();
        const rowPayload = rowSnapshot
            .map((r) => this._mapTableRowToSaveDto(r, selected))
            .filter((row) => row != null);
        return saveRemovePhoneSelections({
            caseId: recordId,
            removedPhoneNumber: phone,
            rowsJson: JSON.stringify(rowPayload)
        });
    }

    connectedCallback() {
        if (this._recordId) {
            this._loadRemovePhoneDraftFromServer();
        }
    }
}