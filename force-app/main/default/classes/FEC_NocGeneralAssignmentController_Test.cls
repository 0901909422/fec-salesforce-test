@IsTest
private class FEC_NocGeneralAssignmentController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(FEC_Active__c = true);
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 1',
            FEC_Code__c = 'STG' + suffix,
            FEC_Active__c = true
        );
        insert stage;

        FEC_Channel__c channel = new FEC_Channel__c(
            Name = 'Zalo',
            FEC_Code__c = 'CHZ' + suffix,
            FEC_Channel_ID__c = 'CH-ZALO-' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Zalo',
            FEC_Channel_Status__c = true
        );
        insert channel;

        // 4. Tạo General Assignment Code mẫu
        FEC_General_Assignment__c gaCode = new FEC_General_Assignment__c(
            FEC_General_Assignment_Name__c = 'GA_001',
            FEC_Active__c = true
        );
        insert gaCode;

        // 5. Tạo cấu hình General Assignment liên kết với NOC
        FEC_General_Assignment_Config__c gaConfig = new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Case_Stage__c = stage.Id,
            FEC_General_Assignment_Name__c = 'GA_001',
            FEC_Customer_Type__c = 'Existing',
            FEC_Channel__c = 'Zalo',
            FEC_Active__c = true
        );
        insert gaConfig;
    }

    @IsTest
    static void testGetGeneralAssignments() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        List<FEC_NocGeneralAssignmentController.GeneralAssignmentWrapper> results = 
            FEC_NocGeneralAssignmentController.getGeneralAssignments(noc.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Phải lấy được 1 bản ghi cấu hình General Assignment.');
        
        FEC_NocGeneralAssignmentController.GeneralAssignmentWrapper wrapper = results[0];
        System.assertEquals('Existing', wrapper.CustomerType);
        System.assertEquals('Zalo', wrapper.Channel);
        System.assertEquals('Stage 1', wrapper.Stage);
        System.assertEquals('GA_001', wrapper.GeneralAssignmentName);
        System.assertEquals(true, wrapper.Active);
        System.assert(wrapper.recordUrl.contains(wrapper.Id), 'Record URL phải chứa ID bản ghi.');
    }

    @IsTest
    static void testGetPicklists() {
        Test.startTest();
        
        List<FEC_Channel__c> channels = FEC_NocGeneralAssignmentController.getChannelValues();
        System.assertEquals(1, channels.size(), 'Phải lấy được danh sách Channel.');

        List<FEC_Case_Stage__c> stages = FEC_NocGeneralAssignmentController.getCaseStages();
        System.assertEquals(1, stages.size(), 'Phải lấy được danh sách Case Stage.');

        List<FEC_General_Assignment__c> gaCodes = FEC_NocGeneralAssignmentController.getGeneralAssignmentCodes();
        System.assertEquals(1, gaCodes.size(), 'Phải lấy được danh sách General Assignment Codes.');

        Test.stopTest();
    }

    @IsTest
    static void testSaveGeneralAssignment_Success() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        FEC_Case_Stage__c stage = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1];

        Map<String, Object> gaData = new Map<String, Object>{
            'FEC_Nature_of_Cases__c' => noc.Id,
            'FEC_Customer_Type__c' => 'All',
            'FEC_Channel__c' => 'Facebook',
            'FEC_Case_Stage__c' => stage.Id,
            'FEC_General_Assignment_Name__c' => 'GA_002',
            'FEC_Active__c' => false
        };

        Test.startTest();
        FEC_NocGeneralAssignmentController.saveGeneralAssignment(gaData);
        Test.stopTest();

        List<FEC_General_Assignment_Config__c> savedConfigs = [
            SELECT Id, FEC_Customer_Type__c 
            FROM FEC_General_Assignment_Config__c 
            WHERE FEC_General_Assignment_Name__c = 'GA_002'
        ];
        
        System.assertEquals(1, savedConfigs.size(), 'Bản ghi cấu hình mới phải được lưu vào database.');
        System.assertEquals('All', savedConfigs[0].FEC_Customer_Type__c);
    }

    @IsTest
    static void testSaveGeneralAssignment_Exception() {
        // Cố tình truyền một Map rỗng hoặc sai kiểu dữ liệu để ép lỗi
        Map<String, Object> invalidData = new Map<String, Object>{
            'FEC_Nature_of_Cases__c' => 'Invalid_ID_String' // Gây lỗi Type Exception khi cast sang (Id)
        };

        Test.startTest();
        try {
            FEC_NocGeneralAssignmentController.saveGeneralAssignment(invalidData);
            System.assert(false, 'Hàm phải ném ra AuraHandledException khi dữ liệu lỗi.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Ngoại lệ ném ra phải thuộc kiểu AuraHandledException.');
        }
        Test.stopTest();
    }
}