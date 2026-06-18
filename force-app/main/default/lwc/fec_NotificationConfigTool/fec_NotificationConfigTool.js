import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getNotifications       from '@salesforce/apex/FEC_NotificationConfigController.getNotifications';
import getNotificationChannels  from '@salesforce/apex/FEC_NotificationConfigController.getNotificationChannels';
import deleteNotification     from '@salesforce/apex/FEC_NotificationConfigController.deleteNotification';
import toggleNotificationStatus from '@salesforce/apex/FEC_NotificationConfigController.toggleNotificationStatus';
import updateChannelStatus    from '@salesforce/apex/FEC_NotificationConfigController.updateChannelStatus';
import getHistoryLogs         from '@salesforce/apex/FEC_NotificationConfigController.getHistoryLogs';
import exportNotifications    from '@salesforce/apex/FEC_NotificationConfigController.exportNotifications';
import FEC_Notification_Management_Tool from '@salesforce/label/c.FEC_Notification_Management_Tool';
import FEC_Auto_Notifications from '@salesforce/label/c.FEC_Auto_Notifications';
import FEC_Export from '@salesforce/label/c.FEC_Export';
import FEC_Add_Auto_Notification from '@salesforce/label/c.FEC_Add_Auto_Notification';
import FEC_Manual_Notifications from '@salesforce/label/c.FEC_Manual_Notifications';
import FEC_Add_Manual_Notification from '@salesforce/label/c.FEC_Add_Manual_Notification';
import FEC_Configuration_History from '@salesforce/label/c.FEC_Configuration_History';
import FEC_No_History_Records from '@salesforce/label/c.FEC_No_History_Records';
import FEC_Notification_Channel_Settings from '@salesforce/label/c.FEC_Notification_Channel_Settings';
import FEC_Btn_Close from '@salesforce/label/c.FEC_Btn_Close';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Notification_Saved_Successfully from '@salesforce/label/c.FEC_Notification_Saved_Successfully';
import FEC_Notification_Deleted from '@salesforce/label/c.FEC_Notification_Deleted';
import FEC_Channel_Status_Updated from '@salesforce/label/c.FEC_Channel_Status_Updated';

const HISTORY_COLUMNS = [
    {
        type: 'button-icon',
        fixedWidth: 40,
        typeAttributes: {
            iconName: { fieldName: 'expandIcon' },
            variant: 'bare',
            name: 'toggle',
            alternativeText: 'Expand'
        }
    },
    {
        label: 'Modified On',
        fieldName: 'changedDate',
        type: 'date',
        initialWidth: 180,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        label: 'Action',
        fieldName: 'action',
        type: 'text',
        initialWidth: 120
    },
    {
        label: 'Modified By',
        fieldName: 'changedBy',
        type: 'text',
        initialWidth: 250
    },
    {
        label: '# Fields',
        fieldName: 'changeCount',
        type: 'number',
        initialWidth: 100
    },
    {
        label: 'Field',
        fieldName: 'fieldLabel',
        type: 'text',
        initialWidth: 300,
        wrapText: true
    },
    {
        label: 'Old Value',
        fieldName: 'oldValue',
        type: 'text',
        initialWidth: 250,
        wrapText: true
    },
    {
        label: 'New Value',
        fieldName: 'newValue',
        type: 'text',
        initialWidth: 250,
        wrapText: true
    }
];

export default class Fec_NotificationConfigTool extends LightningElement {

    labels = {
        FEC_Notification_Management_Tool,
        FEC_Auto_Notifications,
        FEC_Export,
        FEC_Add_Auto_Notification,
        FEC_Manual_Notifications,
        FEC_Add_Manual_Notification,
        FEC_Configuration_History,
        FEC_No_History_Records,
        FEC_Notification_Channel_Settings,
        FEC_Btn_Close,
        FEC_Termination_Loading_Alt,
        FEC_Notification_Saved_Successfully,
        FEC_Notification_Deleted,
        FEC_Channel_Status_Updated
    }

    // ── State ──────────────────────────────────────────────────────────────
    @track isLoading        = true;
    @track activeTab        = 'auto';

    @track autoNotifications   = [];
    @track manualNotifications = [];
    @track channels            = [];

    // Modal
    @track isModalOpen       = false;
    @track modalMode         = 'create';   // 'create' | 'edit'
    @track selectedRecordId  = null;

    // History
    @track isHistoryOpen     = false;
    @track historyLoading    = false;
    @track historyRecords    = [];
    historyColumns           = HISTORY_COLUMNS;

    // Toast
    @track toastVisible  = false;
    @track toastMessage  = '';
    @track toastVariant  = 'success';
    toastTimer           = null;

    // ── Lifecycle ──────────────────────────────────────────────────────────
    connectedCallback() {
        this.initPage();
    }

    async initPage() {
        try {
            this.isLoading = true;
            await Promise.all([this.loadNotifications(), this.loadChannels()]);
        } catch (e) {
            this.showToast('error', this.reduceError(e));
        } finally {
            this.isLoading = false;
        }
    }

    async loadNotifications() {
        const all = await getNotifications();
        this.autoNotifications   = all.filter(n => n.RecordType.Name === 'Auto Notification');
        this.manualNotifications = all.filter(n => n.RecordType.Name === 'Manual Notification');
    }

    async loadChannels() {
        this.channels = await getNotificationChannels();
    }

    // ── Tab ────────────────────────────────────────────────────────────────
    handleTabChange(evt) {
        this.activeTab = evt.target.value;
    }

