// ═══════════════════════════════════════
// Réassigner des offres d'emploi au recruteur Ahmed
// pour simuler le partage par département
// ═══════════════════════════════════════

User ahmed = [SELECT Id FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];
User sami  = [SELECT Id FROM User WHERE Username = 'sami.trabelsi.pfe@talan-tunisie.dev' LIMIT 1];

System.debug('Ahmed ID: ' + ahmed.Id);
System.debug('Sami ID: ' + sami.Id);

// List all job postings
List<Opportunity> jobs = [
    SELECT Id, Name, Departement__c, OwnerId 
    FROM Opportunity 
    WHERE RecordType.DeveloperName = 'Job_Posting'
    ORDER BY CreatedDate DESC
];

for (Opportunity j : jobs) {
    System.debug('Offre: ' + j.Name + ' | Dept: ' + j.Departement__c + ' | Owner: ' + j.OwnerId);
}

// Transfer "Développeur Backend Java" and "Data Analyst IA" to Ahmed
List<Opportunity> toTransfer = [
    SELECT Id, Name, Departement__c
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    AND (Name LIKE '%Java%' OR Name LIKE '%Data%')
];

for (Opportunity j : toTransfer) {
    j.OwnerId = ahmed.Id;
    System.debug('→ Transféré à Ahmed: ' + j.Name);
}
if (!toTransfer.isEmpty()) {
    update toTransfer;
}

// Set Sami as the "manager" by making him owner of a tech lead opportunity
// (This is for the manager email notification — the job posting owner gets notified)
// For now, Sami will be the observer via the Meet link

System.debug('');
System.debug('═══════════════════════════════════════');
System.debug('  RÉSULTAT:');
System.debug('═══════════════════════════════════════');
System.debug('  Meriem (toi) — Recruteur DevOps/Salesforce');
System.debug('    → voit les candidatures DevOps + Salesforce');
System.debug('');
System.debug('  Ahmed Ben Salah — Recruteur Java/Data');
System.debug('    → voit les candidatures Java + Data Analyst');
System.debug('');
System.debug('  Sami Trabelsi — Manager technique');
System.debug('    → reçoit les emails de notification entretien');
System.debug('═══════════════════════════════════════');
