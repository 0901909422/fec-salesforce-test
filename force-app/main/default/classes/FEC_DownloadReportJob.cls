public class FEC_DownloadReportJob implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        FEC_DownloadReportService.generateDailyReports();
    }
}