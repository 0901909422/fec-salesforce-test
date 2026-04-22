import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import getAdditionalFieldOptions from '@salesforce/apex/FEC_MasterDataSettingController.getAdditionalFieldOptions';

import getChannels from '@salesforce/apex/FEC_MasterDataSettingController.getChannels';
import getUserRoles from '@salesforce/apex/FEC_MasterDataSettingController.getUserRoles';

import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_LABEL_CHANNEL_MULTISELECT from '@salesforce/label/c.FEC_Label_Channel_Multiselect';
import LABEL_LABEL_APPLICABLE_ROLES from '@salesforce/label/c.FEC_Label_Applicable_Roles';

import { FIELD_FIELD_ORDER_DISPLAY, OBJECT_MDM_MASTER_DATA_SETTING, FIELD_ADDITIONAL_FIELD, FIELD_FIELD_STATUS, FIELD_FIELD_READONLY, FIELD_FIELD_MANDATORY, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, FIELD_NATURE_OF_CASE, FIELD_STAGE_NAME, DATA_NAME_CHANNELS, DATA_NAME_ROLES, FIELD_SECTION } from 'c/fecConstants';
import { showLog } from 'c/fecMDMUtils';

const FIELDS = [
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_CHANNEL}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_APPLICABLE_ROLE}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_FIELD_STATUS}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_FIELD_READONLY}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_FIELD_MANDATORY}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_SECTION}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_FIELD_ORDER_DISPLAY}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_ADDITIONAL_FIELD}`
];

export default class FecMasterDataSettingForm extends LightningElement {
    @api recordId;
    @api recordData;
    @api natureOfCaseId;
    @api stageId;
    @api nextOrder;
    @api isIntegrationMode = false;

    @track selectedChannels = [];
    @track selectedRoles = [];
    @track channelOptions = [];
    @track roleOptions = [];
    @track additionalFieldOptions = [];
    @track displayOrder;
    @track formData = {
        additionalField: '',
        section: '',
        fieldStatus: true,
        fieldReadOnly: false,
        fieldMandatory: false
    };

    // expose labels and field names
    labelCancel = LABEL_BUTTON_CANCEL;
    labelSave = LABEL_BUTTON_SAVE;
    fieldOrderDisplay = FIELD_FIELD_ORDER_DISPLAY;
    objectApiName = OBJECT_MDM_MASTER_DATA_SETTING;
    fieldAdditionalField = FIELD_ADDITIONAL_FIELD;
    fieldSection = FIELD_SECTION;
    fieldOrder = FIELD_FIELD_ORDER_DISPLAY;
    fieldStatus = FIELD_FIELD_STATUS;
    fieldReadOnly = FIELD_FIELD_READONLY;
    fieldMandatory = FIELD_FIELD_MANDATORY;
    labelChannelMultiselect = LABEL_LABEL_CHANNEL_MULTISELECT;
    labelApplicableRoles = LABEL_LABEL_APPLICABLE_ROLES;
    dataNameChannels = DATA_NAME_CHANNELS;
    dataNameRoles = DATA_NAME_ROLES;

    get isEditMode() {
        return !!this.recordId;
    }

    get isCreateMode() {
        return !this.recordId;
    }

    connectedCallback() {
        if (!this.recordId) {
            // Create mode
            this.displayOrder = this.nextOrder;
            
            // Integration Mode: Set FIMA defaults
            if (this.isIntegrationMode) {
                this.displayOrder = 1;
                this.selectedChannels = ['FIMA'];
                this.formData.additionalField = 'FIMA';
                showLog('[connectedCallback] Integration Mode activated - Set FIMA defaults');
            }
        } else if (this.recordData && Object.keys(this.recordData).length > 0) {
            // Edit mode - populate form from recordData passed from parent
            this.populateFormFromRecordData(this.recordData);
        }
    }

    /**
     * @description Populate form fields from recordData passed by parent component
     */
    populateFormFromRecordData(data) {
        showLog('[populateFormFromRecordData] START with data:', data);
        try {
            const channelsStr = data.FEC_Channel__c || '';
            const rolesStr = data.FEC_Applicable_Role__c || '';
            const section = data.FEC_Section__c || '';
            const order = data.FEC_Field_Order_Display__c || 0;
            const status = data.FEC_Field_Status__c || false;
            const readOnly = data.FEC_Field_ReadOnly__c || false;
            const mandatory = data.FEC_Field_Mandatory__c || false;
            const additionalField = data.FEC_Additional_Field__c || '';

            this.selectedChannels = channelsStr ? channelsStr.split(',').map(item => item.trim()) : [];
            this.selectedRoles = rolesStr ? rolesStr.split(',').map(item => item.trim()) : [];
            this.displayOrder = order;
            this.formData = {
                additionalField: additionalField,
                section: section,
                fieldStatus: status,
                fieldReadOnly: readOnly,
                fieldMandatory: mandatory
            };
            showLog('[populateFormFromRecordData] Form populated successfully');
        } catch (error) {
            showLog('[populateFormFromRecordData] Error:', error);
        }
    }


    @wire(getChannels)
    wiredChannels({ data }) {
        if (data) this.channelOptions = data;
    }

    @wire(getUserRoles)
    wiredRoles({ data }) {
        if (data) this.roleOptions = data;
    }

    @wire(getAdditionalFieldOptions)
    wiredAdditionalFields({ data }) {
        if (data) this.additionalFieldOptions = data;
    }

    // Handle input change for create mode
    handleInputChange(event) {
        const fieldName = event.target.dataset.fieldName;
        const value = event.detail?.value || event.target.value;

        showLog('[handleInputChange] Field:', fieldName, 'Value:', value);

        if (fieldName === 'FEC_Additional_Field__c') {
            this.formData = { ...this.formData, additionalField: value };
        } else if (fieldName === 'FEC_Section__c') {
            this.formData = { ...this.formData, section: value };
        } else if (fieldName === 'FEC_Field_Order_Display__c') {
            this.displayOrder = value;
        } else if (fieldName === 'FEC_Field_Status__c') {
            this.formData = { ...this.formData, fieldStatus: event.detail.checked };
        } else if (fieldName === 'FEC_Field_ReadOnly__c') {
            this.formData = { ...this.formData, fieldReadOnly: event.detail.checked };
        } else if (fieldName === 'FEC_Field_Mandatory__c') {
            this.formData = { ...this.formData, fieldMandatory: event.detail.checked };
        }

        showLog('[handleInputChange] Updated formData:', this.formData);
    }

    handleSelectCustom(event) {
        const field = event.target.dataset.name;
        const value = event.detail.value;

        // Prevent adding empty values
        if (!value) return;

        if (field === DATA_NAME_CHANNELS && !this.selectedChannels.includes(value)) {
            this.selectedChannels = [...this.selectedChannels, value];
            this.clearCombobox(event.target);
        } else if (field === DATA_NAME_ROLES && !this.selectedRoles.includes(value)) {
            this.selectedRoles = [...this.selectedRoles, value];
            this.clearCombobox(event.target);
        }
    }

    clearCombobox(combobox) {
        // Reset combobox value to trigger re-render
        combobox.value = '';
    }

    handleRemoveCustom(event) {
        const field = event.target.dataset.name;
        const value = event.target.name;
        if (field === DATA_NAME_CHANNELS) {
            this.selectedChannels = this.selectedChannels.filter(v => v !== value);
        } else if (field === DATA_NAME_ROLES) {
            this.selectedRoles = this.selectedRoles.filter(v => v !== value);
        }
    }

    handleSubmit(event) {
        event.preventDefault();

        // Validate multi-select fields - Set title to empty string
        if (this.selectedChannels.length === 0) {
            this.showToast('', 'Please select at least one Channel', 'error');
            return;
        }

        if (this.selectedRoles.length === 0) {
            this.showToast('', 'Please select at least one Applicable Role', 'error');
            return;
        }

        try {
            const fields = event.detail.fields || {};
            fields[FIELD_CHANNEL] = this.selectedChannels.join(', ');
            fields[FIELD_APPLICABLE_ROLE] = this.selectedRoles.join(', ');
            fields[FIELD_NATURE_OF_CASE] = this.natureOfCaseId;
            fields[FIELD_STAGE_NAME] = this.stageId;

            this.template.querySelector('lightning-record-edit-form').submit(fields);
        } catch (error) {
            console.error('Error during form submission:', error);
            this.showToast('Error', 'An error occurred while submitting the form', 'error');
        }
    }

    handleCreateSubmit() {
        showLog('[handleSuccess] START - refreshing data');

        // Validation - Trimming whitespace and making sure content exists
        const trimmedSection = this.formData.section ? this.formData.section.trim() : '';

        if (!this.formData.additionalField) {
            this.showToast('', 'Please select Additional Field', 'error');
            return;
        }

        // Additional Validation: Check for duplicate Additional Field in create mode
        if (this.recordData && this.recordData.existingFields && this.recordData.existingFields.includes(this.formData.additionalField)) {
            this.showToast('', 'This Additional Field already exists. Please select a different one.', 'error');
            return;
        }

        if (this.selectedChannels.length === 0) {
            this.showToast('', 'Please select at least one Channel', 'error');
            return;
        }
        if (this.selectedRoles.length === 0) {
            this.showToast('', 'Please select at least one Applicable Role', 'error');
            return;
        }

        try {
            const mappingReq = {
                [FIELD_ADDITIONAL_FIELD]: this.formData.additionalField,
                // Ensure we don't save whitespace-only strings
                [FIELD_SECTION]: trimmedSection || null,
                [FIELD_CHANNEL]: this.selectedChannels.join(', '),
                [FIELD_APPLICABLE_ROLE]: this.selectedRoles.join(', '),
                [FIELD_FIELD_ORDER_DISPLAY]: this.displayOrder || 0,
                [FIELD_FIELD_STATUS]: this.formData.fieldStatus,
                [FIELD_FIELD_READONLY]: this.formData.fieldReadOnly,
                [FIELD_FIELD_MANDATORY]: this.formData.fieldMandatory,
                [FIELD_NATURE_OF_CASE]: this.natureOfCaseId,
                [FIELD_STAGE_NAME]: this.stageId
            };

            saveMasterDataSetting({ mappingReq })
                .then(result => {
                    if (result) {
                        this.showToast('Success', 'Master Data Setting created successfully', 'success');

                        // Dispatch event immediately for modal closure and data refresh
                        try {
                            this.dispatchEvent(new CustomEvent('success', {
                                detail: { id: result },
                                bubbles: true,
                                composed: true
                            }));
                        } catch (eventError) {
                            console.error('Error dispatching success event:', eventError);
                        }
                    } else {
                        this.showToast('Error', 'No ID returned from save operation', 'error');
                    }
                })
                .catch(error => {
                    let errorMessage = 'An error occurred while saving';
                    if (error) {
                        if (error.body && error.body.message) {
                            errorMessage = error.body.message;
                        } else if (error.message) {
                            errorMessage = error.message;
                        }
                    }
                    this.showToast('Error', errorMessage, 'error');
                    console.error('Error saving Master Data Setting:', error);
                });
        } catch (error) {
            console.error('Error in handleCreateSubmit:', error);
            this.showToast('Error', 'An unexpected error occurred', 'error');
        }
    }

    handleSuccess(result) {
        this.dispatchEvent(new CustomEvent('success', { detail: result }));
    }

    handleSubmitEdit() {
        showLog('[handleSubmitEdit] START - Saving edit with all fields editable');
        showLog('[handleSubmitEdit] Current formData:', this.formData);
        showLog('[handleSubmitEdit] Selected Channels:', this.selectedChannels);
        showLog('[handleSubmitEdit] Selected Roles:', this.selectedRoles);
        showLog('[handleSubmitEdit] Display Order:', this.displayOrder);

        // Validation - Trimming whitespace and making sure content exists
        const trimmedSection = this.formData.section ? this.formData.section.trim() : '';

        if (!this.formData.additionalField) {
            this.showToast('', 'Please select Additional Field', 'error');
            return;
        }
        if (this.selectedChannels.length === 0) {
            this.showToast('', 'Please select at least one Channel', 'error');
            return;
        }
        if (this.selectedRoles.length === 0) {
            this.showToast('', 'Please select at least one Applicable Role', 'error');
            return;
        }

        try {
            const mappingReq = {
                Id: this.recordId,
                FEC_Additional_Field__c: this.formData.additionalField,
                // Ensure we don't save whitespace-only strings
                FEC_Section__c: trimmedSection || null,
                FEC_Channel__c: this.selectedChannels.join(', '),
                FEC_Applicable_Role__c: this.selectedRoles.join(', '),
                FEC_Field_Order_Display__c: this.displayOrder || 0,
                FEC_Field_Status__c: this.formData.fieldStatus,
                FEC_Field_ReadOnly__c: this.formData.fieldReadOnly,
                FEC_Field_Mandatory__c: this.formData.fieldMandatory,
                FEC_Nature_Of_Case__c: this.natureOfCaseId,
                FEC_Stage_Name__c: this.stageId
            };

            showLog('[handleSubmitEdit] Mapping Request:', mappingReq);

            saveMasterDataSetting({ mappingReq })
                .then(() => {
                    this.showToast('Success', 'Master Data Setting updated successfully', 'success');
                    this.dispatchEvent(new CustomEvent('success', {
                        detail: { id: this.recordId },
                        bubbles: true,
                        composed: true
                    }));
                })
                .catch(error => {
                    let errorMessage = 'An error occurred while saving';
                    if (error && error.body && error.body.message) {
                        errorMessage = error.body.message;
                    } else if (error && error.message) {
                        errorMessage = error.message;
                    }
                    showLog('[handleSubmitEdit] Error:', error);
                    this.showToast('Error', errorMessage, 'error');
                });
        } catch (error) {
            console.error('Error in handleSubmitEdit:', error);
            this.showToast('Error', 'An unexpected error occurred', 'error');
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleError(event) {
        try {
            let errorMessage = 'An error occurred while saving';

            // Try to extract error message from event detail
            if (event && event.detail) {
                if (event.detail.output && event.detail.output.errors && Array.isArray(event.detail.output.errors) && event.detail.output.errors.length > 0) {
                    errorMessage = event.detail.output.errors[0].message || errorMessage;
                } else if (event.detail.message) {
                    errorMessage = event.detail.message;
                }
            }

            this.showToast('Error', errorMessage, 'error');
            console.error('Form error details:', event.detail);
        } catch (error) {
            console.error('Error in handleError method:', error);
            this.showToast('Error', 'An unexpected error occurred while saving', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}