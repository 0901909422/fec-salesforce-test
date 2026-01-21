import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';
import getCampaignMappings from '@salesforce/apex/FecCampaignController.getCampaignMappings';
import getInProgressSummary from '@salesforce/apex/FecCampaignController.getInProgressSummary';

export default class FecUploadCampaignData extends LightningElement {
    @track blnIsScheduleEnabled = false;
    @track blnRunSaturday = false;
    @track blnRunSunday = false;
    @track blnIsModalOpen = false;
    @track fileNameDisplay = 'No file chosen';
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
            this.showToast('Error', 'Lỗi tải danh sách Mapping: ' + error.body.message, 'error');
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
            this.showToast('Cảnh báo', `Campaign "${selectedRecord.Name}" đang ngưng hoạt động.`, 'warning');
            
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
            this.showToast('Error', 'Thư viện Excel chưa được tải xong.', 'error');
            return;
        }
        
        if (!this.inProgressData || this.inProgressData.length === 0) {
            this.showToast('Info', 'Không có dữ liệu In-progress để tải.', 'info');
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
        return !this.selectedMappingId;
    }

    handlePushRecord() {
        console.log('Action: Push Record');
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