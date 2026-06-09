/****************************************************************************************
* File Name    : FEC_DownloadReportJob
* Author       : Quangdv7
* Date         : 2026-05-20
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-05-20    Quangdv7             Create
 
****************************************************************************************/

public class FEC_DownloadReportJob implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        FEC_DownloadReportService.generateDailyReports();
    }
}