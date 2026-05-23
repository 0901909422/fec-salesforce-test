/****************************************************************************************
 * File Name    : fec_PointsRedemptionCaseForm.js
 * Description  : Points Redemption — Case Information (RC33.01–03): tiers from initData,
 *                redeem via FEC_PointsRedemptionCaseController.redeem (CMS services).
 ****************************************************************************************/
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import CASE_NOC from '@salesforce/messageChannel/FEC_Case_NOC__c';
import initData from '@salesforce/apex/FEC_PointsRedemptionCaseController.initData';
import redeem from '@salesforce/apex/FEC_PointsRedemptionCaseController.redeem';
import saveDraftSelection from '@salesforce/apex/FEC_PointsRedemptionCaseController.saveDraftSelection';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import FEC_Points_Redeem_Button_Label from '@salesforce/label/c.FEC_Points_Redeem_Button_Label';
import FEC_Points_Redeem_Fail_After_Max from '@salesforce/label/c.FEC_Points_Redeem_Fail_After_Max';
import FEC_Points_Redeem_Fail_Retry from '@salesforce/label/c.FEC_Points_Redeem_Fail_Retry';
import FEC_Points_Redeem_Success_Message from '@salesforce/label/c.FEC_Points_Redeem_Success_Message';
import FEC_Points_Redeemed_Points_Label from '@salesforce/label/c.FEC_Points_Redeemed_Points_Label';
import FEC_Points_Redemption_CMS_Phone_Label from '@salesforce/label/c.FEC_Points_Redemption_CMS_Phone_Label';
import FEC_Points_Redemption_Confirm_Message from '@salesforce/label/c.FEC_Points_Redemption_Confirm_Message';
import FEC_Points_Redemption_Confirm_Title from '@salesforce/label/c.FEC_Points_Redemption_Confirm_Title';
import FEC_Yes_Btn from '@salesforce/label/c.FEC_Yes_Btn';
import FEC_No_Btn from '@salesforce/label/c.FEC_No_Btn';
import Loading from '@salesforce/label/c.Loading';
import {
    STR_EMPTY,
    FEC_POINTS_REDEMPTION_STORAGE_NOC_LOCK_PREFIX,
    FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX
} from 'c/fec_CommonConst';

const LS_FAIL = 'fec-pr-fail-';
const LS_OK = 'fec-pr-ok-';
const MAX_FAIL = 3;
const VARIANT = { ERROR: 'error', SUCCESS: 'success', WARNING: 'warning' };

//linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
function isPointsRedemptionRc33Branch(subCode) {
    if (!subCode) {
        return false;
    }
    const s = String(subCode).trim().toUpperCase();
    return s.includes('RC33.01') || s.includes('RC33.02') || s.includes('RC33.03');
}

//linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — khôi phục Redeemed Points đã lưu sau submit
function resolveSelectedTierFromSaved(savedRedeemedPoints, tierOptionsUi) {
    if (!savedRedeemedPoints || !tierOptionsUi || !tierOptionsUi.length) {
        return null;
    }
    const savedNorm = String(savedRedeemedPoints).trim();
    if (!savedNorm) {
        return null;
    }
    for (const o of tierOptionsUi) {
        if (o.label === savedNorm) {
            return o.value;
        }
        try {
            const p = JSON.parse(o.value);
            if (p && p.price != null && String(Math.trunc(Number(p.price))) === savedNorm) {
                return o.value;
            }
        } catch (e) {
            // no-op
        }
    }
    return null;
}

export default class Fec_PointsRedemptionCaseForm extends NavigationMixin(LightningElement) {
    @api recordId;
    @api subCodeCode;
    @api isEdit;

    @track loading = false;
    @track showPanel = false;
    @track notEligibleMessage;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — lý do không đủ điều kiện (vd Available Points < 100,000)
    @track notEligibleReason;
    @track cmsPhone = STR_EMPTY;
    @track tierOptionsUi = [];
    @track selectedTierJson;
    @track redeemDisabled = false;
    @track failCount = 0;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — Noti-06/07: thông báo đỏ in đậm dưới nút Redeem Points
    @track redeemFailMessage;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — thông báo xanh in đậm dưới nút Redeem Points (không toast)
    @track redeemSuccessMessage;
    @track showRedeemConfirmModal = false;

    _lastSub = STR_EMPTY;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — khóa NOC sau Có/Không pop-up Redeem Points
    _redeemModalConfirmed = false;
    _redeemConfirmResolver;

    @wire(MessageContext)
    messageContext;

    get isReadOnly() {
        return this.isEdit === false;
    }

    get lsFailKey() {
        return this.recordId ? LS_FAIL + this.recordId : null;
    }

    get lsOkKey() {
        return this.recordId ? LS_OK + this.recordId : null;
    }

