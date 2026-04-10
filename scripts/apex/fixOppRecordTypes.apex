// Fix: Marquer Is_Candidature__c = true sur les Opportunities créées par conversion Lead
// (celles dont le nom contient "Candidature")
// Pas besoin de changer le RecordType — le JobPostingController filtre sur Is_Candidature__c

List<Opportunity> candidatureOpps = [
    SELECT Id, Name, Is_Candidature__c
    FROM Opportunity
    WHERE Name LIKE '%Candidature%'
    AND (Is_Candidature__c = false OR Is_Candidature__c = null)
];

System.debug('🔍 ' + candidatureOpps.size() + ' Opportunity(s) candidature à marquer:');
for (Opportunity opp : candidatureOpps) {
    System.debug('   ' + opp.Id + ' | ' + opp.Name);
    opp.Is_Candidature__c = true;
}

if (!candidatureOpps.isEmpty()) {
    update candidatureOpps;
    System.debug('✅ ' + candidatureOpps.size() + ' Opportunity(s) marquée(s) Is_Candidature__c = true');
} else {
    System.debug('✅ Aucune Opportunity à corriger');
}
