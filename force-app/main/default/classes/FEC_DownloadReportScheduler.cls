/****************************************************************************************
* File Name    : FEC_DownloadReportScheduler
* Author       : Quangdv7
* Date         : 2026-05-20
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-05-20    Quangdv7             Create
 
****************************************************************************************/
public class FEC_DownloadReportScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        System.enqueueJob(new FEC_DownloadReportJob());
    }
}