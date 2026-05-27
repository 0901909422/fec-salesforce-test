import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import { SUCCESS_TITLE, FAIL_TITLE, EDIT_ACTION, DELETE_ACTION, DELETE_CONFIRMATION_TITLE, DELETE_CONFIRMATION_MSG } from 'c/fecUtils';
import getCampaignMappings from '@salesforce/apex/FEC_CampaignController.getCampaignMappings';
import getCampaignConfigs from '@salesforce/apex/FEC_CampaignController.getCampaignConfigs';
import saveMapping from '@salesforce/apex/FEC_CampaignController.saveMapping';
import deleteMapping from '@salesforce/apex/FEC_CampaignController.deleteMapping';
import savedDataMsg from '@salesforce/label/c.FEC_Saved_Data';
import deletedMsg from '@salesforce/label/c.FEC_Delete_Success_Message';
import unableToLoadRecordsMsg from '@salesforce/label/c.FEC_Unable_To_Load_Records_Message';
import requiredFieldsMsg from '@salesforce/label/c.FEC_Error_Required_Fields';
import LBL_IS_ACTIVE from '@salesforce/label/c.FEC_Lbl_Is_Active';
import LBL_CS_CAMPAIGN_NAME from '@salesforce/label/c.FEC_Lbl_CS_Campaign_Name';
import LBL_GENESYS_CAMPAIGN from '@salesforce/label/c.FEC_Lbl_Genesys_Campaign';
import LBL_CARD_TITLE from '@salesforce/label/c.FEC_Lbl_Mapping_Configuration_Title';
import LBL_NEW_BTN from '@salesforce/label/c.FEC_Btn_Add_New';
import LBL_CANCEL from '@salesforce/label/c.Cancel';
import LBL_SAVE from '@salesforce/label/c.FEC_Button_Save';
import addModalTitle from '@salesforce/label/c.FEC_Lbl_Add_New_Modal_Title';
import editModalTitle from '@salesforce/label/c.FEC_Lbl_Edit_Title';

// Cấu hình cột cho Datatable
const COLUMNS = [
    { label: LBL_CS_CAMPAIGN_NAME, fieldName: 'Name' },
    { label: LBL_GENESYS_CAMPAIGN, fieldName: 'GenesysName' },
    { label: LBL_IS_ACTIVE, fieldName: 'FEC_IsActive__c', type: 'boolean' },
    {
        type: 'action',
        typeAttributes: { rowActions: [
            { iconName: 'utility:edit', name: EDIT_ACTION },
            { iconName: 'utility:delete', name: DELETE_ACTION }
        ] }
    }
];

export default class FecCampaignSettings extends LightningElement {
    label = {
        cardTitle: LBL_CARD_TITLE,
        newBtn: LBL_NEW_BTN,
        csCampaignName: LBL_CS_CAMPAIGN_NAME,
        genesysCampaign: LBL_GENESYS_CAMPAIGN,
        isActive: LBL_IS_ACTIVE,
        cancel: LBL_CANCEL,
        save: LBL_SAVE
    };

    columns = COLUMNS;
    @track mappingList = [];
    @track genesysOptions = [];
    isModalOpen = false;
    modalTitle = addModalTitle;
    isLoading = false;
    wiredMappingResult;

    @track currentRecord = {
        Id: null,
        Name: '',
        FEC_Campaign__c: '',
        FEC_IsActive__c: true
    };

    @wire(getCampaignMappings)
    wiredMappings(result) {
        this.wiredMappingResult = result;
        if (result.data) {
            this.mappingList = result.data.map(row => ({
                ...row,
                GenesysName: row.FEC_Campaign__r ? row.FEC_Campaign__r.Name : ''
            }));
        } else if (result.error) {
            this.showToast(FAIL_TITLE, unableToLoadRecordsMsg, 'error');
        }
    }

    @wire(getCampaignConfigs)
    wiredOptions({ data, error }) {
        if (data) {
            this.genesysOptions = data.map(camp => ({
                label: camp.FEC_CampaignId__c,
                value: camp.Id
            }));
        }
    }

    handleOpenModal() {
        this.resetForm();
        this.modalTitle = addModalTitle;
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === EDIT_ACTION) {
            this.currentRecord = { ...row };
            this.modalTitle = `${editModalTitle} ${row.Name}`;
            this.isModalOpen = true;
        } else if (actionName === DELETE_ACTION) {
            const confirmed = await LightningConfirm.open({
                message: DELETE_CONFIRMATION_MSG,
                variant: 'header',
                label: DELETE_CONFIRMATION_TITLE,
                theme: 'warning'
            });
            if (confirmed) {
                this.handleDelete(row.Id);
            }
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this.currentRecord[field] = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    }

    handleCampaignChange(event) {
        this.currentRecord.FEC_Campaign__c = event.detail.value;
    }

    async handleSave() {
        if (!this.currentRecord.Name || !this.currentRecord.FEC_Campaign__c) {
            this.showToast(FAIL_TITLE, requiredFieldsMsg, 'error');
            return;
        }

        this.isLoading = true;
        try {
            await saveMapping({ mappingData: this.currentRecord });
            this.showToast(SUCCESS_TITLE, savedDataMsg, 'success');
            this.handleCloseModal();
            refreshApex(this.wiredMappingResult);
        } catch (error) {
            this.showToast(FAIL_TITLE, error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDelete(recordId) {
        this.isLoading = true;
        try {
            await deleteMapping({ recordId: recordId });
            this.showToast(SUCCESS_TITLE, deletedMsg, 'success');
            refreshApex(this.wiredMappingResult);
        } catch (error) {
            this.showToast(FAIL_TITLE, error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.currentRecord = {
            Id: null,
            Name: '',
            FEC_Campaign__c: '',
            FEC_IsActive__c: true
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}