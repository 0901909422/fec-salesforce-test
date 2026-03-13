import { LightningElement, track, api } from 'lwc';
import getConfigHistory from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getConfigHistory';

import titleChangeHistory from '@salesforce/label/c.FEC_Title_Change_History';
import btnClose from '@salesforce/label/c.FEC_Btn_Close';
import LBL_DATA_LINKAGE from '@salesforce/label/c.FEC_Lbl_Data_Linkage';
import LBL_FIELD_NAME from '@salesforce/label/c.FEC_Lbl_Field_Name';
import LBL_STATUS from '@salesforce/label/c.FEC_Lbl_Status';
import LBL_IS_ACTIVE from '@salesforce/label/c.FEC_Lbl_Is_Active';
import LBL_START_DATE from '@salesforce/label/c.FEC_Lbl_Start_Date';
import LBL_END_DATE_FINISH from '@salesforce/label/c.FEC_Lbl_End_Date_Finish';
import LBL_CREATED_BY from '@salesforce/label/c.FEC_Lbl_Created_By';
import LBL_CREATED_DATE from '@salesforce/label/c.FEC_Lbl_Created_Date';
import LBL_MODIFIED_BY from '@salesforce/label/c.FEC_Lbl_Modified_By';
import LBL_MODIFIED_DATE from '@salesforce/label/c.FEC_Lbl_Modified_Date';

export default class FecCustomerHistoryModal extends LightningElement {
    label = {
        titleChangeHistory,
        btnClose
    };

    @api configId;
    
    @track historyData = [];
    @track columns = [];
    @track isLoading = false;

    columns = [
        { label: LBL_DATA_LINKAGE, fieldName: 'FEC_KeyIdentifier__c', type: 'text', sortable: true },
        { label: LBL_FIELD_NAME, fieldName: 'FEC_FieldID__c', type: 'text', sortable: true },
        { label: LBL_STATUS, fieldName: 'FEC_Status__c', type: 'text', sortable: true },
        { label: LBL_IS_ACTIVE, fieldName: 'FEC_IsActive__c', type: 'boolean', sortable: true },
        { 
            label: LBL_START_DATE, 
            fieldName: 'FEC_StartDate__c', 
            type: 'date', 
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric' },
            sortable: true
        },
        { 
            label: LBL_END_DATE_FINISH, 
            fieldName: 'FEC_EndDate__c', 
            type: 'date', 
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric' },
            sortable: true 
        },
        { label: LBL_CREATED_BY, fieldName: 'CreatedByName', type: 'text', sortable: true },
        { 
            label: LBL_CREATED_DATE, 
            fieldName: 'CreatedDate', 
            type: 'date',
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' },
            sortable: true
        },
        { label: LBL_MODIFIED_BY, fieldName: 'ModifiedByName', type: 'text', sortable: true },
        { 
            label: LBL_MODIFIED_DATE, 
            fieldName: 'LastModifiedDate', 
            type: 'date',
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' },
            sortable: true
        }
    ];

    async connectedCallback() {
        this.fetchData();
    }

    async fetchData() {
        this.isLoading = true;
        try {
            const data = await getConfigHistory({ configId: this.configId });
            this.historyData = data.map(row => ({
                ...row,
                CreatedByName: row.CreatedBy?.Name,
                ModifiedByName: row.LastModifiedBy?.Name
            }));
        } catch (error) {
            console.error('Error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}