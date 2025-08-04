package options;

class OptimizeSettingsSubState extends BaseOptionsMenu
{
	var bufferCount:Option;
	var cacheCount:Option;

	public function new()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Optimizer Menu", null);
		#end
		
		title = 'Optimizer';
		rpcTitle = 'Optimize Settings Menu'; //for Discord Rich Presence

		//Working in Progress!
        var option:Option = new Option('Working in Progress', //Name
			"Make changes at your own risk.", //Description
			'openDoor', //Save data variable name
			STRING,
			['!']); //Variable type
		addOption(option);

        var option:Option = new Option('Show Notes',
			"If unchecked, appearTime sets to 0. All notes will process by skipped notes.\nalso It forces to turn on botplay.",
			'showNotes',
			BOOL);
		addOption(option);

        var option:Option = new Option('Keep Notes in Screen',
		 	"If checked, notes displays from top to bottom even if skippable.\nUncheck It improves performance especially if a lot of notes displayed.",
		 	'keepNotes',
		 	BOOL);
		addOption(option);

        var option:Option = new Option('Sort Notes:',
			"If checked, notes array sorts every frame which notes added.\nUncheck It improves performance especially if a lot of notes displayed.\nIf you couldn't understand well, set \"After Note Finalized\".",
			'sortNotes',
			STRING,
			[
				'Never',
				'After Note Spawned',
				'After Note Processed',
				'After Note Finalized',
				'Reversed',
				'Chaostic',
				'Randomized Order',
				'Shuffle',
			]); //Variable type
		addOption(option);

        var option:Option = new Option('Show Rating Popup',
			"If checked, \"Rating popup\" shows every time hit notes.\nUncheck It reduces a little bit of memory usage.",
			'showRating',
			BOOL);
		addOption(option);

		var option:Option = new Option('Show Combo Number Popup',
			"If checked, \"Combo Number popup\" shows every time hit notes.\nUncheck It reduces a little bit of memory usage.",
			'showComboNum',
			BOOL);
		addOption(option);

		var option:Option = new Option('Show Combo Popup',
			"If checked, \"Combo popup\" shows every time hit notes.\nWell I think there is no person to check this, but I leave this.",
			'showCombo',
			BOOL);
		addOption(option);

		/* var option:Option = new Option('Better Recycling',
			"If checked, It uses NoteGroup's recycle system.\nIt boosts game perfomance vastly, It works anytime yeah.",
			'betterRecycle',
			BOOL);
		addOption(option);

		var option:Option = new Option('Cache Notes:',
			"Enables recycling of a specified number of items before playing.\nIt cuts time of newing instances. 0 is for disabled.\nIt needs RAM depending this value.",
			'cacheNotes',
			INT);
		option.scrollSpeed = 30;
		option.minValue = 0;
		option.maxValue = 99999;
		option.changeValue = 1;
		option.decimals = 0;
		option.onChange = onChangeCount;
		cacheCount = option;
		addOption(option); */

        var option:Option = new Option('Do Note Process before Spawning',
			"Well, It's literally, yes.\nIt boosts game perfomance vastly, It works anytime yeah.\nIf you don't get it, enable this.",
			'processFirst',
			BOOL);
		addOption(option);

		var option:Option = new Option('Separate Process for Too Slow Note',
			"If checked, Separate note hit processes for too slow one and not.\nIt boosts game perfomance vastly, but it effects at limited scene.\nIf you don't get it, enable this.",
			'separateHitProcess',
			BOOL);
		addOption(option);

        var option:Option = new Option('Skip Process for Spawned Note',
			"If checked, enables Skip Note Function.\nIt boosts game perfomance vastly, but it effects at limited scene.\nIf you don't get it, enable this.",
			'skipSpawnNote',
			BOOL);
		addOption(option);

        var option:Option = new Option('Optimize Process for Spawned Note',
			"If checked, It judges whether or not to do hit process\nimmediately when a note spawned. If you don't get it, enable this.",
			'optimizeSpawnNote',
			BOOL);
		addOption(option);

        var option:Option = new Option('noteHitPreEvent',
			"If unchecked, don't send any noteHitPreEvent on Lua/HScript.",
			'noteHitPreEvent',
			BOOL);
		addOption(option);

        var option:Option = new Option('noteHitEvent',
			"If unchecked, don't send any noteHitEvent on Lua/HScript.\nUnrecommended to disable this option.",
			'noteHitEvent',
			BOOL);
		addOption(option);

		var option:Option = new Option('noteHitEvents for Spawned Notes',
			"If unchecked, don't send any event on Lua/HScript for spawned notes.\nand It improves performance.",
			'spawnNoteScript',
			BOOL);
		addOption(option);

		var option:Option = new Option('noteHitEvents for Skipped Notes',
			"If unchecked, don't send any event on Lua/HScript for skipped notes.\nand It improves performance.",
			'skipNoteScript',
			BOOL);
		addOption(option);

        var option:Option = new Option('Disable Garbage Collector',
			"If checked, You can play the main game without GC lag.\nIt's only works while load & playing chart.",
			'disableGC',
			BOOL);
		addOption(option);

        super();
    }

	function onChangeCount(){
		bufferCount.scrollSpeed = cacheCount.scrollSpeed = interpolate(30, 50000, (holdTime - 0.5) / 10, 3);
	}
}