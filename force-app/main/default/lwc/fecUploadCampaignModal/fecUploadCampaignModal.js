import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';
import { convertExcelToTimestamp } from 'c/fecUtils';
import { SUCCESS_TITLE, FAIL_TITLE } from 'c/fecUtils';
import uploadCampaignData from '@salesforce/apex/FEC_CampaignController.uploadCampaignData';
import lblNoFileChosen from '@salesforce/label/c.FEC_Lbl_No_File_Chosen';
import savedDataMsg from '@salesforce/label/c.FEC_Saved_Data';
import errorUploadAtLeastExcelFile from '@salesforce/label/c.FEC_Error_Upload_At_Least_Excel_File';
import errorCannotReadFile from '@salesforce/label/c.FEC_Cannot_Read_File_Message';
import lblUploadCampaignData from '@salesforce/label/c.FEC_Lbl_Upload_Campaign_Data';
import lblUploadInstruction from '@salesforce/label/c.FEC_Lbl_Upload_Instruction';
import lblChooseFile from '@salesforce/label/c.FEC_Lbl_Choose_File';
import lblNoTemplateQuestion from '@salesforce/label/c.FEC_Lbl_No_Template_Question';
import btnDownloadTemplate from '@salesforce/label/c.FEC_Btn_Download_Template';
import btnCancel from '@salesforce/label/c.Cancel';
import btnSave from '@salesforce/label/c.Save';

export default class FecUploadCampaignModal extends LightningElement {
    label = {
        lblNoFileChosen,
        lblUploadCampaignData,
        lblUploadInstruction,
        lblChooseFile,
        lblNoTemplateQuestion,
        btnDownloadTemplate,
        btnCancel,
        btnSave
    };
    @api isShow = false;
    @api selectedCampaignId;

    @track isLoading = false;
    @track fileNameDisplay = this.label.lblNoFileChosen;
    
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
            this.fileNameDisplay = this.label.lblNoFileChosen;
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
            this.showToast(FAIL_TITLE, errorUploadAtLeastExcelFile, 'error');
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
            this.showToast(FAIL_TITLE, errorCannotReadFile, 'error');
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
                csCampaignId: this.selectedCampaignId 
            })

            if (result === 'Success') {
                this.showToast(SUCCESS_TITLE, savedDataMsg, 'success');
                this.dispatchEvent(new CustomEvent('save'));
            }
        } catch (error) {
            this.showToast(FAIL_TITLE, error.body?.message || error.message, 'error');
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

        this.fileNameDisplay = this.label.lblNoFileChosen;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}