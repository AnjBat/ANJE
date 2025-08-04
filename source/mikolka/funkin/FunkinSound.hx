package mikolka.funkin;

import lime.app.Promise;
import sys.thread.Lock;
import sys.thread.Thread;
import openfl.media.Sound;
import mikolka.vslice.freeplay.FreeplayState;
import funkin.util.flixel.sound.FlxPartialSound;
import haxe.exceptions.NotImplementedException;
import openfl.media.SoundMixer;
import flixel.system.FlxAssets.FlxSoundAsset;

class FunkinSound extends FlxSound
{
	/**
	 * Play a sound effect once, then destroy it.
	 * @param key
	 * @param volume
	 * @return static function construct():FunkinSound
	 */
	public static function playOnce(key:String, volume:Float = 1.0, ?onComplete:Void->Void, ?onLoad:Void->Void):Void
	{
		var result = FunkinSound.load(key, volume, false, true, true, onComplete, onLoad);
	}

	/**
	 * Creates a new `FunkinSound` object synchronously.
	 *
	 * @param embeddedSound   The embedded sound resource you want to play.  To stream, use the optional URL parameter instead.
	 * @param volume          How loud to play it (0 to 1).
	 * @param looped          Whether to loop this sound.
	 * @param group           The group to add this sound to.
	 * @param autoDestroy     Whether to destroy this sound when it finishes playing.
	 *                          Leave this value set to `false` if you want to re-use this `FunkinSound` instance.
	 * @param autoPlay        Whether to play the sound immediately or wait for a `play()` call.
	 * @param onComplete      Called when the sound finished playing.
	 * @param onLoad          Called when the sound finished loading.  Called immediately for succesfully loaded embedded sounds.
	 * @return A `FunkinSound` object, or `null` if the sound could not be loaded.
	 */
	public static function load(embeddedSound:FlxSoundAsset, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false,
			?onComplete:Void->Void, ?onLoad:Void->Void):Null<FunkinSound>
	{
		//? Why was that a thing again?
		// @:privateAccess
		// if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS)
		// {
		// 	FlxG.log.error('FunkinSound could not play sound, channels exhausted! Found ${SoundMixer.__soundChannels.length} active sound channels.');
		// 	return null;
		// }

		var sound:FunkinSound = new FunkinSound(); // pool.recycle(construct);

		// Sets `exists = true` as a side effect.
		if(embeddedSound is String) embeddedSound = Paths.sound(embeddedSound);
		sound.loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);

		//   if (embeddedSound is String)
		//   {
		//     sound._label = embeddedSound;
		//   }
		//   else
		//   {
		//     sound._label = 'unknown';
		//   }

		if (autoPlay)
			sound.play();
		sound.volume = volume;
		sound.group = FlxG.sound.defaultSoundGroup;
		sound.persist = true;

		// Make sure to add the sound to the list.
		// If it's already in, it won't get re-added.
		// If it's not in the list (it gets removed by FunkinSound.playMusic()),
		// it will get re-added (then if this was called by playMusic(), removed again)
		FlxG.sound.list.add(sound);

		// Call onLoad() because the sound already loaded
		if (onLoad != null && sound._sound != null)
			onLoad();

		return sound;
	}
	public static function playMusic(key:String, params:FunkinSoundPlayMusicParams):Bool {
		if(params.pathsFunction == INST){
			var instPath = "";
			
			try {
				//key = songData.songId

				instPath = 'assets/songs/${Paths.formatToSongPath(key)}/Inst.${Paths.SOUND_EXT}';
				#if MODS_ALLOWED
				var modsInstPath = Paths.modFolders('songs/${Paths.formatToSongPath(key)}/Inst.${Paths.SOUND_EXT}');
				if(FileSystem.exists(modsInstPath)) instPath = modsInstPath;
				#end
				#if debug trace(instPath,params.partialParams.start,params.partialParams.end); #end
				var future:Promise<Sound> = FlxPartialSound.partialLoadFromFile(instPath,params.partialParams.start,params.partialParams.end);

				future.future.onComplete(sound ->
				{
					@:privateAccess{
						if(!Std.isOfType(FlxG.state.subState,FreeplayState)) return;
						var fp = cast (FlxG.state.subState,FreeplayState);

						var cap = fp.grpCapsules.members[fp.curSelected];
						if(cap.songData == null || cap.songData.songId != key || fp.busy) return;
					}
					#if debug trace(sound.bytesLoaded, sound.bytesTotal, sound.length); #end
					FlxG.sound.playMusic(sound,0);
					params.onLoad();
				});
				
				if(future.future.value == null) {
					#if debug trace('Internal failure loading instrumentals for ${key} "${instPath}"'); #end
					return false;
				}
				
				#if debug trace('Sound length: ${future.future.value.length}'); #end
				if (future.future.value.length == 0) {
					#if debug trace('No size loaded instrumentals for ${key} "${instPath}"'); #end
					return false;
				}
				return true;
			} catch (x) {
				var targetPath = instPath == "" ? "" : "from "+instPath;
				#if debug 
				trace('Failed to parialy load instrumentals for ${key} ${targetPath}');
				trace('Exception: ${x.message}');
				#end
				return false;
			}
		} else {
			var targetPath = key+"/"+key;
			if(key == "freakyMenu") targetPath = "freakyMenu";
			FlxG.sound.playMusic(Paths.music(targetPath),params.startingVolume * ClientPrefs.data.sfxVolume,params.loop);
			if(params.onLoad!= null)params.onLoad();
			return true;
		}
	}
}

/**
 * Additional parameters for `FunkinSound.playMusic()`
 */
 typedef FunkinSoundPlayMusicParams =
 {
   /**
	* The volume you want the music to start at.
	* @default `1.0`
	*/
   var ?startingVolume:Float;
 
   /**
	* The suffix of the music file to play. Usually for "-erect" tracks when loading an INST file
	* @default ``
	*/
   var ?suffix:String;
 
   /**
	* Whether to override music if a different track is already playing.
	* @default `false`
	*/
   var ?overrideExisting:Bool;
 
   /**
	* Whether to override music if the same track is already playing.
	* @default `false`
	*/
   var ?restartTrack:Bool;
 
   /**
	* Whether the music should loop or play once.
	* @default `true`
	*/
   var ?loop:Bool;
 
   /**
	* Whether to check for `SongMusicData` to update the Conductor with.
	* @default `true`
	*/
   var ?mapTimeChanges:Bool;
 
   /**
	* Which Paths function to use to load a song
	* @default `MUSIC`
	*/
   var ?pathsFunction:PathsFunction;
 
   var ?partialParams:PartialSoundParams;
 
   var ?onComplete:Void->Void;
   var ?onLoad:Void->Void;
 }

 typedef PartialSoundParams =
{
  var loadPartial:Bool;
  var start:Float;
  var end:Float;
}

enum abstract PathsFunction(String)
{
  var MUSIC;
  var INST;
  var VOICES;
  var SOUND;
}