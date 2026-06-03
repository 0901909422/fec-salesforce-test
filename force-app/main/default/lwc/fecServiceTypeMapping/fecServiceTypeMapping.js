import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
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
import LABEL_BP_PREFIX from '@salesforce/label/c.FEC_Label_BusinessProcess_Prefix';
import LABEL_STAGE_PREFIX from '@salesforce/label/c.FEC_Label_Stage_Prefix';
import LABEL_CONFIRM_DISCARD_TITLE from '@salesforce/label/c.FEC_Confirm_DiscardChanges_Title';
import LABEL_CONFIRM_DISCARD_MESSAGE from '@salesforce/label/c.FEC_Confirm_DiscardChanges_Message';

const NODE_TYPE_BP = 'BP';
const NODE_TYPE_STAGE = 'STAGE';
const NODE_TYPE_FIELD = 'FIELD';

export default class FecServiceTypeMapping extends LightningElement {
    @track treeItems = [];
    @track selectedFields = [];
    @track selectedBpName = '';
    @track selectedStageName = '';
    // Lưu node đang chọn để re-derive sau refresh: { nodeType, bpName, stageName? }
    selectedKey = null;
    allPropertiesFlat = [];
    // Lưu wire result object để refreshApex sử dụng sau save (Bug 1)
    wiredResult;
    // Bug 4: bỏ @track cho primitive — LWC tự reactive từ Spring '20
    isSaving = false;

    labelSave = LABEL_BUTTON_SAVE;
    // UI labels
    labelServiceTypes = LABEL_SERVICE_TYPES;
    title = LABEL_SERVICETYP_MAPP_TITLE;
    tableHeaderProperty = LABEL_TABLE_HEADER_PROPERTY;
    tableHeaderReference = LABEL_TABLE_HEADER_REFERENCE;
    placeholderMappingRef = LABEL_PLACEHOLDER_MAPPING_REF;
    messageSelectProperty = LABEL_MESSAGE_SELECT_PROPERTY;

    @wire(getServiceTypeTree)
    wiredTree(result) {
        this.wiredResult = result;
        if (result.data) {
            this.treeItems = result.data;
            showLog('Service Type Tree Data:', result.data);
            // Flatten: BP → Stage → Field (đọc field từ stage.fields, không phải stage.items)
            this.allPropertiesFlat = [];
            result.data.forEach(bp => {
                (bp.items || []).forEach(stage => {
                    (stage.fields || []).forEach(f => this.allPropertiesFlat.push(f));
                });
            });
            // Sau refreshApex, re-derive selectedFields cho selectedKey
            if (this.selectedKey && !this.isDirty) {
                this._reDeriveSelectedFieldsFromTree();
            }
        } else if (result.error) {
            const msg = result.error?.body?.message
                || result.error?.message
                || LABEL_TOAST_SAVE_ERROR_MESSAGE;
            this.showToast(LABEL_TOAST_SAVE_ERROR_TITLE, msg, VARIANT_ERROR);
        }
    }

    /**
     * Helper: rebuild selectedFields từ treeItems theo selectedKey hiện tại.
     * selectedKey = { nodeType, bpName, stageName? }
     */
    _reDeriveSelectedFieldsFromTree() {
        if (!this.selectedKey) return;
        const bpNode = this.treeItems.find(bp => bp.label === this.selectedKey.bpName);
        if (!bpNode) return;

        let fields = [];
        if (this.selectedKey.nodeType === NODE_TYPE_BP) {
            // Click BP → flatten tất cả Field từ mọi Stage (đọc stage.fields)
            (bpNode.items || []).forEach(stage => {
                (stage.fields || []).forEach(f => fields.push(f));
            });
        } else if (this.selectedKey.nodeType === NODE_TYPE_STAGE) {
            // Click Stage → chỉ field thuộc Stage đó
            const stageNode = (bpNode.items || []).find(s => s.label === this.selectedKey.stageName);
            if (stageNode) fields = stageNode.fields || [];
        }

        this.selectedFields = fields.map(field => ({
            ...field,
            fieldLabel: field.fieldLabel || field.label,
            fieldApiName: field.fieldApiName,
            originalRef: field.propertyRef
        }));
    }

