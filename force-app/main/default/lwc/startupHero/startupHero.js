import { LightningElement, api } from "lwc";

export default class StartupHero extends LightningElement {
  @api jobsUrl = "/offres";
  @api applyUrl = "/postuler";
}