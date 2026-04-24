import { LightningElement, api, track } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import loadMasterDataIntegrationMappingById from '@salesforce/apex/FEC_IntegrationCreateFraudController.loadMasterDataIntegrationMappingById';

import getIntegrationFieldTypes 
    from '@salesforce/apex/FEC_IntegrationCreateFraudController.getIntegrationFieldTypes';
import submitCreateFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitCreateFraudCase';
import submitUpdateFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitUpdateFraudCase';
import submitCancelFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitCancelFraudCase';




import Loading from '@salesforce/label/c.Loading';
import User_Type from '@salesforce/label/c.User_Type';
import Int_Channel from '@salesforce/label/c.Int_Channel';
import Int_User_Type from '@salesforce/label/c.Int_User_Type';
import Int_Product_Line from '@salesforce/label/c.Int_Product_Line';
import Int_Service_Type from '@salesforce/label/c.Int_Service_Type';
import Int_Category from '@salesforce/label/c.Int_Category';
import Int_Sub_Category from '@salesforce/label/c.Int_Sub_Category';
import Int_Sub_Code from '@salesforce/label/c.Int_Sub_Code';
import Integrating_Property from '@salesforce/label/c.Integrating_Property';
import Vietnamese_Name from '@salesforce/label/c.Vietnamese_Name';
import Integrating_Property_Type from '@salesforce/label/c.Integrating_Property_Type';
import CSM_Property from '@salesforce/label/c.CSM_Property';
import CSM_Property_Type from '@salesforce/label/c.CSM_Property_Type';
import Auto_Mapping from '@salesforce/label/c.Auto_Mapping';
import Mandatory from '@salesforce/label/c.Mandatory';
import Cancel from '@salesforce/label/c.Cancel';
import Save from '@salesforce/label/c.Save';
import Integration_Mapping_Title from '@salesforce/label/c.Integration_Mapping_Title';
import LBL_Success from '@salesforce/label/c.LBL_Success';
import LBL_Error from '@salesforce/label/c.LBL_Error';
import LBL_SaveSuccess from '@salesforce/label/c.LBL_SaveSuccess';
import LBL_SaveFailed from '@salesforce/label/c.LBL_SaveFailed';
import LBL_UnexpectedError from '@salesforce/label/c.LBL_UnexpectedError';
import LBL_ValidationError from '@salesforce/label/c.LBL_ValidationError';
import LBL_HeaderRequired from '@salesforce/label/c.LBL_HeaderRequired';
import LBL_SelectAtLeastOneRow from '@salesforce/label/c.LBL_SelectAtLeastOneRow';
import LBL_Missing_Required_Fields from '@salesforce/label/c.LBL_Missing_Required_Fields';
import LBL_Fill_Required_Fields from '@salesforce/label/c.LBL_Fill_Required_Fields';
import LBL_Missing_Additional_Properties from '@salesforce/label/c.LBL_Missing_Additional_Properties';
import LBL_Add_Additional_Property from '@salesforce/label/c.LBL_Add_Additional_Property';
import LBL_Create_Fraud_Case_Submission_Failed from '@salesforce/label/c.LBL_Create_Fraud_Case_Submission_Failed';
import LBL_Create_Fraud_Case_Success from '@salesforce/label/c.LBL_Create_Fraud_Case_Success';
import LBL_Cancel_Fraud_Case_Missing_Field from '@salesforce/label/c.LBL_Cancel_Fraud_Case_Missing_Field';
import LBL_Cancel_Fraud_Case_Button from '@salesforce/label/c.LBL_Cancel_Fraud_Case_Button';
import LBL_Create_Fraud_Case_Button from '@salesforce/label/c.LBL_Create_Fraud_Case_Button';



export default class IntegrationCreateFraudCase extends LightningElement {

    @api serviceCaseId;
    @api natureOfCaseId;
    @api mappingId;
    @api caseDataId;

    @track loading = true;
    @track showPreview = false;
    @track previewJson = '';
    isCreateSubmitting = false;
    isCancelSubmitting = false;
   
    categoryOptions = [];
    subCategoryOptions = [];
    subCodeOptions = [];   
    fraudIntUserType = '';
    fraudIntChannel = '';
    fraudIntProductLine = '';
    faudIntServiceType = '';
    fraudIntCategory = '';
    fraudIntSubCategory = '';
    fraudIntSubCode = '';
    fieldTypes = {};
    createActionType = 'create';
    updateActionType = 'update';
    cancelActionType = 'cancel';


