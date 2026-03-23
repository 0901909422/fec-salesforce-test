public class FEC_CaseExportBatch
        implements Database.Batchable<SObject>,
                   Database.AllowsCallouts,
                   Database.Stateful {

    private Integer batchSuccess  = 0;
    private Integer batchFail     = 0;
    private Integer totalCases    = 0;
    private List<String> failedBatchInfo = new List<String>();
    public static final Integer DEFAULT_BATCH_SIZE = 20;

    // ── Archive status values ────────────────────────────────────────────────
    @TestVisible private static final String STATUS_PENDING    = 'Pending';
    @TestVisible private static final String STATUS_PROCESSING = 'Processing';

    private static final String CASE_QUERY =
        'SELECT  ' +
        'Id, CaseNumber, Status,  ' +
        'CreatedById, ' +
        'LastModifiedById, ' +
        'OwnerId, ParentId, ' +
        'FEC_External_Interaction_ID__c, FEC_Channel__c, FEC_Case_Channel__c, ' +
        'FEC_Created_By__c, FEC_Created_On__c, ' +
        'FEC_Interaction_Start_On__c, FEC_Interaction_End_On__c, FEC_Interaction_Duration__c, ' +
        'FEC_Interaction_Resolved_By__c,  ' +
        'FEC_Phone_Number__c, FEC_Transcription__c,  ' +
        'FEC_KYC_Method__c, FEC_Interaction_Subchannel__c, FEC_Other_Subchannel__c, ' +
        'FEC_Customer_Name__c, FEC_Genesys_Campaign_Name__c, FEC_Routing_Action__c, ' +
        'FEC_Interaction__c, FEC_Interaction_Remarks__c, ' +
        'FEC_Interaction_Resolved_By__r.Id, FEC_Interaction_Resolved_By__r.Username, ' +
        'FEC_Interaction_Resolved_By__r.Name, FEC_Interaction_Resolved_By__r.Email, ' +
        'FEC_Interaction_Resolved_By__r.Phone, FEC_Interaction_Resolved_By__r.FEC_Agent_ID__c, FEC_Interaction_Resolved_By__r.FEC_Default_Queue__c, ' +
        'FEC_Customer_Type__c, FEC_Phone_Type__c, FEC_Updated_Info_Phone_Type__c, ' +
        'FEC_Interaction_Email__c, FEC_Account_Number__c, FEC_Contract_Number__c, ' +
        'FEC_National_ID_Passport_ID__c, FEC_Email_From__c, FEC_Email_CC__c, ' +
        'FEC_Account_or_Contract__c, FEC_CIF_Number__c, ' +
        'FEC_Case_Email__c, ' +
        'FEC_Account_or_Contract__r.Id, ' +
        'FEC_Account_or_Contract__r.Name, ' +
        'FEC_Account_or_Contract__r.CreatedById, ' +
        'FEC_Account_or_Contract__r.LastModifiedById, ' +
        'FEC_Account_or_Contract__r.FEC_Account_Close_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Account_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Account_Open_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Account_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Account_Status_Change_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Address__c, ' +
        'FEC_Account_or_Contract__r.FEC_Address_Type__c, ' +
        'FEC_Account_or_Contract__r.FEC_Agent_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_Agent_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Agreement_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Annual_Fee__c, ' +
        'FEC_Account_or_Contract__r.FEC_API_Cache__c, ' +
        'FEC_Account_or_Contract__r.FEC_API_Cache_Secondary_Demo__c, ' +
        'FEC_Account_or_Contract__r.FEC_Application_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Available_Cash_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Available_Points__c, ' +
        'FEC_Account_or_Contract__r.FEC_Bank_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Billing_Cycle__c, ' +
        'FEC_Account_or_Contract__r.FEC_Block_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_Block_Code_1__c, ' +
        'FEC_Account_or_Contract__r.FEC_Block_Code_2__c, ' +
        'FEC_Account_or_Contract__r.FEC_Block_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Block_Date_1__c, ' +
        'FEC_Account_or_Contract__r.FEC_Block_Date_2__c, ' +
        'FEC_Account_or_Contract__r.FEC_Blocked_By__c, ' +
        'FEC_Account_or_Contract__r.FEC_Branch_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Buyer_DOB__c, ' +
        'FEC_Account_or_Contract__r.FEC_Buyer_Gender__c, ' +
        'FEC_Account_or_Contract__r.FEC_Buyer_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Buyer_NID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Cancel_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Card_Activation_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Card_Activation_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Card_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Card_Type__c, ' +
        'FEC_Account_or_Contract__r.FEC_Case__c, ' +
        'FEC_Account_or_Contract__r.FEC_CC_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_CC_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Charge_Off_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_CIF_Number__c, ' +
        'FEC_Account_or_Contract__r.Close_Fee_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Company_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Contract_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Contract_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Contract_Type__c, ' +
        'FEC_Account_or_Contract__r.FEC_Credit_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Current_Balance__c, ' +
        'FEC_Account_or_Contract__r.FEC_Customer_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Customer_Segment__c, ' +
        'FEC_Account_or_Contract__r.FEC_Customer_Type__c, ' +
        'FEC_Account_or_Contract__r.FEC_Daily_Cash_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Daily_Cash_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Daily_Ecommerce_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Daily_Ecommerce_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Daily_Retail_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Daily_Retail_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Date_Assigned__c, ' +
        'FEC_Account_or_Contract__r.FEC_Date_of_Birth__c, ' +
        'FEC_Account_or_Contract__r.FEC_Date_of_Issue__c, ' +
        'FEC_Account_or_Contract__r.FEC_Days_Past_Due__c, ' +
        'FEC_Account_or_Contract__r.FEC_Debt_Sale_Type__c, ' +
        'FEC_Account_or_Contract__r.FEC_Delinquency_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Digital_Card_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Disbursement_Channel__c, ' +
        'FEC_Account_or_Contract__r.FEC_Disbursement_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_DSA_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_DSA_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_E_Commerce_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_E_sign_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Effective_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Email__c, ' +
        'FEC_Account_or_Contract__r.FEC_Embossing_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_EMI__c, ' +
        'FEC_Account_or_Contract__r.FEC_Expiry_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_First_Effective_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_First_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_First_Payment_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_First_Transaction_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Fraud_Monitor_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Fraud_Monitor_Flag__c, ' +
        'FEC_Account_or_Contract__r.FEC_Full_IPP_Payment_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Full_Payment_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Full_Payment_Without_IPP__c, ' +
        'FEC_Account_or_Contract__r.FEC_Gender__c, ' +
        'FEC_Account_or_Contract__r.FEC_Hold_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Installments_Remaining__c, ' +
        'FEC_Account_or_Contract__r.FEC_Insurance_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Insurance_Flag__c, ' +
        'FEC_Account_or_Contract__r.FEC_Interest_Sold__c, ' +
        'FEC_Account_or_Contract__r.FEC_Is_Top_Up_Account__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Advance_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Advance_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_AF_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Credit_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Credit_Limit_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Effective_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Payment_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Payment_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_PIN_Action_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_PIN_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Statement_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Last_Transaction_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Loan_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Local_Use__c, ' +
        'FEC_Account_or_Contract__r.FEC_Mailing_Address__c, ' +
        'FEC_Account_or_Contract__r.FEC_Marital_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Memorable_Question__c, ' +
        'FEC_Account_or_Contract__r.FEC_Middle_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_Minimum_Payment_Due__c, ' +
        'FEC_Account_or_Contract__r.FEC_Mobile_App_Account__c, ' +
        'FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Next_Due_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Next_Statement_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_One_Time_Cash_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_One_Time_Ecommerce_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_One_Time_Retail_Limit__c, ' +
        'FEC_Account_or_Contract__r.FEC_OTB__c, ' +
        'FEC_Account_or_Contract__r.FEC_Payment_Due_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Payment_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_PID_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Place_of_Issue__c, ' +
        'FEC_Account_or_Contract__r.FEC_Plan_Payment_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Plastic_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Policy_Number__c, ' +
        'FEC_Account_or_Contract__r.FEC_Premium_Fee__c, ' +
        'FEC_Account_or_Contract__r.FEC_Primary_Phone__c, ' +
        'FEC_Account_or_Contract__r.FEC_Principal_Sold__c, ' +
        'FEC_Account_or_Contract__r.FEC_Product_Association__c, ' +
        'FEC_Account_or_Contract__r.FEC_Product_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_Rate__c, ' +
        'FEC_Account_or_Contract__r.FEC_Reason_1__c, ' +
        'FEC_Account_or_Contract__r.FEC_Reason_2__c, ' +
        'FEC_Account_or_Contract__r.FEC_Remark__c, ' +
        'FEC_Account_or_Contract__r.FEC_Responsible_Person__c, ' +
        'FEC_Account_or_Contract__r.FEC_Responsible_Unit__c, ' +
        'FEC_Account_or_Contract__r.FEC_Sale_Channel__c, ' +
        'FEC_Account_or_Contract__r.FEC_Scheme_Desc__c, ' +
        'FEC_Account_or_Contract__r.FEC_Scheme_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Sold_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Sold_Date__c, ' +
        'FEC_Account_or_Contract__r.FEC_Sold_Note__c, ' +
        'FEC_Account_or_Contract__r.FEC_Statement_Notification_Type__c, ' +
        'FEC_Account_or_Contract__r.FEC_Status__c, ' +
        'FEC_Account_or_Contract__r.FEC_Sub_Channel__c, ' +
        'FEC_Account_or_Contract__r.FEC_Tenure__c, ' +
        'FEC_Account_or_Contract__r.FEC_Top_Up_Loan_Amount_Requested__c, ' +
        'FEC_Account_or_Contract__r.FEC_Top_Up_Old_Account_App_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Top_Up_Old_A_c_Outstanding__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Accrued_Interest__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Balance__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Close_Fee_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Current_Balance__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Deferred_Interest__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_IPP_Accrued_Interest__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_IPP_Balance__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_IPP_Current_Balance__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Payment_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Payment_Due__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Per_Diem__c, ' +
        'FEC_Account_or_Contract__r.FEC_Total_Plan_Payment_Amount__c, ' +
        'FEC_Account_or_Contract__r.FEC_TSA_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_TSA_Name__c, ' +
        'FEC_Account_or_Contract__r.FEC_User_ID__c, ' +
        'FEC_Account_or_Contract__r.FEC_Warning_Code__c, ' +
        'FEC_Account_or_Contract__r.FEC_Website_Account__c, ' +
        'FEC_Account_or_Contract__r.FEC_Work_Phone__c, ' +
        'FEC_Account_or_Contract__r.FEC_Zalo_Follower__c, ' +
        'FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, ' +
        'FEC_New_Category__c, FEC_New_SubCategory__c, FEC_New_SubCode__c, ' +
        'FEC_Stage_Name__c, FEC_Complain_Type__c, FEC_Original_Info_Phone_Type__c, FEC_Actual_Nature_of_Case__c, ' +
        'FEC_Product_Type__r.Id, FEC_Product_Type__r.Name, FEC_Product_Type__r.FEC_Code__c, FEC_Product_Type__r.FEC_Name_VN__c, FEC_Product_Type__r.FEC_Alias__c, FEC_Product_Type__r.FEC_Order__c, ' +
        'FEC_Category__r.Id, FEC_Category__r.Name, FEC_Category__r.FEC_Code__c, FEC_Category__r.FEC_Name_VN__c, FEC_Category__r.FEC_Alias__c, FEC_Category__r.FEC_Order__c, ' +
        'FEC_SubCategory__r.Id, FEC_SubCategory__r.Name, FEC_SubCategory__r.FEC_Code__c, FEC_SubCategory__r.FEC_Alias__c, FEC_SubCategory__r.FEC_Name_VN__c, FEC_SubCategory__r.FEC_Order__c, ' +
        'FEC_SubCode__r.Id, FEC_SubCode__r.Name, FEC_SubCode__r.FEC_Code__c, FEC_SubCode__r.FEC_Name_VN__c, FEC_SubCode__r.FEC_Alias__c, FEC_SubCode__r.FEC_Order__c, ' +
        'FEC_New_Category__r.Id, FEC_New_Category__r.Name, FEC_New_Category__r.FEC_Code__c, FEC_New_Category__r.FEC_Name_VN__c, FEC_New_Category__r.FEC_Alias__c, FEC_New_Category__r.FEC_Order__c, ' +
        'FEC_New_SubCategory__r.Id, FEC_New_SubCategory__r.Name, FEC_New_SubCategory__r.FEC_Code__c, FEC_New_SubCategory__r.FEC_Name_VN__c, FEC_New_SubCategory__r.FEC_Alias__c, FEC_New_SubCategory__r.FEC_Order__c, ' +
        'FEC_New_SubCode__r.Id, FEC_New_SubCode__r.Name, FEC_New_SubCode__r.FEC_Code__c, FEC_New_SubCode__r.FEC_Name_VN__c, FEC_New_SubCode__r.FEC_Alias__c, FEC_New_SubCode__r.FEC_Order__c, ' +
        'FEC_Actual_Nature_of_Case__r.Id,  ' +
        'FEC_Actual_Nature_of_Case__r.Name, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Customer_Type__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_User_Group__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.Id, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.Name, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Alias__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Name_VN__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Order__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.Id, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.Name, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Code__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Alias__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Name_VN__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Order__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Category__r.Id, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Category__r.Name, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Code__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Alias__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Name_VN__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Order__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.Id, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.Name, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Code__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Alias__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Name_VN__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Order__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.Id, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.Name, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Code__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Alias__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Name_VN__c, ' +
        'FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Order__c, ' +
        'FEC_Service_Case_Owner__c, FEC_Final_Status__c, FEC_Task__c, ' +
        'FEC_Remarks__c, FEC_Team__c, FEC_Completed_User__c, ' +
        'FEC_Follow_Up_User__c, FEC_Is_My_Follow_Up__c, FEC_Is_Submited__c, ' +
        'FEC_Is_Save_Closed__c, FEC_Draft_Remarks__c, ' +
        'FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c, ' +
        'FEC_FCR__c, ' +
        'FEC_Case_Created_On__c, FEC_Case_Created_By__c,  ' +
        'FEC_Last_Updated_On__c, FEC_Last_Updated_By__c, ' +
        'CreatedDate, LastModifiedDate, ClosedDate, ' +
        'FEC_Link_ID__c, FEC_Interaction_Status__c, ' +
        'FEC_Case_ID__c, FEC_Interaction_ID__c, FEC_Customer_Username__c, ' +
        'FEC_Interaction_Owner__c, FEC_Original_Info_Phone_Number__c, ' +
        'FEC_Updated_Info_Phone_Number__c, FEC_Correct_Contract_Number__c, ' +
        'FEC_User_Email_ID__c, FEC_Is_In_Create_new_mode__c, FEC_Show_Action__c, ' +
        'FEC_Has_Account_or_Contract__c, EntitlementId, FEC_Business_Process__c, ' +
        'FEC_Business_Process__r.Id, ' +
        'FEC_Business_Process__r.Name, ' +
        'FEC_Business_Process__r.FEC_Code__c, ' +
        'FEC_Business_Process__r.FEC_Alias__c, ' +
        'FEC_Business_Process__r.FEC_Name_VN__c, ' +
        'FEC_Business_Process__r.FEC_Order__c,  ' +
        'FEC_SLA_Violating_Warning__c, FEC_SLA_Warning__c, FEC_Genesys_Campaign__c, ' +
        'FEC_CS_D2C_Assessment_Type__c, FEC_CS_D2C_Risk_Level__c, ' +
        'FEC_Outcome_Code__c, FEC_Application_ID__c, FEC_ID_Search__c, ' +
        'FEC_Interaction_Masked_Phone__c, FEC_Case_Phone_Number__c, ' +
        'FEC_Account_Contract_Number_Text__c, ' +
        'RecordTypeId, RecordType.Name, ' +
        'FEC_Archive_Status__c ' +
        'FROM Case ' +
        'ORDER BY ClosedDate ASC LIMIT 20';

    // ── start() ──────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[CaseExportBatch] start() - jobId: ' + bc.getJobId());
        return Database.getQueryLocator(CASE_QUERY);
    }

    // ── execute() ────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Case> cases = (List<Case>) scope;
        totalCases += cases.size();

        Set<Id> caseIds  = new Set<Id>();
        Set<Id> userIds  = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
            if (c.CreatedById      != null) userIds.add(c.CreatedById);
            if (c.LastModifiedById != null) userIds.add(c.LastModifiedById);
            if (c.OwnerId          != null) userIds.add(c.OwnerId);
        }

        // ── [1] Query User với custom fields (không bị giới hạn bởi Name entity) ──
        Map<Id, User> usersById = queryUsersById(userIds);

        // ── [2] Query remarks ─────────────────────────────────────────────────
        Map<Id, List<FEC_Case_Remarks__c>> remarksByCaseId =
            queryRemarksByCaseIds(caseIds);

        // ── [3] Build JSON array toàn bộ batch ───────────────────────────────
        String jsonPayload = FEC_CasePayloadBuilder.buildBatch(cases, remarksByCaseId, usersById);

        // ── [4] 1 callout cho cả batch ────────────────────────────────────────
        Boolean calloutSuccess = false;
        try {
            FEC_CaseExportHttpService.postCases(jsonPayload);
            calloutSuccess = true;
            batchSuccess++;
            System.debug('[CaseExportBatch] Batch OK — ' + cases.size() + ' cases gửi thành công');
        } catch (Exception ex) {
            batchFail++;
            String batchInfo = cases.size() + ' cases ['
                + cases[0].CaseNumber + ' … ' + cases[cases.size()-1].CaseNumber
                + ']: ' + ex.getMessage();
            failedBatchInfo.add(batchInfo);
            System.debug(LoggingLevel.ERROR,
                '[CaseExportBatch] Batch FAILED — ' + batchInfo);
        }

        // ── [5] Update flag chỉ khi callout thành công ────────────────────────
        if (calloutSuccess) {
            markCasesAsProcessing(caseIds);
        }
    }

    // ── finish() ─────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('[CaseExportBatch] ═══ KẾT QUẢ ═══');
        System.debug('  Tổng số cases : ' + totalCases);
        System.debug('  Batch OK      : ' + batchSuccess);
        System.debug('  Batch FAILED  : ' + batchFail);
        if (!failedBatchInfo.isEmpty()) {
            for (String info : failedBatchInfo) {
                System.debug('  ✗ ' + info);
            }
        }
    }

        // ── Query User với đầy đủ custom fields (tránh giới hạn của Name entity) ──
        @TestVisible
        private static Map<Id, User> queryUsersById(Set<Id> userIds) {
            Map<Id, User> result = new Map<Id, User>();
            if (userIds.isEmpty()) return result;
            for (User u : [
                SELECT Id, Name, Username, Email, Phone,
                       FEC_Agent_ID__c, FEC_Default_Queue__c
                FROM User
                WHERE Id IN :userIds
            ]) {
                result.put(u.Id, u);
            }
            return result;
        }

    // ── Query remarks gom theo CaseId — 1 SOQL cho cả batch ──────────────────
    @TestVisible
    private static Map<Id, List<FEC_Case_Remarks__c>> queryRemarksByCaseIds(Set<Id> caseIds) {
        Map<Id, List<FEC_Case_Remarks__c>> result = new Map<Id, List<FEC_Case_Remarks__c>>();
        for (Id cId : caseIds) {
            result.put(cId, new List<FEC_Case_Remarks__c>());
        }
        for (FEC_Case_Remarks__c r : [
            SELECT Id, Name, FEC_Case__c, FEC_Case_Remarks__c,
                   FEC_Stage_Name__c, FEC_User__c, FEC_User_Role__c
            FROM FEC_Case_Remarks__c
            WHERE FEC_Case__c IN :caseIds
            ORDER BY FEC_Case__c, CreatedDate ASC
        ]) {
            result.get(r.FEC_Case__c).add(r);
        }
        return result;
    }

    // ── Update FEC_Archive_Status__c = 'Processing' sau khi gửi thành công ───
    @TestVisible
    private static void markCasesAsProcessing(Set<Id> caseIds) {
        List<Case> toUpdate = new List<Case>();
        Datetime now = System.now();
        for (Id cId : caseIds) {
            toUpdate.add(new Case(
                Id                     = cId,
                FEC_Archive_Status__c  = STATUS_PROCESSING,
                FEC_Archive_Sent_At__c = now,
                FEC_Attachment_Status__c = null
            ));
        }
        // allOrNone=false: 1 record lỗi không làm hỏng cả batch
        List<Database.SaveResult> results = Database.update(toUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.WARN,
                    '[CaseExportBatch] Không update archive flag cho '
                    + toUpdate[i].Id + ': '
                    + results[i].getErrors()[0].getMessage());
            }
        }
    }

    // ── Static helpers để chạy từ Anonymous Apex / Scheduler ─────────────────
    public static void run() {
        Database.executeBatch(new FEC_CaseExportBatch(), DEFAULT_BATCH_SIZE);
    }

    public static void run(Integer batchSize) {
        Database.executeBatch(new FEC_CaseExportBatch(), batchSize);
    }
}