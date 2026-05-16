// Deploy fix cho FEC_RelevantTicketController và FEC_RelevantTicketTriggerHandler lên FecUat
// Chạy script này bằng: sf apex run --file scripts/deploy_relevant_ticket_fix_uat.apex --target-org FecUat
// NOTE: Không thể deploy Apex class qua anonymous - cần dùng Workbench hoặc nhờ admin deploy
System.debug('Cannot deploy Apex via anonymous. Please use Workbench or ask admin to deploy FEC_RelevantTicketController and FEC_RelevantTicketTriggerHandler to FecUat.');
