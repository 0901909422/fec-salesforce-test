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

        FEC_Ward__c ward = new FEC_Ward__c(
            Name = 'Ward Lookup CC',
            FEC_Code__c = 'WL' + suffix,
            FEC_Name_VN__c = 'Phuong Lookup',
            FEC_Province__c = province.Id
        );
        insert ward;

        FEC_Address_Info__c officeAddr = new FEC_Address_Info__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = 'Office Address',
            FEC_Mailing_Address__c = false,
            FEC_Street__c = 'Office Street',
            FEC_Province__c = province.Id,
            FEC_District__c = district.Id,
            FEC_Ward__c = ward.Id,
            FEC_Country__c = country.Id
        );
        insert officeAddr;

        insert new FEC_Contact_List__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = hist.Id,
            FEC_Communication_Type__c = FEC_ConstantCommon.EMAIL,
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Contact_String__c = 'contactlist@example.com'
        );

        insert new FEC_Additional_Info__c(FEC_Case__c = c.Id);

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Selected_Address__c = officeAddr.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
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
    static void testUpsertTemporaryAddress_OptionalBuildingAndNumber() {
        Case c = getClosureCase();
        FEC_Province__c prov = getProvince();
        String payload = JSON.serialize(new Map<String, Object>{
            'tempAddressParts' => new Map<String, Object>{
                'building' => '',
                'streetNumber' => '',
                'street' => 'Le Loi',
                'wardLabel' => 'Ward 5',
                'provinceLabel' => prov.FEC_Name_VN__c,
                'provinceRecordId' => prov.Id
            }
        });

        Test.startTest();
        Id tempId = FEC_ContractClosureController.upsertTemporaryAddress(c.Id, payload);
        Test.stopTest();

        FEC_Address_Info__c row = [
            SELECT FEC_Building__c, FEC_Number__c, FEC_Street__c, FEC_Full_Address__c
            FROM FEC_Address_Info__c
            WHERE Id = :tempId
        ];
        System.assertEquals(null, row.FEC_Building__c);
        System.assertEquals(null, row.FEC_Number__c);
        System.assertEquals('Le Loi', row.FEC_Street__c);
        System.assert(row.FEC_Full_Address__c.contains('Le Loi'));
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

    @IsTest
    static void testGetInitData_ExtendedPaths() {
        Case c = getClosureCase();
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];

        Case otherCase = new Case(
            Subject = 'Other Closure Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Account_or_Contract__c = hist.Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert otherCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Case__c = otherCase.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
            FEC_Street__c = 'Other Temp'
        );

        Test.startTest();
        FEC_ContractClosureController.InitDataDTO init =
            FEC_ContractClosureController.getInitData(c.Id);
        Test.stopTest();

        System.assertEquals('contactlist@example.com', init.savedTemporaryEmail);
        System.assertNotEquals(null, init.savedSelectedAddressId);

        Boolean foundWardLookup = false;
        Boolean foundOfficeMailing = false;
        for (FEC_ContractClosureController.AddressRowDTO row : init.addresses) {
            if (row.wardLabel == 'Phuong Lookup') {
                foundWardLookup = true;
            }
            if (row.addressType == 'Office Address' && row.mailingAddressLabel == 'false') {
                foundOfficeMailing = true;
            }
        }
        System.assert(foundWardLookup, 'Expected ward label from FEC_Ward__r');
        System.assert(foundOfficeMailing, 'Expected mailing address false label');
    }

    @IsTest
    static void testSaveForm_EmailDeliveryAndAdditionalInfo() {
        Case c = getClosureCase();
        FEC_ContractClosureController.InitDataDTO init =
            FEC_ContractClosureController.getInitData(c.Id);

        String verifyVal = init.verifyInformationOptions.isEmpty()
            ? null : init.verifyInformationOptions[0].value;
        String callbackVal = init.callbackOptions.isEmpty()
            ? null : init.callbackOptions[0].value;

        String payload = JSON.serialize(new Map<String, Object>{
            'deliveryEmailSelected' => true,
            'deliveryOptionCombined' => FEC_ConstantCommon.EMAIL,
            'emailDeliveryChannel' => FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
            'temporaryEmail' => 'newtemp@example.com',
            'verifyInformation' => verifyVal,
            'callback' => callbackVal
        });

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);

        FEC_Additional_Info__c info = [
            SELECT FEC_Verify_Information__c, FEC_Callback__c
            FROM FEC_Additional_Info__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertEquals(verifyVal, info.FEC_Verify_Information__c);
        System.assertEquals(callbackVal, info.FEC_Callback__c);

        FEC_Contact_List__c cl = [
            SELECT FEC_Contact_String__c
            FROM FEC_Contact_List__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertEquals('newtemp@example.com', cl.FEC_Contact_String__c);
    }

    @IsTest
    static void testSaveForm_EmailDeliveryC360Channel() {
        Case c = getClosureCase();
        String payload = JSON.serialize(new Map<String, Object>{
            'deliveryEmailSelected' => true,
            'deliveryOptionCombined' => FEC_ConstantCommon.EMAIL,
            'emailDeliveryChannel' => FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_C360
        });

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testSaveForm_DeliveryValuesAndSelectedAddress() {
        Case c = getClosureCase();
        Id addrId = getPermanentAddress().Id;

        String payload = JSON.serialize(new Map<String, Object>{
            'deliveryEmailSelected' => true,
            'deliveryValues' => new List<String>{ FEC_ConstantCommon.EMAIL },
            'emailDeliveryChannel' => FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
            'temporaryEmail' => 'values@example.com',
            'selectedAddressId' => addrId
        });

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
        System.assertEquals(
            addrId,
            [SELECT FEC_Selected_Address__c FROM Case WHERE Id = :c.Id].FEC_Selected_Address__c
        );
    }

    @IsTest
    static void testSaveForm_NoDemographicEmailRequiresTemporary() {
        Case c = getClosureCase();
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        hist.FEC_Email__c = null;
        update hist;

        String payload = JSON.serialize(new Map<String, Object>{
            'deliveryEmailSelected' => true,
            'deliveryOptionCombined' => FEC_ConstantCommon.EMAIL,
            'emailDeliveryChannel' => FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
            'temporaryEmail' => 'required@example.com'
        });

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);

        FEC_Contact_List__c cl = [
            SELECT FEC_Contact_String__c
            FROM FEC_Contact_List__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertEquals('required@example.com', cl.FEC_Contact_String__c);
    }

    @IsTest
    static void testValidateForComplete_DeliveryRuleFailures() {
        Case c = getClosureCase();

        System.assertEquals(
            false,
            FEC_ContractClosureController.validateForComplete(
                c.Id,
                JSON.serialize(new Map<String, Object>{
                    'deliveryAddressSelected' => true,
                    'deliveryOfficeSelected' => true,
                    'deliveryOptionCombined' => 'Address;Office'
                })
            ).valid
        );

        System.assertEquals(
            false,
            FEC_ContractClosureController.validateForComplete(
                c.Id,
                JSON.serialize(new Map<String, Object>{
                    'deliveryEmailSelected' => true,
                    'deliveryOptionCombined' => FEC_ConstantCommon.EMAIL,
                    'emailDeliveryChannel' => FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
                    'temporaryEmail' => 'not-an-email'
                })
            ).valid
        );

        System.assertEquals(
            false,
            FEC_ContractClosureController.validateForComplete(
                c.Id,
                JSON.serialize(new Map<String, Object>{
                    'deliveryAddressSelected' => true,
                    'deliveryOptionCombined' => 'Address',
                    'recipientName' => 'Recipient One',
                    'recipientPhone' => 'abc'
                })
            ).valid
        );

        System.assertEquals(
            false,
            FEC_ContractClosureController.validateForComplete(
                c.Id,
                JSON.serialize(new Map<String, Object>{
                    'deliveryAddressSelected' => true,
                    'deliveryOptionCombined' => 'Address',
                    'recipientName' => 'Recipient One',
                    'recipientPhone' => '0901234567',
                    'selectedAddressId' => 'a0X000000000000AAA'
                })
            ).valid
        );
    }

    @IsTest
    static void testSearchAdministrativeUnits_EmptySearchKey() {
        FEC_Province__c prov = getProvince();
        FEC_District__c dist = getDistrict();

        Test.startTest();
        List<FEC_ContractClosureController.PicklistEntryDTO> allProvinces =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_Province__c', '', null);
        List<FEC_ContractClosureController.PicklistEntryDTO> allDistricts =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_District__c', null, prov.Id);
        List<FEC_ContractClosureController.PicklistEntryDTO> noProvinceDistricts =
            FEC_ContractClosureController.searchAdministrativeUnits('FEC_District__c', 'Ba', null);
        Test.stopTest();

        System.assert(allProvinces.size() >= 1);
        System.assert(allDistricts.size() >= 1);
        System.assertEquals(0, noProvinceDistricts.size());
        System.assertNotEquals(null, dist.Id);
    }

    @IsTest
    static void testUpsertTemporaryAddress_MissingParts() {
        Case c = getClosureCase();

        Boolean threwMissingParts = false;
        try {
            FEC_ContractClosureController.upsertTemporaryAddress(
                c.Id,
                JSON.serialize(new Map<String, Object>())
            );
        } catch (AuraHandledException e) {
            threwMissingParts = true;
        }
        System.assertEquals(true, threwMissingParts);

        Boolean threwValidation = false;
        try {
            FEC_ContractClosureController.upsertTemporaryAddress(
                c.Id,
                JSON.serialize(new Map<String, Object>{
                    'tempAddressParts' => new Map<String, Object>{
                        'provinceLabel' => 'Ha Noi'
                    }
                })
            );
        } catch (AuraHandledException e) {
            threwValidation = true;
        }
        System.assertEquals(true, threwValidation);
    }

    @IsTest
    static void testUpsertTemporaryAddress_InvalidExistingRow() {
        Case c = getClosureCase();
        Id permanentId = getPermanentAddress().Id;

        Map<String, Object> updatePayload = (Map<String, Object>) JSON.deserializeUntyped(
            buildTempAddressPayload()
        );
        updatePayload.put('tempAddressRecordId', permanentId);

        Boolean threwInvalid = false;
        try {
            FEC_ContractClosureController.upsertTemporaryAddress(
                c.Id,
                JSON.serialize(updatePayload)
            );
        } catch (AuraHandledException e) {
            threwInvalid = true;
        }
        System.assertEquals(true, threwInvalid);
    }

    @IsTest
    static void testSaveFormDraft_EmailDelivery() {
        Case c = getClosureCase();
        String payload = JSON.serialize(new Map<String, Object>{
            'deliveryEmailSelected' => true,
            'deliveryOptionCombined' => FEC_ConstantCommon.EMAIL,
            'emailDeliveryChannel' => FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
            'temporaryEmail' => 'draft@example.com'
        });

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_ContractClosureController.saveFormDraft(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
        FEC_Contact_List__c cl = [
            SELECT FEC_Contact_String__c
            FROM FEC_Contact_List__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertEquals('draft@example.com', cl.FEC_Contact_String__c);
    }
}
