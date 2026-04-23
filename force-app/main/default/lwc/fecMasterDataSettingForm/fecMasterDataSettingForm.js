import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import getAdditionalFieldOptions from '@salesforce/apex/FEC_MasterDataSettingController.getAdditionalFieldOptions';
import checkParentDuplicateProperty from '@salesforce/apex/FEC_MasterDataSettingController.checkParentDuplicateProperty';

import getChannels from '@salesforce/apex/FEC_MasterDataSettingController.getChannels';
import getUserRoles from '@salesforce/apex/FEC_MasterDataSettingController.getUserRoles';

import MDM_MASTER_DATA_SETTING_OBJECT from '@salesforce/schema/FEC_MDM_Master_Data_Setting__c';
import MASKING_TYPE_FIELD from '@salesforce/schema/FEC_MDM_Master_Data_Setting__c.FEC_Masking_Type__c';
import EDITABLE_USER_GROUP_FIELD from '@salesforce/schema/FEC_MDM_Master_Data_Setting__c.FEC_Editable_User_Group__c';

import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_LABEL_CHANNEL_MULTISELECT from '@salesforce/label/c.FEC_Label_Channel_Multiselect';
import LABEL_LABEL_APPLICABLE_ROLES from '@salesforce/label/c.FEC_Label_Applicable_Roles';

