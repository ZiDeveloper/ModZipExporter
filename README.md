# !!! THIS IS A FORK !!!

# Mod Zip Exporter  
Exports the selected folder to a `.zip` for use with mods.  
Exports the imported assets and converts text resources to binary resources.  
Unlike exporting through the editor with only selected resources and scenes, it doesn't pull in any unnecessary dependencies like the splash screen, autoloads and any resources referenced by your files outside of the selected directory.  

To install, create a `res://addons/mod_exporter` directory, search for ["VostokMods Exporter"](https://godotengine.org/asset-library/asset/3764) in the AssetLib and download it. During installation, press "Change Install Folder" and select the `mod_exporter` folder.  
Enable the plugin in Project > Project Settings... > Plugins.  
A new panel called "Mod" will be created at the bottom of the screen, it will scan for any files named `mod.txt` and add them to the list of mods.  

Remaps for existing files can be defined by creating a `[remaps]` section in the mod.txt you are exporting. The target path will automatically be resolved to the imported asset path.   
Example:
```conf
[remaps]
"res://MyFile.tres"="res://mods/MyMod/ModdedFile.tres"
```
