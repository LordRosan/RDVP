export enum UiFeedbackTone {
  Success = 'success',
  Danger = 'danger',
  Warning = 'warning',
  Info = 'info'
}

export interface UiFeedbackMessage {
  message: string;
  tone: UiFeedbackTone;
}
