import { LightningElement, track, api } from 'lwc';
import updateMultipleNodes from '@salesforce/apex/FEC_NatureOfCaseTreeController.updateMultipleNodes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { VARIANT_SUCCESS, VARIANT_ERROR, VARIANT_INFO, EVENT_REFRESH_ALL } from 'c/fecConstants';
import LABEL_MASTERDATA_TITLE from '@salesforce/label/c.FEC_MasterData_Title';
import LABEL_BUTTON_SAVE_ALL from '@salesforce/label/c.FEC_Button_Save_All';
import LABEL_SPINNER_SAVING from '@salesforce/label/c.FEC_Spinner_Saving';
import LABEL_NOTIFY_CANCEL_NODE_CHANGES from '@salesforce/label/c.FEC_Notify_Cancel_Node_Changes';
import LABEL_TAB_NODE_DETAILS from '@salesforce/label/c.FEC_Tab_Node_Details';
import LABEL_TAB_MASTER_DATA_SETTINGS from '@salesforce/label/c.FEC_Tab_Master_Data_Settings';
import LABEL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Toast_Success';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_TOAST_INFO from '@salesforce/label/c.FEC_Toast_Info';
import LABEL_NOTIFY_SAVE_ALL from '@salesforce/label/c.FEC_Notify_Save_All';

export default class FecMasterDataContainer extends LightningElement {
    @track pendingChanges = new Map(); // Key: ID của Node, Value: Dữ liệu đã sửa
    @track displayItem = {}; // Biến này dùng để truyền xuống Detail
    loading = false;
    // expose labels
    labelTitle = LABEL_MASTERDATA_TITLE;
    labelSaveAll = LABEL_BUTTON_SAVE_ALL;
    labelSpinnerSaving = LABEL_SPINNER_SAVING;
    labelTabNodeDetails = LABEL_TAB_NODE_DETAILS;
    labelTabMasterDataSettings = LABEL_TAB_MASTER_DATA_SETTINGS;

