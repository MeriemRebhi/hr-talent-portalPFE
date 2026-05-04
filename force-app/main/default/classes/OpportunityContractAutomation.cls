public with sharing class OpportunityContractAutomation {

    public static void handleAfterInsert(List<Opportunity> newList) {
        if (newList == null || newList.isEmpty()) return;

        Set<Id> oppIdsToDispatch = new Set<Id>();
        for (Opportunity opp : newList) {
            if (shouldDispatch(opp)) {
                oppIdsToDispatch.add(opp.Id);
            }
        }

        DocuSignContractDispatcher.enqueueForOpportunities(oppIdsToDispatch);
    }

    public static void handleAfterUpdate(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
        if (newList == null || newList.isEmpty()) return;

        Set<Id> oppIdsToDispatch = new Set<Id>();
        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;
            if (!shouldDispatch(opp)) continue;

            Boolean movedToClosedWon = (oldOpp == null) || (oldOpp.StageName != 'Closed Won');
            Boolean becameCandidature = oldOpp != null && oldOpp.Is_Candidature__c != true && opp.Is_Candidature__c == true;

            if (movedToClosedWon || becameCandidature) {
                oppIdsToDispatch.add(opp.Id);
            }
        }

        DocuSignContractDispatcher.enqueueForOpportunities(oppIdsToDispatch);
    }

    @TestVisible
    private static Boolean shouldDispatch(Opportunity opp) {
        if (opp == null || opp.Id == null) return false;
        if (opp.StageName != 'Closed Won') return false;
        if (opp.Is_Candidature__c != true) return false;
        if (hasActiveContract(opp)) return false;
        return true;
    }

    @TestVisible
    private static Boolean hasActiveContract(Opportunity opp) {
        if (opp == null) return false;
        if (String.isBlank(opp.DocuSign_Envelope_Id__c)) return false;

        String status = String.isBlank(opp.Contract_Status__c)
            ? ''
            : opp.Contract_Status__c.trim().toLowerCase();

        return status == 'sent'
            || status == 'queued'
            || status == 'created'
            || status == 'delivered';
    }
}