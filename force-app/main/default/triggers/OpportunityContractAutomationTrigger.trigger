trigger OpportunityContractAutomationTrigger on Opportunity (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            OpportunityContractAutomation.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            OpportunityContractAutomation.handleAfterUpdate(Trigger.oldMap, Trigger.new);
        }
    }
}