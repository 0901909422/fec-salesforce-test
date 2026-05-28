import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import CASE_NOC from '@salesforce/messageChannel/FEC_Case_NOC__c';
import getNFUReasons from '@salesforce/apex/FEC_HoldCaseController.getNFUReasons';
import saveHoldCase from '@salesforce/apex/FEC_HoldCaseController.saveHoldCase';
import persistManualHoldCaseError from '@salesforce/apex/FEC_HoldCaseController.persistManualHoldCaseError';

import FEC_NFU_Reason from '@salesforce/label/c.FEC_NFU_Reason';
import FEC_Hold_Case from '@salesforce/label/c.FEC_Hold_Case';
import FEC_NFU_Code from '@salesforce/label/c.FEC_NFU_Code';
import FEC_NFU_Hold_Day_Duration from '@salesforce/label/c.FEC_NFU_Hold_Day_Duration';
import FEC_Messenger_Success_Hold_Case from '@salesforce/label/c.FEC_Messenger_Success_Hold_Case';
import FEC_Error_MessageError_Hold_Case from '@salesforce/label/c.FEC_Error_MessageError_Hold_Case';
import FEC_Error_Message_Maxretris from '@salesforce/label/c.FEC_Error_Message_Maxretris';
import FEC_Show_Action_Hold_Case from '@salesforce/label/c.FEC_Show_Action_Hold_Case';
import FEC_Failed_To_Load_NFU from '@salesforce/label/c.FEC_Failed_To_Load_NFU';
import FEC_Please_Select_An_NFU from '@salesforce/label/c.FEC_Please_Select_An_NFU';
import FEC_An_Unexpected_Error from '@salesforce/label/c.FEC_An_Unexpected_Error';
import FEC_MSG_SUCCESS from '@salesforce/label/c.FEC_MSG_SUCCESS';
import FEC_STOP_IMPACT_ALREADY_MARKED_MSG from '@salesforce/label/c.FEC_STOP_IMPACT_ALREADY_MARKED_MSG';
import FEC_MSG_ERROR from '@salesforce/label/c.FEC_MSG_ERROR';
import {
    STR_EMPTY, ERROR_TOAST_TYPE, WARNING_HOLD_CASE,
    WARNING_HOLD_TOAST, SUCCESS_MODAL_TITLE, ERROR_MODAL_TITLE
} from 'c/fec_CommonConst';

export default class Fec_holdCaseManual extends LightningElement {

    @api
    get recordId() { return this._recordId; }
    set recordId(val) {
        this._recordId = val;
        // tungnm37 fix: khi recordId được set, thử đọc sessionStorage và load nếu chưa có options
        if (this._recordId && this.nfuReasonOptions.length === 0) {
            this._readSessionStorageNoc();
            // tungnm37: nếu đã có NOC IDs từ sessionStorage thì load ngay, không cần chờ message
            const hasNocIds = !!(this._nocProductTypeId && this._nocCategoryId && this._nocSubCategoryId);
            this._loadNFUReasons(!hasNocIds);
        }
    }
    _recordId;

    // tungnm37: NOC IDs từ parent (khi Case chưa save NOC vào DB)
    @api productTypeId;
    @api categoryId;
    @api subCategoryId;
    @api subCodeId;

    // tungnm37: NOC IDs từ message channel (Quick Action không nhận props từ parent)
    _nocProductTypeId;
    _nocCategoryId;
    _nocSubCategoryId;
    _nocSubCodeId;

    @wire(MessageContext)
    messageContext;

    _subscription = null;

    @track selectedReason = STR_EMPTY;
    @track nfuCode = STR_EMPTY;
    @track nfuHoldDayDuration = STR_EMPTY;
    @track nfuReasonOptions = [];
    @track isLoading = false;
    @track errorMessage = STR_EMPTY;
    // tungnm37: TH1 = already marked (xanh lá), TH2 = success (xanh lá), TH3 = max retries (đỏ)
    @track responseMessage = STR_EMPTY;
    @track responseType = STR_EMPTY; // 'ALREADY_MARKED' | 'SUCCESS' | 'ERROR'
    // tungnm37: NFU info sau khi gọi API thành công
    @track nfuStatus = STR_EMPTY;
    @track nfuStartedDate = STR_EMPTY;
    @track nfuExpiryDate = STR_EMPTY;
    @track nfuReason = STR_EMPTY;
    // tungnm37: NFU result sau khi thành công
    @track nfuStatusResult = STR_EMPTY;
    @track nfuCodeResult = STR_EMPTY;
    @track nfuStartedDateResult = STR_EMPTY;
    @track nfuExpiryDateResult = STR_EMPTY;
    @track nfuReasonResult = STR_EMPTY;
    @track isCompleted = false; // tungnm37: true khi SUCCESS hoặc ALREADY_MARKED

    _nfuReasonMap = {};
    _retryCount = 0;
    _maxRetries = 3;

