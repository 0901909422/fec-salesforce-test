@IsTest
private class FEC_RDPaymentContractAssessService_Test {

    @TestSetup
    static void setupData() {
        User admin = [
            SELECT Id FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
        System.runAs(admin) {
            insert new Group(
                Name = 'Customer Support Queue',
                Type = 'Queue',
                DeveloperName = 'CS_Support_Queue'
            );
        }
    }

    @IsTest
    static void testGetRoutingConfig() {
        Test.startTest();
        Map<String, Object> result = FEC_RDPaymentContractAssessmentService.getRoutingConfig();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Kết quả không được null.');
        System.assert(
            result.containsKey('routingMap') || result.containsKey('scopedStageTeamByAssessment'),
            'Phải chứa cấu hình routing.'
        );

        Map<String, Object> routingMap = result.containsKey('routingMap')
            ? (Map<String, Object>) result.get('routingMap')
            : (Map<String, Object>) result.get('scopedStageTeamByAssessment');
        System.assertNotEquals(null, routingMap);
        System.assert(routingMap.size() > 0, 'routing map không được rỗng.');
    }

    @IsTest
    static void testGetScopedStageTeamByAssessment() {
        Test.startTest();
        Map<String, Object> config = FEC_RDPaymentContractAssessmentService.getRoutingConfig();
        Test.stopTest();

        System.assertNotEquals(null, config);
        Map<String, Object> routingMap = config.containsKey('routingMap')
            ? (Map<String, Object>) config.get('routingMap')
            : (Map<String, Object>) config.get('scopedStageTeamByAssessment');
        System.assertNotEquals(null, routingMap, 'routing map không được null.');
        System.assert(routingMap.size() > 0, 'routing map không được rỗng.');

        for (String assessment : routingMap.keySet()) {
            Object routeObj = routingMap.get(assessment);
            if (routeObj instanceof Map<String, Object>) {
                Map<String, Object> route = (Map<String, Object>) routeObj;
                System.assertNotEquals(null, route.get('team'), 'Mỗi assessment phải có team.');
                System.assertNotEquals(
                    null,
                    route.get('queueDevName'),
                    'Mỗi assessment phải có queueDevName.'
                );
            }
        }
    }

    @IsTest
    static void testGetQueuesByDeveloperNames() {
        List<String> devNames = new List<String>{ 'CS_Support_Queue', 'NON_EXISTENT' };

        Test.startTest();
        Map<String, Map<String, String>> result =
            FEC_RDPaymentContractAssessmentService.getQueuesByDeveloperNames(devNames);
        Map<String, Map<String, String>> emptyRes =
            FEC_RDPaymentContractAssessmentService.getQueuesByDeveloperNames(new List<String>());
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Chỉ tìm thấy 1 queue tồn tại.');
        System.assert(result.containsKey('CS_Support_Queue'));
        System.assertEquals('Customer Support Queue', result.get('CS_Support_Queue').get('name'));
        System.assertEquals(0, emptyRes.size(), 'Input rỗng phải trả về Map rỗng.');
    }
}
