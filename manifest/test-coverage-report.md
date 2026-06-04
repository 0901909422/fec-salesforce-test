# Báo cáo Test Coverage theo Manifest Package

> Ngày tạo: 2026-06-03
> Project: salesforce-new-csm (Unlocked Package: GitLabPipelinesPkg)

## Tổng kết

| Manifest | Status | Coverage |
|----------|--------|----------|
| CSM-8156.xml | ❌ FAIL | 0% |
| CSM-8157.xml | ❌ FAIL | 0% |
| CSM-8158.xml | ✅ PASS | 100% |
| CSM-8169.xml | ✅ PASS | 100% |
| CSM-8170.xml | ⚠️ PARTIAL | 50% |
| CSM-8171.xml | ❌ FAIL | 0% |
| CSM-Fraud.xml | ❌ FAIL | 19% |
| package-batch-job-archival.xml | ✅ PASS | 100% |
| package-chathub.xml | ✅ PASS | 100% |
| package-customer-additional-data.xml | ✅ PASS | 100% |
| package-pdf.xml | ✅ PASS | 100% |
| package-upload-campaign..xml | ⚠️ PARTIAL | 73% |
| genesys-package.xml | ✅ N/A | No Apex |
| master-data-management-package.xml | ✅ PASS | 100% |

---

## Chi tiết các Manifest FAIL/PARTIAL

### CSM-8156.xml ❌ (0%)

| Apex Class | Test? |
|-----------|-------|
| FEC_IntegrationCreateFraudController | ❌ |
| FEC_IntegrationSoapFraudcaseService | ❌ |
| FEC_ServiceFraudTaskCaseController | ❌ |

### CSM-8157.xml ❌ (0%)

| Apex Class | Test? |
|-----------|-------|
| FEC_IntegrationFraudScheduler | ❌ |
| FEC_IntegrationFraudService | ❌ |
| FEC_IntegrationMasterDataController | ❌ |

### CSM-8170.xml ⚠️ (50%)

| Apex Class | Test? |
|-----------|-------|
| FEC_IntegrationFraudCaseDetailController | ✅ |
| FEC_IntegrationFraudCaseUtil | ❌ |

### CSM-8171.xml ❌ (0%)

| Apex Class | Test? |
|-----------|-------|
| FEC_IntegrationFraudCaseApi | ❌ |
| FEC_IntegrationFraudCaseUtil | ❌ |

### CSM-Fraud.xml ❌ (19% — 3/16)

| Apex Class | Test? |
|-----------|-------|
| FEC_IntegrationSoapFraudcaseService | ❌ |
| FEC_IntegrationFraudCaseUtil | ❌ |
| FEC_IntegrationFraudScheduler | ❌ |
| FEC_IntegrationFraudService | ❌ |
| FEC_IntegrationMasterDataController | ❌ |
| FEC_ServiceFraudTaskCaseController | ❌ |
| FEC_IntegrationSearchFraudCaseController | ✅ |
| FEC_IntegrationFraudCaseDetailController | ✅ |
| FEC_IntegrationFraudCaseApi | ❌ |
| FEC_IntegrationCreateFraudController | ❌ |
| FEC_IntegrationMappingController | ✅ |
| FEC_IntegrationLocationService | ❌ |
| FEC_LocationSyncScheduler | ❌ |
| FEC_AutoIntegratingPropertyMappingCtrl | ❌ |
| FEC_MapAPropertiesToMasterDataItemCtrl | ❌ |
| FEC_IntegrationManageFraudCaseCtrl | ❌ |

### package-upload-campaign..xml ⚠️ (73%)

| Apex Class thiếu test | |
|-----------|-------|
| FEC_PushExistingRecordsBatch | ❌ |
| FEC_PushCallbackRecordsBatch | ❌ |
| FEC_CommonUltils | ❌ |
| FEC_EndpointResolver | ❌ |

---

## Manifests ĐẠT (100%)

