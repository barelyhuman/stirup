
watch:
	ls ./src/* | entr nimble run -- ./example/stirup.ini

w: watch