import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { SUCCESS_TITLE, FAIL_TITLE, WARNING_TITLE } from 'c/fecUtils';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';
import getCampaignMappings from '@salesforce/apex/FEC_CampaignController.getCampaignMappings';
import getInProgressSummary from '@salesforce/apex/FEC_CampaignController.getInProgressSummary';
import pushRecords from '@salesforce/apex/FEC_CampaignController.pushRecords';
import saveConfigurationDetails from '@salesforce/apex/FEC_CampaignController.saveConfigurationDetails';
import unableToLoadRecordsMsg from '@salesforce/label/c.FEC_Unable_To_Load_Records_Message';
import savedDataMsg from '@salesforce/label/c.FEC_Saved_Data';
import savingConfigErrMsg from '@salesforce/label/c.FEC_Saving_Configuration_Error_Message';
import selectACampaignMsg from '@salesforce/label/c.FEC_Please_Select_A_Campaign_Message';
import errorLoadExcelLib from '@salesforce/label/c.FEC_Load_Excel_Lib';
import inactiveItemMsg from '@salesforce/label/c.FEC_Label_Status_INACTIVE';
import noContentMsg from '@salesforce/label/c.FEC_Msg_No_Content';
import notifyPushStartedMsg from '@salesforce/label/c.FEC_Notify_Push_Started';
import lblCampaignConfiguration from '@salesforce/label/c.FEC_Lbl_Campaign_Configuration';
import btnSave from '@salesforce/label/c.FEC_Save';
import lblCsCampaignMapping from '@salesforce/label/c.FEC_Lbl_CS_Campaign_Mapping';
import placeholderSelectCampaign from '@salesforce/label/c.FEC_Placeholder_Select_Campaign';
import lblNoOfInprogressRecords from '@salesforce/label/c.FEC_Lbl_No_Of_Inprogress_Records';
import btnDownloadExcel from '@salesforce/label/c.FEC_Btn_Download_Excel';
import lblDbJobAnnouncement from '@salesforce/label/c.FEC_Lbl_DB_Job_Announcement';
import lblEnableSchedule from '@salesforce/label/c.FEC_Lbl_Enable_Schedule';
import lblRunWeekendQuestion from '@salesforce/label/c.FEC_Lbl_Run_Weekend_Question';
import lblSaturday from '@salesforce/label/c.FEC_Lbl_Saturday';
import lblSunday from '@salesforce/label/c.FEC_Lbl_Sunday';
import btnPushRecord from '@salesforce/label/c.FEC_Btn_Push_Record';
import lblUploadCampaignData from '@salesforce/label/c.FEC_Lbl_Upload_Campaign_Data';

export default class FecUploadCampaignData extends LightningElement {
    label = {
        lblCampaignConfiguration,
        btnSave,
        lblCsCampaignMapping,
        placeholderSelectCampaign,
        lblNoOfInprogressRecords,
        btnDownloadExcel,
        lblDbJobAnnouncement,
        lblEnableSchedule,
        lblRunWeekendQuestion,
        lblSaturday,
        lblSunday,
        btnPushRecord,
        lblUploadCampaignData
    };

    @track blnIsScheduleEnabled = false;
    @track blnRunSaturday = false;
    @track blnRunSunday = false;
    @track isSaving = false;
    @track blnIsModalOpen = false;
    @track inProgressCount = 0;
    @track inProgressData = [];
    @track mappingOptions = [];

    selectedMappingId = '';
    rawMappingData = [];
    librariesLoaded = false;
    EXCEL_HEADERS = [
        "ProductLine",
        "Campaign ID",
        "App ID",
        "Account or Contract number",
        "DateTime 1",
        "DateTime 2",
        "DateTime 3",
        "Number 1",
        "Number 2",
        "Number 3",
        "Number 4",
        "Number 5",
        "String 1",
        "String 2",
        "String 3",
        "String 4",
        "String 5"
    ];

    renderedCallback() {
        if (this.librariesLoaded) return;
        loadScript(this, FEC_SHEETJS)
            .then(() => { this.librariesLoaded = true; })
            .catch(error => { console.error('Error loading XLSX', error); });
    }

    @wire(getCampaignMappings)
    wiredMappings({ error, data }) {
        if (data) {
            this.rawMappingData = data;
            let options = data.map(record => {
                let labelDisplay = record.Name;
                if (!record.FEC_IsActive__c) {
                    labelDisplay = '⛔ ' + labelDisplay;
                }
                return {
                    label: labelDisplay,
                    value: record.Id,
                    isActive: record.FEC_IsActive__c,
                    name: record.Name
                };
            });

            options.sort((a, b) => a.name.localeCompare(b.name));

            this.mappingOptions = options;

        } else if (error) {
            this.showToast(FAIL_TITLE, unableToLoadRecordsMsg + error.body.message, 'error');
        }
    }

    async refreshInProgressDetails() {
        if (!this.selectedMappingId) return;
        
        try {
            const res = await getInProgressSummary({ mappingId: this.selectedMappingId });
            this.inProgressCount = res.count;
            this.inProgressData = res.data;
        } catch (error) {
            console.error('Error refreshing count:', error);
        }
    }

