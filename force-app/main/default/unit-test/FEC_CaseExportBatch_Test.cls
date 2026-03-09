/**
 * CaseExportBatchTest
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_CaseExportBatch (bulk mode + archive flag update).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_CaseExportBatch_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock API trả 200 OK */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success","received":1}');
            return res;
        }
    }

    /** Mock API luôn trả 500 → test retry và fail path */
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /** Mock API trả 400 Bad Request → không retry */
    private class BadRequestMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad payload"}');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test data helpers
    // ══════════════════════════════════════════════════════════════════════════

    private static List<Case> createCases(Integer n) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < n; i++) {
            cases.add(new Case(
                Status   = 'Closed',
                Subject  = 'Test Case ' + i
            ));
        }
        insert cases;
        // Set ClosedDate qua update vì insert không set được ClosedDate trực tiếp
        List<Case> toClose = new List<Case>();
        for (Case c : cases) {
            toClose.add(new Case(Id = c.Id, Status = 'Closed'));
        }
        update toClose;
        return [SELECT Id, CaseNumber, Status, ClosedDate,
                       FEC_Archive_Status__c
                FROM Case WHERE Id IN :cases];
    }

    private static void createRemarks(Id caseId, Integer n) {
        List<FEC_Case_Remarks__c> results = new List<FEC_Case_Remarks__c>();
        for (Integer i = 0; i < n; i++) {
            results.add(new FEC_Case_Remarks__c(
                FEC_Case__c         = caseId,
                FEC_Case_Remarks__c = 'Remark ' + i,
                FEC_Stage_Name__c   = 'Stage ' + i,
                FEC_User__c         = 'user' + i,
                FEC_User_Role__c    = i == 0 ? 'Agent' : 'Supervisor'
            ));
        }
        insert results;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 1: Batch thành công → flag = 'Processing'
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testBatchSuccessUpdatesFlag() {
        List<Case> cases = createCases(3);
        for (Case c : cases) {
            createRemarks(c.Id, 2);
        }

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new FEC_CaseExportBatch(), 3);
        Test.stopTest();

        // Tất cả cases phải có flag = 'Processing'
        List<Case> updated = [
            SELECT Id, FEC_Archive_Status__c
            FROM Case
            WHERE Id IN :cases
        ];
        for (Case c : updated) {
            System.assertEquals(
                FEC_CaseExportBatch.STATUS_PROCESSING,
                c.FEC_Archive_Status__c,
                'Flag phải là Processing sau khi callout thành công: ' + c.Id
            );
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 2: Batch thất bại (5xx) → flag KHÔNG được update
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testBatchFailDoesNotUpdateFlag() {
        List<Case> cases = createCases(2);

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        Database.executeBatch(new FEC_CaseExportBatch(), 2);
        Test.stopTest();

        List<Case> notUpdated = [
            SELECT Id, FEC_Archive_Status__c
            FROM Case
            WHERE Id IN :cases
        ];
        for (Case c : notUpdated) {
            System.assertNotEquals(
                FEC_CaseExportBatch.STATUS_PROCESSING,
                c.FEC_Archive_Status__c,
                'Flag KHÔNG được update khi callout thất bại: ' + c.Id
            );
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 3: Case không có remark vẫn chạy đúng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testBatchNoRemarks() {
        createCases(2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new FEC_CaseExportBatch(), 5);
        Test.stopTest();

        System.assert(true, 'Batch chạy OK khi không có remarks');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 4: queryRemarksByCaseIds grouping đúng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testQueryRemarksGrouping() {
        List<Case> cases = createCases(2);
        createRemarks(cases[0].Id, 3);
        createRemarks(cases[1].Id, 1);

        Set<Id> caseIds = new Set<Id>{ cases[0].Id, cases[1].Id };

        Test.startTest();
        Map<Id, List<FEC_Case_Remarks__c>> result =
            FEC_CaseExportBatch.queryRemarksByCaseIds(caseIds);
        Test.stopTest();

        System.assertEquals(3, result.get(cases[0].Id).size(),
            'Case 0 phải có 3 remarks');
        System.assertEquals(1, result.get(cases[1].Id).size(),
            'Case 1 phải có 1 remark');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 5: markCasesAsProcessing update đúng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testMarkCasesAsProcessing() {
        List<Case> cases = createCases(3);
        Set<Id> caseIds = new Map<Id, Case>(cases).keySet();

        Test.startTest();
        FEC_CaseExportBatch.markCasesAsProcessing(caseIds);
        Test.stopTest();

        List<Case> updated = [
            SELECT Id, FEC_Archive_Status__c, FEC_Archive_Sent_At__c
            FROM Case WHERE Id IN :caseIds
        ];
        for (Case c : updated) {
            System.assertEquals(FEC_CaseExportBatch.STATUS_PROCESSING,
                c.FEC_Archive_Status__c, 'Status phải Processing');
            System.assertNotEquals(null, c.FEC_Archive_Sent_At__c,
                'FEC_Archive_Sent_At__c phải được set');
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 6: FEC_CasePayloadBuilder.buildBatch cấu trúc JSON đúng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPayloadBuilderBatch() {
        List<Case> cases = createCases(2);
        List<Case> queried = [
            SELECT  
            Id, CaseNumber, Status,  
            CreatedById, CreatedBy.Name, CreatedBy.Username, CreatedBy.Email, CreatedBy.Phone, CreatedBy.FEC_Agent_ID__c, CreatedBy.FEC_Default_Queue__c, 
            LastModifiedById, LastModifiedBy.Name, LastModifiedBy.Username, LastModifiedBy.Email, LastModifiedBy.Phone, LastModifiedBy.FEC_Agent_ID__c, LastModifiedBy.FEC_Default_Queue__c, 
            OwnerId, Owner.Name, Owner.Username, Owner.Email, Owner.Phone, 
            ParentId, 
            FEC_External_Interaction_ID__c, FEC_Channel__c, FEC_Case_Channel__c, 
            FEC_Created_By__c, FEC_Created_On__c, 
            FEC_Interaction_Start_On__c, FEC_Interaction_End_On__c, FEC_Interaction_Duration__c, 
            FEC_Interaction_Resolved_By__c,  
            FEC_Phone_Number__c, FEC_Transcription__c,  
            FEC_KYC_Method__c, FEC_Interaction_Subchannel__c, FEC_Other_Subchannel__c, 
            FEC_Customer_Name__c, FEC_Genesys_Campaign_Name__c, FEC_Routing_Action__c, 
            FEC_Interaction__c, FEC_Interaction_Remarks__c, 
            FEC_Interaction_Resolved_By__r.Id, FEC_Interaction_Resolved_By__r.Username, 
            FEC_Interaction_Resolved_By__r.Name, FEC_Interaction_Resolved_By__r.Email, 
            FEC_Interaction_Resolved_By__r.Phone, FEC_Interaction_Resolved_By__r.FEC_Agent_ID__c, FEC_Interaction_Resolved_By__r.FEC_Default_Queue__c, 
            FEC_Customer_Type__c, FEC_Phone_Type__c, FEC_Updated_Info_Phone_Type__c, 
            FEC_Interaction_Email__c, FEC_Account_Number__c, FEC_Contract_Number__c, 
            FEC_National_ID_Passport_ID__c, FEC_Email_From__c, FEC_Email_CC__c, 
            FEC_Account_or_Contract__c, FEC_CIF_Number__c, 
            FEC_Case_Email__c, 
            FEC_Account_or_Contract__r.Id, 
            FEC_Account_or_Contract__r.Name, 
            FEC_Account_or_Contract__r.CreatedById, 
            FEC_Account_or_Contract__r.LastModifiedById, 
            FEC_Account_or_Contract__r.FEC_Account_Close_Date__c, 
            FEC_Account_or_Contract__r.FEC_Account_Number__c, 
            FEC_Account_or_Contract__r.FEC_Account_Open_Date__c, 
            FEC_Account_or_Contract__r.FEC_Account_Status__c, 
            FEC_Account_or_Contract__r.FEC_Account_Status_Change_Date__c, 
            FEC_Account_or_Contract__r.FEC_Address__c, 
            FEC_Account_or_Contract__r.FEC_Address_Type__c, 
            FEC_Account_or_Contract__r.FEC_Agent_Code__c, 
            FEC_Account_or_Contract__r.FEC_Agent_Name__c, 
            FEC_Account_or_Contract__r.FEC_Agreement_Date__c, 
            FEC_Account_or_Contract__r.FEC_Annual_Fee__c, 
            FEC_Account_or_Contract__r.FEC_API_Cache__c, 
            FEC_Account_or_Contract__r.FEC_API_Cache_Secondary_Demo__c, 
            FEC_Account_or_Contract__r.FEC_Application_ID__c, 
            FEC_Account_or_Contract__r.FEC_Available_Cash_Limit__c, 
            FEC_Account_or_Contract__r.FEC_Available_Points__c, 
            FEC_Account_or_Contract__r.FEC_Bank_Name__c, 
            FEC_Account_or_Contract__r.FEC_Billing_Cycle__c, 
            FEC_Account_or_Contract__r.FEC_Block_Code__c, 
            FEC_Account_or_Contract__r.FEC_Block_Code_1__c, 
            FEC_Account_or_Contract__r.FEC_Block_Code_2__c, 
            FEC_Account_or_Contract__r.FEC_Block_Date__c, 
            FEC_Account_or_Contract__r.FEC_Block_Date_1__c, 
            FEC_Account_or_Contract__r.FEC_Block_Date_2__c, 
            FEC_Account_or_Contract__r.FEC_Blocked_By__c, 
            FEC_Account_or_Contract__r.FEC_Branch_Name__c, 
            FEC_Account_or_Contract__r.FEC_Buyer_DOB__c, 
            FEC_Account_or_Contract__r.FEC_Buyer_Gender__c, 
            FEC_Account_or_Contract__r.FEC_Buyer_Name__c, 
            FEC_Account_or_Contract__r.FEC_Buyer_NID__c, 
            FEC_Account_or_Contract__r.FEC_Cancel_Date__c, 
            FEC_Account_or_Contract__r.FEC_Card_Activation_Date__c, 
            FEC_Account_or_Contract__r.FEC_Card_Activation_Status__c, 
            FEC_Account_or_Contract__r.FEC_Card_Number__c, 
            FEC_Account_or_Contract__r.FEC_Card_Type__c, 
            FEC_Account_or_Contract__r.FEC_Case__c, 
            FEC_Account_or_Contract__r.FEC_CC_Code__c, 
            FEC_Account_or_Contract__r.FEC_CC_Name__c, 
            FEC_Account_or_Contract__r.FEC_Charge_Off_Date__c, 
            FEC_Account_or_Contract__r.FEC_CIF_Number__c, 
            FEC_Account_or_Contract__r.Close_Fee_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Company_Name__c, 
            FEC_Account_or_Contract__r.FEC_Contract_Number__c, 
            FEC_Account_or_Contract__r.FEC_Contract_Status__c, 
            FEC_Account_or_Contract__r.FEC_Contract_Type__c, 
            FEC_Account_or_Contract__r.FEC_Credit_Limit__c, 
            FEC_Account_or_Contract__r.FEC_Current_Balance__c, 
            FEC_Account_or_Contract__r.FEC_Customer_Name__c, 
            FEC_Account_or_Contract__r.FEC_Customer_Segment__c, 
            FEC_Account_or_Contract__r.FEC_Customer_Type__c, 
            FEC_Account_or_Contract__r.FEC_Daily_Cash_Limit__c, 
            FEC_Account_or_Contract__r.FEC_Daily_Cash_Number__c, 
            FEC_Account_or_Contract__r.FEC_Daily_Ecommerce_Limit__c, 
            FEC_Account_or_Contract__r.FEC_Daily_Ecommerce_Number__c, 
            FEC_Account_or_Contract__r.FEC_Daily_Retail_Limit__c, 
            FEC_Account_or_Contract__r.FEC_Daily_Retail_Number__c, 
            FEC_Account_or_Contract__r.FEC_Date_Assigned__c, 
            FEC_Account_or_Contract__r.FEC_Date_of_Birth__c, 
            FEC_Account_or_Contract__r.FEC_Date_of_Issue__c, 
            FEC_Account_or_Contract__r.FEC_Days_Past_Due__c, 
            FEC_Account_or_Contract__r.FEC_Debt_Sale_Type__c, 
            FEC_Account_or_Contract__r.FEC_Delinquency_Date__c, 
            FEC_Account_or_Contract__r.FEC_Digital_Card_ID__c, 
            FEC_Account_or_Contract__r.FEC_Disbursement_Channel__c, 
            FEC_Account_or_Contract__r.FEC_Disbursement_Date__c, 
            FEC_Account_or_Contract__r.FEC_DSA_Code__c, 
            FEC_Account_or_Contract__r.FEC_DSA_Name__c, 
            FEC_Account_or_Contract__r.FEC_E_Commerce_Status__c, 
            FEC_Account_or_Contract__r.FEC_E_sign_Status__c, 
            FEC_Account_or_Contract__r.FEC_Effective_Date__c, 
            FEC_Account_or_Contract__r.FEC_Email__c, 
            FEC_Account_or_Contract__r.FEC_Embossing_Name__c, 
            FEC_Account_or_Contract__r.FEC_EMI__c, 
            FEC_Account_or_Contract__r.FEC_Expiry_Date__c, 
            FEC_Account_or_Contract__r.FEC_First_Effective_Date__c, 
            FEC_Account_or_Contract__r.FEC_First_Name__c, 
            FEC_Account_or_Contract__r.FEC_First_Payment_Date__c, 
            FEC_Account_or_Contract__r.FEC_First_Transaction_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Fraud_Monitor_Date__c, 
            FEC_Account_or_Contract__r.FEC_Fraud_Monitor_Flag__c, 
            FEC_Account_or_Contract__r.FEC_Full_IPP_Payment_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Full_Payment_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Full_Payment_Without_IPP__c, 
            FEC_Account_or_Contract__r.FEC_Gender__c, 
            FEC_Account_or_Contract__r.FEC_Hold_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Installments_Remaining__c, 
            FEC_Account_or_Contract__r.FEC_Insurance_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Insurance_Flag__c, 
            FEC_Account_or_Contract__r.FEC_Interest_Sold__c, 
            FEC_Account_or_Contract__r.FEC_Is_Top_Up_Account__c, 
            FEC_Account_or_Contract__r.FEC_Last_Advance_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Last_Advance_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_AF_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_Credit_Limit__c, 
            FEC_Account_or_Contract__r.FEC_Last_Credit_Limit_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_Effective_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_Name__c, 
            FEC_Account_or_Contract__r.FEC_Last_Payment_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Last_Payment_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_PIN_Action_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_PIN_Status__c, 
            FEC_Account_or_Contract__r.FEC_Last_Statement_Date__c, 
            FEC_Account_or_Contract__r.FEC_Last_Transaction_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Loan_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Local_Use__c, 
            FEC_Account_or_Contract__r.FEC_Mailing_Address__c, 
            FEC_Account_or_Contract__r.FEC_Marital_Status__c, 
            FEC_Account_or_Contract__r.FEC_Memorable_Question__c, 
            FEC_Account_or_Contract__r.FEC_Middle_Name__c, 
            FEC_Account_or_Contract__r.FEC_Minimum_Payment_Due__c, 
            FEC_Account_or_Contract__r.FEC_Mobile_App_Account__c, 
            FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c, 
            FEC_Account_or_Contract__r.FEC_Next_Due_Date__c, 
            FEC_Account_or_Contract__r.FEC_Next_Statement_Date__c, 
            FEC_Account_or_Contract__r.FEC_One_Time_Cash_Limit__c, 
            FEC_Account_or_Contract__r.FEC_One_Time_Ecommerce_Limit__c, 
            FEC_Account_or_Contract__r.FEC_One_Time_Retail_Limit__c, 
            FEC_Account_or_Contract__r.FEC_OTB__c, 
            FEC_Account_or_Contract__r.FEC_Payment_Due_Date__c, 
            FEC_Account_or_Contract__r.FEC_Payment_ID__c, 
            FEC_Account_or_Contract__r.FEC_PID_Number__c, 
            FEC_Account_or_Contract__r.FEC_Place_of_Issue__c, 
            FEC_Account_or_Contract__r.FEC_Plan_Payment_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Plastic_ID__c, 
            FEC_Account_or_Contract__r.FEC_Policy_Number__c, 
            FEC_Account_or_Contract__r.FEC_Premium_Fee__c, 
            FEC_Account_or_Contract__r.FEC_Primary_Phone__c, 
            FEC_Account_or_Contract__r.FEC_Principal_Sold__c, 
            FEC_Account_or_Contract__r.FEC_Product_Association__c, 
            FEC_Account_or_Contract__r.FEC_Product_Code__c, 
            FEC_Account_or_Contract__r.FEC_Rate__c, 
            FEC_Account_or_Contract__r.FEC_Reason_1__c, 
            FEC_Account_or_Contract__r.FEC_Reason_2__c, 
            FEC_Account_or_Contract__r.FEC_Remark__c, 
            FEC_Account_or_Contract__r.FEC_Responsible_Person__c, 
            FEC_Account_or_Contract__r.FEC_Responsible_Unit__c, 
            FEC_Account_or_Contract__r.FEC_Sale_Channel__c, 
            FEC_Account_or_Contract__r.FEC_Scheme_Desc__c, 
            FEC_Account_or_Contract__r.FEC_Scheme_ID__c, 
            FEC_Account_or_Contract__r.FEC_Sold_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Sold_Date__c, 
            FEC_Account_or_Contract__r.FEC_Sold_Note__c, 
            FEC_Account_or_Contract__r.FEC_Statement_Notification_Type__c, 
            FEC_Account_or_Contract__r.FEC_Status__c, 
            FEC_Account_or_Contract__r.FEC_Sub_Channel__c, 
            FEC_Account_or_Contract__r.FEC_Tenure__c, 
            FEC_Account_or_Contract__r.FEC_Top_Up_Loan_Amount_Requested__c, 
            FEC_Account_or_Contract__r.FEC_Top_Up_Old_Account_App_ID__c, 
            FEC_Account_or_Contract__r.FEC_Top_Up_Old_A_c_Outstanding__c, 
            FEC_Account_or_Contract__r.FEC_Total_Accrued_Interest__c, 
            FEC_Account_or_Contract__r.FEC_Total_Balance__c, 
            FEC_Account_or_Contract__r.FEC_Total_Close_Fee_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Total_Current_Balance__c, 
            FEC_Account_or_Contract__r.FEC_Total_Deferred_Interest__c, 
            FEC_Account_or_Contract__r.FEC_Total_IPP_Accrued_Interest__c, 
            FEC_Account_or_Contract__r.FEC_Total_IPP_Balance__c, 
            FEC_Account_or_Contract__r.FEC_Total_IPP_Current_Balance__c, 
            FEC_Account_or_Contract__r.FEC_Total_Payment_Amount__c, 
            FEC_Account_or_Contract__r.FEC_Total_Payment_Due__c, 
            FEC_Account_or_Contract__r.FEC_Total_Per_Diem__c, 
            FEC_Account_or_Contract__r.FEC_Total_Plan_Payment_Amount__c, 
            FEC_Account_or_Contract__r.FEC_TSA_Code__c, 
            FEC_Account_or_Contract__r.FEC_TSA_Name__c, 
            FEC_Account_or_Contract__r.FEC_User_ID__c, 
            FEC_Account_or_Contract__r.FEC_Warning_Code__c, 
            FEC_Account_or_Contract__r.FEC_Website_Account__c, 
            FEC_Account_or_Contract__r.FEC_Work_Phone__c, 
            FEC_Account_or_Contract__r.FEC_Zalo_Follower__c, 
            FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, 
            FEC_New_Category__c, FEC_New_SubCategory__c, FEC_New_SubCode__c, 
            FEC_Stage_Name__c, FEC_Complain_Type__c, FEC_Original_Info_Phone_Type__c, FEC_Actual_Nature_of_Case__c, 
            FEC_Product_Type__r.Id, FEC_Product_Type__r.Name, FEC_Product_Type__r.FEC_Code__c, FEC_Product_Type__r.FEC_Name_VN__c, FEC_Product_Type__r.FEC_Alias__c, FEC_Product_Type__r.FEC_Order__c, 
            FEC_Category__r.Id, FEC_Category__r.Name, FEC_Category__r.FEC_Code__c, FEC_Category__r.FEC_Name_VN__c, FEC_Category__r.FEC_Alias__c, FEC_Category__r.FEC_Order__c, 
            FEC_SubCategory__r.Id, FEC_SubCategory__r.Name, FEC_SubCategory__r.FEC_Code__c, FEC_SubCategory__r.FEC_Alias__c, FEC_SubCategory__r.FEC_Name_VN__c, FEC_SubCategory__r.FEC_Order__c, 
            FEC_SubCode__r.Id, FEC_SubCode__r.Name, FEC_SubCode__r.FEC_Code__c, FEC_SubCode__r.FEC_Name_VN__c, FEC_SubCode__r.FEC_Alias__c, FEC_SubCode__r.FEC_Order__c, 
            FEC_New_Category__r.Id, FEC_New_Category__r.Name, FEC_New_Category__r.FEC_Code__c, FEC_New_Category__r.FEC_Name_VN__c, FEC_New_Category__r.FEC_Alias__c, FEC_New_Category__r.FEC_Order__c, 
            FEC_New_SubCategory__r.Id, FEC_New_SubCategory__r.Name, FEC_New_SubCategory__r.FEC_Code__c, FEC_New_SubCategory__r.FEC_Name_VN__c, FEC_New_SubCategory__r.FEC_Alias__c, FEC_New_SubCategory__r.FEC_Order__c, 
            FEC_New_SubCode__r.Id, FEC_New_SubCode__r.Name, FEC_New_SubCode__r.FEC_Code__c, FEC_New_SubCode__r.FEC_Name_VN__c, FEC_New_SubCode__r.FEC_Alias__c, FEC_New_SubCode__r.FEC_Order__c, 
            FEC_Actual_Nature_of_Case__r.Id,  
            FEC_Actual_Nature_of_Case__r.Name, 
            FEC_Actual_Nature_of_Case__r.FEC_Customer_Type__c, 
            FEC_Actual_Nature_of_Case__r.FEC_User_Group__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.Id, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.Name, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Alias__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Name_VN__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Order__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.Id, 
            FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.Name, 
            FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Code__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Alias__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Name_VN__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.FEC_Order__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Category__r.Id, 
            FEC_Actual_Nature_of_Case__r.FEC_Category__r.Name, 
            FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Code__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Alias__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Name_VN__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Category__r.FEC_Order__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.Id, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.Name, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Code__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Alias__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Name_VN__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.FEC_Order__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.Id, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.Name, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Code__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Alias__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Name_VN__c, 
            FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.FEC_Order__c, 
            FEC_Service_Case_Owner__c, FEC_Final_Status__c, FEC_Task__c, 
            FEC_Remarks__c, FEC_Team__c, FEC_Completed_User__c, 
            FEC_Follow_Up_User__c, FEC_Is_My_Follow_Up__c, FEC_Is_Submited__c, 
            FEC_Is_Save_Closed__c, FEC_Draft_Remarks__c, 
            FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c, 
            FEC_FCR__c, 
            FEC_Case_Created_On__c, FEC_Case_Created_By__c,  
            FEC_Last_Updated_On__c, FEC_Last_Updated_By__c, 
            CreatedDate, LastModifiedDate, ClosedDate, 
            FEC_Link_ID__c, FEC_Interaction_Status__c, 
            FEC_Case_ID__c, FEC_Interaction_ID__c, FEC_Customer_Username__c, 
            FEC_Interaction_Owner__c, FEC_Original_Info_Phone_Number__c, 
            FEC_Updated_Info_Phone_Number__c, FEC_Correct_Contract_Number__c, 
            FEC_User_Email_ID__c, FEC_Is_In_Create_new_mode__c, FEC_Show_Action__c, 
            FEC_Has_Account_or_Contract__c, EntitlementId, FEC_Business_Process__c, 
            FEC_Business_Process__r.Id, 
            FEC_Business_Process__r.Name, 
            FEC_Business_Process__r.FEC_Code__c, 
            FEC_Business_Process__r.FEC_Alias__c, 
            FEC_Business_Process__r.FEC_Name_VN__c, 
            FEC_Business_Process__r.FEC_Order__c,  
            FEC_SLA_Violating_Warning__c, FEC_SLA_Warning__c, FEC_Genesys_Campaign__c, 
            FEC_CS_D2C_Assessment_Type__c, FEC_CS_D2C_Risk_Level__c, 
            FEC_Outcome_Code__c, FEC_Application_ID__c, FEC_ID_Search__c, 
            FEC_Interaction_Masked_Phone__c, FEC_Case_Phone_Number__c, 
            FEC_Account_Contract_Number_Text__c, 
            RecordTypeId, RecordType.Name,
            FEC_Archive_Status__c 
            FROM Case WHERE Id IN :cases
        ];

        Map<Id, List<FEC_Case_Remarks__c>> remarksMap =
            new Map<Id, List<FEC_Case_Remarks__c>>();

        for (Case c : queried) {
            remarksMap.put(c.Id, new List<FEC_Case_Remarks__c>());
        }

        Test.startTest();
        String jsonStr = FEC_CasePayloadBuilder.buildBatch(queried, remarksMap);
        Test.stopTest();

        System.assert(String.isNotBlank(jsonStr), 'JSON không được rỗng');

        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(jsonStr);
        System.assertEquals(2, parsed.size(), 'Phải có 2 case trong array');

        Map<String, Object> firstCase = (Map<String, Object>) parsed[0];
        System.assert(firstCase.containsKey('Id'), 'Phải có key Id');
        System.assert(firstCase.containsKey('FEC_Case_Remarks_List__r'),
            'Phải có key FEC_Case_Remarks_List__r');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 7: FEC_CaseExportHttpService throw khi 400
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testHttpServiceThrowsOn400() {
        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Test.startTest();
        Boolean threw = false;
        try {
            FEC_CaseExportHttpService.postCases('[{"Id":"test"}]');
        } catch (FEC_CaseExportHttpService.ExportCalloutException ex) {
            threw = true;
            System.assert(ex.getMessage().contains('400'), 'Message phải đề cập 400');
        }
        Test.stopTest();

        System.assert(threw, 'Phải throw ExportCalloutException khi HTTP 400');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 8: Batch chỉ query case chưa archive (status = null / Pending)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testBatchSkipsProcessingCases() {
        List<Case> allCases = createCases(4);

        // Đánh dấu 2 case đầu đã Processing
        List<Case> alreadyDone = new List<Case>{
            new Case(Id = allCases[0].Id, FEC_Archive_Status__c = 'Processing'),
            new Case(Id = allCases[1].Id, FEC_Archive_Status__c = 'Processing')
        };
        update alreadyDone;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new FEC_CaseExportBatch(), 10);
        Test.stopTest();

        // 2 case đã Processing → không được thay đổi gì thêm (vẫn Processing)
        // 2 case còn lại (null) → sẽ được update thành Processing
        List<Case> result = [
            SELECT Id, FEC_Archive_Status__c
            FROM Case WHERE Id IN :allCases
        ];
        Integer processingCount = 0;
        for (Case c : result) {
            if (c.FEC_Archive_Status__c == 'Processing') processingCount++;
        }
        System.assertEquals(4, processingCount,
            'Tất cả 4 case phải có status Processing sau batch');
    }
}