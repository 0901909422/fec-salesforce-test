import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import TRANSFER_DATA_FIELD   from '@salesforce/schema/Case.FEC_Transfer_Data_to_Collections__c';
import TRANSFER_TIME_FIELD   from '@salesforce/schema/Case.FEC_Transfer_Time__c';
import TRANSFER_STATUS_FIELD from '@salesforce/schema/Case.FEC_Transfer_Status__c';
import FAILURE_REASON_FIELD  from '@salesforce/schema/Case.FEC_Failure_Reason__c';
import COLL_ACTION_CODE_FIELD     from '@salesforce/schema/Case.FEC_Coll_Action_Code__c';
import COLL_SUB_ACTION_CODE_FIELD from '@salesforce/schema/Case.FEC_Coll_Sub_Action_Code__c';
import COLL_REMARKS_FIELD         from '@salesforce/schema/Case.FEC_Coll_Remarks__c';
import COLL_ACTION_DATE_FIELD     from '@salesforce/schema/Case.FEC_Coll_Action_Date__c';
import COLL_AGENT_FIELD           from '@salesforce/schema/Case.FEC_Coll_Agent__c';

const TRANSFER_DETAIL_FIELDS = [
    TRANSFER_DATA_FIELD, TRANSFER_TIME_FIELD, TRANSFER_STATUS_FIELD,
    FAILURE_REASON_FIELD, COLL_ACTION_CODE_FIELD, COLL_SUB_ACTION_CODE_FIELD,
    COLL_REMARKS_FIELD, COLL_ACTION_DATE_FIELD, COLL_AGENT_FIELD
];
import transferCallFromCase from '@salesforce/apex/FEC_TranferInformationCallout.transferCallFromCase';
import FEC_Collections_Transfer_Failed_Summary from '@salesforce/label/c.FEC_Collections_Transfer_Failed_Summary';
import FEC_Collections_Transfer_MaxFailed_Summary from '@salesforce/label/c.FEC_Collections_Transfer_MaxFailed_Summary';
import FEC_Notification_16_Collections_Transfer_Success from '@salesforce/label/c.FEC_Notification_16_Collections_Transfer_Success';
import FEC_TransferCall_Section_CaseInfo from '@salesforce/label/c.FEC_TransferCall_Section_CaseInfo';
import FEC_TransferCall_Subtitle from '@salesforce/label/c.FEC_TransferCall_Subtitle';
import FEC_TransferCall_Btn_TransferToCollection from '@salesforce/label/c.FEC_TransferCall_Btn_TransferToCollection';
import FEC_TransferCall_Modal_ConfirmMessage from '@salesforce/label/c.FEC_TransferCall_Modal_ConfirmMessage';
import FEC_TransferCall_Modal_RemarkLabel from '@salesforce/label/c.FEC_TransferCall_Modal_RemarkLabel';
import FEC_TransferCall_Modal_RemarkRequired from '@salesforce/label/c.FEC_TransferCall_Modal_RemarkRequired';
import FEC_TransferCall_Btn_Cancel from '@salesforce/label/c.FEC_TransferCall_Btn_Cancel';
import FEC_TransferCall_Btn_ConfirmTransfer from '@salesforce/label/c.FEC_TransferCall_Btn_ConfirmTransfer';
import FEC_TransferCall_Spinner_Loading from '@salesforce/label/c.FEC_TransferCall_Spinner_Loading';
const CASE_INFO_SECTION = 'caseInformation';
/** Mirror FEC_ConstantCommon.STR_EMPTY — chuỗi rỗng dùng chung. */
const STR_EMPTY = '';
const STR_UNKNOWN_ERROR = 'Unknown error';

/** Thông báo từ imperative Apex (body mảng hoặc object). */
function imperativeApexErrorMessage(error) {
    if (!error) {
        return STR_UNKNOWN_ERROR;
    }
    const body = error.body;
    if (Array.isArray(body)) {
        const joined = body
            .map((e) => e?.message)
            .filter((m) => typeof m === 'string' && m.length);
        if (joined.length) {
            return joined.join(', ');
        }
    }
    const outErrs = body?.output?.errors;
    if (Array.isArray(outErrs) && outErrs.length) {
        const joined = outErrs
            .map((e) => e?.message)
            .filter((m) => typeof m === 'string' && m.length);
        if (joined.length) {
            return joined.join(', ');
        }
    }
    if (body && typeof body.message === 'string' && body.message.length) {
        return body.message;
    }
    if (typeof error.message === 'string' && error.message.length) {
        return error.message;
    }
    return STR_UNKNOWN_ERROR;
}