    connectedCallback() {
        this.restoreLocalState();
        this._restoreRedeemModalConfirmedFromStorage();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — gap 1: re-publish khóa NOC khi reload tab
        this._syncNocLockToCaseEditNocIfNeeded();
        this._lastSub = (this.subCodeCode || STR_EMPTY).trim();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
        this._notifyPointsRedemptionSectionVisibility();
        this.refreshInit();
    }

    renderedCallback() {
        const sub = (this.subCodeCode || STR_EMPTY).trim();
        if (this.recordId && sub !== this._lastSub) {
            this._lastSub = sub;
            //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
            this._notifyPointsRedemptionSectionVisibility();
            this.refreshInit();
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — chỉ ẩn C360/Property khi không đủ điều kiện đổi điểm
    _notifyPointsRedemptionSectionVisibility() {
        if (!isPointsRedemptionRc33Branch(this.subCodeCode)) {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('fecpointsredemptionsectionvisibility', {
                bubbles: true,
                composed: true,
                detail: {
                    hideC360AndProperty: !!this.notEligibleMessage
                }
            })
        );
    }

    restoreLocalState() {
        try {
            if (this.lsOkKey && window.localStorage.getItem(this.lsOkKey) === '1') {
                this.redeemDisabled = true;
                this.redeemSuccessMessage = FEC_Points_Redeem_Success_Message;
            }
            if (this.lsFailKey) {
                const n = parseInt(window.localStorage.getItem(this.lsFailKey) || '0', 10);
                this.failCount = isNaN(n) ? 0 : n;
                if (this.failCount >= MAX_FAIL) {
                    this.redeemDisabled = true;
                    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — gap 6: hiển thị Noti-07 sau reload
                    this.redeemFailMessage = FEC_Points_Redeem_Fail_After_Max;
                }
            }
        } catch (e) {
            // no-op
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
    _applyInitResult(r) {
        this.showPanel = !!(r && r.showRedemptionUi);
        this.notEligibleMessage = r && r.notEligibleMessage ? r.notEligibleMessage : null;
        this.notEligibleReason = r && r.notEligibleReason ? r.notEligibleReason : null;
        this.cmsPhone = r && r.cmsPhone ? r.cmsPhone : STR_EMPTY;
        const opts = (r && r.tierOptions) || [];
        this.tierOptionsUi = opts.map((o) => ({
            label: o.label,
            value: o.valueJson
        }));
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
        const restored = resolveSelectedTierFromSaved(r && r.savedRedeemedPoints, this.tierOptionsUi);
        this.selectedTierJson = restored || null;
        this._notifyPointsRedemptionSectionVisibility();
    }

    refreshInit() {
        if (!this.recordId) {
            return;
        }
        this.loading = true;
        this.notEligibleMessage = null;
        this.notEligibleReason = null;
        this._notifyPointsRedemptionSectionVisibility();
        initData({ caseId: this.recordId, subCodeCode: this.subCodeCode || null })
            .then((r) => {
                this._applyInitResult(r);
            })
            .catch((err) => {
                this.showPanel = false;
                this.notEligibleMessage = null;
                this.notEligibleReason = null;
                this._notifyPointsRedemptionSectionVisibility();
                this.toast(FEC_Toast_Error, this.msg(err), VARIANT.ERROR);
            })
            .finally(() => {
                this.loading = false;
            });
    }

    handleTierChange(e) {
        this.selectedTierJson = e.detail.value;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    _storageRedeemModalConfirmedKey() {
        return this.recordId ? FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId : null;
    }

    _storageNocLockKey() {
        return this.recordId ? FEC_POINTS_REDEMPTION_STORAGE_NOC_LOCK_PREFIX + this.recordId : null;
    }

    _restoreRedeemModalConfirmedFromStorage() {
        try {
            const k = this._storageRedeemModalConfirmedKey();
            this._redeemModalConfirmed = !!(k && sessionStorage.getItem(k) === '1');
        } catch (e) {
            this._redeemModalConfirmed = false;
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — gap 1: fec_CaseEditNOC mount sau vẫn nhận khóa NOC
    _syncNocLockToCaseEditNocIfNeeded() {
        if (!this._redeemModalConfirmed || !this.messageContext || !this.recordId) {
            return;
        }
        publish(this.messageContext, CASE_NOC, {
            caseId: this.recordId,
            pointsRedemptionNocLocked: true
        });
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — Có/Không pop-up Redeem Points: khóa NOC (giống Fast Cash)
    applyNocLockAfterRedeemModal() {
        this._redeemModalConfirmed = true;
        try {
            const modalKey = this._storageRedeemModalConfirmedKey();
            const lockKey = this._storageNocLockKey();
            if (modalKey) {
                sessionStorage.setItem(modalKey, '1');
            }
            if (lockKey) {
                sessionStorage.setItem(lockKey, '1');
            }
        } catch (e) {
            // no-op
        }
        if (this.messageContext && this.recordId) {
            publish(this.messageContext, CASE_NOC, {
                caseId: this.recordId,
                pointsRedemptionNocLocked: true
            });
        }
        this.dispatchEvent(
            new CustomEvent('fecpointsredemptionredeemmodalconfirmed', {
                bubbles: true,
                composed: true,
                detail: { recordId: this.recordId }
            })
        );
    }

    async handleRedeemClick() {
        if (this.isReadOnly || this.redeemDisabled) {
            return;
        }
        if (!this.selectedTierJson) {
            this.toast(FEC_Toast_Validation_Title, FEC_Complete_This_Field, VARIANT.WARNING);
            return;
        }
        const ok = await this.openRedeemConfirmModal();
        if (!ok) {
            return;
        }
        this.redeemFailMessage = null;
        this.redeemSuccessMessage = null;
        this.loading = true;
        redeem({ caseId: this.recordId, tierJson: this.selectedTierJson, subCodeCode: this.subCodeCode || null })
            .then((res) => {
                if (res && res.success) {
                    this.persistOk();
                    this.redeemDisabled = true;
                    this.redeemSuccessMessage = FEC_Points_Redeem_Success_Message;
                    this.navigateCase();
                } else {
                    this.onRedeemFail();
                }
            })
            .catch(() => {
                this.onRedeemFail();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    openRedeemConfirmModal() {
        this.showRedeemConfirmModal = true;
        return new Promise((resolve) => {
            this._redeemConfirmResolver = resolve;
        });
    }

    _finishRedeemConfirmModal(result) {
        if (this._redeemConfirmResolver) {
            this._redeemConfirmResolver(result);
            this._redeemConfirmResolver = null;
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — Không: khóa NOC (giống Fast Cash handleConfirmNo)
    handleCancelRedeemConfirmModal() {
        this.showRedeemConfirmModal = false;
        this.applyNocLockAfterRedeemModal();
        this._finishRedeemConfirmModal(false);
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — Có: khóa NOC rồi gọi redeem (giống Fast Cash handleConfirmYes)
    handleConfirmRedeemConfirmModal() {
        this.showRedeemConfirmModal = false;
        this.applyNocLockAfterRedeemModal();
        this._finishRedeemConfirmModal(true);
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — Noti-06/07 inline, không toast lỗi API
    onRedeemFail() {
        this.failCount += 1;
        try {
            if (this.lsFailKey) {
                window.localStorage.setItem(this.lsFailKey, String(this.failCount));
            }
        } catch (e) {
            // no-op
        }
        if (this.failCount >= MAX_FAIL) {
            this.redeemDisabled = true;
            this.redeemFailMessage = FEC_Points_Redeem_Fail_After_Max;
            this.navigateCase();
        } else {
            this.redeemFailMessage = FEC_Points_Redeem_Fail_Retry;
        }
    }

    persistOk() {
        try {
            if (this.lsOkKey) {
                window.localStorage.setItem(this.lsOkKey, '1');
            }
        } catch (e) {
            // no-op
        }
    }

    navigateCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Case', actionName: 'view' }
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    msg(err) {
        return err && err.body && err.body.message ? err.body.message : err && err.message ? err.message : FEC_Toast_Error;
    }

    @api validateForSubmit() {
        if (this.isReadOnly || !this.showPanel) {
            return true;
        }
        if (!this.selectedTierJson) {
            this.toast(FEC_Toast_Validation_Title, FEC_Complete_This_Field, VARIANT.WARNING);
            return false;
        }
        return true;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    @api saveDraftIfApplicable() {
        if (this.isReadOnly || !this.showPanel || !this.selectedTierJson) {
            return Promise.resolve();
        }
        return saveDraftSelection({ caseId: this.recordId, tierJson: this.selectedTierJson, subCodeCode: this.subCodeCode || null });
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — đồng bộ FEC_Redeemed_Points__c lên record form khi submit
    @api getSelectedRedeemedPointsValue() {
        if (!this.selectedTierJson) {
            return null;
        }
        try {
            const p = JSON.parse(this.selectedTierJson);
            if (p && p.price != null) {
                return String(Math.trunc(Number(p.price)));
            }
        } catch (e) {
            // no-op
        }
        return null;
    }

    get loadingLabel() {
        return Loading;
    }

    get labelRedeemedPoints() {
        return FEC_Points_Redeemed_Points_Label;
    }

    get labelCmsPhone() {
        return FEC_Points_Redemption_CMS_Phone_Label;
    }

    get labelRedeemPoints() {
        return FEC_Points_Redeem_Button_Label;
    }

    get labelRedeemConfirmTitle() {
        return FEC_Points_Redemption_Confirm_Title;
    }

    get labelRedeemConfirmMessage() {
        return FEC_Points_Redemption_Confirm_Message;
    }

    get labelNoBtn() {
        return FEC_No_Btn;
    }

    get labelYesBtn() {
        return FEC_Yes_Btn;
    }
}