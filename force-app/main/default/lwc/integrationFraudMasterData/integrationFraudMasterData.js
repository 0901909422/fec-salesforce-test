import { LightningElement, track } from 'lwc';
import getMasterData from '@salesforce/apex/FEC_IntegrationMasterDataController.getMasterDataForUI';
import syncFraudMasterData from '@salesforce/apex/FEC_IntegrationMasterDataController.syncFraudMasterData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';



export default class IntegrationFraudMasterData extends LightningElement {

    
    @track isLoading = false;
    @track showModal = false;
    @track showNoData = false;    
    @track masterData = [];

    connectedCallback() {
        this.loadMasterData();
    }
    loadMasterData() {
        getMasterData()
        .then(res => {
            let json = JSON.parse(res);
            this.masterData = json.categories;
        })
        .catch(err => {
            console.error('Master Data error:', err);
        });
    }
    handleImport() {
        this.isLoading = true;

        syncFraudMasterData()
            .then(result => {
                this.showToast('Import Completed', result, 'success');
                this.loadMasterData();
            })
            .catch(error => {
                this.showToast('Import Failed', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}