public without sharing class DocuSignContractDispatcher implements Queueable, Database.AllowsCallouts {

    private List<Id> oppIds;

    public DocuSignContractDispatcher(Id oppId) {
        this.oppIds = new List<Id>();
        if (oppId != null) {
            this.oppIds.add(oppId);
        }
    }

    public DocuSignContractDispatcher(List<Id> oppIds) {
        this.oppIds = new List<Id>();
        if (oppIds == null) return;

        for (Id currentId : oppIds) {
            if (currentId != null && !this.oppIds.contains(currentId)) {
                this.oppIds.add(currentId);
            }
        }
    }

    public void execute(QueueableContext context) {
        if (oppIds == null || oppIds.isEmpty()) return;

        for (Id currentOppId : oppIds) {
            try {
                DocuSignEnvelopeService.sendContractForOpportunity(currentOppId);
            } catch (Exception ex) {
                try {
                    DocuSignEnvelopeService.markOpportunityError(currentOppId, ex.getMessage());
                } catch (Exception nested) {
                    System.debug('DocuSignContractDispatcher nested error: ' + nested.getMessage());
                }
            }
        }
    }

    public static void enqueueForOpportunity(Id oppId) {
        if (oppId == null) return;
        enqueueForOpportunities(new Set<Id>{ oppId });
    }

    public static void enqueueForOpportunities(Set<Id> oppIds) {
        if (oppIds == null || oppIds.isEmpty()) return;

        List<Id> orderedIds = new List<Id>(oppIds);
        Integer chunkSize = 20;

        for (Integer i = 0; i < orderedIds.size(); i += chunkSize) {
            Integer endExclusive = Math.min(i + chunkSize, orderedIds.size());
            List<Id> chunk = orderedIds.subList(i, endExclusive);
            System.enqueueJob(new DocuSignContractDispatcher(chunk));
        }
    }
}