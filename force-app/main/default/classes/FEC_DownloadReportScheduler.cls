public class FEC_DownloadReportScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        System.enqueueJob(new FEC_DownloadReportJob());
    }
}