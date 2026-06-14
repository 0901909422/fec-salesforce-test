/****************************************************************************************
 * File Name    : FEC_SaleInfoUpdateQueueable
 * Author       : Quangdv7
 * Date         : 2026-06-12
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-06-12     Quangdv7             Create
 
****************************************************************************************/

public class FEC_SaleInfoUpdateQueueable implements Queueable {

    private Id cacheId;
    private String saleMapJson;

    public FEC_SaleInfoUpdateQueueable(Id cacheId, String saleMapJson) {
        this.cacheId = cacheId;
        this.saleMapJson = saleMapJson;
    }

    public void execute(QueueableContext context) {

        Map<String, Object> rawSaleMap =
            (Map<String, Object>) JSON.deserializeUntyped(saleMapJson);

        FEC_Application_List__c rec = [
            SELECT Id, FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :cacheId
            LIMIT 1
        ];

        if (String.isBlank(rec.FEC_API_Cache_Applications__c)) return;

        List<Object> rawList =
            (List<Object>) JSON.deserializeUntyped(rec.FEC_API_Cache_Applications__c);

        for (Object obj : rawList) {
            Map<String, Object> row = (Map<String, Object>) obj;

            String appId = (String) row.get('applicationId');

            if (rawSaleMap.containsKey(appId)) {
                Map<String, Object> sale =
                    (Map<String, Object>) rawSaleMap.get(appId);

                row.put('ccCode', sale.get('CC_CODE'));
                row.put('ccName', sale.get('CC_NAME'));
                row.put('dSACode', sale.get('DSA_CODE'));
                row.put('dSAName', sale.get('DSA_NAME'));
                row.put('tSACode', sale.get('TSA_CODE'));
                row.put('tSAName', sale.get('TSA_NAME'));
            }
        }

        rec.FEC_API_Cache_Applications__c = JSON.serialize(rawList);
        update rec;
    }
}