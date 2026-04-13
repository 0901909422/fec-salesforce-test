import { LightningElement, api, wire, track } from 'lwc';

import { getFocusedTabInfo, setTabLabel, setTabIcon } from 'lightning/platformWorkspaceApi';

import getCaseData from '@salesforce/apex/FEC_ServiceFraudTaskCaseController.getCaseData';
import submitProcessCaseDecision from '@salesforce/apex/FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision';

// =====================
// Custom Labels
// =====================
import LBL_SFT_Fraud_Task from '@salesforce/label/c.LBL_SFT_Fraud_Task';
import LBL_SFT_Status from '@salesforce/label/c.LBL_SFT_Status';
import LBL_SFT_Assign_To_Me from '@salesforce/label/c.LBL_SFT_Assign_To_Me';
import LBL_SFT_Loading from '@salesforce/label/c.LBL_SFT_Loading';

import LBL_SFT_Customer_Information from '@salesforce/label/c.LBL_SFT_Customer_Information';
import LBL_SFT_Fraud_Case_Information from '@salesforce/label/c.LBL_SFT_Fraud_Case_Information';
import LBL_SFT_Task_Case_Information from '@salesforce/label/c.LBL_SFT_Task_Case_Information';
import LBL_SFT_Notification_History from '@salesforce/label/c.LBL_SFT_Notification_History';
import LBL_SFT_Related_Service_Cases from '@salesforce/label/c.LBL_SFT_Related_Service_Cases';
import LBL_SFT_Fraud_Cases from '@salesforce/label/c.LBL_SFT_Fraud_Cases';
import LBL_SFT_Remarks_History from '@salesforce/label/c.LBL_SFT_Remarks_History';
import LBL_SFT_Customer_Name from '@salesforce/label/c.LBL_SFT_Customer_Name';
import LBL_SFT_Contract_Number from '@salesforce/label/c.LBL_SFT_Contract_Number';
import LBL_SFT_National_ID from '@salesforce/label/c.LBL_SFT_National_ID';
import LBL_SFT_Primary_Phone from '@salesforce/label/c.LBL_SFT_Primary_Phone';
import LBL_SFT_Application_ID from '@salesforce/label/c.LBL_SFT_Application_ID';
import LBL_SFT_Product_Type from '@salesforce/label/c.LBL_SFT_Product_Type';
import LBL_SFT_Account_Number from '@salesforce/label/c.LBL_SFT_Account_Number';
import LBL_SFT_Toggle_National_ID from '@salesforce/label/c.LBL_SFT_Toggle_National_ID';
import LBL_SFT_Toggle_Phone from '@salesforce/label/c.LBL_SFT_Toggle_Phone';
import LBL_SFT_Fraud_Case_ID from '@salesforce/label/c.LBL_SFT_Fraud_Case_ID';
import LBL_SFT_Created_Date from '@salesforce/label/c.LBL_SFT_Created_Date';
import LBL_SFT_Created_By from '@salesforce/label/c.LBL_SFT_Created_By';
import LBL_SFT_Fraud_Category from '@salesforce/label/c.LBL_SFT_Fraud_Category';
import LBL_SFT_Fraud_Subcategory from '@salesforce/label/c.LBL_SFT_Fraud_Subcategory';
import LBL_SFT_Reference_ID from '@salesforce/label/c.LBL_SFT_Reference_ID';
import LBL_SFT_Customer_Care from '@salesforce/label/c.LBL_SFT_Customer_Care';
import LBL_SFT_Remarks from '@salesforce/label/c.LBL_SFT_Remarks';
import LBL_SFT_Fraud_Sub_Code from '@salesforce/label/c.LBL_SFT_Fraud_Sub_Code';
import LBL_SFT_Task_Case_ID from '@salesforce/label/c.LBL_SFT_Task_Case_ID';

