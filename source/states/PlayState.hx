package states;

import flixel.math.FlxRandom;
import haxe.ds.IntMap;
import haxe.Timer;
import haxe.ds.Vector;
import mikolka.JoinedLuaVariables;
import substates.StickerSubState;
import states.FreeplayState;
import mikolka.vslice.freeplay.FreeplayState as NewFreeplayState;
import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;
import cutscenes.DialogueBoxPsych;
import states.StoryMenuState;
import lime.math.Matrix3;
import mikolka.funkin.Scoring;
import mikolka.funkin.custom.FunkinTools;
import mikolka.vslice.results.Tallies;
import mikolka.vslice.results.ResultState;
import openfl.media.Sound;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;
import substates.PauseSubState;
import substates.GameOverSubstate;
#if !flash
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
import shaders.WiggleEffect;
import shaders.PulseEffect;
#end
import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import mikolka.stages.erect.*;
import states.stages.objects.*;
#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end
#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
#end

/**
 * This is where all the Gameplay stuff happens and is managed
 *
 * here's some useful tips if you are making a mod in source:
 *
 * If you want to add your stage to the game, copy states/stages/Template.hx,
 * and put your stage code there, then, on PlayState, search for
 * "switch (curStage)", and add your stage to that list.
 *
 * If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
 *
 * "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
 * "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
 * "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
 * "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
**/
class PlayState extends MusicBeatState
{
	public static var STRUM_X = 50;
	public static var STRUM_X_MIDDLESCROLL = -276;

	private var strumAnim:Bool = ClientPrefs.data.strumAnim;

	public static var ratingStuff:Array<Dynamic> = [
		["wh- really? are you sure???", 0.2], // From 0% to 19%
		["If it's not overcharted, you're just bad.", 0.4], // From 20% to 39%
		["Might you need a practice?", 0.5], // From 40% to 49%
		["Not Bad", 0.6], // From 50% to 59%
		["Ok?", 0.69], // From 60% to 68%
		["Nice", 0.7], // 69%
		["Good", 0.8], // From 70% to 79%
		["Great!", 0.9], // From 80% to 89%
		["Sick!!", 1], // From 90% to 99%
		["ALL SICK?!?", 1] // The value on this one isn't used actually, since Perfect is always "1"
	];
	public var ratingImage:String = "";
	var forceSick:Rating = new Rating('sick');

	// event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedRate:Float = 1;
	public var songSpeedType:String = "multiplicative";
	public final NoteKillTime:Float = 350;
	public var noteKillOffset:Float = 0;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public static var curStage:String = '';
	public static var stageUI:String = "normal";
	public static var isPixelStage(get, never):Bool;
	public var antialias:Bool = true;

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	// ! new shit
	public static var storyCampaignTitle = "";
	public static var storyDifficultyColor = FlxColor.GRAY;