/**
 * Gom chi tiết từ TransferCallResponse khi success === false.
 * Ưu tiên errorMessage / ResultOfClass / body thô (rawResponse), tránh chỉ hiện Code: 0 + HTTP.
 */
function transferCallFailureMessage(result) {
    if (!result || typeof result !== 'object') {
        return 'Transfer failed.';
    }
    const r = result;
    const err = typeof r.errorMessage === 'string' ? r.errorMessage.trim() : STR_EMPTY;
    const reason =
        typeof r.Reason === 'string'
            ? r.Reason.trim()
            : typeof r.reason === 'string'
              ? r.reason.trim()
              : STR_EMPTY;
    const roc =
        typeof r.ResultOfClass === 'string'
            ? r.ResultOfClass.trim()
            : typeof r.resultOfClass === 'string'
              ? r.resultOfClass.trim()
              : STR_EMPTY;
    const rawFull =
        typeof r.rawResponse === 'string' ? r.rawResponse.trim() : STR_EMPTY;
    let rawForMain = rawFull;
    if (rawFull.startsWith('{') || rawFull.startsWith('[')) {
        try {
            const parsed = JSON.parse(rawFull);
            const pick =
                (typeof parsed?.Reason === 'string' && parsed.Reason) ||
                (typeof parsed?.reason === 'string' && parsed.reason) ||
                (typeof parsed?.message === 'string' && parsed.message) ||
                (typeof parsed?.errorMessage === 'string' && parsed.errorMessage) ||
                (typeof parsed?.error === 'string' && parsed.error) ||
                (typeof parsed?.detail === 'string' && parsed.detail) ||
                (typeof parsed?.ResultOfClass === 'string' && parsed.ResultOfClass);
            if (pick) {
                rawForMain = pick;
            }
        } catch {
            /* giữ nguyên raw */
        }
    }
    const rawShort =
        rawForMain.length > 550 ? `${rawForMain.slice(0, 550)}…` : rawForMain;

    let main = err || reason || roc || STR_EMPTY;
    if (!main && rawShort) {
        main = rawShort;
    }

    const codeRaw = r.Code ?? r.code;
    const codeStr = codeRaw != null && codeRaw !== STR_EMPTY ? String(codeRaw).trim() : STR_EMPTY;

    const codeTrivial =
        codeStr === STR_EMPTY || codeStr === '0' || codeStr === 'E';
    const st = r.httpStatus ?? r.HttpStatus;
    const hasHttp = st != null && String(st).length > 0;

    const meta = [];
    if (!codeTrivial) {
        meta.push(`Code: ${codeStr}`);
    }
    if (hasHttp) {
        meta.push(`HTTP ${st}`);
    }

    if (main) {
        // Pega đã trả Reason — chỉ hiển thị nội dung nghiệp vụ, bỏ "HTTP 400" gây nhiễu.
        const fromPegaReason =
            typeof r.Reason === 'string' && r.Reason.trim().length > 0;
        if (fromPegaReason) {
            return main;
        }
        return meta.length ? `${main} — ${meta.join(', ')}` : main;
    }
    if (meta.length) {
        return meta.join(' — ');
    }
    return 'Transfer failed.';
}

const STORAGE_KEY_PREFIX        = 'fec_TransferCall_ok_';
const STORAGE_REMARK_PREFIX     = 'fec_TransferCall_remark_';
const STORAGE_STATUS_PREFIX     = 'fec_TransferCall_status_';
const STORAGE_REASON_PREFIX     = 'fec_TransferCall_reason_';
const STORAGE_FAIL_COUNT_PREFIX = 'fec_TransferCall_failCount_';

const MAX_TRANSFER_RETRIES = 3;

export default class Fec_TransferCall extends NavigationMixin(LightningElement) {
    @api recordId;

