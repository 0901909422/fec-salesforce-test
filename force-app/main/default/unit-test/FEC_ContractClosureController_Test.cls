@IsTest
private class FEC_ContractClosureController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Closure Case',
                Status = 'New',
                FEC_ID_Search__c = 'CLSR-' + suffix
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Email__c = 'test@example.com',
            FEC_Customer_Name__c = 'Test Customer',
            FEC_Primary_Phone__c = '0901234567'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Country__c(Name = 'Vietnam', FEC_Code__c = '2');
    }

    private static Case getAnyCase() {
        return [SELECT Id FROM Case LIMIT 1];
    }

    private static Case createCaseWithHistory(String key) {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Closure ' + key,
                Status = 'New',
                FEC_ID_Search__c = 'CLSR-' + key + '-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Email__c = key + '@example.com',
            FEC_Customer_Name__c = 'Customer ' + key,
            FEC_Primary_Phone__c = '0901234567'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = hist.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static String firstPicklistValue(Schema.SObjectType sobj, String fieldApi) {
        Map<String, Schema.SObjectField> fm = sobj.getDescribe().fields.getMap();
        if (!fm.containsKey(fieldApi.toLowerCase())) {
            return null;
        }
        for (Schema.PicklistEntry pe : fm.get(fieldApi.toLowerCase()).getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    @IsTest
    static void testGetInitData_NullCaseId() {
        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result = FEC_ContractClosureController.getInitData(null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Null case id phải thất bại.');
        System.assertNotEquals(null, result.errorMessage, 'Phải có thông báo lỗi.');
    }

    @IsTest
    static void testGetInitData_Success() {
        Case c = getAnyCase();

        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result = FEC_ContractClosureController.getInitData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Dữ liệu phải được tải thành công.');
        System.assertEquals('test@example.com', result.demographicEmail);
    }

    @IsTest
    static void testValidateForComplete_InvalidDelivery() {
        Case c = getAnyCase();
        String payload = '{"deliveryEmailSelected": false, "deliveryAddressSelected": false, "deliveryOfficeSelected": false}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result = FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid, 'Validation phải thất bại nếu không chọn phương thức giao hàng.');
    }

    @IsTest
    static void testValidateForComplete_InvalidEmail() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryEmailSelected": true, "useExistingEmail": false, "temporaryEmail": "not-an-email"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result = FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid, 'Email sai định dạng phải fail.');
    }

    @IsTest
    static void testSaveForm_FailWhenMissingDelivery() {
        Case c = getAnyCase();
        String payload = '{"deliveryEmailSelected": false, "deliveryAddressSelected": false, "deliveryOfficeSelected": false}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result = FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid, 'saveForm phải fail khi thiếu delivery.');
    }

    @IsTest
    static void testSaveFormDraft_Success() {
        Case c = getAnyCase();
        String payload = '{"deliveryEmailSelected": true, "temporaryEmail": "test@new.com"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveFormDraft(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid, 'Lưu draft phải thành công.');
    }

    @IsTest
    static void testSearchAdministrativeUnits_InvalidObject() {
        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> rows =
            FEC_ContractClosureController.searchAdministrativeUnits('Account', 'a', null);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Object không hợp lệ phải trả rỗng.');
    }

    @IsTest
    static void testSearchAdministrativeUnits_Province() {
        FEC_Country__c vn = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        insert new FEC_Province__c(
            FEC_Country__c = vn.Id,
            FEC_Name_VN__c = 'Viet Test',
            FEC_Code__c = 'PVT01'
        );

        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> provinces =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_Province__c', 'Viet', null);
        Test.stopTest();

        System.assertNotEquals(null, provinces);
        System.assert(provinces.size() > 0, 'Phải trả về dữ liệu province.');
    }

    @IsTest
    static void testSearchAdministrativeUnits_District() {
        FEC_Country__c vn = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        FEC_Province__c pr = new FEC_Province__c(
            FEC_Country__c = vn.Id,
            FEC_Name_VN__c = 'Ha Noi',
            FEC_Code__c = 'PHN01'
        );
        insert pr;
        insert new FEC_District__c(
            FEC_Country__c = vn.Id,
            FEC_Province__c = pr.Id,
            FEC_Name_VN__c = 'Ba Dinh',
            FEC_Code__c = 'DBD01'
        );

        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> emptyRows =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_District__c', 'Ba', null);
        List<FEC_ContractClosureController.PicklistEntryDTO> rows =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_District__c', 'Ba', pr.Id);
        Test.stopTest();

        System.assertEquals(0, emptyRows.size(), 'District không có provinceId phải rỗng.');
        System.assert(rows.size() > 0, 'District có provinceId phải có kết quả.');
    }

    @IsTest
    static void testDeleteTemporaryAddressRecord_Null() {
        Test.startTest();
        FEC_ContractClosureController.deleteTemporaryAddressRecord(null);
        Test.stopTest();

        System.assert(true, 'Null id không được throw exception.');
    }

    @IsTest
    static void testUpsertTemporaryAddress_Error() {
        Case c = getAnyCase();
        String payload = '{"tempAddressParts": {"building": ""}}';

        Test.startTest();
        try {
            FEC_ContractClosureController.upsertTemporaryAddress(c.Id, payload);
            System.assert(false, 'Phải ném AuraHandledException do thiếu dữ liệu.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpsertTemporaryAddress_MissingParts() {
        Case c = getAnyCase();
        String payload = '{}';

        Test.startTest();
        try {
            FEC_ContractClosureController.upsertTemporaryAddress(c.Id, payload);
            System.assert(false, 'Thiếu tempAddressParts phải throw exception.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpsertAndDeleteTemporaryAddress_Success() {
        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE FEC_Account_or_Contract__c != null
            LIMIT 1
        ];

        String payloadInsert =
            '{"tempAddressParts":{"building":"B1","streetNumber":"12","street":"Le Loi","wardLabel":"Ward 1","provinceLabel":"HCM"}}';

        Test.startTest();
        Id addrId = FEC_ContractClosureController.upsertTemporaryAddress(c.Id, payloadInsert);
        String payloadUpdate =
            '{"tempAddressRecordId":"' + String.valueOf(addrId) + '","tempAddressParts":{"building":"B2","streetNumber":"99","street":"Tran Hung Dao","wardLabel":"Ward 2","provinceLabel":"HN"}}';
        Id updatedId = FEC_ContractClosureController.upsertTemporaryAddress(c.Id, payloadUpdate);
        FEC_ContractClosureController.deleteTemporaryAddressRecord(updatedId);
        Test.stopTest();

        System.assertNotEquals(null, addrId, 'Insert temporary address phải thành công.');
        System.assertEquals(addrId, updatedId, 'Update phải trả lại cùng id.');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Address_Info__c WHERE Id = :updatedId],
            'Address phải bị xóa.'
        );
    }

    @IsTest
    static void testUpsertTemporaryAddress_InvalidRowOwnership() {
        Case c1 = createCaseWithHistory('A');
        Case c2 = createCaseWithHistory('B');
        String payloadInsert =
            '{"tempAddressParts":{"building":"B1","streetNumber":"12","street":"Le Loi","wardLabel":"Ward 1","provinceLabel":"HCM"}}';

        Id addrId;
        Test.startTest();
        addrId = FEC_ContractClosureController.upsertTemporaryAddress(c1.Id, payloadInsert);
        String payloadUpdateWrongCase =
            '{"tempAddressRecordId":"' + String.valueOf(addrId) + '","tempAddressParts":{"building":"B9","streetNumber":"9","street":"Wrong","wardLabel":"Ward X","provinceLabel":"PX"}}';
        try {
            FEC_ContractClosureController.upsertTemporaryAddress(c2.Id, payloadUpdateWrongCase);
            System.assert(false, 'Address thuộc case khác phải throw exception.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateForComplete_AddressOfficeConflict() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryAddressSelected":true,"deliveryOfficeSelected":true,"recipientName":"A","recipientPhone":"0901234567"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid, 'Chọn đồng thời Address và Office phải fail.');
    }

    @IsTest
    static void testSaveForm_AddressInvalidPhone() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryAddressSelected":true,"recipientName":"Receiver","recipientPhone":"abcd","selectedAddressId":"a0X000000000001"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid, 'Số điện thoại không hợp lệ phải fail.');
    }

    @IsTest
    static void testSaveForm_Success_CreateAdditionalInfoAndContactList() {
        Case c = createCaseWithHistory('SAVE1');
        String verifyVal = firstPicklistValue(FEC_Additional_Info__c.SObjectType, 'FEC_Verify_Information__c');
        String callbackVal = firstPicklistValue(FEC_Additional_Info__c.SObjectType, 'FEC_Callback__c');
        String payload =
            '{"deliveryEmailSelected":true,"useExistingEmail":true,"verifyInformation":"' +
            (verifyVal == null ? '' : verifyVal) +
            '","callback":"' +
            (callbackVal == null ? '' : callbackVal) +
            '"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid, 'saveForm phải thành công với payload hợp lệ.');
        System.assertNotEquals(null, result.messages);
    }

    @IsTest
    static void testGetInitData_WithAddressRow() {
        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            LIMIT 1
        ];
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Case__c = c.Id,
            FEC_Address_Type__c = 'Permanent',
            FEC_Building__c = 'B1',
            FEC_Number__c = '12',
            FEC_Street__c = 'Le Loi',
            FEC_Ward_Text__c = 'Ward 1',
            FEC_Province_Text__c = 'HCM'
        );

        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result =
            FEC_ContractClosureController.getInitData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertNotEquals(null, result.addresses, 'Phải trả về danh sách address.');
    }

    @IsTest
    static void testValidateForComplete_EmailWithTemporaryChannel() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryEmailSelected":true,"useExistingEmail":false,"emailDeliveryChannel":"' +
            FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY +
            '","temporaryEmail":"newtemp@example.com"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testValidateForComplete_AddressMissingSelection() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryAddressSelected":true,"recipientName":"Receiver","recipientPhone":"0901234567"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid);
    }

    @IsTest
    static void testSearchAdministrativeUnits_ProvinceNoSearchTerm() {
        FEC_Country__c vn = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        insert new FEC_Province__c(
            FEC_Country__c = vn.Id,
            FEC_Name_VN__c = 'Da Nang',
            FEC_Code__c = 'PDN01'
        );

        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> rows =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_Province__c', '', null);
        Test.stopTest();

        System.assert(rows.size() > 0, 'Province không có keyword vẫn trả danh sách.');
    }

    @IsTest
    static void testSaveForm_Success_UpdateAdditionalInfoAndContactList() {
        Case c = createCaseWithHistory('SAVE2');
        FEC_Additional_Info__c ai = new FEC_Additional_Info__c(
            FEC_Case__c = c.Id,
            FEC_Verify_Information__c = null,
            FEC_Callback__c = null
        );
        insert ai;

        Id histId = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :c.Id LIMIT 1].FEC_Account_or_Contract__c;
        SObject contactList = Schema.getGlobalDescribe().get('FEC_Contact_List__c').newSObject(null);
        contactList.put('FEC_Customer_History__c', histId);
        contactList.put('FEC_Communication_Type__c', FEC_ConstantCommon.EMAIL);
        Map<String, Schema.SObjectField> clf = Schema.SObjectType.FEC_Contact_List__c.fields.getMap();
        if (clf.containsKey('fec_temporary_email__c')) {
            contactList.put('FEC_Temporary_Email__c', 'old-temp@example.com');
        }
        insert contactList;

        String verifyVal = firstPicklistValue(FEC_Additional_Info__c.SObjectType, 'FEC_Verify_Information__c');
        String callbackVal = firstPicklistValue(FEC_Additional_Info__c.SObjectType, 'FEC_Callback__c');
        String payload =
            '{"deliveryEmailSelected":true,"useExistingEmail":true,"verifyInformation":"' +
            (verifyVal == null ? '' : verifyVal) +
            '","callback":"' +
            (callbackVal == null ? '' : callbackVal) +
            '"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid, 'saveForm phải thành công.');
        FEC_Additional_Info__c aiAfter = [
            SELECT FEC_Verify_Information__c, FEC_Callback__c
            FROM FEC_Additional_Info__c
            WHERE Id = :ai.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, aiAfter);
    }

    @IsTest
    static void testValidateForComplete_TooManyDeliveryOptions() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryEmailSelected":true,"deliveryAddressSelected":true,"deliveryOfficeSelected":true,"deliveryPosSelected":true}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid);
    }

    @IsTest
    static void testSaveForm_AddressDeliveryWithSelectedAddress() {
        Case c = createCaseWithHistory('ADDR1');
        FEC_Address_Info__c addr = new FEC_Address_Info__c(
            FEC_Customer_History__c = [
                SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :c.Id LIMIT 1
            ].FEC_Account_or_Contract__c,
            FEC_Address_Type__c = 'Permanent',
            FEC_Full_Address__c = '123 Main St',
            FEC_Building__c = 'B1',
            FEC_Number__c = '12',
            FEC_Street__c = 'Le Loi',
            FEC_Ward_Text__c = 'Ward 1',
            FEC_Province_Text__c = 'HCM'
        );
        insert addr;

        String payload =
            '{"deliveryAddressSelected":true,"recipientName":"Receiver","recipientPhone":"0901234567","selectedAddressId":"' +
            String.valueOf(addr.Id) +
            '"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testValidateForComplete_EmailC360WithDemographic() {
        Case c = getAnyCase();
        String payload =
            '{"deliveryEmailSelected":true,"useExistingEmail":true,"emailDeliveryChannel":"' +
            FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_C360 +
            '"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testGetInitData_CaseNotFound() {
        Id fakeCaseId = Case.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result =
            FEC_ContractClosureController.getInitData(fakeCaseId);
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testSaveFormDraft_WithDeliveryValuesList() {
        Case c = getAnyCase();
        String deliveryVal = firstPicklistValue(Case.SObjectType, 'FEC_Delivery_Option_2__c');
        String payload = '{"deliveryValues":["' + (deliveryVal == null ? 'Email' : deliveryVal) + '"],"deliveryEmailSelected":true,"temporaryEmail":"draft@example.com"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveFormDraft(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testSearchAdministrativeUnits_DistrictNoSearchTerm() {
        FEC_Country__c vn = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        FEC_Province__c pr = new FEC_Province__c(
            FEC_Country__c = vn.Id,
            FEC_Name_VN__c = 'Can Tho',
            FEC_Code__c = 'PCT01'
        );
        insert pr;
        insert new FEC_District__c(
            FEC_Country__c = vn.Id,
            FEC_Province__c = pr.Id,
            FEC_Name_VN__c = 'Ninh Kieu',
            FEC_Code__c = 'DNK01'
        );

        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> rows =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_District__c', '', pr.Id);
        Test.stopTest();

        System.assert(rows.size() > 0);
    }
}