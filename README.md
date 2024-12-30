# VRCSaver
Are you tried of having to copy a code from a VRChat world, then go to your computer to save it to a text file and then having to get that file and copy the data again to paste back into the world the next time you login.

This tool is to help with this. The program will keep an eye on your clipboard to see changes and then save these changes to a text file for you. Not only that, when you start the program or chnage the profile. It will copy the latest text file to your clipboard so you can paste it in right away.

# How To Use
Run the program and it will initally create a default profile with default settings. The clipboard monitor will autostart with default settings.
Simply copy to the clipboard and the program will create the file.

# GUI
Profile: Profile is the currently selected program (Note: this does **NOT** auto update when the clipboard monitor is running)<br/>
Set as default: This will set the currently selected profile as default. This means when the program start, it will use this profile first.<br/>
Open profile folder: This will open the folder of the currently selected profile if you want to check the text files out directly.<br/>
Create new profile: This will popup a new window asking for a name for the new profile. Note: Profile cannot contain illegal windows folder characters.<br/>
Remove Profile: Thie will delete the currently selected profile. A popup will ask to confirm this actions. Note: default cannot be deleted but it can be cleared of all files.<br/>
Control: This is the control character that you can use to change profiles or to stop the clipboard monitor from within the game. Note this works outside the game, so it is a genric clipboard tool.<br/>
AutoStart: To enable or disable autostart of the clipboard monitor when starting the program.<br/>
Seconds: How long between each time the clipboard monitor will check the clipboard for change.<br/>
Max History: How many text files will it keep of the clipboard history. Note: Slide to the complete left to set to unlimited.<br/>
Save: Saves the current settings to the setting file.<br/>
Start: Start the clipboard monitor.<br/>
Stop: Stop the clipboard monitor.<br/>

# In game (Text)
When the program start, It will copy the latest file of the current default profile to the clipboard. You can simply then paste in the code in the VRChat game world textbox.<br/>
To switch or to create a new profile. Open your textbox and type in the Control character and then follow by the name. Example: @idletower<br/>
Then simply copy this text (you do not need to send this text) and wait the time in seconds that the program is set to.<br/>
If the profile does not exist: It will create a new profile with that name and clear the clipboard.<br/>
If the profile exist: It will switch to that profile and copy the latest file into your clipboard.<br/>
If you wish to stop the clipboard monitor in game. Open your textbox and type in the Control character and then follow by stop. Example: @stop<br/>
Then simply copy this text (you do not need to send this text) and the clipboard monitor will stop on next check.<br/>

# Project Notes
This was a small project for me to
1. Get back into opensource
2. Save me the headack of copying and pasting code in VRChat
3. More work is needed and this is a genric program so it will remain somewhat basic
4. Yes I know TON in Vrchat have their own saver, which is great but it is only for TON. This is a gernic solution for VRChat