    activeSections = [CASE_INFO_SECTION];
    showConfirmModal = false;
    remarkValue = STR_EMPTY;
    isTransferring = false;
    /** Sau khi chuyển Collections thành công — hiện Noti-16 (nút vẫn bấm được). */
    transferCompleted = false;

    /** Sau khi chuyển Collections thất bại — hiện Call Transfer Details với status Failure. */
    transferFailed = false;

    /** Status tức thì sau khi transfer (trước khi wire refresh): 'Success' | 'Failure' | ''. */
    _localTransferStatus = STR_EMPTY;

    /** Lý do lỗi tức thì sau khi transfer thất bại (trước khi wire refresh). */
    _localFailureReason = STR_EMPTY;

    /** Remark user đã nhập tại modal xác nhận, lưu để hiển thị trong Call Transfer Details. */
    transferRemark = STR_EMPTY;

    /** Dòng chi tiết sau &quot;Lí do:&quot; — chỉ báo lỗi inline, không toast. */
    transferErrorReason = STR_EMPTY;

    /** Số lần transfer thất bại liên tiếp — ẩn nút khi đạt MAX_TRANSFER_RETRIES. */
    _transferFailCount = 0;

    @wire(getRecord, { recordId: '$recordId', fields: TRANSFER_DETAIL_FIELDS })
    _caseRecord;

    get detailTransferDataToCollections() {
        if (this.transferCompleted || this.transferFailed) {
            return 'Yes';
        }
        const v = getFieldValue(this._caseRecord?.data, TRANSFER_DATA_FIELD);
        return v === true ? 'Yes' : v === false ? 'No' : STR_EMPTY;
    }
    get detailTransferTime() {
        const v = getFieldValue(this._caseRecord?.data, TRANSFER_TIME_FIELD);
        return v || STR_EMPTY;
    }
    get detailTransferStatus() {
        if (this._localTransferStatus) {
            return this._localTransferStatus;
        }
        return getFieldValue(this._caseRecord?.data, TRANSFER_STATUS_FIELD) || STR_EMPTY;
    }
    get detailFailureReason() {
        if (this._localTransferStatus === 'Success') {
            return STR_EMPTY;
        }
        if (this._localTransferStatus === 'Failure') {
            return this._localFailureReason;
        }
        return getFieldValue(this._caseRecord?.data, FAILURE_REASON_FIELD) || STR_EMPTY;
    }
    get detailCollActionCode()     { return getFieldValue(this._caseRecord?.data, COLL_ACTION_CODE_FIELD)     || STR_EMPTY; }
    get detailCollSubActionCode()  { return getFieldValue(this._caseRecord?.data, COLL_SUB_ACTION_CODE_FIELD) || STR_EMPTY; }
    get detailCollRemarks()        { return getFieldValue(this._caseRecord?.data, COLL_REMARKS_FIELD)         || STR_EMPTY; }
    get detailCollActionDate() {
        const v = getFieldValue(this._caseRecord?.data, COLL_ACTION_DATE_FIELD);
        if (!v) return STR_EMPTY;
        try {
            const d = new Date(v);
            if (isNaN(d.getTime())) return String(v);
            const fmt = new Intl.DateTimeFormat('en-GB', {
                day: '2-digit', month: '2-digit', year: 'numeric',
                hour: '2-digit', minute: '2-digit', second: '2-digit',
                hour12: false,
                timeZone: 'Asia/Ho_Chi_Minh'
            });
            // en-GB cho "dd/MM/yyyy, HH:mm:ss" → đổi dấu phẩy thành dấu cách
            return fmt.format(d).replace(',', STR_EMPTY);
        } catch { return String(v); }
    }
    get detailCollAgent()          { return getFieldValue(this._caseRecord?.data, COLL_AGENT_FIELD)           || STR_EMPTY; }

