/****************************************************************************************
 * File Name    : Fec_HoldCaseConfigurationTabView.js
 * Author       : Quangdv7
 * Date         : 2026-05-11
 * Description  : Call data object Hold Case Config
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-05-11    Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference,NavigationMixin } from 'lightning/navigation';

import { setConsoleTab } from 'c/fec_CommonUtils';

import getHoldCaseConfigurationDetail from '@salesforce/apex/Fec_HoldCaseConfigurationController.getHoldCaseConfigurationDetail';
import getHoldCaseConfigHistory from '@salesforce/apex/Fec_HoldCaseConfigurationController.getHoldCaseConfigHistory';

import FEC_HCC_Name from '@salesforce/label/c.FEC_HCC_Name';
import FEC_Hold_Case_Type from '@salesforce/label/c.FEC_Hold_Case_Type';
import FEC_Current_Status from '@salesforce/label/c.FEC_Current_Status';
import FEC_Changed_Status from '@salesforce/label/c.FEC_Changed_Status';
import FEC_Manual from '@salesforce/label/c.FEC_Manual';
import FEC_Col_Active from '@salesforce/label/c.FEC_Col_Active';
import FEC_Tab_Case_Stage from '@salesforce/label/c.FEC_Tab_Case_Stage';
import FEC_LABEL_USER from '@salesforce/label/c.FEC_LABEL_USER';
import LBL_Channel_Col from '@salesforce/label/c.LBL_Channel_Col';

import FEC_Date from '@salesforce/label/c.FEC_Date'; 
import FEC_Field from '@salesforce/label/c.FEC_Field';
import FEC_Original_Value from '@salesforce/label/c.FEC_Original_Value';  
import FEC_New_Value from '@salesforce/label/c.FEC_New_Value';  
import FEC_Detail_Information from '@salesforce/label/c.FEC_Detail_Information';  


export default class Fec_HoldCaseConfigurationTabView  extends NavigationMixin(LightningElement) {

    /* ================= STATE ================= */

    @track record = null;
    @track historyRecords = [];
    isLoading = false;

    holdCaseConfigurationId;
    activeSections =['holaCaseConfigHistory']

    /* ================= LABEL ================= */
    customLabel = {
        hccName : FEC_HCC_Name,
        holdCaseType: FEC_Hold_Case_Type,
        channel: LBL_Channel_Col,
        currentStatus:FEC_Current_Status,
        changedStatus: FEC_Changed_Status,
        nfuCode: FEC_NFU_Code,
        caseStage: FEC_Tab_Case_Stage,
        active: FEC_Col_Active,
        manual: FEC_Manual,
        date: FEC_Date,
        user: FEC_LABEL_USER,
        field: FEC_Field,
        OriginalValue: FEC_Original_Value,
        newValue: FEC_New_Value,
        detailInformation: FEC_Detail_Information
    }

    /* ================= FIELD CONFIG ================= */

    holdCaseFields = [

        { label: this.customLabel.hccName, fieldName: 'Name'},
        { label: this.customLabel.holdCaseType, fieldName: 'Hold_Case_Type__c'},
        { label: this.customLabel.channel, fieldName: 'FEC_Channel__c'},
        { label: this.customLabel.currentStatus, fieldName: 'FEC_Current_Status__c'},
        { label: this.customLabel.changedStatus, fieldName: 'FEC_Changed_Status__c'},
        { label: this.customLabel.caseStage, fieldName: 'caseStageName'},
        { label: this.customLabel.nfuCode, fieldName: 'FEC_NFU_Code__c'},
        { label: this.customLabel.active, fieldName: 'activeText'}
    ];

    holdCaseConfigHistoryColumns = [
        { label: this.customLabel.date, fieldName: 'modifiedDate'},
        { label: this.customLabel.user, fieldName: 'userLabel', type: 'link',recordIdField: 'userId'},
        { label: this.customLabel.field, fieldName: 'field'},
        { label: this.customLabel.OriginalValue, fieldName: 'originalValue'},
        { label: this.customLabel.newValue, fieldName: 'newValue'}
    ]

    /* ================= NAV ================= */

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {

        const holdCaseConfigurationId =
            pageRef?.state?.c__recordId;

        if (holdCaseConfigurationId) {

            this.holdCaseConfigurationId =
                holdCaseConfigurationId;

            this.loadDetail();
        }
    }

    /* ================= LOAD DATA ================= */
    loadDetail() {

        if (!this.holdCaseConfigurationId) {
            return;
        }

        this.isLoading = true;

        getHoldCaseConfigurationDetail({
            recordId: this.holdCaseConfigurationId
        })
        .then(result => {

            this.record = {
                ...result,

                caseStageName:
                    result?.FEC_Case_Stage__r?.Name || '-',

                activeText:
                    result?.FEC_Active__c
                        ? 'Yes'
                        : 'No'
            };

            setConsoleTab(
                this.record.Name,
                'standard:orders'
            );

            // ================= HISTORY =================

            return getHoldCaseConfigHistory({
                recordId: this.holdCaseConfigurationId
            });
        })
        .then(data => {

            this.historyRecords = data.map(item => {

                return {
                    ...item,
                    userLabel: item.userName,
                };
            });
        })
        .catch(error => {console.error(error)})
        .finally(() => {
            this.isLoading = false;
        });
    }
    
    /* ================= SECTION ================= */

    get sections() {

        if (!this.record) {
            return null;
        }

        return [
            {
                name: 'detail',
                label: this.customLabel.detailInformation,
               fields: this.buildFields(
                    this.filteredHoldCaseFields
                )
            }
        ];
    }

    handleEdit() {

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.holdCaseConfigurationId,
                objectApiName: 'FEC_Hold_Case_Config__c',
                actionName: 'edit'
            }
        });
    }

    get filteredHoldCaseFields() {

        if (!this.record) {
            return [];
        }

        const isManual =
            this.record.Hold_Case_Type__c === this.customLabel.manual;

        if (isManual) {

            return this.holdCaseFields.filter(field =>
                field.fieldName !== 'FEC_Current_Status__c' &&
                field.fieldName !== 'FEC_Changed_Status__c'
            );
        }

        return this.holdCaseFields;
    }

    handleUserSelect(event) {

        const recordId = event.detail.recordId;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'User',
                actionName: 'view'
            }
        });
    }

    /* ================= FIELD BUILDER ================= */

    buildFields(configs) {

        if (!this.record) {
            return [];
        }

        return configs.map(cfg => {

            let value = this.record?.[cfg.fieldName];

            if (
                value === null ||
                value === undefined ||
                value === ''
            ) {
                value = '-';
            }

            return {
                label: cfg.label,
                value,
                fieldName: cfg.fieldName
            };
        });
    }
}