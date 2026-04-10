// Créer le statut Lead "Candidat - Converti" avec IsConverted = true
List<LeadStatus> existing = [SELECT Id, MasterLabel FROM LeadStatus WHERE MasterLabel = 'Candidat - Converti' LIMIT 1];
if (!existing.isEmpty()) {
    System.debug('✅ Statut "Candidat - Converti" existe déjà: ' + existing[0].Id);
} else {
    LeadStatus ls = new LeadStatus(
        MasterLabel  = 'Candidat - Converti',
        ApiName      = 'Candidat_Converti',
        IsConverted  = true,
        IsDefault    = false
    );
    insert ls;
    System.debug('✅ Statut "Candidat - Converti" créé avec succès: ' + ls.Id);
}
