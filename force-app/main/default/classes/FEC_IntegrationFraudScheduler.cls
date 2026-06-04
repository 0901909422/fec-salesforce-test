public class FEC_IntegrationFraudScheduler implements Schedulable {

    
    
    public void execute(SchedulableContext sc) {

        Long startTime = System.currentTimeMillis();

        String triggerId = sc.getTriggerId();
        String jobName = null;
        String cronExpr = null;
        Datetime nextRun = null;
        List<String> ADMIN_RECIPIENTS = FEC_IntegrationFraudService.getAdminRecipients();

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
            // EMAIL SUCCESS
            // ---------------------------------------------------------
            FEC_IntegrationFraudService.sendJobEmail(
                'SUCCESS',
                jobName,
                triggerId,
                cronExpr,
                nextRun,
                importedCount,
                durationText,
                null, // no exception
                ADMIN_RECIPIENTS
            );
            

        } catch (Exception ex) {

            Long endTime = System.currentTimeMillis();
            Long durationMs = endTime - startTime;
            String durationText = (durationMs / 1000) + ' seconds (' + durationMs + ' ms)';

            // ---------------------------------------------------------
            // EMAIL FAILURE
            // ---------------------------------------------------------
            FEC_IntegrationFraudService.sendJobEmail(
                'FAILED',
                jobName,
                triggerId,
                cronExpr,
                null,
                null,
                durationText,
                ex,
                ADMIN_RECIPIENTS
            );
           
        }
    }

    
}