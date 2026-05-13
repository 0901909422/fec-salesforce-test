import { LightningElement, api, track } from 'lwc';
import checkEligibility from '@salesforce/apex/FEC_RemovePhoneController.checkEligibility';
import saveRemovePhoneSelections from '@salesforce/apex/FEC_RemovePhoneController.saveRemovePhoneSelections';
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

export default class Fec_RemovePhoneForm extends LightningElement {

    @api recordId;

    @api isEdit;

    get isReadOnly() {
        return this.isEdit === false;
    }

    @track phone = STR_EMPTY;
    @track rows = [];
    @track selectedRowIds = [];
    @track currentPage = 1;
    @track resultMessage = STR_EMPTY;
    @track resultClass = RESULT_ERROR;
    @track isLoading = false;

    lastCheckedPhone = STR_EMPTY;

    pageSize = 10;

    paginationPrevLabel = FEC_Btn_Previous;

    paginationNextLabel = FEC_Btn_Next;

    columns = [
        { label: FEC_Customer_Name_Label, fieldName: 'customerName', type: 'text' },
        { label: FEC_MainInfo_Contract_Number_Label, fieldName: 'contractNumber', type: 'text' },
        { label: FEC_MainInfo_Contract_Status_Label, fieldName: 'contractStatus', type: 'text' },
        { label: FEC_LBL_Remove_Phone_Phone_Type, fieldName: 'phoneType', type: 'text' },
        { label: FEC_LBL_Remove_Phone_Removable, fieldName: 'removable', type: 'text' },
        { label: FEC_Reason_Label, fieldName: 'reason', type: 'text' }
    ];

    customLabel = {
        sectionTitle: FEC_LBL_Remove_Phone_Section_Title,
        removedPhoneLabel: FEC_LBL_Remove_Phone_Input_Label,
        checkEligibility: FEC_Btn_Remove_Phone_Check_Eligibility,
        loading: Loading
    };

    handlePhoneChange(event) {
        if (this.isReadOnly) {
            return;
        }
        this.phone = (event.target.value || STR_EMPTY).trim();
        const phoneInput = this.template.querySelector('lightning-input');
        if (phoneInput) {
            phoneInput.setCustomValidity('');
        }
        if (this.phone !== this.lastCheckedPhone) {
            this.rows = [];
            this.selectedRowIds = [];
            this.currentPage = 1;
        }
        this.resultMessage = STR_EMPTY;
    }

    get disableCheckButton() {
        return this.isLoading || !this.phone || this.isReadOnly;
    }

    get showTable() {
        return this.rows && this.rows.length > 0;
    }

    get totalPages() {
        const len = (this.rows || []).length;
        if (!len) {
            return 1;
        }
        return Math.ceil(len / this.pageSize);
    }

    get pagedRows() {
        const all = this.rows || [];
        if (!all.length) {
            return [];
        }
        const tp = this.totalPages;
        const page = Math.min(Math.max(1, this.currentPage), tp);
        const start = (page - 1) * this.pageSize;
        return all.slice(start, start + this.pageSize);
    }

    get selectedRowKeysOnPage() {
        const sel = new Set(this.selectedRowIds || []);
        const page = this.pagedRows || [];
        return page.filter((r) => sel.has(r.id)).map((r) => r.id);
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
        if (this.isReadOnly) {
            return;
        }
        const config = event.detail.config || {};
        const action = config.action;
        if (action === 'selectAllRows') {
            const merged = new Set(this.selectedRowIds || []);
            (this.rows || []).forEach((item) => {
                if (item && item.id != null && item.id !== STR_EMPTY) {
                    merged.add(item.id);
                }
            });
            this.selectedRowIds = Array.from(merged);
            return;
        }
        const pageData = this.pagedRows || [];
        const pageIds = new Set(pageData.map((item) => item.id));
        const selectedFromTable = new Set((event.detail.selectedRows || []).map((item) => item.id));
        const merged = new Set(this.selectedRowIds || []);
        pageIds.forEach((id) => {
            merged.delete(id);
        });
        selectedFromTable.forEach((id) => {
            merged.add(id);
        });
        this.selectedRowIds = Array.from(merged);
    }

    handlePrevPage() {
        if (this.disablePrevPage) {
            return;
        }
        this.currentPage -= 1;
    }

    handleNextPage() {
        if (this.disableNextPage) {
            return;
        }
        this.currentPage += 1;
    }

    handleCheckEligibility() {
        if (this.isReadOnly) {
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

        checkEligibility({ phone: this.phone })
            .then((res) => {
                if (res && res.success) {
                    this.rows = res.rows || [];
                    this.lastCheckedPhone = this.phone;
                    this.currentPage = 1;
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
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this.recordId || !this.phone || !this.rows || this.rows.length === 0) {
            return Promise.resolve();
        }
        if (this.phone !== this.lastCheckedPhone) {
            return Promise.resolve();
        }
        const selectedSet = new Set(this.selectedRowIds || []);
        const rowPayload = (this.rows || []).map((r) => ({
            customerName: r.customerName,
            contractNumber: r.contractNumber,
            contractStatus: r.contractStatus,
            phoneType: r.phoneType,
            removable: r.removable,
            reason: r.reason,
            checkRemovePhone: selectedSet.has(r.id)
        }));
        return saveRemovePhoneSelections({
            caseId: this.recordId,
            removedPhoneNumber: this.phone,
            rows: rowPayload
        });
    }
}