import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';
import { convertExcelToTimestamp } from 'c/fecUtils';
import uploadCampaignData from '@salesforce/apex/FecCampaignController.uploadCampaignData';


export default class FecUploadCampaignModal extends LightningElement {
    @api isShow = false;
    @api selectedCampaignId;

    @track isLoading = false;
    @track fileNameDisplay = 'No file chosen';
    
    selectedFile;
    librariesLoaded = false;

    // Cấu hình Header Excel
    EXCEL_HEADERS = [
        "ProductLine", "Campaign ID", "App ID", "Account or Contract number",
        "DateTime 1", "DateTime 2", "DateTime 3", "Number 1", "Number 2",
        "Number 3", "Number 4", "Number 5", "string 1", "string 2",
        "string 3", "string 4", "string 5"
    ];

    renderedCallback() {
        if (this.librariesLoaded) return;
        loadScript(this, FEC_SHEETJS)
            .then(() => { this.librariesLoaded = true; })
            .catch(error => { console.error('Error loading XLSX', error); });
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.selectedFile = file;
            this.fileNameDisplay = file.name;
        } else {
            this.fileNameDisplay = 'No file chosen';
        }
    }

    downloadTemplate() {
        if (!this.librariesLoaded) return;
        const XLSX = window.XLSX;
        const ws_data = [this.EXCEL_HEADERS];
        const worksheet = XLSX.utils.aoa_to_sheet(ws_data);
        const workbook = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(workbook, worksheet, "Template");
        XLSX.writeFile(workbook, "OutboundCampaignManualUpload_Template.xlsx");
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleConfirm() {
        if (!this.selectedFile) {
            this.showToast('Lỗi', 'Vui lòng chọn file Excel', 'error');
            return;
        }

        this.isUploading = true;
        
        // 1. Đọc file Excel bằng JS
        const reader = new FileReader();
        reader.onload = (e) => {
            const data = e.target.result;
            const XLSX = window.XLSX;

            const workbook = XLSX.read(data, { type: 'binary' });
            const firstSheetName = workbook.SheetNames[0];
            const worksheet = workbook.Sheets[firstSheetName];
            const jsonData = XLSX.utils.sheet_to_json(worksheet);

            this.sendDataToApex(jsonData);
        };
        reader.onerror = (error) => {
            this.isUploading = false;
            this.showToast('Lỗi', 'Không thể đọc file', 'error');
        };
        reader.readAsBinaryString(this.selectedFile);
    }

    async sendDataToApex(jsonData) {
        this.isLoading = true;

        try {
            const processedData = jsonData.map(row => {
                let newRow = { ...row };
        
                if (newRow['DateTime 1']) newRow['DateTime 1'] = convertExcelToTimestamp(newRow['DateTime 1']);
                if (newRow['DateTime 2']) newRow['DateTime 2'] = convertExcelToTimestamp(newRow['DateTime 2']);
                if (newRow['DateTime 3']) newRow['DateTime 3'] = convertExcelToTimestamp(newRow['DateTime 3']);
    
                return newRow;
            });
    
            const result = await uploadCampaignData({ 
                jsonString: JSON.stringify(processedData), 
                campaignId: this.selectedCampaignId 
            })

            if (result === 'Success') {
                this.showToast('Thành công', 'Đã lưu dữ liệu!', 'success');
                this.dispatchEvent(new CustomEvent('save'));
            }
        } catch (error) {
            this.showToast('Lỗi', error.body?.message || error.message, 'error');
        } finally {
            this.resetForm();
            this.isLoading = false;
        }
    }

    resetForm() {
        this.selectedFile = null;
        
        const fileInput = this.template.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.value = null; 
        }

        this.fileNameDisplay = 'No file chosen';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}