import LBL_SFT_Task_Status from '@salesforce/label/c.LBL_SFT_Task_Status';
import LBL_SFT_UIC from '@salesforce/label/c.LBL_SFT_UIC';
import LBL_SFT_Deadline from '@salesforce/label/c.LBL_SFT_Deadline';
import LBL_SFT_Task_Name from '@salesforce/label/c.LBL_SFT_Task_Name';
import LBL_SFT_Violation_Type from '@salesforce/label/c.LBL_SFT_Violation_Type';
import LBL_SFT_Fraud_Conclusion from '@salesforce/label/c.LBL_SFT_Fraud_Conclusion';
import LBL_SFT_Notification_Type from '@salesforce/label/c.LBL_SFT_Notification_Type';
import LBL_SFT_Template_Name from '@salesforce/label/c.LBL_SFT_Template_Name';
import LBL_SFT_Notification_Channel from '@salesforce/label/c.LBL_SFT_Notification_Channel';
import LBL_SFT_Recipient from '@salesforce/label/c.LBL_SFT_Recipient';
import LBL_SFT_Delivery_Status from '@salesforce/label/c.LBL_SFT_Delivery_Status';
import LBL_SFT_Sent_Time from '@salesforce/label/c.LBL_SFT_Sent_Time';
import LBL_SFT_Actual_Delivery_Time from '@salesforce/label/c.LBL_SFT_Actual_Delivery_Time';
import LBL_SFT_Service_Case_ID from '@salesforce/label/c.LBL_SFT_Service_Case_ID';
import LBL_SFT_Case_Type from '@salesforce/label/c.LBL_SFT_Case_Type';
import LBL_SFT_Case_Status from '@salesforce/label/c.LBL_SFT_Case_Status';
import LBL_SFT_Resolved_By from '@salesforce/label/c.LBL_SFT_Resolved_By';
import LBL_SFT_Created_On from '@salesforce/label/c.LBL_SFT_Created_On';
import LBL_SFT_Resolved_On from '@salesforce/label/c.LBL_SFT_Resolved_On';
import LBL_SFT_Creator from '@salesforce/label/c.LBL_SFT_Creator';
import LBL_SFT_Category from '@salesforce/label/c.LBL_SFT_Category';
import LBL_SFT_Sub_Category from '@salesforce/label/c.LBL_SFT_Sub_Category';
import LBL_SFT_Sub_Code from '@salesforce/label/c.LBL_SFT_Sub_Code';
import LBL_SFT_Create_Time from '@salesforce/label/c.LBL_SFT_Create_Time';
import LBL_SFT_Update_Time from '@salesforce/label/c.LBL_SFT_Update_Time';
import LBL_SFT_Submit_By_Department from '@salesforce/label/c.LBL_SFT_Submit_By_Department';
import LBL_SFT_Processing_Status from '@salesforce/label/c.LBL_SFT_Processing_Status';
import LBL_SFT_Decision from '@salesforce/label/c.LBL_SFT_Decision';
import LBL_SFT_Created_Date_Time from '@salesforce/label/c.LBL_SFT_Created_Date_Time';
import LBL_SFT_Assigned_To from '@salesforce/label/c.LBL_SFT_Assigned_To';
import LBL_SFT_Case_Id from '@salesforce/label/c.LBL_SFT_Case_Id';
import LBL_SFT_Account_Owner from '@salesforce/label/c.LBL_SFT_Account_Owner';
import LBL_SFT_Urgency from '@salesforce/label/c.LBL_SFT_Urgency';
import LBL_SFT_Goal from '@salesforce/label/c.LBL_SFT_Goal';
import LBL_SFT_Deadline_Date from '@salesforce/label/c.LBL_SFT_Deadline_Date';
import LBL_SFT_Last_Update from '@salesforce/label/c.LBL_SFT_Last_Update';
import LBL_SFT_Created from '@salesforce/label/c.LBL_SFT_Created';
import LBL_SFT_Created_In_Channel from '@salesforce/label/c.LBL_SFT_Created_In_Channel';
import LBL_SFT_Last_Updated_By from '@salesforce/label/c.LBL_SFT_Last_Updated_By';
import LBL_SFT_Case_Will_Be_Transferred  from '@salesforce/label/c.LBL_SFT_Case_Will_Be_Transferred';
import LBL_SFT_Cancel_Reasons from '@salesforce/label/c.LBL_SFT_Cancel_Reasons';
import LBL_SFT_Value_Cannot_Be_Blank from '@salesforce/label/c.LBL_SFT_Value_Cannot_Be_Blank';
import LBL_SFT_Enter_Investigation_Notes from '@salesforce/label/c.LBL_SFT_Enter_Investigation_Notes';
import LBL_SFT_Submit from '@salesforce/label/c.LBL_SFT_Submit';








