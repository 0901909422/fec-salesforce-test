// tungnm37: NOC Channel Config tab - multi-select Channel lookup
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import searchChannels from '@salesforce/apex/FEC_NocChannelConfigController.searchChannels';
import getChannelIds from '@salesforce/apex/FEC_NocChannelConfigController.getChannelIds';
import saveChannelIds from '@salesforce/apex/FEC_NocChannelConfigController.saveChannelIds';
import FEC_Toast_Success from '@salesforce/label/c.FEC_Toast_Success';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Channel_Config_Save_Success from '@salesforce/label/c.FEC_Channel_Config_Save_Success';
import FEC_Channel_Config_Save_Error from '@salesforce/label/c.FEC_Channel_Config_Save_Error';
import FEC_Search_Channel_Placeholder from '@salesforce/label/c.FEC_Search_Channel_Placeholder';
import FEC_No_Results from '@salesforce/label/c.FEC_No_Results';
import FEC_Button_Cancel from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';

export default class Fec_NocChannelConfig extends LightningElement {
    @api recordId;
    @track selectedChannels = []; // [{id, name}]
    @track searchTerm = '';
    @track searchResults = [];
    @track isOpen = false;
    @track isLoading = false;
    @track isSaving = false;
    @track isEditMode = false;
    _timer = null;
    _originalIds = '';

    searchChannelPlaceholder = FEC_Search_Channel_Placeholder;
    noResultsLabel = FEC_No_Results;
    cancelLabel = FEC_Button_Cancel;
    saveLabel = FEC_Button_Save;

    connectedCallback() {
        this.loadCurrentChannels();
    }

    async loadCurrentChannels() {
        try {
            const ids = await getChannelIds({ nocId: this.recordId });
            if (!ids) return;
            // ids là comma-separated Channel IDs (Id của FEC_Channel__c)
            const idList = ids.split(',').map(s => s.trim()).filter(s => s);
            if (!idList.length) return;
            this._originalIds = ids;
            // Load tên channel từ search
            const results = await searchChannels({ searchTerm: '' });
            this.selectedChannels = results
                .filter(ch => idList.includes(ch.Id))
                .map(ch => ({ id: ch.Id, name: ch.FEC_Channel_Vietnamese_name__c || ch.Name }));
        } catch (e) {
            console.error('loadCurrentChannels error', e);
        }
    }

    get hasSelected() {
        return this.selectedChannels.length > 0;
    }

    get noResults() {
        return !this.isLoading && this.searchResults.length === 0 && this.isOpen;
    }

    handleInput(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length < 1) {
            this.isOpen = false;
            this.searchResults = [];
            return;
        }
        this.isLoading = true;
        this.isOpen = true;
        if (this._timer) clearTimeout(this._timer);
        this._timer = setTimeout(() => {
            searchChannels({ searchTerm: this.searchTerm })
                .then(data => {
                    // Lọc bỏ những channel đã chọn
                    const selectedIds = this.selectedChannels.map(c => c.id);
                    this.searchResults = data.filter(ch => !selectedIds.includes(ch.Id));
                    this.isLoading = false;
                })
                .catch(() => { this.isLoading = false; });
        }, 300);
    }

    handleFocus() {
        if (this.searchTerm.length >= 1) this.isOpen = true;
    }

    handleBlur() {
        setTimeout(() => { this.isOpen = false; }, 200);
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        if (!this.selectedChannels.find(c => c.id === id)) {
            this.selectedChannels = [...this.selectedChannels, { id, name }];
        }
        this.searchTerm = '';
        this.searchResults = [];
        this.isOpen = false;
    }

    handleRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedChannels = this.selectedChannels.filter(c => c.id !== id);
    }

    async handleSave() {
        this.isSaving = true;
        try {
            const ids = this.selectedChannels.map(c => c.id).join(',');
            await saveChannelIds({ nocId: this.recordId, channelIds: ids || null });
            this._originalIds = ids;
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.isEditMode = false;
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Success,
                message: FEC_Channel_Config_Save_Success,
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Error,
                message: e?.body?.message || FEC_Channel_Config_Save_Error,
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        // Restore về giá trị ban đầu
        this.loadCurrentChannels();
        this.searchTerm = '';
        this.searchResults = [];
        this.isOpen = false;
        this.isEditMode = false;
    }

    handleEdit() {
        this.isEditMode = true;
    }
}
