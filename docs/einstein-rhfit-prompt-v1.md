# Einstein Prompt RH Fit (V1)

This document contains the deployed Prompt Builder template for RH Fit interview preparation.

## Template Setup

- Template label: `RH Fit Interview Question Generator`
- API name (dev name): `RH_Fit_Interview_Question_Generator`
- Template type: `Flex`
- Language: `French`
- Generation mode: `JSON output only`

## Input Variables (Flow / Apex)

Use these input variables in Prompt Builder (Flex templates are limited to 5 custom inputs):

- `Input:JobOfferContext` (required)
- `Input:CandidateContext` (required)
- `Input:PreviousInterviewContext` (optional)
- `Input:RecruiterGuidance` (optional)

## System Prompt

```text
Tu es un Senior HR Interview Designer pour Talan Tunisie.
Ta mission est de generer un guide d entretien RH Fit personnalise pour une candidature.
Tu dois adapter les questions selon:
- l offre (titre, departement, description, competences attendues)
- le profil candidat
- les resultats precedents (score matching IA, technique, architecture, feedback)

Regles strictes:
1) Genere exactement 12 questions RH Fit.
2) Chaque question doit inclure:
   - question
   - relance
   - competence evaluee
   - signal positif attendu
   - signal d alerte
   - bareme 0 a 5
3) Questions concretes, non generiques, orientees poste.
4) Interdits: questions discriminatoires (age, religion, etat civil, etc.).
5) Ton professionnel, clair, en francais.
6) Retourne uniquement du JSON valide. Pas de markdown, pas de texte avant ou apres.

Format JSON attendu:
{
  "interview_intro": "string",
  "job_summary": "string",
  "candidate_summary": "string",
  "questions": [
    {
      "id": 1,
      "question": "string",
      "follow_up": "string",
      "competency": "string",
      "positive_signal": "string",
      "red_flag": "string",
      "score_guide_0_5": "string"
    }
  ],
  "decision_framework": {
    "hire_if": "string",
    "hold_if": "string",
    "reject_if": "string"
  }
}
```

## Context Construction (Flow)

```text
JobOfferContext
- Titre: {!Opportunity.Name}
- Departement: {!Opportunity.Department__c}
- Description: {!Opportunity.Job_Description__c}
- Competences attendues: {!Opportunity.Required_Skills__c}

CandidateContext
- Nom: {!Lead.Name}
- Score matching IA: {!Lead.Score_Matching__c}
- Recommandation IA: {!Lead.Recommendation_IA__c}
- Points forts: {!Lead.AI_Points_Forts__c}
- Points faibles: {!Lead.AI_Points_Faibles__c}
- Score technique: {!Technical_Score}
- Score architecture: {!Architecture_Score}

PreviousInterviewContext
- Notes entretien technique: {!Tech_Interview_Notes}
- Notes entretien architecture: {!Architecture_Interview_Notes}

RecruiterGuidance
- Priorites RH fit (valeurs, communication, teamwork, leadership, etc.)
```

## Recommended Output Post-Processing

After generation, save the full JSON in one long text field (or rich text) on an RH Fit interview object.

Suggested logical fields to parse from JSON:

- `interview_intro`
- `job_summary`
- `candidate_summary`
- `questions` (array)
- `decision_framework.hire_if`
- `decision_framework.hold_if`
- `decision_framework.reject_if`

## Flow Mapping (Quick)

For a record-triggered or screen flow:

- Build 4 text variables (`JobOfferContext`, `CandidateContext`, `PreviousInterviewContext`, `RecruiterGuidance`).
- Call the Prompt Template action `RH_Fit_Interview_Question_Generator`.
- Map each text variable to the corresponding prompt input (`Input:...`).
- Save the JSON output in your RH Fit interview object for recruiter review.

## Deployed Flow (Org)

Flow name deployed in org:

- `Generate_RH_Fit_Questions` (AutoLaunchedFlow, Active)

Current flow inputs:

- `vJobOfferContext`
- `vCandidateContext`
- `vPreviousInterviewContext`
- `vRecruiterGuidance`

Execution path:

1. Flow receives the 4 text contexts.
2. Flow calls Apex invocable `RHFitPromptFlowAction`.
3. Apex invocable calls Einstein Prompt action `generatePromptResponse` targeting `RH_Fit_Interview_Question_Generator`.

## V1 Guardrails

- Keep recruiter final decision manual.
- Use generated questions as interview support, not as automated hiring decision.
- Move to `Closed Won` only after recruiter confirmation.