export default class ServiceFraudTaskCaseAction extends LightningElement {
    @api recordId;
    @track isLoading = true;
    @track effectiveRecordId;
   
    labels = {
        // ===== HEADER =====
        fraudTask: LBL_SFT_Fraud_Task,
        status: LBL_SFT_Status,
        assignToMe: LBL_SFT_Assign_To_Me,
        loading: LBL_SFT_Loading,
    
        // ===== SECTION TITLES =====
        customerInfo: LBL_SFT_Customer_Information,
        fraudCaseInfo: LBL_SFT_Fraud_Case_Information,
        taskCaseInfo: LBL_SFT_Task_Case_Information,
        notificationHistory: LBL_SFT_Notification_History,
        relatedServiceCases: LBL_SFT_Related_Service_Cases,
        fraudCases: LBL_SFT_Fraud_Cases,
        remarksHistory: LBL_SFT_Remarks_History,
    
        // ===== CUSTOMER INFO =====
        customerName: LBL_SFT_Customer_Name,
        contractNumber: LBL_SFT_Contract_Number,
        nationalId: LBL_SFT_National_ID,
        primaryPhone: LBL_SFT_Primary_Phone,
        applicationId: LBL_SFT_Application_ID,
        productType: LBL_SFT_Product_Type,
        accountNumber: LBL_SFT_Account_Number,
        toggleNationalId: LBL_SFT_Toggle_National_ID,
        togglePhone: LBL_SFT_Toggle_Phone,
    
        // ===== FRAUD INFO =====
        fraudCaseId: LBL_SFT_Fraud_Case_ID,
        createdDate: LBL_SFT_Created_Date,
        createdBy: LBL_SFT_Created_By,
        fraudCategory: LBL_SFT_Fraud_Category,
        fraudSubCategory: LBL_SFT_Fraud_Subcategory,
        referenceId: LBL_SFT_Reference_ID,
        customerCare: LBL_SFT_Customer_Care,
        remarks: LBL_SFT_Remarks,
        fraudSubCode: LBL_SFT_Fraud_Sub_Code,
    
        // ===== TASK INFO =====
        taskCaseId: LBL_SFT_Task_Case_ID,
        taskStatus: LBL_SFT_Task_Status,
        uic: LBL_SFT_UIC,
        deadline: LBL_SFT_Deadline,
        taskName: LBL_SFT_Task_Name,
        violationType: LBL_SFT_Violation_Type,
        fraudConclusion: LBL_SFT_Fraud_Conclusion,
    
        // ===== NOTIFICATION TABLE =====
        notificationType: LBL_SFT_Notification_Type,
        templateName: LBL_SFT_Template_Name,
        notificationChannel: LBL_SFT_Notification_Channel,
        recipient: LBL_SFT_Recipient,
        deliveryStatus: LBL_SFT_Delivery_Status,
        sentTime: LBL_SFT_Sent_Time,
        actualDeliveryTime: LBL_SFT_Actual_Delivery_Time,
    
        // ===== SERVICE CASES =====
        serviceCaseId: LBL_SFT_Service_Case_ID,
        caseType: LBL_SFT_Case_Type,
        caseStatus: LBL_SFT_Case_Status,
        resolvedBy: LBL_SFT_Resolved_By,
        createdOn: LBL_SFT_Created_On,
        resolvedOn: LBL_SFT_Resolved_On,
    
        // ===== FRAUD CASE TABLE =====
        creator: LBL_SFT_Creator,
        category: LBL_SFT_Category,
        subCategory: LBL_SFT_Sub_Category,
        subCode: LBL_SFT_Sub_Code,
        createTime: LBL_SFT_Create_Time,
        updateTime: LBL_SFT_Update_Time,
    
        // ===== REMARKS HISTORY =====
        submitByDepartment: LBL_SFT_Submit_By_Department,
        processingStatus: LBL_SFT_Processing_Status,
        decision: LBL_SFT_Decision,
        createdDateTime: LBL_SFT_Created_Date_Time,
        assignedTo: LBL_SFT_Assigned_To,
    
        // ===== FOOTER =====
        caseId: LBL_SFT_Case_Id,
        accountOwner: LBL_SFT_Account_Owner,
        urgency: LBL_SFT_Urgency,
        goal: LBL_SFT_Goal,
        deadlineDate: LBL_SFT_Deadline_Date,
        lastUpdate: LBL_SFT_Last_Update,
        created: LBL_SFT_Created,
        createdInChannel: LBL_SFT_Created_In_Channel,
        lastUpdatedBy: LBL_SFT_Last_Updated_By,
    
        // ===== MODAL / MESSAGE =====
        caseWillBeTransferred: LBL_SFT_Case_Will_Be_Transferred,
        cancelReasons: LBL_SFT_Cancel_Reasons,
        valueCannotBeBlank: LBL_SFT_Value_Cannot_Be_Blank,
        enterInvestigationNotes: LBL_SFT_Enter_Investigation_Notes,
        submit: LBL_SFT_Submit
    };
    
