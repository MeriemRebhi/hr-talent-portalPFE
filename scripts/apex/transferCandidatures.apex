// Transfer Application opportunities to match job posting ownership
User ahmed = [SELECT Id FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];

// Ahmed's job posting IDs
Set<Id> ahmedJobIds = new Set<Id>{'006fj00000AIUY9AAP', '006fj00000AISuXAAX', '006fj00000AITvRAAX'};

// Find all leads that reference Ahmed's jobs
List<Lead> leads = [
    SELECT Id, ConvertedOpportunityId, Description
    FROM Lead
    WHERE IsConverted = true AND ConvertedOpportunityId != null
    LIMIT 500
];

Set<Id> oppIdsToTransfer = new Set<Id>();
for (Lead l : leads) {
    if (l.Description == null) continue;
    for (Id jId : ahmedJobIds) {
        if (l.Description.contains('JOB_ID:' + jId)) {
            oppIdsToTransfer.add(l.ConvertedOpportunityId);
            break;
        }
    }
}

if (!oppIdsToTransfer.isEmpty()) {
    List<Opportunity> toTransfer = [
        SELECT Id, Name FROM Opportunity WHERE Id IN :oppIdsToTransfer
    ];
    for (Opportunity opp : toTransfer) {
        opp.OwnerId = ahmed.Id;
        System.debug('→ Candidature transférée à Ahmed: ' + opp.Name);
    }
    update toTransfer;
}

System.debug('Total candidatures transférées: ' + oppIdsToTransfer.size());
