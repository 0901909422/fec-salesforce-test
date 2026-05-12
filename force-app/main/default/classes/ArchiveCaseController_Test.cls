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
                '  "FEC_District__c": null,' +
                '  "FEC_Country__c": null,' +
                '  "FEC_Case_Stage__c": null,' +
                '  "FEC_Actual_Nature_of_Case__c": null,' +
                '  "FEC_Business_Process__c": null,' +
                '  "ServiceContract": null,' +
                '  "Group": null,' +
                '  "SvcCatalogRequest": null,' +
                '  "SocialPost": null,' +
                '  "ResidentialLoanApplication": null,' +
                '  "PublicComplaint": null,' +
                '  "PersonLifeEvent": null,' +
                '  "InsurancePolicy": null,' +
                '  "EmailMessage": null,' +
                '  "BusinessMilestone": null,' +
                '  "Entitlement": null,' +
                '  "Product2": null,' +
                '  "Asset": null,' +
                '  "Account": null,' +
                '  "Contact": null,' +
                '  "FEC_Sub_Code__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Sub_Code__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Sub_Code__c/a0g850000010LNrAAM"' +
                '    },' +
                '    "Id": "a0g850000010LNrAAM",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "RC09.07-Cập nhật giới tính",' +
                '    "CreatedDate": "2026-02-11T07:24:59.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-02-24T07:31:06.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-02-24T07:31:06.000+0000",' +
                '    "FEC_Code__c": "RC09.07",' +
                '    "FEC_Do_Not_Bother__c": false' +
                '  },' +
                '  "FEC_Sub_Category__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Sub_Category__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Sub_Category__c/a0f85000001HD6hAAG"' +
                '    },' +
                '    "Id": "a0f85000001HD6hAAG",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "RC09-Cập nhật thông tin",' +
                '    "CreatedDate": "2026-02-11T07:23:50.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-02-24T07:30:12.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-02-24T07:30:12.000+0000",' +
                '    "FEC_Code__c": "RC09",' +
                '    "FEC_Do_Not_Bother__c": false' +
                '  },' +
                '  "FEC_Product_Type__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Product_Type__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Product_Type__c/a0a8500000ByciRAAR"' +
                '    },' +
                '    "Id": "a0a8500000ByciRAAR",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "Card",' +
                '    "CreatedDate": "2026-02-11T07:20:53.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-03-02T07:59:59.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-03-02T07:59:59.000+0000",' +
                '    "FEC_Code__c": "Card"' +
                '  },' +
                '  "FEC_Category__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Category__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Category__c/a0T85000004BTHYEA4"' +
                '    },' +
                '    "Id": "a0T85000004BTHYEA4",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "Request",' +
                '    "CreatedDate": "2026-02-11T07:22:04.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-02-24T07:29:34.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-02-24T07:29:34.000+0000",' +
                '    "FEC_Code__c": "Request",' +
                '    "FEC_Do_Not_Bother__c": false' +
                '  },' +
                '  "User": {' +
                '    "attributes": {' +
                '      "type": "User",' +
                '      "url": "/services/data/v66.0/sobjects/User/005d50000049NeDAAU"' +
                '    },' +
                '    "Id": "005d50000049NeDAAU",' +
                '    "Username": "long.nguyen.50@fecredit.com.vn.fecsit",' +
                '    "LastName": "Nguyễn",' +
                '    "FirstName": "Long",' +
                '    "MiddleName": "Thành",' +
                '    "Name": "Long Nguyễn",' +
                '    "Email": "long.nguyen.50@fecredit.com.vn",' +
                '    "IsActive": true,' +
                '    "TimeZoneSidKey": "Asia/Ho_Chi_Minh",' +
                '    "LocaleSidKey": "en_SG",' +
                '    "LanguageLocaleKey": "en_US",' +
                '    "FEC_Main_Queue__c": "FEC_DQ_CS_Support"' +
                '  },' +
                '  "RecordType": {' +
                '    "Id": "01285000000CMMXAA4",' +
                '    "Name": "Customer Case",' +
                '    "DeveloperName": "Customer_Case"' +
                '  },' +
                '  "FEC_Watcher__c": [' +
                '    {' +
                '      "Id": "a1685000001hy0PAAQ",' +
                '      "Name": "A-00000558",' +
                '      "FEC_User__c": "long.nguyen.50@fecredit.com.vn"' +
                '    }' +
                '  ],' +
                '  "FEC_Customer_History__c": {' +
                '    "Id": "a0h85000002dAOAAA2",' +
                '    "Name": "0001500010000005476"' +
                '  },' +
                '  "FEC_Case_Remarks__c": [' +
                '    {' +
                '      "Id": "a0u85000003LYxqAAG",' +
                '      "FEC_Case_Remarks__c": "sdefrgthj"' +
                '    },' +
                '    {' +
                '      "Id": "a0u85000003LZVhAAO",' +
                '      "FEC_Case_Remarks__c": "dfghj"' +
                '    }' +
                '  ],' +
                '  "Case": {' +
                '    "Id": "5008500000HigGOAAZ",' +
                '    "CaseNumber": "00001639",' +
                '    "Status": "Pending",' +
                '    "FEC_Account_Number__c": "0001500010000005476"' +
                '  },' +
                '  "FEC_Case_Attachments": [' +
                '    {' +
                '      "filename": "Screenshot 2026-05-06 at 11.06.33.png"' +
                '    }' +
                '  ]' +
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

    @isTest
    static void testQueryArchiveCases() {
        AthenaCases__x fakeRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999', 
                                                    case_id__c = 'EXAMPLE-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        Test.startTest();
            ArchiveCaseController.queryArchiveCases(null, 'EXAMPLE-999');
        Test.stopTest();
    }

    @isTest
    static void testResolveIdByCode() {
        Test.startTest();
            ArchiveCaseController.resolveIdByCode('FEC_Product_Type__c', 'FEC_Code__c', 'test');
        Test.stopTest();
    }

    @IsTest
    static void testExtractNestedCode_Success() {
        Map<String, Object> childMap = new Map<String, Object>{
            'ProductCode' => 'SKU-123'
        };
        Map<String, Object> parentMap = new Map<String, Object>{
            'ProductDetails' => childMap
        };

        Test.startTest();
            String result = ArchiveCaseController.extractNestedCode(parentMap, 'ProductDetails', 'ProductCode');
        Test.stopTest();
    }
}