// Scheduled Apex gọi FEC_CaseAssignmentAutoDistributeService.executeNow().
//
// Mỗi lần chạy service soát toàn bộ FEC_Case_Assignment__c Active và chỉ phân bổ khi isDueToRun
// (Continuous: FEC_Scheduled_Time__c khớp “bội phút trong ngày”; Time-Based: khớp FEC_Time_Slots__c HH:mm).
//
// Hạn chế cron Salesforce: không dùng được liệt kê phút (0,5,10,...) hoặc */5 trong một số biểu thức —
// đăng ký 12 Scheduled Job (mỗi phút lệch 5: :00,:05,…,:55) tương đương quét 5 phút một lần.
//
// Sau deploy (chọn một):
//   FEC_AssignAutoDistribSched.scheduleEveryFiveMinutes();  // 12 job
// hoặc (legacy — 2 job mỗi :00 và :30):
//   FEC_AssignAutoDistribSched.scheduleHalfHourlyJobs();
//
public without sharing class FEC_AssignAutoDistribSched implements Schedulable {
    public static final String CRON_HOURLY_AT_MIN_0 = '0 0 * * * ?';

    public static final String CRON_HOURLY_AT_MIN_30 = '0 30 * * * ?';

    public static final String JOB_NAME_MIN0 = 'FEC Case Assignment Auto Distribute :00';

    public static final String JOB_NAME_MIN30 = 'FEC Case Assignment Auto Distribute :30';

    public static final String JOB_NAME_EVERY_FIVE_PREFIX = 'FEC Case Assignment Auto Distribute 5m :';

    public void execute(SchedulableContext sc) {
        FEC_CaseAssignmentAutoDistributeService.executeNow();
    }

    /**
     * Đăng ký 12 job (một phút mỗi 5 phút trong giờ).
     * Trùng tên: Setup → Scheduled Jobs → Abort các job cũ cùng prefix rồi gọi lại.
     *
     * @return Id CronTrigger của 12 job đã schedule
     */
    public static List<String> scheduleEveryFiveMinutes() {
        List<String> jobIds = new List<String>();
        for (Integer minuteVal = 0; minuteVal < 60; minuteVal += 5) {
            String mm = minuteVal < 10 ? '0' + String.valueOf(minuteVal) : String.valueOf(minuteVal);
            String cron = '0 ' + String.valueOf(minuteVal) + ' * * * ?';
            jobIds.add(System.schedule(JOB_NAME_EVERY_FIVE_PREFIX + mm, cron, new FEC_AssignAutoDistribSched()));
        }
        return jobIds;
    }

    /** Đăng ký 2 job. Trùng tên: Scheduled Jobs → Abort rồi chạy lại. */
    public static List<String> scheduleHalfHourlyJobs() {
        return new List<String>{
            System.schedule(JOB_NAME_MIN0, CRON_HOURLY_AT_MIN_0, new FEC_AssignAutoDistribSched()),
            System.schedule(JOB_NAME_MIN30, CRON_HOURLY_AT_MIN_30, new FEC_AssignAutoDistribSched())
        };
    }
}
