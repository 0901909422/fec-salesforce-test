import { LightningElement, api, wire, track } from 'lwc';
import getRecordHistory from '@salesforce/apex/FEC_HistoryController.getRecordHistory';
import { refreshApex } from '@salesforce/apex';

/**
 * @description: Reusable LWC to show History tracking
 * @author: DAT NGO
 * @date: 2026-03-11
 */
export default class FecConfigHistory extends LightningElement {
    // Tự động nhận từ Flexipage Context
    @api recordId;
    @api objectApiName;
    wiredHistoryResult; // Biến lưu kết quả wire để refresh

    @track lstHistory;
    @track error;
    @track isLoading = true; // Trạng thái loading

    showLog(methodName, message) {
        console.log(`[fecConfigHistory][${methodName}]: ${message}`);
    }

    @wire(getRecordHistory, { recordId: '$recordId', objectApiName: '$objectApiName' })
    wiredHistory(result) {
        this.wiredHistoryResult = result; // Lưu lại context để refresh sau này
        const { error, data } = result;
        this.showLog('wiredHistory', 'START with recordId: [' + this.recordId + ']');
        
        if (data) {
            this.lstHistory = data;
            this.error = undefined;
            this.isLoading = false; // Tắt loading khi có data
            this.showLog('wiredHistory', 'RETURN: Success with ' + data.length + ' records');
        } else if (error) {
            this.error = error.body.message;
            this.lstHistory = undefined;
            this.isLoading = false; // Tắt loading khi có lỗi
            this.showLog('wiredHistory', 'ERROR: ' + JSON.stringify(error));
        }
    }

    // Expose hàm này ra ngoài cho Parent LWC gọi
    @api
    refreshData() {
        this.showLog('refreshData', 'START');
        // Đảm bảo không bị lỗi nếu context chưa sẵn sàng
        if (this.wiredHistoryResult) {
            this.isLoading = true; // Bật loading lại mỗi khi refresh
            return refreshApex(this.wiredHistoryResult);
        }
        return Promise.resolve();
    }
}