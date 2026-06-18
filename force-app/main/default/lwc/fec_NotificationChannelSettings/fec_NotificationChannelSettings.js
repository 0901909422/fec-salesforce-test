import { LightningElement, api, track } from 'lwc';
import FEC_Notification_Channel_Settings from '@salesforce/label/c.FEC_Notification_Channel_Settings';
import FEC_Notification_Channel_Settings_Description from '@salesforce/label/c.FEC_Notification_Channel_Settings_Description';
import FEC_Notification_Channel_Settings_Loading from '@salesforce/label/c.FEC_Notification_Channel_Settings_Loading';
import FEC_Notification_Channel_Settings_Disable from '@salesforce/label/c.FEC_Notification_Channel_Settings_Disable';
import FEC_Button_Submit from '@salesforce/label/c.FEC_Button_Submit';
import FEC_Cancel from '@salesforce/label/c.FEC_Cancel';
import FEC_Disabled from '@salesforce/label/c.FEC_Disabled';
import FEC_Enabled from '@salesforce/label/c.FEC_Enabled';

const CHANNEL_ICONS = {
    'Email'      : 'utility:email',
    'SMS'        : 'utility:sms',
    'ZNS'        : 'utility:connected_apps',
    'Mobile App' : 'utility:apps',
};

export default class Fec_NotificationChannelSettings extends LightningElement {

    labels = {
        FEC_Notification_Channel_Settings,
        FEC_Notification_Channel_Settings_Description,
        FEC_Notification_Channel_Settings_Loading,
        FEC_Notification_Channel_Settings_Disable,
        FEC_Button_Submit,
        FEC_Cancel,
        FEC_Disabled,
        FEC_Enabled
    }

    @api isLoading = false;

    _channels = [];
    @track localChannels   = [];
    @track pendingChanges  = {};

    @api get channels() { return this._channels; }
    set channels(val) {
        this._channels = val || [];
        this.initLocal();
    }

    initLocal() {
        this.localChannels = this._channels.map(ch => this.enrichChannel(ch));
        this.pendingChanges = {};
    }

    enrichChannel(ch) {
        const icon    = CHANNEL_ICONS[ch.Name] || 'utility:notification';
        const enabled = !!ch.FEC_Noti_Channel_Status__c;
        return {
            ...ch,
            icon        : icon,
            iconClass   : enabled ? 'icon-enabled' : 'icon-disabled',
            cardClass   : enabled ? 'channel-card' : 'channel-card channel-card_disabled',
            statusLabel : enabled ? 'Enabled' : 'Disabled',
        };
    }

    handleToggle(evt) {
        const id     = evt.currentTarget.dataset.id;
        const status = evt.detail.checked;
        this.pendingChanges = { ...this.pendingChanges, [id]: status };
        this.localChannels = this.localChannels.map(ch => {
            if (ch.Id !== id) return ch;
            return this.enrichChannel({ ...ch, FEC_Noti_Channel_Status__c: status });
        });
    }

    handleSubmit() {
        Object.entries(this.pendingChanges).forEach(([channelId, newStatus]) => {
            this.dispatchEvent(new CustomEvent('channelupdate', {
                detail: { channelId, newStatus }, bubbles: true, composed: true
            }));
        });
        this.pendingChanges = {};
    }

    handleCancel() {
        this.initLocal();
    }

    get hasNoPendingChanges() {
        return Object.keys(this.pendingChanges).length === 0;
    }
}