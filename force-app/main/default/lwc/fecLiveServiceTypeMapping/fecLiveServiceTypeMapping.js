import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLiveServiceTypeTree from '@salesforce/apex/FEC_LiveDataViewController.getLiveServiceTypeTree';
import LABEL_SERVICE_TYPES from '@salesforce/label/c.FEC_Label_ServiceTypes';
import LABEL_SERVICETYP_MAPP_TITLE from '@salesforce/label/c.FEC_ServiceTypeMapping_Title';
import LABEL_TABLE_HEADER_PROPERTY from '@salesforce/label/c.FEC_TableHeader_PropertyName';
import LABEL_TABLE_HEADER_REFERENCE from '@salesforce/label/c.FEC_TableHeader_Reference';
import LABEL_MESSAGE_SELECT_PROPERTY from '@salesforce/label/c.FEC_Message_Select_Property';
import LABEL_NODATA_MESSAGE from '@salesforce/label/c.FEC_NoData_Message';

export default class FecLiveServiceTypeMapping extends LightningElement {
    @track treeItems = [];
    @track selectedProperty = null;
    allPropertiesFlat = [];
    isLoading = true;

    // UI labels
    labelServiceTypes = LABEL_SERVICE_TYPES;
    title = LABEL_SERVICETYP_MAPP_TITLE;
    tableHeaderProperty = LABEL_TABLE_HEADER_PROPERTY;
    tableHeaderReference = LABEL_TABLE_HEADER_REFERENCE;
    messageSelectProperty = LABEL_MESSAGE_SELECT_PROPERTY;
    labelNoData = LABEL_NODATA_MESSAGE;

    get hasTreeItems() {
        return this.treeItems && this.treeItems.length > 0;
    }

    @wire(getLiveServiceTypeTree)
    wiredTree({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.treeItems = data;
            this.allPropertiesFlat = data.flatMap(bp => bp.items || []);
        } else if (error) {
            this.treeItems = [];
            this.allPropertiesFlat = [];
            this.showErrorToast(error.body?.message || error.message || 'Error loading service type tree');
        }
    }

    handleSelect(event) {
        const id = event.detail.name;
        const found = this.allPropertiesFlat.find(p => p.name === id);
        if (found) {
            this.selectedProperty = { ...found };
        }
    }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }
}