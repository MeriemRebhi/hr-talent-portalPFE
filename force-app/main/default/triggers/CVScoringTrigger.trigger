/**
 * Déclenche le scoring dès qu'un CV est lié à un Lead
 */
trigger CVScoringTrigger on ContentDocumentLink (after insert) {
    Set<String> leadIds = new Set<String>();

    for (ContentDocumentLink link : Trigger.new) {
        // On vérifie si l'entité liée est un Lead (Objet Prospect)
        if (link.LinkedEntityId != null && link.LinkedEntityId.getSObjectType() == Lead.SObjectType) {
            leadIds.add(String.valueOf(link.LinkedEntityId));
        }
    }

    if (!leadIds.isEmpty()) {
        // Appel asynchrone pour ne pas bloquer l'upload du fichier
        CVScoringService.scoreCVForLeads(leadIds);
    }
}