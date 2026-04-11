// Transfer job postings to Ahmed (Recruteur Java/Data)
User ahmed = [SELECT Id FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];

// Ahmed gets: Java, Data Analyst, Full Stack
List<Opportunity> toTransfer = [
    SELECT Id, Name FROM Opportunity
    WHERE Id IN ('006fj00000AIUY9AAP', '006fj00000AISuXAAX', '006fj00000AITvRAAX')
];
for (Opportunity j : toTransfer) {
    j.OwnerId = ahmed.Id;
    System.debug('Transféré à Ahmed: ' + j.Name);
}
update toTransfer;

System.debug('');
System.debug('RÉSULTAT:');
System.debug('  Meriem → DevOps, Salesforce, Architecte SF, ingenieur IA, Devops');
System.debug('  Ahmed  → Java, Data Analyst, Full Stack');