    async handleMappingChange(event) {
        const selectedId = event.detail.value;
        const selectedRecord = this.rawMappingData.find(item => item.Id === selectedId);

        if (selectedRecord && !selectedRecord.FEC_IsActive__c) {
            this.showToast(WARNING_TITLE, `Campaign "${selectedRecord.Name + inactiveItemMsg}"`, 'warning');
            
            setTimeout(() => {
                this.inProgressCount = 0;
                this.inProgressData = null;
                this.selectedMappingId = null;
                const combobox = this.template.querySelector('lightning-combobox[data-id="mappingDropdown"]');
                if(combobox) combobox.value = null;
            }, 0);
            
            return; 
        }

        this.selectedMappingId = selectedId;

        if (selectedRecord && selectedRecord.FEC_Campaign__r) {
            // Gán giá trị từ Object cha vào biến UI, mặc định false nếu null
            this.blnIsScheduleEnabled = selectedRecord.FEC_ScheduleCampaign__c || false;
            this.blnRunSaturday = selectedRecord.FEC_SaturdaySchedule__c || false;
            this.blnRunSunday = selectedRecord.FEC_SundaySchedule__c || false;
        } else {
            // Reset về false nếu không tìm thấy dữ liệu liên quan
            this.blnIsScheduleEnabled = false;
            this.blnRunSaturday = false;
            this.blnRunSunday = false;
        }
        await this.refreshInProgressDetails();
    }

    findCSCampaignLabel(id) {
        if (id == null) return;
        const csCampaign = this.mappingOptions.find(item => item.value === id);
        return csCampaign.label;
    }

    handleDownloadExcel() {
        // 1. Kiểm tra thư viện và dữ liệu
        if (!this.librariesLoaded || !window.XLSX) {
            this.showToast(FAIL_TITLE, errorLoadExcelLib, 'error');
            return;
        }
        
        if (!this.inProgressData || this.inProgressData.length === 0) {
            this.showToast(WARNING_TITLE, noContentMsg, 'info');
            return;
        }
    
        const XLSX = window.XLSX;
    
        // 2. Khởi tạo mảng dữ liệu với dòng đầu tiên là Header
        const ws_data = [this.EXCEL_HEADERS];
    
        // 3. Map dữ liệu từ Object sang mảng theo đúng thứ tự cột của Header
        this.inProgressData.forEach(item => {
            ws_data.push([
                item.FEC_ProductLine__c || '',               // ProductLine
                this.findCSCampaignLabel(this.selectedMappingId) || '',                // Campaign ID (lấy từ biến chung)
                item.FEC_AppId__c || '',                    // App ID
                item.FEC_AccountOrContractNumber__c || '',   // Account or Contract number
                item.FEC_DateTime1__c || '',                // DateTime 1
                item.FEC_DateTime2__c || '',                // DateTime 2
                item.FEC_DateTime3__c || '',                // DateTime 3
                item.FEC_Number1__c ?? 0,                   // Number 1 (Dùng ?? để giữ giá trị 0)
                item.FEC_Number2__c ?? 0,                   // Number 2
                item.FEC_Number3__c ?? 0,                   // Number 3
                item.FEC_Number4__c ?? 0,                   // Number 4
                item.FEC_Number5__c ?? 0,                   // Number 5
                item.FEC_String1__c || '',                  // String 1
                item.FEC_String2__c || '',                  // String 2
                item.FEC_String3__c || '',                  // String 3
                item.FEC_String4__c || '',                  // String 4
                item.FEC_String5__c || ''                   // String 5
            ]);
        });
    
        // 4. Tạo Worksheet và Workbook bằng thư viện
        const worksheet = XLSX.utils.aoa_to_sheet(ws_data);
        const workbook = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(workbook, worksheet, "InProgress_Records");
    
        // 5. Xuất file với định dạng .xlsx chuẩn
        const fileName = `Campaign_InProgress_${new Date().getTime()}.xlsx`;
        XLSX.writeFile(workbook, fileName);
    }

    handleToggleSchedule(event) {
        this.blnIsScheduleEnabled = event.target.checked;
        if (!this.blnIsScheduleEnabled) {
            this.blnRunSaturday = false;
            this.blnRunSunday = false;
        }
    }

    handleDayChange(event) {
        if (event.target.name === 'saturday') this.blnRunSaturday = event.target.checked;
        if (event.target.name === 'sunday') this.blnRunSunday = event.target.checked;
    }

    get isPushDisabled() {
        return !this.selectedMappingId || this.isLoading;
    }

    /**
     * Xử lý sự kiện lưu cấu hình Schedule
     */
    async handleSaveSchedule() {
        if (!this.selectedMappingId) {
            this.showToast(FAIL_TITLE, selectACampaignMsg, 'error');
            return;
        }

        this.isSaving = true;
        try {
            // Truyền các giá trị cờ hiện tại trên UI xuống Apex
            await saveConfigurationDetails({
                mappingId: this.selectedMappingId,
                isSchedule: this.blnIsScheduleEnabled,
                isSaturday: this.blnRunSaturday,
                isSunday: this.blnRunSunday
            });
            
            this.showToast(SUCCESS_TITLE, savedDataMsg, 'success');
        } catch (error) {
            this.showToast(FAIL_TITLE, savingConfigErrMsg + (error.body ? error.body.message : error.message), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handlePushRecord() {
        if (!this.selectedMappingId) {
            this.showToast(FAIL_TITLE, selectACampaignMsg, 'error');
            return;
        }
    
        this.isLoading = true;
        try {
            await pushRecords({ mappingId: this.selectedMappingId });
            
            this.showToast(SUCCESS_TITLE, notifyPushStartedMsg, 'success');
            await this.refreshInProgressDetails();
        } catch (error) {
            this.showToast(FAIL_TITLE, error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFile() {
        await this.refreshInProgressDetails();
        this.closeModal();
    }

    /**
     * Mở Modal khi nhấn nút Upload
     */
    handleUploadData() {
        this.blnIsModalOpen = true;
    }

    /**
     * Đóng Modal
     */
    closeModal() {
        this.blnIsModalOpen = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}