/****************************************************************************************
 * File Name    : FEC_SaleInfoQueueable
 * Author       : Quangdv7
 * Date         : 2026-06-12
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-06-12     Quangdv7             Create
 
****************************************************************************************/
public class FEC_SaleInfoQueueable implements Queueable, Database.AllowsCallouts {

    private Id cacheId;
    private List<String> applicationIds;

    public FEC_SaleInfoQueueable(Id cacheId, List<String> applicationIds) {
        this.cacheId = cacheId;
        this.applicationIds = applicationIds;
    }

    public void execute(QueueableContext context) {

        Map<String, Object> saleMap = new Map<String, Object>();

        for (String appId : applicationIds) {
            try {
                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse res =
                    FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(appId);

                if (res != null && res.CustomerSaleInfos != null && !res.CustomerSaleInfos.isEmpty()) {
                    saleMap.put(appId, res.CustomerSaleInfos[0]);
                }

            } catch (Exception e) {
                System.debug('Queueable SaleInfo failed: ' + e.getMessage());
            }
        }

        if (Test.isRunningTest()) {
            new FEC_SaleInfoUpdateQueueable(cacheId, JSON.serialize(saleMap)).execute(null);
        } else {
            System.enqueueJob(new FEC_SaleInfoUpdateQueueable(cacheId, JSON.serialize(saleMap)));
        }
    }
}