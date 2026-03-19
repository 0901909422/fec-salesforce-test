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

    handleNodeBufferChange(event) {
        const updatedNode = event.detail;
        const nodeKey = updatedNode.idType;

        if (nodeKey) {
            // Normalize Status to Boolean to avoid type mismatch when sending to Apex
            const normalizedNode = {
                ...updatedNode,
                Status: Boolean(updatedNode.Status)
            };

            // Cập nhật Map
            this.pendingChanges.set(nodeKey, normalizedNode);

            // Ép LWC nhận diện sự thay đổi bằng cách gán lại chính nó (nếu cần render count lên UI)
            this.pendingChanges = new Map(this.pendingChanges);
            this.displayItem = { ...normalizedNode };
            console.log('[DEBUG][handleNodeBufferChange] nodeKey:', nodeKey, '| Status:', normalizedNode.Status, '| Pending count:', this.pendingChanges.size);
        }
    }

    // Khi người dùng nhấn Save All
    async handleSaveAll() {
        // ==========================================
        // LỚP BẢO VỆ 1: Kiểm tra UI của Tab đang mở
        // ==========================================
        const detailCmp = this.template.querySelector('[data-id="detailComponent"]');
        if (detailCmp && !detailCmp.validateForm()) {
            this.showToast(LABEL_TOAST_ERROR, 'Vui lòng kiểm tra và sửa các trường bị báo lỗi trước khi lưu.', VARIANT_ERROR);
            return; // Chặn đứng tại đây
        }

        const listToUpdate = Array.from(this.pendingChanges.values()).map(node => ({
            ...node,
            Status: Boolean(node.Status)
        }));

        // ==========================================
        // LỚP BẢO VỆ 2: Quét toàn bộ dữ liệu ẩn chờ lưu
        // Đề phòng user làm sai Node A rồi nhảy sang xem Node B
        // ==========================================
        let hasHiddenError = false;
        for (let node of listToUpdate) {
            // Kiểm tra các trường bắt buộc không được null hoặc rỗng (chỉ chứa khoảng trắng)
            if (
                !node.Alias || String(node.Alias).trim() === '' ||
                !node.NameEN || String(node.NameEN).trim() === '' ||
                !node.nameVN || String(node.nameVN).trim() === '' ||
                node.PosOrder === null || node.PosOrder === undefined || String(node.PosOrder).trim() === ''
            ) {
                hasHiddenError = true;
                // Báo chính xác tên Node đang bị lỗi để user biết đường tìm lại
                this.showToast(
                    LABEL_TOAST_ERROR, 
                    `Bản ghi "${node.NameEN || node.Code}" đang chứa dữ liệu rỗng. Vui lòng chọn lại Node đó để sửa.`, 
                    VARIANT_ERROR
                );
                break; // Thoát vòng lặp
            }
        }

        if (hasHiddenError) {
            return; // Chặn đứng, không gọi Server
        }

        // ==========================================
        // VƯỢT QUA 2 LỚP -> TIẾN HÀNH CALL APEX LƯU
        // ==========================================
        console.log('[DEBUG][handleSaveAll] All Valid! listToUpdate:', JSON.stringify(listToUpdate));
        this.loading = true;
        try {
            await updateMultipleNodes({ listData: listToUpdate });
            this.showToast(LABEL_TOAST_SUCCESS, LABEL_NOTIFY_SAVE_ALL.replace('{0}', listToUpdate.length), VARIANT_SUCCESS);

            this.pendingChanges.clear();
            this.pendingChanges = new Map(); // Reset map

            // Gửi event báo cho Tree biết để làm mới toàn bộ
            this.dispatchEvent(new CustomEvent(EVENT_REFRESH_ALL, { bubbles: true, composed: true }));
            if (detailCmp) {
                detailCmp.refreshHistory();
                detailCmp.markAsSaved();
            }

        } catch (error) {
            console.error('[DEBUG][handleSaveAll] ERROR:', error);
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || 'Lỗi lưu', VARIANT_ERROR);
        } finally {
            this.loading = false;
        }
    }

    get currentItemIsDirty() {
        if (!this.displayItem) return false;
        const nodeKey = this.displayItem.idType || this.displayItem.id;
        return this.pendingChanges.has(nodeKey);
    }

    // Hàm xử lý việc xóa dữ liệu tạm khi người dùng nhấn Refresh
    handleNodeBufferReset(event) {
        const { idType } = event.detail;
        const nodeKey = idType;

        if (this.pendingChanges.has(nodeKey)) {
            // 1. Xóa khỏi kho lưu trữ tạm
            this.pendingChanges.delete(nodeKey);

            // 2. Cập nhật lại Map để LWC nhận diện (update số lượng trên nút Save All)
            this.pendingChanges = new Map(this.pendingChanges);

            // 3. Ép displayItem hiển thị lại dữ liệu gốc (từ biến _item đã lưu trong setter)
            this.displayItem = { ...this._item };

            this.showToast(LABEL_TOAST_INFO, LABEL_NOTIFY_CANCEL_NODE_CHANGES, VARIANT_INFO);
        }
    }

    handleItemSave() {
        const nodeKey = this.item.idType;
        if (this.pendingChanges.has(nodeKey)) {
            this.pendingChanges.delete(nodeKey);
            this.pendingChanges = new Map(this.pendingChanges);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}