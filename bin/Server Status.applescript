-- Bouton de vérification manuelle, sans rien démarrer/arrêter — juste la
-- notification de l'état actuel.
try
	set out to do shell script "/Users/Majid/Documents/Twitch/bin/server-status.sh 5500"
	display notification out with title "Serveur Twitch — en route ✓"
on error
	display notification "arrêté" with title "Serveur Twitch — arrêté ✕"
end try
