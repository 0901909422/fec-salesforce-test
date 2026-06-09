trigger FEC_ContentDistributionTrigger on ContentDistribution(before insert) {
  FEC_ContentDistributionTriggerHandler handler = new FEC_ContentDistributionTriggerHandler();

  handler.run();
}