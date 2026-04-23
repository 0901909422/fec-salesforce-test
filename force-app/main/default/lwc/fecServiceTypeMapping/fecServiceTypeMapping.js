import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getServiceTypeTree from '@salesforce/apex/FEC_FecServiceTypeMappingController.getServiceTypeTree';
import savePropertyMapping from '@salesforce/apex/FEC_FecServiceTypeMappingController.savePropertyMapping';
import savePropertyMappings from '@salesforce/apex/FEC_FecServiceTypeMappingController.savePropertyMappings';
import { showLog } from 'c/fecMDMUtils';
import LABEL_TOAST_SAVE_SUCCESS_TITLE from '@salesforce/label/c.FEC_Toast_Save_Success_Title';
import LABEL_TOAST_SAVE_SUCCESS_MESSAGE from '@salesforce/label/c.FEC_Toast_Save_Success_Message';
import LABEL_TOAST_SAVE_ERROR_TITLE from '@salesforce/label/c.FEC_Toast_Save_Error_Title';
import LABEL_TOAST_SAVE_ERROR_MESSAGE from '@salesforce/label/c.FEC_Toast_Save_Error_Message';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import { VARIANT_SUCCESS, VARIANT_ERROR } from 'c/fecConstants';
import LABEL_SERVICE_TYPES from '@salesforce/label/c.FEC_Label_ServiceTypes';
import LABEL_SERVICETYP_MAPP_TITLE from '@salesforce/label/c.FEC_ServiceTypeMapping_Title';
import LABEL_TABLE_HEADER_PROPERTY from '@salesforce/label/c.FEC_TableHeader_PropertyName';
import LABEL_TABLE_HEADER_REFERENCE from '@salesforce/label/c.FEC_TableHeader_Reference';
import LABEL_PLACEHOLDER_MAPPING_REF from '@salesforce/label/c.FEC_Placeholder_Mapping_Reference';
import LABEL_MESSAGE_SELECT_PROPERTY from '@salesforce/label/c.FEC_Message_Select_Property';

export default class FecServiceTypeMapping extends LightningElement {
    @track treeItems = [];
    @track selectedFields = [];
    @track selectedBpName = '';
    allPropertiesFlat = [];

    labelSave = LABEL_BUTTON_SAVE;
    // UI labels
    labelServiceTypes = LABEL_SERVICE_TYPES;
    title = LABEL_SERVICETYP_MAPP_TITLE;
    tableHeaderProperty = LABEL_TABLE_HEADER_PROPERTY;
    tableHeaderReference = LABEL_TABLE_HEADER_REFERENCE;
    placeholderMappingRef = LABEL_PLACEHOLDER_MAPPING_REF;
    messageSelectProperty = LABEL_MESSAGE_SELECT_PROPERTY;

    @wire(getServiceTypeTree)
    wiredTree({ error, data }) {
        if (data) {
            this.treeItems = data;
            showLog('Service Type Tree Data:', data);
            // Làm phẳng dữ liệu để tìm kiếm nhanh
            this.allPropertiesFlat = data.flatMap(bp => bp.items);
        }
    }

    handleSelect(event) {
        const id = event.detail.name;
        // Check if selected node is a BP (has items in treeItems)
        const bpNode = this.treeItems.find(bp => bp.name === id);
        if (bpNode) {
            // Selected a BP node → get all child fields
            this.selectedBpName = bpNode.label;
            this.selectedFields = (bpNode.items || []).map(field => ({
                ...field,
                fieldLabel: field.fieldLabel || field.label,
                fieldApiName: field.fieldApiName,
                originalRef: field.propertyRef
            }));
        } else {
            // Selected a field node → find parent BP, then get all fields of that BP
            const parentBp = this.treeItems.find(bp =>
                (bp.items || []).some(item => item.name === id)
            );
            if (parentBp) {
                this.selectedBpName = parentBp.label;
                this.selectedFields = (parentBp.items || []).map(field => ({
                    ...field,
                    fieldLabel: field.fieldLabel || field.label,
                    fieldApiName: field.fieldApiName,
                    originalRef: field.propertyRef
                }));
            }
        }
    }

    handleFieldInputChange(event) {
        const fieldName = event.target.dataset.id;
        this.selectedFields = this.selectedFields.map(field => {
            if (field.name === fieldName) {
                return { ...field, propertyRef: event.target.value };
            }
            return field;
        });
    }

    @track isSaving = false; // Thêm biến này

    // Getter để kiểm tra khi nào nút Save nên bị khóa
    get isSaveDisabled() {
        return this.selectedFields.length === 0 || this.isSaving;
    }

    get hasSelectedFields() {
        return this.selectedFields.length > 0;
    }

    async handleSave() {
        if (this.selectedFields.length === 0 || this.isSaving) return;

        // Collect only changed fields
        const changedFields = this.selectedFields.filter(
            field => field.propertyRef !== field.originalRef
        );

        if (changedFields.length === 0) {
            this.showToast(LABEL_TOAST_SAVE_SUCCESS_TITLE, LABEL_TOAST_SAVE_SUCCESS_MESSAGE, VARIANT_SUCCESS);
            return;
        }

        this.isSaving = true;
        try {
            // 1. Build bulk save payload
            const mappings = changedFields.map(field => ({
                settingId: field.name,
                newRef: field.propertyRef
            }));

            // 2. Bulk save via Apex
            await savePropertyMappings({ mappingsJson: JSON.stringify(mappings) });

            // 3. Update local allPropertiesFlat array
            const changedMap = {};
            changedFields.forEach(field => {
                changedMap[field.name] = field.propertyRef;
            });

            this.allPropertiesFlat = this.allPropertiesFlat.map(item => {
                if (changedMap[item.name] !== undefined) {
                    return { ...item, propertyRef: changedMap[item.name] };
                }
                return item;
            });

            // 4. Update originalRef in selectedFields to reflect saved state
            this.selectedFields = this.selectedFields.map(field => ({
                ...field,
                originalRef: field.propertyRef
            }));

            showLog('Updated allPropertiesFlat:', this.allPropertiesFlat);

            // 5. Thông báo thành công
            this.showToast(LABEL_TOAST_SAVE_SUCCESS_TITLE, LABEL_TOAST_SAVE_SUCCESS_MESSAGE, VARIANT_SUCCESS);

        } catch (error) {
            console.error('Save error:', error);
            this.showToast(LABEL_TOAST_SAVE_ERROR_TITLE, LABEL_TOAST_SAVE_ERROR_MESSAGE, VARIANT_ERROR);
        } finally {
            this.isSaving = false;
        }
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}