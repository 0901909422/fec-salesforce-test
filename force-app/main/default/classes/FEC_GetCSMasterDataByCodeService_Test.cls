@IsTest
private class FEC_GetCSMasterDataByCodeService_Test {

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = 'API Channel',
            FEC_Channel_ID__c = FEC_ConstantCommon.KEY_VALID_CHANNELS_API,
            FEC_Channel_Vietnamese_name__c = 'API',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true
        );

        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'CARD',
            FEC_Active__c = true
        );
        insert productType;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Test SubCat',
            FEC_Code__c = 'SC01',
            FEC_Name_VN__c = 'Danh mục phụ test',
            FEC_Active__c = true
        );
        insert subCat;

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = productType.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Channel__c = FEC_ConstantCommon.KEY_VALID_CHANNELS_API,
            FEC_Active__c = true
        );
        FEC_CommonUltils.resetActiveChannelCacheForTest();
    }

    @IsTest
    static void testGetCSMasterDataByCode_Success() {
        // 2. Chuẩn bị Request
        FEC_GetCSMasterDataByCodeService.SysRequestType sys = new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.TransactionID = 'TXN123';
        sys.DateTime_x = System.now();

        FEC_GetCSMasterDataByCodeService.MasterDataCodeType masterCode = new FEC_GetCSMasterDataByCodeService.MasterDataCodeType();
        masterCode.SubCategory = 'SC01';

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res = 
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, masterCode, null, null, 'Test Remarks'
            );
        Test.stopTest();

        // 3. Xác thực kết quả
        System.assertEquals('1', res.Sys.Code, 'API nên trả về thành công (Code 1).');
        System.assert(res.DataItems.size() > 0, 'Phải có ít nhất 1 item dữ liệu.');
        System.assertEquals('CARD', res.DataItems[0].ID);
    }

    @IsTest
    static void testGetCSMasterDataByCode_ChannelFunctionNotAllowed() {
        insert new FEC_Channel__c(
            Name = 'Vtiger',
            FEC_Channel_ID__c = 'Vtiger',
            FEC_Channel_Vietnamese_name__c = 'Vtiger',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = true,
            FEC_Get_Nature_Of_Case__c = false
        );

        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = 'Vtiger';
        sys.TransactionID = 'TXN-VTIGER';
        sys.DateTime_x = System.now();

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, null, null, null, null
            );
        Test.stopTest();

        System.assertEquals('0', res.Sys.Code);
        System.assertEquals(
            FEC_ConstantCommon.MY_CASE_CHANNEL_GET_MASTER_DATA_BY_CODE_NOT_ALLOWED_MSG,
            res.Sys.Description
        );
    }

    @IsTest
    static void testGetCSMasterDataByCode_InvalidChannel() {
        // Chuẩn bị Request với Channel không hợp lệ
        FEC_GetCSMasterDataByCodeService.SysRequestType sys = new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = 'INVALID';
        sys.TransactionID = 'TXN999';
        sys.DateTime_x = System.now();

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res = 
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, null, null, null, null
            );
        Test.stopTest();

        System.assertEquals('0', res.Sys.Code, 'API phải trả về lỗi (Code 0) khi channel không hợp lệ.');
    }

    @IsTest
    static void testGetCSMasterDataByCode_MultiChannelNocTokenMatch() {
        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Multi Channel Product',
            FEC_Code__c = 'MCARD',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Multi SubCat',
            FEC_Code__c = 'MSC01',
            FEC_Name_VN__c = 'Multi sub category',
            FEC_Active__c = true
        );
        insert new List<SObject>{ productType, subCat };

        insert new FEC_Channel__c(
            Name = 'CSM Channel',
            FEC_Channel_ID__c = 'CSM',
            FEC_Code__c = 'CSM',
            FEC_Channel_Vietnamese_name__c = 'CSM',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true
        );
        FEC_CommonUltils.resetActiveChannelCacheForTest();

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = productType.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Channel__c = 'CSM,Vymo,Vtiger_Sale,iCollect,FEMobile,FEWeb,Zalo',
            FEC_Active__c = true
        );

        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = 'CSM';
        sys.TransactionID = 'TXN-MULTI';
        sys.DateTime_x = System.now();

        FEC_GetCSMasterDataByCodeService.MasterDataCodeType masterCode =
            new FEC_GetCSMasterDataByCodeService.MasterDataCodeType();
        masterCode.SubCategory = 'MSC01';

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, masterCode, null, null, null
            );
        Test.stopTest();

        System.assertEquals('1', res.Sys.Code);
        System.assertEquals(1, res.DataItems.size());
        System.assertEquals('MCARD', res.DataItems[0].ID);
    }

    @IsTest
    static void testGetCSMasterDataByCode_MultiChannelNocDoesNotPartialMatch() {
        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Partial Match Product',
            FEC_Code__c = 'PCARD',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Partial SubCat',
            FEC_Code__c = 'PSC01',
            FEC_Name_VN__c = 'Partial sub category',
            FEC_Active__c = true
        );
        insert new List<SObject>{ productType, subCat };

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = productType.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Channel__c = 'CSM,Vymo,Vtiger_Sale,iCollect,FEMobile,FEWeb,Zalo',
            FEC_Active__c = true
        );

        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.TransactionID = 'TXN-PARTIAL';
        sys.DateTime_x = System.now();

        FEC_GetCSMasterDataByCodeService.MasterDataCodeType masterCode =
            new FEC_GetCSMasterDataByCodeService.MasterDataCodeType();
        masterCode.SubCategory = 'PSC01';

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, masterCode, null, null, null
            );
        Test.stopTest();

        System.assertEquals('1', res.Sys.Code);
        System.assertEquals(0, res.DataItems.size(), 'CS must not match CSM substring.');
    }

    @IsTest
    static void testGetCSMasterDataByCode_WithCustomerTypeAndAdditionalInfo() {
        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.TransactionID = 'TXN-FULL';
        sys.DateTime_x = System.now();

        FEC_GetCSMasterDataByCodeService.MasterDataCodeType masterCode =
            new FEC_GetCSMasterDataByCodeService.MasterDataCodeType();
        masterCode.SubCategory = 'SC01';

        FEC_GetCSMasterDataByCodeService.CustomerTypeRequest customerType =
            new FEC_GetCSMasterDataByCodeService.CustomerTypeRequest();
        customerType.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        customerType.Language = FEC_ConstantCommon.LANGUAGE_VN;

        FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest additionalInfo =
            new FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest();
        additionalInfo.ID = 'Field1';
        additionalInfo.Value = 'Value1';

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys,
                masterCode,
                customerType,
                additionalInfo,
                'Integration remarks'
            );
        Test.stopTest();

        System.assertEquals('1', res.Sys.Code);
        System.assert(res.DataItems.size() > 0);
        System.assertEquals('Integration remarks', res.RequestInfo.Remarks);
        System.assertEquals('Field1', res.AdditionalInfo.ID);
        System.assertEquals('Value1', res.AdditionalInfo.Value);
        System.assertEquals(
            FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE,
            res.CustomerInfo.UserType
        );
    }

    @IsTest
    static void testGetCSMasterDataByCode_NullSys() {
        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                null, null, null, null, null
            );
        Test.stopTest();

        System.assertEquals('0', res.Sys.Code);
        System.assertNotEquals(null, res.Sys.Description);
    }

    @IsTest
    static void testGetCSMasterDataByCode_InvalidTransactionId() {
        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.TransactionID = 'X'.repeat(
            FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN + 1
        );
        sys.DateTime_x = System.now();

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, null, null, null, null
            );
        Test.stopTest();

        System.assertEquals('0', res.Sys.Code);
    }

    @IsTest
    static void testGetCSMasterDataByCode_NullDateTime() {
        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.TransactionID = 'TXN-NO-DT';
        sys.DateTime_x = null;

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, null, null, null, null
            );
        Test.stopTest();

        System.assertEquals('0', res.Sys.Code);
    }

    @IsTest
    static void testGetCSMasterDataByCode_ProductTypeReturnLevel() {
        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        sys.Channel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        sys.TransactionID = 'TXN-PT';
        sys.DateTime_x = System.now();

        Test.startTest();
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse res =
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                sys, new FEC_GetCSMasterDataByCodeService.MasterDataCodeType(), null, null, null
            );
        Test.stopTest();

        System.assertEquals('1', res.Sys.Code);
        System.assertEquals(1, res.DataItems.size());
        System.assertEquals('CARD', res.DataItems[0].ID);
        System.assertEquals(
            FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT,
            res.DataItems[0].Type
        );
    }
}