- **package-batch-job-archival.xml** — 8/8 classes có test
- **package-chathub.xml** — 6/6 classes có test
- **package-customer-additional-data.xml** — 6/6 classes có test
- **package-pdf.xml** — 1/1 class có test
- **master-data-management-package.xml** — đã include test classes trong manifest
- **CSM-8158.xml** — 1/1 class có test
- **CSM-8169.xml** — 1/1 class có test

---

---

## Nested Manifests (subfolders)

### FE-Internal/workbasket-management.xml ✅ PASS (100%)

Classes: CustomLog, DepartmentAdmin, FEC_TeamQueue — tất cả có test.

### FE-Internal/Api-UndeliveredCard/Api-UndeliveredCard.xml ✅ PASS (100%)

FEC_UndeliveredCardRestService → FEC_UndeliveredCardRestService_Test

### FE-Internal/Custom-Sync/CSM-CustomSync.xml ✅ PASS (100%)

8 classes đều covered bởi FEC_CustomSyncAllInOneTest, FEC_CustomSyncValidatorTest, FEC_BatchCustomSyncByIdsTest.

### fec-mdm/mdm-package.xml ⚠️ PARTIAL (~70%)

Classes thiếu test: FEC_LiveDataViewController, FEC_DecisionTableController, FEC_HistoryController, FEC_IntegrationFraudService, FEC_IntegrationFraudCaseUtil, FEC_IntegrationSoapFraudcaseService, FEC_FieldDeployQueueable, FEC_AutoIntegratingPropertyMappingCtrl, FEC_MapAPropertiesToMasterDataItemCtrl, FEC_IntegrationMasterDataController

### fis-uat-1/ (14 packages) ❌ PHẦN LỚN THIẾU TEST

| Package | Apex Classes | Thiếu test |
|---------|-------------|-----------|
| package-interaction.xml | 27 | ~27 |
| package-service-case.xml | 9 | 9 |
| package-search-functional.xml | 6 | 6 |
| package-business-process-migration.xml | 10 | 10 |
| package-cus360-account-info.xml | 28 | 28 |
| package-cus360-customer-info.xml | 13 | 13 |
| package-channel-library.xml | 0 | N/A |
| package-release-uat-1.xml | 27+ | ~27 |

### fis-uat-2/ và fis-uat-3/

Tương tự — sử dụng lại classes từ fis-uat-1 + thêm batch/notification/template classes thiếu test.

---

## Tổng kết đầy đủ

| Folder | Manifests | Pass | Partial | Fail |
|--------|-----------|------|---------|------|
| manifest/ (root) | 15 | 8 | 2 | 4 |
| FE-Internal/ | 3 | 3 | 0 | 0 |
| fec-mdm/ | 1 | 0 | 1 | 0 |
| fis-uat-1/ | 14 | 1 | 0 | 13 |
| fis-uat-2/ | 8 | ~0 | ~2 | ~6 |
| fis-uat-3/ | 8 | ~0 | ~2 | ~6 |

---

## Priority: Classes cần viết test

### Critical (Block package creation)
1. FEC_IntegrationFraudService
2. FEC_IntegrationSoapFraudcaseService
3. FEC_IntegrationFraudCaseApi
4. FEC_IntegrationFraudCaseUtil
5. FEC_IntegrationCreateFraudController
6. FEC_ServiceFraudTaskCaseController
7. FEC_IntegrationFraudScheduler
8. FEC_IntegrationMasterDataController
9. FEC_IntegrationLocationService
10. FEC_IntegrationManageFraudCaseCtrl

### High (Core functionality — fis-uat packages)
11. FEC_CaseService
12. FEC_CaseTriggerHandler
13. FEC_CaseBusinessService
14. FEC_SearchController
15. FEC_InteractionController
16. FEC_InteractionHighlightController
17. FEC_KYCController / FEC_KYCService / FEC_KYCResultService
18. FEC_CreateCaseInteractionController
19. FEC_CreateInteractionGenesys
20. FEC_FollowUpController

