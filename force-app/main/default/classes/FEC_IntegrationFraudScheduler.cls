public class FEC_IntegrationFraudScheduler implements Schedulable {

    private static final List<String> ADMIN_RECIPIENTS =
        new List<String>{ 'vu.nguyen.35@fecredit.com.vn' };

    public void execute(SchedulableContext sc) {

        Long startTime = System.currentTimeMillis();

        String triggerId = sc.getTriggerId();
        String jobName = null;
        String cronExpr = null;
        Datetime nextRun = null;

        Integer importedCount = 0;

        try {
            CronTrigger ct = [
                SELECT Id, CronExpression, NextFireTime, CronJobDetail.Name
                FROM CronTrigger
                WHERE Id = :triggerId
                LIMIT 1
            ];

            jobName = ct.CronJobDetail.Name;
            cronExpr = ct.CronExpression;
            nextRun = ct.NextFireTime;

            // ---------------------------------------------------------
            // RUN IMPORT
            // ---------------------------------------------------------
            importedCount = FEC_IntegrationFraudService.syncMasterDataIntegration();

            Long endTime = System.currentTimeMillis();
            Long durationMs = endTime - startTime;
            String durationText = (durationMs / 1000) + ' seconds (' + durationMs + ' ms)';

            // ---------------------------------------------------------
            // LOG SUCCESS
            // // ---------------------------------------------------------
            // FEC_IntegrationLogService.logSuccess(
            //     jobName,
            //     triggerId,
            //     cronExpr,
            //     nextRun,
            //     importedCount,
            //     durationMs,
            //     durationText,
            //     'Master Data sync completed successfully.'
            // );

            // ---------------------------------------------------------
            // EMAIL SUCCESS
            // ---------------------------------------------------------
            String subject = 'Master Data Sync SUCCESS - ' + jobName;
            String body =
                'Job Name: ' + jobName + '\n' +
                'Trigger ID: ' + triggerId + '\n' +
                'Cron: ' + cronExpr + '\n' +
                'Next Run: ' + nextRun + '\n\n' +
                'Result: SUCCESS\n' +
                'Imported Records: ' + importedCount + '\n' +
                'Duration: ' + durationText + '\n';

            sendEmail(subject, body, ADMIN_RECIPIENTS);

        } catch (Exception ex) {

            Long endTime = System.currentTimeMillis();
            Long durationMs = endTime - startTime;
            String durationText = (durationMs / 1000) + ' seconds (' + durationMs + ' ms)';

            // // ---------------------------------------------------------
            // // LOG FAILURE
            // // ---------------------------------------------------------
            // FEC_IntegrationLogService.logFailure(
            //     jobName,
            //     triggerId,
            //     cronExpr,
            //     durationMs,
            //     durationText,
            //     ex
            // );

            // ---------------------------------------------------------
            // EMAIL FAILURE
            // ---------------------------------------------------------
            String subject = 'Master Data Sync FAILED - ' + jobName;
            String body =
                'Job Name: ' + jobName + '\n' +
                'Trigger ID: ' + triggerId + '\n' +
                'Cron: ' + cronExpr + '\n\n' +
                'ERROR: ' + ex.getMessage() + '\n' +
                'Duration: ' + durationText + '\n\n' +
                ex.getStackTraceString();

            sendEmail(subject, body, ADMIN_RECIPIENTS);
        }
    }

    private static void sendEmail(String subject, String body, List<String> toAddresses) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject(subject);
            email.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Email send failed: ' + e.getMessage());
        }
    }
}