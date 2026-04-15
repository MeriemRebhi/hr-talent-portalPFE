import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getArchInterviewInfo from '@salesforce/apex/ArchitectureInterviewController.getArchInterviewInfo';
import uploadAudio from '@salesforce/apex/ArchitectureInterviewController.uploadAudio';
import processAudio from '@salesforce/apex/ArchitectureInterviewController.processAudio';
import getProcessingStatus from '@salesforce/apex/ArchitectureInterviewController.getProcessingStatus';
import requestReschedule from '@salesforce/apex/ArchitectureInterviewController.requestReschedule';

export default class ArchitectureInterview extends LightningElement {

    /* ────────── State Machine ────────── */
    @track step = 'loading'; // loading | error | welcome | interview | recording | uploading | processing | results | done

    /* ────────── IDs ────────── */
    oppId;

    /* ────────── Interview info ────────── */
    @track candidateName = '';
    @track jobTitle = '';
    @track meetLink = '';
    @track jitsiRoom = '';
    @track scheduledDate = null;
    @track duration = '';
    @track status = '';
    @track existingScore = null;

    /* ────────── Audio Recording ────────── */
    _mediaRecorder = null;
    _audioChunks = [];
    @track isRecording = false;
    @track recordingTime = 0;
    _recordingInterval = null;

    /* ────────── Results ────────── */
    @track transcription = '';
    @track aiFeedback = '';
    @track score = null;

    /* ────────── Processing ────────── */
    @track processingMessage = '';
    _pollingInterval = null;

    /* ────────── Reschedule ────────── */
    @track rescheduleRequested = false;
    @track showRescheduleModal = false;
    @track rescheduleReason = '';
    @track isRescheduling = false;

    /* ────────── Consent ────────── */
    @track consentGiven = false;

    /* ────────── Error ────────── */
    @track errorMessage = '';

    /* ═══════════ COMPUTED ═══════════ */

    get jitsiUrl() {
        return this.jitsiRoom ? `https://meet.jit.si/${this.jitsiRoom}` : '';
    }

    get scheduledDateFormatted() {
        if (!this.scheduledDate) return '';
        try {
            const d = new Date(this.scheduledDate);
            const pad = n => String(n).padStart(2, '0');
            return `${pad(d.getDate())}/${pad(d.getMonth()+1)}/${d.getFullYear()} à ${pad(d.getHours())}:${pad(d.getMinutes())}`;
        } catch (e) {
            return '';
        }
    }

    get durationLabel() {
        const map = { '30': '30 minutes', '45': '45 minutes', '60': '1 heure', '90': '1h30' };
        return map[this.duration] || (this.duration + ' min');
    }

    get recordingTimeFormatted() {
        const min = Math.floor(this.recordingTime / 60);
        const sec = this.recordingTime % 60;
        return `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
    }

    get consentNotGiven() {
        return !this.consentGiven;
    }

    get isNotRecording() {
        return !this.isRecording;
    }

    get rescheduleButtonLabel() {
        return this.isRescheduling ? 'Envoi…' : 'Confirmer le report';
    }

    get canReschedule() {
        return !this.rescheduleRequested && this.scheduledDate;
    }

    get isStepLoading()    { return this.step === 'loading'; }
    get isStepError()      { return this.step === 'error'; }
    get isStepWelcome()    { return this.step === 'welcome'; }
    get isStepInterview()  { return this.step === 'interview'; }
    get isStepUploading()  { return this.step === 'uploading'; }
    get isStepProcessing() { return this.step === 'processing'; }
    get isStepResults()    { return this.step === 'results' || this.step === 'done'; }

    get scoreClass() {
        if (this.score >= 70) return 'score-high';
        if (this.score >= 50) return 'score-mid';
        return 'score-low';
    }

    /* ═══════════ LIFECYCLE ═══════════ */

    @wire(CurrentPageReference)
    setPageRef(ref) {
        if (ref && ref.state && ref.state.id) {
            this.oppId = ref.state.id;
        }
    }

    connectedCallback() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._loadInterview(); }, 300);
    }

    disconnectedCallback() {
        this._stopRecording();
        this._clearPolling();
    }

    /* ═══════════ LOAD ═══════════ */

    async _loadInterview() {
        try {
            if (!this.oppId) {
                const url = new URL(window.location.href);
                this.oppId = url.searchParams.get('id');
            }
            if (!this.oppId) {
                this.errorMessage = 'Identifiant de candidature manquant dans l\'URL.';
                this.step = 'error';
                return;
            }

            const info = await getArchInterviewInfo({ oppId: this.oppId });
            this.candidateName       = info.candidateName;
            this.jobTitle            = info.jobTitle;
            this.meetLink            = info.meetLink;
            this.jitsiRoom           = info.jitsiRoom;
            this.scheduledDate       = info.scheduledDate;
            this.duration            = info.duration;
            this.status              = info.status;
            this.existingScore       = info.existingScore;
            this.rescheduleRequested = info.rescheduleRequested;
            this.transcription       = info.transcription;
            this.aiFeedback          = info.aiFeedback;
            this.score               = info.existingScore;

            if (info.alreadyCompleted) {
                this.step = 'results';
            } else if (info.status === 'Processing') {
                this.step = 'processing';
                this.processingMessage = 'Traitement IA en cours…';
                this._startPolling();
            } else if (info.isScheduled) {
                this.step = 'welcome';
            } else {
                this.errorMessage = 'Aucun entretien architecture n\'est encore planifié pour votre candidature.';
                this.step = 'error';
            }
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.step = 'error';
        }
    }

    /* ═══════════ CONSENT + START ═══════════ */

    handleConsent(event) {
        this.consentGiven = event.target.checked;
    }

    handleStartInterview() {
        if (!this.consentGiven) {
            this.errorMessage = 'Veuillez accepter le consentement d\'enregistrement.';
            return;
        }
        this.errorMessage = '';
        this.step = 'interview';
    }

    /* ═══════════ JITSI IFRAME ═══════════ */

    get jitsiIframeSrc() {
        if (!this.jitsiRoom) return '';
        const params = new URLSearchParams({
            'config.startWithAudioMuted': 'false',
            'config.startWithVideoMuted': 'false',
            'config.prejoinPageEnabled': 'false',
            'config.disableDeepLinking': 'true',
            'interfaceConfig.TOOLBAR_BUTTONS': '["microphone","camera","hangup","chat","fullscreen"]'
        });
        return `https://meet.jit.si/${this.jitsiRoom}#${params.toString()}`;
    }

