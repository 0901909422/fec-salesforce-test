/**
 * Schedules nightly processing of uploaded batch case creation files (00:00 org time).
 */
public without sharing class FEC_BatchCaseCreationScheduler implements Schedulable {
  public static final String DAILY_MIDNIGHT_CRON = '0 0 0 * * ?';
  private static final String JOB_NAME = 'FEC Batch Case Creation Daily 00:00';

  public void execute(SchedulableContext context) {
    Database.executeBatch(new FEC_BatchCaseCreationProcessBatch(), 1);
  }

  public static String scheduleDailyMidnightJob() {
    return System.schedule(JOB_NAME, DAILY_MIDNIGHT_CRON, new FEC_BatchCaseCreationScheduler());
  }
}