	public var spawnTime:Float = 1500;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var unspawnSustainNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];
	public var sustainAnim:Bool = ClientPrefs.data.holdAnim;

	public var skipGhostNotes:Bool = ClientPrefs.data.skipGhostNotes;
	public var ghostNotesCaught:Int = 0;

	public var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();

	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	public var grpHoldSplashes:FlxTypedGroup<SustainSplash> = new FlxTypedGroup<SustainSplash>();

	public static var splashUsing:Array<Array<NoteSplash>>;
	public static var splashMoment:Vector<Int> = new Vector(8, 0);

	var splashCount:Int = ClientPrefs.data.splashCount != 0 ? ClientPrefs.data.splashCount : 2147483647;
	var splashOpponent:Bool = ClientPrefs.data.splashOpponent;
	var enableSplash:Bool = ClientPrefs.data.splashAlpha != 0;
	var enableHoldSplash:Bool = ClientPrefs.data.holdSplashAlpha != 0;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingFrequency:Float = 4;
	public var camZoomingDecay:Float = 1;

	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;

	private var healthLerp:Float = 1;

	public var combo:Float = 0;
	public var opCombo:Float = 0;
	public var maxCombo:Float = 0;

	public var healthBar:Bar;
	public var timeBar:Bar;

	var songPercent:Float = 0;
	public var nanoPosition:Bool = ClientPrefs.data.nanoPosition;
	public var ratingsData:Array<Rating> = Rating.loadDefault();
	private var generatedMusic:Bool = false;

	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	private var updateTime:Bool = true;

	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	// Recycling PopUps
	public var showPopups:Bool;
	public var showRating:Bool = ClientPrefs.data.showRating;
	public var showComboNum:Bool = ClientPrefs.data.showComboNum;
	public var showCombo:Bool = ClientPrefs.data.showCombo;
	public var changePopup:Bool = ClientPrefs.data.changeNotes;

	// Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;

	public var guitarHeroSustains:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var pressMissDamage:Float = 0.05;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;
	public var infoTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var luaTpadCam:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Float = 0;
	public var songHits:Float = 0;
	public var songMisses:Float = 0;
	public var scoreTxt:FlxText;

	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Float = 0;
	public static var campaignMisses:Float = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public static var campaignSaveData:SaveScoreData = FunkinTools.newTali();

	public var defaultCamZoom:Float = 1.05;
	public var defaultStageZoom:Float = 1.05;

	private static var zoomTween:FlxTween;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	// Achievement shit
	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	public static var instance:PlayState;

	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];
	public var wiggleMap:Map<String, WiggleEffect> = new Map<String, WiggleEffect>();
	#end

	// Shaders
	public var shaderEnabled = ClientPrefs.data.shaders;
	public static var masterPulse:PulseEffect;
	var allowDisable:Bool = false;
	var allowDisableAt:Int = 0;

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end

	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;

	public var songName:String;

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	// Optimizer
	var processFirst:Bool = ClientPrefs.data.processFirst;
	var showNotes:Bool = ClientPrefs.data.showNotes;
	var keepNotes:Bool = ClientPrefs.data.keepNotes;
	var sortNotes:String = ClientPrefs.data.sortNotes;
	var whenSortNotes:Int = 0;
	var noteHitPreEvent:Bool = ClientPrefs.data.noteHitPreEvent;
	var noteHitEvent:Bool = ClientPrefs.data.noteHitEvent;
	var skipNoteScript:Bool = ClientPrefs.data.skipNoteScript;
	var spawnNoteScript:Bool = ClientPrefs.data.spawnNoteScript;
	// var betterRecycle:Bool = ClientPrefs.data.betterRecycle;
	// var cacheNotes:Int = ClientPrefs.data.cacheNotes;
	// var doneCache:Bool = false;
	var skipSpawnNote:Bool = ClientPrefs.data.skipSpawnNote;
	var separateHitProcess:Bool = ClientPrefs.data.separateHitProcess;
	var optimizeSpawnNote:Bool = ClientPrefs.data.optimizeSpawnNote;

	// CoolUtils Shortcut
	var toBool = CoolUtil.bool;
	var toInt = CoolUtil.int;
	var numFormat = CoolUtil.floatToStringPrecision;
	var fillNum = CoolUtil.fillNumber;
	var formatD = CoolUtil.formatMoney;
	var numberSeparate:Bool = ClientPrefs.data.numberFormat;

	// Debug Infomations
	var showInfoType = ClientPrefs.data.showInfoType;

	// songTime but it's based in nano second lmfao.
	public static var nanoTime:Float = 0;
	public static var elapsedNano:Float = 0;
	
	public static var nextReloadAll:Bool = false;

	#if TOUCH_CONTROLS_ALLOWED
	public var luaTouchPad:TouchPad;
	#end

	override public function create()
	{
		this.variables = new JoinedLuaVariables();
		// trace('Playback Rate: ' + playbackRate);
		Paths.clearUnusedMemory();
		Paths.clearStoredMemory();
		if (nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;
		noteKillOffset = NoteKillTime;

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;
		
		if (shaderEnabled) {
			// Rainbow Eyesore Effect
			masterPulse = new PulseEffect();
			masterPulse.waveAmplitude = 1;
			masterPulse.waveFrequency = 2;
			masterPulse.waveSpeed = 1;
			masterPulse.shader.uTime.value[0] = new flixel.math.FlxRandom().float(-100000, 100000);
			masterPulse.shader.uampmul.value[0] = 0;
		}

		PauseSubState.songName = null; // Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = ['note_left', 'note_down', 'note_up', 'note_right'];

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		luaTpadCam = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		luaTpadCam.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		FlxG.cameras.add(luaTpadCam, false);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		// var tmpNote:Note = new Note(0, 0, null);
		// tmpNote.strum = playerStrums.members[0];
		// spawnNoteSplash(tmpNote, -1);
		splashUsing = [[], [], [], [], [], [], [], []];

		persistentUpdate = true;
		persistentDraw = true;

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if (SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;
		defaultStageZoom = defaultCamZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage == true) // Backward compatibility
			stageUI = "pixel";

		antialias = ClientPrefs.data.antialiasing && !isPixelStage;

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if (stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null) // Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage)
		{
			case 'stage': new StageWeek1(); 						//Week 1
			case 'spooky': new Spooky();							//Week 2
			case 'philly': new Philly();							//Week 3
			case 'limo': new Limo();								//Week 4
			case 'mall': new Mall();								//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();						//Week 5 - Winter Horrorland
			case 'school': new School();							//Week 6 - Senpai, Roses
			case 'schoolEvil': new SchoolEvil();					//Week 6 - Thorns
			case 'tank': new Tank();								//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 				//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();				//Weekend 1 - Blazin
			case 'mainStageErect': new MainStageErect();			//Week 1 Special 
			case 'spookyMansionErect': new SpookyMansionErect();	//Week 2 Special 
			case 'phillyTrainErect': new PhillyTrainErect();  		//Week 3 Special 
			case 'limoRideErect': new LimoRideErect();  			//Week 4 Special 
			case 'mallXmasErect': new MallXmasErect(); 				//Week 5 Special 
			case 'phillyStreetsErect': new PhillyStreetsErect(); 	//Weekend 1 Special 
		}
		if (isPixelStage)
			introSoundsSuffix = '-pixel';

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		if (!stageData.hide_girlfriend)
		{
			if (SONG.gfVersion == null || SONG.gfVersion.length < 1)
				SONG.gfVersion = 'gf'; // Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);

		if (stageData.objects != null && stageData.objects.length > 0)
		{
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup,
				boyfriendGroup, this);
			for (key => spr in list)
				if (!StageData.reservedNames.contains(key))
					variables.set(key, spr);
		}
		else
		{
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// "SCRIPTS FOLDER" SCRIPTS
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
			#if linux
			for (file in CoolUtil.sortAlphabetically(Paths.readDirectory(folder)))
			#else
			for (file in Paths.readDirectory(folder))
			#end
		{
			#if LUA_ALLOWED
			if (file.toLowerCase().endsWith('.lua'))
				new FunkinLua(folder + file);
			#end

			#if HSCRIPT_ALLOWED
			if (file.toLowerCase().endsWith('.hx'))
				initHScript(folder + file);
			#end
		}
		#end

		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if (dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);
			if (gf != null)
				gf.visible = false;
		}

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// STAGE SCRIPTS
		#if LUA_ALLOWED startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + curStage + '.hx'); #end

		// CHARACTER SCRIPTS
		if (gf != null)
			startCharacterScripts(gf.curCharacter);
		startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		notesGroup = new FlxTypedGroup<FlxBasic>();
		add(notesGroup);
		
		showPopups = showRating || showComboNum || showCombo;
		if (showPopups) {
			popUpGroup = new FlxTypedSpriteGroup<Popup>();
			add(popUpGroup);
		}

		uiGroup = new FlxSpriteGroup();
		add(uiGroup);

		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.antialiasing = ClientPrefs.data.antialiasing;
		timeTxt.visible = updateTime = showTime;
		if (ClientPrefs.data.downScroll)
			timeTxt.y = FlxG.height - 44;
		if (ClientPrefs.data.timeBarType == 'Song Name')
			timeTxt.text = SONG.song;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		notesGroup.add(strumLineNotes);

		if (ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		generateSong();

		notesGroup.add(grpNoteSplashes);
		notesGroup.add(grpHoldSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function()
		{
			if (ClientPrefs.data.vsliceSmoothBar)
			{
				healthLerp = FlxMath.lerp(healthLerp, health, 0.15);
				return healthLerp;
			}
			return health;
		}, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		scoreTxt.antialiasing = ClientPrefs.data.antialiasing;
		updateScore(false);
		uiGroup.add(scoreTxt);
		
		infoTxt = new FlxText(0, ClientPrefs.data.downScroll ? healthBar.y + 64 : healthBar.y - 48, FlxG.width, "", 32);
		infoTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoTxt.scrollFactor.set();
		infoTxt.borderSize = 1.25;
		infoTxt.visible = true;
		infoTxt.antialiasing = ClientPrefs.data.antialiasing;
		
		if (!ClientPrefs.data.downScroll) {
			switch (ClientPrefs.data.showInfoType) {
				case 'Note Splash Counter' | 'Note Info':
					infoTxt.y -= 40;
				case 'Notes Per Second':
					infoTxt.y -= 80;
			}
		}

		uiGroup.add(infoTxt);

		// Default Value has inherited from HRK Engine
		var botplayTxtY:Float = timeBar.y + (ClientPrefs.data.downScroll ? -80 : 55);
		switch (ClientPrefs.data.vsliceBotPlayPlace) {
			case "Near the Health Bar":
				botplayTxtY = healthBar.y + (ClientPrefs.data.downScroll ? -80 : 70);
			case "Near the Time Bar": // Omitted because nothing has changed.
		}

		botplayTxt = new FlxText(400, botplayTxtY, FlxG.width - 800, Language.getPhrase("Botplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		botplayTxt.antialiasing = ClientPrefs.data.antialiasing;
		uiGroup.add(botplayTxt);

		uiGroup.cameras = [camHUD];
		notesGroup.cameras = [camHUD];
		if (showPopups) {
			popUpGroup.cameras = [camHUD];
		}

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed)
			startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		if (eventNotes.length > 1)
		{
			for (event in eventNotes)
				event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		// SONG SPECIFIC SCRIPTS
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
			#if linux
			for (file in CoolUtil.sortAlphabetically(Paths.readDirectory(folder)))
			#else
			for (file in Paths.readDirectory(folder))
			#end
		{
			#if LUA_ALLOWED
			if (file.toLowerCase().endsWith('.lua'))
				new FunkinLua(folder + file);
			#end

			#if HSCRIPT_ALLOWED
			if (file.toLowerCase().endsWith('.hx'))
				initHScript(folder + file);
			#end
		}
		#end

		#if TOUCH_CONTROLS_ALLOWED
		addHitbox();
		hitbox.visible = true;
		#end

		startCallback();
		recalculateRating();
		if (cpuControlled) ratingImage = forceSick.name;

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		// PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if (ClientPrefs.data.hitsoundVolume > 0)
			Paths.sound('hitsound');
		if (!ClientPrefs.data.ghostTapping)
			for (i in 1...4)
				Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if (Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));

		resetRPC();

		stagesFunc(function(stage:BaseStage) stage.createPost());

		callOnScripts('onCreatePost');

		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; // cant make it invisible or it won't allow precaching

		SustainSplash.startCrochet = Conductor.stepCrochet;
		SustainSplash.frameRate = Math.floor(24 / 100 * SONG.bpm);
		var holdSplash:SustainSplash = new SustainSplash();
		holdSplash.alpha = 0.0001;

		#if (!android && TOUCH_CONTROLS_ALLOWED)
		addTouchPad('NONE', 'P');
		addTouchPadCamera();
		#end

		super.create();
		Paths.clearUnusedMemory();
		switch (sortNotes) {
			case "After Note Spawned": whenSortNotes = 1;
			case "After Note Processed": whenSortNotes = 2;
			case "After Note Finalized": whenSortNotes = 3;
			case "Reversed": whenSortNotes = 4;
			case "Chaostic": whenSortNotes = 5;
			case "Randomized Order": whenSortNotes = 6;
			case "Shuffle": whenSortNotes = 7;
		}

		cacheCountdown();
		cachePopUpScore();

		if (eventNotes.length < 1)
			checkEventNote();

		if (ClientPrefs.data.disableGC) {
			MemoryUtil.enable();
			MemoryUtil.collect(true);
			MemoryUtil.disable();
		}
	}

	function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; // funny word huh
			if (ratio != 1)
			{
				for (note in notes.members)
					note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, NoteKillTime / songSpeed);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if (generatedMusic)
		{
			if (bfVocal) vocals.pitch = value;
			if (opVocal) opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; // funny word huh
			if (ratio != 1)
			{
				for (note in notes.members)
					note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function addTextToDebug(text:String, color:FlxColor)
	{
		var newText:psychlua.DebugLuaText = luaDebugGroup.recycle(psychlua.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:psychlua.DebugLuaText)
		{
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);

		Sys.println(text);
	}
	#end

	public function reloadHealthBarColors()
	{
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function addCharacterToList(newCharacter:String, type:Int)
	{
		switch (type)
		{
			case 0:
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if (gf != null && !gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if (FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getSharedPath(luaFile);
			if (FileSystem.exists(luaFile))
				doPush = true;
		}
		#else
		luaFile = Paths.getSharedPath(luaFile);
		if (Assets.exists(luaFile))
			doPush = true;
		#end

		if (doPush)
		{
			for (script in luaArray)
			{
				if (script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if (doPush)
				new FunkinLua(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(scriptFile);
		if (FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		#end
		{
			scriptFile = Paths.getSharedPath(scriptFile);
			if (FileSystem.exists(scriptFile))
				doPush = true;
		}

		if (doPush)
		{
			if (Iris.instances.exists(scriptFile))
				doPush = false;

			if (doPush)
				initHScript(scriptFile);
		}
		#end
	}

	public function getLuaObject(tag:String, text:Bool = true):FlxSprite
		return variables.get(tag);

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf'))
		{ // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public var videoCutscene:VideoSprite = null;

	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;
		canPause = false;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);

			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = false;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}
			add(videoCutscene);

			if (playOnLoad)
				videoCutscene.play();
			return videoCutscene;
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		else
			addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else
			FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	function startAndEnd()
	{
		if (endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;

	public var psychDialogue:DialogueBoxPsych;

	// You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null)
			return;

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong)
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					endSong();
				}
			}
			else
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		}
		else
		{
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch (stageUI)
		{
			case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
			case "normal": ["ready", "set", "go"];
			default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts)
			Paths.image(asset);

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if (startedCountdown)
		{
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		returnValue = callOnScripts('onStartCountdown', null, true);
		if (returnValue != LuaUtils.Function_Stop)
		{
			if (skipCountdown || startOnTime > 0)
				skipArrowStartTween = true;

			canPause = true;
			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length)
			{
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length)
			{
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				// if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			// Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			botplaySine = Conductor.songPosition * 0.18;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0)
			{
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch (stageUI)
				{
					case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
					case "normal": ["ready", "set", "go"];
					default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var tick:Countdown = THREE;

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6 * ClientPrefs.data.sfxVolume);
						tick = THREE;
					case 1:
						countdownReady = createCountdownSprite(introAlts[0], antialias);
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6 * ClientPrefs.data.sfxVolume);
						tick = TWO;
					case 2:
						countdownSet = createCountdownSprite(introAlts[1], antialias);
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6 * ClientPrefs.data.sfxVolume);
						tick = ONE;
					case 3:
						countdownGo = createCountdownSprite(introAlts[2], antialias);
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6 * ClientPrefs.data.sfxVolume);
						tick = GO;
					case 4:
						tick = START;
				}

				if (!skipArrowStartTween)
				{
					notes.forEachAlive(function(note:Note)
					{
						if (ClientPrefs.data.opponentStrums || note.mustPress)
						{
							note.copyAlpha = false;
							note.alpha = note.multAlpha;
							if (ClientPrefs.data.middleScroll && !note.mustPress)
								note.alpha *= 0.35;
						}
					});
				}

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(notesGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}

	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = unspawnNotes[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				if(!ClientPrefs.data.lowQuality || !showPopups || !cpuControlled) daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = notes.members[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	var returnValue:Dynamic;
	public dynamic function updateScore(miss:Bool = false)
	{
		returnValue = callOnScripts('preUpdateScore', [miss], true);
		if (returnValue == LuaUtils.Function_Stop)
			return;

		updateScoreText();
		if (!miss && !cpuControlled)
			doScoreBop();

		callOnScripts('onUpdateScore', [miss]);
	}

	var updateScoreStr:String;
	var hpShowStr:String;
	var tempScoreStr:String;
	var opComboStr:String;
	var comboStr:String;
	var notesStr:String;
	public dynamic function updateScoreText()
	{
		updateScoreStr = Language.getPhrase('rating_$ratingName', ratingName);
		if (totalPlayed != 0)
			updateScoreStr += ' (${CoolUtil.floorDecimal(ratingPercent * 100, 2)}%) - ' + Language.getPhrase(ratingFC);
		
		hpShowStr = numFormat(health*50, 4 - Std.string(Math.floor(health*50)).length);

		if (!cpuControlled) {
			if (!instakillOnMiss)
				tempScoreStr = Language.getPhrase(
					'score_text',
					'Score: {1} | Misses: {2} | Rating: {3} | HP: {4} %',
					[songScore, songMisses, updateScoreStr, hpShowStr]
				);
			else
				tempScoreStr = Language.getPhrase(
					'score_text_instakill',
					'Score: {1} | Instant Kill Mode - Good Luck! | Rating: {2}',
					[songScore, updateScoreStr]
				);
		} else {
			
			if (numberSeparate) {
				opComboStr = formatD(opCombo);
				comboStr = formatD(combo);
				notesStr = formatD(opCombo + combo);
			} else {
				opComboStr = Std.string(opCombo);
				comboStr = Std.string(combo);
				notesStr = Std.string(opCombo + combo);
			}

			tempScoreStr = Language.getPhrase(
				'score_text_bot',
				'Score: {1} | Combo: {2} + {3} = {4} | HP: {5} %',
				[ songScore, opComboStr, comboStr, notesStr, hpShowStr ]
			);
			
		}
		scoreTxt.text = tempScoreStr;
		hpShowStr = null;
	}

	public dynamic function fullComboFunction()
	{
		ratingFC = "";
		if (songMisses == 0)
		{
			if (ratingsData[2].hits > 0 || ratingsData[3].hits > 0)
				ratingFC = 'FC';
			else if (ratingsData[1].hits > 0)
				ratingFC = 'GFC';
			else if (ratingsData[0].hits > 0)
				ratingFC = 'SFC';
		}
		else
		{
			if (songMisses < 10)
				ratingFC = 'SDCB';
			else
				ratingFC = 'Clear';
		}
	}

	public function doScoreBop():Void
	{
		if (!ClientPrefs.data.scoreZoom)
			return;

		if (scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween)
			{
				scoreTxtTween = null;
			}
		});
	}

	public function setSongTime(time:Float)
	{
		if (!inStarting) {
			FlxG.sound.music.pause();
			if (bfVocal) vocals.pause();
			if (opVocal) opponentVocals.pause();

			FlxG.sound.music.time = time - Conductor.offset;
			#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
			FlxG.sound.music.play();

			if (bfVocal) {
				if (Conductor.songPosition < vocals.length)
				{
					vocals.time = time - Conductor.offset;
					#if FLX_PITCH vocals.pitch = playbackRate; #end
					vocals.play();
					vocals.volume = ClientPrefs.data.bgmVolume;
				}
				else vocals.pause();
			}

			if (opVocal) {
				if (Conductor.songPosition < opponentVocals.length)
				{
					opponentVocals.time = time - Conductor.offset;
					#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
					opponentVocals.play();
					opponentVocals.volume = ClientPrefs.data.bgmVolume;
				}
				else opponentVocals.pause();
			}
		}
		Conductor.songPosition = time;
	}

	public function startNextDialogue()
	{
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue()
	{
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	var inStarting:Bool = false;
	var started:Bool = false;
	function startSong():Void
	{
		startingSong = false;
		inStarting = true; // prevent play inst double times

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, ClientPrefs.data.bgmVolume, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		if (bfVocal) {
			vocals.play();
			vocals.volume = ClientPrefs.data.bgmVolume;
		}
		if (opVocal) {
			opponentVocals.play();
			opponentVocals.volume = ClientPrefs.data.bgmVolume;
		}

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if (paused)
		{
			// trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			if (bfVocal) vocals.pause();
			if (opVocal) opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if (autoUpdateRPC)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');

		inStarting = false;
		started = true;
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	private var totalColumns:Int = 4;

	public var bfVocal:Bool = false; // a.k.a. legacy voices
	public var opVocal:Bool = false;

	private function generateSong():Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch (songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = opponentVocals = null;
		try
		{
			if (songData.needsVoices)
			{
				var legacyVoices = Paths.voices(songData.song);
				if (legacyVoices == null)
				{
					var playerVocals = Paths.voices(songData.song,
						(boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
					vocals = new FlxSound().loadEmbedded(playerVocals);
					bfVocal = true;

					var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
					if (oppVocals != null && oppVocals.length > 0) {
						opponentVocals = new FlxSound().loadEmbedded(oppVocals);
						opVocal = true;
					}
				}
				else {
					vocals = new FlxSound().loadEmbedded(legacyVoices);
					bfVocal = true;
				}
			}
		}
		catch (e:Dynamic)
		{
		}

		#if FLX_PITCH
		if (bfVocal) vocals.pitch = playbackRate;
		if (opVocal) opponentVocals.pitch = playbackRate;
		#end
		if (bfVocal) FlxG.sound.list.add(vocals);
		if (opVocal) FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic)
		{
		}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		notesGroup.add(notes);

		try
		{
			var eventsChart:SwagSong = Song.getChart('events', songName);
			if (eventsChart != null)
				for (event in eventsChart.events) // Event Notes
					for (i in 0...event[1].length)
						makeEvent(event, i);
		} catch (e:Dynamic) {}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var daBpm:Float = Conductor.bpm;

		var cnt:Float = 0;
		var notes:Float = 0;

		var sectionNoteCnt:Float = 0;
		var shownProgress:Bool = false;
		var sustainNoteCnt:Float = 0;
		var sustainTotalCnt:Float = 0;

		var songNotes:Array<Dynamic> = [];
		var strumTime:Float;
		var noteColumn:Int;
		var holdLength:Float;
		var noteType:String;

		var gottaHitNote:Bool;

		var swagNote:Note;
		var roundSus:Int;
		var curStepCrochet:Float;
		var sustainNote:Note;

		var updateTime:Float = 0.1;
		var syncTime:Float = Timer.stamp();

		function showProgress(force:Bool = false) {
			if (Main.isConsoleAvailable)
			{
				if (Timer.stamp() - syncTime > updateTime || force)
				{
					Sys.stdout().writeString('\x1b[0GLoading $cnt/${sectionsData.length} (${notes + sectionNoteCnt} notes)');
					syncTime = Timer.stamp();
				}
			}
		}

		for (section in sectionsData)
		{
			++cnt;
			sectionNoteCnt = 0;
			shownProgress = false;
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i in 0...section.sectionNotes.length)
			{
				songNotes = section.sectionNotes[i];
				strumTime = songNotes[0];
				noteColumn = Std.int(songNotes[1] % totalColumns);
				holdLength = songNotes[2];
				noteType = songNotes[3];
				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				gottaHitNote = (songNotes[1] < totalColumns);

				swagNote = new Note(strumTime, noteColumn, oldNote);
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = section.altAnim && !gottaHitNote ? "-alt" : "";
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = holdLength;
				swagNote.noteType = noteType;

				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);
				oldNote = swagNote;

				curStepCrochet = 60 / daBpm * 250;
				roundSus = Math.round(swagNote.sustainLength / curStepCrochet);
				if (roundSus > 0)
				{
					for (susNote in 0...roundSus + 1)
					{
						sustainNote = new Note(strumTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						unspawnSustainNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if (!PlayState.isPixelStage)
						{
							if (oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
							}

							if (ClientPrefs.data.downScroll)
								sustainNote.correctionOffset = 0;
						}
						else if (oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
						}

						if (sustainNote.mustPress)
							sustainNote.x += FlxG.width / 2; // general offset
						else if (ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if (noteColumn > 1) // Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}

						++sustainNoteCnt;
						oldNote = sustainNote;
					}
					sustainTotalCnt += sustainNoteCnt;
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if (ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if (noteColumn > 1) // Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}
				if (!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				showProgress();
				++sectionNoteCnt;
			}

			showProgress();
			notes += sectionNoteCnt;
		}

		showProgress(true);
		if (skipGhostNotes) {
			Sys.println('\nSorting for remove overlaps...');
			unspawnNotes.sort(sortByTime);
			var prev:Note;
			var tmpNotes:Array<Note>;
			var tmpSusNotes:Array<Note>;

			for (i in 0...4) {
				for (j in 0...2) {
					// CLEAR ANY POSSIBLE GHOST NOTE
					Sys.println('Removing Overlapped Notes... (Pass ${i*2+j+1}/8)');
					
					prev = unspawnNotes[unspawnNotes.length-1];

					tmpNotes = unspawnNotes.filter( n -> n.noteData == i && n.mustPress == toBool(j) );
					tmpSusNotes = unspawnSustainNotes.filter( n -> n.noteData == i && n.mustPress == toBool(j) );

					for (evil in tmpNotes) {
						if (prev.strumTime == evil.strumTime) {
							if (prev.noteType == evil.noteType) {
								evil.destroy();
								unspawnNotes.remove(evil);
								ghostNotesCaught++;
							}
						}
						prev = evil;
					}

					for (sussy in tmpSusNotes) {
						if (prev.strumTime == sussy.strumTime) {
							if (prev.noteType == sussy.noteType) {
								sussy.destroy();
								unspawnSustainNotes.remove(sussy);
								ghostNotesCaught++;
							}
						}
						prev = sussy;
					}
				}
			}
		}

		Sys.println('\n[ --- "${SONG.song.toUpperCase()}" CHART INFO --- ]');
		Sys.println('Loaded $notes notes!');
		for (event in songData.events) // Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);

		if (skipGhostNotes) {
			if (ghostNotesCaught > 0)
				Sys.println('Overlapped Notes Cleared: $ghostNotesCaught');
			else {
				Sys.println('WOW! There is no overlapped notes. Great charting!');
			}
		}

		Sys.println('Merging Notes...');
		for (susNote in unspawnSustainNotes)
		{
			unspawnNotes.push(susNote);
		}
		unspawnSustainNotes.resize(0);
		unspawnNotes.sort(sortByTime);

		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote)
	{
		eventPushedUnique(event);
		if (eventsPushed.contains(event.event))
		{
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote)
	{
		switch (event.event)
		{
			case "Change Character":
				var charType:Int = 0;
				switch (event.value1.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if (Math.isNaN(val1))
							val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); // Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float
	{
		returnValue = Std.parseFloat(callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true, [], [0]));
		if (!Math.isNaN(returnValue) && returnValue != 0)
		{
			return returnValue;
		}

		switch (event.event)
		{
			case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
				return 280; // Plays 280ms before the actual position
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [
			subEvent.event,
			subEvent.value1 != null ? subEvent.value1 : '',
			subEvent.value2 != null ? subEvent.value2 : '',
			subEvent.strumTime
		]);
	}

	public var skipArrowStartTween:Bool = false; // for lua

	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		var chochet:Float = Conductor.crochet;
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if (!ClientPrefs.data.opponentStrums)
					targetAlpha = 0;
				else if (ClientPrefs.data.middleScroll)
					targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			skipArrowStartTween = skipArrowStartTween || chochet <= ClientPrefs.data.framerate * 1000;
			if (!isStoryMode && !skipArrowStartTween)
			{
				babyArrow.y -= 640 / (i+1);
				babyArrow.alpha = 0;
				babyArrow.angle = -2 * Math.PI;
				FlxTween.tween(
					babyArrow, 
					{
						y: babyArrow.y + 640 / (i+1),
						alpha: targetAlpha,
						angle: 0
					},
					chochet * (4-i),
					{
						ease: FlxEase.circOut,
						startDelay: (chochet * (i+1))
					}
				);
			}
			else
				babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
			{
				if (ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if (i > 1)
					{ // Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				if (bfVocal) vocals.pause();
				if (opVocal) opponentVocals.pause();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished)
				tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished)
				twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;

	override function closeSubState()
	{
		super.closeSubState();

		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished)
				tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished)
				twn.active = true);

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}
	}

	override public function onFocus():Void
	{
		if (health > 0 && !paused)
			resetRPC(Conductor.songPosition > 0.0);
		if (FlxG.autoPause && nanoPosition) nanoTime = CoolUtil.getNanoTime();
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		#if DISCORD_ALLOWED
		if (health > 0 && !paused && autoUpdateRPC)
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end

		if (FlxG.autoPause && nanoPosition) nanoTime = CoolUtil.getNanoTime();
		trace(nanoTime);

		super.onFocusLost();
	}

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; // performance setting for custom RPC things

	function resetRPC(?showTime:Bool = false)
	{
		#if DISCORD_ALLOWED
		if (!autoUpdateRPC)
			return;

		if (showTime)
			DiscordClient.changePresence(detailsText, SONG.song
				+ " ("
				+ storyDifficultyText
				+ ")", iconP2.getCharacter(), true,
				songLength
				- Conductor.songPosition
				- ClientPrefs.data.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	var thresholdTime:Float = 20;
	var desyncCount:Float = 0;
	var desyncTime:Float = 0;
	var desyncBf:Float = 0;
	var desyncOp:Float = 0;
	function checkSync() {
		desyncTime = Math.abs(FlxG.sound.music.time - Conductor.songPosition);

		if (desyncTime > thresholdTime)	resyncVocals();

		if (bfVocal) {
			desyncBf = Math.abs(vocals.time - Conductor.songPosition);
			if (desyncBf > thresholdTime) resyncVocals();
		}

		if (opVocal) {
			desyncOp = Math.abs(opponentVocals.time - Conductor.songPosition);
			if (desyncOp > thresholdTime) resyncVocals();
		}
	}

	function resyncVocals():Void
	{
		if (finishTimer != null)
			return;

		desyncCount++;
		#if debug trace('resynced vocals at ' + Math.floor(Conductor.songPosition)); #end

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (voc == null) continue;
			if (FlxG.sound.music.time < voc.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			} else voc.pause();
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var freezeCamera:Bool = false;
	var allowDebugKeys:Bool = true;

	// Time
	public var timeout:Float = ClientPrefs.data.nanoPosition ? CoolUtil.getNanoTime() : Timer.stamp();
	var globalElapsed:Float = 0;
	var shownTime:Float = 0;
	var shownRealTime:Float = 0;
	var canBeHit:Bool = false;
	var tooLate:Bool = false;
	var noteSpawnJudge:Bool = false;
	var safeTime:Float = 0;
	var frameCount:Int = 0;

	// Spawning
	var totalCnt:Int = 0;
	var targetNote:Note = null;
	var dunceNote:Note = null;
	var strumGroup:FlxTypedGroup<StrumNote>;

	// Popup
	var popUpHitNote:Note = null;
	var popUpDebug:Vector<Int> = new Vector(4, 0);

	// Hit Management
	var hit:Int = 0;
	var globalNoteHit:Bool = false;
	var daHit:Bool = false;
	var bfHit:Bool = false;

	// Rendering Counter
	public var shownMax:Int = 0;
	var skipCnt:Int = 0;
	var skipBf:Int = 0;
	var skipOp:Int = 0;
	var skipTotalCnt:Float = 0;
	var skipMax:Int = 0;

	// Infomation
	public var debugInfos:Bool = false;
	public var debugInfoType:Int = 0;

	// NPS
	var npsTime:Int;
	var npsMod:Bool = false;
	var bothNpsAdd:Bool = false;
	
	var nps:IntMap<Float> = new IntMap<Float>();
	var opNps:IntMap<Float> = new IntMap<Float>();
	var bfNpsVal:Float = 0;
	var opNpsVal:Float = 0;
	var bfNpsMax:Float = 0;
	var opNpsMax:Float = 0;
	var totalNpsVal:Float = 0;
	var totalNpsMax:Float = 0;
	var npsControlled:Int = 0;
	var bfNpsAdd:Float = 0;
	var opNpsAdd:Float = 0;
	var bfSideHit:Float = 0;
	var opSideHit:Float = 0;

	override public function update(elapsed:Float)
	{
		daHit = bfHit = false;
		if (popUpHitNote != null) popUpHitNote = null;
		hit = skipBf = skipOp = 0;

		splashMoment.fill(0);

		if (nanoPosition) {
			if (frameCount <= 2) elapsedNano = FlxG.elapsed; // Sync the timing
			else elapsedNano = CoolUtil.getNanoTime() - nanoTime;
			
			globalElapsed = elapsedNano * playbackRate;
			nanoTime = CoolUtil.getNanoTime();
		} else {
			globalElapsed = FlxG.elapsed * playbackRate;
		}
		
		if (startedCountdown && !paused) {
			Conductor.songPosition += globalElapsed * 1000;
		}
		
		if (!inCutscene && !paused && !freezeCamera)
		{
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			if (!startingSong && !endingSong && boyfriend.getAnimationName().startsWith('idle'))
			{
				boyfriendIdleTime += globalElapsed;
				if (boyfriendIdleTime >= 0.15)
				{ // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			}
			else
			{
				boyfriendIdleTime = 0;
			}
		}
		else
			FlxG.camera.followLerp = 0;
		callOnScripts('onUpdate', [globalElapsed]);

		super.update(globalElapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if (botplayTxt != null && botplayTxt.visible)
		{
			botplaySine += 180 * globalElapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE #if android || FlxG.android.justReleased.BACK #end && startedCountdown && canPause)
		{
			returnValue = callOnScripts('onPause', null, true);
			if (returnValue != LuaUtils.Function_Stop)
			{
				openPauseMenu();
			}
		}

		if (!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
				openChartEditor();
			else if (controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (startedCountdown && !paused)
		{
			if (Conductor.songPosition >= Conductor.offset)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-globalElapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if (!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float;
			var songCalc:Float;
			var secondsTotal:Int;

			curTime = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			songCalc = (songLength - curTime);
			if (ClientPrefs.data.timeBarType == 'Time Elapsed')
				songCalc = curTime;

			secondsTotal = Math.floor(songCalc / 1000);
			if (secondsTotal < 0)
				secondsTotal = 0;

			if (ClientPrefs.data.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}

		if (camZooming)
		{
			var ratio = Math.exp(-globalElapsed * 3.125 * camZoomingDecay);
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, ratio);
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, ratio);
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (started && !paused && canResync) {
			checkSync();
		}

		if (!processFirst) {
			noteSpawn();
			noteUpdate();
		} else {
			noteUpdate();
			noteSpawn();
		}
		noteFinalize();
		
		if (whenSortNotes > 3) {
			noteSort();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		updateIconsScale(globalElapsed);
		updateIconsPosition();

		// Shader Update Zone
		if (shaderEnabled) {
			for(wig in wiggleMap) {
				wig.update(globalElapsed);
			}

			if (allowDisableAt == curStep || isDead)
				allowDisable = true;

			if (allowDisable)
				masterPulse.shader.uampmul.value[0] -= (globalElapsed / 2);

			if (masterPulse.shader.uampmul.value[0] > 0)
				masterPulse.update(globalElapsed);
		}

		if (showPopups && popUpHitNote != null) {
			popUpScore(popUpHitNote);
		}

		// NPS Zone
		if (showInfoType == "Notes Per Second" && !paused) {
			if (npsMod) {
				if (globalNoteHit) {
					if (opNpsAdd > 0) {
						opSideHit -= bothNpsAdd ? opSideHit : Math.max(opSideHit, bfSideHit);
						doAnim(null, true, false);
					}
					if (bfNpsAdd > 0) {
						bfSideHit -= bothNpsAdd ? bfSideHit : Math.max(opSideHit, bfSideHit);
						doAnim(null, false, true);
					}
					npsMod = false;
				}
				opSideHit += opNpsAdd * globalElapsed;
				bfSideHit += bfNpsAdd * globalElapsed;
			}
			npsTime = Math.round(Conductor.songPosition);

			if (opSideHit > 0) opNps.set(npsTime, opSideHit);
			if (bfSideHit > 0) nps.set(npsTime, bfSideHit);

			for (key => value in opNps) {
				if (key + 1000 > npsTime) {
					if (opSideHit > 0) {
						opNpsVal += opSideHit;
						opSideHit = 0;
					} else continue;
				} else {
					opNpsVal -= value;
					opNps.remove(key);
				}
			}

			for (key => value in nps) {
				if (key + 1000 > npsTime) {
					if (bfSideHit > 0) {
						bfNpsVal += bfSideHit;
						bfSideHit = 0;
					} else continue;
				} else {
					bfNpsVal -= value;
					nps.remove(key);
				}
			}

			totalNpsVal = opNpsVal + bfNpsVal;

			totalNpsMax = Math.max(totalNpsVal, totalNpsMax);
			opNpsMax = Math.max(opNpsVal, opNpsMax);
			bfNpsMax = Math.max(bfNpsVal, bfNpsMax);
		}

		if (debugInfos) {
			if (FlxG.keys.justPressed.UP) ++debugInfoType;
			if (FlxG.keys.justPressed.DOWN) --debugInfoType;

			if (debugInfoType >= 3) debugInfoType -= 3;
			if (debugInfoType < 0) debugInfoType += 3;

			popUpDebug.fill(0); popUpAlive = 0;
			if (showPopups) {
				popUpGroup.forEach(lmfao -> {
					switch (lmfao.type) {
						case NONE: ++popUpDebug[0];
						case RATING: ++popUpDebug[1];
						case COMBO: ++popUpDebug[2];
						case NUMBER: ++popUpDebug[3];
					}
				});
			}

			for (index in 0...popUpDebug.length) {
				if (index != 0)
					popUpAlive += popUpDebug[index];
			}
		}

		if (showInfoType != "None") {
			var info:String = "";
			switch (showInfoType) {
				case 'Notes Per Second':
					var nps:Array<Float> = [
						Math.fround(opNpsVal),
						Math.fround(bfNpsVal),
						Math.fround(totalNpsVal),
						Math.fround(opNpsMax),
						Math.fround(bfNpsMax),
						Math.fround(totalNpsMax),
					];

					var opNpsStr:String = fillNum(nps[0], Std.string(nps[3]).length, ' '.fastCodeAt(0));
					var bfNpsStr:String = fillNum(nps[1], Std.string(nps[4]).length, ' '.fastCodeAt(0));
					var totalNpsStr:String = fillNum(nps[2], Std.string(nps[5]).length, ' '.fastCodeAt(0));

					info = '$opNpsStr/${nps[3]}\n$bfNpsStr/${nps[4]}\n$totalNpsStr/${nps[5]}';
					nps = null; opNpsStr = bfNpsStr = totalNpsStr = null;
				case 'Rendered Notes':
					shownMax = notes.length > shownMax ? notes.length : shownMax;

					skipMax = skipCnt > skipMax ? skipCnt : skipMax;
					if (numberSeparate)
						info = 'Rendered/Skipped: ${formatD(notes.length)}/${formatD(skipCnt)}/${formatD(shownMax)}/${formatD(skipMax)}\n';
					else
						info = 'Rendered/Skipped: ${notes.length}/$skipCnt/$shownMax/$skipMax\n';
					// info = 'Rendered/Skipped: ${notes.length}/$shownMax\n';
				case 'Note Splash Counter':
					var buf:StringBuf = new StringBuf();
					buf.add("[");
					for (index => splash in splashUsing) {
						buf.add(splash.length.hex());
						if (index < splashUsing.length-1)
							buf.add(",");
					} buf.add("]\n[");
					for (i in 0...splashMoment.length) {
						buf.add(splashMoment[i].hex());
						if (i < splashMoment.length-1)
							buf.add(",");
					} buf.add("]");
					info = buf.toString();
					buf = null;
				case 'Note Appear Time':
					info = "Speed: " + CoolUtil.decimal(songSpeed, 3)
						+ " / Time: " + CoolUtil.decimal(shownTime, 3)
						+ " ms / Capacity: " + CoolUtil.floatToStringPrecision(safeTime, 1)
						+ " % / Skip: " + skipTotalCnt;
				case 'Video Info':
					info = numFormat((CoolUtil.getNanoTime() - elapsedNano) * 1000, 1) + " ms / " + (numberSeparate ? formatD(frameCount) : Std.string(frameCount));
				// case 'Note Info':
				// 	info = CoolUtil.hex2bin(noteDataInfo.hex(4));
				// 	if (dunceNote != null) info += '\nX:${fillNum(dunceNote.x, 5, 32)}, W:${fillNum(dunceNote.width, 5, 32)}, Offset:${fillNum(dunceNote.offset.x, 5, 32)}';
				case 'Strums Info':
					var additional:Int = 0;
					for (strums in [opponentStrums, playerStrums]) {
						for (strum in strums) {
							switch(strum.animation.curAnim.name) {
								case "static": additional = 0;
								case "press": additional = 1;
								case "confirm": additional = 2;
							}
							info += ', $additional';
						}
					}
					info = info.substr(2);
				case 'Song Info':
					info = 'BPM: ${Conductor.bpm}, Sections: ${curSection+1}/${Math.max(curBeat+1,0)}/${Math.max(curStep+1,0)}, Update Cnt: ${updateMaxSteps}';
				case 'Music Sync Info':
					info = 'Desync: ('
						 + numFormat(desyncTime, 1)
						 + (bfVocal ? ('/' + numFormat(desyncBf, 1)) : "")
						 + (opVocal ? ('/' + numFormat(desyncOp, 1)) : "")
						 + ') Sync Count: $desyncCount';
				case 'Debug Info':
					debugInfos = true;
					switch (debugInfoType) {
						case 0:
							/* if (Std.isOfType(notes, NoteGroup)) {
								var f:Array<Float>;
								f = notes.debugInfo();
								info = '${f[0]}, ${f[1]}, ${f[2]}';
							} else { */
								info = 'Up/Down Key to change infomation';
							// }
						case 1:
							info = '${numFormat(dad != null ? dad.holdTimer : Math.NaN, 3)}, '
								 + '${numFormat(gf != null ? gf.holdTimer : Math.NaN, 3)}, '
								 + '${numFormat(boyfriend != null ? boyfriend.holdTimer : Math.NaN, 3)}';
						case 2:
							if (showPopups) {
								info = '${popUpDebug[0]}, '
									 + '${popUpDebug[1]}, '
									 + '${popUpDebug[2]}, '
									 + '${popUpDebug[3]}, '
									 + '$popUpAlive / ${popUpGroup.length}';
							} else {
								info = 'No Popups';
							}
					}
			}
			infoTxt.text = info;
			info = null;
		} else {
			infoTxt.text = null;
		}

		updateScoreText();

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if (FlxG.keys.justPressed.TWO)
			{ // Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnScripts('botPlay', cpuControlled);
		callOnScripts('onUpdatePost', [globalElapsed]);

		#if debug
		if (FlxG.keys.justPressed.F1)
		{
			KillNotes();
			endSong();
		}
		#end

		++frameCount;
	}

	// Health icon updaters
	public dynamic function updateIconsScale(time:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-time * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-time * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	var skipNote:Note = new Note(0, 0);
	var isCanPass:Bool = false;
	var isDisplay:Bool = false;
	var timeLimit:Bool = false;
	public function noteSpawn()
	{
		timeout = nanoPosition ? CoolUtil.getNanoTime() : Timer.stamp();
		if (unspawnNotes.length > totalCnt)
		{
			targetNote = unspawnNotes[totalCnt];
			shownTime = showNotes ? targetNote.isSustainNote ? Math.max(spawnTime / songSpeed, Conductor.stepCrochet) : spawnTime / songSpeed : 0;
			shownRealTime = shownTime * 0.001;
			isDisplay = targetNote.strumTime - Conductor.songPosition < shownTime;

			while (isDisplay)
			{
				canBeHit = Conductor.songPosition > targetNote.strumTime;
				tooLate = Conductor.songPosition > targetNote.strumTime + noteKillOffset;
				timeLimit = (nanoPosition ? CoolUtil.getNanoTime() : Timer.stamp()) - timeout < shownRealTime;

				if (keepNotes) 
					 isCanPass = !skipSpawnNote || timeLimit || !tooLate;
				else isCanPass = !skipSpawnNote || timeLimit;

				if (isCanPass) {
					dunceNote = targetNote;
					dunceNote.spawned = true;
	
					strumGroup = !dunceNote.mustPress ? opponentStrums : playerStrums;
					dunceNote.strum = strumGroup.members[dunceNote.noteData];
					if (dunceNote.isSustainNote) dunceNote.resizeByRatio(songSpeedRate);
					notes.add(dunceNote);
					
					if (spawnNoteScript) {
						callOnLuas('onSpawnNote', [
							totalCnt,
							dunceNote.noteData,
							dunceNote.noteType,
							dunceNote.isSustainNote,
							dunceNote.strumTime
						]);
						callOnHScript('onSpawnNote', [dunceNote]);
					}
					
					if (optimizeSpawnNote) {
						if (!canBeHit && dunceNote.strum != null) dunceNote.followStrumNote(songSpeed / playbackRate);
						else {
							if (dunceNote.mustPress)
							{
								if (cpuControlled && (!dunceNote.blockHit || dunceNote.isSustainNote))
									goodNoteHit(dunceNote);
							}
							else if (!dunceNote.hitByOpponent && !dunceNote.ignoreNote)
								opponentNoteHit(dunceNote);
		
							if (dunceNote.isSustainNote && dunceNote.strum.sustainReduce)
								dunceNote.clipToStrumNote();
						}
					}
				} else {
					// Skip notes without spawning
					targetNote.mustPress ? ++skipBf : ++skipOp;
					skipNote = targetNote;
				}
				
				unspawnNotes[totalCnt] = null; ++totalCnt;
				if (unspawnNotes.length > totalCnt) targetNote = unspawnNotes[totalCnt]; else break;
				isDisplay = targetNote.strumTime - Conductor.songPosition < shownTime;
			}
		}
		safeTime = ((nanoPosition ? CoolUtil.getNanoTime() : Timer.stamp()) - timeout) / shownRealTime * 100;
		
		if (whenSortNotes == 1)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
	}

	var index:Int = 0;
	var noteUpdateJudge:Bool = false;
	public function noteUpdate()
	{
		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (!cpuControlled)
					keysCheck();
				else
					playerDance();

				if (notes.length > 0)
				{
					if (startedCountdown)
					{
						index = notes.length - 1;
						var daNote:Note;

						while(index >= 0) {
							daNote = notes.members[index];
							canBeHit = Conductor.songPosition - daNote.strumTime > 0;
							tooLate = Conductor.songPosition - daNote.strumTime > noteKillOffset;

							if (!separateHitProcess || !tooLate) daNote.followStrumNote(songSpeed);

							if (canBeHit && !tooLate) {
								if (daNote.mustPress) {
									if (cpuControlled)
										if (!daNote.blockHit && daNote.canBeHit || daNote.isSustainNote)
											goodNoteHit(daNote);
								} else if (!daNote.hitByOpponent && !daNote.ignoreNote || daNote.isSustainNote)
									opponentNoteHit(daNote);

								if (daNote.isSustainNote && daNote.strum.sustainReduce) {
									daNote.clipToStrumNote();
								}
							}
							if (tooLate) {
								// Kill extremely late notes and cause misses
								if (daNote.mustPress)
								{
									if (cpuControlled)
										goodNoteHit(daNote);
									else if (!daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit)) {
										// trace(noteKillOffset, Conductor.stepCrochet);
										noteMiss(daNote);
									}
								} else if (!daNote.hitByOpponent)
									opponentNoteHit(daNote);

								if (daNote != null) invalidateNote(daNote);
							}
							--index;
						}
						
						daNote = null;
					}
					else
					{
						notes.forEachAlive(daNote ->
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		if (whenSortNotes == 2)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
	}

	var skipResult:Dynamic = null;
	var skipDaNote:Note = null;
	var skipArray:Array<Dynamic> = [];
	var skipAnim:Array<Bool> = [];
	inline public function noteFinalize() {
		skipDaNote = skipNote;
		opCombo += skipOp;
		combo += skipBf;
		skipCnt = skipOp + skipBf;
		skipTotalCnt += skipCnt;

		skipAnim.push(skipCnt > 0);
		skipAnim.push(skipOp > 0);
		skipAnim.push(skipBf > 0);

		if (skipAnim[0]) {
			doAnim(skipDaNote, skipAnim[1], skipAnim[2]);
			if (showPopups) {
				if (!changePopup && skipAnim[2]) popUpHitNote = skipDaNote;
				else if (changePopup && skipAnim[0]) popUpHitNote = skipDaNote;
			}
		}

		if (skipNoteScript && skipAnim[0]) {
			skipArray = [0,Math.abs(skipDaNote.noteData), skipDaNote.noteType, skipDaNote.isSustainNote];
			for (i in 0...skipOp) {
				if (noteHitPreEvent) {
					skipResult = callOnLuas('opponentNoteHitPre', skipArray);
		
					if (skipResult != LuaUtils.Function_Stop) {
						if(skipResult != LuaUtils.Function_StopHScript && skipResult != LuaUtils.Function_StopAll)
							skipResult = callOnHScript('opponentNoteHitPre', [skipDaNote]);
					}
				}
				if (noteHitEvent) {
					skipResult = callOnLuas('opponentNoteHit', skipArray);
		
					if (skipResult != LuaUtils.Function_Stop) {
						if(skipResult != LuaUtils.Function_StopHScript && skipResult != LuaUtils.Function_StopAll)
							skipResult = callOnHScript('opponentNoteHitPre', [skipDaNote]);
					}
				}
			}
			for (i in 0...skipBf) {
				if (noteHitPreEvent) {
					skipResult = callOnLuas('goodNoteHitPre', skipArray);
		
					if (skipResult != LuaUtils.Function_Stop) {
						if(skipResult != LuaUtils.Function_StopHScript && skipResult != LuaUtils.Function_StopAll)
							skipResult = callOnHScript('opponentNoteHitPre', [skipDaNote]);
					}
				}
				if (noteHitEvent) {
					skipResult = callOnLuas('goodNoteHit', skipArray);
		
					if (skipResult != LuaUtils.Function_Stop) {
						if(skipResult != LuaUtils.Function_StopHScript && skipResult != LuaUtils.Function_StopAll)
							skipResult = callOnHScript('opponentNoteHitPre', [skipDaNote]);
					}
				}
			}
		}

		if (whenSortNotes == 3)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
	}
	
	var randomize = new FlxRandom();
	
	inline private function noteSort() {
		switch (whenSortNotes) {
			case 4:
				notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.DESCENDING : FlxSort.ASCENDING);
			case 5:
				if (frameCount & 1 == 1) {
					notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.DESCENDING : FlxSort.ASCENDING);
				} else {
					notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
				}
			case 6:
				if (randomize.bool(50)) {
					notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.DESCENDING : FlxSort.ASCENDING);
				} else {
					notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
				}
			case 7:
				randomize.shuffle(notes.members);
		}
	}

	var altAnim:String;
	var currNote:SwagSection;
	var holdTime:Float = Conductor.stepCrochet / 1000;

	/**
	 * Force dance animation on the character.
	 * if objectNote is null, It uses bf and daddy flag
	 * for decide target to animation. that case, 
	 * girlfriend will never dance.
	 * 
	 * @param objectNote 
	 * @param bf 
	 * @param daddy 
	 */
	private function doAnim(objectNote:Note, daddy:Bool, bf:Bool) {
		var isNullNote = objectNote == null;
		if (!isNullNote) {
			if (objectNote.mustPress) {
				if (bf) return;
				else bf = bfHit = true;
			} else if (!objectNote.mustPress) {
				if (daddy) return;
				else daddy = daHit = true;
			}

			strumPlayAnim(!objectNote.mustPress, objectNote.noteData);
			char = objectNote.gfNote ? gf : objectNote.mustPress ? boyfriend : dad;
		} else {
			if (daddy) {
				if (daHit) return;
				char = dad;
				daHit = true;
			}
			if (bf) {
				if (bfHit) return;
				char = boyfriend;
				bfHit = true;
			}
			char = daddy && !bf ? !daddy && bf ? boyfriend : dad : null;
		}

		if (char != null)
		{
			if (!isNullNote) {
				altAnim = objectNote.animSuffix;
				currNote = SONG.notes[curSection];
				animCheck = objectNote.gfNote ? 'cheer' : 'hey';
				animToPlay = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, objectNote.noteData)))];
			} else {
				currNote = null;
				animToPlay = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, FlxG.random.int(0, 4))))];
			}

			if (currNote != null) {
				if (currNote.altAnim && !currNote.gfSection)
					altAnim = '-alt';
			} else if (altAnim != '') altAnim = '';

			char.playAnim(animToPlay + altAnim, true);
			char.holdTimer = 0;

			if (!isNullNote && objectNote.noteType == 'Hey!') {
				if (char.animOffsets.exists(animCheck)) {
					char.playAnim(animCheck, true);
					char.specialAnim = true;
					char.heyTimer = 0.6;
				}
			}
		}
	}

	var iconsAnimations:Bool = true;

	function set_health(value:Float):Float // You can alter how icon animations work here
	{
		// value = FlxMath.roundDecimal(value, 5); // Fix Float imprecision
		if (!iconsAnimations || healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		// update health bar
		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max),
			healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		healthBar.percent = (newPercent != null ? newPercent : 0);

		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0; // If health is under 20%, change player icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : 0; // If health is over 80%, change opponent icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		return health;
	}

	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.pause();
			if (bfVocal) vocals.pause();
			if (opVocal) opponentVocals.pause();
		}
		if (!cpuControlled)
		{
			for (note in playerStrums)
				if (note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if (autoUpdateRPC)
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	public function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		chartingMode = true;
		paused = true;

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		if (bfVocal) vocals.pause();
		if (opVocal) opponentVocals.pause();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if (bfVocal) vocals.pause();
		if (opVocal) opponentVocals.pause();

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	public var isDead:Bool = false; // Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;

	function doDeathCheck(?skipHealthCheck:Bool = false)
	{
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null)
		{
			returnValue = callOnScripts('onGameOver', null, true);
			if (returnValue != LuaUtils.Function_Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.setFilters([]);

				if (GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						if (bfVocal) vocals.stop();
						if (opVocal) opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					if (bfVocal) vocals.stop();
					if (opVocal) opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if (autoUpdateRPC)
					DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote()
	{
		while (eventNotes.length > 0)
		{
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime)
			{
				return;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if (eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float)
	{
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if (Math.isNaN(flValue1))
			flValue1 = null;
		if (Math.isNaN(flValue2))
			flValue2 = null;

		switch (eventName)
		{
			case 'Hey!':
				var value:Int = 2;
				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				if (flValue2 == null || flValue2 <= 0)
					flValue2 = 0.6;

				if (value != 0)
				{
					if (dad.curCharacter.startsWith('gf'))
					{ // Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					}
					else if (gf != null)
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if (value != 1)
				{
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if (flValue1 == null || flValue1 < 1)
					flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if (ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
				{
					if (flValue1 == null)
						flValue1 = 0.015;
					if (flValue2 == null)
						flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				// trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch (value2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if (flValue2 == null)
							flValue2 = 0;
						switch (Math.round(flValue2))
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if (camFollow != null)
				{
					isCameraOnForcedPos = false;
					if (flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if (flValue1 == null)
							flValue1 = 0;
						if (flValue2 == null)
							flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val))
							val = 0;

						switch (val)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length)
				{
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null)
						duration = Std.parseFloat(split[0].trim());
					if (split[1] != null)
						intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration))
						duration = 0;
					if (Math.isNaN(intensity))
						intensity = 0;

					if (duration > 0 && intensity != 0)
					{
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:Int = 0;
				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if (Math.isNaN(charType)) charType = 0;
				}

				switch (charType)
				{
					case 0:
						if (boyfriend.curCharacter != value2)
						{
							if (!boyfriendMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if (dad.curCharacter != value2)
						{
							if (!dadMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if (!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf')
							{
								if (wasGf && gf != null)
								{
									gf.visible = true;
								}
							}
							else if (gf != null)
							{
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if (gf != null)
						{
							if (gf.curCharacter != value2)
							{
								if (!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if (flValue1 == null)
						flValue1 = 1;
					if (flValue2 == null)
						flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					
					if (flValue2 <= 0) {
						songSpeed = newValue;
						songSpeedRate = flValue1;
					} else {
						songSpeedTween = FlxTween.tween(
							this,
							{
								songSpeed: newValue,
								songSpeedRate: flValue1
							},
							flValue2 / playbackRate,
							{
								ease: FlxEase.linear,
								onComplete: function(twn:FlxTween)
								{
									songSpeedTween = null;
								}
							}
						);
					}
				}
			case 'Vslice Scroll Speed':
				if (songSpeedType != "constant")
				{
					if (flValue1 == null) flValue1 = 1;
					if (flValue2 == null) flValue2 = 0;

					var newValue:Float = ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if (flValue2 <= 0) {
						songSpeed = newValue;
						songSpeedRate = flValue1;
					} else {
						songSpeedTween = FlxTween.tween(
							this, 
							{
								songSpeed: newValue,
								songSpeedRate: flValue1
							}, 
							flValue2 / playbackRate, 
							{
								ease: FlxEase.quadInOut,
								onComplete: function(twn:FlxTween)
								{
									songSpeedTween = null;
								}
							}
						);
					}
				}
			case 'Set Property':
				try
				{
					var trueValue:Dynamic = value2.trim();
					if (trueValue == 'true' || trueValue == 'false')
						trueValue = trueValue == 'true';
					else if (flValue2 != null)
						trueValue = flValue2;
					else
						trueValue = value2;

					var split:Array<String> = value1.split('.');
					if (split.length > 1)
					{
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1], trueValue);
					}
					else
					{
						LuaUtils.setVarInArray(this, value1, trueValue);
					}
				}
				catch (e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if (len <= 0)
						len = e.message.length;
					#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}

			case 'Rainbow Eyesore':
				if (shaderEnabled && ClientPrefs.data.flashing)
				{
					allowDisable = false;
					allowDisableAt = Std.parseInt(value1);
					FlxG.camera.setFilters([new ShaderFilter(masterPulse.shader)]);
					
					masterPulse.waveAmplitude = 1;
					masterPulse.waveFrequency = 2;
					masterPulse.waveSpeed = Std.parseFloat(value2);
					masterPulse.shader.uTime.value[0] = new flixel.math.FlxRandom().float(-100000, 100000);
					masterPulse.shader.uampmul.value[0] = 1;
					masterPulse.enabled = true;
				}
	
			case 'Play Sound':
				if (flValue2 == null)
					flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2 * ClientPrefs.data.sfxVolume);
			case 'SetCameraBop': // P-slice event notes
				var val1 = Std.parseFloat(value1);
				var val2 = Std.parseFloat(value2);
				camZoomingMult = !Math.isNaN(val2) ? val2 : 1;
				camZoomingFrequency = !Math.isNaN(val1) ? val1 : 4;
			case 'ZoomCamera': // defaultCamZoom
				var keyValues = value1.split(",");
				if (keyValues.length != 2)
				{
					trace("INVALID EVENT VALUE");
					return;
				}
				var floaties = keyValues.map(s -> Std.parseFloat(s));
				if (mikolka.funkin.utils.ArrayTools.findIndex(floaties, s -> Math.isNaN(s)) != -1)
				{
					trace("INVALID FLOATIES");
					return;
				}
				var easeFunc = LuaUtils.getTweenEaseByString(value2);
				if (zoomTween != null)
					zoomTween.cancel();
				var targetZoom = floaties[1] * defaultStageZoom;
				zoomTween = FlxTween.tween(this, {defaultCamZoom: targetZoom}, (Conductor.stepCrochet / 1000) * floaties[0], {
					onStart: (x) ->
					{
						// camZooming = false;
						camZoomingDecay = 7;
					},
					ease: easeFunc,
					onComplete: (x) ->
					{
						defaultCamZoom = targetZoom;
						camZoomingDecay = 1;
						// camZooming = true;
						zoomTween = null;
					}
				});
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	public function moveCameraSection(?sec:Null<Int>):Void
	{
		if (sec == null)
			sec = curSection;
		if (sec < 0)
			sec = 0;

		if (SONG.notes[sec] == null)
			return;

		if (gf != null && SONG.notes[sec].gfSection)
		{
			moveCameraToGirlfriend();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		if (isDad)
			callOnScripts('onMoveCamera', ['dad']);
		else
			callOnScripts('onMoveCamera', ['boyfriend']);
	}

	public function moveCameraToGirlfriend()
	{
		camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
		camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
		tweenCamIn();
	}

	var cameraTwn:FlxTween;

	public function moveCamera(isDad:Bool)
	{
		if (isDad)
		{
			if (dad == null)
				return;
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			if (boyfriend == null)
				return;
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {
					ease: FlxEase.elasticInOut,
					onComplete: function(twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn()
	{
		if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {
				ease: FlxEase.elasticInOut,
				onComplete: function(twn:FlxTween)
				{
					cameraTwn = null;
				}
			});
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		if (bfVocal) {
			vocals.volume = 0;
			vocals.pause();
		}
		if (opVocal) {
			opponentVocals.volume = 0;
			opponentVocals.pause();
		}

		if (ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset)
		{
			endCallback();
		}
		else
		{
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer)
			{
				endCallback();
			});
		}
	}

	public var transitioning = false;

	public function endSong()
	{
		#if TOUCH_CONTROLS_ALLOWED
		hitbox.visible = #if !android touchPad.visible = #end false;
		#end
		//Should kill you if you tried to cheat
		if(!startingSong)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			});
			for (daNote in unspawnNotes)
			{
				if(daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			}

			if(doDeathCheck()) {
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
		#end

		returnValue = callOnScripts('onEndSong', null, true);
		var accPts = ratingPercent * totalPlayed;
		if (returnValue != LuaUtils.Function_Stop && !transitioning)
		{
			var tempActiveTallises = {
				score: songScore,
				accPoints: accPts,

				sick: ratingsData[0].hits,
				good: ratingsData[1].hits,
				bad: ratingsData[2].hits,
				shit: ratingsData[3].hits,
				missed: songMisses,
				combo: combo,
				maxCombo: maxCombo,
				totalNotesHit: totalPlayed,
				totalNotes: 69.0,
			};

			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;
				campaignSaveData = FunkinTools.combineTallies(campaignSaveData, tempActiveTallises);

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					var prevScore = Highscore.getWeekScore(WeekData.weeksList[storyWeek], storyDifficulty);
					var wasFC = Highscore.getWeekFC(WeekData.weeksList[storyWeek], storyDifficulty);
					var prevAcc = Highscore.getWeekAccuracy(WeekData.weeksList[storyWeek], storyDifficulty);

					var prevRank = Scoring.calculateRankFromData(prevScore, prevAcc, wasFC);
					// FlxG.sound.playMusic(Paths.music('freakyMenu'));
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					canResync = false;

					if (!practiceMode && !cpuControlled)
					{
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						var weekAccuracy = FlxMath.bound(campaignSaveData.accPoints / campaignSaveData.totalNotesHit, 0, 1);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty, weekAccuracy, campaignMisses == 0);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					zoomIntoResultsScreen(prevScore < campaignSaveData.score, campaignSaveData, prevRank);
					campaignSaveData = FunkinTools.newTali();

					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, false, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					canResync = false;
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState(), false, false);
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				var wasFC = Highscore.getFCState(curSong, PlayState.storyDifficulty);
				var prevScore = Highscore.getScore(curSong, PlayState.storyDifficulty);
				var prevAcc = Highscore.getRating(curSong, PlayState.storyDifficulty);

				var prevRank = Scoring.calculateRankFromData(prevScore, prevAcc, wasFC);

				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

				canResync = false;
				
				zoomIntoResultsScreen(prevScore < tempActiveTallises.score, tempActiveTallises, prevRank);
				changedDifficulty = false;
			}

			#if !switch
			if (!practiceMode && !cpuControlled)
			{
				var percent:Float = ratingPercent;
				if (Math.isNaN(percent))
					percent = 0;
				Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent, songMisses == 0);
			}
			#end

			transitioning = true;
		}
		return true;
	}

	/**
	 * Play the camera zoom animation and then move to the results screen once it's done.
	 */
	function zoomIntoResultsScreen(isNewHighscore:Bool, scoreData:SaveScoreData, prevScoreRank:ScoringRank):Void
	{
		if (!ClientPrefs.data.vsliceResults || cpuControlled)
		{
			var resultingAccuracy = Math.min(1, scoreData.accPoints / scoreData.totalNotesHit);
			var fpRank = Scoring.calculateRankFromData(scoreData.score, resultingAccuracy, scoreData.missed == 0) ?? SHIT;
			if (isNewHighscore && !isStoryMode)
			{
				camOther.fade(FlxColor.BLACK, 0.6, false, () ->
				{
					if (ClientPrefs.data.vsliceFreeplay) {
						FlxTransitionableState.skipNextTransOut = true;
						FlxG.switchState(() -> NewFreeplayState.build({
							{
								fromResults: {
									oldRank: prevScoreRank,
									newRank: fpRank,
									songId: curSong,
									difficultyId: Difficulty.getString(),
									playRankAnim: !cpuControlled
								}
							}
						}));
					} else {
						MusicBeatState.switchState(new FreeplayState());
						FlxG.sound.playMusic(Paths.music('freakyMenu'), ClientPrefs.data.bgmVolume);
						changedDifficulty = false;
					}
				});
			}
			else if (!isStoryMode)
			{
				if (ClientPrefs.data.vsliceFreeplay) {
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					openSubState(new StickerSubState(null, (sticker) -> NewFreeplayState.build({
						{
							fromResults: {
								oldRank: null,
								playRankAnim: false,
								newRank: fpRank,
								songId: curSong,
								difficultyId: Difficulty.getString()
							}
						}
					}, sticker)));
				} else {
					FlxTransitionableState.skipNextTransIn = false;
					FlxTransitionableState.skipNextTransOut = false;
					MusicBeatState.switchState(new FreeplayState());
					FlxG.sound.playMusic(Paths.music('freakyMenu'), ClientPrefs.data.bgmVolume);
					changedDifficulty = false;
				}
			}
			else
			{
				openSubState(new StickerSubState(null, (sticker) -> new StoryMenuState(sticker)));
			}
			return;
		}
		trace('WENT TO RESULTS SCREEN!');

		// If the opponent is GF, zoom in on the opponent.
		// Else, if there is no GF, zoom in on BF.
		// Else, zoom in on GF.
		var targetDad:Bool = dad != null && dad.curCharacter == 'gf';
		var targetBF:Bool = gf == null && !targetDad;

		if (targetBF)
		{
			FlxG.camera.follow(boyfriend, null, 0.05);
		}
		else if (targetDad)
		{
			FlxG.camera.follow(dad, null, 0.05);
		}
		else
		{
			FlxG.camera.follow(gf, null, 0.05);
		}

		// TODO: Make target offset configurable.
		// In the meantime, we have to replace the zoom animation with a fade out.
		FlxG.camera.targetOffset.y -= 350;
		FlxG.camera.targetOffset.x += 20;

		// Replace zoom animation with a fade out for now.
		FlxG.camera.fade(FlxColor.BLACK, 0.6);

		FlxTween.tween(camHUD, {alpha: 0}, 0.6, {
			onComplete: function(_)
			{
				moveToResultsScreen(isNewHighscore, scoreData, prevScoreRank);
			}
		});

		// Zoom in on Girlfriend (or BF if no GF)
		new FlxTimer().start(0.8, function(_)
		{
			if (targetBF)
			{
				boyfriend.animation.play('hey');
			}
			else if (targetDad)
			{
				dad.animation.play('cheer');
			}
			else
			{
				gf.animation.play('cheer');
			}

			// Zoom over to the Results screen.
			// TODO: Re-enable this.
			/*
						  FlxTween.tween(FlxG.camera, {zoom: 1200}, 1.1,
				{
				  ease: FlxEase.expoIn,
				});
			 */
		});
	}

	/**
	 * Move to the results screen right goddamn now.
	 */
	function moveToResultsScreen(isNewHighscore:Bool, scoreData:SaveScoreData, prevScoreRank:ScoringRank):Void
	{
		persistentUpdate = false;

		var modManifest = Mods.getPack();
		var fpText = modManifest != null ? '${curSong} from ${modManifest.name}' : curSong;
		// Mods.loadTopMod();

		if (bfVocal) vocals.stop();
		camHUD.alpha = 1;

		var res:ResultState = new ResultState({
			storyMode: isStoryMode,
			songId: curSong,
			difficultyId: Difficulty.getString(),
			title: isStoryMode ? ('${storyCampaignTitle}') : fpText,
			scoreData: scoreData,
			prevScoreRank: prevScoreRank,
			isNewHighscore: isNewHighscore,
			characterId: SONG.player1
		});
		this.persistentDraw = false;
		openSubState(res);
	}

	public function KillNotes()
	{
		while (notes.length > 0)
		{
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Float = 0.0;
	public var totalNotesHit:Float = 0.0;
	
	// Stores Ratings and Combo Sprites in a group
	public var popUpGroup:FlxTypedSpriteGroup<Popup>;
	// Stores HUD Objects in a Group
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	public var notesGroup:FlxTypedGroup<FlxBasic>;
	
	var uiPrefix:String = "";
	var uiPostfix:String = '';

	private function cachePopUpScore()
	{
		uiPrefix = '';
		uiPostfix = '';
		if (stageUI != "normal")
		{
			uiPrefix = '${stageUI}UI/';
			if (PlayState.isPixelStage)
				uiPostfix = '-pixel';
		}

		if (showPopups)
		{
			for (rating in ratingsData)
				Paths.image(uiPrefix + rating.image + uiPostfix);
			for (i in 0...10)
				Paths.image(uiPrefix + 'num' + i + uiPostfix);
		}
	}
	
	var noteDiff:Float;
	var score:Float;
	var daRating:Rating;

	inline private function addScore(note:Note = null):Void
	{
		if (note == null) return;
		noteDiff = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		if (!cpuControlled && bfVocal) vocals.volume = ClientPrefs.data.bgmVolume;

		score = 350;

		//tryna do MS based judgment due to popular demand
		daRating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if(!practiceMode && !cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				if (!cpuControlled) recalculateRating();
			}
		}
	}

	var ratingPop:Popup = null;
	var comboPop:Popup = null;
	var numScore:Popup = null;
	var popUpAlive:Float = 0;
	private function popUpScore(note:Note = null):Void
	{
		var daloop:Null<Int> = 0;

		var seperatedScore:Array<Null<Float>> = [];
		var tempCombo:Null<Float> = changePopup ? combo + opCombo : combo;
		var tempNotes:Null<Float> = tempCombo;
		
		var xThing:Null<Float> = 0;

		if (!ClientPrefs.data.comboStacking && popUpGroup.members.length > 0) {
			for (spr in popUpGroup) {
				spr.kill();
				popUpGroup.remove(spr);
			}
		}

		if (showRating && note.mustPress) {
			ratingImage = cpuControlled ? forceSick.image : daRating.image;

			ratingPop = popUpGroup.recycle(Popup);
			ratingPop.setupRatingData(uiPrefix + ratingImage + uiPostfix);
			ratingPop.ratingOtherStuff();
			popUpGroup.add(ratingPop);
		}

		if (showCombo && combo >= 10) {
			comboPop = popUpGroup.recycle(Popup);
			comboPop.setupComboData(uiPrefix + 'combo' + uiPostfix);
			comboPop.comboOtherStuff();
			popUpGroup.add(comboPop);
		}

		if (showComboNum) {
			while(tempCombo >= 10) {
				seperatedScore.unshift(Std.int(tempCombo / 10) % 10);
				tempCombo = Std.int(tempCombo / 10);
			}
			seperatedScore.push(tempNotes % 10);

			for (i in seperatedScore)
			{	
				if (changePopup || combo >= 10 || combo == 0) {
					numScore = popUpGroup.recycle(Popup);
					numScore.setupNumberData(uiPrefix + 'num' + Std.int(i) + uiPostfix, daloop, tempNotes);

					if (showComboNum) popUpGroup.add(numScore);

					numScore.numberOtherStuff();

					if (numScore.x > xThing) xThing = numScore.x;
					++daloop;
				}
			}
		}

		// sorting shits
		// try {
		popUpGroup.sort(
			(order, p1, p2) -> {
				if (p1 != null && p2 != null) {
					return FlxSort.byValues(FlxSort.ASCENDING, p1.popUpTime, p2.popUpTime);
				} else return 0;
			}
		);
		// } catch (e:haxe.Exception) { trace(popUpGroup.length); } // idk why but popUpGroup became null some cases

		for (i in seperatedScore) i = null;
		daloop = null; tempCombo = xThing = null;
	}

	public var strumsBlocked:Array<Bool> = [];

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			// Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey))
				return;
			#end

			if (FlxG.keys.checkStatus(eventKey, JUST_PRESSED))
				keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if (cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || boyfriend.stunned)
			return;

		returnValue = callOnScripts('onKeyPressPre', [key]);
		if (returnValue == LuaUtils.Function_Stop)
			return;

		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if (Conductor.songPosition >= 0)
			Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool
		{
			var canHit:Bool = n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		if (plrInputNotes.length != 0)
		{ // slightly faster than doing `> 0` lol
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1)
			{
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData)
				{
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
			}
			goodNoteHit(funnyNote);
			popUpScore(funnyNote);
		}
		else
		{
			if (ClientPrefs.data.ghostTapping)
				callOnScripts('onGhostTap', [key]);
			else
				noteMissPress(key);
		}

		// Needed for the  "Just the Two of Us" achievement.
		//									- Shadow Mario
		if (!keysPressed.contains(key))
			keysPressed.push(key);

		// more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = playerStrums.members[key];
		if (strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if (!controls.controllerMode && key > -1)
			keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if (cpuControlled || !startedCountdown || paused || key < 0 || key >= playerStrums.length)
			return;

		returnValue = callOnScripts('onKeyReleasePre', [key]);
		if (returnValue == LuaUtils.Function_Stop)
			return;

		var spr:StrumNote = playerStrums.members[key];
		if (spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if (key == noteKey)
						return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if (pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !inCutscene && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0)
			{
				for (n in notes)
				{ // I can't do a filter here, that's kinda awesome
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote)
					{
						var released:Bool = !holdArray[n.noteData];

						if (!released)
							goodNoteHit(n);
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
				playerDance();

			#if ACHIEVEMENTS_ALLOWED
			else
				checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if ((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if (releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void
	{ // You didn't hit the key and let it go offscreen, also used by Hurt Notes
		// Dupe note remove
		notes.forEachAlive(function(note:Note)
		{
			if (daNote != note
				&& daNote.mustPress
				&& daNote.noteData == note.noteData
				&& daNote.isSustainNote == note.isSustainNote
				&& Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});

		final end:Note = daNote.isSustainNote ? daNote.parent.tail[daNote.parent.tail.length - 1] : daNote.tail[daNote.tail.length - 1];
		if (end != null && end.extraData['holdSplash'] != null) {
			end.extraData['holdSplash'].visible = false;
		}

		noteMissCommon(daNote.noteData, daNote);
		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		result = callOnLuas('noteMiss', [
			notes.members.indexOf(daNote),
			daNote.noteData,
			daNote.noteType,
			daNote.isSustainNote
		]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll)
			callOnHScript('noteMiss', [daNote]);
		result = null;
	}

	function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.data.ghostTapping)
			return; // fuck it

		noteMissCommon(direction);
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		// score and data
		var subtract:Float = pressMissDamage;
		if (note != null)
			subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null)
		{
			if (note.tail.length > 0)
			{
				note.alpha = 0.35;
				for (childNote in note.tail)
				{
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				// subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -Tahir
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote)
		{
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0)
			{
				for (child in parentNote.tail)
					if (child != note)
					{
						child.missed = true;
						child.canBeHit = false;
						child.ignoreNote = true;
						child.tooLate = true;
					}
			}
		}

		if (instakillOnMiss)
		{
			if (bfVocal) vocals.volume = 0;
			if (opVocal) opponentVocals.volume = 0;
			doDeathCheck(true);
		}

		var lastCombo:Float = combo;
		combo = 0;

		health -= subtract * healthLoss;
		if (!practiceMode)
			songScore -= 10;
		if (!endingSong)
			songMisses++;
		totalPlayed++;
		recalculateRating(true);

		// play character anims
		var char:Character = boyfriend;
		if ((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection))
			char = gf;

		if (char != null && (note == null || !note.noMissAnimation) && char.hasMissAnimations)
		{
			var postfix:String = '';
			if (note != null)
				postfix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, direction)))] + 'miss' + postfix;
			char.playAnim(animToPlay, true);

			if (char != gf && lastCombo > 5 && gf != null && gf.hasAnimation('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		if (bfVocal) vocals.volume = 0;
	}

	var result:Dynamic;
	var char:Character;
	var animToPlay:String;
	var canPlay:Bool;
	var holdAnim:String;
	function opponentNoteHit(note:Note):Void
	{
		if (note.hitByOpponent) return;

		if (noteHitPreEvent) {
			result = callOnLuas('opponentNoteHitPre', [
				notes.members.indexOf(note),
				Math.abs(note.noteData),
				note.noteType,
				note.isSustainNote
			]);

			if (result != LuaUtils.Function_Stop) {
				if(result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll)
					result = callOnHScript('opponentNoteHitPre', [note]);
			} else {
				result = null;
				return;
			}
			result = null;
		}

		if (songName != 'tutorial')
			camZooming = true;
		globalNoteHit = true;

		if (daHit && !note.isSustainNote && note.sustainLength > 0) daHit = false;
		
		if (!daHit) {
			if (note.noteType == 'Hey!' && dad.hasAnimation('hey'))
			{
				dad.playAnim('hey', true);
				dad.specialAnim = true;
				dad.heyTimer = 0.6;
			}
			else if (!note.noAnimation)
			{
				char = dad;
				animToPlay = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))] + note.animSuffix;
				if (note.gfNote)
					char = gf;

				if (char != null)
				{
					canPlay = !note.isSustainNote || sustainAnim;
					if (note.isSustainNote)
					{
						holdAnim = animToPlay + '-hold';
						if (char.animation.exists(holdAnim))
							animToPlay = holdAnim;
						if (char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop')
							canPlay = false;
					}

					if (canPlay)
						char.playAnim(animToPlay, true);
					char.holdTimer = 0;
				}
			}
		}

		if (bfVocal) vocals.volume = ClientPrefs.data.bgmVolume;
		if (opVocal) opponentVocals.volume = ClientPrefs.data.bgmVolume;
		strumPlayAnim(true, note.noteData);

		note.hitByOpponent = true;

		stagesFunc(stage -> stage.goodNoteHit(note));

		if (noteHitEvent) {
			result = callOnLuas('opponentNoteHit', [
				notes.members.indexOf(note),
				Math.abs(note.noteData),
				note.noteType,
				note.isSustainNote
			]);
			if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll)
				callOnHScript('opponentNoteHit', [note]);
			result = null;
		}

		if (enableSplash && splashOpponent && !note.noteSplashData.disabled) 
			spawnHoldSplashOnNote(note);

		if (!note.isSustainNote) {
			if (enableSplash && splashOpponent && !note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);
			
			++opCombo; ++opSideHit; daHit = true;
			if (showPopups && changePopup) popUpHitNote = note;
			invalidateNote(note);
		}
	}

	var animCheck:String;
	public function goodNoteHit(note:Note):Void
	{
		if (note.wasGoodHit || cpuControlled && note.ignoreNote)
			return;
		
		if (noteHitPreEvent) {
			result = callOnLuas('goodNoteHitPre', [
				notes.members.indexOf(note),
				Math.round(Math.abs(note.noteData)),
				note.noteType,
				note.isSustainNote
			]);
			
			if (result != LuaUtils.Function_Stop) {
				if(result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll)
					result = callOnHScript('opponentNoteHitPre', [note]);
			} else {
				result = null;
				return;
			}
			result = null;
		}

		note.wasGoodHit = true;

		if (!bfHit && note.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);

		if (bfHit && !note.isSustainNote && note.sustainLength > 0) bfHit = false;

		if (!note.hitCausesMiss) // Common notes
		{
			if (!bfHit && !note.noAnimation)
			{
				animToPlay = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))] + note.animSuffix;

				char = boyfriend;
				animCheck = 'hey';
				if (note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}

				if (char != null)
				{
					canPlay = !note.isSustainNote || sustainAnim;
					if (note.isSustainNote)
					{
						holdAnim = animToPlay + '-hold';
						if (char.animation.exists(holdAnim))
							animToPlay = holdAnim;
						if (char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop')
							canPlay = false;
					}

					if (canPlay) {
						char.playAnim(animToPlay, true);
					}
					char.holdTimer = 0;

					if (note.noteType == 'Hey!')
					{
						if (char.hasAnimation(animCheck))
						{
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}
				}
			}

			if (!cpuControlled)
			{
				playerStrums.members[note.noteData].playAnim('confirm', true);
			}
			strumPlayAnim(false, note.noteData);
			if (bfVocal) vocals.volume = ClientPrefs.data.bgmVolume;

			if (!note.isSustainNote)
			{
				++combo; ++bfSideHit; globalNoteHit = true;
				maxCombo = Math.max(maxCombo, combo);
				if (showPopups) popUpHitNote = note;
				addScore(note);
			}

			bfHit = true;

			if (!guitarHeroSustains || !note.isSustainNote)
				health += note.hitHealth * healthGain;
		}
		else // Notes that count as a miss if you hit them (Hurt notes for example)
		{
			if (!bfHit && !note.noMissAnimation)
			{
				switch (note.noteType)
				{
					case 'Hurt Note':
						if (boyfriend.hasAnimation('hurt'))
						{
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
							bfHit = true;
						}
				}
			}

			noteMiss(note);
		}
		if (enableSplash && !note.noteSplashData.disabled) {
			spawnHoldSplashOnNote(note);
			if (!note.isSustainNote) spawnNoteSplashOnNote(note);
		}

		stagesFunc(stage -> stage.goodNoteHit(note));

		if (noteHitEvent) {
			result = callOnLuas('goodNoteHit', 
				[
					notes.members.indexOf(note),
					Math.round(Math.abs(note.noteData)),
					note.noteType,
					note.isSustainNote
				]
			);

			if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll)
				callOnHScript('goodNoteHit', [note]);
			result = null;
		}

		if (!note.isSustainNote) invalidateNote(note);
	}

	public function invalidateNote(note:Note):Void {
		if(!ClientPrefs.data.lowQuality || !showPopups || !cpuControlled) note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function spawnHoldSplashOnNote(note:Note) {
		if (ClientPrefs.data.holdSplashAlpha <= 0) return;

		if (note != null)
			if(note.strum != null) 
				if(note.tail.length != 0)
					spawnHoldSplash(note);
	}

	var sustainEnd:Note = null;
	var susplash:SustainSplash = null;
	var cnt:Int = 0;
	var holdSplashStrum:StrumNote = null;

	public function spawnHoldSplash(note:Note) {
		sustainEnd = note.isSustainNote ? note.parent.tail[note.parent.tail.length - 1] : note.tail[note.tail.length - 1];
		susplash = grpHoldSplashes.recycle(SustainSplash);

		holdSplashStrum = note.mustPress ? playerStrums.members[note.noteData] : opponentStrums.members[note.noteData];
		if (note.strum != splashStrum) note.strum = holdSplashStrum;

		susplash.setupSusSplash(note, playbackRate);
		susplash.strumNote = note.strum;
		grpHoldSplashes.add(sustainEnd.noteHoldSplash = susplash);
	}
	
	var splashNoteData:Int = 0;
	var frames:Int = -1;
	var frameId:Int = -1;
	var targetSplash:NoteSplash = null;
	var splashStrum:StrumNote;

	public function spawnNoteSplashOnNote(note:Note)
	{
		if (!note.mustPress && !splashOpponent)
			return;
		splashNoteData = note.noteData + (note.mustPress ? 4 : 0);
		if (splashMoment[splashNoteData] < splashCount)
		{
			frameId = frames = -1;
			splashStrum = note.mustPress ? playerStrums.members[note.noteData] : opponentStrums.members[note.noteData];
			if (note.strum != splashStrum) note.strum = splashStrum;
			
			if (splashUsing[splashNoteData].length >= splashCount)
			{
				for (index => splash in splashUsing[splashNoteData])
				{
					if (splash.alive && frames < splash.animation.curAnim.curFrame)
					{
						frames = splash.animation.curAnim.curFrame;
						frameId = index;
						targetSplash = splash;
					}
				}
				// trace(splashNoteData, splashUsing[splashNoteData].length, frameId);
				if (frameId != -1) targetSplash.killLimit(frameId);
			}
			spawnNoteSplash(note, splashNoteData);
			++splashMoment[splashNoteData];
		}
	}

	var playerSplash:NoteSplash;

	public function spawnNoteSplash(note:Note = null, splashNoteData:Int = -1)
	{
		playerSplash = grpNoteSplashes.recycle(NoteSplash);
		playerSplash.babyArrow = note.strum;
		// trace(splashNoteData);
		playerSplash.spawnSplashNote(note, splashNoteData);
		if (splashNoteData >= 0) {
			splashUsing[splashNoteData].push(playerSplash);
		}
		grpNoteSplashes.add(playerSplash);
	}

	override function destroy()
	{
		if (psychlua.CustomSubstate.instance != null)
		{
			closeSubState();
			resetSubState();
		}

		#if LUA_ALLOWED
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if (script != null)
			{
				script.executeFunction('onDestroy');
				script.destroy();
			}

		hscriptArray = null;
		#end
		stagesFunc(function(stage:BaseStage) stage.destroy());

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.setFilters([]);

		#if FLX_PITCH FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();
		NoteSplash.configs.clear();
		instance = null;

		Paths.popUpFramesMap.clear();

		super.destroy();

		if (ClientPrefs.data.disableGC) {
			MemoryUtil.enable();
		}
	}

	var lastStepHit:Float = -1;

	override function stepHit()
	{
		super.stepHit();

		if (curStep == lastStepHit)
		{
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Float = -1;

	override function beatHit()
	{
		if (lastBeatHit >= curBeat)
		{
			// trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms && (curBeat % camZoomingFrequency) == 0)
		{
			FlxG.camera.zoom += 0.015 * camZoomingMult;
			camHUD.zoom += 0.03 * camZoomingMult;
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		characterBopper(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	public function characterBopper(beat:Float):Void
	{
		if (gf != null
			&& beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
			&& !gf.getAnimationName().startsWith('sing')
			&& !gf.stunned)
			gf.dance();
		if (boyfriend != null
			&& beat % boyfriend.danceEveryNumBeats == 0
			&& !boyfriend.getAnimationName().startsWith('sing')
			&& !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
	}

	public function playerDance():Void
	{
		var anim:String = boyfriend.getAnimationName();
		if (boyfriend.holdTimer > boyfriend.charaCrochet * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
			boyfriend.dance();
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	var luaToLoad:String;
	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		luaToLoad = Paths.modFolders(luaFile);
		if (!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getSharedPath(luaFile);

		if (FileSystem.exists(luaToLoad))
		#elseif sys
		luaToLoad = Paths.getSharedPath(luaFile);
		if (OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if (script.scriptName == luaToLoad)
					return false;

			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	var scriptToLoad:String;
	public function startHScriptsNamed(scriptFile:String)
	{
		#if MODS_ALLOWED
		scriptToLoad = Paths.modFolders(scriptFile);
		if (!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getSharedPath(scriptFile);
		#else
		scriptToLoad = Paths.getSharedPath(scriptFile);
		#end

		if (FileSystem.exists(scriptToLoad))
		{
			if (Iris.instances.exists(scriptToLoad))
				return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	var newScript:HScript;
	public function initHScript(file:String)
	{
		newScript = null;
		try
		{
			newScript = new HScript(null, file);
			newScript.executeFunction('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		}
		catch (e:Dynamic)
		{
			addTextToDebug('ERROR ON LOADING ($file) - $e', FlxColor.RED);
			newScript = cast(Iris.instances.get(file), HScript);
			if (newScript != null)
				newScript.destroy();
		}
	}
	#end

	var callResult:Dynamic;
	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		// var returnVal:String = LuaUtils.Function_Continue;
		if (args == null)
			args = [];
		if (exclusions == null)
			exclusions = [];
		if (excludeValues == null)
			excludeValues = [LuaUtils.Function_Continue];

		callResult = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (callResult == null || excludeValues.contains(callResult))
			callResult = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return callResult;
	}

	var returnVal:String;
	var arr:Array<FunkinLua> = [];
	var myValue:Dynamic;
	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		returnVal = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if (args == null)
			args = [];
		if (exclusions == null)
			exclusions = [];
		if (excludeValues == null)
			excludeValues = [LuaUtils.Function_Continue];

		arr.resize(0);
		for (script in luaArray)
		{
			if (script.closed)
			{
				arr.push(script);
				continue;
			}

			if (exclusions.contains(script.scriptName))
				continue;

			myValue = script.call(funcToCall, args);
			if ((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll)
				&& !excludeValues.contains(myValue)
				&& !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed)
				arr.push(script);
		}

		if (arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}

	var callValue:IrisCall;
	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		returnVal = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null)
			exclusions = [];
		if (excludeValues == null)
			excludeValues = [];
		excludeValues.push(LuaUtils.Function_Continue);

		if (hscriptArray.length < 1)
			return returnVal;

		for (script in hscriptArray)
		{
			@:privateAccess
			if (script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			try
			{
				callValue = script.call(funcToCall, args);
				myValue = callValue.returnValue;

				if ((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll)
					&& !excludeValues.contains(myValue)
					&& !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if (myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
			catch (e:Dynamic)
			{
				addTextToDebug('ERROR (${script.origin}: $funcToCall) - $e', FlxColor.RED);
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (exclusions == null)
			exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if LUA_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if HSCRIPT_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in hscriptArray)
		{
			if (exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	var strumSpr:StrumNote = null;
	var strumHitId:Int = -1;
	var strumART:Float = 0;

	function strumPlayAnim(isDad:Bool, id:Int)
	{
		if (!strumAnim)
			return;
		strumHitId = id + (isDad ? 0 : 4);
		if (!toBool(hit & 1 << strumHitId))
		{
			if (isDad)
			{
				strumART = dad.charaCrochet;
				strumSpr = opponentStrums.members[id];
			}
			else
			{
				strumART = boyfriend.charaCrochet;
				strumSpr = playerStrums.members[id];
			}

			if (strumSpr != null)
			{
				strumSpr.playAnim('confirm', true);
				strumSpr.resetAnim = strumART;
			}
			hit |= 1 << strumHitId;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	
	var recalcRate:Dynamic;

	public function recalculateRating(badHit:Bool = false)
	{
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		recalcRate = callOnScripts('onRecalculateRating', null, true);
		if (recalcRate != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if (totalPlayed != 0) // Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				// trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length - 1][0]; // Uses last string
				if (ratingPercent < 1)
					for (i in 0...ratingStuff.length - 1)
						if (ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}

		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if (chartingMode)
			return;

		var usedPractice:Bool = (practiceMode || cpuControlled);
		if (cpuControlled)
			return;

		for (name in achievesToCheck)
		{
			if (!Achievements.exists(name))
				continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch (name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !practiceMode);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if (isStoryMode
					&& campaignMisses + songMisses < 1
					&& Difficulty.getString().toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1
					&& !changedDifficulty
					&& !usedPractice)
					unlock = true;
			}

			if (unlock)
				Achievements.unlock(name);
		}
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if (!shaderEnabled)
			return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if (!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if (!shaderEnabled)
			return false;

		#if (MODS_ALLOWED && !flash && sys)
		if (runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/'))
		{
			var frag:String = folder + name + '.frag';
			var vert:String = folder + name + '.vert';
			var found:Bool = false;
			if (FileSystem.exists(frag))
			{
				frag = File.getContent(frag);
				found = true;
			}
			else
				frag = null;

			if (FileSystem.exists(vert))
			{
				vert = File.getContent(vert);
				found = true;
			}
			else
				vert = null;

			if (found)
			{
				runtimeShaders.set(name, [frag, vert]);
				// trace('Found shader $name!');
				return true;
			}
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		addTextToDebug('Missing shader $name .frag AND .vert files!', FlxColor.RED);
		#else
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		#end
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}
	#end

	#if TOUCH_CONTROLS_ALLOWED
	public function makeLuaTouchPad(DPadMode:String, ActionMode:String) {
		if(members.contains(luaTouchPad)) return;

		if(!variables.exists("luaTouchPad"))
			variables.set("luaTouchPad", luaTouchPad);

		luaTouchPad = new TouchPad(DPadMode, ActionMode);
		luaTouchPad.alpha = ClientPrefs.data.controlsAlpha;
	}
	
	public function addLuaTouchPad() {
		if(luaTouchPad == null || members.contains(luaTouchPad)) return;

		var target = LuaUtils.getTargetInstance();
		target.insert(target.members.length + 1, luaTouchPad);
	}

	public function addLuaTouchPadCamera() {
		if(luaTouchPad != null)
			luaTouchPad.cameras = [luaTpadCam];
	}

	public function removeLuaTouchPad() {
		if (luaTouchPad != null) {
			luaTouchPad.kill();
			luaTouchPad.destroy();
			remove(luaTouchPad);
			luaTouchPad = null;
		}
	}

	public function luaTouchPadPressed(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonPressed(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button; // haxe said "You Can't Iterate On A Dyanmic Value Please Specificy Iterator or Iterable *insert nerd emoji*" so that's the only i foud to fix
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyPressed(idArray);
			} else
				return false;
		}
		return false;
	}

	public function luaTouchPadJustPressed(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonJustPressed(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyJustPressed(idArray);
			} else
				return false;
		}
		return false;
	}
	
	public function luaTouchPadJustReleased(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonJustReleased(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyJustReleased(idArray);
			} else
				return false;
		}
		return false;
	}

	public function luaTouchPadReleased(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonJustReleased(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyReleased(idArray);
			} else
				return false;
		}
		return false;
	}
	#end
}
