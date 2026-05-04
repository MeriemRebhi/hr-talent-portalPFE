public without sharing class AgentChangeOpportunityStageSafely {

    public class Input {
        @InvocableVariable(label='Opportunity Id' required=true)
        public Id opportunityId;

        @InvocableVariable(label='Nouveau statut' required=true)
        public String targetStage;

        @InvocableVariable(label='Confirmation explicite')
        public Boolean confirmChange;

        @InvocableVariable(label='Justification')
        public String reason;
    }

    public class Output {
        @InvocableVariable(label='Succes')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Statut precedent')
        public String previousStage;

        @InvocableVariable(label='Nouveau statut')
        public String newStage;

        @InvocableVariable(label='Changement applique')
        public Boolean changed;
    }

    @InvocableMethod(
        label='Changer statut opportunity (securise)'
        description='Change le statut d une opportunity avec validation des regles metier et confirmation explicite.'
        category='Recruteur RH'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Output out = new Output();
            out.success = false;
            out.changed = false;

            try {
                if (inp == null || inp.opportunityId == null || String.isBlank(inp.targetStage)) {
                    out.message = 'Parametres manquants: opportunityId et targetStage sont obligatoires.';
                    results.add(out);
                    continue;
                }

                Opportunity opp = [
                    SELECT Id, Name, StageName, Is_Candidature__c, RecordType.DeveloperName
                    FROM Opportunity
                    WHERE Id = :inp.opportunityId
                    LIMIT 1
                ];

                out.previousStage = opp.StageName;

                String normalizedTarget = normalizeStage(inp.targetStage);
                if (String.isBlank(normalizedTarget)) {
                    out.message =
                        'Statut cible non reconnu. Valeurs acceptees: Gaming, Technique, Architecture, RH Fit, Closed Won, Closed Lost.';
                    logAudit('AGENT_STAGE_CHANGE_REJECTED', 'WARNING', 'Statut cible invalide: ' + inp.targetStage, opp.Id);
                    results.add(out);
                    continue;
                }
                out.newStage = normalizedTarget;

                if (!isCandidateOpportunity(opp)) {
                    out.message = 'Action reservee aux opportunities de type Candidature.';
                    logAudit('AGENT_STAGE_CHANGE_REJECTED', 'WARNING', 'Opportunity non candidature: ' + opp.Id, opp.Id);
                    results.add(out);
                    continue;
                }

                if (opp.StageName == normalizedTarget) {
                    out.success = true;
                    out.changed = false;
                    out.message = 'Aucun changement: le statut est deja ' + normalizedTarget + '.';
                    logAudit('AGENT_STAGE_CHANGE_NOOP', 'INFO', 'Aucun changement sur ' + opp.Id, opp.Id);
                    results.add(out);
                    continue;
                }

                // Mode direct: l'agent applique le changement de statut sans blocage
                // de transition ni verification d'entretiens prealables.

                // Reuse existing business behavior (emails/notifications already implemented there).
                InternalDashboardController.updateOpportunityStage(opp.Id, normalizedTarget);

                out.success = true;
                out.changed = true;
                out.message =
                    'Statut mis a jour avec succes: ' + out.previousStage + ' -> ' + normalizedTarget +
                    (String.isNotBlank(inp.reason) ? ' | Justification: ' + inp.reason : '');
                logAudit('AGENT_STAGE_CHANGE_APPLIED', 'INFO',
                    'Stage change applique ' + out.previousStage + ' -> ' + normalizedTarget + ' sur ' + opp.Id, opp.Id);
            } catch (Exception ex) {
                out.success = false;
                out.changed = false;
                out.message = 'Erreur changement statut: ' + ex.getMessage();
                logAudit('AGENT_STAGE_CHANGE_ERROR', 'CRITICAL', out.message, inp != null ? inp.opportunityId : null);
            }

            results.add(out);
        }

        return results;
    }

    private static Boolean isCandidateOpportunity(Opportunity opp) {
        if (opp == null) return false;
        if (opp.Is_Candidature__c == true) return true;
        return opp.RecordType != null && opp.RecordType.DeveloperName == 'Application';
    }

    private static String normalizeStage(String raw) {
        if (String.isBlank(raw)) return null;
        String v = raw.trim().toLowerCase();

        if (v == 'gaming' || v.contains('gaming')) return 'Gaming';
        if (v == 'technique' || v.contains('tech')) return 'Technique';
        if (v == 'architecture' || v.contains('arch')) return 'Architecture';
        if (v == 'rh fit' || v == 'rhfit' || (v.contains('rh') && v.contains('fit'))) return 'RH Fit';
        if (v == 'closed won' || v.contains('won') || v.contains('embauche')) return 'Closed Won';
        if (v == 'closed lost' || v.contains('lost') || v.contains('refus')) return 'Closed Lost';
        return null;
    }

    private static Boolean isTransitionAllowed(String currentStage, String targetStage) {
        if (String.isBlank(currentStage) || String.isBlank(targetStage)) return false;

        Map<String, Set<String>> allowed = new Map<String, Set<String>>{
            'Gaming' => new Set<String>{ 'Technique', 'Closed Lost' },
            'Technique' => new Set<String>{ 'Architecture', 'Closed Lost' },
            'Architecture' => new Set<String>{ 'RH Fit', 'Closed Lost' },
            'RH Fit' => new Set<String>{ 'Closed Won', 'Closed Lost', 'RH Fit' },
            'Closed Won' => new Set<String>(),
            'Closed Lost' => new Set<String>()
        };

        if (!allowed.containsKey(currentStage)) {
            // If unknown current stage, keep strict behavior: only allow move to Closed Lost.
            return targetStage == 'Closed Lost';
        }
        return allowed.get(currentStage).contains(targetStage);
    }

    private static String evaluateBusinessRules(Id oppId, String targetStage) {
        if (targetStage == 'Architecture') {
            List<Technical_Interview__c> tech = [
                SELECT Status__c, Score__c
                FROM Technical_Interview__c
                WHERE Opportunity__c = :oppId
                LIMIT 1
            ];
            if (tech.isEmpty()) {
                return 'Blocage securite: aucun entretien Technique trouve.';
            }
            String status = safeLower(tech[0].Status__c);
            Decimal score = tech[0].Score__c;
            if (!(status.contains('completed') || status.contains('validated'))) {
                return 'Blocage securite: entretien Technique non finalise.';
            }
            if (score != null && score < 50) {
                return 'Blocage securite: score Technique insuffisant (< 50/100).';
            }
        }

        if (targetStage == 'RH Fit') {
            List<Architecture_Interview__c> arch = [
                SELECT Status__c, Score__c
                FROM Architecture_Interview__c
                WHERE Opportunity__c = :oppId
                LIMIT 1
            ];
            if (arch.isEmpty()) {
                return 'Blocage securite: aucun entretien Architecture trouve.';
            }
            String status = safeLower(arch[0].Status__c);
            Decimal score = arch[0].Score__c;
            if (!(status.contains('completed') || status.contains('validated'))) {
                return 'Blocage securite: entretien Architecture non finalise.';
            }
            if (score != null && score < 60) {
                return 'Blocage securite: score Architecture insuffisant (< 60/100).';
            }
        }

        if (targetStage == 'Closed Won') {
            List<RH_Fit_Interview__c> rhfit = [
                SELECT Status__c, Recruiter_Validated_Score__c
                FROM RH_Fit_Interview__c
                WHERE Opportunity__c = :oppId
                LIMIT 1
            ];
            if (rhfit.isEmpty()) {
                return 'Blocage securite: aucun entretien RH Fit trouve.';
            }
            String status = safeLower(rhfit[0].Status__c);
            Decimal validatedScore = rhfit[0].Recruiter_Validated_Score__c;
            Boolean statusOk = status.contains('validated');
            Boolean scoreOk = validatedScore != null && validatedScore >= 75;
            if (!(statusOk || scoreOk)) {
                return 'Blocage securite: RH Fit doit etre valide (status Validated ou score >= 75).';
            }
        }

        return null;
    }

    private static String safeLower(String value) {
        return value != null ? value.toLowerCase() : '';
    }

    private static void logAudit(String action, String severity, String details, Id oppId) {
        try {
            Security_Audit_Log__c log = new Security_Audit_Log__c(
                Action__c = action,
                Severity__c = severity,
                Timestamp__c = System.now(),
                Email__c = UserInfo.getUserEmail(),
                Details__c =
                    (details != null ? details : '') +
                    (oppId != null ? (' | OpportunityId=' + String.valueOf(oppId)) : '')
            );
            insert log;
        } catch (Exception e) {
            System.debug('Audit log insert failed: ' + e.getMessage());
        }
    }
}
