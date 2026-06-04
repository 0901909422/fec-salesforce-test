@IsTest
private class FEC_GetCSMasterDataByCodeService_Test {

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = FEC_ConstantCommon.KEY_VALID_CHANNELS_API,
            FEC_Code__c = 'API',
            FEC_Channel_ID__c = FEC_ConstantCommon.KEY_VALID_CHANNELS_API,
            FEC_Channel_Vietnamese_name__c = 'API',
            FEC_Channel_Status__c = true
        );

        // 1. Tạo dữ liệu Master Data
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Test SubCat',
            FEC_Code__c = 'SC01',
            FEC_Name_VN__c = 'Danh mục phụ test',
            FEC_Active__c = true
        );
        insert subCat;

        insert new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true
        );
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
        System.assertEquals('SC01', res.DataItems[0].ID);
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
}