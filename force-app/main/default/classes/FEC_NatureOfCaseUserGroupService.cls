/**
 * User group dùng filter FEC_User_Group__c INCLUDES trên Nature of Case / Case Stage.
 */
public without sharing class FEC_NatureOfCaseUserGroupService {
  public static final String FRONT_LINE = 'CS Frontline';
  public static final String BACK_OFFICE = 'CS Back Office';
  private static final String USER_GROUP_CX = 'CX';

  /**
   * Nhóm hiện tại của user cộng mọi FEC_User_Group__c của user CS Frontline / CS Back Office (trừ CX).
   */
  public static List<String> buildRoleListForIncludes(String currentUserGroup) {
    Set<String> groups = new Set<String>();
    if (String.isNotBlank(currentUserGroup)) {
      groups.add(currentUserGroup);
    }
    for (AggregateResult ar : [
      SELECT FEC_User_Group__c
      FROM User
      WHERE
        IsActive = TRUE
        AND FEC_User_Group__c != NULL
        AND FEC_User_Group__c != :USER_GROUP_CX
        AND FEC_User_Division_Group__c IN (:FRONT_LINE, :BACK_OFFICE)
      GROUP BY FEC_User_Group__c
    ]) {
      String grp = (String) ar.get('FEC_User_Group__c');
      if (String.isNotBlank(grp)) {
        groups.add(grp);
      }
    }
    return new List<String>(groups);
  }
}