    labelNoti16 = FEC_Notification_16_Collections_Transfer_Success;
    labelTransferFailSummary = FEC_Collections_Transfer_Failed_Summary;
    labelTransferMaxFailSummary = FEC_Collections_Transfer_MaxFailed_Summary;
    labelSectionCaseInfo = FEC_TransferCall_Section_CaseInfo;
    labelSubtitle = FEC_TransferCall_Subtitle;
    labelTransferToCollection = FEC_TransferCall_Btn_TransferToCollection;
    labelModalConfirmMessage = FEC_TransferCall_Modal_ConfirmMessage;
    labelRemarkLabel = FEC_TransferCall_Modal_RemarkLabel;
    labelRemarkRequired = FEC_TransferCall_Modal_RemarkRequired;
    labelCancel = FEC_TransferCall_Btn_Cancel;
    labelConfirmTransfer = FEC_TransferCall_Btn_ConfirmTransfer;
    labelLoading = FEC_TransferCall_Spinner_Loading;

    get isMaxFailReached() {
        return this._transferFailCount >= MAX_TRANSFER_RETRIES;
    }

    get transferStatusClass() {
        const s = this.detailTransferStatus;
        if (s === 'Success') return 'fec-td-value fec-td-value--success';
        if (s === 'Failure') return 'fec-td-value fec-td-value--failure';
        return 'fec-td-value';
    }

    get transferButtonDisabled() {
        return this.isTransferring || this.isMaxFailReached;
    }

    get hasTransferError() {
        return typeof this.transferErrorReason === 'string' && this.transferErrorReason.trim().length > 0;
    }

    get currentTransferFailSummary() {
        return this.isMaxFailReached ? this.labelTransferMaxFailSummary : this.labelTransferFailSummary;
    }

    get transferErrorReasonLine() {
        const r = (this.transferErrorReason || STR_EMPTY).trim();
        return r.length ? `Lí do: ${r}` : STR_EMPTY;
    }

    _lastRecordIdForStorage;

    renderedCallback() {
        if (!this.recordId) {
            return;
        }
        if (this._lastRecordIdForStorage === this.recordId) {
            return;
        }
        this._lastRecordIdForStorage = this.recordId;
        this.restoreTransferSuccessFromStorage();
    }

    restoreTransferSuccessFromStorage() {
        try {
            const storedFailCount = sessionStorage.getItem(STORAGE_FAIL_COUNT_PREFIX + this.recordId);
            if (storedFailCount != null) {
                this._transferFailCount = parseInt(storedFailCount, 10) || 0;
            }
            if (sessionStorage.getItem(STORAGE_KEY_PREFIX + this.recordId) === '1') {
                this.transferCompleted = true;
                this.transferRemark = sessionStorage.getItem(STORAGE_REMARK_PREFIX + this.recordId) || STR_EMPTY;
                this._localTransferStatus = 'Success';
            } else {
                const storedStatus = sessionStorage.getItem(STORAGE_STATUS_PREFIX + this.recordId);
                if (storedStatus === 'Failure') {
                    this.transferFailed = true;
                    this._localTransferStatus = 'Failure';
                    this._localFailureReason = sessionStorage.getItem(STORAGE_REASON_PREFIX + this.recordId) || STR_EMPTY;
                    this.transferErrorReason = this._localFailureReason;
                }
            }
        } catch {
            /* sessionStorage không dùng được */
        }
    }

    persistTransferSuccess(remark) {
        try {
            sessionStorage.setItem(STORAGE_KEY_PREFIX + this.recordId, '1');
            sessionStorage.setItem(STORAGE_REMARK_PREFIX + this.recordId, remark || STR_EMPTY);
            sessionStorage.setItem(STORAGE_STATUS_PREFIX + this.recordId, 'Success');
            sessionStorage.removeItem(STORAGE_REASON_PREFIX + this.recordId);
            sessionStorage.removeItem(STORAGE_FAIL_COUNT_PREFIX + this.recordId);
        } catch {
            /* bỏ qua */
        }
        this.transferCompleted = true;
        this.transferFailed = false;
        this.transferRemark = remark || STR_EMPTY;
        this._localTransferStatus = 'Success';
        this._localFailureReason = STR_EMPTY;
        this._transferFailCount = 0;
    }

    persistTransferFailure(reason) {
        if (!this.recordId) {
            return;
        }
        const r = reason || STR_EMPTY;
        this._transferFailCount += 1;
        try {
            sessionStorage.setItem(STORAGE_STATUS_PREFIX + this.recordId, 'Failure');
            sessionStorage.setItem(STORAGE_REASON_PREFIX + this.recordId, r);
            sessionStorage.setItem(STORAGE_FAIL_COUNT_PREFIX + this.recordId, String(this._transferFailCount));
        } catch {
            /* bỏ qua */
        }
        this.transferFailed = true;
        this._localTransferStatus = 'Failure';
        this._localFailureReason = r;
    }

