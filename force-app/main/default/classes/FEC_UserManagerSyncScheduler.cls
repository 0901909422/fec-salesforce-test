/**
 * Schedulable: chạy FEC_UserManagerSyncBatch mỗi ngày lúc 00:00 (giờ org).
 *
 * Sau deploy, chạy một lần (Anonymous Apex):
 *   FEC_UserManagerSyncScheduler.scheduleDailyJob();
 */
public without sharing class FEC_UserManagerSyncScheduler implements Schedulable {

  public static final String DAILY_MIDNIGHT_CRON = '0 0 0 * * ?';
  private static final String JOB_NAME = 'FEC User Manager Sync Daily 00:00';

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new FEC_UserManagerSyncBatch(), 200);
  }

  public static String scheduleDailyJob() {
    abortExistingScheduledJobs();
    return System.schedule(JOB_NAME, DAILY_MIDNIGHT_CRON, new FEC_UserManagerSyncScheduler());
  }

  private static void abortExistingScheduledJobs() {
    for (CronTrigger ct : [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'FEC User Manager Sync Daily%'
    ]) {
      System.abortJob(ct.Id);
    }
  }
}