    // ===== DTO DATA =====
    @track data;
    @track caseInfo;
    @track customer;
    @track fraud;
    @track task;
    @track footer;
   

    filters = {
        actor: '',
        remarks: '',
        decision: '',
        createdBy: '',
        createdDate: ''
    };


    // ===== UI STATE =====
    @track showCustomer = true;
    @track showFraud = true;
    @track showTask = true;
    @track showHistory = true;
    @track showFraudCases = true;
    @track showRelatedServiceCases= true;
	@track showRemarksHistory = true;
	@track showNotificationHistory = true;
	
	@track showFraudCasesHistory = true;

    // ===== FORM STATE =====
    @track decision = '';
    @track remarks = '';
    @track cancelReason = '';
    @track showCancelError = false;

    @track notificationHistory = [];   // original data
    @track notificationHistoryData = [];
    notificationHistorySortBy;
    notificationHistorySortDirection = 'asc';

    @track remarksHistoryData = [];
    @track sortedRemarksData = [];
    remarksSortBy;
    remarksSortDirection = 'asc';

    @track relatedServiceCasesData = [];
    @track sortedRelatedServiceCasesData = [];
    serviceCaseSortBy;
    serviceCaseSortDirection = 'asc';

    @track fraudCasesData = [];
    @track sortedFraudCasesData = [];
    
    
    connectedCallback() {
        console.log('recordId:', this.recordId);
    
        if (this.recordId) {
            this.effectiveRecordId = this.recordId;
        }
    
        if (!this.effectiveRecordId) {
            console.error('No caseId provided!');
            this.isLoading = false;
        }
    }

    // ===== OPTIONS =====
    decisionOptions = [
        { label: 'Completed', value: 'Completed' },
        { label: 'Cancel', value: 'Cancel' }
    ];

