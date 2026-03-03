import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import unfollowCase from '@salesforce/apex/FEC_FollowUpController.unfollowCase';
import ACTION_CANCEL from '@salesforce/label/c.FEC_ACTION_CANCEL';
import ACTION_UNFOLLOW from '@salesforce/label/c.FEC_ACTION_UNFOLLOW';
import LABEL_CURRENT_FOLLOW_TYPE from '@salesforce/label/c.FEC_LABEL_CURRENT_FOLLOW_TYPE';
import LABEL_CASE_STATUS from '@salesforce/label/c.FEC_LABEL_CASE_STATUS';
import MSG_CONFIRM_UNFOLLOW from '@salesforce/label/c.FEC_MSG_CONFIRM_UNFOLLOW';
import MSG_UNFOLLOW_INFO from '@salesforce/label/c.FEC_MSG_UNFOLLOW_INFO';


export default class FecCaseUnfollowHeadlessAction extends LightningElement {
    @api recordId;
    @api followTypeLabel;          // value displayed in template

    // internal state for modal
    showModal = false;
    isLoading = false;
    caseInfo;                      // optional object with case information

    // expose JS-side custom labels for template convenience
    get customLabels() {
        return {
            followTypeLabel: this.followTypeLabel,
            caseStatus: this.caseInfo ? this.caseInfo.caseStatus : '',
            confirmUnfollow: MSG_CONFIRM_UNFOLLOW,
            unfollowInfo: MSG_UNFOLLOW_INFO
        };
    }

    // Headless Action - invoke() được gọi khi click button
    // accepts optional data object with properties passed from caller
    // e.g. { caseInfo: {...}, followTypeLabel: 'Until Resolved' }
    @api
    invoke(data) {
        if (!this.recordId) {
            this.showToast('Error', 'Case ID not found', 'error');
            return;
        }
        if (data) {
            if (data.caseInfo) {
                this.caseInfo = data.caseInfo;
            }
            if (data.followTypeLabel) {
                this.followTypeLabel = data.followTypeLabel;
            }
        }
        // show confirmation modal instead of immediate unfollow
        this.showModal = true;
    }

    handleCancel() {
        this.showModal = false;
    }

    handleConfirm() {
        this.isLoading = true;
        unfollowCase({ caseId: this.recordId })
            .then(result => {
                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.showToast('Success', result || 'Unfollowed Case successfully', 'success');
                this.showModal = false;
            })
            .catch(error => {
                const errorMsg = error.body?.message || error.message || 'An error occurred while unfollowing';
                this.showToast('Error', errorMsg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        // allow passing label values too
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        }));
    }
}