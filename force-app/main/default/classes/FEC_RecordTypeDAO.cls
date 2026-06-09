public with sharing class FEC_RecordTypeDAO {
    /**
   * Get RecordType records by record id list
   * @param recordIdlst
   * @return List<RecordType>
   * @created: 2025/12/27 FIS
   * @modified:
   */
  public static List<RecordType> getRecordsById(Set<String> recordIdlst) {
    return [
      SELECT Id, DeveloperName, Name
      FROM RecordType
      WHERE Id IN :recordIdlst
    ];
  }
}