    cancelOptions = [
        { label: 'Task was done before', value: 'DONE_BEFORE' },
        { label: 'Not for task', value: 'NOT_FOR_TASK' }
    ];
    // Status flag
    get isPending() {
        return this.caseInfo && this.caseInfo.caseStatus
            ? this.caseInfo.caseStatus.toLowerCase().includes('pending')
            : false;
    }
    

    // Assign popup
    showAssignModal = false;

    handleAssign() {
        this.showAssignModal = true;
    }

    closeAssignModal() {
        this.showAssignModal = false;
    }

    confirmAssign() {
        this.showAssignModal = false;
        this.assignCaseToMe();
    }
    assignCaseToMe() {

    }
    async updateTabTitle(retry = 0) {
        try {
            console.log('Updating tab title attempt:', retry);

            const tabInfo = await getFocusedTabInfo();
            console.log('updateTabTitle:', JSON.stringify(tabInfo));

    
            if (!tabInfo || !tabInfo.tabId) {
                if (retry < 10) {
                    setTimeout(() => this.updateTabTitle(retry + 1), 300);
                }
                return;
            }
    
            const title = 'Fraud Task ' + this.effectiveRecordId;
    
            await setTabLabel(tabInfo.tabId, title);
            await setTabIcon(tabInfo.tabId, 'standard:case', title);
    
        } catch (e) {
            if (retry < 10) {
                setTimeout(() => this.updateTabTitle(retry + 1), 300);
            }
        }
    }
    
    
    
    // ===== LOAD DATA =====
    @wire(getCaseData, { caseId: '$effectiveRecordId' })
    wiredCase({ data, error }) {
        if (data) {            
            this.data = data;
            this.caseInfo = data.caseInfo;
            this.customer = data.customer;
            this.sortedFraudCasesData = Array.isArray(data.fraudCasesList)
            ? data.fraudCasesList
            : [];
            this.fraud = data.fraud;
            this.task = data.task;
            this.footer = data.caseInfo;           
            this.notificationHistoryData = Array.isArray(data.notificationInfo)
            ? data.notificationInfo
            : [];
            this.sortedRemarksData = Array.isArray(data.remarksInfo)
            ? data.remarksInfo
            : [];
            //console.log('sortedRemarksData: ' + JSON.stringify(this.sortedRemarksData));
            this.sortedRelatedServiceCasesData = Array.isArray(data.serviceCasesInfo)
            ? data.serviceCasesInfo
            : [];         
            //console.log('Loaded DTO:', JSON.stringify(data));
            this.isLoading = false;
            this.updateTabTitle();
        } else if (error) {
            console.error('Load case error:', error);
            this.isLoading = false;
        }
    }    

    //-----------Notification History-------------------
    handleSortNotification(event) {
        const field = event.target.dataset.field;

        this.notificationHistorySortDirection = this.notificationHistorySortBy === field && this.notificationHistorySortDirection === 'asc'
            ? 'desc'
            : 'asc';

        this.notificationHistorySortBy = field;
        this.sortNotificationData(field, this.notificationHistorySortDirection);
    }
    sortNotificationData(field, direction) {
        const isAsc = direction === 'asc';

        this.notificationHistoryData = [...this.notificationHistoryData].sort((a, b) => {
            let x = a[field] || '';
            let y = b[field] || '';

            if (typeof x === 'string') {
                x = x.toLowerCase();
                y = y.toLowerCase();
            }

            return isAsc ? (x > y ? 1 : -1) : (x < y ? -1 : 1);
        });
    }

    //-----------Notification History-------------------

    //-----------Remarks History-------------------   
    handleRemarksSort(event) {
        const field = event.target.dataset.field;

        this.remarksSortDirection =
            this.remarksSortBy === field && this.remarksSortDirection === 'asc'
                ? 'desc'
                : 'asc';

        this.remarksSortBy = field;
        this.sortRemarksData(field, this.remarksSortDirection);
    }

