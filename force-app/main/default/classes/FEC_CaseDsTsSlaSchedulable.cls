/**
 * Schedulable: chạy FEC_CaseDsTsSlaBatch mỗi 15 phút.
 * Một job tự schedule lần chạy kế tiếp (now + 15 phút) — không cần 4 Cron (:00, :15, :30, :45).
 *
 * Sau deploy, chạy một lần (Anonymous):
 *   FEC_CaseDsTsSlaSchedulable.startFifteenMinuteChain();
 */
public without sharing class FEC_CaseDsTsSlaSchedulable implements Schedulable {

    public static final String JOB_NAME_PREFIX = 'FEC Case DS/TS SLA Every 15m';

    /** @deprecated Dùng JOB_NAME_PREFIX; giữ để abort tên job cũ. */
    public static final String JOB_NAME = JOB_NAME_PREFIX;

    private static final Integer INTERVAL_MINUTES = 15;

    public void execute(SchedulableContext context) {
        Database.executeBatch(new FEC_CaseDsTsSlaBatch(), 200);

        Id selfCronTriggerId = context != null ? context.getTriggerId() : null;
        String chainLike = JOB_NAME_PREFIX + ':%';
        for (CronTrigger cronJob : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :chainLike
        ]) {
            if (selfCronTriggerId != null && cronJob.Id == selfCronTriggerId) {
                continue;
            }
            System.abortJob(cronJob.Id);
        }

        scheduleNextRun();
    }

    /** Khởi chạy chuỗi 15 phút: hủy job cũ (4 cron / chain lỗi), đăng ký lần chạy kế tiếp. */
    public static void startFifteenMinuteChain() {
        abortAllJobs();
        scheduleNextRun();
    }

    /**
     * Lên lịch một lần tại now + 15 phút; tên job unique (prefix:timestamp).
     */
    public static void scheduleNextRun() {
        if (Test.isRunningTest()) {
            return;
        }
        DateTime nextRun = System.now().addMinutes(INTERVAL_MINUTES);
        String uniqueName =
            JOB_NAME_PREFIX +
            ':' +
            String.valueOf(nextRun.getTime());
        String cronExpression = String.format(
            '{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(nextRun.second()),
                String.valueOf(nextRun.minute()),
                String.valueOf(nextRun.hour()),
                String.valueOf(nextRun.day()),
                String.valueOf(nextRun.month()),
                String.valueOf(nextRun.year())
            }
        );
        System.schedule(uniqueName, cronExpression, new FEC_CaseDsTsSlaSchedulable());
    }

    public static void ensureScheduled() {
        if (Test.isRunningTest()) {
            return;
        }
        String chainLike = JOB_NAME_PREFIX + ':%';
        List<CronTrigger> existing = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :chainLike
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            startFifteenMinuteChain();
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

    /**
     * @deprecated Dùng startFifteenMinuteChain().
     */
    public static List<String> scheduleEvery15Minutes() {
        startFifteenMinuteChain();
        return new List<String>();
    }
}
