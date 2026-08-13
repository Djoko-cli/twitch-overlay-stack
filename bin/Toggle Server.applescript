-- Un seul bouton Stream Deck qui bascule : lance si arrêté, arrête si en
-- route. Pratique si tu préfères UN bouton plutôt que deux (start + stop
-- séparés) — à toi de choisir selon ta disposition sur le Stream Deck.
try
	do shell script "/Users/Majid/Desktop/Twitch/bin/server-status.sh 5500"
	-- code 0 : en route → on arrête
	set out to do shell script "/Users/Majid/Desktop/Twitch/bin/server-stop.sh 5500"
	display notification out with title "Serveur Twitch"
on error
	-- code 1 (via l'erreur do shell script) : arrêté → on démarre
	try
		set out to do shell script "/Users/Majid/Desktop/Twitch/bin/server-start.sh 5500"
		display notification out with title "Serveur Twitch"
	on error errMsg
		display notification errMsg with title "Serveur Twitch — échec"
	end try
end try