    sortRemarksData(field, direction) {
        const isAsc = direction === 'asc';

        this.sortedRemarksData = [...this.sortedRemarksData].sort((a, b) => {
            let x = a[field] || '';
            let y = b[field] || '';

            if (typeof x === 'string') {
                x = x.toLowerCase();
                y = y.toLowerCase();
            }

            return isAsc ? (x > y ? 1 : -1) : (x < y ? -1 : 1);
        });
    }

    //-----------Remarks History-------------------

    //-----------Related Service Fraud Cases-------------------
    handleServiceCaseSort(event) {
        const field = event.target.dataset.field;
    
        this.serviceCaseSortDirection =
            this.serviceCaseSortBy === field && this.serviceCaseSortDirection === 'asc'
                ? 'desc'
                : 'asc';
    
        this.serviceCaseSortBy = field;
        this.sortServiceCaseData(field, this.serviceCaseSortDirection);
    }
    
    sortServiceCaseData(field, direction) {
        const isAsc = direction === 'asc';
    
        this.sortedRelatedServiceCasesData = [...this.sortedRelatedServiceCasesData].sort((a, b) => {
            let x = a[field] || '';
            let y = b[field] || '';
    
            if (typeof x === 'string') {
                x = x.toLowerCase();
                y = y.toLowerCase();
            }
    
            return isAsc ? (x > y ? 1 : -1) : (x < y ? -1 : 1);
        });
    } 
    //-----------Related Service Fraud Cases-------------------  
    
    //-----------Fraud Cases-------------------
    fraudSortBy = 'fraudCaseId';    
    fraudSortDirection = 'asc';

    get isSortedByFraudId() {
        return this.fraudSortBy === 'fraudCaseId';
    }
    get isSortedBycaseStatus() {
        return this.fraudSortBy === 'caseStatus';
    }
    get isSortedBycreator() {
        return this.fraudSortBy === 'creator';
    }
    get isSortedBycategory() {
        return this.fraudSortBy === 'category';
    }
    get isSortedBysubCategory() {
        return this.fraudSortBy === 'subCategory';
    }
    get isSortedBysubCode() {
        return this.fraudSortBy === 'subCode';
    }
    get isSortedBycreateTime() {
        return this.fraudSortBy === 'createTime';
    }
    get isSortedByupdateTime() {
        return this.fraudSortBy === 'updateTime';
    }
    

    get sortfraudtIcon() {
        return this.fraudSortDirection === 'asc'
            ? 'utility:arrowup'
            : 'utility:arrowdown';
    }

    handleFraudSort(event) {
        const field = event.currentTarget.dataset.field;

        if (this.fraudSortBy === field) {
            this.fraudSortDirection =
                this.fraudSortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.fraudSortBy = field;
            this.fraudSortDirection = 'asc';
        }

        this.sortFraudData(field, this.fraudSortDirection);
    }

    sortFraudData(field, direction) {
        const isAsc = direction === 'asc';

        this.sortedFraudCasesData = [...this.sortedFraudCasesData].sort((a, b) => {
            let x = a[field] ?? '';
            let y = b[field] ?? '';

            if (typeof x === 'string') {
                x = x.toLowerCase();
                y = y.toLowerCase();
            }

            return isAsc ? (x > y ? 1 : -1) : (x < y ? -1 : 1);
        });
    }

    //-----------Fraud Cases-------------------



    // ===== ICONS =====
    get customerIcon() { return this.showCustomer ? 'utility:chevrondown' : 'utility:chevronright'; }
    get fraudIcon()    { return this.showFraud ? 'utility:chevrondown' : 'utility:chevronright'; }
    get taskIcon()     { return this.showTask ? 'utility:chevrondown' : 'utility:chevronright'; }
    get historyIcon()  { return this.showHistory ? 'utility:chevrondown' : 'utility:chevronright'; }
	get remarksHistoryIcon()  { return this.showRemarksHistory ? 'utility:chevrondown' : 'utility:chevronright'; }
	get notificationHistoryIcon()  { return this.showNotificationHistory ? 'utility:chevrondown' : 'utility:chevronright'; }
	
