import { LightningElement, api, wire, track } from 'lwc';
import getAttachmentsFromInteraction from '@salesforce/apex/FEC_AttachmentController.getAttachmentsFromInteraction';
import attachFilesToServiceCase from '@salesforce/apex/FEC_AttachmentController.attachFilesToServiceCase';
import { showToast } from 'c/fecChathubUtils';
/**
 * fec_selectAttachment
 * Modal component to display and select attachments from a related Interaction Case.
 * @created    : 2024/12/03 Gemini
 * @modified   : 
 */
export default class FecSelectAttachment extends LightningElement {
    @api serviceCaseId;        // ID của Service Case hiện tại (Target)
    @api interactionCaseId;    // ID của Interaction Case (Source)

    @track attachmentData = [];
    @track columns = [
        { label: 'Filename', fieldName: 'fileName', type: 'text' },
        { label: 'Create DateTime', fieldName: 'createdDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { label: 'Create Operator', fieldName: 'createdBy', type: 'text' }
    ];

    // Set chứa ID của các ContentDocument được chọn
    selectedContentDocumentIds = new Set();

    // Sử dụng wire để tải dữ liệu tệp đính kèm
    @wire(getAttachmentsFromInteraction, {
        strInteractionCaseId: '$interactionCaseId',
        strTargetServiceCaseId: '$serviceCaseId'
    })
    wiredAttachments({ error, data }) {
        if (data) {
            // Comment: Lọc các file đã gắn (read-only) và các file mới có thể chọn
            this.attachmentData = data.map(item => ({
                ...item,
                // LWC Table Row Selection: vô hiệu hóa hàng nếu đã gắn (read-only)
                _disabled: item.isReadOnly,
                // ID cần dùng cho việc gắn file
                contentDocumentId: item.id.substring(0, 15) // ContentVersionId -> ContentDocumentId (Simulated)
            }));
        } else if (error) {
            showToast(this, 'Error', 'Could not load attachments: ' + error.body.message, 'error');
            console.error(error);
        }
    }

    // Xử lý khi người dùng chọn/bỏ chọn hàng
    handleRowSelection(event) {
        this.selectedContentDocumentIds = new Set();
        const selectedRows = event.detail.selectedRows;

        // Comment: Lọc chỉ những file chưa gắn (isReadOnly=false)
        selectedRows.forEach(row => {
            if (!row._disabled) {
                // Thêm ContentDocumentId vào Set
                this.selectedContentDocumentIds.add(row.contentDocumentId);
            }
        });
    }

    // Xử lý nút "Hoàn tất"
    async handleAttachFiles() {
        if (this.selectedContentDocumentIds.size === 0) {
            showToast(this, 'Warning', 'Vui lòng chọn ít nhất một tệp đính kèm mới.', 'warning');
            return;
        }

        try {
            const listContentDocIds = Array.from(this.selectedContentDocumentIds);

            // Comment: Gọi Apex để tạo ContentDocumentLink
            const result = await attachFilesToServiceCase({
                strTargetServiceCaseId: this.serviceCaseId,
                listSelectedContentDocumentIds: listContentDocIds
            });

            if (result) {
                showToast(this, 'Success', 'Đã gắn tệp đính kèm thành công.', 'success');
                // Đóng modal và refresh giao diện
                this.closeModal();
            } else {
                showToast(this, 'Error', 'Có lỗi xảy ra khi gắn tệp.', 'error');
            }
        } catch (error) {
            showToast(this, 'Error', 'Lỗi hệ thống: ' + error.body.message, 'error');
        }
    }

    // Hàm tiện ích: Đóng modal
    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}