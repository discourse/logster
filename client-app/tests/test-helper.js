import Application from "client-app/app";
import config from "client-app/config/environment";
import * as QUnit from "qunit";
import { setApplication } from "@ember/test-helpers";
import { loadTests } from "ember-qunit/test-loader";
import { setupEmberOnerrorValidation, start } from "ember-qunit";
import { setup } from "qunit-dom";

setApplication(Application.create(config.APP));

setup(QUnit.assert);
setupEmberOnerrorValidation();
loadTests();
start();