import { FIELD_FIELD_ORDER_DISPLAY, OBJECT_MDM_MASTER_DATA_SETTING, FIELD_ADDITIONAL_FIELD, FIELD_FIELD_STATUS, FIELD_FIELD_READONLY, FIELD_FIELD_MANDATORY, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, FIELD_NATURE_OF_CASE, FIELD_STAGE_NAME, DATA_NAME_CHANNELS, DATA_NAME_ROLES, FIELD_SECTION, FIELD_FIELD_OBJECT_NAME, FIELD_FIELD_API_NAME, FIELD_FIELD_LABEL_NAME, FIELD_ID, FIELD_FIELD_MASKING, FIELD_MASKING_TYPE, FIELD_FIELD_REVERTED, FIELD_SUB_SECTION, FIELD_SUB_SECTION_FIELD_LAYOUT, FIELD_SUB_SECTION_LAYOUT, FIELD_SUB_SECTION_ORDER, FIELD_EDITABLE_USER_GROUP, DATA_NAME_EDITABLE_USER_GROUPS, FIELD_FIELD_EDITABLE, FIELD_EDITABLE_ROLE, DEFAULT_CHANNEL_INTEGRATION_CODE } from 'c/fecConstants';
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

    selectedChannel = '';
    @track selectedRoles = [];
    @track selectedEditableUserGroups = [];
    @track channelOptions = [];
    @track roleOptions = [];
    @track additionalFieldOptions = [];
    @track maskingTypeOptions = [];
    propertyInfoMap = new Map(); // Map<Id, {name, fieldApiName}> for auto-fill
    @track editableUserGroupOptions = [];
    @track displayOrder;
    @track formData = {
        additionalField: '',
        section: '',
        fieldStatus: true,
        fieldReadOnly: false,
        fieldMandatory: false,
        fieldObjectName: '',
        fieldApiName: '',
        fieldLabelName: '',
        fieldMasking: false,
        maskingType: '',
        fieldReverted: false,
        subSection: '',
        subSectionFieldLayout: 3,
        subSectionLayout: 12,
        subSectionOrder: null,
        editableUserGroup: '',
        fieldEditable: false,
        editableRole: ''
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
    dataNameEditableUserGroups = DATA_NAME_EDITABLE_USER_GROUPS;

    get isEditMode() {
        return !!this.recordId;
    }

    get isCreateMode() {
        return !this.recordId;
    }

    /**
     * @description Check if field info is auto-filled from Property.
     * When true, Object Name, API Name, and Label fields should be read-only.
     */
    get isAutoFilled() {
        if (!this.formData.additionalField) return false;
        const info = this.propertyInfoMap.get(this.formData.additionalField);
        return info && info.fieldApiName ? true : false;
    }

    @api
    submitForm() {
        if (this.isEditMode) {
            this.handleSubmitEdit();
        } else {
            this.handleCreateSubmit();
        }
    }

    connectedCallback() {
        if (!this.recordId) {
            // Create mode
            this.displayOrder = this.nextOrder;
            
            // Integration Mode: Set FIMA defaults
            if (this.isIntegrationMode) {
                this.displayOrder = 1;
                this.selectedChannel = DEFAULT_CHANNEL_INTEGRATION_CODE;
                this.formData.additionalField = DEFAULT_CHANNEL_INTEGRATION_CODE;
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
            const rolesStr = data.FEC_Applicable_Role__c || '';
            const section = data.FEC_Section__c || '';
            const order = data.FEC_Field_Order_Display__c || 0;
            const status = data.FEC_Field_Status__c || false;
            const readOnly = data.FEC_Field_ReadOnly__c || false;
            const mandatory = data.FEC_Field_Mandatory__c || false;
            const additionalField = data.FEC_Additional_Field__c || '';

            const fieldObjectName = data.FEC_Field_Object_Name__c || '';
            const fieldApiName = data.FEC_Field_API_Name__c || '';
            const fieldLabelName = data.FEC_Field_Label_Name__c || '';

            const fieldMasking = data.FEC_Field_Masking__c || false;
            const maskingType = data.FEC_Masking_Type__c || '';
            const fieldReverted = data.FEC_Field_Reverted__c || false;
            const subSection = data.FEC_Sub_Section__c || '';
            const subSectionFieldLayout = data.FEC_Sub_Section_Field_Layout__c || null;
            const subSectionLayout = data.FEC_Sub_Section_Layout__c || null;
            const subSectionOrder = data.FEC_Sub_Section_Order__c || null;
            const editableUserGroupStr = data.FEC_Editable_User_Group__c || '';
            const fieldEditable = data.FEC_Field_Editable__c || false;
            const editableRole = data.FEC_Editable_Role__c || '';

            this.selectedChannel = data.FEC_MDM_Channel__c || (data.FEC_MDM_Channel__r ? data.FEC_MDM_Channel__r.Id : '') || '';
            this.selectedRoles = rolesStr ? rolesStr.split(',').map(item => item.trim()) : [];
            this.selectedEditableUserGroups = editableUserGroupStr ? editableUserGroupStr.split(';').map(item => item.trim()) : [];
            this.displayOrder = order;
            this.formData = {
                additionalField: additionalField,
                section: section,
                fieldStatus: status,
                fieldReadOnly: readOnly,
                fieldMandatory: mandatory,
                fieldObjectName,
                fieldApiName,
                fieldLabelName,
                fieldMasking,
                maskingType,
                fieldReverted,
                subSection,
                subSectionFieldLayout,
                subSectionLayout,
                subSectionOrder,
                editableUserGroup: editableUserGroupStr,
                fieldEditable,
                editableRole
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
        if (data) {
            this.additionalFieldOptions = data;
            // Build propertyInfoMap for auto-fill (Phase 3)
            this.propertyInfoMap = new Map();
            data.forEach(opt => {
                this.propertyInfoMap.set(opt.value, {
                    name: opt.label,
                    fieldApiName: opt.fieldApiName || ''
                });
            });
        }
    }

    @wire(getObjectInfo, { objectApiName: MDM_MASTER_DATA_SETTING_OBJECT })
    mdmObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$mdmObjectInfo.data.defaultRecordTypeId', fieldApiName: MASKING_TYPE_FIELD })
    wiredMaskingTypeValues({ data }) {
        if (data) {
            this.maskingTypeOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$mdmObjectInfo.data.defaultRecordTypeId', fieldApiName: EDITABLE_USER_GROUP_FIELD })
    wiredEditableUserGroupValues({ data }) {
        if (data) {
            this.editableUserGroupOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        }
    }

    // Handle input change for create mode
    handleInputChange(event) {
        const fieldName = event.target.dataset.fieldName;
        // Use nullish coalescing to properly handle falsy values like 0 and ""
        const value = event.detail?.value ?? event.target.value;

        showLog('[handleInputChange] Field:', fieldName, 'Value:', value);

        if (fieldName === 'FEC_Additional_Field__c') {
            this.formData = { ...this.formData, additionalField: value };
            // Auto-fill from Property info (Phase 3)
            const info = this.propertyInfoMap.get(value);
            if (info && info.fieldApiName) {
                this.formData = {
                    ...this.formData,
                    additionalField: value,
                    fieldObjectName: 'FEC_Additional_Info__c',
                    fieldApiName: info.fieldApiName,
                    fieldLabelName: info.name
                };
            } else {
                // Always set Object Name when a Property is selected
                this.formData = {
                    ...this.formData,
                    additionalField: value,
                    fieldObjectName: value ? 'FEC_Additional_Info__c' : '',
                    fieldApiName: value ? this.formData.fieldApiName : '',
                    fieldLabelName: value ? this.formData.fieldLabelName : ''
                };
            }
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
        } else if (fieldName === 'FEC_Field_Object_Name__c') {
            this.formData = { ...this.formData, fieldObjectName: value };
        } else if (fieldName === 'FEC_Field_API_Name__c') {
            this.formData = { ...this.formData, fieldApiName: value };
        } else if (fieldName === 'FEC_Field_Label_Name__c') {
            this.formData = { ...this.formData, fieldLabelName: value };
        } else if (fieldName === 'FEC_Field_Masking__c') {
            this.formData = { ...this.formData, fieldMasking: event.detail.checked };
        } else if (fieldName === 'FEC_Masking_Type__c') {
            this.formData = { ...this.formData, maskingType: value };
        } else if (fieldName === 'FEC_Field_Reverted__c') {
            this.formData = { ...this.formData, fieldReverted: event.detail.checked };
        } else if (fieldName === 'FEC_Sub_Section__c') {
            this.formData = { ...this.formData, subSection: value };
        } else if (fieldName === 'FEC_Sub_Section_Field_Layout__c') {
            this.formData = { ...this.formData, subSectionFieldLayout: value };
        } else if (fieldName === 'FEC_Sub_Section_Layout__c') {
            this.formData = { ...this.formData, subSectionLayout: value };
        } else if (fieldName === 'FEC_Sub_Section_Order__c') {
            this.formData = { ...this.formData, subSectionOrder: value };
        } else if (fieldName === 'FEC_Field_Editable__c') {
            this.formData = { ...this.formData, fieldEditable: event.detail.checked };
        } else if (fieldName === 'FEC_Editable_Role__c') {
            this.formData = { ...this.formData, editableRole: value };
        }

        showLog('[handleInputChange] Updated formData:', this.formData);
    }

    handleChannelChange(event) {
        this.selectedChannel = event.detail.value;
    }

    handleSelectCustom(event) {
        const field = event.target.dataset.name;
        const value = event.detail.value;

        // Prevent adding empty values
        if (!value) return;

        if (field === DATA_NAME_ROLES && !this.selectedRoles.includes(value)) {
            this.selectedRoles = [...this.selectedRoles, value];
            this.clearCombobox(event.target);
        } else if (field === DATA_NAME_EDITABLE_USER_GROUPS && !this.selectedEditableUserGroups.includes(value)) {
            this.selectedEditableUserGroups = [...this.selectedEditableUserGroups, value];
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
        if (field === DATA_NAME_ROLES) {
            this.selectedRoles = this.selectedRoles.filter(v => v !== value);
        } else if (field === DATA_NAME_EDITABLE_USER_GROUPS) {
            this.selectedEditableUserGroups = this.selectedEditableUserGroups.filter(v => v !== value);
        }
    }

    handleSubmit(event) {
        event.preventDefault();

        // Validate single-select channel
        if (!this.selectedChannel) {
            this.showToast('', 'Please select a Channel', 'error');
            return;
        }

        if (this.selectedRoles.length === 0) {
            this.showToast('', 'Please select at least one Applicable Role', 'error');
            return;
        }

        try {
            const fields = event.detail.fields || {};
            fields['FEC_MDM_Channel__c'] = this.selectedChannel || null;
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
        showLog('[handleCreateSubmit] START');

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

        if (!this.selectedChannel) {
            this.showToast('', 'Please select a Channel', 'error');
            return;
        }
        if (this.selectedRoles.length === 0) {
            this.showToast('', 'Please select at least one Applicable Role', 'error');
            return;
        }

        // Check parent node duplicate trước khi save
        checkParentDuplicateProperty({
            nocId: this.natureOfCaseId,
            stageId: this.stageId,
            additionalFieldId: this.formData.additionalField,
            channelId: this.selectedChannel,
            applicableRole: this.selectedRoles.join(', ')
        })
            .then(parentNodeName => {
                if (parentNodeName) {
                    this.showToast(
                        'Warning',
                        `This property already exists at parent node "${parentNodeName}" with the same Channel. Cannot add duplicate.`,
                        'warning'
                    );
                    return;
                }
                // Không trùng → tiến hành save
                this._doCreateSave(trimmedSection);
            })
            .catch(error => {
                console.error('Error checking parent duplicate:', error);
                // Nếu check lỗi, vẫn cho save (không block user)
                this._doCreateSave(trimmedSection);
            });
    }

    /**
     * Thực hiện save sau khi đã pass duplicate check
     * @param {String} trimmedSection
     */
    _doCreateSave(trimmedSection) {
        try {
            const mappingReq = {
                [FIELD_ADDITIONAL_FIELD]: this.formData.additionalField,
                // Ensure we don't save whitespace-only strings
                [FIELD_SECTION]: trimmedSection || null,
                ['FEC_MDM_Channel__c']: this.selectedChannel || null,
                [FIELD_APPLICABLE_ROLE]: this.selectedRoles.join(', '),
                [FIELD_FIELD_ORDER_DISPLAY]: this.displayOrder || 0,
                [FIELD_FIELD_STATUS]: this.formData.fieldStatus,
                [FIELD_FIELD_READONLY]: this.formData.fieldReadOnly,
                [FIELD_FIELD_MANDATORY]: this.formData.fieldMandatory,
                [FIELD_NATURE_OF_CASE]: this.natureOfCaseId,
                [FIELD_STAGE_NAME]: this.stageId,
                [FIELD_FIELD_OBJECT_NAME]: this.formData.fieldObjectName || null,
                [FIELD_FIELD_API_NAME]: this.formData.fieldApiName || null,
                [FIELD_FIELD_LABEL_NAME]: this.formData.fieldLabelName || null,
                [FIELD_FIELD_MASKING]: this.formData.fieldMasking,
                [FIELD_MASKING_TYPE]: this.formData.maskingType || null,
                [FIELD_FIELD_REVERTED]: this.formData.fieldReverted,
                [FIELD_SUB_SECTION]: this.formData.subSection || null,
                [FIELD_SUB_SECTION_FIELD_LAYOUT]: this.formData.subSectionFieldLayout || null,
                [FIELD_SUB_SECTION_LAYOUT]: this.formData.subSectionLayout || null,
                [FIELD_SUB_SECTION_ORDER]: this.formData.subSectionOrder || null,
                [FIELD_EDITABLE_USER_GROUP]: this.selectedEditableUserGroups.join(';') || null,
                [FIELD_FIELD_EDITABLE]: this.formData.fieldEditable,
                [FIELD_EDITABLE_ROLE]: this.formData.editableRole || null
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
        showLog('[handleSubmitEdit] Selected Channel:', this.selectedChannel);
        showLog('[handleSubmitEdit] Selected Roles:', this.selectedRoles);
        showLog('[handleSubmitEdit] Display Order:', this.displayOrder);

        // Validation - Trimming whitespace and making sure content exists
        const trimmedSection = this.formData.section ? this.formData.section.trim() : '';

        if (!this.formData.additionalField) {
            this.showToast('', 'Please select Additional Field', 'error');
            return;
        }
        if (!this.selectedChannel) {
            this.showToast('', 'Please select a Channel', 'error');
            return;
        }
        if (this.selectedRoles.length === 0) {
            this.showToast('', 'Please select at least one Applicable Role', 'error');
            return;
        }

        try {
            const mappingReq = {
                [FIELD_ID]: this.recordId,
                [FIELD_ADDITIONAL_FIELD]: this.formData.additionalField,
                // Ensure we don't save whitespace-only strings
                [FIELD_SECTION]: trimmedSection || null,
                ['FEC_MDM_Channel__c']: this.selectedChannel || null,
                [FIELD_APPLICABLE_ROLE]: this.selectedRoles.join(', '),
                [FIELD_FIELD_ORDER_DISPLAY]: this.displayOrder || 0,
                [FIELD_FIELD_STATUS]: this.formData.fieldStatus,
                [FIELD_FIELD_READONLY]: this.formData.fieldReadOnly,
                [FIELD_FIELD_MANDATORY]: this.formData.fieldMandatory,
                [FIELD_NATURE_OF_CASE]: this.natureOfCaseId,
                [FIELD_STAGE_NAME]: this.stageId,
                [FIELD_FIELD_OBJECT_NAME]: this.formData.fieldObjectName || null,
                [FIELD_FIELD_API_NAME]: this.formData.fieldApiName || null,
                [FIELD_FIELD_LABEL_NAME]: this.formData.fieldLabelName || null,
                [FIELD_FIELD_MASKING]: this.formData.fieldMasking,
                [FIELD_MASKING_TYPE]: this.formData.maskingType || null,
                [FIELD_FIELD_REVERTED]: this.formData.fieldReverted,
                [FIELD_SUB_SECTION]: this.formData.subSection || null,
                [FIELD_SUB_SECTION_FIELD_LAYOUT]: this.formData.subSectionFieldLayout || null,
                [FIELD_SUB_SECTION_LAYOUT]: this.formData.subSectionLayout || null,
                [FIELD_SUB_SECTION_ORDER]: this.formData.subSectionOrder || null,
                [FIELD_EDITABLE_USER_GROUP]: this.selectedEditableUserGroups.join(';') || null,
                [FIELD_FIELD_EDITABLE]: this.formData.fieldEditable,
                [FIELD_EDITABLE_ROLE]: this.formData.editableRole || null
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