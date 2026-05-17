/****************************************************************************************
 * File Name    : fec_PointsRedemptionCaseForm.js
 * Description  : Points Redemption — Case Information (RC33.01–03): tiers from initData,
 *                redeem via FEC_PointsRedemptionCaseController.redeem (CMS services).
 ****************************************************************************************/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import LightningConfirm from 'lightning/confirm';
import initData from '@salesforce/apex/FEC_PointsRedemptionCaseController.initData';
import redeem from '@salesforce/apex/FEC_PointsRedemptionCaseController.redeem';
import saveDraftSelection from '@salesforce/apex/FEC_PointsRedemptionCaseController.saveDraftSelection';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import FEC_Points_Redeem_Button_Label from '@salesforce/label/c.FEC_Points_Redeem_Button_Label';
import FEC_Points_Redeem_Fail_After_Max from '@salesforce/label/c.FEC_Points_Redeem_Fail_After_Max';
import FEC_Points_Redeem_Fail_Prefix from '@salesforce/label/c.FEC_Points_Redeem_Fail_Prefix';
import FEC_Points_Redeem_Success_Message from '@salesforce/label/c.FEC_Points_Redeem_Success_Message';
import FEC_Points_Redeemed_Points_Label from '@salesforce/label/c.FEC_Points_Redeemed_Points_Label';
import FEC_Points_Redemption_CMS_Phone_Label from '@salesforce/label/c.FEC_Points_Redemption_CMS_Phone_Label';
import FEC_Points_Redemption_Confirm_Message from '@salesforce/label/c.FEC_Points_Redemption_Confirm_Message';
import FEC_Points_Redemption_Confirm_Title from '@salesforce/label/c.FEC_Points_Redemption_Confirm_Title';
import Loading from '@salesforce/label/c.Loading';
import { STR_EMPTY } from 'c/fec_CommonConst';

const LS_FAIL = 'fec-pr-fail-';
const LS_OK = 'fec-pr-ok-';
const MAX_FAIL = 3;
const VARIANT = { ERROR: 'error', SUCCESS: 'success', WARNING: 'warning' };

//linhdev fix jira FECREDIT_CSM_2025_KH-1393
function isPointsRedemptionHideC360AndProperty(subCode) {
    if (!subCode) {
        return false;
    }
    const s = String(subCode).trim().toUpperCase();
    return s.includes('RC33.01') || s.includes('RC33.02') || s.includes('RC33.03');
}

export default class Fec_PointsRedemptionCaseForm extends NavigationMixin(LightningElement) {
    @api recordId;
    @api subCodeCode;
    @api isEdit;

    @track loading = false;
    @track showPanel = false;
    @track notEligibleMessage;
    @track notEligibleReason;
    @track cmsPhone = STR_EMPTY;
    @track tierOptionsUi = [];
    @track selectedTierJson;
    @track redeemDisabled = false;
    @track failCount = 0;

    _lastSub = STR_EMPTY;

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
        this._lastSub = (this.subCodeCode || STR_EMPTY).trim();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1393
        this._notifyPointsRedemptionSectionVisibility();
        this.refreshInit();
    }

    renderedCallback() {
        const sub = (this.subCodeCode || STR_EMPTY).trim();
        if (this.recordId && sub !== this._lastSub) {
            this._lastSub = sub;
            //linhdev fix jira FECREDIT_CSM_2025_KH-1393
            this._notifyPointsRedemptionSectionVisibility();
            this.refreshInit();
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393
    _notifyPointsRedemptionSectionVisibility() {
        this.dispatchEvent(
            new CustomEvent('fecpointsredemptionsectionvisibility', {
                bubbles: true,
                composed: true,
                detail: {
                    hideC360AndProperty: isPointsRedemptionHideC360AndProperty(this.subCodeCode)
                }
            })
        );
    }

    restoreLocalState() {
        try {
            if (this.lsOkKey && window.localStorage.getItem(this.lsOkKey) === '1') {
                this.redeemDisabled = true;
            }
            if (this.lsFailKey) {
                const n = parseInt(window.localStorage.getItem(this.lsFailKey) || '0', 10);
                this.failCount = isNaN(n) ? 0 : n;
                if (this.failCount >= MAX_FAIL) {
                    this.redeemDisabled = true;
                }
            }
        } catch (e) {
            // no-op
        }
    }

    refreshInit() {
        if (!this.recordId) {
            return;
        }
        this.loading = true;
        initData({ caseId: this.recordId, subCodeCode: this.subCodeCode || null })
            .then((r) => {
                this.showPanel = !!(r && r.showRedemptionUi);
                this.notEligibleMessage = r && r.notEligibleMessage ? r.notEligibleMessage : null;
                this.notEligibleReason = r && r.notEligibleReason ? r.notEligibleReason : null;
                this.cmsPhone = r && r.cmsPhone ? r.cmsPhone : STR_EMPTY;
                const opts = (r && r.tierOptions) || [];
                this.tierOptionsUi = opts.map((o) => ({
                    label: o.label,
                    value: o.valueJson
                }));
                this.selectedTierJson = null;
            })
            .catch((err) => {
                this.showPanel = false;
                this.toast(FEC_Toast_Error, this.msg(err), VARIANT.ERROR);
            })
            .finally(() => {
                this.loading = false;
            });
    }

    handleTierChange(e) {
        this.selectedTierJson = e.detail.value;
    }

    async handleRedeemClick() {
        if (this.isReadOnly || this.redeemDisabled) {
            return;
        }
        if (!this.selectedTierJson) {
            this.toast(FEC_Toast_Validation_Title, FEC_Complete_This_Field, VARIANT.WARNING);
            return;
        }
        const ok = await LightningConfirm.open({
            message: FEC_Points_Redemption_Confirm_Message,
            variant: 'header',
            label: FEC_Points_Redemption_Confirm_Title,
            theme: 'default'
        });
        if (!ok) {
            return;
        }
        this.loading = true;
        redeem({ caseId: this.recordId, tierJson: this.selectedTierJson, subCodeCode: this.subCodeCode || null })
            .then((res) => {
                if (res && res.success) {
                    this.persistOk();
                    this.redeemDisabled = true;
                    this.toast(FEC_Success_Title, FEC_Points_Redeem_Success_Message, VARIANT.SUCCESS);
                    this.navigateCase();
                } else {
                    this.onRedeemFail(res && res.errorMessage ? res.errorMessage : FEC_Toast_Error);
                }
            })
            .catch((err) => {
                this.onRedeemFail(this.msg(err));
            })
            .finally(() => {
                this.loading = false;
            });
    }

    onRedeemFail(message) {
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
            this.toast(FEC_Toast_Error, FEC_Points_Redeem_Fail_After_Max.replace('{0}', String(MAX_FAIL)) + message, VARIANT.ERROR);
            this.navigateCase();
        } else {
            this.toast(FEC_Toast_Error, FEC_Points_Redeem_Fail_Prefix + message, VARIANT.ERROR);
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

    @api saveDraftIfApplicable() {
        if (this.isReadOnly || !this.showPanel || !this.selectedTierJson) {
            return Promise.resolve();
        }
        return saveDraftSelection({ caseId: this.recordId, tierJson: this.selectedTierJson, subCodeCode: this.subCodeCode || null });
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
}