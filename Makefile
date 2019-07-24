all: rgss/mailslot.dll mailslot/mailslot.dll

rgss/mailslot.dll: mailslot/mailslot.c
	gcc -m32 $^ -shared -s -O -o $@

mailslot/mailslot.dll: mailslot/mailslot.c
	gcc $^ -shared -s -O -o $@