    subCategoriesAll = [];    
    subCodesAll = [];
    @track rows = [];
    get notLoading() { return !this.loading; }

    master = null;
    resultMessage = '';

    // FORM VALUES (IDs only)
    selectedCategory = null;
    selectedSubCategory = null;
    selectedSubCode = null;

    // OPTIONS
    categoryOptions = [];
    subCategoryOptions = [];
    subCodeOptions = [];

    // Additional Props
    @track additionalProps = [];

    // Other fields
    productType = '';
    remarks = '';
    creatorEmail = '';
    fraudCase = '';

    actionType = this.createActionType; // create | update | cancel
    labels = {
        Integration_Mapping_Title,
        Loading,
        User_Type,
        Int_Channel,
        Int_User_Type,
        Int_Product_Line,
        Int_Service_Type,
        Int_Category,
        Int_Sub_Category,
        Int_Sub_Code,
        Integrating_Property,
        Vietnamese_Name,
        Integrating_Property_Type,
        CSM_Property,
        CSM_Property_Type,
        Auto_Mapping,
        Mandatory,
        Cancel,
        Save,
        success: LBL_Success,
        error: LBL_Error,
        saveSuccess: LBL_SaveSuccess,
        saveFailed: LBL_SaveFailed,
        unexpectedError: LBL_UnexpectedError,
        validationError: LBL_ValidationError,
        headerRequired: LBL_HeaderRequired,
        selectAtLeastOneRow: LBL_SelectAtLeastOneRow,
        missingRequiredTitle: LBL_Missing_Required_Fields,
        missingRequiredMsg: LBL_Fill_Required_Fields,
        missingAdditionalTitle: LBL_Missing_Additional_Properties,
        missingAdditionalMsg: LBL_Add_Additional_Property,
        responseSuccess: LBL_Create_Fraud_Case_Success,
        responseFailed: LBL_Create_Fraud_Case_Submission_Failed,
        missingRequiredCancel: LBL_Cancel_Fraud_Case_Missing_Field,
        Create_Fraud_Case_Button: LBL_Create_Fraud_Case_Button,
        Cancel_Fraud_Case_Button: LBL_Cancel_Fraud_Case_Button
    };
    showErrorToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: 'error'
            })
        );
    }

    connectedCallback() {
        this.loading = true;
        getIntegrationFieldTypes()
            .then(types => {
                this.fieldTypes = types;
                if (this.mappingId) {
                    console.log('case-data-id: ', this.caseDataId);
                    return this.loadMasterDataIntegrationMapping(this.mappingId, this.caseDataId);
                }
            })
            .catch(err => {
                console.error('[ERROR] connectedCallback:', err);
            })
            .finally(() => {
                this.loading = false;
            });
    }


   loadMasterDataIntegrationMapping(mappingId, caseDataId) {
        console.log('[CALL] loadMasterDataIntegrationMapping:', mappingId);
        return loadMasterDataIntegrationMappingById({
            integrationMappingId: mappingId,
            caseDataId: caseDataId
        })
        .then(data => {
            console.log('[SUCCESS] loadMasterDataIntegrationMapping list:', data);
            this.fraudIntChannel = data.intChannel;           
            this.fraudIntUserType = data.intUserType;
            this.fraudIntProductLine = data.intProductLine;
            this.fraudIntServiceType = data.intServiceType;
            this.category = data.intCategory;
            this.subCategory = data.intSubCategory;
            this.subCode = data.intSubCode;            
            this.loadAdditionalProps(data.propertyValues, data.propertyMappingValues);
        })
        .catch(err => {
            console.error('[ERROR] loadMasterDataIntegrationMapping:', err);
            throw err; // important for Promise.all
        });
    }


    loadAdditionalProps(responseData, propertyMappingValues) {
        console.log('[SUCCESS] Additional Properties:', responseData);
        console.log('[SUCCESS] Property Mapping Values:', propertyMappingValues);
        const list = Array.isArray(responseData) ? responseData : [];
        const mappingValues = propertyMappingValues || {};
        console.log('[SUCCESS] Additional Properties list:', list);
        this.additionalProps = list.map(p => {
            const type = p.type?.trim().toLowerCase();
            // Auto-populate value from propertyMappingValues if exists
            const mappedValue = mappingValues[p.property] || null;

            return {
                ...p,
                type,
                value: mappedValue,

                // type flags
                isString: type === this.fieldTypes.STRING,
                isMulti: type === this.fieldTypes.MULTI,
                isDate: type === this.fieldTypes.DATE,
                isFile: type === this.fieldTypes.FILE,
                isNumber: type === this.fieldTypes.NUMBER,
                isBoolean: type === this.fieldTypes.BOOLEAN,
                isPicklist: type ===  this.fieldTypes.PICKLIST,
                isList: type ===  this.fieldTypes.LIST,
    
                options: (p.availableValues || []).map(v => ({
                    label: v.displayName,
                    value: v.property
                }))
            };
        });
    }
    getSubCategoryByValue(value) {
        return this.subCategoriesAll.find(sc => sc.value === value);
    }
    
    getSubCodeByValue(value) {
        return this.subCodesAll.find(sc => sc.value === value);
    }
    
    


    // OTHER FIELD CHANGES
    onSimpleChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this[field] = event.detail.value;
            console.log(`[SET] ${field}:`, this[field]);
        }
    }

    onFieldChange(event) {
        const fieldId = event.target.dataset.id;
        console.log('onFieldChange: ', fieldId);
    
        const value =
            event.target.type === 'checkbox'
                ? event.target.checked
                : event.detail.value;
        console.log('onFieldChange: ', value);
    
        this.additionalProps = this.additionalProps.map(p =>
            p.id === fieldId
                ? { ...p, value }
                : p
        );
    }

    // -------------------------------------------------------------------
    // FILE HANDLING
    // -------------------------------------------------------------------
    onFileChange(event) {
        const fieldId = event.target.dataset.id;
        const file = event.target.files[0];
        if (!file) return;
    
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            const fileName = file.name;
            const fileType = fileName.split('.').pop();
    
            const combinedValue = `${fileName}|${fileType}|${base64}`;
    
            this.additionalProps = this.additionalProps.map(p =>
                p.id === fieldId
                    ? {
                        ...p,
                        value: combinedValue,
                        base64,
                        fileName
                    }
                    : p
            );
        };
    
        reader.readAsDataURL(file);
    }

    // -------------------------------------------------------------------
    // BUILD PAYLOAD — USE ID INSTEAD OF NAME
    // -------------------------------------------------------------------
    buildPayload() {
        const additionalInfoPayload = this.additionalProps
            .filter(p => {
                if (p.type === this.fieldTypes.FILE) {
                    return !!p.fileName;
                }
                if (p.isBoolean) {
                    return p.value !== null && p.value !== undefined;
                }
            
                return p.value !== null && p.value !== undefined && p.value !== '';
            })
            .map(p => ({
                ID: p.property,
                Value: p.value !== null && p.value !== undefined
                    ? String(p.value)
                    : null,
                FileName: p.fileName || null,
                Type: p.type,
                Mandatory: p.mandatory
            }));
    console.log('additionalInfoPayload: ', JSON.stringify(additionalInfoPayload));
        return {
            CaseType: this.fraudIntServiceType,
            ProductType: this.fraudIntProductLine,
            Category: this.category,
            SubCategory: this.subCategory,
            SubCode: this.subCode,
            Remarks: this.remarks,
            UserType: this.fraudIntUserType,
            CreatorEmail: this.creatorEmail,
            FraudCaseId: this.fraudCase,
            ServiceCaseId: this.serviceCaseId,
            caseDataId: this.caseDataId,
            AdditionalInfo: additionalInfoPayload
        };
    }

    // -------------------------------------------------------------------
    // PREVIEW + SUBMIT
    // -------------------------------------------------------------------

    async onSubmitCancel() {
        if (this.isCancelSubmitting) return;
        this.loading = true;
        this.isCancelSubmitting = true;
        try {
            const payload = this.buildPayload();    
            const serviceCaseId = payload?.ServiceCaseId;
            const fraudCaseId = payload?.FraudCaseId;    
            if (!serviceCaseId || !fraudCaseId) {
                this.showErrorToast(
                    this.labels.missingRequiredTitle,
                    this.labels.missingRequiredCancel
                );
                this.loading = false;
                this.isCancelSubmitting = false;
                return;
            }
    
            this.previewJson = JSON.stringify(payload, null, 2);
            this.actionType = this.cancelActionType;    
            await this.confirmSubmit(); //wait until finished
        } catch (error) {
            this.showErrorToast('Error', error?.body?.message || error.message);
        } finally {
            this.loading = false; //unlock only when everything finishes
            this.isCancelSubmitting = false;
        }
    }
    
    async onSubmit() {

        if (this.isCreateSubmitting) return; // extra protection against double click   
        this.isCreateSubmitting = true;   
        this.loading = true;  
        //Validate standard lightning inputs
        const allInputs = this.template.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        );
    
        let isValid = true;
        let firstInvalid = null;
    
        allInputs.forEach(el => {
            if (!el.checkValidity()) {
                el.reportValidity();
                isValid = false;
    
                if (!firstInvalid) {
                    firstInvalid = el;
                }
            }
        });
    
        //Validate dynamic additional properties
        const missingDynamic = this.additionalProps.filter(p => {
    
            if (!p.mandatory) return false;
    
            if (p.isBoolean) {
                return p.value !== true;
            }
    
            if (p.isFile) {
                return !p.fileName;
            }
    
            return !p.value || p.value === '';
        });
    
        if (missingDynamic.length > 0) {
            isValid = false;
    
            const firstMissing = missingDynamic[0];
            const el = this.template.querySelector(
                `[data-id="${firstMissing.id}"]`
            );
    
            if (el) {
                el.reportValidity?.();
                firstInvalid = el;
            }
        }
    
        if (!isValid) {
            if (firstInvalid) {
                firstInvalid.scrollIntoView({
                    behavior: 'smooth',
                    block: 'center'
                });
            }
    
            this.showErrorToast(
                this.labels.missingRequiredTitle,
                this.labels.missingRequiredMsg
            );
            this.loading = false;
            this.isCreateSubmitting = false;   
            return;
        }
    
        if (this.additionalProps.length === 0) {
            this.showErrorToast(
                this.labels.missingAdditionalTitle,
                this.labels.missingAdditionalMsg
            );
            this.loading = false;
            this.isCreateSubmitting = false;   
            return;
        }
    
        // =============================
        // PROCESSING STARTS HERE
        // =============================    
        try {
            const payload = this.buildPayload();
            this.previewJson = JSON.stringify(payload, null, 2);
    
            const isUpdate =
                this.fraudCase && Object.keys(this.fraudCase).length > 0;
    
            this.actionType = isUpdate
                ? this.updateActionType
                : this.createActionType;         
            console.log('onSUbmit: ', this.previewJson);  
            await this.confirmSubmit();
            
            
        } catch (error) {
            this.showErrorToast(
                'Error',
                error?.body?.message || error.message
            );
        } finally {
            this.loading = false;
            this.isCreateSubmitting = false;   
        }
    }

    showSuccessToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'success',
                mode: 'dismissable'
            })
        );
    }
    
    showErrorToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'error',
                mode: 'sticky' // stays until user closes
            })
        );
    }

    async confirmSubmit() {
        let payload;
    
        try {
            payload = JSON.parse(this.previewJson);
        } catch (e) {
            //this.showPreview = false;
            //return;
        }
    
        let actionPromise;
    
        if (this.actionType === this.cancelActionType) {
            actionPromise = await submitCancelFraudCase({ payload });
        } 
        else if (this.actionType === this.updateActionType) {
            actionPromise = await submitUpdateFraudCase({ payload });
        } 
        else {
            actionPromise = await submitCreateFraudCase({ payload });
        }
        if (actionPromise && actionPromise.success) {
            this.showSuccessToast(
                this.labels.responseSuccess,
                actionPromise.message
            );
            // Notify parent to reload
            this.dispatchEvent(new CustomEvent('fraudcasesuccess', {
                detail: { message: actionPromise.message },
                bubbles: true,
                composed: true
            }));
        } else {
            this.showErrorToast(
                this.labels.responseFailed,
                actionPromise.message
            );
        }
    
        this.resultMessage = actionPromise?.message;
    
    }
    

    cancelPreview() {
        this.showPreview = false;
    }
}