    /* ═══════════ RECORDING — MediaRecorder API ═══════════ */

    async handleStartRecording() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            this._audioChunks = [];
            this._mediaRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });

            this._mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this._audioChunks.push(event.data);
                }
            };

            this._mediaRecorder.start(1000); // chunk every 1s
            this.isRecording = true;
            this.recordingTime = 0;

            // Timer
            this._recordingInterval = setInterval(() => {
                this.recordingTime++;
            }, 1000);
        } catch (err) {
            this.errorMessage = 'Impossible d\'accéder au microphone : ' + err.message;
        }
    }

    async handleStopRecording() {
        if (!this._mediaRecorder || this._mediaRecorder.state === 'inactive') return;

        return new Promise((resolve) => {
            this._mediaRecorder.onstop = async () => {
                this._clearRecordingTimer();
                this.isRecording = false;

                const blob = new Blob(this._audioChunks, { type: 'audio/webm' });

                // Stop all tracks
                this._mediaRecorder.stream.getTracks().forEach(t => t.stop());

                await this._uploadBlob(blob);
                resolve();
            };
            this._mediaRecorder.stop();
        });
    }

    _stopRecording() {
        if (this._mediaRecorder && this._mediaRecorder.state !== 'inactive') {
            this._mediaRecorder.stop();
            this._mediaRecorder.stream.getTracks().forEach(t => t.stop());
        }
        this._clearRecordingTimer();
    }

    _clearRecordingTimer() {
        if (this._recordingInterval) {
            clearInterval(this._recordingInterval);
            this._recordingInterval = null;
        }
    }

    /* ═══════════ UPLOAD ═══════════ */

    async _uploadBlob(blob) {
        this.step = 'uploading';

        try {
            // Check size (25 MB limit for Whisper)
            if (blob.size > 25 * 1024 * 1024) {
                this.errorMessage = 'Le fichier audio dépasse 25 MB. Essayez un entretien plus court.';
                this.step = 'error';
                return;
            }

            // Convert blob to base64
            const base64 = await this._blobToBase64(blob);
            const fileName = `arch-interview-${this.oppId}-${Date.now()}.webm`;

            await uploadAudio({
                oppId: this.oppId,
                audioBase64: base64,
                fileName: fileName
            });

            // Start processing
            this.step = 'processing';
            this.processingMessage = 'Transcription audio en cours (Whisper)…';

            await processAudio({ oppId: this.oppId });

            // Start polling for results
            this._startPolling();
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.step = 'error';
        }
    }

    _blobToBase64(blob) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => {
                // Remove data:audio/webm;base64, prefix
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(blob);
        });
    }

    /* ═══════════ POLLING ═══════════ */

    _startPolling() {
        this._pollingInterval = setInterval(async () => {
            try {
                const result = await getProcessingStatus({ oppId: this.oppId });
                if (result.status === 'Completed') {
                    this._clearPolling();
                    this.score = result.score;
                    this.transcription = result.transcription;
                    this.aiFeedback = result.aiFeedback;
                    this.step = 'results';
                } else if (result.status === 'Error') {
                    this._clearPolling();
                    this.errorMessage = result.aiFeedback || 'Une erreur est survenue.';
                    this.step = 'error';
                } else {
                    this.processingMessage = 'Analyse IA en cours…';
                }
            } catch (err) {
                // Keep polling
            }
        }, 5000);
    }

    _clearPolling() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
            this._pollingInterval = null;
        }
    }

    /* ═══════════ RESCHEDULE ═══════════ */

    handleShowReschedule() {
        this.showRescheduleModal = true;
    }

    handleCloseReschedule() {
        this.showRescheduleModal = false;
    }

    handleRescheduleReasonChange(event) {
        this.rescheduleReason = event.target.value;
    }

    async handleSubmitReschedule() {
        this.isRescheduling = true;
        try {
            await requestReschedule({
                oppId: this.oppId,
                reason: this.rescheduleReason
            });
            this.rescheduleRequested = true;
            this.showRescheduleModal = false;
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        }
        this.isRescheduling = false;
    }
}
