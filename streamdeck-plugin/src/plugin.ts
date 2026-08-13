import streamDeck from "@elgato/streamdeck";

import { ToggleServer } from "./actions/toggle-server";

streamDeck.logger.setLevel("info");

streamDeck.actions.registerAction(new ToggleServer());

streamDeck.connect();
