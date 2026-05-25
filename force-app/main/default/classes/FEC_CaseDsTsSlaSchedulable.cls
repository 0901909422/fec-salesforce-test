/**
 * Schedulable: chạy FEC_CaseDsTsSlaBatch mỗi 15 phút.
 * Salesforce cron chỉ cho phép một số nguyên ở phút/giây — đăng ký 4 job (:00, :15, :30, :45).
 */
public without sharing class FEC_CaseDsTsSlaSchedulable implements Schedulable {

    public static final String JOB_NAME_PREFIX = 'FEC Case DS/TS SLA Every 15m';

    /** @deprecated Dùng JOB_NAME_PREFIX; giữ để tương thích abort tên job cũ. */
    public static final String JOB_NAME = JOB_NAME_PREFIX;

    private static final List<Integer> RUN_MINUTES = new List<Integer>{ 0, 15, 30, 45 };

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_CaseDsTsSlaBatch(), 200);
    }

    public static List<String> scheduleEvery15Minutes() {
        abortAllJobs();
        List<String> jobIds = new List<String>();
        for (Integer minute : RUN_MINUTES) {
            String jobName = buildJobName(minute);
            String cron = '0 ' + String.valueOf(minute) + ' * * * ?';
            jobIds.add(System.schedule(jobName, cron, new FEC_CaseDsTsSlaSchedulable()));
        }
        return jobIds;
    }

    public static void ensureScheduled() {
        if (Test.isRunningTest()) {
            return;
        }
        String nameLike = JOB_NAME_PREFIX + '%';
        List<CronTrigger> existing = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :nameLike
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            scheduleEvery15Minutes();
        }
    }

    public static void abortExistingByName(String jobName) {
        abortAllJobs();
    }

    public static void abortAllJobs() {
        String nameLike = JOB_NAME_PREFIX + '%';
        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
               OR CronJobDetail.Name LIKE :nameLike
        ]) {
            System.abortJob(ct.Id);
        }
    }

    private static String buildJobName(Integer minute) {
        String mm = minute < 10 ? '0' + String.valueOf(minute) : String.valueOf(minute);
        return JOB_NAME_PREFIX + ' :' + mm;
    }
}
