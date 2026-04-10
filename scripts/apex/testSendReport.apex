// Test: Envoyer manuellement le rapport ATS pour un candidat ayant complété le gaming test
// Exécuter dans: Dev Console > Execute Anonymous

// 1. Trouver un candidat avec Gaming complété
List<Opportunity> opps = [
    SELECT Id, Name, Gaming_Test_Score__c, Gaming_Test_Status__c, StageName
    FROM Opportunity
    WHERE Gaming_Test_Status__c = 'Completed'
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];

if (opps.isEmpty()) {
    System.debug('❌ Aucune opportunité avec Gaming complété trouvée.');
} else {
    System.debug('=== Candidats avec Gaming complété :');
    for (Opportunity o : opps) {
        System.debug('  ' + o.Name + ' | Score: ' + o.Gaming_Test_Score__c + '% | Stage: ' + o.StageName + ' | Id: ' + o.Id);
    }

    // 2. Envoyer le rapport pour le premier candidat trouvé
    Opportunity opp = opps[0];
    Decimal score = opp.Gaming_Test_Score__c != null ? opp.Gaming_Test_Score__c : 70;
    Boolean passed = score >= 60;

    System.debug('>>> Envoi du rapport ATS pour: ' + opp.Name + ' (score: ' + score + '%)');

    GamingTestReportController.sendReportAsync(
        opp.Id,
        score,
        (score / 10).intValue(),  // correctCount estimé
        10,                        // totalQuestions
        300,                       // timeSpentSeconds (5 min)
        passed
    );

    System.debug('✅ sendReportAsync appelé — vérifiez :');
    System.debug('   1. Setup > Environments > Jobs > Apex Jobs (cherchez GamingTestReportController)');
    System.debug('   2. La boîte mail du candidat');
    System.debug('   3. Setup > Email > Email Logs (si activé)');
}
