package options;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.Alphabet;

import debug.FPSCounter;

class VisualsSettingsSubState extends BaseOptionsMenu
{
	public static var pauseMusics:Array<String> = ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)'];
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var noteY:Float = 90;
	var fpsRateOption:Option;
	var splashOption:Option;

	public function new()
	{
		title = Language.getPhrase('visuals_menu', 'Visuals Settings');
		rpcTitle = 'Visuals Settings Menu'; //for Discord Rich Presence

		// for note skins and splash skins
		notes = new FlxTypedGroup<StrumNote>();
		splashes = new FlxTypedGroup<NoteSplash>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			notes.add(note);
			
			var splash:NoteSplash = new NoteSplash();
			splash.noteData = i;
			splash.setPosition(note.x, noteY);
			splash.loadSplash();
			splash.visible = false;
			splash.alpha = ClientPrefs.data.splashAlpha;
			splash.animation.finishCallback = name -> splash.visible = false;
			splashes.add(splash);
			
			Note.initializeGlobalRGBShader(i % Note.colArray.length);
			splash.rgbShader.copyValues(Note.globalRgbShaders[i % Note.colArray.length]);
		}

		// options
		var noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		if(noteSkins.length > 0)
		{
			if(!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); //Default skin always comes first
			var option:Option = new Option('Note Skins:',
				"Select your preferred Note skin.",
				'noteSkin',
				STRING,
				noteSkins);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			splashOption = option;
			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
		if(noteSplashes.length > 0)
		{
			if(!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			var option:Option = new Option('Note Splashes:',
				"Select your preferred Note Splash variation or turn it off.",
				'splashSkin',
				STRING,
				noteSplashes);
			addOption(option);
			option.onChange = onChangeSplashSkin;
		}

		var option:Option = new Option('Note Splash Opacity',
			'How much transparent should the Note Splashes be.',
			'splashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 2;
		addOption(option);
		option.onChange = playNoteSplashes;

		var option:Option = new Option('Note Splash Count:',
			'How much the Note Splashes should spawn every arrow?\n0 means no limits for appears splash.',
			'splashCount',
			INT);
		option.scrollSpeed = 30;
		option.minValue = 0;
		option.maxValue = 15;
		option.changeValue = 1;
		addOption(option);
		option.onChange = playNoteSplashes;

		var holdSkins:Array<String> = Mods.mergeAllTextsNamed('images/holdCovers/list.txt');
		if(holdSkins.length > 0)
		{
			if(!holdSkins.contains(ClientPrefs.data.holdSkin))
				ClientPrefs.data.holdSkin = ClientPrefs.defaultData.holdSkin; //Reset to default if saved splashskin couldnt be found
			holdSkins.remove(ClientPrefs.defaultData.holdSkin);
			holdSkins.insert(0, ClientPrefs.defaultData.holdSkin); //Default skin always comes first
			var option:Option = new Option('Hold Splashes:',
				"Select your preferred Hold Splash variation or turn it off.",
				'holdSkin',
				STRING,
				holdSkins);
			addOption(option);
		}

		var option:Option = new Option('Note Hold Splash Opacity',
			'How much transparent should the Note Hold Splash be.\n0% disables it.',
			'holdSplashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Opponent Note Splash',
			'If checked, Note Splash appears in Opponent Strum.',
			'splashOpponent',
			BOOL);
		addOption(option);

		var option:Option = new Option('Strum Animation',
			'If checked, Play animation of strum arrows every note hits.',
			'strumAnim',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Play Animation on Sustain Hit',
			"If unchecked, ignores hit animaiton when hits sustain notes.",
			'holdAnim',
			BOOL);
		addOption(option);

		var option:Option = new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			BOOL);
		addOption(option);

		var option:Option = new Option('3 digits Separator',
			'If checked, Increases the visibility of large numbers, such as 1000 or more.',
			'numberFormat',
			BOOL);
		addOption(option);

		var option:Option = new Option('Show Info:',
			"If checked, shows amount of some infomation in screen.\nwell It's for Debug.",
			'showInfoType',
			STRING,
			[
				'None',
				'Notes Per Second',
				'Rendered Notes',
				'Note Splash Counter',
				'Note Appear Time',
				'Video Info',
				// 'Note Info',
				'Strums Info',
				'Song Info',
				'Music Sync Info',
				'Debug Info',
			]);
		addOption(option);
		
		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			STRING,
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option('Score Text Grow on Hit',
			"If unchecked, disables the Score text growing\neverytime you hit a note.",
			'scoreZoom',
			BOOL);
		addOption(option);

		var option:Option = new Option('Health Bar Opacity',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		var option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			BOOL);
		addOption(option);
		option.onChange = onChangeFPSCounter;
		
		var option:Option = new Option('FC - Update Rate',
			"It can change updating date on FPS Counter.",
			'fpsRate',
			INT);
		option.defaultValue = 1;
		option.scrollSpeed = 30;
		option.minValue = 1;
		option.maxValue = 1000;
		option.changeValue = 1;
		option.decimals = 0;
		option.onChange = onChangeFPSRate;
		addOption(option);
		fpsRateOption = option;

		var option:Option = new Option('Pause Music:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			STRING,
			pauseMusics);
		addOption(option);
		option.onChange = onChangePauseMusic;
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord",
			'discordRPC',
			BOOL);
		addOption(option);
		#end

		var option:Option = new Option('Popup Stacking',
			"If unchecked, The popup won't stack. but it's using recycling system,\nso it doesn't have effects so much.",
			'comboStacking',
			BOOL);
		addOption(option);

		var option:Option = new Option('Combo <-> Notes',
			"If checked, The popup become a note counter instead combo.\nIt appears opponent hits too, and bf and opponent combo are combined.",
			'changeNotes',
			BOOL);
		addOption(option);

		super();
		add(notes);
		add(splashes);
	}

	var notesShown:Bool = false;
	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		switch(curOption.variable)
		{
			case 'noteSkin', 'splashSkin', 'splashAlpha', 'splashCount':
				if(!notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = true;
				if(curOption.variable.startsWith('splash') && Math.abs(notes.members[0].y - noteY) < 25) playNoteSplashes();

			default:
				if(notesShown) 
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = false;
		}
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.data.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), ClientPrefs.data.bgmVolume);

		changedMusic = true;
	}

	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote) {
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
	}

	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		note.texture = skin; //Load texture and anims
		note.reloadNote();
		note.playAnim('static');
	}

	function onChangeSplashSkin()
	{
		for (splash in splashes)
			splash.loadSplash();

		playNoteSplashes();
	}

	function playNoteSplashes()
	{
		for (splash in splashes)
		{
			var anim:String = splash.playDefaultAnim();
			splash.visible = true;
			splash.alpha = ClientPrefs.data.splashAlpha;
			
			var conf = splash.config.animations.get(anim);
			var offsets:Array<Float> = [0, 0];

			if (conf != null)
				offsets = conf.offsets;

			if (offsets != null)
			{
				splash.centerOffsets();
				splash.offset.set(offsets[0], offsets[1]);
			}
		}
	}

	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), ClientPrefs.data.bgmVolume, true);
		super.destroy();
	}

	function onChangeFPSCounter()
	{
		if (Main.fpsVar != null) Main.fpsVar.visible = ClientPrefs.data.showFPS;
		if (Main.fpsBg != null) Main.fpsBg.visible = ClientPrefs.data.showFPS;
	}

	function onChangeFPSRate()
	{
		var rate:Null<Float> = fpsRateOption.getValue();
		fpsRateOption.scrollSpeed = interpolate(30, 50000, (holdTime - 0.5) / 10, 3);
		if (rate != null) FPSCounter.instance.updateRate = rate;
		else FPSCounter.instance.updateRate = 1;
	}
}
