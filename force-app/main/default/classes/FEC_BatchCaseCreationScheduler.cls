/**
 * Schedules daily processing of uploaded batch case creation files (00:00 org time).
 */
public without sharing class FEC_BatchCaseCreationScheduler implements Schedulable {
  public static final String DAILY_SCHEDULE_CRON = '0 0 0 * * ?';
  private static final String JOB_NAME = 'FEC Batch Case Creation Daily 00:00';

  public void execute(SchedulableContext context) {
    FEC_BatchCaseCreationController.processAllPendingImports();
  } 

  /** Legacy: batch job (cần class trong permission set). Ưu tiên processAllPendingImports. */
  public static Id runProcessBatchNow() {
    return Database.executeBatch(new FEC_BatchCaseCreationProcessBatch(), 1);
  }

  /**
   * Đăng ký job 00:00 hàng ngày. Gọi một lần sau deploy (Setup → Scheduled Jobs không tự cập nhật từ code).
   * Hủy các job cùng prefix trước khi schedule lại.
   */
  public static String scheduleDailyJob() {
    abortExistingScheduledJobs();
    return System.schedule(JOB_NAME, DAILY_SCHEDULE_CRON, new FEC_BatchCaseCreationScheduler());
  }

  private static void abortExistingScheduledJobs() {
    for (CronTrigger ct : [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'FEC Batch Case Creation Daily%'
    ]) {
      System.abortJob(ct.Id);
    }
  }
}
