/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class of ArchiveCaseController
Test Class:    
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
@IsTest
global with sharing class ArchiveCaseController_Test {

    @isTest
    static void testGetOrCreateCaseWithExistedCase() {
        AthenaCases__x fakeRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999', 
                                                    case_id__c = 'EXAMPLE-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ fakeRecord };
        Case localCase = new Case(ArchiveExternalId__c = 'EXAMPLE-999');
        insert localCase;
        
        Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(fakeRecord);
            ArchiveCaseController controller = new ArchiveCaseController(stdController);
            PageReference result = controller.fetchAndRedirect();
        Test.stopTest();
    }

    public class CaseDetailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String body = '{' +
            '  "attributes": {' +
            '    "type": "Case",' +
            '    "url": "/services/data/v66.0/sobjects/Case/5008600000EfFe9AAF"' +
            '  },' +
            '  "Id": "5008600000EfFe9AAF",' +
            '  "CaseNumber": "00001094",' +
            '  "Status": "Pending",' +
            '  "CreatedById": "00586000002D4FxAAK",' +
            '  "LastModifiedById": "00586000002CXNMAA4",' +
            '  "OwnerId": "00586000002CXNFAA4",' +
            '  "ParentId": null,' +
            '  "FEC_External_Interaction_ID__c": null,' +
            '  "FEC_Channel__c": "Inbound",' +
            '  "FEC_Case_Channel__c": null,' +
            '  "FEC_Created_by__c": null,' +
            '  "FEC_Created_On__c": null,' +
            '  "FEC_Interaction_Start_On__c": null,' +
            '  "FEC_Interaction_End_On__c": null,' +
            '  "FEC_Interaction_Duration__c": null,' +
            '  "FEC_Interaction_Resolved_By__c": null,' +
            '  "FEC_Phone_Number__c": null,' +
            '  "FEC_Transcription__c": null,' +
            '  "FEC_KYC_Method__c": null,' +
            '  "FEC_Interaction_Subchannel__c": null,' +
            '  "FEC_Other_Subchannel__c": null,' +
            '  "FEC_Customer_Name__c": null,' +
            '  "FEC_Genesys_Campaign_Name__c": null,' +
            '  "FEC_Routing_Action__c": null,' +
            '  "FEC_Interaction__c": "5008600000EfEbgAAF",' +
            '  "FEC_Interaction_Remarks__c": null,' +
            '  "FEC_Interaction_Resolved_By__r": null,' +
            '  "FEC_Customer_Type__c": "Existing",' +
            '  "FEC_Phone_Type__c": null,' +
            '  "FEC_Updated_Info_Phone_Type__c": "Primary Phone",' +
            '  "FEC_Interaction_Email__c": null,' +
            '  "FEC_Account_Number__c": null,' +
            '  "FEC_Contract_Number__c": null,' +
            '  "FEC_National_ID_Passport_ID__c": null,' +
            '  "FEC_Email_From__c": null,' +
            '  "FEC_Email_CC__c": null,' +
            '  "FEC_Account_or_Contract__c": "a0I86000000R4NhEAK",' +
            '  "FEC_CIF_Number__c": null,' +
            '  "FEC_Case_Email__c": null,' +
            '  "FEC_Account_or_Contract__r": {' +
            '    "attributes": {' +
            '      "type": "FEC_Customer_History__c",' +
            '      "url": "/services/data/v66.0/sobjects/FEC_Customer_History__c/a0I86000000R4NhEAK"' +
            '    },' +
            '    "Id": "a0I86000000R4NhEAK",' +
            '    "Name": "0001500040006525520",' +
            '    "CreatedById": "00586000002D4FxAAK",' +
            '    "LastModifiedById": "00586000002D4FxAAK",' +
            '    "FEC_Account_Close_Date__c": null,' +
            '    "FEC_Account_Number__c": "0001500040006525520",' +
            '    "FEC_Account_Open_Date__c": null,' +
            '    "FEC_Account_Status__c": null,' +
            '    "FEC_Account_Status_Change_Date__c": null,' +
            '    "FEC_Address__c": null,' +
            '    "FEC_Address_Type__c": null,' +
            '    "FEC_Agent_Code__c": null,' +
            '    "FEC_Agent_Name__c": null,' +
            '    "FEC_Agreement_Date__c": null,' +
            '    "FEC_Annual_Fee__c": null,' +
            '    "FEC_API_Cache__c": null,' +
            '    "FEC_API_Cache_Secondary_Demo__c": null,' +
            '    "FEC_Application_ID__c": null,' +
            '    "FEC_Available_Cash_Limit__c": null,' +
            '    "FEC_Available_Points__c": null,' +
            '    "FEC_Bank_Name__c": null,' +
            '    "FEC_Billing_Cycle__c": null,' +
            '    "FEC_Block_Code__c": null,' +
            '    "FEC_Block_Code_1__c": null,' +
            '    "FEC_Block_Code_2__c": null,' +
            '    "FEC_Block_Date__c": null,' +
            '    "FEC_Block_Date_1__c": null,' +
            '    "FEC_Block_Date_2__c": null,' +
            '    "FEC_Blocked_By__c": null,' +
            '    "FEC_Branch_Name__c": null,' +
            '    "FEC_Buyer_DOB__c": null,' +
            '    "FEC_Buyer_Gender__c": null,' +
            '    "FEC_Buyer_Name__c": null,' +
            '    "FEC_Buyer_NID__c": null,' +
            '    "FEC_Cancel_Date__c": null,' +
            '    "FEC_Card_Activation_Date__c": null,' +
            '    "FEC_Card_Activation_Status__c": null,' +
            '    "FEC_Card_Number__c": null,' +
            '    "FEC_Card_Type__c": null,' +
            '    "FEC_Case__c": "5008600000EfEbgAAF",' +
            '    "FEC_CC_Code__c": null,' +
            '    "FEC_CC_Name__c": null,' +
            '    "FEC_Charge_Off_Date__c": null,' +
            '    "FEC_CIF_Number__c": null,' +
            '    "Close_Fee_Amount__c": null,' +
            '    "FEC_Company_Name__c": null,' +
            '    "FEC_Contract_Number__c": null,' +
            '    "FEC_Contract_Status__c": null,' +
            '    "FEC_Contract_Type__c": null,' +
            '    "FEC_Credit_Limit__c": null,' +
            '    "FEC_Current_Balance__c": null,' +
            '    "FEC_Customer_Name__c": null,' +
            '    "FEC_Customer_Segment__c": null,' +
            '    "FEC_Customer_Type__c": "Existing",' +
            '    "FEC_Daily_Cash_Limit__c": null,' +
            '    "FEC_Daily_Cash_Number__c": null,' +
            '    "FEC_Daily_Ecommerce_Limit__c": null,' +
            '    "FEC_Daily_Ecommerce_Number__c": null,' +
            '    "FEC_Daily_Retail_Limit__c": null,' +
            '    "FEC_Daily_Retail_Number__c": null,' +
            '    "FEC_Date_Assigned__c": null,' +
            '    "FEC_Date_of_Birth__c": null,' +
            '    "FEC_Date_of_Issue__c": null,' +
            '    "FEC_Days_Past_Due__c": null,' +
            '    "FEC_Debt_Sale_Type__c": null,' +
            '    "FEC_Delinquency_Date__c": null,' +
            '    "FEC_Digital_Card_ID__c": null,' +
            '    "FEC_Disbursement_Channel__c": null,' +
            '    "FEC_Disbursement_Date__c": null,' +
            '    "FEC_DSA_Code__c": null,' +
            '    "FEC_DSA_Name__c": null,' +
            '    "FEC_E_Commerce_Status__c": null,' +
            '    "FEC_E_sign_Status__c": null,' +
            '    "FEC_Effective_Date__c": null,' +
            '    "FEC_Email__c": null,' +
            '    "FEC_Embossing_Name__c": null,' +
            '    "FEC_EMI__c": null,' +
            '    "FEC_Expiry_Date__c": null,' +
            '    "FEC_First_Effective_Date__c": null,' +
            '    "FEC_First_Name__c": null,' +
            '    "FEC_First_Payment_Date__c": null,' +
            '    "FEC_First_Transaction_Amount__c": null,' +
            '    "FEC_Fraud_Monitor_Date__c": null,' +
            '    "FEC_Fraud_Monitor_Flag__c": null,' +
            '    "FEC_Full_IPP_Payment_Amount__c": null,' +
            '    "FEC_Full_Payment_Amount__c": null,' +
            '    "FEC_Full_Payment_Without_IPP__c": null,' +
            '    "FEC_Gender__c": null,' +
            '    "FEC_Hold_Amount__c": null,' +
            '    "FEC_Installments_Remaining__c": null,' +
            '    "FEC_Insurance_Amount__c": null,' +
            '    "FEC_Insurance_Flag__c": null,' +
            '    "FEC_Interest_Sold__c": null,' +
            '    "FEC_Is_Top_Up_Account__c": null,' +
            '    "FEC_Last_Advance_Amount__c": null,' +
            '    "FEC_Last_Advance_Date__c": null,' +
            '    "FEC_Last_AF_Date__c": null,' +
            '    "FEC_Last_Credit_Limit__c": null,' +
            '    "FEC_Last_Credit_Limit_Date__c": null,' +
            '    "FEC_Last_Effective_Date__c": null,' +
            '    "FEC_Last_Name__c": null,' +
            '    "FEC_Last_Payment_Amount__c": null,' +
            '    "FEC_Last_Payment_Date__c": null,' +
            '    "FEC_Last_PIN_Action_Date__c": null,' +
            '    "FEC_Last_PIN_Status__c": null,' +
            '    "FEC_Last_Statement_Date__c": null,' +
            '    "FEC_Last_Transaction_Amount__c": null,' +
            '    "FEC_Loan_Amount__c": null,' +
            '    "FEC_Local_Use__c": null,' +
            '    "FEC_Mailing_Address__c": null,' +
            '    "FEC_Marital_Status__c": null,' +
            '    "FEC_Memorable_Question__c": null,' +
            '    "FEC_Middle_Name__c": null,' +
            '    "FEC_Minimum_Payment_Due__c": null,' +
            '    "FEC_Mobile_App_Account__c": null,' +
            '    "FEC_National_ID_Passport_ID__c": null,' +
            '    "FEC_Next_Due_Date__c": null,' +
            '    "FEC_Next_Statement_Date__c": null,' +
            '    "FEC_One_Time_Cash_Limit__c": null,' +
            '    "FEC_One_Time_Ecommerce_Limit__c": null,' +
            '    "FEC_One_Time_Retail_Limit__c": null,' +
            '    "FEC_OTB__c": null,' +
            '    "FEC_Payment_Due_Date__c": null,' +
            '    "FEC_Payment_ID__c": null,' +
            '    "FEC_PID_Number__c": null,' +
            '    "FEC_Place_of_Issue__c": null,' +
            '    "FEC_Plan_Payment_Amount__c": null,' +
            '    "FEC_Plastic_ID__c": null,' +
            '    "FEC_Policy_Number__c": null,' +
            '    "FEC_Premium_Fee__c": null,' +
            '    "FEC_Primary_Phone__c": null,' +
            '    "FEC_Principal_Sold__c": null,' +
            '    "FEC_Product_Association__c": "Not defined",' +
            '    "FEC_Product_Code__c": null,' +
            '    "FEC_Rate__c": null,' +
            '    "FEC_Reason_1__c": null,' +
            '    "FEC_Reason_2__c": null,' +
            '    "FEC_Remark__c": null,' +
            '    "FEC_Responsible_Person__c": null,' +
            '    "FEC_Responsible_Unit__c": null,' +
            '    "FEC_Sale_Channel__c": null,' +
            '    "FEC_Scheme_Desc__c": null,' +
            '    "FEC_Scheme_ID__c": null,' +
            '    "FEC_Sold_Amount__c": null,' +
            '    "FEC_Sold_Date__c": null,' +
            '    "FEC_Sold_Note__c": null,' +
            '    "FEC_Statement_Notification_Type__c": null,' +
            '    "FEC_Status__c": null,' +
            '    "FEC_Sub_Channel__c": null,' +
            '    "FEC_Tenure__c": null,' +
            '    "FEC_Top_Up_Loan_Amount_Requested__c": null,' +
            '    "FEC_Top_Up_Old_Account_App_ID__c": null,' +
            '    "FEC_Top_Up_Old_A_c_Outstanding__c": null,' +
            '    "FEC_Total_Accrued_Interest__c": 0,' +
            '    "FEC_Total_Balance__c": null,' +
            '    "FEC_Total_Close_Fee_Amount__c": 0,' +
            '    "FEC_Total_Current_Balance__c": 0,' +
            '    "FEC_Total_Deferred_Interest__c": 0,' +
            '    "FEC_Total_IPP_Accrued_Interest__c": 0,' +
            '    "FEC_Total_IPP_Balance__c": 0,' +
            '    "FEC_Total_IPP_Current_Balance__c": 0,' +
            '    "FEC_Total_Payment_Amount__c": 0,' +
            '    "FEC_Total_Payment_Due__c": null,' +
            '    "FEC_Total_Per_Diem__c": 0,' +
            '    "FEC_Total_Plan_Payment_Amount__c": 0,' +
            '    "FEC_TSA_Code__c": null,' +
            '    "FEC_TSA_Name__c": null,' +
            '    "FEC_User_ID__c": null,' +
            '    "FEC_Warning_Code__c": null,' +
            '    "FEC_Website_Account__c": null,' +
            '    "FEC_Work_Phone__c": null,' +
            '    "FEC_Zalo_Follower__c": null' +
            '  },' +
            '  "FEC_Product_Type__c": "a0a8600000CBiV4AAL",' +
            '  "FEC_Category__c": "a0E86000000T4ugEAC",' +
            '  "FEC_SubCategory__c": "a0j86000001EJF3AAO",' +
            '  "FEC_SubCode__c": "a0k86000002Xf8ZAAS",' +
            '  "FEC_New_Category__c": null,' +
            '  "FEC_New_SubCategory__c": null,' +
            '  "FEC_New_SubCode__c": null,' +
            '  "FEC_Stage_Name__c": "Phone Update - Card - Stage 2",' +
            '  "FEC_Complain_Type__c": null,' +
            '  "FEC_Original_Info_Phone_Type__c": "Primary Phone",' +
            '  "FEC_Actual_Nature_of_Case__c": "a0486000000G8rFAAS",' +
            '  "FEC_Product_Type__r": {' +
            '    "attributes": {' +
            '      "type": "FEC_Product_Type__c",' +
            '      "url": "/services/data/v66.0/sobjects/FEC_Product_Type__c/a0a8600000CBiV4AAL"' +
            '    },' +
            '    "Id": "a0a8600000CBiV4AAL",' +
            '    "Name": "Card",' +
            '    "FEC_Code__c": "Card",' +
            '    "FEC_Name_VN__c": "Card",' +
            '    "FEC_Alias__c": "Card",' +
            '    "FEC_Order__c": null' +
            '  },' +
            '  "FEC_Category__r": {' +
            '    "attributes": {' +
            '      "type": "FEC_Category__c",' +
            '      "url": "/services/data/v66.0/sobjects/FEC_Category__c/a0E86000000T4ugEAC"' +
            '    },' +
            '    "Id": "a0E86000000T4ugEAC",' +
            '    "Name": "Request",' +
            '    "FEC_Code__c": "Request",' +
            '    "FEC_Name_VN__c": "Request",' +
            '    "FEC_Alias__c": "Request",' +
            '    "FEC_Order__c": null' +
            '  },' +
            '  "FEC_SubCategory__r": {' +
            '    "attributes": {' +
            '      "type": "FEC_Sub_Category__c",' +
            '      "url": "/services/data/v66.0/sobjects/FEC_Sub_Category__c/a0j86000001EJF3AAO"' +
            '    },' +
            '    "Id": "a0j86000001EJF3AAO",' +
            '    "Name": "RC09-Cập nhật thông tin",' +
            '    "FEC_Code__c": "RC09",' +
            '    "FEC_Alias__c": "RC09",' +
            '    "FEC_Name_VN__c": "RC09-Cập nhật thông tin",' +
            '    "FEC_Order__c": null' +
            '  },' +
            '  "FEC_SubCode__r": {' +
            '    "attributes": {' +
            '      "type": "FEC_Sub_Code__c",' +
            '      "url": "/services/data/v66.0/sobjects/FEC_Sub_Code__c/a0k86000002Xf8ZAAS"' +
            '    },' +
            '    "Id": "a0k86000002Xf8ZAAS",' +
            '    "Name": "RC09.01-Cập nhật số điện thoại",' +
            '    "FEC_Code__c": "RC09.01",' +
            '    "FEC_Name_VN__c": "RC09.01-Cập nhật số điện thoại",' +
            '    "FEC_Alias__c": "RC09.01",' +
            '    "FEC_Order__c": null' +
            '  },' +
            '  "FEC_New_Category__r": null,' +
            '  "FEC_New_SubCategory__r": null,' +
            '  "FEC_New_SubCode__r": null,' +
            '  "FEC_Actual_Nature_of_Case__r": {' +
            '    "attributes": {' +
            '      "type": "FEC_Actual_Nature_of_Case__c",' +
            '      "url": "/services/data/v66.0/sobjects/FEC_Actual_Nature_of_Case__c/a0486000000G8rFAAS"' +
            '    },' +
            '    "Id": "a0486000000G8rFAAS",' +
            '    "Name": "a0486000000G8rF",' +
            '    "FEC_Customer_Type__c": "Existing",' +
            '    "FEC_User_Group__c": "CC;EC;F2F;IB;OB;QC;SP",' +
            '    "FEC_Business_Process__c": "a0986000002fPPeAAM",' +
            '    "FEC_Business_Process__r": {' +
            '      "attributes": {' +
            '        "type": "FEC_Business_Process__c",' +
            '        "url": "/services/data/v66.0/sobjects/FEC_Business_Process__c/a0986000002fPPeAAM"' +
            '      },' +
            '      "Id": "a0986000002fPPeAAM",' +
            '      "Name": "Phone Update",' +
            '      "FEC_Code__c": "Phone Update",' +
            '      "FEC_Alias__c": "Phone Update",' +
            '      "FEC_Name_VN__c": null,' +
            '      "FEC_Order__c": null' +
            '    },' +
            '    "FEC_Product_Type__r": {' +
            '      "attributes": {' +
            '        "type": "FEC_Product_Type__c",' +
            '        "url": "/services/data/v66.0/sobjects/FEC_Product_Type__c/a0a8600000CBiV4AAL"' +
            '      },' +
            '      "Id": "a0a8600000CBiV4AAL",' +
            '      "Name": "Card",' +
            '      "FEC_Code__c": "Card",' +
            '      "FEC_Alias__c": "Card",' +
            '      "FEC_Name_VN__c": "Card",' +
            '      "FEC_Order__c": null' +
            '    },' +
            '    "FEC_Category__r": {' +
            '      "attributes": {' +
            '        "type": "FEC_Category__c",' +
            '        "url": "/services/data/v66.0/sobjects/FEC_Category__c/a0E86000000T4ugEAC"' +
            '      },' +
            '      "Id": "a0E86000000T4ugEAC",' +
            '      "Name": "Request",' +
            '      "FEC_Code__c": "Request",' +
            '      "FEC_Alias__c": "Request",' +
            '      "FEC_Name_VN__c": "Request",' +
            '      "FEC_Order__c": null' +
            '    },' +
            '    "FEC_Sub_Category__r": {' +
            '      "attributes": {' +
            '        "type": "FEC_Sub_Category__c",' +
            '        "url": "/services/data/v66.0/sobjects/FEC_Sub_Category__c/a0j86000001EJF3AAO"' +
            '      },' +
            '      "Id": "a0j86000001EJF3AAO",' +
            '      "Name": "RC09-Cập nhật thông tin",' +
            '      "FEC_Code__c": "RC09",' +
            '      "FEC_Alias__c": "RC09",' +
            '      "FEC_Name_VN__c": "RC09-Cập nhật thông tin",' +
            '      "FEC_Order__c": null' +
            '    },' +
            '    "FEC_Sub_Code__r": {' +
            '      "attributes": {' +
            '        "type": "FEC_Sub_Code__c",' +
            '        "url": "/services/data/v66.0/sobjects/FEC_Sub_Code__c/a0k86000002Xf8ZAAS"' +
            '    },' +
            '      "Id": "a0k86000002Xf8ZAAS",' +
            '      "Name": "RC09.01-Cập nhật số điện thoại",' +
            '      "FEC_Code__c": "RC09.01",' +
            '      "FEC_Alias__c": "RC09.01",' +
            '      "FEC_Name_VN__c": "RC09.01-Cập nhật số điện thoại",' +
            '      "FEC_Order__c": null' +
            '    }' +
            '  },' +
            '  "FEC_Service_Case_Owner__c": "thanh.vu.5",' +
            '  "FEC_Final_Status__c": "Pending - CSOperations ",' +
            '  "FEC_Task__c": null,' +
            '  "FEC_Remarks__c": null,' +
            '  "FEC_Team__c": "CSOperations ",' +
            '  "FEC_Completed_User__c": null,' +
            '  "FEC_Follow_Up_User__c": "00586000002D4FxAAK|R;00586000002CXNMAA4|R;00586000002CXNFAA4|R",' +
            '  "FEC_Is_My_Follow_Up__c": false,' +
            '  "FEC_Is_Submited__c": true,' +
            '  "FEC_Is_Save_Closed__c": false,' +
            '  "FEC_Draft_Remarks__c": null,' +
            '  "FEC_SLA_Notification_1__c": null,' +
            '  "FEC_SLA_Notification_2__c": null,' +
            '  "FEC_SLA_Notification_3__c": null,' +
            '  "FEC_FCR__c": false,' +
            '  "FEC_Case_Created_On__c": "2026-03-03T15:50:55.000+0000",' +
            '  "FEC_Case_Created_By__c": "trangll2",' +
            '  "FEC_Last_Updated_On__c": "2026-03-27T03:00:13.000+0000",' +
            '  "FEC_Last_Updated_By__c": "huyen.nguyen.7",' +
            '  "CreatedDate": "2026-03-03T15:50:55.000+0000",' +
            '  "LastModifiedDate": "2026-03-27T03:00:13.000+0000",' +
            '  "ClosedDate": null,' +
            '  "FEC_Link_ID__c": "<a href=\\\"/5008600000EfFe9\\\" target=\\\"_self\\\">S-0032</a>",' +
            '  "FEC_Interaction_Status__c": "Auto-Closed",' +
            '  "FEC_Case_ID__c": "<a href=\\\"/5008600000EfFe9\\\" target=\\\"_self\\\">S-0032</a>",' +
            '  "FEC_Interaction_ID__c": "<a href=\\\"/5008600000EfEbg\\\" target=\\\"_self\\\">I-0016</a>",' +
            '  "FEC_Customer_Username__c": null,' +
            '  "FEC_Interaction_Owner__c": null,' +
            '  "FEC_Original_Info_Phone_Number__c": null,' +
            '  "FEC_Updated_Info_Phone_Number__c": "0987654332",' +
            '  "FEC_Correct_Contract_Number__c": null,' +
            '  "FEC_User_Email_ID__c": null,' +
            '  "FEC_Is_In_Create_new_mode__c": false,' +
            '  "FEC_Show_Action__c": true,' +
            '  "FEC_Has_Account_or_Contract__c": true,' +
            '  "EntitlementId": null,' +
            '  "FEC_Business_Process__c": null,' +
            '  "FEC_Business_Process__r": null,' +
            '  "FEC_SLA_Violating_Warning__c": null,' +
            '  "FEC_SLA_Warning__c": null,' +
            '  "FEC_Genesys_Campaign__c": null,' +
            '  "FEC_CS_D2C_Assessment_Type__c": null,' +
            '  "FEC_CS_D2C_Risk_Level__c": null,' +
            '  "FEC_Outcome_Code__c": null,' +
            '  "FEC_Application_ID__c": null,' +
            '  "FEC_ID_Search__c": "S-0032",' +
            '  "FEC_Interaction_Masked_Phone__c": null,' +
            '  "FEC_Case_Phone_Number__c": null,' +
            '  "FEC_Account_Contract_Number_Text__c": "0001500040006525520",' +
            '  "RecordTypeId": "012860000008vYzAAI",' +
            '  "RecordType": {' +
            '    "attributes": {' +
            '      "type": "RecordType",' +
            '      "url": "/services/data/v66.0/sobjects/RecordType/012860000008vYzAAI"' +
            '    },' +
            '    "Name": "Customer Case"' +
            '  }' +
            '}';
            
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testGetOrCreateCase_CreateNewCaseSuccess() {
        Test.setMock(HttpCalloutMock.class, new CaseDetailMock());
        AthenaCases__x fakeExternalRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999', 
                                                    case_id__c = 'EXAMPLE-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ fakeExternalRecord };
        
        Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(fakeExternalRecord);
            ArchiveCaseController controller = new ArchiveCaseController(stdController);
            PageReference result = controller.fetchAndRedirect();
        Test.stopTest();
    }
}