import Application from "client-app/app";
import config from "client-app/config/environment";
import * as QUnit from "qunit";
import { setApplication } from "@ember/test-helpers";
import { setupEmberOnerrorValidation, start as qunitStart } from "ember-qunit";
import { setup } from "qunit-dom";

export function start() {
  setApplication(Application.create(config.APP));

  setup(QUnit.assert);
  setupEmberOnerrorValidation();
  qunitStart();
}
