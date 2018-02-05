#NoTrayIcon

SetKeyDelay, 0, 30
SendMode Event

global SubMenuParents := {}
global NoteKeys := {}
global keybindFile := ""
global playerFiles := []
global currentPlayer := 0
global mainWindowState := false
global mainWindowX := 0
global mainWindowY := 0

global settings := {ExitConfirmation: 1, HideHotkey: "Insert"}
ReadSettings() {
	Loop, Read, BardMacroPlayer.ini
	{
		spl := StrSplit(A_LoopReadLine, "=")
		t := spl[1]
		d := spl[2]
		settings[t] := d
	}
}

global FileSelectionControl
global FileLoadedControl
global StopControl
global PlayPauseControl

global trayIcon := "bard.ico"
ICON [trayIcon]
IfExist, %trayIcon%
	Menu, Tray, Icon, %trayIcon%

#Include configLoader.ahk
#Include notePlayer.ahk

ShowParsedKeyboard() {
	sharps := [NoteKeys["C#"], NoteKeys["Eb"], NoteKeys["F#"], NoteKeys["G#"], NoteKeys["Bb"]]
	keys := [NoteKeys["C"], NoteKeys["D"], NoteKeys["E"], NoteKeys["F"], NoteKeys["G"], NoteKeys["A"], NoteKeys["B"]]
	
	Gui, KeyboardWindow: New, +ToolWindow +AlwaysOnTop
	
	Gui, Font, s8, Consolas
	
	Gui, Add, Text, x20 y2, ** Parsed piano keys **
	Gui, Add, Button, Disabled x20 y20 w20,  % sharps[1]
	Gui, Add, Button, Disabled x40 y20 w20,  % sharps[2]
	Gui, Add, Button, Disabled x80 y20 w20,  % sharps[3]
	Gui, Add, Button, Disabled x100 y20 w20, % sharps[4]
	Gui, Add, Button, Disabled x120 y20 w20, % sharps[5]
	
	Gui, Add, Button, Disabled x10 y40 w20,  % keys[1]
	Gui, Add, Button, Disabled x30 y40 w20,  % keys[2]
	Gui, Add, Button, Disabled x50 y40 w20,  % keys[3]
	Gui, Add, Button, Disabled x70 y40 w20,  % keys[4]
	Gui, Add, Button, Disabled x90 y40 w20,  % keys[5]
	Gui, Add, Button, Disabled x110 y40 w20, % keys[6]
	Gui, Add, Button, Disabled x130 y40 w20, % keys[7]
}

ToggleMainWindow() {

	Gui PlayWindow:+LastFoundExist
	if(!WinExist()) {
		MakeMainWindow()
	}
	UpdateMainWindow()

	if(mainWindowState) {
		Gui, PlayWindow: Hide
		Gui, ExitWindow: Hide
		mainWindowState := false
	} else {
		Gui, PlayWindow: Show, NoActivate
		mainWindowState := true
	}
}

MakeMainWindow() {
	ControlGetPos, ffxivX, ffxivY, ffxivWidth, ffxivHeight,, ahk_class FFXIVGAME
	playWidth := 250
	playHeight := 70
	mainWindowX := (ffxivX + ffxivWidth - playWidth * 2)
	mainWindowY := (ffxivY + ffxivHeight / 2 - playHeight * 2)
	
	Gui, PlayWindow: New, +ToolWindow +AlwaysOnTop +E0x08000000
	Gui, PlayWindow:+Owner +OwnDialogs
	Gui, PlayWindow: Show, w%playWidth% h%playHeight% x%mainWindowX% y%mainWindowY%, FFXIV Bard Macro Player 1.0
	
	Gui, Add, DropDownList, w%playWidth% r20 ym-3 xm-20 x0 vFileSelectionControl gLoadMusicFile AltSubmit, ||
	
	Gui, Font, s18, Webdings
	Gui, Add, Button, Hide xs Section w30 h30 vStopControl gStopSubmit, <
	Gui, Add, Button, Hide ys w30 h30 vPlayPauseControl gPausePlaySubmit, `;
	
	Gui, Font, s8 w400, Segoe UI
	Gui, Add, Text, ys w180 vFileLoadedControl, [ BARD Macro Player v1.0 ]`n by Freya Katva @ Ultros
	Gui, Color, 
	Gui, Add, Text, x190 y56 cBlue gLaunchGithub, Project site
		
}
LaunchGithub() {
	Run https://github.com/parulina/bardmacroplayer
}
StopSubmit() {
	Gui, Submit, NoHide
	if(currentPlayer) {
		LoadFile(currentPlayer.filename, currentPlayer.trackIndex)
	}
	UpdateMainWindow()
}
PausePlaySubmit() {
	Gui, Submit, NoHide
	if(currentPlayer) {
		if(currentPlayer.IsPlaying()) {
			currentPlayer.Pause()
		} else {
			currentPlayer.Play()
			WinActivate, ahk_class FFXIVGAME
		}
	}
	UpdateMainWindow()
}