    clearTransferSuccessSession() {
        this.transferCompleted = false;
        this.transferFailed = false;
        this._localTransferStatus = STR_EMPTY;
        this._localFailureReason = STR_EMPTY;
        this.transferRemark = STR_EMPTY;
        if (!this.recordId) {
            return;
        }
        try {
            sessionStorage.removeItem(STORAGE_KEY_PREFIX + this.recordId);
            sessionStorage.removeItem(STORAGE_REMARK_PREFIX + this.recordId);
            sessionStorage.removeItem(STORAGE_STATUS_PREFIX + this.recordId);
            sessionStorage.removeItem(STORAGE_REASON_PREFIX + this.recordId);
        } catch {
            /* bỏ qua */
        }
    }

    navigateToCaseView() {
        if (!this.recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    handleSectionToggle(event) {
        this.activeSections = event.detail.openSections;
    }

    handleOpenConfirmModal() {
        if (!this.recordId || this.isTransferring || this.isMaxFailReached) {
            return;
        }
        this.transferErrorReason = STR_EMPTY;
        this.transferFailed = false;
        this._localTransferStatus = STR_EMPTY;
        this._localFailureReason = STR_EMPTY;
        this.remarkValue = STR_EMPTY;
        this.showConfirmModal = true;
    }

    handleCancelModal() {
        if (this.isTransferring) {
            return;
        }
        this.showConfirmModal = false;
        this.remarkValue = STR_EMPTY;
    }

    handleRemarkChange(event) {
        this.remarkValue = event.target.value;
    }

    async handleConfirmTransfer() {
        if (!this.recordId || this.isTransferring) {
            return;
        }

        const textarea = this.template.querySelector(
            'lightning-textarea[name="collectionsRemark"]'
        );
        if (textarea) {
            const ok = textarea.checkValidity();
            textarea.reportValidity();
            if (!ok) {
                return;
            }
        }

        const trimmed = (this.remarkValue || STR_EMPTY).trim();
        if (!trimmed) {
            this.showConfirmModal = false;
            this.transferErrorReason = 'Vui lòng nhập Remark for Collections.';
            return;
        }

        this.transferErrorReason = STR_EMPTY;
        this.isTransferring = true;

        transferCallFromCase({ caseId: this.recordId, remark: trimmed })
            .then((result) => {
                // Debug: mở DevTools (F12) → Console khi cần bắt HTTP 400 / payload Pega.
                // eslint-disable-next-line no-console
                console.log('[fec_TransferCall] apex result', {
                    caseId: this.recordId,
                    remarkLen: trimmed.length,
                    success: result?.success,
                    httpStatus: result?.httpStatus,
                    Code: result?.Code,
                    Reason: result?.Reason,
                    errorMessage: result?.errorMessage,
                    ResultOfClass: result?.ResultOfClass,
                    rawResponse: result?.rawResponse
                });
                if (result?.success) {
                    this.showConfirmModal = false;
                    this.transferErrorReason = STR_EMPTY;
                    this.persistTransferSuccess(trimmed);
                    this.remarkValue = STR_EMPTY;
                    this.navigateToCaseView();
                } else {
                    this.clearTransferSuccessSession();
                    this.showConfirmModal = false;
                    this.transferErrorReason = transferCallFailureMessage(result);
                    this.persistTransferFailure(this.transferErrorReason);
                    // eslint-disable-next-line no-console
                    console.warn(
                        '[fec_TransferCall] transfer failed',
                        this.transferErrorReason
                    );
                }
            })
            .catch((err) => {
                this.clearTransferSuccessSession();
                this.showConfirmModal = false;
                this.transferErrorReason = imperativeApexErrorMessage(err);
                this.persistTransferFailure(this.transferErrorReason);
                // eslint-disable-next-line no-console
                console.error('[fec_TransferCall] apex exception', err);
            })
            .finally(() => {
                this.isTransferring = false;
            });
    }

}