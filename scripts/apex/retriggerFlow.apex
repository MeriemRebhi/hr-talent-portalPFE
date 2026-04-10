// Re-trigger le Flow pour les Leads qualifiés non convertis
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c
    FROM Lead 
    WHERE Status = 'Condidature - Validée- Email Envoyé' 
    AND IsConverted = false
    AND Score_Matching__c > 30
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Leads qualifiés non convertis: ' + leads.size());
for (Lead l : leads) {
    System.debug('→ ' + l.FirstName + ' ' + l.LastName + ' | Score: ' + l.Score_Matching__c);
    // Changer le statut puis le remettre pour trigger le Flow
    l.Status = 'Condidat -Non contacté';
}
if (!leads.isEmpty()) {
    update leads;
    for (Lead l : leads) {
        l.Status = 'Condidature - Validée- Email Envoyé';
    }
    update leads;
    System.debug('✅ Leads re-triggered pour le Flow');
}