PlayWindowGuiEscape() {
	PlayWindowGuiClose()
}
PlayWindowGuiClose() {
	if(settings["ExitConfirmation"]) {
		xx := mainWindowX + 180
		yy := mainWindowY + 10
		Gui, ExitWindow: Destroy
		Gui, ExitWindow: New, +OwnerPlayWindow +AlwaysOnTop +ToolWindow
		Gui, ExitWindow: Show, w90 h50 x%xx% y%yy%, Exit
		Gui, Add, Text, Section, Exit player?
		Gui, Add, Button, xs Section Default gExitApplication, Yes
		Gui, Add, Button, ys gReturnApplication, No
		Gui, PlayWindow: +Disabled
		return 1
		
	} else {
		ExitApplication()
	}
}

ExitWindowGuiEscape() {
	ExitWindowGuiClose()
}
ExitWindowGuiClose() {
	ReturnApplication()
}

ExitApplication() {
	ExitApp
}

ReturnApplication() {
	Gui, PlayWindow: -Disabled
	Gui, ExitWindow: Destroy
}

SetPlayButtonsVisibility(visible) {
	v := (visible ? 1 : 0)
	GuiControl, Show%v%, StopControl
	GuiControl, Show%v%, PlayPauseControl
}

SetPlayPauseButton(play) {
	if(play) {
		GuiControl,, PlayPauseControl, 4
	} else {
		GuiControl,, PlayPauseControl, `;
	}
}

UpdateMainWindow() {
	UpdateFileList()
	GuiControl,, FileSelectionControl, |
	for i, e in playerFiles {
		f := e
		;if(InStr(e, "\")) {
		;	f := StrSplit(e,"`\")
		;	f := f[f.MaxIndex()]
		;}
		GuiControl,, FileSelectionControl, %f%
	}
	
	SetPlayButtonsVisibility((currentPlayer != 0))
	
	if(currentPlayer) {
		text := currentPlayer.filename
		GuiControl, ChooseString, FileSelectionControl, % text
		if(currentPlayer.trackIndex != 1) {
			text .= "`nTrack "
			text .= currentPlayer.trackIndex
		}
		GuiControl,, FileLoadedControl, % text
		SetPlayPauseButton(!currentPlayer.playing)
	}
}

LoadMusicFile() {
	Gui, Submit, NoHide
	
	filename := playerFiles[FileSelectionControl]
	track := 1
	if(InStr(filename, ".mid ")) {
		pos := InStr(filename, A_Space, false, 0, 1)
		len := StrLen(filename)+1
		track := SubStr(filename, pos+1, len - pos)
		filename := SubStr(filename, 1, pos-1)
	}
	LoadFile(filename, track)
}


UpdateFileList() {
	playerFiles := []
	Loop, songs/* {
		file := "songs/"A_LoopFileFullPath
		if(A_LoopFileExt == "mid") {
			midi := new MidiPlayer(file)
			if(midi.midi.midiNumTracks > 1) {
				Loop % midi.midi.midiNumTracks {
					track := midi.midi.midiTracks[A_Index]
					nn := track.trackNumNotes
					if(nn > 0) {
						sf := file . " "A_Index
						playerFiles.Push(sf)
					}
				}
			} else {
				playerFiles.Push(file)
			}
		}
		if(A_LoopFileExt == "txt") {
			; todo parse and check count
			playerFiles.Push(file)
		}
	}
}
ReadSettings()
ToggleMainWindow()
ReadKeyConfig()
Hotkey, % settings["HideHotkey"], ToggleWindow

ToggleWindow() {
	if(WinActive("ahk_class FFXIVGAME")) {
		Thread, NoTimers
		ReadKeyConfig()
		ToggleMainWindow()
	}
}

LoadFile(file, track := 1) {
	if(currentPlayer) {
		Thread, NoTimers
		currentPlayer.Stop()
	}
	currentPlayer := 0
	if(SubStr(file, -3) == ".mid") {
		currentPlayer := new MidiPlayer(file, track)
		
	} else {
		currentPlayer := new TxtPlayer(file)
	}
	if(currentPlayer) {
		currentPlayer.noteCallback := Func("PlayNoteCallback")
	}
	UpdateMainWindow()
}

PlayNoteCallback(note)
{
	key := NoteKeys[note]
;	MsgBox % key
	ControlSend,, %key%, ahk_class FFXIVGAME
	return
}
