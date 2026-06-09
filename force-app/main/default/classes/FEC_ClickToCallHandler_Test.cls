@IsTest
private class FEC_ClickToCallHandler_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetPhoneList_Success() {
        User admin = adminUser();
        Id caseId;

        System.runAs(admin) {
            Case c = new Case(
                Subject = 'Test Phone Fields',
                Status = 'New',
                SuppliedPhone = '0901234567',
                FEC_Phone_Number__c = '0901234567',
                FEC_ID_Search__c = 'CTC-' + String.valueOf(System.currentTimeMillis())
            );
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                insert c;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
            caseId = c.Id;
        }

        List<FEC_ClickToCallHandler.PhoneWrapper> results;
        System.runAs(admin) {
            Test.startTest();
            results = FEC_ClickToCallHandler.getPhoneList(caseId);
            Test.stopTest();
        }

        System.assertNotEquals(null, results, 'Danh sách trả về không được null.');
        System.assert(results.size() > 0, 'Phải có ít nhất một trường Phone trên Case.');

        Boolean foundPhone = false;
        for (FEC_ClickToCallHandler.PhoneWrapper pw : results) {
            if (pw.phone != null && pw.phone.contains('901234567')) {
                foundPhone = true;
                break;
            }
        }
        System.assert(foundPhone, 'Phải tìm thấy số điện thoại đã gán trên Case.');
    }

    @IsTest
    static void testGetPhoneList_NullId() {
        Test.startTest();
        List<FEC_ClickToCallHandler.PhoneWrapper> results = FEC_ClickToCallHandler.getPhoneList(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Nếu ID null, phải trả về danh sách rỗng.');
    }

    @IsTest
    static void testGetPhoneList_InvalidId() {
        // Sử dụng Id giả lập không tồn tại trong hệ thống
        Id fakeId = Id.valueOf('500000000000001AAA');
        
        Test.startTest();
        List<FEC_ClickToCallHandler.PhoneWrapper> results = FEC_ClickToCallHandler.getPhoneList(fakeId);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Nếu không tìm thấy Case, danh sách phải rỗng.');
    }

    @IsTest
    static void testWrapperCoverage() {
        // Bao phủ constructor của wrapper
        Test.startTest();
        FEC_ClickToCallHandler.PhoneWrapper pw = new FEC_ClickToCallHandler.PhoneWrapper('Label', '0123456789');
        System.assertEquals('0123456789', pw.phone);
        
        FEC_ClickToCallHandler.CallResponse cr = new FEC_ClickToCallHandler.CallResponse();
        Test.stopTest();
    }
}