    get fraudCasesIcon()  { return this.showFraudCases ? 'utility:chevrondown' : 'utility:chevronright'; }
    get relatedServiceCasesIcon()  { return this.showRelatedServiceCases ? 'utility:chevrondown' : 'utility:chevronright'; }
	get fraudCasesHistoryIcon()  { return this.showFraudCasesHistory ? 'utility:chevrondown' : 'utility:chevronright'; }
	
    
    

    // ===== COMPUTED =====
    get isCancel() {
        return this.decision === 'Cancel';
    }

    // ===== COLLAPSE =====
    toggleCustomer() { this.showCustomer = !this.showCustomer; }
    toggleFraud()    { this.showFraud = !this.showFraud; }
    toggleTask()     { this.showTask = !this.showTask; }
	toggleRemarksHistory()     { this.showRemarksHistory = !this.showRemarksHistory ; }
    toggleHistory()  { this.showHistory = !this.showHistory; }
    toggleFraudCases()  { this.showFraudCases = !this.showFraudCases; }
	toggleNotificationHistory()  { this.showNotificationHistory = !this.showNotificationHistory; }	
    toggleRelatedServiceCases()  { this.showRelatedServiceCases = !this.showRelatedServiceCases; }
	toggleFraudCasesHistory()  { this.showFraudCasesHistory = !this.showFraudCasesHistory; }
	

    

    // ===== FORM =====
    handleDecisionChange(event) {
        this.decision = event.detail.value;
        if (this.decision !== 'Cancel') {
            this.cancelReason = '';
            this.showCancelError = false;
        }
    }

    handleCancelReasonChange(event) {
        this.cancelReason = event.detail.value;
        this.showCancelError = false;
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    submit() {
        if (!this.decision) {
            alert('Please select a decision');
            return;
        }
    
        if (!this.remarks) {
            alert('Please input your remark');
            return;
        }
    
        if (this.isCancel && !this.cancelReason) {
            this.showCancelError = true;
            return;
        }
        console.log('Submit clicked');
        console.log('recordId:', this.recordId);
        console.log('decision:', this.decision);
        console.log('subDecision (cancelReason):', this.cancelReason);
        console.log('remarks:', this.remarks);
    
        submitProcessCaseDecision({
            caseId: this.effectiveRecordId,
            decision: this.decision,
            subDecision: this.cancelReason,
            reason: this.cancelReason,
            remarks: this.remarks
            
        })
        .then(result => {
            console.log('Server response:', result);
    
            if (result && result.success) {
                const resultMessage = result.message || 'Submit successfully';
                alert(resultMessage);
                location.reload();
            } else {
                const resultMessage = result?.message || 'Submit failed';
                alert(resultMessage);
            }
        })
        .catch(error => {
            console.error('Submit error:', error);
            alert(error?.body?.message || 'Submit failed');
        });
    }
    
    

    // ===== MASKING =====
    showNationalId = false;
    showPhone = false;

    get displayNationalId() {
        if (!this.customer?.nationalId) return '—';
        return this.showNationalId
            ? this.customer.nationalId
            : this.maskValue(this.customer.nationalId);
    }

    get displayPhone() {
        if (!this.customer?.primaryPhone) return '—';
        return this.showPhone
            ? this.customer.primaryPhone
            : this.maskValue(this.customer.primaryPhone);
    }

    get nationalIdIcon() {
        return this.showNationalId ? 'utility:hide' : 'utility:preview';
    }

    get phoneIcon() {
        return this.showPhone ? 'utility:hide' : 'utility:preview';
    }

    toggleNationalId() { this.showNationalId = !this.showNationalId; }
    togglePhone() { this.showPhone = !this.showPhone; }

    maskValue(value) {
        const visible = 3;
        return '*'.repeat(value.length - visible) + value.slice(-visible);
    }
}