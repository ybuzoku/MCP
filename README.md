# MCP
The Minimal Control Program!

Welcome to the Minimal Control Program Project. A very useless but rather fun project that I hope to develop into something similar to 
the Woz Monitor upon the reccomendation of u/theinternetftw (thanks for the idea)! This project really didnt take me more than a few 
hours to do so im certain there are bugs. If you find any, feel free to correct them/contact me at the addresses below, and ill 
endeavour to fix them asap!

Progress on this Control Program will likely be slow since it is not my main project and I dont get as much time to program this stuff 
as I would like. The purpose of this program was to be as tiny as possible and still of some use. Therefore, all it does (for now) is 
allow you to specify a buffer in RAM, specify which sector on the disk you booted from you wish to start copying from and how many 
contiguous sectors do you wish to copy. I use an LBA addressing scheme that addresses CHS=(0,0,0) as LBA=0.

----------------------------------------------------------------------------------------------------------------------------------------

This program was assembled on an IBM PC XT with 256Kb of RAM using MASM 2.0, MS Link 2.0 and converted into a binary file using Symdeb 
(Seriously one of the best debuggers ive ever used).

Nonetheless there are some considerations you must think about when using this program, at least for now. This program is a boot sector 
program so it will never grow too much. It currently has a BPB area at its head which will more than likely be removed by my next upload 
(this program was built off of my other major project, using its bootloader. Its internal name is visible, if you have a sharp eye ;) ).

Firstly, input is NOT checked. Therefore, please please please dont type characters that dont translate to hexadecimal values (ie, 
please only type 0123456789abcdef) and in lower case only, as you may potentially damage your drives!

Secondly, and perhaps MOST IMPORTANTLY, the BPB variable I mainly use, is set for a 360Kb, 5.25" diskette system (the same as what I did 
my testing on.) To make it work on a 1.44Mb 3.5" system, please change the BPB variable sectrc to 0012h from 0009h (using either a hex 
editor or assembling it yourself from the source provided).

----------------------------------------------------Instructions for use--------------------------------------------------------------
Upon booting from a media with this program as its bootsector, you will be greeted with a welcome message and a prompt as so:

"? SEG> " 

Hereupon, you must press exactly 4 keys, to specify the segment in memory you wish to upload your program to, for example b800 (notice 
lower case!). Once the fourth keypress is completed, the program will then prompt you again, this time for the offset into the segment 
as so:

"? OFF> "

Here, you must again press exactly 4 keys to specify the offset of the address. Once the fourth keystroke is complete, you will then be 
prompted as so:

"? LSctrStrt> "

Here you must specify by typing exactly 4 keys again, which logical sector you wish to start copying from. Again, upon completetion of
the 4 keystroke, you will be prompted with the final message:

"? # Sctrs> "

Here you must specify the number of contiguous sectors you wish to copy, again a four digit number.
Then you will see the following message:

"Loading... "

Depending on whether the disk drive is responding to your input commands or not, you will either get a message saying:

"Done, Strike a key to jmp..."

or a message saying:

" Failed. Strike a key to reset...".

In both cases a keystroke is required. In the former case, you will then jump to the head of the buffer you specified (so you better 
make sure the first instruction in the program you have loaded in is indeed code and not data). 
In the latter case, you will simply trigger Int 19h and soft reboot the system. Should this not work, CTRL+ALT+Del your way back to the 
beginning.

PLEASE NOTE, when prompted for numerical values, typing fewer than 4 digits and pressing enter WILL NOT work. Be precise and type in 
exactly 4 digits and if you make a mistake, CTRL+ALT+Del your way back to the start.

----------------------------------------------------------------------------------------------------------------------------------------

The source code is heavily commented, so feel free to do with it whatever you will, but if you intend to use any part of my code as part 
of a project, please acknowledge me as the original writer of whatever code you wish to use.
Im more than happy to answer any questions about the code and my other projects. You can contact me via my reddit, u/ylli122 or via 
email (although, try not to spam me please), at ybuzoku@hotmail.co.uk

PS. Before someone complains to me about using ptr directives when copying FROM variables in memory, thats more for me to 
reference at a quick glance. MASM honestly doenst care about it so its fair game imo!
