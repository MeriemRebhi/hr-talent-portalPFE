// Force conversion du lead bloqué (score=20, non converti par le Flow car seuil était 30)
String stuckLeadId = '00Qfj00000EKx7AEAT';
Lead l = [SELECT Id, Score_Matching__c, IsConverted, Status FROM Lead WHERE Id = :stuckLeadId LIMIT 1];
System.debug('🎯 Lead: Status=' + l.Status + ' | Score=' + l.Score_Matching__c + ' | Converted=' + l.IsConverted);
if (!l.IsConverted) {
    CVScoringService.convertLeads(new List<Id>{ stuckLeadId });
    System.debug('✅ Conversion lancée pour: ' + stuckLeadId);
} else {
    System.debug('ℹ️ Déjà converti');
}
