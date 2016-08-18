# AVR-GCC Makefile
PROJECT=testproj
#SOURCES=main.c lib.c
SOURCES=main.S
CC=avr-gcc
OBJCOPY=avr-objcopy
MMCU=attiny26
#AVRBINDIR=~/avr-tools/bin/
AVRDUDECMD=avrdude -p t26 -c dt006 -E reset

CFLAGS=-mmcu=$(MMCU) -Os -g  -Wall -W -Werror -mcall-prologues -pipe -fwhole-program
 
$(PROJECT).hex: $(PROJECT).out
	$(AVRBINDIR)$(OBJCOPY) -j .text -O ihex $(PROJECT).out $(PROJECT).hex
 
$(PROJECT).out: $(SOURCES)
	$(AVRBINDIR)$(CC) $(CFLAGS) -I./ -o $(PROJECT).out $(SOURCES)
	$(AVRBINDIR)avr-size $(PROJECT).out
 
program: $(PROJECT).hex
	$(AVRBINDIR)$(AVRDUDECMD) -U flash:w:$(PROJECT).hex

clean:
	rm -f $(PROJECT).out
	rm -f $(PROJECT).hex

backup:
	$(AVRBINDIR)$(AVRDUDECMD) -U flash:r:backup.bin:r

backup-eeprom:
	$(AVRBINDIR)$(AVRDUDECMD) -U eeprom:r:eebackup.bin:r
