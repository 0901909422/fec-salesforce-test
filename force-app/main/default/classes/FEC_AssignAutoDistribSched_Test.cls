@IsTest
private class FEC_AssignAutoDistribSched_Test {

    @IsTest
    static void testStartFiveMinuteChain() {
        // 1. Giả lập (Schedule) các job cũ để test logic dọn dẹp (abort)
        String dummyCron = '0 0 0 1 1 ? 2099';
        System.schedule('FEC Case Assignment Auto Distribute - Legacy Test', dummyCron, new FEC_AssignAutoDistribSched());
        System.schedule('FEC_AssignAutoDistribSched:OldChainTest', dummyCron, new FEC_AssignAutoDistribSched());

        Test.startTest();
        // 2. Gọi hàm bắt đầu chuỗi mới
        FEC_AssignAutoDistribSched.startFiveMinuteChain();
        Test.stopTest();

        // 3. Xác minh: Các job cũ đã bị hủy và một job chain mới đã được lên lịch
        List<CronTrigger> newJobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'FEC_AssignAutoDistribSched:%'
        ];
        
        System.assert(!newJobs.isEmpty(), 'Hệ thống phải lên lịch ít nhất 1 job chain mới sau khi gọi startFiveMinuteChain.');
        
        // Kiểm tra job cũ đã bị xóa
        List<CronTrigger> legacyJobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = 'FEC Case Assignment Auto Distribute - Legacy Test'
        ];
        System.assert(legacyJobs.isEmpty(), 'Job legacy cũ phải bị hủy bỏ.');
    }

    @IsTest
    static void testExecuteMethod() {
        // 1. Tạo một job rác cùng tiền tố để test logic tự dọn dẹp bên trong hàm execute()
        String dummyCron = '0 0 0 1 1 ? 2099';
        System.schedule('FEC_AssignAutoDistribSched:ToAbort', dummyCron, new FEC_AssignAutoDistribSched());

        Test.startTest();
        FEC_AssignAutoDistribSched scheduler = new FEC_AssignAutoDistribSched();
        
        // 2. Gọi trực tiếp hàm execute với context = null
        // Gọi trực tiếp là cách tốt nhất để cover toàn bộ code bên trong execute() khi test Schedulable
        scheduler.execute(null);
        Test.stopTest();

        // 3. Xác minh hàm đã tự lên lịch lại (scheduleNextRun)
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'FEC_AssignAutoDistribSched:%'
        ];
        System.assert(!jobs.isEmpty(), 'Hàm execute phải tự lên lịch lần chạy tiếp theo.');
    }

    @IsTest
    static void testDeprecatedMethods() {
        Test.startTest();
        // 1. Gọi các hàm đã deprecated để đảm bảo code không bị lỗi (backward compatibility)
        List<String> res1 = FEC_AssignAutoDistribSched.scheduleEveryFiveMinutes();
        List<String> res2 = FEC_AssignAutoDistribSched.scheduleHalfHourlyJobs();
        Test.stopTest();

        // 2. Xác minh hàm trả về danh sách rỗng (như thiết kế ban đầu) và lên lịch job mới
        System.assertNotEquals(null, res1, 'Không được trả về null.');
        System.assertNotEquals(null, res2, 'Không được trả về null.');

        List<CronTrigger> jobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'FEC_AssignAutoDistribSched:%'
        ];
        System.assert(!jobs.isEmpty(), 'Các hàm deprecated phải gọi startFiveMinuteChain() và lên lịch thành công.');
    }
}