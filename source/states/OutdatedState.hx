package states;

import flixel.FlxG;
import flixel.FlxState;
import states.TitleState; // Make sure to import the state you're redirecting to

class OutdatedState extends FlxState
{
    override function create()
    {
        super.create();

        // Instantly switch to the main game screen
        FlxG.switchState(new TitleState());
    }
}