    customLabel = {
        nfuReason: FEC_NFU_Reason,
        HoldCase: FEC_Hold_Case,
        nfuCode: FEC_NFU_Code,
        nfuHoldDayDuration: FEC_NFU_Hold_Day_Duration,
        messengerSuccessHoldCase: FEC_Messenger_Success_Hold_Case,
        errorMessageErrorHoldCase: FEC_Error_MessageError_Hold_Case,
        errorMessageMaxretris: FEC_Error_Message_Maxretris,
        showActionHoldCase: FEC_Show_Action_Hold_Case,
        failedToLoadNFU: FEC_Failed_To_Load_NFU,
        pleaseSelectAnNFU: FEC_Please_Select_An_NFU,
        anUnexpectedError: FEC_An_Unexpected_Error
    };

    connectedCallback() {
        // tungnm37: đọc NOC IDs từ sessionStorage (được lưu bởi fec_SubProcessContainer)
        // vì Quick Action mount sau khi message CASE_NOC đã publish → subscription không nhận được
        this._readSessionStorageNoc();

        // tungnm37: subscribe CASE_NOC để lấy NOC IDs khi Case chưa save
        this._subscription = subscribe(
            this.messageContext,
            CASE_NOC,
            (msg) => {
                this._nocProductTypeId = msg.productTypeId;
                this._nocCategoryId = msg.categoryId;
                this._nocSubCategoryId = msg.subCategoryId;
                this._nocSubCodeId = msg.subCodeId;
                // tungnm37 fix: khi nhận được NOC IDs → load lại nếu chưa có options
                if (this._recordId && this.nfuReasonOptions.length === 0) {
                    this._loadNFUReasons(false);
                }
            },
            { scope: APPLICATION_SCOPE }
        );

        if (this._recordId && this.nfuReasonOptions.length === 0) {
            // tungnm37: nếu đã có NOC IDs (từ sessionStorage) thì load ngay, không chờ message
            const hasNocIds = !!(this._nocProductTypeId && this._nocCategoryId && this._nocSubCategoryId);
            this._loadNFUReasons(!hasNocIds);
        }
    }

