/**
 * Cổng tích hợp Auto Hold Case — delegate xuống SOAP Mark NFU (FEC_MarkNFU).
 */
public inherited sharing class FEC_AutoHoldCaseApi {
    /** Trùng tên config Custom Metadata (FEC_MarkNFU.API_CONFIG_NAME). */
    public static final String MARK_NFU_API_CONFIG_NAME = FEC_MarkNFU.API_CONFIG_NAME;

    /**
     * Có khả năng gọi Mark NFU khi org có bản ghi Custom Metadata api (FEC_API_Config cho Mark NFU).
     */
    public static Boolean isIntegrationEnabled() {
        return FEC_API_Config__mdt.getInstance(MARK_NFU_API_CONFIG_NAME) != null;
    }

    /**
     * Mark NFU — gọi thống nhất qua lớp này để auto-hold và tích hợp sau này không phụ thuộc trực tiếp implementation.
     */
    public static FEC_MarkNFU.MarkNFUResult markNFU(FEC_MarkNFU.MarkNFURequest req) {
        return FEC_MarkNFU.markNFU(req);
    }
}
