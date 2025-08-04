package mikolka.vslice;

import haxe.macro.PlatformConfig.ExceptionsConfig;
import flixel.FlxGame;
import mikolka.compatibility.VsliceOptions;
import mikolka.compatibility.ModsHelper;
import flixel.FlxState;
#if !LEGACY_PSYCH
import states.TitleState;
#end
import openfl.events.ErrorEvent;
import openfl.display.BitmapData;
// crash handler stuff
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;

using StringTools;

class CrashState extends FlxState
{
	var screenBelow:BitmapData = BitmapData.fromImage(FlxG.stage.window.readPixels());
	var textBg:FlxSprite;

	var EMessage:String;
	var callstack:Array<StackItem>;

	#if TOUCH_CONTROLS_ALLOWED
	var musicState:MusicBeatState;
	var isTouchable:Bool = true;
	#else
	var isTouchable:Bool = false;
	#end

	public function new(EMessage:String, callstack:Array<StackItem>)
	{
		this.EMessage = EMessage;
		this.callstack = callstack;
		super();
	}

	override function create()
	{
		if (Main.fpsVar != null)
			Main.fpsVar.visible = false;

		super.create();
		var previousScreen = new FlxSprite(0, 0, screenBelow);
		previousScreen.setGraphicSize(FlxG.width, FlxG.height);
		previousScreen.updateHitbox();

		textBg = new FlxSprite();
		FunkinTools.makeSolidColor(textBg, Math.floor(FlxG.width * 0.73), FlxG.height, 0x86000000);
		textBg.screenCenter();

		add(previousScreen);
		add(textBg);
		var error = collectErrorData();
		printError(error);
		saveError(error);
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end

		#if TOUCH_CONTROLS_ALLOWED
		musicState = new MusicBeatState();
		musicState.removeTouchPad();
		musicState.addTouchPad('NONE', 'A_B');
		#end

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function collectErrorData():CrashData
	{
		var errorMessage = EMessage;

		var callStack:Array<StackItem> = callstack;
		var errMsg = new Array<Array<String>>();
		var errExtended = new Array<String>();
		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, pos_line, column):
					var line = new Array<String>();
					switch (s)
					{
						case Module(m):
							line.push("MD:" + m);
						case CFunction:
							line.push("Native function");
						case Method(classname, method):
							var regex = ~/(([A-Z]+[A-z]*)\.?)+/g;
							regex.match(classname);
							line.push("CLS:" + regex.matched(0) + ":" + method + "()");
						default:
							Sys.println(stackItem);
					}
					line.push("Line:" + pos_line);
					errMsg.push(line);
					errExtended.push('In file ${file}: ${line.join("  ")}');
				default:
					Sys.println(stackItem);
			}
		}
		return {
			message: errorMessage,
			trace: errMsg,
			extendedTrace: errExtended,
			date: Date.now().toString(),
			systemName: #if android 'Android' #elseif linux 'Linux' #elseif mac 'macOS' #elseif windows 'Windows' #else 'iOS' #end,
			activeMod: ModsHelper.getActiveMod()
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ENTER #if TOUCH_CONTROLS_ALLOWED || musicState.touchPad.buttonA.justPressed #end)
		{
			TitleState.initialized = false;
			TitleState.closedState = false;
			if (Main.fpsVar != null) Main.fpsVar.visible = ClientPrefs.data.showFPS;
			if (Main.fpsBg != null) Main.fpsBg.visible = ClientPrefs.data.showFPS;
			FlxG.sound.pause();
			FlxTween.globalManager.clear();
			FlxG.resetGame();
		}
		if (FlxG.keys.justPressed.ESCAPE #if TOUCH_CONTROLS_ALLOWED || musicState.touchPad.buttonB.justPressed #end)
		{
			Sys.exit(1);
		}
	}

	function printError(error:CrashData)
	{
		printToTrace('A-SLICE ${MainMenuState.pSliceVersion}  (${error.message})');
		textNextY += 35;

		final enter:String = isTouchable ? 'A' : 'ENTER';
		final escape:String = isTouchable ? 'B' : 'ESCAPE';

		FlxTimer.wait(1 / 24, () ->
		{
			printSpaceToTrace();
			for (line in error.trace)
			{
				switch (line.length)
				{
					case 1:
						printToTrace(line[0]);
					case 2:
						var first_line = line[0].rpad(" ", 33).replace("_", "");
						printToTrace('${first_line}${line[1]}');
					default:
						printToTrace(" ");
				}
			}
			var remainingLines = 12 - error.trace.length;
			if (remainingLines > 0)
			{
				for (x in 0...remainingLines)
				{
					printToTrace(" ");
				}
			}
			printSpaceToTrace();
			printToTrace('RUNTIME INFORMATION');
			var date_split = error.date.split(" ");
			printToTrace('TIME:${date_split[1].rpad(" ",9)} DATE:${date_split[0]}');
			printToTrace('MOD:${error.activeMod.rpad(" ",10)} PE:${MainMenuState.psychEngineVersion.rpad(" ", 5)} SYS:${error.systemName}');
			printSpaceToTrace();
			printToTrace('REPORT TO GITHUB.COM/YOUR_USERNAME/A-SLICE');
			printToTrace('PRESS $enter TO RESTART / $escape TO EXIT');
		});
	}

	static function saveError(error:CrashData)
	{
		var errMsg = "A-Slice CRASHED!\n";
		var dateNow:String = error.date;

		dateNow = dateNow.replace(' ', '_');
		dateNow = dateNow.replace(':', "'");

		errMsg += '\nUncaught Error: ' + error.message + "\n";
		for (x in error.extendedTrace)
		{
			errMsg += x + "\n";
		}
		errMsg += '----------\n';
		errMsg += 'Active mod: ${error.activeMod}\n';
		errMsg += 'Platform: ${error.systemName}\n';
		errMsg += '\n';
		errMsg += '\nPlease report this error to the GitHub page: https://github.com/AnjBat/A-Slice\n\n> Crash Handler customized by: YOUR_NAME';

		#if !LEGACY_PSYCH
		@:privateAccess // lazy
		backend.CrashHandler.saveErrorMessage(errMsg + '\n');
		#else
		var path = './crash/' + 'A-Slice_' + dateNow + '.txt';
		File.saveContent(path, errMsg + '\n');
		Sys.println(errMsg);
		#end
		Sys.println(errMsg);
	}

	var textNextY = 5;

	function printToTrace(text:String):FlxText
	{
		var test_text = new FlxText(180, textNextY, 920, text.toUpperCase());
		test_text.setFormat(Paths.font('vcr.ttf'), 35, FlxColor.WHITE, LEFT);
		test_text.updateHitbox();
		test_text.antialiasing = ClientPrefs.data.antialiasing;
		add(test_text);
		textNextY += 35;
		return test_text;
	}

	function printSpaceToTrace()
	{
		textNextY += 10;
	}
}

typedef CrashData =
{
	message:String,
	trace:Array<Array<String>>,
	extendedTrace:Array<String>,
	date:String,
	systemName:String,
	activeMod:String
}
