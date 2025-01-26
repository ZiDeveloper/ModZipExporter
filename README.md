# Mod Zip Exporter  
Exports the selected folder to a `.zip` for use with mods.  
Exports the imported assets and converts text resources to binary resources.  
Unlike exporting through the editor with only selected resources and scenes, it doesn't pull in any unnecessary dependencies like the splash screen, autoloads and any resources referenced by your files outside of the selected directory.  

## Usage:  
* Download or clone the `.zip`.  
* Extract the contents to `res://addons/mod_exporter`. Create the folder if it doesn't exist  
* Enable the plugin in Project > Project Settings... > Plugins  
* Open the "Mod" bottom panel  
* Enter the path of your mod's contents  
* Enter the `.zip` name, including the extension  
* Press "Export!"  
* Add `mod.txt` to the `.zip`  