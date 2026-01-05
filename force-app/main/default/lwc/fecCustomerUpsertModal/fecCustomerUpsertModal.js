import { LightningElement, api, track, wire } from 'lwc';
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
        console.log("🚀 ~ FecCustomerUpsertModal ~ connectedCallback ~ this.localData:", JSON.stringify(this.localData))

        if (this.initialData.Id) {
            this.fetchExistingFiles(this.initialData.Id);
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
            const isUnique = await this.validateUniqueInput();
            if (!isUnique) return;
            const excelResult = await this.processExcelFile(file);
            
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                const newFileRecord = {
                    id: 'temp-' + Date.now(),
                    name: file.name,
                    uploadedBy: this.currentUserName,
                    status: 'Uploaded',
                    uploadedTime: formatDateDDMMYYYY(new Date()),
                    base64Data: base64,
                    fileBlob: file,
                    isProcessing: true,
                    sheetXml: excelResult.jsonString
                };

                this.existingFiles = [...this.existingFiles, newFileRecord];
                this.pendingFiles = [...this.pendingFiles, newFileRecord];
                this.resetFileState();
            };
            reader.readAsDataURL(file);

        } catch (error) {
            this.showToast('Lỗi validate', error.message, 'error');
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
            reader.onload = (e) => {
                try {
                    const data = new Uint8Array(e.target.result);
                    const workbook = XLSX.read(data, { 
                        type: 'array',
                        cellDates: true 
                    });
                    
                    if (!workbook || !workbook.SheetNames.length) {
                        throw new Error('File không hợp lệ hoặc trống.');
                    }
                    
                    const sheet = workbook.Sheets[workbook.SheetNames[0]];
                    const rawRows = XLSX.utils.sheet_to_json(sheet, { header: 1 });

                    // 1. Validate Header ngay tại đây
                    this.validateFileHeader(rawRows, file.name);

                    // 2. Trả về kết quả kép: mảng thô (để dùng ngay) và JSON string (để gửi Server)
                    resolve({
                        rawRows: rawRows,
                        jsonString: JSON.stringify(rawRows)
                    });
                } catch (err) {
                    reject(err);
                }
            };
            reader.onerror = (err) => reject(err);
            reader.readAsArrayBuffer(file);
        });
    }
    
    // Hàm chuyển đổi mảng thô sang list SObject
    mapRowsToSObject(lstRows, fileName) {
        return lstRows.slice(1).map(lstCols => ({
            sobjectType: 'FEC_CustomerAdditionalInfo__c',
            FEC_KeyIDValue__c: lstCols[0] ? String(lstCols[0]).trim() : '',
            FEC_FieldValue__c: lstCols[1] ? String(lstCols[1]).trim() : '',
            FEC_IsActive__c: (lstCols[2] !== undefined) ? (String(lstCols[2]).toLowerCase() === 'true') : true,
            FEC_LinkedFilename__c: fileName,
        }));
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

    async handleDeleteFile(event) {
        const fileId = event.currentTarget.dataset.id;

        try {
            this.isLoading = true;

            if (!fileId.startsWith('temp-')) {
                if (this.existingFiles.length < 2) {
                    this.showToast('Lỗi', 'Tối thiểu phải có một file excel!', 'error');
                    return;
                }
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