    // tungnm37: đọc NOC IDs từ sessionStorage
    _readSessionStorageNoc() {
        try {
            const key = 'fec_case_noc_' + this._recordId;
            const stored = sessionStorage.getItem(key);
            if (stored) {
                const noc = JSON.parse(stored);
                this._nocProductTypeId = noc.productTypeId;
                this._nocCategoryId = noc.categoryId;
                this._nocSubCategoryId = noc.subCategoryId;
                this._nocSubCodeId = noc.subCodeId;
            }
        } catch (e) {
            // ignore storage errors
        }
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = null;
        }
    }

    // tungnm37: load NFU Reasons theo caseId (query NOC từ Case)
    // tungnm37 fix: nếu có NOC IDs từ parent/message channel thì dùng trực tiếp (Case chưa save NOC)
    // isInitial=true: lần đầu load, không đóng popup nếu empty (chờ NOC IDs từ message channel)
    async _loadNFUReasons(isInitial = false) {
        this.isLoading = true;
        try {
            const data = await getNFUReasons({
                caseId: this._recordId,
                productTypeId: this.productTypeId || this._nocProductTypeId || null,
                categoryId: this.categoryId || this._nocCategoryId || null,
                subCategoryId: this.subCategoryId || this._nocSubCategoryId || null,
                subCodeId: this.subCodeId || this._nocSubCodeId || null
            });
            if (data && data.length > 0) {
                this.nfuReasonOptions = data
                    .filter(item => item.isActive)
                    .map(item => ({
                        label: item.nfuReasonVN || item.nfuReasonEN,
                        value: item.nfuCode
                    }));

                this._nfuReasonMap = {};
                data.forEach(item => {
                    this._nfuReasonMap[item.nfuCode] = {
                        nfuDuration: item.nfuDuration,
                        holdCaseType: item.holdCaseType,
                        nfuReasonVN: item.nfuReasonVN,
                        nfuCode: item.nfuCode
                    };
                });
            } else {
                // tungnm37 fix: không có config hold case → hiện thông báo và đóng popup
                this._showToast(STR_EMPTY, this.customLabel.showActionHoldCase, ERROR_TOAST_TYPE);
                this.handleCancel();
            }
        } catch (error) {
            this._showToast(STR_EMPTY, this.customLabel.failedToLoadNFU + (error?.body?.message ?? error), ERROR_TOAST_TYPE);
        } finally {
            this.isLoading = false;
        }
    }

    get isHoldDisabled() {
        return !this.selectedReason || this._retryCount >= this._maxRetries;
    }

    // tungnm37: hiện message xanh lá khi TH1 hoặc TH2
    get isSuccessMessage() {
        return this.responseType === 'SUCCESS' || this.responseType === 'ALREADY_MARKED';
    }

    // tungnm37: hiện message đỏ khi lỗi
    get isErrorMessage() {
        return this.responseType === 'ERROR';
    }

    get showNfuDetailsInPopup() {
        return this.isCompleted
            && (this.responseType === 'SUCCESS' || this.responseType === 'ALREADY_MARKED');
    }

    handleReasonChange(event) {
        this.selectedReason = event.detail.value;
        const meta = this._nfuReasonMap[this.selectedReason];
        if (meta) {
            this.nfuCode = meta.nfuCode;
            this.nfuHoldDayDuration = meta.nfuDuration;
        } else {
            this.nfuCode = STR_EMPTY;
            this.nfuHoldDayDuration = STR_EMPTY;
        }
        // Reset message khi chọn lại
        this.responseMessage = STR_EMPTY;
        this.responseType = STR_EMPTY;
    }

    async handleCancel() {
        if (this.responseType === 'ERROR' && this._retryCount >= this._maxRetries) {
            try {
                await persistManualHoldCaseError({ caseId: this._recordId });
            } catch (persistErr) {
                // ignore
            }
            await this._notifyCaseRefresh('ERROR');
        }
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    _setHoldCaseDisplayFlag(resultType) {
        if (!this._recordId || !resultType) {
            return;
        }
        try {
            sessionStorage.setItem('fec_hold_case_display_' + this._recordId, resultType);
        } catch (e) {
            // ignore
        }
    }

    async _notifyCaseRefresh(resultType) {
        if (!this._recordId) {
            return;
        }
        if (resultType) {
            this._setHoldCaseDisplayFlag(resultType);
        }
        try {
            sessionStorage.setItem('fec_hold_case_refresh_' + this._recordId, Date.now().toString());
        } catch (e) {
            // ignore
        }
        getRecordNotifyChange([{ recordId: this._recordId }]);
        // Đợi LDS propagate trước khi user đóng popup
        await new Promise((resolve) => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(resolve, 400);
        });
    }

    _applyNfuResultFromResponse(response) {
        this.nfuCodeResult = response.nfuCode || this.nfuCode || STR_EMPTY;
        this.nfuStatusResult = response.nfuStatus || STR_EMPTY;
        this.nfuStartedDateResult = response.nfuStartedDate || STR_EMPTY;
        this.nfuExpiryDateResult = response.nfuExpiryDate || STR_EMPTY;
        this.nfuReasonResult = response.nfuReason || STR_EMPTY;
    }

    async handleHoldCase() {
        if (!this.selectedReason) {
            this._showToast(WARNING_HOLD_CASE, this.customLabel.pleaseSelectAnNFU, WARNING_HOLD_TOAST);
            return;
        }
        if (this._retryCount >= this._maxRetries) return;

        const attemptNumber = this._retryCount + 1;
        this.isLoading = true;
        try {
            const response = await saveHoldCase({
                caseId: this._recordId,
                nfuReason: this.selectedReason,
                nfuCode: this.nfuCode,
                holdDuration: this.nfuHoldDayDuration,
                attemptNumber
            });

            if (response?.status === 'SUCCESS') {
                this.responseType = 'SUCCESS';
                this.responseMessage = response.message || FEC_MSG_SUCCESS;
                this._retryCount = 0;
                this.isCompleted = true;
                this._applyNfuResultFromResponse(response);
                await this._notifyCaseRefresh('SUCCESS');

            } else if (response?.status === 'ALREADY_MARKED') {
                this.responseType = 'ALREADY_MARKED';
                this.responseMessage = response.message || FEC_STOP_IMPACT_ALREADY_MARKED_MSG;
                this._retryCount = 0;
                this.isCompleted = true;
                this._applyNfuResultFromResponse(response);
                await this._notifyCaseRefresh('ALREADY_MARKED');

            } else {
                this._retryCount += 1;
                this.responseType = 'ERROR';
                if (this._retryCount >= this._maxRetries) {
                    this.responseMessage = FEC_MSG_ERROR;
                    try {
                        await persistManualHoldCaseError({ caseId: this._recordId });
                    } catch (persistErr) {
                        // ignore
                    }
                    await this._notifyCaseRefresh('ERROR');
                } else {
                    this.responseMessage = FEC_MSG_ERROR;
                }
            }

        } catch (error) {
            this._retryCount += 1;
            this.responseType = 'ERROR';
            const msg = error?.body?.message ?? this.customLabel.anUnexpectedError;
            if (this._retryCount >= this._maxRetries) {
                this.responseMessage = FEC_MSG_ERROR;
                try {
                    await persistManualHoldCaseError({ caseId: this._recordId });
                } catch (persistErr) {
                    // ignore persist failure
                }
                await this._notifyCaseRefresh('ERROR');
            } else {
                this.responseMessage = FEC_MSG_ERROR;
            }
        } finally {
            this.isLoading = false;
        }
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}