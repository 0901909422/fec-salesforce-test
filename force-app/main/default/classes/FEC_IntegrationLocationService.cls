public class FEC_IntegrationLocationService {

    public static final Boolean DEBUG_LOG = true;
    // Named Credential endpoint for ODI OData service
    private static final String ENDPOINT =
        'callout:ODI_OData/LocationHierarchy';
    public static Boolean useMock = false;
    @TestVisible
    private static List<Map<String, Object>> mockRecords = null;

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
        } else if (mockRecords != null) {
            log('[syncLocation] Using injected mock records');
            records = mockRecords;
        } else {
            log('[syncLocation] Using external object CifFeDictLocationVw__x');
            records = new List<Map<String, Object>>();

            // External objects limit OFFSET to 2000 globally,
            // so query per SCHEME and paginate within each using OFFSET up to 2000
            List<String> schemes = new List<String>{FEC_FraudConstantCommon.LOCATION_SCHEME_COUNTRY, FEC_FraudConstantCommon.LOCATION_SCHEME_PROVINCE, FEC_FraudConstantCommon.LOCATION_SCHEME_CITY_DISTRICT, FEC_FraudConstantCommon.LOCATION_SCHEME_WARD};
            Integer pageSize = FEC_FraudConstantCommon.LOCATION_PAGE_SIZE;

            for (String scheme : schemes) {
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
                        // External object OFFSET cap is 2000
                        if (offset >= FEC_FraudConstantCommon.LOCATION_OFFSET) {
                            log('[syncLocation] SCHEME=' + scheme + ' reached OFFSET limit 2000');
                            hasMore = false;
                        }
                    }
                }
            }
            log('[syncLocation] Total external records loaded: ' + records.size());
        }

        if (records == null || records.isEmpty()) {
            log('[syncLocation] No records to process → EXIT');
            return;
        }
        log('syncLocation-data: '+ records);

        log('[syncLocation] Processing ' + records.size() + ' records');
        upsertFromFlatRecords(records);
        log('[syncLocation] END');
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
            upsert countries.values() FEC_Code__c;
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
            upsert provinces.values() FEC_Code__c;
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
            upsert districts.values() FEC_Code__c;
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
            upsert wards.values() FEC_Code__c;
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