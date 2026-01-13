import { LightningElement, api, track, wire } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import USER_NAME_FIELD from '@salesforce/schema/User.Name'
import { ACCOUNT_LINKAGE_OPTIONS, formatDateDDMMYYYY } from 'c/fecUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveCustomerData from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.saveCustomerData';
import getRelatedFiles from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getRelatedFiles';
import deleteFile from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.deleteFile';
import checkDuplicateConfig from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.checkDuplicateConfig';
import { loadScript } from 'lightning/platformResourceLoader';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';

export default class FecCustomerUpsertModal extends LightningElement {
    @api title = 'Thêm mới/Cập nhật';
    @api initialData = {}; 

    @track isLibraryLoaded = false
    @track accountLinkageOptions = ACCOUNT_LINKAGE_OPTIONS;
    @track localData = {};
    @track fileInfo = {
        name: '',
    };
    @track fileName = 'Chưa có tệp nào được chọn';
    @track isLoading = false;
    @track isUploadDisabled = true;
    @track isEditting = false;
    @track pendingFiles = [];
    @track existingFiles = [];
    fileAccept = '.xlsx, .xls, .csv';
    fileObject;
    base64Data;
    currentUserName;
    currentSelectedFile;

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.currentUserName = data.fields.Name.value;
        } else if (error) {
            console.error('Error loading user data', error);
        }
    }

    connectedCallback() {
        this.localData = {
            Id: this.initialData.Id || null,
            FEC_KeyIdentifier__c: this.initialData.FEC_KeyIdentifier__c || '',
            FEC_FieldID__c: this.initialData.FEC_FieldID__c || '',
            FEC_FieldName__c: this.initialData.FEC_FieldName__c || '',
            FEC_IsActive__c: this.initialData.FEC_IsActive__c !== undefined ? this.initialData.FEC_IsActive__c : false,
            FEC_StartDate__c: this.initialData.FEC_StartDate__c || new Date(),
            FEC_EndDate__c: this.initialData.FEC_EndDate__c || null,
        };

        if (this.initialData.Id) {
            this.fetchExistingFiles(this.initialData.Id);
            this.isEditting = true;
        } else {
            this.isEditting = false;
        }
        this.resetFileState();
    }

    /**
     * Lifecycle Hook: renderedCallback
     * Load thư viện xử lý Excel khi component render
     * @created: 2025/12/29 trung.bui.4
     */
    renderedCallback() {
        if (this.isLibraryLoaded) return;
        
        loadScript(this, FEC_SHEETJS)
            .then(() => {
                console.log('FEC_SheetJS loaded successfully');
                this.isLibraryLoaded = true;
            })
            .catch(error => {
                console.error('Error loading FEC_SheetJS', error);
                this.showToast('Lỗi', 'Không tải được thư viện xử lý Excel', 'error');
            });
    }

    handleInputChange(event) {
        const field = event.target.name;
        const val = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.localData = { ...this.localData, [field]: val };
    }

    resetFileState() {
        this.fileName = 'Chưa có tệp nào được chọn';
        this.isUploadDisabled = true;
        this.currentSelectedFile = null;
    }

    /**
     * Xử lý sự kiện chọn file Excel
     * @param event
     * @created: 2025/12/29 trung.bui.4
     */
    handleFileChange(event) {
        if (event.target.files.length > 0) {
            this.currentSelectedFile = event.target.files[0];
            this.fileName = this.currentSelectedFile.name;
            this.isUploadDisabled = false;
        }
    }

    /**
     * Hàm kiểm tra tính hợp lệ của Header file Excel
     * @param {Array} lstRows - Danh sách các dòng từ file Excel
     * @param {String} fileName - Tên file đang xử lý để hiển thị lỗi
     * @returns {Boolean} - Trả về true nếu hợp lệ, throw Error nếu không hợp lệ
     */
    validateFileHeader(lstRows, fileName) {
        if (!lstRows || lstRows.length === 0) {
            throw new Error(`File ${fileName} không có dữ liệu.`);
        }

        const fileHeader = lstRows[0]; // Dòng tiêu đề đầu tiên
        const fieldId = this.localData.FEC_FieldID__c;
        const keyId = this.localData.FEC_KeyIdentifier__c;

        // So sánh không phân biệt hoa thường và loại bỏ khoảng trắng thừa
        const isKeyMatch = fileHeader[0] && String(fileHeader[0]).trim().toUpperCase() === String(keyId).trim().toUpperCase();
        const isFieldMatch = fileHeader[1] && String(fileHeader[1]).trim().toUpperCase() === String(fieldId).trim().toUpperCase();

        if (!isKeyMatch || !isFieldMatch) {
            let errorMsg = `File "${fileName}" không khớp cấu trúc đã chọn: \n`;
            if (!isKeyMatch) errorMsg += `- Cột A: Mong muốn "${keyId}", Thực tế "${fileHeader[0] || 'Trống'}" \n`;
            if (!isFieldMatch) errorMsg += `- Cột B: Mong muốn "${fieldId}", Thực tế "${fileHeader[1] || 'Trống'}"`;
            throw new Error(errorMsg);
        }

        return true;
    }

    /**
     * Hàm kiểm tra trùng lặp cặp Key - Field từ Database
     * @returns {Promise<Boolean>} - true nếu hợp lệ, false nếu trùng
     */
    async validateUniqueInput() {
        const isDuplicate = await checkDuplicateConfig({
            keyId: this.localData.FEC_KeyIdentifier__c,
            fieldId: this.localData.FEC_FieldID__c,
            currentConfigId: this.localData.Id
        });

        if (isDuplicate) {
            const errorMsg = 'Cấu hình với cặp Key Identifier và Field ID này đã tồn tại.';
            throw new Error(errorMsg);
        } 
        return true;
    }

    async handleUpload() {
        if (!this.currentSelectedFile) return;
        this.isLoading = true;
        const file = this.currentSelectedFile;
    
        try {
            await this.validateUniqueInput();
    
            const result = await this.processExcelFile(file);
            
            const newFileRecord = {
                id: 'temp-' + Date.now(),
                name: file.name,
                uploadedBy: this.currentUserName,
                status: 'Uploaded',
                uploadedTime: formatDateDDMMYYYY(new Date()),
                base64Data: result.base64Data,
                sheetXml: result.jsonString,
                isProcessing: true
            };
    
            this.existingFiles = [...this.existingFiles, newFileRecord];
            this.pendingFiles = [...this.pendingFiles, newFileRecord];
            this.resetFileState();
    
        } catch (error) {
            this.showToast('Lỗi', error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
    * Xử lý lưu dữ liệu từ file Excel
    * @created      : 2025/12/30 trung.bui.4
    * @modified     : 
    */
    async handleSave() {
        const allValid = [...this.template.querySelectorAll('lightning-input'), 
                      ...this.template.querySelectorAll('lightning-combobox')]
                      .reduce((validSoFar, inputCmp) => {
                          inputCmp.reportValidity();
                          return validSoFar && inputCmp.checkValidity();
                      }, true);

        if (!allValid) {
            this.showToast('Lỗi', 'Vui lòng kiểm tra lại thông tin bắt buộc', 'error');
            return;
        }

        if (this.existingFiles.length === 0) {
            this.showToast('Lỗi', 'Vui lòng tải ít nhất một file Excel', 'error');
            return;
        }
        
        this.isLoading = true;

        try {
            const fileUploadBatch = this.pendingFiles.map(f => ({
                name: f.name,
                base64Data: f.base64Data,
                sheetXml: f.sheetXml
            }));

            // 4. Chuẩn bị Header Object
            const objConfig = {
                sobjectType: 'FEC_CustomerAdditionalInfoConfig__c',
                ...this.localData
            };

            // 5. Gọi Apex (Cần sửa tham số fileInfo thành List ở Apex)
            const result = await saveCustomerData({
                objConfig: objConfig,
                lstFiles: fileUploadBatch
            });

            if (result === 'Success') {
                this.showToast('Thành công', 'Đã lưu dữ liệu!', 'success');
                this.dispatchEvent(new CustomEvent('save'));
                this.handleClose();
            }
        } catch (error) {
            this.showToast('Lỗi', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Hàm duy nhất xử lý đọc file Excel: Validate Header và Trích xuất JSON
     * @param {File} file - Đối tượng file từ input
     * @returns {Promise<Object>} - Trả về mảng dữ liệu thô và chuỗi JSON
     */
    processExcelFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            // Đọc dưới dạng DataURL để lấy Base64 trước
            reader.onload = (e) => {
                try {
                    const base64WithHeader = e.target.result;
                    const base64Data = base64WithHeader.split(',')[1]; // Lấy phần data sau dấu phẩy
    
                    // Chuyển từ base64 sang ArrayBuffer để SheetJS xử lý
                    const data = new Uint8Array(atob(base64Data).split("").map(c => c.charCodeAt(0)));
                    const workbook = XLSX.read(data, { type: 'array', cellDates: true });
                    
                    if (!workbook || !workbook.SheetNames.length) {
                        throw new Error('File không hợp lệ hoặc trống.');
                    }
                    
                    const sheet = workbook.Sheets[workbook.SheetNames[0]];
                    const rawRows = XLSX.utils.sheet_to_json(sheet, { header: 1 });
    
                    // Validate Header
                    this.validateFileHeader(rawRows, file.name);
    
                    // Trả về tất cả kết quả xử lý
                    resolve({
                        jsonString: JSON.stringify(rawRows),
                        base64Data: base64Data
                    });
                } catch (err) {
                    reject(err);
                }
            };
            reader.onerror = (err) => reject(err);
            reader.readAsDataURL(file); // Đọc 1 lần lấy DataURL (Base64)
        });
    }

    /**
     * Tải template dưới dạng Excel (.xlsx) sử dụng SheetJS
     */
    handleDownloadTemplate() {
        // Kiểm tra thư viện đã load chưa
        if (!this.isLibraryLoaded || typeof XLSX === 'undefined') {
            this.showToast('Cảnh báo', 'Thư viện Excel đang tải, vui lòng thử lại sau giây lát.', 'warning');
            return;
        }

        try {
            const keyHeader = this.localData.FEC_KeyIdentifier__c 
                ? this.localData.FEC_KeyIdentifier__c.trim() 
                : '<Key Identifier>';
                
            const fieldHeader = this.localData.FEC_FieldID__c 
                ? this.localData.FEC_FieldID__c.trim() 
                : '<Field ID>';

            const wsData = [
                [keyHeader, fieldHeader, 'Is Active'] 
            ];

            // 3. Tạo Worksheet
            const ws = XLSX.utils.aoa_to_sheet(wsData);

            ws['!cols'] = [
                { wch: 30 },
                { wch: 30 },
                { wch: 15 }
            ];

            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, "Template_Import");

            // 5. Xuất file (SheetJS tự xử lý Blob và download)
            XLSX.writeFile(wb, 'Customer_Additional_Info_Template.xlsx');

        } catch (error) {
            console.error('Error generating template:', error);
            this.showToast('Lỗi', 'Không thể tạo file template: ' + error.message, 'error');
        }
    }

    async handleDeleteFile(event) {
        const fileId = event.currentTarget.dataset.id;

        try {
            this.isLoading = true;

            if (!fileId.startsWith('temp-')) {
                if (this.existingFiles.length < 2) {
                    this.showToast('Lỗi', 'Tối thiểu phải có một file excel!', 'error');
                    return;
                }
                const result = await LightningConfirm.open({
                    message: `Bạn có chắc chắn muốn xóa không?`,
                    variant: 'header',
                    label: 'Xác nhận xóa',
                    theme: 'error',
                });
                if (!result) return;
                await deleteFile({ documentId: fileId });
            }

            this.existingFiles = this.existingFiles.filter(f => f.id !== fileId);
            this.pendingFiles = this.pendingFiles.filter(f => f.id !== fileId);
            this.showToast('Thành công', 'Đã xóa file', 'success');
        } catch (error) {
            this.showToast('Lỗi', 'Không thể xóa file: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    /**
     * Helper hiển thị link tải file trong danh sách existingFiles
     */
    get processedExistingFiles() {
        return this.existingFiles ? this.existingFiles : [];
    }

    fetchExistingFiles(recordId) {
        getRelatedFiles({ recordId: recordId })
            .then(result => {
                this.existingFiles = result.map(file => ({
                        id: file.id,
                        name: file.name,
                        downloadUrl: `/sfc/servlet.shepherd/document/download/${file.id}`,
                        uploadedBy: file.uploadedBy,
                        uploadedTime: formatDateDDMMYYYY(file.uploadedTime),
                        status: file.status,
                        isProcessing: file.status === 'Uploaded'
                    }));
            })
            .catch(error => {
                console.error('### FEC_ERROR fetchFiles:', error);
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}