import { LightningElement, api, track } from 'lwc';
import { ACCOUNT_LINKAGE_OPTIONS } from 'c/fecUtils';

export default class FecCustomerUpsertModal extends LightningElement {
    @api title = 'Thêm mới/Cập nhật';
    @api initialData = {}; 

    @track accountLinkageOptions = ACCOUNT_LINKAGE_OPTIONS;
    @track localData = {};
    @track fileName = 'Chưa có tệp nào được chọn';
    @track isUploadDisabled = true;
    @track existingFiles = [];
    fileAccept = '.pdf, .docx, .xlsx, .csv';

    connectedCallback() {
        // Clone data để tránh mutate props
        this.localData = { ...this.initialData };
        this.resetFileState();
    }

    handleInputChange(event) {
        const field = event.target.name;
        const val = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.localData = { ...this.localData, [field]: val };
    }

    resetFileState() {
        this.fileName = 'Chưa có tệp nào được chọn';
        this.isUploadDisabled = true;
        this.existingFiles = [];
    }

    handleFileChange(event) {
        if (event.target.files.length > 0) {
            this.fileName = event.target.files[0].name;
            this.isUploadDisabled = false;
        }
    }

    handleUpload() {
        if (this.fileName) {
            // 1. Thêm 1 dòng mới vào bảng record (existingFiles) phía dưới
            const newFileRecord = {
                id: Date.now(), // Tạo ID duy nhất bằng timestamp
                name: this.fileName,
                status: 'Uploaded',
                uploadTime: Date.now(),
                uploadedBy: 'Current User' // Bạn có thể thay bằng tên user thật
            };
    
            // Cập nhật mảng bằng cách tạo bản sao mới để LWC nhận diện thay đổi
            this.existingFiles = [...this.existingFiles, newFileRecord];
    
            // 2. Reset lại khu vực upload file
            this.fileName = '';
            this.isUploadDisabled = true;
    
            // Reset giá trị của input file trong DOM (nếu cần)
            const fileInput = this.template.querySelector('input[type="file"]');
            if (fileInput) {
                fileInput.value = '';
            }
    
            // Thông báo thành công (tùy chọn)
            console.log('Upload thành công và đã thêm record mới.');
        }
    }

    handleDownloadTemplate() {
        try {
            // 1. Định nghĩa nội dung Header khớp chính xác với file template bạn gửi
            const headers = ['<Key Identifier>', '<Field ID>', 'Is Active'];
            const csvContent = headers.join(',') + '\n';
            
            // 2. Sử dụng BOM để hỗ trợ hiển thị tốt nhất trên Excel
            const BOM = '\uFEFF';
            const finalContent = BOM + csvContent;
    
            // 3. Chuyển đổi nội dung sang định dạng Base64 để tạo Data URI
            // Cách này an toàn hơn Blob trong môi trường bật LWS
            const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(finalContent);
            
            // 4. Tạo thẻ link ẩn và kích hoạt download
            const link = document.createElement("a");
            link.setAttribute("href", encodedUri);
            link.setAttribute("download", "customer_additional_info_template.csv");
            document.body.appendChild(link); // Bắt buộc thêm vào DOM để hoạt động ổn định
            
            link.click();
            
            // 5. Dọn dẹp DOM sau khi tải
            document.body.removeChild(link);
        } catch (error) {
            console.error('Lỗi khi tải template:', error);
        }
    }

    handleDeleteFile(event) {
        const id = event.currentTarget.dataset.id;
        this.existingFiles = this.existingFiles.filter(f => f.id !== id);
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        this.dispatchEvent(new CustomEvent('save', { detail: this.localData }));
    }
}