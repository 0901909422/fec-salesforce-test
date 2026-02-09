import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getServiceTypeTree from '@salesforce/apex/FEC_FecServiceTypeMappingController.getServiceTypeTree';
import savePropertyMapping from '@salesforce/apex/FEC_FecServiceTypeMappingController.savePropertyMapping';
import { showLog } from 'c/fecUtils';
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
    @track selectedProperty = null;
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
        const found = this.allPropertiesFlat.find(p => p.name === id);
        if (found) {
            this.selectedProperty = { ...found };
        }
    }

    handleInputChange(event) {
        this.selectedProperty.propertyRef = event.target.value;
    }

    @track isSaving = false; // Thêm biến này

    // Getter để kiểm tra khi nào nút Save nên bị khóa
    get isSaveDisabled() {
        return !this.selectedProperty || this.isSaving;
    }

    async handleSave() {
        if (!this.selectedProperty || this.isSaving) return;

        this.isSaving = true;
        try {
            // 1. Lưu vào Database (Apex)
            await savePropertyMapping({
                settingId: this.selectedProperty.name,
                newRef: this.selectedProperty.propertyRef
            });

            // 2. Cập nhật mảng local bằng cách tạo bản sao mới (Tránh lỗi Proxy)
            const targetId = this.selectedProperty.name;
            const newRefValue = this.selectedProperty.propertyRef;

            // Tạo mảng mới hoàn toàn dựa trên mảng cũ
            this.allPropertiesFlat = this.allPropertiesFlat.map(item => {
                if (item.name === targetId) {
                    // Trả về một object mới đã được cập nhật
                    return { ...item, propertyRef: newRefValue };
                }
                return item;
            });

            showLog('Updated allPropertiesFlat:', this.allPropertiesFlat);

            // 3. Thông báo thành công
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