@IsTest
private class FEC_GetCSMasterDataService_Test {

    @TestSetup
    static void setupData() {
        FEC_Channel__c apiChannel = FEC_UnitTestMyCaseChannelUtil.ensureApiChannel();
        String suffix = String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000));

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = 'P01' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert prod;

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud',
            FEC_Code__c = 'B01' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert proc;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Category',
            FEC_Code__c = 'C01' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SubCat',
            FEC_Code__c = 'S01' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SubCode',
            FEC_Code__c = 'SC01' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c nocExisting = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Business_Process__c = proc.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
            FEC_Active__c = true
        );
        FEC_Nature_of_Case__c nocNonExisting = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Business_Process__c = proc.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER,
            FEC_Active__c = true
        );
        insert new List<FEC_Nature_of_Case__c>{ nocExisting, nocNonExisting };
        FEC_UnitTestMyCaseChannelUtil.linkNocToChannel(nocExisting.Id, apiChannel.Id);
        FEC_UnitTestMyCaseChannelUtil.linkNocToChannel(nocNonExisting.Id, apiChannel.Id);

        insert new FEC_Master_Data_Setting__c(
            FEC_Field_Object_Name__c = FEC_ConstantCommon.OBJ_ADDITIONAL_INFO,
            FEC_Field_API_Name__c = 'FEC_Verify_Information__c',
            FEC_Field_Order_Display__c = 1,
            FEC_Field_Mandatory__c = true,
            FEC_Nature_Of_Case__c = nocExisting.Id
        );
        insert new FEC_Master_Data_Setting__c(
            FEC_Field_Object_Name__c = FEC_ConstantCommon.OBJ_ADDITIONAL_INFO,
            FEC_Field_API_Name__c = 'InvalidField__c',
            FEC_Field_Order_Display__c = 2
        );
    }

    private static FEC_GetCSMasterDataService.SysRequestType validSys() {
        FEC_GetCSMasterDataService.SysRequestType sys = new FEC_GetCSMasterDataService.SysRequestType();
        sys.TransactionID = 'TXN123';
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.DateTime_x = System.now();
        return sys;
    }

    @IsTest
    static void testGetCSMasterData_Success() {
        FEC_GetCSMasterDataService.SysRequestType sys = validSys();

        Test.startTest();
        FEC_GetCSMasterDataService.GetCSMasterDataResponse res =
            FEC_GetCSMasterDataService.GetCSMasterDataRequest(sys);
        Test.stopTest();

        System.assert(
            res.Sys.Code == '1' || res.Sys.Code == System.Label.FEC_Success_Title,
            'API nên trả về mã thành công.'
        );
        System.assert(res.MasterDataItems.size() > 0, 'Dữ liệu master không được trống.');
        Boolean hasAdditionalProps = false;
        for (FEC_GetCSMasterDataService.MasterDataItemType item : res.MasterDataItems) {
            if (item.AdditionalProperties != null && !item.AdditionalProperties.isEmpty()) {
                hasAdditionalProps = true;
                break;
            }
        }
        System.assertEquals(true, hasAdditionalProps, 'Phải có AdditionalProperties từ master data setting.');
    }

    @IsTest
    static void testGetCSMasterData_ValidationFail() {
        FEC_GetCSMasterDataService.SysRequestType sys = new FEC_GetCSMasterDataService.SysRequestType();
        sys.Channel = 'INVALID';

        Test.startTest();
        FEC_GetCSMasterDataService.GetCSMasterDataResponse res =
            FEC_GetCSMasterDataService.GetCSMasterDataRequest(sys);
        Test.stopTest();

        System.assertEquals('102', res.Sys.Code, 'API nên trả về lỗi channel không hợp lệ.');
    }

    @IsTest
    static void testGetCSMasterData_NullSys() {
        Test.startTest();
        FEC_GetCSMasterDataService.GetCSMasterDataResponse res =
            FEC_GetCSMasterDataService.GetCSMasterDataRequest(null);
        Test.stopTest();

        System.assertEquals('101', res.Sys.Code);
    }

    @IsTest
    static void testGetCSMasterData_InvalidTransactionId() {
        FEC_GetCSMasterDataService.SysRequestType sys = validSys();
        sys.TransactionID = '';

        Test.startTest();
        FEC_GetCSMasterDataService.GetCSMasterDataResponse res =
            FEC_GetCSMasterDataService.GetCSMasterDataRequest(sys);
        Test.stopTest();

        System.assertEquals('103', res.Sys.Code);
    }

    @IsTest
    static void testGetCSMasterData_TransactionIdTooLong() {
        FEC_GetCSMasterDataService.SysRequestType sys = validSys();
        sys.TransactionID = 'X'.repeat(FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN + 1);

        Test.startTest();
        FEC_GetCSMasterDataService.GetCSMasterDataResponse res =
            FEC_GetCSMasterDataService.GetCSMasterDataRequest(sys);
        Test.stopTest();

        System.assertEquals('103', res.Sys.Code);
    }

    @IsTest
    static void testBuildGetCSMasterDataSoapXml() {
        FEC_GetCSMasterDataService.SysRequestType sys = validSys();

        Test.startTest();
        String soapXml = FEC_GetCSMasterDataService.buildGetCSMasterDataSoapXml(sys);
        Test.stopTest();

        System.assertNotEquals(null, soapXml);
        System.assert(soapXml.contains('MasterData') || soapXml.length() > 0, 'SOAP XML phải được dựng.');
    }
}