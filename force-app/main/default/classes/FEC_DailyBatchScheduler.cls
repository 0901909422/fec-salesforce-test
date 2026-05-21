/**
 * FEC_DailyBatchScheduler
 * ─────────────────────────────────────────────────────────────────────────────
 * Schedulable class điều phối 3 batch jobs chạy hàng ngày:
 *   - 1:00 AM → FEC_ArchiveVerifyBatch (batch size 100)
 *   - 2:00 AM → FEC_CaseExportBatch    (batch size 100)
 *   - 3:00 AM → FEC_AttachmentExportBatch (batch size 1)
 *
 * Sử dụng:
 *   FEC_DailyBatchScheduler.scheduleAll();   // Đăng ký tất cả jobs
 *   FEC_DailyBatchScheduler.unscheduleAll(); // Hủy tất cả jobs
 * ─────────────────────────────────────────────────────────────────────────────
 */
public class FEC_DailyBatchScheduler implements Schedulable {

    // ── Constants ────────────────────────────────────────────────────────────
    public static final String JOB_PREFIX = 'FEC_Daily_';
    public static final String JOB_NAME_ARCHIVE_VERIFY    = JOB_PREFIX + 'ArchiveVerify';
    public static final String JOB_NAME_CASE_EXPORT       = JOB_PREFIX + 'CaseExport';
    public static final String JOB_NAME_ATTACHMENT_EXPORT = JOB_PREFIX + 'AttachmentExport';

    public static final String CRON_1AM = '0 0 1 * * ?';
    public static final String CRON_2AM = '0 0 2 * * ?';
    public static final String CRON_3AM = '0 0 3 * * ?';

    @TestVisible
    private static final Set<String> RUNNING_STATUSES = new Set<String>{
        'Holding', 'Queued', 'Preparing', 'Processing'
    };

    // ── Cho phép inject hour trong test ──────────────────────────────────────
    @TestVisible
    private static Integer testHourOverride = null;

    // ── Schedulable interface ────────────────────────────────────────────────
    public void execute(SchedulableContext sc) {
        Integer currentHour = getHour();

        try {
            if (currentHour == 1) {
                executeBatchIfNotRunning('FEC_ArchiveVerifyBatch',
                    new FEC_ArchiveVerifyBatch(),
                    FEC_ArchiveVerifyBatch.DEFAULT_BATCH_SIZE);
            } else if (currentHour == 2) {
                executeBatchIfNotRunning('FEC_CaseExportBatch',
                    new FEC_CaseExportBatch(),
                    FEC_CaseExportBatch.DEFAULT_BATCH_SIZE);
            } else if (currentHour == 3) {
                executeBatchIfNotRunning('FEC_AttachmentExportBatch',
                    new FEC_AttachmentExportBatch(), 1);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                '[FEC_DailyBatchScheduler] Unexpected error: ' + ex.getMessage());
        }
    }

    // ── Static utility methods ───────────────────────────────────────────────
    public static void scheduleAll() {
        unscheduleAll();
        System.schedule(JOB_NAME_ARCHIVE_VERIFY, CRON_1AM, new FEC_DailyBatchScheduler());
        System.schedule(JOB_NAME_CASE_EXPORT, CRON_2AM, new FEC_DailyBatchScheduler());
        System.schedule(JOB_NAME_ATTACHMENT_EXPORT, CRON_3AM, new FEC_DailyBatchScheduler());
    }

    public static void unscheduleAll() {
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :JOB_PREFIX + '%'
        ];
        for (CronTrigger job : jobs) {
            System.abortJob(job.Id);
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────
    private void executeBatchIfNotRunning(String batchClassName,
                                          Database.Batchable<SObject> batchInstance,
                                          Integer batchSize) {
        if (isBatchRunning(batchClassName)) {
            System.debug(LoggingLevel.WARN,
                '[FEC_DailyBatchScheduler] ' + batchClassName
                + ' is still running, skipping execution.');
            return;
        }
        Database.executeBatch(batchInstance, batchSize);
        System.debug('[FEC_DailyBatchScheduler] Started ' + batchClassName
            + ' with batch size ' + batchSize);
    }

    @TestVisible
    private static Boolean isBatchRunning(String batchClassName) {
        List<AsyncApexJob> runningJobs = [
            SELECT Id FROM AsyncApexJob
            WHERE ApexClass.Name = :batchClassName
            AND Status IN :RUNNING_STATUSES
            LIMIT 1
        ];
        return !runningJobs.isEmpty();
    }

    @TestVisible
    private static Integer getHour() {
        if (testHourOverride != null) {
            return testHourOverride;
        }
        return Datetime.now().hour();
    }
}
