@IsTest
private class FEC_NocRoutingAssignmentController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        // 1. Tạo Group (Queue) - Cần chạy trong khối System.runAs để tránh lỗi MIXED_DML_OPERATION
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            Group testQueue = new Group(
                Name = 'Test Queue Label',
                Type = 'Queue',
                DeveloperName = 'Test_Queue_Dev'
            );
            insert testQueue;
        }

        // 2. Tạo Master Data
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(FEC_Active__c = true);
        insert noc;

        FEC_Channel__c channel = new FEC_Channel__c(
            Name = 'CH01',
            FEC_Code__c = 'CHZ' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Zalo',
            FEC_Channel_ID__c = 'ZALO_' + suffix,
            FEC_Channel_Status__c = true
        );
        insert channel;

        // Giả định FEC_Select_Team__c là lookup trỏ đến FEC_Team__c
        // Nếu trong Org của bạn lookup này trỏ đến object khác, hãy đổi tên Object ở đây.
        FEC_Team__c team = new FEC_Team__c(Name = 'Team Alpha');
        insert team;

        FEC_Team_Queue__c teamQueue = new FEC_Team_Queue__c(
            Team__c = team.Id,
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'Test_Queue_Dev'
        );
        insert teamQueue;

        // 3. Tạo bản ghi Routing Assignment mẫu
        FEC_Routing_Assignment__c assignment = new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Channel__c = 'ZALO_' + suffix,
            FEC_Team__c = 'Team Alpha',
            FEC_Queue__c = 'Test_Queue_Dev',
            FEC_Active__c = true
        );
        insert assignment;
    }

    @IsTest
    static void testGetRoutingAssignmentsByNoc() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        // Nhánh 1: Truyền ID hợp lệ
        List<FEC_NocRoutingAssignmentController.RoutingAssignmentWrapper> results = 
            FEC_NocRoutingAssignmentController.getRoutingAssignmentsByNoc(noc.Id);
        
        // Nhánh 2: Truyền ID rỗng
        List<FEC_NocRoutingAssignmentController.RoutingAssignmentWrapper> emptyResults = 
            FEC_NocRoutingAssignmentController.getRoutingAssignmentsByNoc('');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Phải lấy được 1 cấu hình từ NOC ID hợp lệ.');
        System.assertEquals('Team Alpha', results[0].team);
        System.assertEquals(0, emptyResults.size(), 'Truyền ID rỗng phải trả về danh sách rỗng.');
    }

    @IsTest
    static void testGetOptions() {
        Test.startTest();
        // 1. Team Options
        List<Map<String, String>> teams = FEC_NocRoutingAssignmentController.getTeamOptions();
        System.assert(teams.size() > 0, 'Phải lấy được ít nhất 1 Team.');

        // 2. Queue Options
        List<Map<String, String>> queues = FEC_NocRoutingAssignmentController.getQueuesByTeam('Team Alpha');
        List<Map<String, String>> emptyQueues = FEC_NocRoutingAssignmentController.getQueuesByTeam('');
        System.assert(queues.size() > 0, 'Phải lấy được Queue theo Team Name.');
        System.assertEquals('Test Queue Label', queues[0].get('label'), 'Phải lấy được Label của Group Queue.');
        System.assertEquals(0, emptyQueues.size(), 'Truyền Team Name rỗng phải trả về mảng rỗng.');

        // 3. Channel Options
        List<Map<String, String>> channels = FEC_NocRoutingAssignmentController.getChannelOptions();
        System.assertEquals(1, channels.size(), 'Phải lấy được 1 Channel.');
        Test.stopTest();
    }

    @IsTest
    static void testCreateRoutingAssignment_SuccessAndException() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        String channelId = [
            SELECT FEC_Channel_ID__c
            FROM FEC_Channel__c
            LIMIT 1
        ].FEC_Channel_ID__c;

        Test.startTest();
        // 1. Test Thành công
        String newId = FEC_NocRoutingAssignmentController.createRoutingAssignment(
            noc.Id, 'All', channelId, 'Team Beta', 'New_Queue_Dev', true
        );
        System.assertNotEquals(null, newId, 'Phải tạo thành công và trả về ID.');

        // 2. Test Exception - Trùng Queue trong cùng NOC
        try {
            FEC_NocRoutingAssignmentController.createRoutingAssignment(
                noc.Id, 'All', channelId, 'Team Beta', 'New_Queue_Dev', true
            );
            System.assert(false, 'Hàm phải ném ngoại lệ khi tạo trùng Queue.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }

        // 3. Test Exception - Thiếu NOC ID
        try {
            FEC_NocRoutingAssignmentController.createRoutingAssignment(
                '', 'All', 'ZALO_01', 'Team Beta', 'Q3', true
            );
            System.assert(false, 'Hàm phải ném ngoại lệ khi thiếu NOC ID.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateRoutingAssignment_SuccessAndException() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        FEC_Routing_Assignment__c assignment1 = [
            SELECT Id, FEC_Channel__c
            FROM FEC_Routing_Assignment__c
            LIMIT 1
        ];
        String channelId = assignment1.FEC_Channel__c;
        
        // Tạo thêm 1 bản ghi để test update trùng lặp
        FEC_Routing_Assignment__c assignment2 = new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Queue__c = 'Another_Queue'
        );
        insert assignment2;

        Test.startTest();
        // 1. Test Thành công
        FEC_NocRoutingAssignmentController.updateRoutingAssignment(
            assignment1.Id, 'Existing', channelId, 'Team Alpha', 'Test_Queue_Dev_UPDATED', false
        );
        FEC_Routing_Assignment__c updated = [SELECT FEC_Queue__c, FEC_Active__c FROM FEC_Routing_Assignment__c WHERE Id = :assignment1.Id];
        System.assertEquals('Test_Queue_Dev_UPDATED', updated.FEC_Queue__c);
        System.assertEquals(false, updated.FEC_Active__c);

        // 2. Test Exception - Cập nhật trùng Queue với bản ghi khác
        try {
            FEC_NocRoutingAssignmentController.updateRoutingAssignment(
                assignment1.Id, 'Existing', channelId, 'Team Alpha', 'Another_Queue', true
            );
            System.assert(false, 'Hàm phải ném ngoại lệ khi update trùng Queue.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSingleRecordAndHistory() {
        FEC_Routing_Assignment__c assignment = [SELECT Id, Name FROM FEC_Routing_Assignment__c LIMIT 1];

        Test.startTest();
        // 1. Get Record Wrapper
        FEC_NocRoutingAssignmentController.RoutingAssignmentWrapper wrapper = 
            FEC_NocRoutingAssignmentController.getRoutingAssignment(assignment.Id);
        System.assertNotEquals(null, wrapper);
        System.assertEquals(assignment.Id, wrapper.id);

        FEC_NocRoutingAssignmentController.RoutingAssignmentWrapper nullWrapper = 
            FEC_NocRoutingAssignmentController.getRoutingAssignment('');
        System.assertEquals(null, nullWrapper);

        // 2. Get Record Name
        String name = FEC_NocRoutingAssignmentController.getRoutingAssignmentName(assignment.Id);
        System.assertEquals(assignment.Name, name);
        System.assertEquals('Routing Assignment', FEC_NocRoutingAssignmentController.getRoutingAssignmentName(''));

        // 3. Get History
        // History Tracking thường không sinh dữ liệu trực tiếp trong quá trình test chạy synchronous.
        // Việc gọi hàm này đảm bảo query không bị lỗi SOQL và nhánh if (isBlank) hoạt động.
        List<FEC_NocRoutingAssignmentController.HistoryWrapper> histories = 
            FEC_NocRoutingAssignmentController.getRoutingAssignmentHistory(assignment.Id);
        System.assertNotEquals(null, histories);
        
        List<FEC_NocRoutingAssignmentController.HistoryWrapper> nullHistories = 
            FEC_NocRoutingAssignmentController.getRoutingAssignmentHistory('');
        System.assertEquals(0, nullHistories.size());
        Test.stopTest();
    }
}