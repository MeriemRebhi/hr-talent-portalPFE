// ...existing code...
// ...existing code...
import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createCandidateForJob from '@salesforce/apex/ApplicationController.createCandidateForJob';
import uploadCv              from '@salesforce/apex/ApplicationController.uploadCv';
import initUpload            from '@salesforce/apex/ApplicationController.initUpload';
import uploadChunk           from '@salesforce/apex/ApplicationController.uploadChunk';
import finalizeUpload        from '@salesforce/apex/ApplicationController.finalizeUpload';

// Taille max d'un chunk base64 (750KB → bien sous la limite Aura de 4MB)
const CHUNK_SIZE_BYTES = 750 * 1024;

export default class ApplicationForm extends NavigationMixin(LightningElement) {

    @api jobId;
    @track firstName    = '';
    @track lastName     = '';
    @track email        = '';
    @track phone        = '';
    @track message      = '';
    @track agreeTerms   = false;
    @track isSubmitting = false;
    @track successMessage = false;
    @track errorMessage   = '';
    @track uploadedFile   = null;
    @track uploadProgress = 0;   // 0-100 pour afficher une barre de progression

    // ═════════════════════════════════════════
    // FORM HANDLERS
    // ═════════════════════════════════════════

    handleFirstName(event) { this.firstName = event.target.value; }
    handleLastName(event)  { this.lastName  = event.target.value; }
    handleEmail(event)     { this.email     = event.target.value; }
    handlePhone(event)     { this.phone     = event.target.value; }
    handleMessage(event)   { this.message   = event.target.value; }
    handleAgreeTerms(event){ this.agreeTerms = event.target.checked; }

    // ═════════════════════════════════════════
    // FILE UPLOAD HANDLERS
    // ═════════════════════════════════════════

    handleFileClick() {
        this.template.querySelector('.file-input').click();
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (files && files.length > 0) {
            const file = files[0];

            // Vérification taille max: 10MB
            const maxSize = 10 * 1024 * 1024;
            if (file.size > maxSize) {
                this.showError('Le fichier ne doit pas dépasser 10MB.');
                event.target.value = '';
                return;
            }

            // Vérification format
            const allowed = ['pdf', 'doc', 'docx', 'txt'];
            const ext = file.name.split('.').pop().toLowerCase();
            if (!allowed.includes(ext)) {
                this.showError('Format accepté: PDF, DOC, DOCX, TXT uniquement.');
                event.target.value = '';
                return;
            }

            this.uploadedFile = file.name;
        }
    }

