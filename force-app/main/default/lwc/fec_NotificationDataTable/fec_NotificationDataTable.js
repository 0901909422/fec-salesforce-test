import { LightningElement, api, track } from 'lwc';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Notification_History_Col_Notification_Type from '@salesforce/label/c.FEC_Notification_History_Col_Notification_Type';
import FEC_Col_Channel from '@salesforce/label/c.FEC_Col_Channel';
import FEC_Label_Product_Type from '@salesforce/label/c.FEC_Label_Product_Type';
import FEC_Label_Category from '@salesforce/label/c.FEC_Label_Category';
import FEC_Label_Sub_Category from '@salesforce/label/c.FEC_Label_Sub_Category';
import FEC_Label_Sub_Code from '@salesforce/label/c.FEC_Label_Sub_Code';
import FEC_Notification_Channel from '@salesforce/label/c.FEC_Notification_Channel';
import FEC_Col_Status from '@salesforce/label/c.FEC_Col_Status';
import FEC_Child_Actions from '@salesforce/label/c.FEC_Child_Actions';
import FEC_Btn_History from '@salesforce/label/c.FEC_Btn_History';
import FEC_Edit from '@salesforce/label/c.FEC_Edit';
import FEC_Delete_Button from '@salesforce/label/c.FEC_Delete_Button';
import FEC_Col_Template_Name from '@salesforce/label/c.FEC_Col_Template_Name';
import FEC_Confirm_Delete_Title from '@salesforce/label/c.FEC_Confirm_Delete_Title';
import FEC_Btn_Cancel from '@salesforce/label/c.FEC_Btn_Cancel';
import FEC_Button_Delete from '@salesforce/label/c.FEC_Button_Delete';
import FEC_No_Notifications_Msg from '@salesforce/label/c.FEC_No_Notifications_Msg';
import FEC_Template_Details from '@salesforce/label/c.FEC_Template_Details';
import FEC_Template_Active from '@salesforce/label/c.FEC_Template_Active';
import FEC_No_Templates_Linked from '@salesforce/label/c.FEC_No_Templates_Linked';
import FEC_Delete_Notification_Confirm from '@salesforce/label/c.FEC_Delete_Notification_Confirm';

export default class Fec_NotificationDataTable extends LightningElement {

    labels = {
        FEC_Termination_Loading_Alt,
        FEC_Notification_History_Col_Notification_Type,
        FEC_Col_Channel,
        FEC_Label_Product_Type,
        FEC_Label_Category,
        FEC_Label_Sub_Category,
        FEC_Label_Sub_Code,
        FEC_Notification_Channel,
        FEC_Col_Status,
        FEC_Child_Actions,
        FEC_Btn_History,
        FEC_Edit,
        FEC_Delete_Button,
        FEC_Col_Template_Name,
        FEC_Confirm_Delete_Title,
        FEC_Btn_Cancel,
        FEC_Button_Delete,
        FEC_Template_Details,
        FEC_No_Notifications_Msg,
        FEC_Template_Active,
        FEC_No_Templates_Linked,
        FEC_Delete_Notification_Confirm
    }

    @api records    = [];
    @api channels   = [];
    @api isLoading  = false;
    @api tabType    = 'auto';

    @track expandedRows     = new Set();
    @track showDeleteConfirm = false;
    pendingDeleteId          = null;

