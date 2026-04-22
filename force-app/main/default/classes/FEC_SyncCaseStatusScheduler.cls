public without sharing class FEC_SyncCaseStatusScheduler implements Schedulable {

    public static final String DAILY_MIDNIGHT_CRON = '0 0 0 * * ?';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_SyncCaseStatusBatch(), 200);
    }

    public static String scheduleDailyMidnightJob() {
        return System.schedule(
            'FEC Sync Case Status Daily 00:00',
            DAILY_MIDNIGHT_CRON,
            new FEC_SyncCaseStatusScheduler()
        );
    }
}