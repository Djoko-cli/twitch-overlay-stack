import { action, KeyDownEvent, SingletonAction, WillAppearEvent, WillDisappearEvent } from "@elgato/streamdeck";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import streamDeck from "@elgato/streamdeck";

const execFileAsync = promisify(execFile);

// Chemins en dur : ce plugin est spécifique à cette install de la stack
// Twitch, pas un plugin générique distribué à d'autres personnes. Réutilise
// les scripts bin/*.sh déjà testés (démarrage/arrêt idempotents) plutôt que
// de réimplémenter cette logique en TypeScript.
const PORT = 5500;
const CHECK_URL = `http://127.0.0.1:${PORT}/`;
const TIMER_URL = `http://127.0.0.1:${PORT}/controls/timer.html`;
const START_SCRIPT = "/Users/Majid/Documents/Twitch/bin/server-start.sh";
const STOP_SCRIPT = "/Users/Majid/Documents/Twitch/bin/server-stop.sh";
const POLL_MS = 4000;
const HTTP_TIMEOUT_MS = 1500;

async function isServerUp(): Promise<boolean> {
	try {
		const res = await fetch(CHECK_URL, { signal: AbortSignal.timeout(HTTP_TIMEOUT_MS) });
		return res.ok;
	} catch {
		return false;
	}
}

// `open` est la commande macOS pour lancer une URL dans le navigateur par
// défaut — cohérent avec le reste du projet (.applescript, lsof), qui est
// déjà Mac-only. Si le navigateur a déjà un onglet sur cette URL, la plupart
// des navigateurs (Safari inclus) réactivent cet onglet plutôt que d'en
// ouvrir un nouveau.
async function openTimerPage(): Promise<void> {
	try {
		await execFileAsync("open", [TIMER_URL]);
	} catch (e) {
		streamDeck.logger.error(`ouverture du panneau minuteur échouée: ${e}`);
	}
}

/**
 * Un seul bouton : l'icône reflète l'état réel du serveur (sondé toutes les
 * POLL_MS, pas seulement au clic), et appuyer bascule démarré/arrêté.
 */
@action({ UUID: "com.majid.twitch-server-control.toggle" })
export class ToggleServer extends SingletonAction {
	// un minuteur par instance visible du bouton (en pratique une seule, mais
	// gérer plusieurs onWillAppear/onWillDisappear proprement coûte peu)
	private pollers = new Map<string, ReturnType<typeof setInterval>>();

	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		await this.refresh(ev);
		const id = ev.action.id;
		this.clearPoller(id);
		this.pollers.set(
			id,
			setInterval(() => {
				this.refresh(ev).catch((e) => streamDeck.logger.error(`poll échoué: ${e}`));
			}, POLL_MS)
		);
	}

	override onWillDisappear(ev: WillDisappearEvent): void {
		this.clearPoller(ev.action.id);
	}

	override async onKeyDown(ev: KeyDownEvent): Promise<void> {
		const up = await isServerUp();
		try {
			if (up) {
				await execFileAsync(STOP_SCRIPT, [String(PORT)]);
			} else {
				// server-start.sh ne retourne qu'une fois le port confirmé lié
				// (voir son propre sleep + vérification), donc le serveur est
				// déjà prêt à répondre quand on ouvre le panneau juste après.
				await execFileAsync(START_SCRIPT, [String(PORT)]);
				await openTimerPage();
			}
		} catch (e) {
			streamDeck.logger.error(`bascule du serveur échouée: ${e}`);
		}
		await this.refresh(ev);
	}

	private async refresh(ev: WillAppearEvent | KeyDownEvent): Promise<void> {
		const up = await isServerUp();
		// ev.action est typé DialAction | KeyAction pour WillAppearEvent (le
		// bouton pourrait en théorie être un dial Stream Deck+) — seul
		// KeyAction a setState. Le manifest ne déclare que "Keypad", donc
		// ev.action.isKey() sera toujours vrai en pratique ; le garde de type
		// est là pour satisfaire le compilateur, pas pour un cas réel.
		if (ev.action.isKey()) {
			await ev.action.setState(up ? 1 : 0);
		}
	}

	private clearPoller(id: string): void {
		const existing = this.pollers.get(id);
		if (existing) {
			clearInterval(existing);
			this.pollers.delete(id);
		}
	}
}