    // ── Computed ───────────────────────────────────────────────────────────
    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    get enrichedRecords() {
        return (this.records || []).map(r => {
            const isExpanded = this.expandedRows.has(r.Id);

            // Build channel badges with disabled-channel warning
            const channelIds = (r.Notification_Template_Channel__r || []).map(item => item.FEC_Notification_Channel__r?.Id).filter(Boolean);
            //const channelIds    = (r.FEC_Channel__c || '').split(',').map(s => s.trim()).filter(Boolean);
            const channelBadges = channelIds.map(id => {
                const ch = (this.channels || []).find(c => c.Id === id);
                const isDisabled = ch && !ch.FEC_Noti_Channel_Status__c;
                return {
                    id           : id,
                    name         : ch ? ch.Name : id,
                    isDisabled,
                    badgeClass   : isDisabled ? 'channel-badge channel-badge_disabled' : 'channel-badge',
                    disabledTitle: isDisabled ? `Channel "${ch.Name}" is disabled` : ''
                };
            });

            // Build template/channel lines from junction object
            const templateChannels = (r.Notification_Template_Channel__r || []).map(tc => ({
                Id            : tc.Id,
                channelName   : tc.FEC_Notification_Channel__r
                                    ? tc.FEC_Notification_Channel__r.Name : '—',
                warningChannel : (tc.FEC_Notification_Channel__r && tc.FEC_Notification_Channel__r.FEC_Noti_Channel_Status__c) 
                                    ? false : true,
                templateName  : tc.FEC_Notification_Template__r
                                    ? tc.FEC_Notification_Template__r.Name : '—',
                apiName       : tc.FEC_Notification_Template__r
                                    ? tc.FEC_Notification_Template__r.FEC_API_Name__c : '—',
                subject       : tc.FEC_Notification_Template__r
                                    ? tc.FEC_Notification_Template__r.FEC_Subject_Line__c : '—',
                activeIcon    : (tc.FEC_Notification_Template__r && tc.FEC_Notification_Template__r.FEC_Active__c)
                                    ? 'utility:check' : 'utility:close',
                activeVariant : (tc.FEC_Notification_Template__r && tc.FEC_Notification_Template__r.FEC_Active__c)
                                    ? 'success' : 'error',
                isZns         : tc.FEC_Notification_Template__r && tc.FEC_Notification_Template__r.FEC_Is_ZNS_Template__c,
                znsUrl        : tc.FEC_Notification_Template__r
                                    ? tc.FEC_Notification_Template__r.FEC_Preview_ZNS_Url__c : null,
            }));

            return {
                ...r,
                isExpanded,
                expandKey      : r.Id + '_expand',
                expandIcon     : isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                rowClass       : isExpanded ? 'data-row data-row_expanded' : 'data-row',
                channelBadges,
                templateChannels,
                hasTemplates   : templateChannels.length > 0,
                FEC_Product_Type_Name__c : r.FEC_Product_Type__r ? r.FEC_Product_Type__r.Name : '—',
                FEC_Category_Name__c     : r.FEC_Category__r     ? r.FEC_Category__r.Name     : '—',
            };
        });
    }

    // ── Expand / Collapse ──────────────────────────────────────────────────
    toggleExpand(evt) {
        const id  = evt.currentTarget.dataset.id;
        const set = new Set(this.expandedRows);
        if (set.has(id)) { set.delete(id); } else { set.add(id); }
        this.expandedRows = set;
    }

    // ── Status Toggle ──────────────────────────────────────────────────────
    handleStatusChange(evt) {
        const recordId = evt.currentTarget.dataset.id;
        const newStatus = evt.detail.checked;
        this.dispatchEvent(new CustomEvent('statustoggle', {
            detail: { recordId, newStatus }, bubbles: true, composed: true
        }));
    }

    // ── Actions ────────────────────────────────────────────────────────────
    handleEdit(evt) {
        this.dispatchEvent(new CustomEvent('rowedit', {
            detail: { recordId: evt.currentTarget.dataset.id }, bubbles: true, composed: true
        }));
    }

    handleHistory(evt) {
        this.dispatchEvent(new CustomEvent('rowhistory', {
            detail: { recordId: evt.currentTarget.dataset.id }, bubbles: true, composed: true
        }));
    }

    handleDelete(evt) {
        this.pendingDeleteId   = evt.currentTarget.dataset.id;
        this.showDeleteConfirm = true;
    }

    cancelDelete() {
        this.showDeleteConfirm = false;
        this.pendingDeleteId   = null;
    }

    confirmDelete() {
        this.showDeleteConfirm = false;
        this.dispatchEvent(new CustomEvent('rowdelete', {
            detail: { recordId: this.pendingDeleteId }, bubbles: true, composed: true
        }));
        this.pendingDeleteId = null;
    }
}