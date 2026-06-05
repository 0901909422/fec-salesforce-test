@IsTest
private class FEC_ContractClosureController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(8);

        FEC_Country__c country = new FEC_Country__c(
            Name = 'Vietnam',
            FEC_Code__c = '2'
        );
        insert country;

        FEC_Province__c province = new FEC_Province__c(
            Name = 'Hanoi CC',
            FEC_Name_VN__c = 'Ha Noi',
            FEC_Code__c = 'HN' + suffix,
            FEC_Country__c = country.Id
        );
        insert province;

        FEC_District__c district = new FEC_District__c(
            Name = 'Ba Dinh CC',
            FEC_Name_VN__c = 'Ba Dinh',
            FEC_Code__c = 'BD' + suffix,
            FEC_Country__c = country.Id,
            FEC_Province__c = province.Id
        );
        insert district;

        Case c = new Case(
            Subject = 'Contract Closure Test Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Recipient_Name__c = 'Recipient One',
            FEC_Recipient_Phone_Number__c = '0901234567',
            FEC_ID_Search__c = 'CC-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'CC Customer',
            FEC_Case__c = c.Id,
            FEC_Customer_Name__c = 'Closure Customer',
            FEC_Email__c = 'closure@example.com',
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

        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = 'Current Address',
            FEC_Mailing_Address__c = true,
            FEC_Building__c = 'Tower A',
            FEC_Number__c = '10',
            FEC_Street__c = 'Main Street',
            FEC_Province__c = province.Id,
            FEC_Province_Text__c = 'Ha Noi',
            FEC_Ward_Text__c = 'Ba Dinh',
            FEC_Country__c = country.Id
        );

        insert new FEC_Additional_Info__c(FEC_Case__c = c.Id);
    }

    private static Case getClosureCase() {
        return [
            SELECT Id
            FROM Case
            WHERE Subject = 'Contract Closure Test Case'
            LIMIT 1
        ];
    }

    private static FEC_Address_Info__c getPermanentAddress() {
        return [
            SELECT Id, FEC_Full_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Address_Type__c = 'Current Address'
            LIMIT 1
        ];
    }

    private static FEC_Province__c getProvince() {
        return [SELECT Id, FEC_Name_VN__c FROM FEC_Province__c LIMIT 1];
    }

    private static FEC_District__c getDistrict() {
        return [SELECT Id, FEC_Name_VN__c, FEC_Province__c FROM FEC_District__c LIMIT 1];
    }

    private static String buildOfficeDraftPayload() {
        return JSON.serialize(new Map<String, Object>{
            'deliveryOfficeSelected' => true,
            'deliveryOptionCombined' => 'Office'
        });
    }

    private static String buildAddressCompletePayload(Id addressId) {
        FEC_Address_Info__c addr = [
            SELECT FEC_Full_Address__c
            FROM FEC_Address_Info__c
            WHERE Id = :addressId
            LIMIT 1
        ];
        return JSON.serialize(new Map<String, Object>{
            'deliveryAddressSelected' => true,
            'deliveryOptionCombined' => 'Address',
            'recipientName' => 'Recipient One',
            'recipientPhone' => '0901234567',
            'selectedAddressId' => addressId,
            'temporaryAddressDisplay' => addr.FEC_Full_Address__c
        });
    }

    private static String buildTempAddressPayload() {
        FEC_Province__c prov = getProvince();
        return JSON.serialize(new Map<String, Object>{
            'tempAddressParts' => new Map<String, Object>{
                'building' => 'Block B',
                'streetNumber' => '25',
                'street' => 'Le Loi',
                'wardLabel' => 'Ward 5',
                'provinceLabel' => prov.FEC_Name_VN__c,
                'provinceRecordId' => prov.Id
            }
        });
    }

    @IsTest
    static void testGetInitData() {
        Case c = getClosureCase();

        Test.startTest();
        FEC_ContractClosureController.InitDataDTO init =
            FEC_ContractClosureController.getInitData(c.Id);
        FEC_ContractClosureController.InitDataDTO nullInit =
            FEC_ContractClosureController.getInitData(null);
        Test.stopTest();

        System.assertEquals(true, init.success);
        System.assertEquals('closure@example.com', init.demographicEmail);
        System.assertEquals('Closure Customer', init.demographicCustomerName);
        System.assertEquals(false, nullInit.success);
        System.assert(init.addresses.size() >= 1);
        System.assertNotEquals(null, init.additionalInfoId);
    }

    @IsTest
    static void testValidateForComplete() {
        Case c = getClosureCase();
        FEC_Address_Info__c addr = getPermanentAddress();

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO invalid =
            FEC_ContractClosureController.validateForComplete(c.Id, '{}');
        FEC_ContractClosureController.ValidationResultDTO valid =
            FEC_ContractClosureController.validateForComplete(
                c.Id,
                buildAddressCompletePayload(addr.Id)
            );
        Test.stopTest();

        System.assertEquals(false, invalid.valid);
        System.assertEquals(true, valid.valid);
    }

    @IsTest
    static void testSaveFormDraft() {
        Case c = getClosureCase();

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveFormDraft(c.Id, buildOfficeDraftPayload());
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testSaveForm() {
        Case c = getClosureCase();
        FEC_Address_Info__c addr = getPermanentAddress();

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(
                c.Id,
                buildAddressCompletePayload(addr.Id)
            );
        Test.stopTest();

        System.assertEquals(true, result.valid);

        Case updated = [
            SELECT FEC_Recipient_Name__c, FEC_Recipient_Phone_Number__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('Recipient One', updated.FEC_Recipient_Name__c);
    }

    @IsTest
    static void testSearchAdministrativeUnits() {
        FEC_Province__c prov = getProvince();
        FEC_District__c dist = getDistrict();

        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> provinces =
            FEC_ContractClosureController.searchAdministrativeUnits(
                'FEC_Province__c',
                'Ha',
                null
            );
        List<FEC_ContractClosureController.PicklistEntryDTO> districts =
            FEC_ContractClosureController.searchAdministrativeUnits(
                'FEC_District__c',
                'Ba',
                prov.Id
            );
        List<FEC_ContractClosureController.PicklistEntryDTO> invalidObject =
            FEC_ContractClosureController.searchAdministrativeUnits(
                'Account',
                'x',
                null
            );
        Test.stopTest();

        System.assert(provinces.size() >= 1);
        System.assert(districts.size() >= 1);
        System.assertEquals(0, invalidObject.size());
        System.assertNotEquals(null, dist.Id);
    }

    @IsTest
    static void testUpsertAndDeleteTemporaryAddress() {
        Case c = getClosureCase();
        String payload = buildTempAddressPayload();

        Test.startTest();
        Id tempId = FEC_ContractClosureController.upsertTemporaryAddress(c.Id, payload);
        FEC_ContractClosureController.deleteTemporaryAddressRecord(tempId);
        FEC_ContractClosureController.deleteTemporaryAddressRecord(null);
        Test.stopTest();

        System.assertNotEquals(null, tempId);
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM FEC_Address_Info__c
                WHERE Id = :tempId
            ]
        );
    }

    @IsTest
    static void testUpsertTemporaryAddress_UpdateExisting() {
        Case c = getClosureCase();

        Test.startTest();
        Id firstId = FEC_ContractClosureController.upsertTemporaryAddress(
            c.Id,
            buildTempAddressPayload()
        );

        Map<String, Object> updatePayload = (Map<String, Object>) JSON.deserializeUntyped(
            buildTempAddressPayload()
        );
        updatePayload.put('tempAddressRecordId', firstId);

        Id secondId = FEC_ContractClosureController.upsertTemporaryAddress(
            c.Id,
            JSON.serialize(updatePayload)
        );
        Test.stopTest();

        System.assertEquals(firstId, secondId);
        FEC_Address_Info__c row = [
            SELECT FEC_Building__c, FEC_Address_Type__c, FEC_Case__c
            FROM FEC_Address_Info__c
            WHERE Id = :firstId
        ];
        System.assertEquals(
            FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
            row.FEC_Address_Type__c
        );
        System.assertEquals(c.Id, row.FEC_Case__c);
        System.assertEquals('Block B', row.FEC_Building__c);
    }

    @IsTest
    static void testSaveForm_InvalidCase() {
        Id fakeCaseId = '500000000000000AAA';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(fakeCaseId, buildOfficeDraftPayload());
        Test.stopTest();

        System.assertEquals(false, result.valid);
        System.assert(result.messages.size() > 0);
    }
}
