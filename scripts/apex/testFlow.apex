// Re-trigger le Flow en changeant puis remettant le statut
Lead l = [SELECT Id, Status, Score_Matching__c FROM Lead WHERE LastName = 'Marioumti' AND IsConverted = false LIMIT 1];
if (l != null) {
    System.debug('Lead trouvé: ' + l.Id + ' | Score: ' + l.Score_Matching__c);
    l.Status = 'Condidat -Non contacté';
    update l;
    l.Status = 'Condidature - Validée- Email Envoyé';
    update l;
    System.debug('✅ Lead re-triggered pour le Flow!');
} else {
    System.debug('❌ Lead non trouvé ou déjà converti');
}
