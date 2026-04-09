import { LightningElement, api, track } from 'lwc';
import getCustomHistoryLog from '@salesforce/apex/CustomLog.getCustomHistoryLog';
import { customLabels } from 'c/fec_ResourceHelper';

export default class Fec_CustomHistoryLog extends LightningElement {
    customLabels = customLabels;
    // Public API to accept the target record Id from parent
    @api targetId;

    @track dataLogs = [];
    isExpanded = false;
    isLoading = false;
    hasError = false;
    errorMessage = '';

    // Define datatable columns
    // Use field names that match the normalized row properties below
    columns = [
        { label: this.customLabels.CS_OrgChart_Table_HistoryLog_ModifiedOn_Column, fieldName: 'LogCreatedDate', type: 'date', typeAttributes: {
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
        }},
        { label: this.customLabels.CS_OrgChart_Table_HistoryLog_ModifiedBy_Column, fieldName: 'LogCreatedByEmail', type: 'email' },
        { label: this.customLabels.CS_OrgChart_Table_HistoryLog_Action_Column, fieldName: 'LogActionName', type: 'text' },
        { label: this.customLabels.CS_OrgChart_Table_HistoryLog_OldValue_Column, fieldName: 'LogMessage', type: 'text' },
        { label: this.customLabels.CS_OrgChart_Table_HistoryLog_NewValue_Column, fieldName: 'LogResponse', type: 'text' }
    ];

    get expandLabel() {
        return this.isExpanded ? this.customLabels.CS_OrgChart_Btn_HistoryLog_Hide : this.customLabels.CS_OrgChart_Btn_HistoryLog_View;
    }

    async handleExpandClick() {
        // Toggle expanded; on expand, fetch if not yet loaded
        if (!this.isExpanded) {
            this.loadHistory();
        }
        this.isExpanded = !this.isExpanded;
    }

    // Expose loadHistory so parent can call it
    // Load history from Apex and normalize fields for lightning-datatable
    @api
    async loadHistory(teamId) {
        if (teamId) {
            this.targetId = teamId;
        }
        if (!this.targetId) {
            this.hasError = true;
            this.errorMessage = this.customLabels.CS_OrgChart_Text_HistoryLog_Require_Select_Object;
            return;
        }
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';
        try {
            const historyLogs = await getCustomHistoryLog({ targetId: this.targetId });
            // Map Apex HistoryLog -> UI fields used by columns
            this.dataLogs = (historyLogs || []).map(log => ({
                Id: log.Id, // keep Id for key-field
                LogCreatedDate: log.createdDate,
                LogCreatedByEmail: log.createdByEmail,
                LogActionName: log.logActionName,
                LogMessage: log.logMessage,
                LogResponse: log.logResponse
            }));
        } catch (e) {
            this.hasError = true;
            this.errorMessage = (e && e.body && e.body.message) ? e.body.message : (e && e.message) ? e.message : 'Unknown error';
        } finally {
            this.isLoading = false;
        }
    }
}