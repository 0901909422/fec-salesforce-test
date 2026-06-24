/**
 * Đồng bộ member (theo Role) cho Public Group FEC_My_Team_List_View.
 * List View My Team dùng sharedTo theo group thay vì role vì Salesforce kế thừa
 * visibility lên role cha trong hierarchy (Center Director vẫn thấy nếu share role con).
 */
public without sharing class FEC_MyTeamListViewGroupService {
  public static final String GROUP_DEVELOPER_NAME = 'FEC_My_Team_List_View';

  private static final Set<String> EXCLUDED_ROLE_DEVELOPER_NAMES = new Set<String>{
    'FEC_Customer_Service_Center_Director',
    'FEC_Customer_Service_Inbound_Specialist_1',
    'FEC_Customer_Service_Inbound_Specialist_2',
    'FEC_Customer_Service_Inbound_Specialist_3',
    'FEC_Customer_Service_Inbound_Specialist_4',
    'FEC_Customer_Service_Inbound_Specialist_5',
    'FEC_Customer_Service_Inbound_Specialist_6',
    'FEC_Customer_Service_Inbound_Specialist_7',
    'FEC_Customer_Service_Inbound_Officer_1',
    'FEC_Customer_Service_Inbound_Officer_2',
    'FEC_Customer_Service_Inbound_Officer_3',
    'FEC_Customer_Service_Inbound_Officer_4',
    'FEC_Customer_Service_Inbound_Officer_5',
    'FEC_Customer_Service_Inbound_Officer_6',
    'FEC_Customer_Service_Inbound_Officer_7',
    'FEC_Customer_Service_Outbound_Specialist_1',
    'FEC_Customer_Service_Outbound_Specialist_2',
    'FEC_Customer_Service_Outbound_Specialist_3',
    'FEC_Customer_Service_Outbound_Officer_1',
    'FEC_Customer_Service_Outbound_Officer_2',
    'FEC_Customer_Service_Outbound_Officer_3',
    'FEC_Customer_Service_Ecom_Specialist_1',
    'FEC_Customer_Service_Ecom_Specialist_2',
    'FEC_Customer_Service_Ecom_Officer_1',
    'FEC_Customer_Service_Ecom_Officer_2',
    'FEC_Customer_Service_Support_Specialist',
    'FEC_Customer_Care_Specialist',
    'FEC_Customer_Service_Operations_Management_Specialist',
    'FEC_Card_Risk_Monitoring_Specialist',
    'FEC_Customer_Service_Quality_Control_Specialist'
  };

  public static Set<String> getExcludedRoleDeveloperNames() {
    return EXCLUDED_ROLE_DEVELOPER_NAMES.clone();
  }

  /**
   * Gán mọi FEC role (trừ EXCLUDED) vào public group. Chạy sau deploy group + list view.
   */
  public static void syncRoleMembers() {
    Id publicGroupId = resolvePublicGroupId();
    if (publicGroupId == null) {
      throw new IllegalArgumentException(
        'Public group ' + GROUP_DEVELOPER_NAME + ' not found.'
      );
    }

    Set<Id> allowedRoleIds = new Set<Id>();
    for (UserRole roleRecord : [
      SELECT Id, DeveloperName
      FROM UserRole
      WHERE DeveloperName LIKE 'FEC%'
    ]) {
      if (!roleRecord.DeveloperName.startsWith('FEC_')) {
        continue;
      }
      if (EXCLUDED_ROLE_DEVELOPER_NAMES.contains(roleRecord.DeveloperName)) {
        continue;
      }
      allowedRoleIds.add(roleRecord.Id);
    }

    if (allowedRoleIds.isEmpty()) {
      delete [SELECT Id FROM GroupMember WHERE GroupId = :publicGroupId];
      return;
    }

    Map<Id, Id> roleIdToRoleGroupId = new Map<Id, Id>();
    for (Group roleGroup : [
      SELECT Id, RelatedId
      FROM Group
      WHERE Type = 'Role' AND RelatedId IN :allowedRoleIds
    ]) {
      roleIdToRoleGroupId.put(roleGroup.RelatedId, roleGroup.Id);
    }

    delete [SELECT Id FROM GroupMember WHERE GroupId = :publicGroupId];

    List<GroupMember> membersToInsert = new List<GroupMember>();
    for (Id roleGroupId : roleIdToRoleGroupId.values()) {
      membersToInsert.add(
        new GroupMember(GroupId = publicGroupId, UserOrGroupId = roleGroupId)
      );
    }

    if (!membersToInsert.isEmpty()) {
      insert membersToInsert;
    }
  }

  @TestVisible
  private static Id resolvePublicGroupId() {
    List<Group> groups = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = :GROUP_DEVELOPER_NAME AND Type = 'Regular'
      LIMIT 1
    ];
    return groups.isEmpty() ? null : groups[0].Id;
  }
}
