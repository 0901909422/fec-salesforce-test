import { LightningElement, track } from 'lwc';
import syncFraudMasterData from '@salesforce/apex/FEC_IntegrationMasterDataController.syncFraudMasterData';
import syncLocation from '@salesforce/apex/FEC_IntegrationLocationService.syncLocation';
import autoSyncMapAPropertiesToMasterDataItemtoApply from '@salesforce/apex/FEC_MapAPropertiesToMasterDataItemCtrl.autoSyncMapAPropertiesToMasterDataItemtoApply';
import autoSyncIntegratingPropertyMappingtoApply from '@salesforce/apex/FEC_AutoIntegratingPropertyMappingCtrl.autoSyncIntegratingPropertyMappingtoApply';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LBL_Master_XML_Sync_Msg_Success from '@salesforce/label/c.LBL_Master_XML_Sync_Msg_Success';
import LBL_Master_XML_Msg_Failed from '@salesforce/label/c.LBL_Master_XML_Msg_Failed';

export default class IntegrationFraudMasterData extends LightningElement {

    @track isLoading = false;
    @track showModal = false;
    @track showNoData = false;
    @track masterData = [];

    labels = {
        successTitle: LBL_Master_XML_Sync_Msg_Success,
        errorTitle: LBL_Master_XML_Msg_Failed
    };

    handleImport() {
        this.isLoading = true;

        syncFraudMasterData()
            .then(result => {
                this.showToast(
                    this.labels.successTitle,
                    result,
                    'success'
                );
            })
            .catch(error => {
                this.showToast(
                    this.labels.errorTitle,
                    error?.body?.message || 'Unexpected error',
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSyncLocation() {
        this.isLoading = true;

        syncLocation()
            .then(() => {
                this.showToast('Success', 'Location data synced successfully', 'success');
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Failed to sync location data', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSyncMapProperties() {
        this.isLoading = true;
        autoSyncMapAPropertiesToMasterDataItemtoApply()
            .then(result => {
                this.showToast('Success',
                    'Map Properties: ' + result.totalUpdated + '/' + result.totalToUpdate + ' records synced',
                    'success');
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Failed to sync map properties', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleSyncIntegratingProperty() {
        this.isLoading = true;
        autoSyncIntegratingPropertyMappingtoApply()
            .then(result => {
                this.showToast('Success',
                    'Integrating Property: ' + result.totalUpdated + '/' + result.totalToUpdate + ' records synced',
                    'success');
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Failed to sync integrating property', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}