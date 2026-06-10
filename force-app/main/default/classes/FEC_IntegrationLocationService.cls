public class FEC_IntegrationLocationService {

    public static final Boolean DEBUG_LOG = true;
    // Named Credential endpoint for ODI OData service
    private static final String ENDPOINT =
        'callout:ODI_OData/LocationHierarchy';
    public static Boolean useMock = false;

    /* ================= RESPONSE DTO ================= */

    public class LocationResponseDTO {
        public List<LocationDTO> location;
    }

    public class LocationDTO {
        public String countryCode;
        public String countryNameVn;
        public String countryNameEn;
        public Boolean isActive;
        public String effectiveDate;
        public List<ProvinceDTO> province;
    }

    public class ProvinceDTO {
        public String provinceCode;
        public String provinceNameVn;
        public String provinceNameEn;
        public Boolean isActive;
        public String effectiveDate;
        public String parentCode; // countryCode
        public List<DistrictDTO> district;
    }

    public class DistrictDTO {
        public String districtCode;
        public String districtNameVn;
        public String districtNameEn;
        public Boolean isActive;
        public String effectiveDate;
        public String parentCode; // provinceCode
        public List<WardDTO> ward; // optional
    }

    public class WardDTO {
        public String wardCode;
        public String wardNameVn;
        public String wardNameEn;
        public String effectiveDate;
        public Boolean isActive;
        public String parentCode; // districtCode
    }
    
    /* ================= FLATTENED ROW ================= */
    public class LocationRow {
        public String COUNTRY_CODE;
        public String COUNTRY_NAME_EN;
        public String COUNTRY_NAME_VN;
        public Date COUNTRY_EFFECTIVE_DATE;
        public Boolean COUNTRY_ISACTIVE;

        public String PROVINCE_CODE;
        public String PROVINCE_NAME_EN;
        public String PROVINCE_NAME_VN;
        public Date PROVINCE_EFFECTIVE_DATE;
        public Boolean PROVINCE_ISACTIVE;
        public String PROVINCE_PARENT_CODE;

        public String DISTRICT_CODE;
        public String DISTRICT_NAME_EN;
        public String DISTRICT_NAME_VN;
        public Date DISTRICT_EFFECTIVE_DATE;
        public Boolean DISTRICT_ISACTIVE;
        public String DISTRICT_PARENT_CODE;

        public String WARD_CODE;
        public String WARD_NAME_EN;
        public String WARD_NAME_VN;
        public Date WARD_EFFECTIVE_DATE;
        public Boolean WARD_ISACTIVE;
        public String WARD_PARENT_CODE;
    }

   
    
    
    
         

    /**
     * Entry point method.
     *
     * - Calls ODI OData service
     * - Deserializes JSON response
     * - Delegates persistence logic to upsertSyncLocation()
     */
    @AuraEnabled
    public static void syncLocation() {
        log('[syncLocation] START');
        List<Map<String, Object>> records;

        if (useMock) {
            log('[syncLocation] Using mock data');
            records = FEC_FraudCaseMockData.getCifFeDictLocationVw();
            log('[syncLocation] Mock records loaded: ' + records.size());
        } else {
            log('[syncLocation] Using external object CifFeDictLocationVw__x');
            records = new List<Map<String, Object>>();

            // External objects limit OFFSET to 2000 globally.
            // For schemes with >2000 records (Ward, City District), use parent-based pagination.
            List<String> smallSchemes = new List<String>{FEC_FraudConstantCommon.LOCATION_SCHEME_COUNTRY, FEC_FraudConstantCommon.LOCATION_SCHEME_PROVINCE};
            List<String> largeSchemes = new List<String>{FEC_FraudConstantCommon.LOCATION_SCHEME_CITY_DISTRICT, FEC_FraudConstantCommon.LOCATION_SCHEME_WARD};
            Integer pageSize = FEC_FraudConstantCommon.LOCATION_PAGE_SIZE;
            Integer offsetCap = FEC_FraudConstantCommon.LOCATION_OFFSET;

            // Small schemes (Country, Province) - standard offset pagination
            for (String scheme : smallSchemes) {
                Integer offset = 0;
                Boolean hasMore = true;

                while (hasMore) {
                    log('[syncLocation] SCHEME=' + scheme + ' offset=' + offset);
                    String soql = 'SELECT ExternalId, CODE__c, NAME__c, NAME_EN__c, '
                                + 'PARENTCODE__c, ISACTIVE__c, SCHEME__c, EFFECTIVEDATE__c '
                                + 'FROM CifFeDictLocationVw__x '
                                + 'WHERE SCHEME__c = :scheme '
                                + 'LIMIT ' + pageSize + ' OFFSET ' + offset;
                    List<CifFeDictLocationVw__x> batch = Database.query(soql);
                    log('[syncLocation] SCHEME=' + scheme + ' returned ' + batch.size() + ' records');

                    for (CifFeDictLocationVw__x loc : batch) {
                        records.add(new Map<String, Object>{
                            'ExternalId' => loc.ExternalId,
                            'CODE__c' => loc.CODE__c,
                            'NAME__c' => loc.NAME__c,
                            'NAME_EN__c' => loc.NAME_EN__c,
                            'PARENTCODE__c' => loc.PARENTCODE__c,
                            'ISACTIVE__c' => loc.ISACTIVE__c,
                            'SCHEME__c' => loc.SCHEME__c,
                            'EFFECTIVEDATE__c' => loc.EFFECTIVEDATE__c
                        });
                    }

                    if (batch.size() < pageSize) {
                        hasMore = false;
                    } else {
                        offset += pageSize;
                        if (offset >= offsetCap) {
                            hasMore = false;
                        }
                    }
                }
            }

            // Large schemes (City District, Ward) - paginate by PARENTCODE batches to bypass OFFSET limit
            // Each batch uses IN clause with subset of parent codes, each query stays under OFFSET 2000
            Set<String> provinceCodes = new Set<String>();
            Set<String> districtCodes = new Set<String>();
            for (Map<String, Object> rec : records) {
                String recScheme = (String) rec.get('SCHEME__c');
                String code = (String) rec.get('CODE__c');
                if (recScheme == FEC_FraudConstantCommon.LOCATION_SCHEME_PROVINCE && String.isNotBlank(code)) {
                    provinceCodes.add(code);
                }
            }

            // Load City Districts - batch by province parent codes (each province has ~40 districts)
            log('[syncLocation] Loading City District by ' + provinceCodes.size() + ' province parents');
            String districtScheme = FEC_FraudConstantCommon.LOCATION_SCHEME_CITY_DISTRICT;
            List<String> provinceList = new List<String>(provinceCodes);
            Integer batchSize = 20; // ~20 provinces per query → ~800 districts per query (safe under 2000)

            for (Integer i = 0; i < provinceList.size(); i += batchSize) {
                Integer endIdx = Math.min(i + batchSize, provinceList.size());
                List<String> parentBatch = new List<String>();
                for (Integer j = i; j < endIdx; j++) {
                    parentBatch.add(provinceList[j]);
                }

                Integer offset = 0;
                Boolean hasMore = true;
                while (hasMore) {
                    List<CifFeDictLocationVw__x> batch = [
                        SELECT ExternalId, CODE__c, NAME__c, NAME_EN__c,
                               PARENTCODE__c, ISACTIVE__c, SCHEME__c, EFFECTIVEDATE__c
                        FROM CifFeDictLocationVw__x
                        WHERE SCHEME__c = :districtScheme
                          AND PARENTCODE__c IN :parentBatch
                        LIMIT :pageSize OFFSET :offset
                    ];
                    for (CifFeDictLocationVw__x loc : batch) {
                        records.add(new Map<String, Object>{
                            'ExternalId' => loc.ExternalId,
                            'CODE__c' => loc.CODE__c,
                            'NAME__c' => loc.NAME__c,
                            'NAME_EN__c' => loc.NAME_EN__c,
                            'PARENTCODE__c' => loc.PARENTCODE__c,
                            'ISACTIVE__c' => loc.ISACTIVE__c,
                            'SCHEME__c' => loc.SCHEME__c,
                            'EFFECTIVEDATE__c' => loc.EFFECTIVEDATE__c
                        });
                        districtCodes.add(loc.CODE__c);
                    }
                    hasMore = (batch.size() == pageSize && offset + pageSize < offsetCap);
                    offset += pageSize;
                }
            }
            log('[syncLocation] City District total loaded: ' + districtCodes.size());

            // Load Wards - batch by district parent codes (each district has ~3 wards)
            log('[syncLocation] Loading Ward by ' + districtCodes.size() + ' district parents');
            String wardScheme = FEC_FraudConstantCommon.LOCATION_SCHEME_WARD;
            List<String> districtList = new List<String>(districtCodes);
            Integer wardBatchSize = 50; // ~50 districts per query → ~150 wards per query (safe under 2000)
            Integer wardTotal = 0;

            for (Integer i = 0; i < districtList.size(); i += wardBatchSize) {
                Integer endIdx = Math.min(i + wardBatchSize, districtList.size());
                List<String> parentBatch = new List<String>();
                for (Integer j = i; j < endIdx; j++) {
                    parentBatch.add(districtList[j]);
                }

                Integer offset = 0;
                Boolean hasMore = true;
                while (hasMore) {
                    List<CifFeDictLocationVw__x> batch = [
                        SELECT ExternalId, CODE__c, NAME__c, NAME_EN__c,
                               PARENTCODE__c, ISACTIVE__c, SCHEME__c, EFFECTIVEDATE__c
                        FROM CifFeDictLocationVw__x
                        WHERE SCHEME__c = :wardScheme
                          AND PARENTCODE__c IN :parentBatch
                        LIMIT :pageSize OFFSET :offset
                    ];
                    for (CifFeDictLocationVw__x loc : batch) {
                        records.add(new Map<String, Object>{
                            'ExternalId' => loc.ExternalId,
                            'CODE__c' => loc.CODE__c,
                            'NAME__c' => loc.NAME__c,
                            'NAME_EN__c' => loc.NAME_EN__c,
                            'PARENTCODE__c' => loc.PARENTCODE__c,
                            'ISACTIVE__c' => loc.ISACTIVE__c,
                            'SCHEME__c' => loc.SCHEME__c,
                            'EFFECTIVEDATE__c' => loc.EFFECTIVEDATE__c
                        });
                    }
                    wardTotal += batch.size();
                    hasMore = (batch.size() == pageSize && offset + pageSize < offsetCap);
                    offset += pageSize;
                }
            }
            log('[syncLocation] Ward total loaded: ' + wardTotal);
            log('[syncLocation] Total external records loaded: ' + records.size());
        }

        if (records == null || records.isEmpty()) {
            log('[syncLocation] No records to process → EXIT');
            return;
        }
        log('syncLocation-data: '+ records);

        log('[syncLocation] Processing ' + records.size() + ' records');
        // Use Queueable chain to avoid DML row limit (10,000 per transaction)
        System.enqueueJob(new LocationSyncQueueable(records));
        log('[syncLocation] Enqueued LocationSyncQueueable');
    }

    /**
     * Queueable that processes location sync in steps to stay within DML limits.
     * Step 0: Country, Step 1: Province, Step 2: District, Step 3+: Ward (chunked by 8000)
     */
    public class LocationSyncQueueable implements Queueable {
        private List<Map<String, Object>> records;
        private Integer step;
        private Integer wardOffset;

        public LocationSyncQueueable(List<Map<String, Object>> records) {
            this.records = records;
            this.step = 0;
            this.wardOffset = 0;
        }

        public LocationSyncQueueable(List<Map<String, Object>> records, Integer step, Integer wardOffset) {
            this.records = records;
            this.step = step;
            this.wardOffset = wardOffset;
        }

        public void execute(QueueableContext context) {
            try {
                if (step == 0) {
                    upsertCountries(records);
                    System.enqueueJob(new LocationSyncQueueable(records, 1, 0));
                } else if (step == 1) {
                    upsertProvinces(records);
                    System.enqueueJob(new LocationSyncQueueable(records, 2, 0));
                } else if (step == 2) {
                    upsertDistricts(records);
                    System.enqueueJob(new LocationSyncQueueable(records, 3, 0));
                } else if (step == 3) {
                    Boolean hasMore = upsertWardsChunk(records, wardOffset);
                    if (hasMore) {
                        System.enqueueJob(new LocationSyncQueueable(records, 3, wardOffset + 3000));
                    } else {
                        log('[LocationSyncQueueable] All steps completed');
                    }
                }
            } catch (Exception ex) {
                log('[LocationSyncQueueable] ERROR at step ' + step + ' offset ' + wardOffset + ': ' + ex.getMessage());
            }
        }
    }

    @TestVisible
    private static void upsertCountries(List<Map<String, Object>> records) {
        Map<String, FEC_Country__c> countries = new Map<String, FEC_Country__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_COUNTRY) continue;
            String code = (String) r.get('CODE__c');
            if (String.isBlank(code)) continue;
            countries.put(code, new FEC_Country__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('[upsertCountries] count: ' + countries.size());
        if (!countries.isEmpty()) {
            upsert countries.values() FEC_Code__c;
        }
    }

    @TestVisible
    private static void upsertProvinces(List<Map<String, Object>> records) {
        Map<String, Id> countryMap = new Map<String, Id>();
        for (FEC_Country__c c : [SELECT Id, FEC_Code__c FROM FEC_Country__c]) {
            countryMap.put(c.FEC_Code__c, c.Id);
        }
        Map<String, FEC_Province__c> provinces = new Map<String, FEC_Province__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_PROVINCE) continue;
            String code = (String) r.get('CODE__c');
            String parentCode = (String) r.get('PARENTCODE__c');
            if (String.isBlank(code) || !countryMap.containsKey(parentCode)) continue;
            provinces.put(code, new FEC_Province__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_Country_Code__c = parentCode,
                FEC_Country__c = countryMap.get(parentCode),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('[upsertProvinces] count: ' + provinces.size());
        if (!provinces.isEmpty()) {
            upsert provinces.values() FEC_Code__c;
        }
    }

    @TestVisible
    private static void upsertDistricts(List<Map<String, Object>> records) {
        Map<String, Id> provinceMap = new Map<String, Id>();
        Map<String, Id> provinceToCountryMap = new Map<String, Id>();
        for (FEC_Province__c p : [SELECT Id, FEC_Code__c, FEC_Country__c FROM FEC_Province__c]) {
            provinceMap.put(p.FEC_Code__c, p.Id);
            if (p.FEC_Country__c != null) provinceToCountryMap.put(p.FEC_Code__c, p.FEC_Country__c);
        }
        List<FEC_District__c> districtList = new List<FEC_District__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_CITY_DISTRICT) continue;
            String code = (String) r.get('CODE__c');
            String parentCode = (String) r.get('PARENTCODE__c');
            if (String.isBlank(code) || !provinceMap.containsKey(parentCode)) continue;
            districtList.add(new FEC_District__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_Province__c = provinceMap.get(parentCode),
                FEC_Province_Code__c = parentCode,
                FEC_Country__c = provinceToCountryMap.get(parentCode),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('[upsertDistricts] count: ' + districtList.size());
        if (!districtList.isEmpty()) {
            safeBatchUpsert(districtList);
        }
    }

    @TestVisible
    private static void upsertWards(List<Map<String, Object>> records) {
        upsertWardsChunk(records, 0);
    }

    /**
     * Upserts a chunk of Ward records starting at the given offset.
     * Returns true if there are more wards to process.
     */
    @TestVisible
    private static Boolean upsertWardsChunk(List<Map<String, Object>> records, Integer offset) {
        Map<String, Id> districtMap = new Map<String, Id>();
        Map<String, Id> districtToProvinceMap = new Map<String, Id>();
        Map<String, Id> districtToCountryMap = new Map<String, Id>();
        for (FEC_District__c d : [SELECT Id, FEC_Code__c, FEC_Province__c, FEC_Country__c FROM FEC_District__c]) {
            districtMap.put(d.FEC_Code__c, d.Id);
            if (d.FEC_Province__c != null) districtToProvinceMap.put(d.FEC_Code__c, d.FEC_Province__c);
            if (d.FEC_Country__c != null) districtToCountryMap.put(d.FEC_Code__c, d.FEC_Country__c);
        }
        // Collect all ward records first
        List<FEC_Ward__c> allWards = new List<FEC_Ward__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_WARD) continue;
            String code = (String) r.get('CODE__c');
            String parentCode = (String) r.get('PARENTCODE__c');
            if (String.isBlank(code) || !districtMap.containsKey(parentCode)) continue;
            allWards.add(new FEC_Ward__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_District__c = districtMap.get(parentCode),
                FEC_District_Code__c = parentCode,
                FEC_Province__c = districtToProvinceMap.get(parentCode),
                FEC_Country__c = districtToCountryMap.get(parentCode),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('[upsertWardsChunk] total wards: ' + allWards.size() + ', offset: ' + offset);
        
        Integer chunkSize = 3000;
        Integer endIdx = Math.min(offset + chunkSize, allWards.size());
        if (offset >= allWards.size()) return false;
        
        List<SObject> chunk = new List<SObject>();
        for (Integer i = offset; i < endIdx; i++) {
            chunk.add(allWards[i]);
        }
        if (!chunk.isEmpty()) {
            Schema.SObjectField extField = FEC_Ward__c.FEC_Code__c;
            Database.upsert(chunk, extField, false);
            log('[upsertWardsChunk] Upserted ' + chunk.size() + ' wards');
        }
        return endIdx < allWards.size();
    }

    /**
     * Upserts flat location records into the correct objects based on SCHEME__c.
     * Order: Country → Province → District → Ward (to resolve lookups).
     */
    @TestVisible
    private static void upsertFromFlatRecords(List<Map<String, Object>> records) {

        /* ================= COUNTRY (SCHEME = Country) ================= */
        Map<String, FEC_Country__c> countries = new Map<String, FEC_Country__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_COUNTRY) continue;
            String code = (String) r.get('CODE__c');
            if (String.isBlank(code)) continue;

            countries.put(code, new FEC_Country__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('countries: ' + countries.size());
        log('countries-data: ' + countries);
        if (!countries.isEmpty()) {
            upsertInBatches(countries.values(), 'FEC_Code__c');
        }

        // Build code → Id map
        Map<String, Id> countryMap = new Map<String, Id>();
        for (FEC_Country__c c : [SELECT Id, FEC_Code__c FROM FEC_Country__c WHERE FEC_Code__c IN :countries.keySet()]) {
            countryMap.put(c.FEC_Code__c, c.Id);
        }

        /* ================= PROVINCE (SCHEME = Province) ================= */
        Map<String, FEC_Province__c> provinces = new Map<String, FEC_Province__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_PROVINCE) continue;
            String code = (String) r.get('CODE__c');
            String parentCode = (String) r.get('PARENTCODE__c');
            if (String.isBlank(code) || !countryMap.containsKey(parentCode)) continue;

            provinces.put(code, new FEC_Province__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_Country_Code__c = parentCode,
                FEC_Country__c = countryMap.get(parentCode),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('provinces: ' + provinces.size());
        log('provinces-data: ' + provinces);
        if (!provinces.isEmpty()) {
            upsertInBatches(provinces.values(), 'FEC_Code__c');
        }

        Map<String, Id> provinceMap = new Map<String, Id>();
        Map<String, Id> provinceToCountryMap = new Map<String, Id>();
        for (FEC_Province__c p : [SELECT Id, FEC_Code__c, FEC_Country__c FROM FEC_Province__c WHERE FEC_Code__c IN :provinces.keySet()]) {
            provinceMap.put(p.FEC_Code__c, p.Id);
            if (p.FEC_Country__c != null) {
                provinceToCountryMap.put(p.FEC_Code__c, p.FEC_Country__c);
            }
        }

        /* ================= DISTRICT (SCHEME = City) ================= */
        Map<String, FEC_District__c> districts = new Map<String, FEC_District__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_CITY_DISTRICT) continue;
            String code = (String) r.get('CODE__c');
            String parentCode = (String) r.get('PARENTCODE__c');
            if (String.isBlank(code) || !provinceMap.containsKey(parentCode)) continue;

            districts.put(code, new FEC_District__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_Province__c = provinceMap.get(parentCode),
                FEC_Province_Code__c = parentCode,
                FEC_Country__c = provinceToCountryMap.get(parentCode),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('districts: ' + districts.size());
        log('districts-data: ' + districts);
        if (!districts.isEmpty()) {
            upsertInBatches(districts.values(), 'FEC_Code__c');
        }

        Map<String, Id> districtMap = new Map<String, Id>();
        Map<String, Id> districtToProvinceMap = new Map<String, Id>();
        Map<String, Id> districtToCountryMap = new Map<String, Id>();
        for (FEC_District__c d : [SELECT Id, FEC_Code__c, FEC_Province__c, FEC_Country__c FROM FEC_District__c WHERE FEC_Code__c IN :districts.keySet()]) {
            districtMap.put(d.FEC_Code__c, d.Id);
            if (d.FEC_Province__c != null) districtToProvinceMap.put(d.FEC_Code__c, d.FEC_Province__c);
            if (d.FEC_Country__c != null) districtToCountryMap.put(d.FEC_Code__c, d.FEC_Country__c);
        }

        /* ================= WARD (SCHEME = anything else) ================= */
        Map<String, FEC_Ward__c> wards = new Map<String, FEC_Ward__c>();
        for (Map<String, Object> r : records) {
            String scheme = (String) r.get('SCHEME__c');
            if (scheme != FEC_FraudConstantCommon.LOCATION_SCHEME_WARD) continue;
            String code = (String) r.get('CODE__c');
            String parentCode = (String) r.get('PARENTCODE__c');
            if (String.isBlank(code) || !districtMap.containsKey(parentCode)) continue;

            wards.put(code, new FEC_Ward__c(
                FEC_Code__c = code,
                Name = (String) r.get('NAME_EN__c'),
                FEC_Name_VN__c = (String) r.get('NAME__c'),
                FEC_District__c = districtMap.get(parentCode),
                FEC_District_Code__c = parentCode,
                FEC_Province__c = districtToProvinceMap.get(parentCode),
                FEC_Country__c = districtToCountryMap.get(parentCode),
                FEC_Is_Active__c = r.get('ISACTIVE__c') == true,
                FEC_Effective_Date__c = parseDate(r.get('EFFECTIVEDATE__c'))
            ));
        }
        log('wards: ' + wards.size());
         log('wards-data: ' + wards);
        if (!wards.isEmpty()) {
            upsertInBatches(wards.values(), 'FEC_Code__c');
        }
    }

    @TestVisible
    private static Date parseDate(Object dateVal) {
        if (dateVal == null) return null;
        try {
            if (dateVal instanceof Date) {
                return (Date) dateVal;
            }
            if (dateVal instanceof Datetime) {
                return ((Datetime) dateVal).date();
            }
            String dateStr = String.valueOf(dateVal);
            if (String.isBlank(dateStr)) return null;
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            return null;
        }
    }

   
    
    


    /**
     * Performs hierarchical upsert of location data in the following order:
     *
     * 1. Country
     * 2. Province
     * 3. District
     * 4. Ward
     *
     * Order is critical to ensure lookup relationships
     * can be resolved correctly.
     */
    @TestVisible
    private static void upsertSyncLocation(List<LocationRow> rows) {

         /* ================= COUNTRY ================= */
         Map<String, FEC_Country__c> countries = new Map<String, FEC_Country__c>();

        for (LocationRow r : rows) {
            if (String.isBlank(r.COUNTRY_CODE)) continue;
            countries.put(r.COUNTRY_CODE,
                new FEC_Country__c(
                    FEC_Code__c = r.COUNTRY_CODE,
                    Name = r.COUNTRY_NAME_EN,
                    FEC_Name_VN__c = r.COUNTRY_NAME_VN,
                    FEC_Effective_Date__c = r.COUNTRY_EFFECTIVE_DATE,
                    FEC_Is_Active__c = r.COUNTRY_ISACTIVE

                )
            );
        }
        log('countries: '+ countries);
        if (!countries.isEmpty()) {
            upsert countries.values() FEC_Code__c;
        }

        Map<String, Id> countryMap = new Map<String, Id>();
        for (FEC_Country__c c : [
            SELECT Id, FEC_Code__c
            FROM FEC_Country__c
            WHERE FEC_Code__c IN :countries.keySet()
        ]) {
            countryMap.put(c.FEC_Code__c, c.Id);
        }

        /* ================= PROVINCE ================= */
        Map<String, FEC_Province__c> provinces = new Map<String, FEC_Province__c>();

        for (LocationRow r : rows) {
            if (String.isBlank(r.PROVINCE_CODE) || !countryMap.containsKey(r.PROVINCE_PARENT_CODE)) {
                continue;
            }
            provinces.put(r.PROVINCE_CODE,
                new FEC_Province__c(
                    FEC_Code__c = r.PROVINCE_CODE,
                    Name                  = r.PROVINCE_NAME_EN,
                    FEC_Name_VN__c        = r.PROVINCE_NAME_VN,
                    FEC_Country_Code__c   = countryMap.get(r.PROVINCE_PARENT_CODE),
                    FEC_Effective_Date__c = r.PROVINCE_EFFECTIVE_DATE,
                    FEC_Is_Active__c      = r.PROVINCE_ISACTIVE
                )
            );
        }
        log('provinces: '+ provinces);
        if (!provinces.isEmpty()) {
            upsert provinces.values() FEC_Code__c;
        }

        Map<String, Id> provinceMap = new Map<String, Id>();
        for (FEC_Province__c p : [
            SELECT Id, FEC_Code__c
            FROM FEC_Province__c
            WHERE FEC_Code__c IN :provinces.keySet()
        ]) {
            provinceMap.put(p.FEC_Code__c, p.Id);
        }

        /* ================= DISTRICT ================= */
        Map<String, FEC_District__c> districts = new Map<String, FEC_District__c>();

        for (LocationRow r : rows) {
            if (String.isBlank(r.DISTRICT_CODE) || !provinceMap.containsKey(r.DISTRICT_PARENT_CODE)) {
                continue;
            }
            districts.put(r.DISTRICT_CODE,
                new FEC_District__c(
                    FEC_Code__c      = r.DISTRICT_CODE,
                    Name                  = r.DISTRICT_NAME_EN,
                    FEC_Name_VN__c        = r.DISTRICT_NAME_VN,
                    FEC_Province_Code__c           = provinceMap.get(r.DISTRICT_PARENT_CODE),
                    FEC_Effective_Date__c = r.DISTRICT_EFFECTIVE_DATE,
                    FEC_Is_Active__c      = r.DISTRICT_ISACTIVE
                )
            );
        }
        log('districts: '+ districts);
        if (!districts.isEmpty()) {
            upsert districts.values() FEC_Code__c;
        }

        Map<String, Id> districtMap = new Map<String, Id>();
        for (FEC_District__c d : [
            SELECT Id, FEC_Code__c
            FROM FEC_District__c
            WHERE FEC_Code__c IN :districts.keySet()
        ]) {
            districtMap.put(d.FEC_Code__c, d.Id);
        }

        /* ================= WARD ================= */
        Map<String, FEC_Ward__c> wards = new Map<String, FEC_Ward__c>();

        for (LocationRow r : rows) {
            if (String.isBlank(r.WARD_CODE) || !districtMap.containsKey(r.WARD_PARENT_CODE)) {
                continue;
            }

            wards.put(r.WARD_CODE,
                new FEC_Ward__c(
                    FEC_Code__c          = r.WARD_CODE,
                    Name                  = r.WARD_NAME_EN,
                    FEC_Name_VN__c        = r.WARD_NAME_VN,
                    FEC_District_Code__c           = districtMap.get(r.WARD_PARENT_CODE),
                    FEC_Effective_Date__c = r.WARD_EFFECTIVE_DATE,
                    FEC_Is_Active__c      = r.WARD_ISACTIVE
                )
            );
        }
        log('wards: '+ wards);
        if (!wards.isEmpty()) {
            upsert wards.values() FEC_Code__c;
        }
    }

    /**
     * Upserts records in batches to avoid DML row limits.
     * Uses FEC_Code__c as the external ID field for upsert.
     */
    private static void upsertInBatches(List<SObject> records, String externalIdField) {
        Schema.SObjectField extField = records[0].getSObjectType().getDescribe().fields.getMap().get(externalIdField);
        Integer batchSize = 2000;
        for (Integer i = 0; i < records.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, records.size());
            List<SObject> batch = new List<SObject>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(records[j]);
            }
            Database.upsert(batch, extField, false);
            log('Upserted batch: ' + i + ' to ' + endIdx + ' (' + batch.size() + ' records)');
        }
    }

    /**
     * Safely upserts a large list of SObjects using FEC_Code__c as external ID.
     * Splits into chunks of 5000 to stay within the 10,000 DML row governor limit.
     */
    private static void safeBatchUpsert(List<SObject> records) {
        if (records == null || records.isEmpty()) return;
        Schema.SObjectField extField = records[0].getSObjectType().getDescribe().fields.getMap().get('FEC_Code__c');
        Integer batchSize = 3000;
        for (Integer i = 0; i < records.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, records.size());
            List<SObject> batch = new List<SObject>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(records[j]);
            }
            Database.upsert(batch, extField, false);
            log('[safeBatchUpsert] Upserted ' + batch.size() + ' records (offset ' + i + ')');
        }
    }

    /**
     * Writes a log message to the debug log if debugging is enabled.
     *
     * This method centralizes logging behavior and ensures that debug
     * messages are only printed when the DEBUG_LOG flag is set to true.
     * It helps control log noise and improves performance in production
     * environments by avoiding unnecessary debug statements.
     *
     * @param msg The message to be written to the debug log.
     */
    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }
}