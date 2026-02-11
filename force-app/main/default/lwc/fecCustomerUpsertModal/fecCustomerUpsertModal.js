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
import { FILE_ACCEPT, formatString } from 'c/fecUtils';

import lblDataLinkage from '@salesforce/label/c.FEC_Lbl_Data_Linkage';
import lblFieldId from '@salesforce/label/c.FEC_Lbl_Field_ID';
import lblFieldName from '@salesforce/label/c.FEC_Lbl_Field_Name';
import lblIsActive from '@salesforce/label/c.FEC_Lbl_Is_Active';
import lblStartDate from '@salesforce/label/c.FEC_Lbl_Start_Date';
import lblEndDate from '@salesforce/label/c.FEC_Lbl_End_Date';
import msgProcessEOD from '@salesforce/label/c.FEC_Msg_Process_End_Of_Day';
import lblChooseFile from '@salesforce/label/c.FEC_Lbl_Choose_File';
import lblNoFileChosen from '@salesforce/label/c.FEC_Lbl_No_File_Chosen';
import btnUpload from '@salesforce/label/c.FEC_Btn_Upload';
import btnDownloadTemplate from '@salesforce/label/c.FEC_Btn_Download_Template';
import lblFileName from '@salesforce/label/c.FEC_Lbl_File_Name';
import lblStatus from '@salesforce/label/c.FEC_Lbl_Status';
import lblUploadedBy from '@salesforce/label/c.FEC_Lbl_Uploaded_By';
import lblUploadedAt from '@salesforce/label/c.FEC_Lbl_Uploaded_At';
import lblAction from '@salesforce/label/c.FEC_Lbl_Action';
import msgNoContent from '@salesforce/label/c.FEC_Msg_No_Content';
import btnCancel from '@salesforce/label/c.FEC_Btn_Cancel';
import btnFinish from '@salesforce/label/c.FEC_Btn_Finish';
import errorLoadExcelLib from '@salesforce/label/c.FEC_Load_Excel_Lib';
import fileHasNoDataMsg from '@salesforce/label/c.FEC_Has_No_Data';
import errorExpectedKey from '@salesforce/label/c.FEC_Error_Expected_Key';
import errorExpectedValue from '@salesforce/label/c.FEC_Error_Expected_Value';
import errorFileInvalid from '@salesforce/label/c.FEC_Error_File_Invalid';
import emptyMsg from '@salesforce/label/c.FEC_Empty';
import errorDuplicatedKeyIdFieldId from '@salesforce/label/c.FEC_Error_Duplicated_KeyId_FieldId';
import errorRequiredFields from '@salesforce/label/c.FEC_Error_Required_Fields';
import errorUploadAtLeastExcelFile from '@salesforce/label/c.FEC_Error_Upload_At_Least_Excel_File';
import deletedFileMsg from '@salesforce/label/c.FEC_Deleted_File';
import savedDataMsg from '@salesforce/label/c.FEC_Saved_Data';
import errorCreateTemplate from '@salesforce/label/c.FEC_Error_Create_Template';
import deleteConfirmationTitle from '@salesforce/label/c.FEC_Delete_Confirmation_Title';
import deleteConfirmationMsg from '@salesforce/label/c.FEC_Delete_Confirmation_Msg';
import cannotDeleteFileMsg from '@salesforce/label/c.FEC_Cannot_Delete_File';
import successTitle from '@salesforce/label/c.FEC_Success_Title';
import failTitle from '@salesforce/label/c.FEC_Fail_Title';
import warningTitle from '@salesforce/label/c.FEC_Warning_Title';

export default class FecCustomerUpsertModal extends LightningElement {
    label = {
        lblDataLinkage, lblFieldId, lblFieldName, lblIsActive,
        lblStartDate, lblEndDate, msgProcessEOD, lblChooseFile,
        btnUpload, btnDownloadTemplate, lblFileName, lblNoFileChosen, lblStatus,
        lblUploadedBy, lblUploadedAt, lblAction, msgNoContent,
        btnCancel, btnFinish
    };

    @api title;
    @api initialData = {}; 

    @track isLibraryLoaded = false
    @track accountLinkageOptions = ACCOUNT_LINKAGE_OPTIONS;
    @track localData = {};
    @track fileInfo = {
        name: '',
    };
    @track fileName = this.label.lblNoFileChosen;
    @track isLoading = false;
    @track isUploadDisabled = true;
    @track isEditting = false;
    @track pendingFiles = [];
    @track existingFiles = [];
    fileAccept = FILE_ACCEPT;
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
                this.showToast(failTitle, errorLoadExcelLib, 'error');
            });
    }

    handleInputChange(event) {
        const field = event.target.name;
        const val = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.localData = { ...this.localData, [field]: val };
    }

    resetFileState() {
        this.fileName = this.label.lblNoFileChosen;
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
            throw new Error(fileHasNoDataMsg);
        }
    
        const fileHeader = lstRows[0];
        const fieldId = this.localData.FEC_FieldID__c;
        const keyId = this.localData.FEC_KeyIdentifier__c;
    
        const isKeyMatch = fileHeader[0] && String(fileHeader[0]).trim().toUpperCase() === String(keyId).trim().toUpperCase();
        const isFieldMatch = fileHeader[1] && String(fileHeader[1]).trim().toUpperCase() === String(fieldId).trim().toUpperCase();
    
        if (!isKeyMatch || !isFieldMatch) {
            let errorMsg = '';
            
            if (!isKeyMatch) {
                errorMsg += formatString(errorExpectedKey, keyId, fileHeader[0] || emptyMsg) + '\n';
            }
            
            if (!isFieldMatch) {
                errorMsg += formatString(errorExpectedValue, fieldId, fileHeader[1] || emptyMsg);
            }
            
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
            throw new Error(errorDuplicatedKeyIdFieldId);
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
            this.showToast(failTitle, error.message, 'error');
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
            this.showToast(failTitle, errorRequiredFields, 'error');
            return;
        }

        if (this.existingFiles.length === 0) {
            this.showToast(failTitle, errorUploadAtLeastExcelFile, 'error');
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
                this.showToast(successTitle, savedDataMsg, 'success');
                this.dispatchEvent(new CustomEvent('save'));
                this.handleClose();
            }
        } catch (error) {
            this.showToast(failTitle, error.body?.message || error.message, 'error');
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
                        throw new Error(errorFileInvalid);
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
            this.showToast(warningTitle, errorLoadExcelLib, 'warning');
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
            this.showToast(failTitle, errorCreateTemplate + error.message, 'error');
        }
    }

    async handleDeleteFile(event) {
        const fileId = event.currentTarget.dataset.id;

        try {
            this.isLoading = true;

            if (!fileId.startsWith('temp-')) {
                if (this.existingFiles.length < 2) {
                    this.showToast(failTitle, errorUploadAtLeastExcelFile, 'error');
                    return;
                }
                const result = await LightningConfirm.open({
                    message: deleteConfirmationMsg,
                    variant: 'header',
                    label: deleteConfirmationTitle,
                    theme: 'error',
                });
                if (!result) return;
                await deleteFile({ documentId: fileId });
            }

            this.existingFiles = this.existingFiles.filter(f => f.id !== fileId);
            this.pendingFiles = this.pendingFiles.filter(f => f.id !== fileId);
            this.showToast(successTitle, deletedFileMsg, 'success');
        } catch (error) {
            this.showToast(failTitle, cannotDeleteFileMsg + (error.body?.message || error.message), 'error');
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