    async handleSelect(event) {
        const id = event.detail.name;
        // Walk tree: chỉ có 2 cấp BP → Stage trong lightning-tree (Field không render)
        const found = this._findNodeInTree(id);
        if (!found) return;

        const { node, parentBp } = found;
        let targetKey;

        if (node.nodeType === NODE_TYPE_BP) {
            // Clicked BP → all properties (flatten across stages)
            targetKey = { nodeType: NODE_TYPE_BP, bpName: node.label, stageName: null };
        } else if (node.nodeType === NODE_TYPE_STAGE) {
            // Clicked Stage → only its properties
            targetKey = { nodeType: NODE_TYPE_STAGE, bpName: parentBp.label, stageName: node.label };
        } else {
            return;
        }

        // Bug 2: dirty-check trước khi switch sang key khác
        if (this.isDirty && !this._sameKey(this.selectedKey, targetKey)) {
            const confirmed = await LightningConfirm.open({
                label: LABEL_CONFIRM_DISCARD_TITLE,
                message: LABEL_CONFIRM_DISCARD_MESSAGE,
                theme: 'warning',
                variant: 'header'
            });
            if (!confirmed) return;
        }

        // Click cùng node đang chọn → giữ nguyên dirty changes (idempotent)
        if (this._sameKey(this.selectedKey, targetKey)) {
            return;
        }

        this.selectedKey = targetKey;
        this.selectedBpName = targetKey.bpName;
        this.selectedStageName = targetKey.nodeType === NODE_TYPE_STAGE ? targetKey.stageName : '';
        this._reDeriveSelectedFieldsFromTree();
    }

    _findNodeInTree(id) {
        for (const bp of this.treeItems) {
            if (bp.name === id) return { node: bp, parentBp: null };
            for (const stage of (bp.items || [])) {
                if (stage.name === id) return { node: stage, parentBp: bp };
            }
        }
        return null;
    }

    _sameKey(a, b) {
        if (!a || !b) return false;
        return a.nodeType === b.nodeType
            && a.bpName === b.bpName
            && (a.stageName || null) === (b.stageName || null);
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

    // Getter để kiểm tra khi nào nút Save nên bị khóa
    get isSaveDisabled() {
        return this.selectedFields.length === 0 || this.isSaving;
    }

    get hasSelectedFields() {
        return this.selectedFields.length > 0;
    }

    // Bug 2: dirty state cho confirm dialog
    get isDirty() {
        return this.selectedFields.some(f => f.propertyRef !== f.originalRef);
    }

    // Bug 5: header label dùng custom label thay cho hardcode "BP: "
    get bpHeaderLabel() {
        const bpPart = `${LABEL_BP_PREFIX} ${this.selectedBpName}`;
        if (this.selectedStageName) {
            return `${bpPart}  —  ${LABEL_STAGE_PREFIX} ${this.selectedStageName}`;
        }
        return bpPart;
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

            // 3. Update local allPropertiesFlat array (immediate UI feedback)
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

            // 6. Bug 1: Refresh wire data từ server để treeItems đồng bộ với DB
            try {
                await refreshApex(this.wiredResult);
            } catch (refreshError) {
                // refreshApex fail không phá vỡ luồng — local optimistic update đã chạy ở bước 3-4
                console.warn('refreshApex failed (UI vẫn show optimistic update):', refreshError);
            }

        } catch (error) {
            console.error('Save error:', error);
            // Bug 6: dùng null-safe error message từ server
            const errorMessage = error?.body?.message
                || error?.message
                || LABEL_TOAST_SAVE_ERROR_MESSAGE;
            this.showToast(LABEL_TOAST_SAVE_ERROR_TITLE, errorMessage, VARIANT_ERROR);
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}