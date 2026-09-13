-- Compilé en .app via make-apps.sh — c'est CETTE .app que tu pointes depuis
-- le bouton Stream Deck (action "Système : Ouvrir"), pas le .sh directement :
-- une .app se lance silencieusement, un .sh ouvrirait une fenêtre Terminal.
try
	set out to do shell script "/Users/Majid/Documents/Twitch/bin/server-start.sh 5500"
	display notification out with title "Serveur Twitch"
on error errMsg
	display notification errMsg with title "Serveur Twitch — échec"
end try
