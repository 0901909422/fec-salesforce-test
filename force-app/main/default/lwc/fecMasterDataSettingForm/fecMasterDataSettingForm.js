import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import getAdditionalFieldOptions from '@salesforce/apex/FEC_MasterDataSettingController.getAdditionalFieldOptions';
import checkParentDuplicateProperty from '@salesforce/apex/FEC_MasterDataSettingController.checkParentDuplicateProperty';
import getSubSectionOrderMap from '@salesforce/apex/FEC_MasterDataSettingController.getSubSectionOrderMap';

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
    @api nocUserGroup = '';

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
    @track selectedColumnCount = '4'; // Virtual field: number of columns (default 4 → 12/4=3)
    @track formData = {
        additionalField: '',
        section: 'Case Information',
        fieldStatus: true,
        fieldReadOnly: false,
        fieldMandatory: false,
        fieldObjectName: '',
        fieldApiName: '',
        fieldLabelName: '',
        fieldMasking: false,
        maskingType: '',
        fieldReverted: false,
        subSection: 'Property Info',
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

    // Search state for custom search dropdowns
    additionalFieldSearchTerm = '';
    isAdditionalFieldDropdownOpen = false;
    roleSearchTerm = '';
    isRoleDropdownOpen = false;
    editableRoleSearchTerm = '';
    isEditableRoleDropdownOpen = false;
    @track selectedEditableRoles = [];
    channelSearchTerm = '';
    isChannelDropdownOpen = false;
    isSaving = false;

    // Filtered options for search dropdowns
    get filteredAdditionalFieldOptions() {
        if (!this.additionalFieldOptions) return [];
        if (!this.additionalFieldSearchTerm || !this.additionalFieldSearchTerm.trim()) {
            return this.additionalFieldOptions;
        }
        const key = this.additionalFieldSearchTerm.toLowerCase().trim();
        return this.additionalFieldOptions.filter(opt =>
            (opt.label || '').toLowerCase().includes(key)
        );
    }

    get filteredRoleOptions() {
        if (!this.roleOptions) return [];
        if (!this.roleSearchTerm || !this.roleSearchTerm.trim()) {
            return this.roleOptions;
        }
        const key = this.roleSearchTerm.toLowerCase().trim();
        return this.roleOptions.filter(opt =>
            (opt.label || '').toLowerCase().includes(key)
        );
    }

    // Additional Field search handlers
    handleAdditionalFieldSearch(event) {
        this.additionalFieldSearchTerm = event.target.value;
        this.isAdditionalFieldDropdownOpen = true;
    }
    handleAdditionalFieldFocus() { this.isAdditionalFieldDropdownOpen = true; }
    handleAdditionalFieldBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.isAdditionalFieldDropdownOpen = false; }, 200);
    }
    handleSelectAdditionalField(event) {
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        this.additionalFieldSearchTerm = selectedLabel;
        this.isAdditionalFieldDropdownOpen = false;
        // Trigger same logic as handleInputChange for FEC_Additional_Field__c
        this.formData = { ...this.formData, additionalField: selectedValue };
        const info = this.propertyInfoMap.get(selectedValue);
        if (info && info.fieldApiName) {
            this.formData = {
                ...this.formData,
                additionalField: selectedValue,
                fieldObjectName: 'FEC_Additional_Info__c',
                fieldApiName: info.fieldApiName,
                fieldLabelName: info.name
            };
        } else {
            this.formData = {
                ...this.formData,
                additionalField: selectedValue,
                fieldObjectName: selectedValue ? 'FEC_Additional_Info__c' : '',
                fieldApiName: selectedValue ? this.formData.fieldApiName : '',
                fieldLabelName: selectedValue ? this.formData.fieldLabelName : ''
            };
        }
    }

    // Role search handlers
    handleRoleSearch(event) {
        this.roleSearchTerm = event.target.value;
        this.isRoleDropdownOpen = true;
    }
    handleRoleFocus() { this.isRoleDropdownOpen = true; }
    handleRoleBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.isRoleDropdownOpen = false; }, 200);
    }
    handleSelectRoleFromList(event) {
        const selectedRole = event.currentTarget.dataset.value;
        if (selectedRole && !this.selectedRoles.includes(selectedRole)) {
            this.selectedRoles = [...this.selectedRoles, selectedRole];
        }
        this.roleSearchTerm = '';
        this.isRoleDropdownOpen = false;
    }

    handleDropdownItemHover(event) {
        event.currentTarget.style.backgroundColor = '#f3f3f3';
        event.currentTarget.addEventListener('mouseleave', (e) => {
            e.currentTarget.style.backgroundColor = '#ffffff';
        }, { once: true });
    }

    // Channel search handlers (single-select)
    get filteredChannelOptions() {
        if (!this.channelOptions) return [];
        if (!this.channelSearchTerm || !this.channelSearchTerm.trim()) {
            return this.channelOptions;
        }
        const key = this.channelSearchTerm.toLowerCase().trim();
        return this.channelOptions.filter(opt =>
            (opt.label || '').toLowerCase().includes(key)
        );
    }
    handleChannelSearch(event) {
        this.channelSearchTerm = event.target.value;
        this.isChannelDropdownOpen = true;
    }
    handleChannelFocus() { this.isChannelDropdownOpen = true; }
    handleChannelBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.isChannelDropdownOpen = false; }, 200);
    }
    handleSelectChannel(event) {
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        this.selectedChannel = selectedValue;
        this.channelSearchTerm = selectedLabel;
        this.isChannelDropdownOpen = false;
    }

    // Editable Role search handlers (uses same roleOptions as Applicable Roles)
    get filteredEditableRoleOptions() {
        if (!this.roleOptions) return [];
        if (!this.editableRoleSearchTerm || !this.editableRoleSearchTerm.trim()) {
            return this.roleOptions;
        }
        const key = this.editableRoleSearchTerm.toLowerCase().trim();
        return this.roleOptions.filter(opt =>
            (opt.label || '').toLowerCase().includes(key)
        );
    }
    handleEditableRoleSearch(event) {
        this.editableRoleSearchTerm = event.target.value;
        this.isEditableRoleDropdownOpen = true;
    }
    handleEditableRoleFocus() { this.isEditableRoleDropdownOpen = true; }
    handleEditableRoleBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.isEditableRoleDropdownOpen = false; }, 200);
    }
    handleSelectEditableRoleFromList(event) {
        const selectedRole = event.currentTarget.dataset.value;
        if (selectedRole && !this.selectedEditableRoles.includes(selectedRole)) {
            this.selectedEditableRoles = [...this.selectedEditableRoles, selectedRole];
            this.formData = { ...this.formData, editableRole: this.selectedEditableRoles.join(', ') };
        }
        this.editableRoleSearchTerm = '';
        this.isEditableRoleDropdownOpen = false;
    }
    handleRemoveEditableRole(event) {
        const roleToRemove = event.detail.name;
        if (!roleToRemove) return;
        this.selectedEditableRoles = this.selectedEditableRoles.filter(r => r !== roleToRemove);
        this.formData = { ...this.formData, editableRole: this.selectedEditableRoles.join(', ') };
    }

    // Section & Sub Section standard options
    get sectionOptions() {
        return [
            { label: 'Case Information', value: 'Case Information' },
            { label: 'Account Information', value: 'Account Information' },
            { label: '-- Custom --', value: '__custom__' }
        ];
    }

    get subSectionOptions() {
        const opts = [];
        if (this.formData.section === 'Case Information') {
            opts.push(
                { label: 'Property Info', value: 'Property Info' },
                { label: 'Case Info', value: 'Case Info' },
                { label: 'Original Information', value: 'Original Information' },
                { label: 'Updated Information', value: 'Updated Information' },
                { label: 'CS SP Assessment', value: 'CS SP Assessment' },
                { label: 'Confirm to CS SP Assessment', value: 'Confirm to CS SP Assessment' },
                { label: 'D2C Assessment', value: 'D2C Assessment' },
                { label: 'Confirm to D2C Assessment', value: 'Confirm to D2C Assessment' }
            );
        } else if (this.formData.section === 'Account Information') {
            opts.push({ label: 'C360 Info', value: 'C360 Info' });
        }
        opts.push({ label: '-- Custom --', value: '__custom__' });
        return opts;
    }

    get isCustomSection() { return this._isCustomSection; }
    get isCustomSubSection() { return this._isCustomSubSection; }
    get isSubSectionOrderReadOnly() { return !this._isCustomSubSection && this.formData.subSectionOrder != null; }
    get showSubSectionOrder() { return this._isCustomSubSection || this.formData.subSectionOrder == null; }
    _isCustomSection = false;
    _isCustomSubSection = false;

    handleSectionChange(event) {
        const value = event.detail.value;
        if (value === '__custom__') {
            this._isCustomSection = true;
            this._isCustomSubSection = true;
            this.formData = { ...this.formData, section: '', subSection: '', subSectionOrder: null };
        } else {
            this._isCustomSection = false;
            this._isCustomSubSection = false;
            let defaultSubSection = '';
            if (value === 'Case Information') defaultSubSection = 'Property Info';
            else if (value === 'Account Information') defaultSubSection = 'C360 Info';
            const order = this.subSectionOrderMap[defaultSubSection] || null;
            this.formData = { ...this.formData, section: value, subSection: defaultSubSection, subSectionOrder: order };
        }
    }

    handleSubSectionChange(event) {
        const value = event.detail.value;
        if (value === '__custom__') {
            this._isCustomSubSection = true;
            this.formData = { ...this.formData, subSection: '', subSectionOrder: null };
        } else {
            this._isCustomSubSection = false;
            // Auto-fill Sub Section Order from existing data
            const order = this.subSectionOrderMap[value] || null;
            this.formData = { ...this.formData, subSection: value, subSectionOrder: order };
        }
    }

    handleCustomSectionInput(event) {
        this.formData = { ...this.formData, section: event.target.value };
    }

    handleCustomSubSectionInput(event) {
        this.formData = { ...this.formData, subSection: event.target.value };
    }

    // Column count options for Sub Section layout (12-column grid)
    get columnCountOptions() {
        return [
            { label: '1', value: '1' },
            { label: '2', value: '2' },
            { label: '3', value: '3' },
            { label: '4', value: '4' },
            { label: '6', value: '6' },
            { label: '12', value: '12' }
        ];
    }

    handleColumnCountChange(event) {
        const cols = parseInt(event.detail.value, 10);
        this.selectedColumnCount = String(cols);
        const fieldLayout = Math.floor(12 / cols);
        this.formData = {
            ...this.formData,
            subSectionLayout: 12,
            subSectionFieldLayout: fieldLayout
        };
    }

    get isEditMode() {
        return !!this.recordId;
    }

    get isCreateMode() {
        return !this.recordId;
    }

    // Conditional visibility getters
    get isFieldActive() { return this.formData.fieldStatus; }
    get showMaskingType() { return this.formData.fieldStatus && this.formData.fieldMasking; }
    get showEditableRole() { return this.formData.fieldStatus && this.formData.fieldEditable; }
    get showFieldReverted() {
        // Field Reverted chỉ hiện khi Additional Field là Updated Info field
        if (!this.formData.additionalField) return false;
        const info = this.propertyInfoMap.get(this.formData.additionalField);
        return info && info.fieldApiName && info.fieldApiName.includes('Updated_Info');
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
            
            // Auto-fill Editable User Group from NOC User Group
            if (this.nocUserGroup) {
                this.selectedEditableUserGroups = this.nocUserGroup.split(';').map(g => g.trim()).filter(g => g);
            }
            
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
            // Set channel search term for display
            if (data.FEC_MDM_Channel__r && data.FEC_MDM_Channel__r.Name) {
                this.channelSearchTerm = data.FEC_MDM_Channel__r.Name;
            }
            this.selectedRoles = rolesStr ? rolesStr.split(',').map(item => item.trim()) : [];
            this.selectedEditableUserGroups = editableUserGroupStr ? editableUserGroupStr.split(';').map(item => item.trim()) : [];
            this.selectedEditableRoles = editableRole ? editableRole.split(',').map(item => item.trim()).filter(item => item) : [];
            this.selectedEditableRoles = editableRole ? editableRole.split(',').map(item => item.trim()).filter(item => item) : [];
            this.displayOrder = order;
            // Reverse-calculate column count from existing layout values
            if (subSectionFieldLayout && subSectionFieldLayout > 0) {
                this.selectedColumnCount = String(Math.floor(12 / subSectionFieldLayout));
            }
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
            // Set search term for Additional Field display in edit mode
            if (additionalField && this.additionalFieldOptions) {
                const match = this.additionalFieldOptions.find(opt => opt.value === additionalField);
                if (match) {
                    this.additionalFieldSearchTerm = match.label;
                }
            }
            // Check if section/sub section are custom (not in standard list)
            const standardSections = ['Case Information', 'Account Information'];
            if (section && !standardSections.includes(section)) {
                this._isCustomSection = true;
                this._isCustomSubSection = true;
            } else {
                this._isCustomSection = false;
                const standardSubSections = {
                    'Case Information': ['Property Info', 'Case Info', 'Original Information', 'Updated Information', 'CS SP Assessment', 'Confirm to CS SP Assessment', 'D2C Assessment', 'Confirm to D2C Assessment'],
                    'Account Information': ['C360 Info']
                };
                const validSubs = standardSubSections[section] || [];
                this._isCustomSubSection = subSection && !validSubs.includes(subSection);
            }
        } catch (error) {
            showLog('[populateFormFromRecordData] Error:', error);
        }
    }


    @wire(getChannels)
    wiredChannels({ data }) {
        if (data) {
            this.channelOptions = data;
            // Set channel search term for edit mode display
            if (this.selectedChannel) {
                const match = data.find(opt => opt.value === this.selectedChannel);
                if (match) this.channelSearchTerm = match.label;
            }
        }
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
            // Set search term display for edit mode (options may load after form data)
            if (this.formData.additionalField) {
                const match = data.find(opt => opt.value === this.formData.additionalField);
                if (match) {
                    this.additionalFieldSearchTerm = match.label;
                }
            }
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

    // Sub Section Order auto-fill map from Live data
    subSectionOrderMap = {};
    @wire(getSubSectionOrderMap)
    wiredSubSectionOrderMap({ data }) {
        if (data) {
            this.subSectionOrderMap = data;
            // Auto-fill Sub Section Order for default sub section (wire loads after connectedCallback)
            if (this.formData.subSection && this.formData.subSectionOrder == null) {
                const order = data[this.formData.subSection];
                if (order != null) {
                    this.formData = { ...this.formData, subSectionOrder: order };
                }
            }
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
            const checked = event.detail.checked;
            // Field Status = false → reset tất cả checkbox khác vì field ẩn hoàn toàn
            if (!checked) {
                this.formData = {
                    ...this.formData,
                    fieldStatus: false,
                    fieldReadOnly: false,
                    fieldMandatory: false,
                    fieldMasking: false,
                    maskingType: '',
                    fieldReverted: false,
                    fieldEditable: false,
                    editableRole: ''
                };
            } else {
                this.formData = { ...this.formData, fieldStatus: true };
            }
        } else if (fieldName === 'FEC_Field_ReadOnly__c') {
            const checked = event.detail.checked;
            // Read Only + Mandatory conflict: bỏ Mandatory khi bật Read Only
            if (checked && this.formData.fieldMandatory) {
                this.formData = { ...this.formData, fieldReadOnly: true, fieldMandatory: false };
            } else {
                this.formData = { ...this.formData, fieldReadOnly: checked };
            }
        } else if (fieldName === 'FEC_Field_Mandatory__c') {
            const checked = event.detail.checked;
            // Mandatory + Read Only conflict: bỏ Read Only khi bật Mandatory
            if (checked && this.formData.fieldReadOnly) {
                this.formData = { ...this.formData, fieldMandatory: true, fieldReadOnly: false };
            } else {
                this.formData = { ...this.formData, fieldMandatory: checked };
            }
        } else if (fieldName === 'FEC_Field_Object_Name__c') {
            this.formData = { ...this.formData, fieldObjectName: value };
        } else if (fieldName === 'FEC_Field_API_Name__c') {
            this.formData = { ...this.formData, fieldApiName: value };
        } else if (fieldName === 'FEC_Field_Label_Name__c') {
            this.formData = { ...this.formData, fieldLabelName: value };
        } else if (fieldName === 'FEC_Field_Masking__c') {
            const checked = event.detail.checked;
            // Masking off → clear Masking Type
            if (!checked) {
                this.formData = { ...this.formData, fieldMasking: false, maskingType: '' };
            } else {
                this.formData = { ...this.formData, fieldMasking: true };
            }
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
            const checked = event.detail.checked;
            // Editable off → clear Editable Role
            if (!checked) {
                this.formData = { ...this.formData, fieldEditable: false, editableRole: '' };
            } else {
                this.formData = { ...this.formData, fieldEditable: true };
            }
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
        if (this.isSaving) return;
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
        this.isSaving = true;
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
                    this.isSaving = false;
                });
        } catch (error) {
            console.error('Error in handleCreateSubmit:', error);
            this.showToast('Error', 'An unexpected error occurred', 'error');
            this.isSaving = false;
        }
    }

    handleSuccess(result) {
        this.dispatchEvent(new CustomEvent('success', { detail: result }));
    }

    handleSubmitEdit() {
        if (this.isSaving) return;
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
            this.isSaving = true;
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