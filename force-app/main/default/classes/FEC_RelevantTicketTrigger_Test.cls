/**
 * Unit tests for FEC_RelevantTicketTrigger (before delete — blocks linked tickets from prior stages).
 */
@IsTest
private class FEC_RelevantTicketTrigger_Test {

  private static final String STAGE_CURRENT = 'RT_CUR';
  private static final String STAGE_OLD = 'RT_OLD';

  @TestSetup
  static void setupData() {
    FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
      Name = 'Relevant Ticket Stage',
      FEC_Code__c = STAGE_CURRENT
    );
    insert stage;

    FEC_CaseTriggerHandler.isExecuting = true;
    try {
      insert new List<Case>{
        new Case(
          Subject = 'RT Case With Stage',
          FEC_Current_Case_Stage__c = stage.Id
        ),
        new Case(Subject = 'RT Case No Stage')
      };
    } finally {
      FEC_CaseTriggerHandler.isExecuting = false;
    }
  }

  private static Case caseWithStage() {
    return [
      SELECT Id
      FROM Case
      WHERE Subject = 'RT Case With Stage'
      LIMIT 1
    ];
  }

  private static Case caseWithoutStage() {
    return [
      SELECT Id
      FROM Case
      WHERE Subject = 'RT Case No Stage'
      LIMIT 1
    ];
  }

  @IsTest
  static void testBeforeDelete_AllowsWhenTicketStageMatchesCase() {
    Case c = caseWithStage();
    FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
      FEC_Interaction__c = c.Id,
      FEC_Stage_Name__c = STAGE_CURRENT
    );
    insert rt;

    Test.startTest();
    Database.DeleteResult dr = Database.delete(rt, false);
    Test.stopTest();

    System.assert(dr.isSuccess(), 'Same stage ticket should delete.');
    System.assertEquals(
      0,
      [SELECT COUNT() FROM FEC_Relevant_Ticket__c WHERE Id = :rt.Id]
    );
  }

  @IsTest
  static void testBeforeDelete_BlocksWhenTicketStageDiffers() {
    Case c = caseWithStage();
    FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
      FEC_Interaction__c = c.Id,
      FEC_Stage_Name__c = STAGE_OLD
    );
    insert rt;

    Test.startTest();
    Database.DeleteResult dr = Database.delete(rt, false);
    Test.stopTest();

    System.assert(!dr.isSuccess(), 'Different stage ticket should be blocked.');
    System.assertEquals(
      StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
      dr.getErrors()[0].getStatusCode()
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM FEC_Relevant_Ticket__c WHERE Id = :rt.Id]
    );
  }

  @IsTest
  static void testBeforeDelete_BlocksWhenTicketStageBlank() {
    Case c = caseWithStage();
    FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
      FEC_Interaction__c = c.Id,
      FEC_Stage_Name__c = null
    );
    insert rt;

    Test.startTest();
    Database.DeleteResult dr = Database.delete(rt, false);
    Test.stopTest();

    System.assert(!dr.isSuccess(), 'Blank stage ticket should be blocked when case has stage.');
  }

  @IsTest
  static void testBeforeDelete_AllowsWhenCaseHasNoStage() {
    Case c = caseWithoutStage();
    FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
      FEC_Interaction__c = c.Id,
      FEC_Stage_Name__c = STAGE_OLD
    );
    insert rt;

    Test.startTest();
    Database.DeleteResult dr = Database.delete(rt, false);
    Test.stopTest();

    System.assert(dr.isSuccess(), 'Case without workflow stage should allow delete.');
  }

  @IsTest
  static void testBeforeDelete_BulkMixedResults() {
    Case c = caseWithStage();
    FEC_Relevant_Ticket__c allowed = new FEC_Relevant_Ticket__c(
      FEC_Interaction__c = c.Id,
      FEC_Stage_Name__c = STAGE_CURRENT
    );
    FEC_Relevant_Ticket__c blocked = new FEC_Relevant_Ticket__c(
      FEC_Interaction__c = c.Id,
      FEC_Stage_Name__c = STAGE_OLD
    );
    insert new List<FEC_Relevant_Ticket__c>{ allowed, blocked };

    Test.startTest();
    Database.DeleteResult[] results = Database.delete(
      new List<FEC_Relevant_Ticket__c>{ allowed, blocked },
      false
    );
    Test.stopTest();

    System.assertEquals(2, results.size());
    System.assert(results[0].isSuccess(), 'Matching stage row should delete.');
    System.assert(!results[1].isSuccess(), 'Mismatched stage row should fail.');
  }
}
