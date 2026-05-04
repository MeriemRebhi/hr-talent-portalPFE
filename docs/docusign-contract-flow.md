# DocuSign Contract Flow (Closed Won -> Signature)

Ce document decrit l integration DocuSign ajoutee dans le projet.

## 1) Prerequis

- Configuration DocuSign deja faite manuellement dans l org (ton setup Step 1..9).
- Record `DocuSignConfig__mdt` cree dans Salesforce avec les vraies valeurs.
- Endpoint webhook publie dans DocuSign Connect:
  - `/services/apexrest/docusign/webhook`

## 2) Ce qui est automatise

Quand une candidature Opportunity passe en `Closed Won`:

1. `InternalDashboardController.updateOpportunityStage(...)` detecte la transition.
2. Un `Queueable` (`DocuSignContractDispatcher`) est lance.
3. Le service `DocuSignEnvelopeService`:
   - authentifie en JWT
   - cree l enveloppe DocuSign (template)
   - stocke le tracking dans Salesforce (`Opportunity` + `DocuSign_Envelope__c`)

Quand DocuSign envoie les events webhook:

1. `DocuSignWebhookRest` recoit l event.
2. Le payload est journalise dans `DocuSignWebhookEvent__c`.
3. Le statut contrat est mis a jour sur `Opportunity`.
4. Sur `completed`, un job telecharge le PDF signe et l attache a l Opportunity.

## 3) Champs Opportunity utilises

- `DocuSign_Envelope_Id__c`
- `Contract_Status__c`
- `Contract_Sent_At__c`
- `Contract_Signed_At__c`
- `Contract_Error__c`
- `Contract_Template_Id__c` (optionnel, sinon template par defaut)
- `Contract_Attempts__c`

## 4) Objets de suivi

- `DocuSign_Envelope__c`
- `DocuSignWebhookEvent__c`

## 5) Configuration metadata attendue (Custom Metadata Type)

Type: `DocuSignConfig__mdt`

Champs attendus dans le record actif:

- `IntegrationKey__c`
- `UserId__c`
- `AccountId__c`
- `BaseUri__c` (`https://demo.docusign.net` pour sandbox)
- `OauthBaseUri__c` (`https://account-d.docusign.com` pour sandbox)
- `PrivateKey__c`
- `DefaultTemplateId__c`
- `SignerRoleName__c` (ex: `Candidate`)
- `WebhookSecret__c` (si HMAC active)
- `IsEnabled__c = true`

## 6) Deploiement cible (suggestion)

Deployer d abord metadata + classes DocuSign, puis le controller mis a jour:

```powershell
sf project deploy start --source-dir force-app/main/default/objects/DocuSignConfig__mdt --source-dir force-app/main/default/objects/DocuSign_Envelope__c --source-dir force-app/main/default/objects/DocuSignWebhookEvent__c --source-dir force-app/main/default/objects/Opportunity/fields/DocuSign_Envelope_Id__c.field-meta.xml --source-dir force-app/main/default/objects/Opportunity/fields/Contract_Status__c.field-meta.xml --source-dir force-app/main/default/objects/Opportunity/fields/Contract_Sent_At__c.field-meta.xml --source-dir force-app/main/default/objects/Opportunity/fields/Contract_Signed_At__c.field-meta.xml --source-dir force-app/main/default/objects/Opportunity/fields/Contract_Error__c.field-meta.xml --source-dir force-app/main/default/objects/Opportunity/fields/Contract_Template_Id__c.field-meta.xml --source-dir force-app/main/default/objects/Opportunity/fields/Contract_Attempts__c.field-meta.xml --source-dir force-app/main/default/remoteSiteSettings/DocuSign_Auth.remoteSite-meta.xml --source-dir force-app/main/default/remoteSiteSettings/DocuSign_Demo.remoteSite-meta.xml --source-dir force-app/main/default/classes/DocuSignConfigService.cls --source-dir force-app/main/default/classes/DocuSignAuthService.cls --source-dir force-app/main/default/classes/DocuSignEnvelopeService.cls --source-dir force-app/main/default/classes/DocuSignContractDispatcher.cls --source-dir force-app/main/default/classes/DocuSignEnvelopeCompletionJob.cls --source-dir force-app/main/default/classes/DocuSignWebhookRest.cls --source-dir force-app/main/default/classes/InternalDashboardController.cls --target-org <ton-org-alias> --wait 30
```

## 7) Verification rapide

1. Ouvrir une candidature en `RH Fit`.
2. Valider RH Fit vers `Closed Won`.
3. Verifier qu un `DocuSign_Envelope__c` est cree.
4. Verifier `Opportunity.Contract_Status__c = Sent`.
5. Signer le document dans DocuSign demo.
6. Verifier webhook recu (`DocuSignWebhookEvent__c`) puis `Contract_Status__c = Completed`.
7. Verifier PDF signe attache a l Opportunity.

## 8) Important pour le webhook (public access)

DocuSign Connect envoie des requetes serveur-a-serveur sans session Salesforce utilisateur.

- Evite l URL `*.develop.my.salesforce.com/services/apexrest/...` pour Connect.
- Utilise plutot une URL publique de Site/Experience Cloud, par exemple:
  - `https://<ton-site>.my.site.com/services/apexrest/docusign/webhook`

Checklist guest access:

1. Donner l acces Apex guest a `DocuSignWebhookRest`.
2. Donner au profil guest les droits create/read sur `DocuSignWebhookEvent__c`.
3. Donner les droits edit necessaires sur `DocuSign_Envelope__c` et champs Opportunity de suivi si webhook met a jour les records.
4. Si HMAC est active dans Connect, renseigner le meme secret dans `DocuSignConfig__mdt.WebhookSecret__c`.