    removeFile() {
        this.uploadedFile = null;
        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) fileInput.value = '';
    }

    // ═════════════════════════════════════════
    // FORM SUBMISSION
    // ═════════════════════════════════════════

    handleSubmit(event) {
        event.preventDefault();

        if (!this.firstName.trim()) {
            this.showError('Veuillez entrer votre prénom'); return;
        }
        if (!this.lastName.trim()) {
            this.showError('Veuillez entrer votre nom'); return;
        }
        if (!this.email.trim() || !this.isValidEmail(this.email)) {
            this.showError('Veuillez entrer un email valide'); return;
        }
        // Le champ 'Profil candidat' n'est plus obligatoire
        if (!this.agreeTerms) {
            this.showError('Vous devez accepter les conditions'); return;
        }

        this.isSubmitting  = true;
        this.errorMessage  = '';
        this.uploadProgress = 0;

        createCandidateForJob({
            firstName:        this.firstName,
            lastName:         this.lastName,
            email:            this.email,
            phone:            this.phone,
            jobId:            this.jobId,
            candidateProfile: this.message.trim()
        })
        .then(leadId => {
            console.log('✅ Lead créé: ' + leadId);
            const fileInput = this.template.querySelector('.file-input');
            if (fileInput && fileInput.files && fileInput.files.length > 0) {
                console.log('📄 Fichier trouvé, upload chunked en cours...');
                return this.uploadFileChunked(leadId, fileInput.files[0]);
            }
            console.log('ℹ️ Pas de fichier, candidature sans CV');
            return leadId;
        })
        .then(() => {
            console.log('✅ Candidature complète');
            this.isSubmitting   = false;
            this.successMessage = true;
            this.uploadProgress = 100;
            this.showSuccessToast = true;
            this.resetForm();
            setTimeout(() => {
                this.showSuccessToast = false;
                this.dispatchEvent(new CustomEvent('close'));
            }, 3500);
        })
        .catch(error => {
            console.error('❌ Erreur:', error);
            this.isSubmitting = false;
            const msg = error?.body?.message || error?.message || 'Erreur lors de l\'envoi.';
            this.showError(msg);
        });
    }

    // ═════════════════════════════════════════
    // UPLOAD CHUNKED
    // ═════════════════════════════════════════

    /**
     * Upload un fichier CV en chunks pour éviter la limite 4MB Aura
     * - Fichiers < 1MB : upload direct
     * - Fichiers >= 1MB : upload par morceaux de 750KB
     */
    async uploadFileChunked(leadId, file) {
        try {
            // Lire le fichier en base64
            const base64Full = await this.readFileAsBase64(file);
            const totalChars = base64Full.length;

            console.log(`📦 Taille base64: ${totalChars} chars | Fichier: ${file.size} bytes`);

            // Fichier petit → upload direct
            if (file.size < 1 * 1024 * 1024) {
                console.log('📤 Upload direct (fichier < 1MB)');
                await uploadCv({
                    leadId:     leadId,
                    fileName:   file.name,
                    base64Data: base64Full
                });
                this.uploadProgress = 100;
                console.log('✅ Upload direct terminé');
                return leadId;
            }

            // Fichier grand → upload par chunks
            // Chaque chunk = 750KB de bytes → ~1000KB en base64 (facteur 4/3)
            const chunkBase64Size = Math.ceil(CHUNK_SIZE_BYTES * 4 / 3);
            const totalChunks     = Math.ceil(totalChars / chunkBase64Size);

            console.log(`🔢 Upload chunked: ${totalChunks} chunks de ~750KB`);

            // Étape 1: Initialiser
            const contentVersionId = await initUpload({
                leadId:   leadId,
                fileName: file.name
            });
            console.log('✅ initUpload OK: ' + contentVersionId);

            // Étape 2: Envoyer les chunks
            for (let i = 0; i < totalChunks; i++) {
                const start = i * chunkBase64Size;
                const end   = Math.min(start + chunkBase64Size, totalChars);
                const chunk = base64Full.substring(start, end);

                await uploadChunk({
                    contentVersionId: contentVersionId,
                    base64Chunk:      chunk,
                    chunkIndex:       i,
                    totalChunks:      totalChunks
                });

                // Mise à jour progression (0 à 90% pendant l'upload)
                this.uploadProgress = Math.round(((i + 1) / totalChunks) * 90);
                console.log(`✅ Chunk ${i + 1}/${totalChunks} envoyé`);
            }

            // Étape 3: Finaliser
            await finalizeUpload({
                contentVersionId: contentVersionId,
                leadId:           leadId
            });

            this.uploadProgress = 100;
            console.log('✅ Upload chunked terminé');
            return leadId;

        } catch (error) {
            console.error('❌ Erreur uploadFileChunked:', error);
            // Ne pas bloquer la candidature si l'upload échoue
            // Le Lead est déjà créé, le scoring se fera sans CV
            console.warn('⚠️ Candidature créée sans CV (erreur upload)');
            return leadId;
        }
    }

    /**
     * Lit un File et retourne son contenu en base64 pur (sans le préfixe data:...)
     */
    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result;
                const base64 = result.includes(',') ? result.split(',')[1] : result;
                resolve(base64);
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    // ═════════════════════════════════════════
    // MODAL HANDLERS
    // ═════════════════════════════════════════

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick() {
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    // ═════════════════════════════════════════
    // UTILITIES
    // ═════════════════════════════════════════

    resetForm() {
        this.firstName    = '';
        this.lastName     = '';
        this.email        = '';
        this.phone        = '';
        this.message      = '';
        this.agreeTerms   = false;
        this.uploadedFile = null;
        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) fileInput.value = '';
    }

    showError(message) {
        this.errorMessage = message;
        setTimeout(() => { this.errorMessage = ''; }, 5000);
    }

    isValidEmail(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    }

    // Getter pour afficher la barre de progression
    get isUploading() {
        return this.isSubmitting && this.uploadProgress > 0 && this.uploadProgress < 100;
    }

    get progressStyle() {
        return `width: ${this.uploadProgress}%`;
    }
}