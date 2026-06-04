import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';

import syncDataToMDM from '@salesforce/apex/FEC_CleanUpMasterDataController.syncDataToMDM';
import pushMDMToLive from '@salesforce/apex/FEC_CleanUpMasterDataController.pushMDMToLive';
import getRecentBatchLogs from '@salesforce/apex/FEC_CleanUpMasterDataController.getRecentBatchLogs';

import LABEL_RESET_MDM from '@salesforce/label/c.FEC_Reset_MDM';
import LABEL_PUSH_MDM from '@salesforce/label/c.FEC_Push_MDM_To_Live';
import LABEL_REFRESH from '@salesforce/label/c.FEC_Refresh_Data';
import LABEL_CONFIRM_SYNC from '@salesforce/label/c.FEC_Confirm_Sync_Question';
import LABEL_NOTIFY_SYNC_STARTED from '@salesforce/label/c.FEC_Notify_Sync_Started';
import LABEL_CONFIRM_PUSH from '@salesforce/label/c.FEC_Confirm_Push_Question';
import LABEL_NOTIFY_PUSH_STARTED from '@salesforce/label/c.FEC_Notify_Push_Started';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_TOAST_REFRESH_SUCCESS from '@salesforce/label/c.FEC_Toast_Refresh_Success';
import LABEL_TOAST_REFRESH_ERROR from '@salesforce/label/c.FEC_Toast_Refresh_Error';
import LABEL_TITLE from '@salesforce/label/c.FEC_Tab_Sync_Operations';
import LABEL_SECTION_ACTIONS from '@salesforce/label/c.FEC_Section_Sync_Actions';
import LABEL_SECTION_LOG from '@salesforce/label/c.FEC_Section_Batch_Log';
import LABEL_COL_BATCH_NAME from '@salesforce/label/c.FEC_Col_Batch_Name';
import LABEL_COL_JOB_ID from '@salesforce/label/c.FEC_Col_Job_ID';
import LABEL_COL_STATUS from '@salesforce/label/c.FEC_Col_Status';
import LABEL_COL_TOTAL_ITEMS from '@salesforce/label/c.FEC_Col_Total_Items';
import LABEL_COL_PROCESSED_ITEMS from '@salesforce/label/c.FEC_Col_Processed_Items';
import LABEL_COL_ERROR_COUNT from '@salesforce/label/c.FEC_Col_Error_Count';
import LABEL_COL_CREATED_DATE from '@salesforce/label/c.FEC_Col_Created_Date';
import LABEL_NO_BATCH_LOGS from '@salesforce/label/c.FEC_No_Batch_Logs';

import { VARIANT_SUCCESS, VARIANT_ERROR, VARIANT_INFO } from 'c/fecConstants';

const STATUS_SUCCESS = 'Success';
const STATUS_FAILED = 'Failed';

export default class FecMdmSyncOperations extends LightningElement {
    labelTitle = LABEL_TITLE;
    labelRefresh = LABEL_REFRESH;
    labelReset = LABEL_RESET_MDM;
    labelPush = LABEL_PUSH_MDM;
    labelSectionActions = LABEL_SECTION_ACTIONS;
    labelSectionLog = LABEL_SECTION_LOG;
    labelNoBatchLogs = LABEL_NO_BATCH_LOGS;

    @track batchLogs = [];
    @track isSyncing = false;
    @track isPushing = false;
    wiredBatchLogResult;

    columnsBatchLog = [
        { label: LABEL_COL_BATCH_NAME, fieldName: 'FEC_Batch_Name__c' },
        { label: LABEL_COL_JOB_ID, fieldName: 'FEC_Job_ID__c' },
        {
            label: LABEL_COL_STATUS,
            fieldName: 'FEC_Status__c',
            cellAttributes: { class: { fieldName: '_statusClass' } }
        },
        { label: LABEL_COL_TOTAL_ITEMS, fieldName: 'FEC_Total_Job_Items__c', type: 'number' },
        { label: LABEL_COL_PROCESSED_ITEMS, fieldName: 'FEC_Processed_Items__c', type: 'number' },
        { label: LABEL_COL_ERROR_COUNT, fieldName: 'FEC_Error_Count__c', type: 'number' },
        {
            label: LABEL_COL_CREATED_DATE,
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric', month: 'short', day: '2-digit',
                hour: '2-digit', minute: '2-digit', second: '2-digit'
            }
        }
    ];

    @wire(getRecentBatchLogs, { limitSize: 50 })
    wiredBatchLogs(result) {
        this.wiredBatchLogResult = result;
        const { error, data } = result;
        if (data) {
            this.batchLogs = data.map(row => ({
                ...row,
                _statusClass: row.FEC_Status__c === STATUS_SUCCESS
                    ? 'slds-text-color_success'
                    : (row.FEC_Status__c === STATUS_FAILED ? 'slds-text-color_error' : 'slds-text-color_weak')
            }));
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('getRecentBatchLogs error', error);
        }
    }

    get hasBatchLogs() {
        return Array.isArray(this.batchLogs) && this.batchLogs.length > 0;
    }

    get isBusy() {
        return this.isSyncing || this.isPushing;
    }

    async handleSyncDataToMDM() {
        const confirmed = await LightningConfirm.open({
            message: LABEL_CONFIRM_SYNC,
            label: this.labelReset,
            theme: 'warning'
        });
        if (!confirmed) return;

        this.isSyncing = true;
        try {
            await syncDataToMDM();
            this.showToast(LABEL_NOTIFY_SYNC_STARTED, '', VARIANT_INFO);
            await refreshApex(this.wiredBatchLogResult);
        } catch (error) {
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message || 'Unknown error', VARIANT_ERROR);
        } finally {
            this.isSyncing = false;
        }
    }

    async handlePushToLive() {
        const confirmed = await LightningConfirm.open({
            message: LABEL_CONFIRM_PUSH,
            label: this.labelPush,
            theme: 'warning'
        });
        if (!confirmed) return;

        this.isPushing = true;
        try {
            await pushMDMToLive();
            this.showToast(LABEL_NOTIFY_PUSH_STARTED, '', VARIANT_SUCCESS);
            await refreshApex(this.wiredBatchLogResult);
        } catch (error) {
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message || 'Unknown error', VARIANT_ERROR);
        } finally {
            this.isPushing = false;
        }
    }

    async handleRefreshBatchLogs() {
        try {
            await refreshApex(this.wiredBatchLogResult);
            this.showToast(LABEL_TOAST_REFRESH_SUCCESS, '', VARIANT_SUCCESS);
        } catch (error) {
            this.showToast(LABEL_TOAST_REFRESH_ERROR, error.body?.message || error.message || 'Unknown error', VARIANT_ERROR);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}