### Medium (Cus360/Account)
21. FEC_CardInfoController
22. FEC_CardPaymentController
23. FEC_EmeaAccountInqService
24. FEC_MainInfoController / FEC_MainInfoAccountController
25. FEC_SecondaryController
26. FEC_TransactionsController
27. FEC_PaymentHistoryController
28. FEC_ApplicationsListController
29. FEC_CaseRemarkController
30. FEC_CaseEditNOCController

> Unlocked Package yêu cầu minimum 75% code coverage.
> Hiện tại ước tính coverage ~25-30%. Cần viết ít nhất 150+ test classes để đạt 75%.


---

# Phân tích Dependency giữa các Manifest Packages

## Shared Classes (xuất hiện trong nhiều manifests)

| Class | Số manifests | Vai trò |
|-------|-------------|---------|
| FEC_ConstantCommon | 12+ | Constants, enum values |
| FEC_CommonUltils | 8+ | Utility functions |
| FEC_MockupEndpoint | 6+ | Mock endpoint |
| FEC_Constants | 4 | Global constants |
| FEC_Util | 4 | Utility |
| FEC_CaseService | 4 | Core case logic |
| FEC_CaseTriggerHandler | 4 | Case trigger |

## Dependency Graph (Deploy Order)

```
Layer 0 - Foundation (PHẢI deploy trước)
├── FEC_ConstantCommon, FEC_Constants, FEC_FieldConstants
├── FEC_CommonUltils, FEC_Util, FEC_MockupEndpoint
└── FEC_FraudConstantCommon

Layer 1 - Core Services
├── FEC_CaseService ← Layer 0
├── FEC_CaseTriggerHandler ← FEC_CaseService
├── FEC_BusinessProcessService ← Layer 0
├── FEC_EmeaAccountInqService ← Layer 0
└── FEC_KYCService ← Layer 0

Layer 2 - Controllers
├── FEC_SearchController ← Layer 1
├── FEC_InteractionController ← Layer 1
├── FEC_CaseBusinessService ← Layer 1
├── FEC_CardInfoController ← Layer 1
└── FEC_IntegrationFraudService ← Layer 0

Layer 3 - Features
├── Fraud (CSM-8156~8171, CSM-Fraud)
├── Archival, Chathub, Campaign, PDF
└── Custom Sync, Workbasket
```

## Thứ tự Deploy an toàn

| Phase | Manifest | Lý do |
|-------|----------|-------|
| 1 | master-data-management-package.xml | Objects + Constants |
| 2 | fis-uat-1/package-channel-library.xml | Object layouts |
| 3 | fis-uat-1/package-interaction.xml | Core interaction |
| 4 | fis-uat-1/package-service-case.xml | Service case |
| 5 | fis-uat-1/package-search-functional.xml | Search |
| 6 | fis-uat-1/package-business-process-migration.xml | Business process |
| 7 | fis-uat-1/package-cus360-customer-info.xml | Customer 360 |
| 8 | fis-uat-1/package-cus360-account-info.xml | Account 360 |
| 9 | package-batch-job-archival.xml | Archival |
| 10 | package-chathub.xml | Chat |
| 11 | package-customer-additional-data.xml | Customer data |
| 12 | package-upload-campaign..xml | Campaign |
| 13 | package-pdf.xml | PDF |
| 14 | FE-Internal/* | Internal tools |
| 15 | CSM-Fraud.xml | Fraud (last - most deps) |
| 16 | fec-mdm/mdm-package.xml | Full MDM (SIT only) |

## Rủi ro Go-Live

| Rủi ro | Mitigation |
|--------|-----------|
| Deploy sai thứ tự → class not found | Theo phases ở trên |
| CustomObject field thiếu | Gộp fields vào manifest base |
| Trigger conflict (Case) | Trigger chỉ ở 1 manifest |
| Duplicate members trong XML | Fix trước khi deploy |
| Test coverage < 75% | Viết test trước go-live |

## Đề xuất: Chuyển sang Unlocked Package

Thay vì 49 manifest riêng lẻ → 1 Unlocked Package (`GitLabPipelinesPkg`):
- Mỗi release = 1 package version
- SF tự xử lý dependency order trong package
- Chỉ cần đảm bảo 75% test coverage
- Không cần lo thứ tự deploy