    // ── Add / Edit ─────────────────────────────────────────────────────────
    handleAddNew(evt) {
        this.activeTab       = evt.currentTarget.dataset.tab;
        this.modalMode       = 'create';
        this.selectedRecordId = null;
        this.isModalOpen     = true;
    }

    handleRowEdit(evt) {
        this.selectedRecordId = evt.detail.recordId;
        this.modalMode        = 'edit';
        this.isModalOpen      = true;
    }

    handleModalClose() {
        this.isModalOpen      = false;
        this.selectedRecordId = null;
    }

    async handleModalSave() {
        this.isModalOpen = false;
        this.showToast('success', this.labels.FEC_Notification_Saved_Successfully);
        await this.loadNotifications();
    }

    // ── Delete ─────────────────────────────────────────────────────────────
    async handleRowDelete(evt) {
        const id = evt.detail.recordId;
        try {
            this.isLoading = true;
            await deleteNotification({ notificationId: id });
            this.showToast('success', this.labels.FEC_Notification_Deleted);
            await this.loadNotifications();
        } catch (e) {
            this.showToast('error', this.reduceError(e));
        } finally {
            this.isLoading = false;
        }
    }

    // ── Status Toggle ──────────────────────────────────────────────────────
    async handleStatusToggle(evt) {
        const { recordId, newStatus } = evt.detail;
        try {
            await toggleNotificationStatus({ notificationId: recordId, newStatus });
            await this.loadNotifications();
        } catch (e) {
            this.showToast('error', this.reduceError(e));
        }
    }

    // ── Channel Update ─────────────────────────────────────────────────────
    async handleChannelUpdate(evt) {
        const { channelId, newStatus } = evt.detail;
        try {
            await updateChannelStatus({ channelId, newStatus });
            this.showToast('success', this.labels.FEC_Channel_Status_Updated);
            await Promise.all([this.loadChannels(), this.loadNotifications()]);
        } catch (e) {
            this.showToast('error', this.reduceError(e));
        }
    }

    // ── History ────────────────────────────────────────────────────────────
    async handleRowHistory(evt) {
        this.isHistoryOpen  = true;
        this.historyLoading = true;
        this.historyRecords = [];
        try {
            this.rawHistoryTransactions = await getHistoryLogs({ notificationId: evt.detail.recordId });
            this.buildHistoryRows();
        } catch (e) {
            this.showToast('error', this.reduceError(e));
        } finally {
            this.historyLoading = false;
        }
    }

    closeHistory() {
        this.isHistoryOpen  = false;
        this.historyRecords = [];
    }

    // ── Export ─────────────────────────────────────────────────────────────
    async handleExport(evt) {
        const tabType = evt.currentTarget.dataset.tab;
        try {
            const base64 = await exportNotifications({ tabType });
            const link   = document.createElement('a');
            link.href    = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,' + base64;
            link.download = `${tabType}_notifications.csv`;
            link.click();
        } catch (e) {
            this.showToast('error', this.reduceError(e));
        }
    }

    // ── Toast ──────────────────────────────────────────────────────────────
    showToast(variant, message) {
        if (this.toastTimer) { clearTimeout(this.toastTimer); }
        this.toastVariant = variant;
        this.toastMessage = message;
        this.toastVisible = true;
        this.toastTimer   = setTimeout(() => { this.toastVisible = false; }, 4000);
    }

    closeToast() {
        this.toastVisible = false;
    }

    get toastClass() {
        return `slds-notify slds-notify_toast slds-theme_${this.toastVariant} custom-toast`;
    }

    get toastIcon() {
        const icons = { success: 'utility:success', error: 'utility:error',
                        warning: 'utility:warning', info: 'utility:info' };
        return icons[this.toastVariant] || 'utility:info';
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    reduceError(err) {
        if (typeof err === 'string') return err;
        if (err.body && err.body.message) return err.body.message;
        if (err.message) return err.message;
        return JSON.stringify(err);
    }

    // ── History ────────────────────────────────────────────────────────────
    rawHistoryTransactions = [];
    expandedRows = new Set();

    buildHistoryRows() {

        const rows = [];

        this.rawHistoryTransactions.forEach(txn => {

            rows.push({
                id: txn.id,
                rowType: 'transaction',

                expandIcon:
                    this.expandedRows.has(txn.id)
                        ? 'utility:chevrondown'
                        : 'utility:chevronright',

                changedDate: txn.changedDate,
                action: txn.action,
                changedBy: txn.changedBy,
                changeCount: txn.changeCount,

                fieldLabel: '',
                oldValue: '',
                newValue: ''
            });

            if (this.expandedRows.has(txn.id)) {

                txn.changes.forEach((c, idx) => {

                    rows.push({
                        id: `${txn.id}_${idx}`,

                        rowType: 'detail',

                        expandIcon: '',

                        changedDate: null,
                        action: '',
                        changedBy: '',
                        changeCount: '',

                        fieldLabel: c.fieldLabel,
                        oldValue: c.oldValue,
                        newValue: c.newValue
                    });
                });
            }
        });

        this.historyRecords = rows;
    }

    handleRowHistoryAction(event) {

        const row = event.detail.row;

        if (row.rowType !== 'transaction') {
            return;
        }

        if (this.expandedRows.has(row.id)) {
            this.expandedRows.delete(row.id);
        } else {
            this.expandedRows.add(row.id);
        }

        this.buildHistoryRows();
    }
}