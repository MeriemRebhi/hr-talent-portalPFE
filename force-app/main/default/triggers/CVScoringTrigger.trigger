trigger CVScoringTrigger on ContentDocumentLink (after insert) {
    // Garde anti-récursion : ne pas re-fire pendant une conversion en cours
    if (CVScoringService.isProcessing) return;

    Set<String> leadIds = new Set<String>();
    for (ContentDocumentLink link : Trigger.new) {
        if (link.LinkedEntityId != null && link.LinkedEntityId.getSObjectType() == Lead.SObjectType) {
            leadIds.add(String.valueOf(link.LinkedEntityId));
        }
    }
    if (!leadIds.isEmpty()) {
        CVScoringService.scoreCVForLeads(leadIds);
    }
}