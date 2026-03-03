import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import unfollowCase from '@salesforce/apex/FEC_FollowUpController.unfollowCase';
import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_MSG_FollowUp_Case_ID_Not_Found from '@salesforce/label/c.FEC_MSG_FollowUp_Case_ID_Not_Found';
import FEC_MSG_FollowUp_Unfollow_Success from '@salesforce/label/c.FEC_MSG_FollowUp_Unfollow_Success';
import FEC_MSG_FollowUp_Error_Detail from '@salesforce/label/c.FEC_MSG_FollowUp_Error_Detail';
import FEC_MSG_FollowUp_Unfollow_Error from '@salesforce/label/c.FEC_MSG_FollowUp_Unfollow_Error';

export default class FecCaseUnfollowHeadlessAction extends LightningElement {
    @api recordId;

    // Headless Action - invoke() được gọi khi click button
    // Unfollow trực tiếp KHÔNG cần popup xác nhận
    @api
    invoke() {
        if (!this.recordId) {
            this.showToast(FEC_Error_Title, FEC_MSG_FollowUp_Case_ID_Not_Found, 'error');
            return;
        }

        // Unfollow ngay lập tức
        unfollowCase({ caseId: this.recordId })
            .then(() => {
                // Notify LDS to refresh record
                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.showToast(FEC_Success_Title, FEC_MSG_FollowUp_Unfollow_Success, 'success');
            })
            .catch(error => {
                const errorMsg = error.body?.message || error.message || FEC_MSG_FollowUp_Unfollow_Error;
                this.showToast(FEC_Error_Title, FEC_MSG_FollowUp_Error_Detail.replace('{0}', errorMsg), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        }));
    }
}