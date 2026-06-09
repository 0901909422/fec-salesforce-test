import { LightningElement, api, track } from 'lwc';
import getUserQueues from '@salesforce/apex/DepartmentAdmin.getUserQueues';
import updateMainQueueForUser from '@salesforce/apex/DepartmentAdmin.updateMainQueueForUser';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { customLabels } from 'c/fec_ResourceHelper';

export default class Fec_UserQueueDetail extends LightningElement {
    customLabels = customLabels;
    
    @track queues = [];
    @track isLoading = false;
    @track error;
    @api userId;
    @api queueId;
    @track selectedQueueId = null; // Track selected queue for main queue assignment
    @track selectedMainQueueDevName = null;

    // Computed property for error message
    get errorMessage() {
        if (!this.error) {
            return this.customLabels.CS_OrgChart_Text_Unknow_Eror;
        }
        if (this.error.message) {
            return this.error.message;
        }
        if (typeof this.error.toString === 'function') {
            return this.error.toString();
        }
        return this.customLabels.CS_OrgChart_Text_Unknow_Eror;
    }

    connectedCallback() {
        try {
            // Ensure userId is valid before proceeding
            if (this.userId) {
                console.log('Fetching queues for userId:', this.userId);
                this.fetchUserQueues();
            } else {
                this.error = this.customLabels.CS_OrgChart_Text_UserDetail_Error_UserID_Null;
                console.log('Setting error: No user specified for queue lookup.');
            }
        } catch (error) {
            console.error('Error in connectedCallback:', error);
            this.error = this.customLabels.CS_OrgChart_Text_UserDetail_MainQueue_Init_Queue_Data_Err;
        }
    }
    
    fetchUserQueues() {
        if (!this.userId) return;
        
        this.isLoading = true;
        this.error = undefined;
        
        getUserQueues({ userId: this.userId })
            .then(result => {
                // Normalize the data to ensure all fields are properly set and avoid null/undefined values
                const normalizedQueues = (result || []).map(queue => {
                    // Ensure all required fields exist with proper default values
                    const normalizedQueue = {
                        id: queue && queue.id ? queue.id.toString() : '',
                        name: queue && queue.name ? queue.name.toString() : '',
                        email: queue && queue.email ? queue.email.toString() : '',
                        devname: queue && queue.devname ? queue.devname.toString() : '',
                        queueSobjectType: queue && queue.queueSobjectType ? queue.queueSobjectType.toString() : '',
                        isMainQueue: queue && queue.mainqueue ?  queue.mainqueue : false// Initialize as false
                    };
                    // Log the normalized data for debugging purposes
                    return normalizedQueue;
                });
                this.queues = normalizedQueues;
            })
            .catch(error => {
                this.error = error;
                console.error('Error fetching user queues:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    // Handle checkbox selection for main queue (single selection)
    handleCheckboxChange(event) {
        const isChecked = event.target.checked;
        if (isChecked) {
            const devName = event.target.dataset.devname;
            const queueId = event.target.dataset.id;
            
            // Reset all queues to unchecked
            this.queues = this.queues.map(queue => ({
                ...queue,
                isMainQueue: false
            }));
            
            // Check the selected queue
            this.queues = this.queues.map(queue => ({
                ...queue,
                isMainQueue: queue.id === queueId
            }));
            
            this.selectedMainQueueDevName = devName;
            this.selectedQueueId = queueId;
        } else {
            this.selectedMainQueueDevName = null;
        }
        
    }

    // Handle save button click
    async handleSaveMainQueue() {
        // Validate inputs
        if (!this.userId || !this.selectedMainQueueDevName) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.customLabels.CS_OrgChart_Text_Save_Error_Title,
                    message: this.customLabels.CS_OrgChart_Text_UserDetail_MainQueue_Select_Err,
                    variant: 'error'
                })
            );
            return;
        }

        this.isLoading = true;
        try {
            const result = await updateMainQueueForUser({
                queueId: this.queueId,
                userId: this.userId,
                namequeue: this.selectedMainQueueDevName
            });

            if (result === true) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.customLabels.CS_OrgChart_Text_Save_Success_Title,
                        message: this.customLabels.CS_OrgChart_Text_UserDetail_MainQueue_Success,
                        variant: 'success'
                    })
                );
                // Refresh queues to reflect the new main queue
                this.fetchUserQueues();
                this.dispatchEvent(new CustomEvent('closeuserdetailmodal', { detail: {} }));
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.customLabels.CS_OrgChart_Text_Save_Error_Title,
                        message: this.customLabels.CS_OrgChart_Text_UserDetail_MainQueue_Error,
                        variant: 'error'
                    })
                );
            }
        } catch (e) {
            const msg = (e && e.body && e.body.message) || e.message || this.customLabels.CS_OrgChart_Text_Unknow_Eror;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.customLabels.CS_OrgChart_Text_UserDetail_MainQueue_Error,
                    message: msg,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}