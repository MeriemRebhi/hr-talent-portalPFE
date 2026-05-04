# Agentforce Recruteur - Opportunity Setup

Ce guide active un agent recruteur dans Salesforce (sur Opportunity) avec 3 actions:

1. `AgentGetOpportunityDetails`
2. `AgentFindBestCandidateForJob`
3. `AgentChangeOpportunityStageSafely`

## 1) Deployer le package

```powershell
cd C:\Users\rabhi\Downloads\hr-talent-portalPFE-main\hr-talent-portalPFE-main
sf project deploy start --source-dir force-app/main/default/classes/AgentGetOpportunityDetails.cls --source-dir force-app/main/default/classes/AgentGetOpportunityDetails.cls-meta.xml --source-dir force-app/main/default/classes/AgentFindBestCandidateForJob.cls --source-dir force-app/main/default/classes/AgentFindBestCandidateForJob.cls-meta.xml --source-dir force-app/main/default/classes/AgentChangeOpportunityStageSafely.cls --source-dir force-app/main/default/classes/AgentChangeOpportunityStageSafely.cls-meta.xml --source-dir force-app/main/default/permissionsets/Recruiter_Agent_Actions.permissionset-meta.xml --target-org <ton-org-alias> --wait 20
```

## 2) Assigner le permission set

- Setup -> Permission Sets
- Ouvrir `Recruiter Agent Actions`
- Manage Assignments -> Add Assignment -> choisir les recruteurs

## 3) Ajouter les actions dans ton agent Agentforce existant

- Setup -> Agentforce Agents
- Ouvrir ton agent recruteur
- Agent Builder -> Actions -> Add Action
- Ajouter:
  - `Obtenir details opportunity (recruteur)`
  - `Trouver meilleur candidat pour un poste`
  - `Changer statut opportunity (securise)`
- Sauvegarder puis `Activate`

## 4) Utilisation sur Opportunity

- Ouvrir une Opportunity
- Ouvrir le panneau Agentforce (icône Einstein)
- Exemples:
  - "Donne moi les details de cette opportunity"
  - "Qui est le meilleur candidat pour l offre DevOps"
  - "Propose le changement vers RH Fit"
  - "Confirme le changement de statut vers RH Fit"

## 5) Validation securisee de statut

L action `Changer statut opportunity (securise)` applique les regles:

- confirmation explicite obligatoire (`confirmChange=true`)
- transitions controlees (Gaming -> Technique -> Architecture -> RH Fit -> Closed Won/Closed Lost)
- verifications metier:
  - vers `Architecture`: Technique finalise
  - vers `RH Fit`: Architecture finalise
  - vers `Closed Won`: RH Fit valide (status valide ou score >= 75)
- ecriture d un audit dans `Security_Audit_Log__c`