    // Sử dụng Getter/Setter cho thuộc tính item
    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;
        if (value) {
            const nodeKey = value.idType;
            // KIỂM TRA: Nếu node này đã có trong danh sách chờ lưu (đã sửa)
            if (this.pendingChanges.has(nodeKey)) {
                // Lấy bản copy đã sửa từ Map ra để hiển thị
                this.displayItem = { ...this.pendingChanges.get(nodeKey) };
            } else {
                // Nếu chưa sửa, hiển thị dữ liệu gốc từ Tree
                this.displayItem = { ...value };
            }
        }
    }

    get saveButtonLabel() {
        const count = this.pendingChanges.size;
        return count > 0 ? `${this.labelSaveAll} (${count})` : this.labelSaveAll;
    }

    // Kiểm tra xem có thay đổi nào không để disable nút nếu cần
    get isSaveDisabled() {
        return this.pendingChanges.size === 0 || this.loading;
    }

    // NOC Id from the currently selected tree item (for Hold Case Config tab)
    get currentNocId() {
        return this._item?.id || '';
    }

    handleNodeBufferChange(event) {
        const updatedNode = event.detail;
        const nodeKey = updatedNode.idType;

        if (nodeKey) {
            const normalizedNode = {
                ...updatedNode,
                Status: Boolean(updatedNode.Status)
            };

            // Chỉ cập nhật Map để báo nút "Save All"
            this.pendingChanges.set(nodeKey, normalizedNode);
            this.pendingChanges = new Map(this.pendingChanges);

            // QUAN TRỌNG: Xóa dòng this.displayItem = ... ở đây
            // Không dội data ngược lại Component Con khi đang gõ
        }
    }

    handleNodeBufferReset(event) {
        const { idType } = event.detail;
        const nodeKey = idType;

        if (this.pendingChanges.has(nodeKey)) {
            // 1. Chỉ xóa khỏi Map tạm
            this.pendingChanges.delete(nodeKey);
            this.pendingChanges = new Map(this.pendingChanges);

            // QUAN TRỌNG: Không cần set lại displayItem. Con đã tự khôi phục form của nó.
            this.showToast(LABEL_TOAST_INFO, LABEL_NOTIFY_CANCEL_NODE_CHANGES, VARIANT_INFO);
        }
    }

    // Khi người dùng nhấn Save All
    async handleSaveAll() {
        const listToUpdate = Array.from(this.pendingChanges.values()).map(node => ({
            ...node,
            Status: Boolean(node.Status)
        }));

        console.log('[DEBUG][handleSaveAll] listToUpdate:', JSON.stringify(listToUpdate));

        if (listToUpdate.length === 0) {
            this.showToast(LABEL_TOAST_WARNING, LABEL_NOTIFY_NO_CHANGES_TO_SAVE, VARIANT_WARNING);
            return;
        }

        // --- LAYER 1: VALIDATE REQUIRED FIELDS BEFORE CALLING APEX ---
        let hasError = false;

        // Iterate through all nodes to check requirements based on Node Type (Product vs Nature Case)
        for (const node of listToUpdate) {
            // Check for required fields
            if (
                !node.Alias || String(node.Alias).trim() === '' ||
                !node.NameEN || String(node.NameEN).trim() === '' ||
                !node.nameVN || String(node.nameVN).trim() === '' ||
                node.PosOrder === null || node.PosOrder === undefined || String(node.PosOrder).trim() === ''
            ) {
                hasError = true;
                this.showToast(
                    LABEL_TOAST_ERROR,
                    `Bản ghi "${node.NameEN || node.Code}" đang chứa dữ liệu rỗng. Vui lòng chọn lại Node đó để sửa.`,
                    VARIANT_ERROR
                );
                break;
            }
        }

        if (hasError) {
            return;
        }

        // --- LAYER 2: CALL APEX TO SAVE DATA ---
        this.loading = true;
        try {
            await updateMultipleNodes({ listData: listToUpdate });
            this.showToast(LABEL_TOAST_SUCCESS, LABEL_NOTIFY_SAVE_ALL.replace('{0}', listToUpdate.length), VARIANT_SUCCESS);

            // Save NOC fields if dirty
            const detailCmp = this.template.querySelector('[data-id="detailComponent"]');
            if (detailCmp) {
                try {
                    await detailCmp.saveNocFields();
                } catch (nocError) {
                    console.error('[handleSaveAll] NOC save error:', nocError);
                    this.showToast(LABEL_TOAST_ERROR, nocError.body?.message || nocError.message || 'Error saving NOC', VARIANT_ERROR);
                }
            }

            // TỰ ĐỒNG BỘ DỮ LIỆU Ở CHA
            const currentNodeKey = this.displayItem?.idType;
            if (currentNodeKey && this.pendingChanges.has(currentNodeKey)) {
                this._item = { ...this._item, ...this.pendingChanges.get(currentNodeKey) };
                this.displayItem = { ...this._item }; // Cập nhật displayItem sau khi ĐÃ SAVE
            }

            this.pendingChanges.clear();
            this.pendingChanges = new Map(); // Reset map

            this.dispatchEvent(new CustomEvent(EVENT_REFRESH_ALL, { bubbles: true, composed: true }));

            detailCmp.markAsSaved();
            detailCmp.refreshHistory();

            // Dùng setTimeout ở phía Parent để đợi DOM ổn định (và đợi Tree refresh) 
            // trước khi ra lệnh cho Child refresh History.
            // setTimeout(() => {
            //     const detailCmp = this.template.querySelector('[data-id="detailComponent"]');
            //     if (detailCmp) {
            //         detailCmp.markAsSaved();
            //         detailCmp.refreshHistory();
            //         console.log('[DEBUG][handleSaveAll] Called detailCmp.refreshHistory() and markAsSaved()');
            //     } else {
            //         console.log('[DEBUG][handleSaveAll] detailComponent not found!');
            //     }
            // }, 500);

        } catch (error) {
            console.error('[DEBUG][handleSaveAll] ERROR:', error);
            this.showToast(LABEL_TOAST_ERROR, error.body.message, VARIANT_ERROR);
        } finally {
            this.loading = false;
        }
    }

    /**
     * Handle save event from detail component (Save Node Details button).
     * Refreshes tree and clears pending changes for the saved node.
     */
    handleItemSave() {
        // Clear pending changes for the current node since it was saved directly
        if (this._item && this._item.idType) {
            const key = this._item.idType;
            if (this.pendingChanges && this.pendingChanges.has(key)) {
                this.pendingChanges.delete(key);
                // Reassign Map to trigger reactivity for saveButtonLabel/isSaveDisabled getters
                this.pendingChanges = new Map(this.pendingChanges);
            }
        }
        // Refresh tree to reflect updated data
        this.dispatchEvent(new CustomEvent(EVENT_REFRESH_ALL, { bubbles: true, composed: true }));
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}