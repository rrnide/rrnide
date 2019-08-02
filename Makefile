all: rgss/mailslot.dll lib/mailslot.dll frontend/style.css

rgss/mailslot.dll: src/mailslot.c
	gcc -m32 $^ -shared -s -O -o $@

lib/mailslot.dll: src/mailslot.c
	gcc $^ -shared -s -O -o $@

frontend/style.css: src/style.sass
	sass $^ $@
