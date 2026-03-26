import { LightningElement, api, track } from 'lwc';
import updateCaseApplicationHistory from '@salesforce/apex/FEC_GetLoanApplicationHistory.updateCaseApplicationHistory';
import { formatDate } from 'c/fec_CommonUtils';

import FEC_Application_History_Label from '@salesforce/label/c.FEC_Application_History_Label';
import FEC_User_Label from '@salesforce/label/c.FEC_User_Label';
import FEC_Activity_ID_Label from '@salesforce/label/c.FEC_Activity_ID_Label';
import FEC_Status_Label from '@salesforce/label/c.FEC_Status_Label';
import FEC_Edit_Date_Label from '@salesforce/label/c.FEC_Edit_Date_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';

export default class Fec_AppInfo extends LightningElement {
    @api recordId;
    @track histories = [];
    @track isLoading = false;
    @track errorText = '';

    activeSections = ['appHistory'];

    customLabel = {
        applicationHistoryLabel: FEC_Application_History_Label,
        userLabel: FEC_User_Label,
        activityIdLabel: FEC_Activity_ID_Label,
        statusLabel: FEC_Status_Label,
        editDateLabel: FEC_Edit_Date_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label
    };

    columns = [
        {
            label: this.customLabel.userLabel,
            fieldName: 'user',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: this.customLabel.activityIdLabel,
            fieldName: 'activityId',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: this.customLabel.statusLabel,
            fieldName: 'status',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: this.customLabel.editDateLabel,
            fieldName: 'editDate',
            type: 'text',
            cellAlign: 'center'
        }
    ];

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        if (!this.recordId) return;

        this.isLoading = true;

        updateCaseApplicationHistory({ caseId: this.recordId })
            .then(res => {
                if (res) {
                    this.histories = [this.mapHistory(res)];
                } else {
                    this.histories = [];
                }
                this.errorText = '';
            })
            .catch(err => {
                console.error('[FEC] updateCaseApplicationHistory error', err);
                this.histories = [];
                this.errorText = this.customLabel.msgErrorAPI;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    mapHistory(record) {
        return {
            Id: record.Id,
            user: record.FEC_User__c || '',
            activityId: record.FEC_Activity_ID__c || '',
            status: record.FEC_Status__c || '',
            editDate: formatDate(record.FEC_Edit_Date__c)
        };
    }
}