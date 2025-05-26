package states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.group.FlxTypedGroup;
import flixel.sound.FlxSound;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import sys.FileSystem;
import sys.io.File;

#if desktop
import DiscordClient;
#end

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '0.0.1';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits'
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var rightOption:String = 'options';

	var magenta:FlxSprite;

	static var showOutdatedWarning:Bool = true;

	var lastSelectedColumn:MainMenuColumn;
	var lastSelectedIndex:Int = -1;

	var webiSprite:FlxSprite;
	var webiDanceTween:FlxTween;
	var webiDanceOffset:Float = 15;

	var spookyMusic:FlxSound;

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("En los Menús", null);
		#end

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var startX:Float = 100;
		var startY:Float = 200;
		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, startX, startY + (num * 140));
		}

		if (leftOption != null) {
			leftItem = createMenuItem(leftOption, startX, startY + (optionShit.length * 140));
		}

		// --- Configuración de la imagen "Webi" (PNG) ---
		webiSprite = new FlxSprite(FlxG.width * 0.65, FlxG.height * 0.35);
		webiSprite.loadGraphic(Paths.image('Webi'));
		webiSprite.antialiasing = ClientPrefs.data.antialiasing;
		webiSprite.setGraphicSize(Std.int(webiSprite.width * 0.7));
		webiSprite.updateHitbox();
		add(webiSprite);
		startWebiDanceTween();

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "Washos Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);

		changeItem();
		lastSelectedColumn = curColumn;
		lastSelectedIndex = curSelected;

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');
		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.scroll.set();

		addTouchPad('NONE', 'E');

		// --- Cargar y reproducir el SFX de fondo ---
		spookyMusic = FlxG.sound.playMusic(Paths.sound('spooky_month_bg_sfx'), 1.0, true);
		spookyMusic.volume = 0.6;
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();

		menuItem.scale.set(0.95, 0.95);
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	var selectedSomethin:Bool = false;
	var timeNotMoving:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.sound.music.volume < 0.8 && FlxG.sound.music != spookyMusic)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P) {
				changeItem(-1);
			}

			if (controls.UI_DOWN_P) {
				changeItem(1);
			}

			var currentMouseAllow:Bool = allowMouse;
			if (currentMouseAllow && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0 || FlxG.mouse.justPressed))
			{
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var mouseOverItemChanged:Bool = false;

				var dist:Float = -1;
				var distItem:Int = -1;
				for (i in 0...optionShit.length)
				{
					var memb:FlxSprite = menuItems.members[i];
					if(FlxG.mouse.overlaps(memb))
					{
						var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
						if (dist < 0 || distance < dist)
						{
							dist = distance;
							distItem = i;
						}
					}
				}

				if(distItem != -1 && (curColumn != CENTER || curSelected != distItem))
				{
					curColumn = CENTER;
					curSelected = distItem;
					changeItem();
					mouseOverItemChanged = true;
				} else if (distItem == -1 && curColumn != CENTER) {
					curColumn = CENTER;
					changeItem();
					mouseOverItemChanged = true;
				}
				if (leftItem != null && FlxG.mouse.overlaps(leftItem)) {
					if (curColumn != LEFT || curSelected != optionShit.length) {
						curColumn = LEFT;
						curSelected = optionShit.length;
						changeItem();
						mouseOverItemChanged = true;
					}
				} else if (leftItem != null && curColumn == LEFT && distItem == -1) {
					curColumn = CENTER;
					changeItem();
					mouseOverItemChanged = true;
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftItem != null) {
						curColumn = LEFT;
						curSelected = optionShit.length;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P) {
						curColumn = CENTER;
						curSelected = 0;
						changeItem();
					}
				case RIGHT:
					// Esta columna no se usa en este diseño
			}

			var fadeOutDuration:Float = 0.4; // Duración del desvanecimiento para SFX y Webi

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				// --- Desvanecer el SFX de fondo y Webi al salir ---
				FlxG.sound.fadeOut(spookyMusic, fadeOutDuration, 0);
				FlxTween.tween(webiSprite, {alpha: 0}, fadeOutDuration, {
					ease: FlxEase.quadOut,
					onComplete: function(t:FlxTween) {
						MusicBeatState.switchState(new TitleState());
					}
				});
			}

			var canAccept:Bool = controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse && FlxG.mouse.overlaps(getSelectedMenuItem()));

			if (canAccept)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite = getSelectedMenuItem();
				var option:String;
				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
					case LEFT:
						option = leftOption;
					case RIGHT:
						option = rightOption;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					// --- Desvanecer el SFX de fondo y Webi al cambiar de estado ---
					FlxG.sound.fadeOut(spookyMusic, fadeOutDuration, 0);
					FlxTween.tween(webiSprite, {alpha: 0}, fadeOutDuration, {
						ease: FlxEase.quadOut,
						onComplete: function(t:FlxTween) {
							// Este switch de estados se ejecuta después de que Webi se ha desvanecido
							switch (option)
							{
								case 'story_mode':
									MusicBeatState.switchState(new StoryMenuState());
								case 'freeplay':
									MusicBeatState.switchState(new FreeplayState());

								#if MODS_ALLOWED
								case 'mods':
									MusicBeatState.switchState(new ModsMenuState());
								#end

								#if ACHIEVEMENTS_ALLOWED
								case 'achievements':
									MusicBeatState.switchState(new AchievementsMenuState());
								#end

								case 'credits':
									MusicBeatState.switchState(new CreditsState());
								case 'options':
									MusicBeatState.switchState(new OptionsState());
									OptionsState.onPlayState = false;
									if (PlayState.SONG != null)
									{
										PlayState.SONG.arrowSkin = null;
										PlayState.SONG.splashSkin = null;
										PlayState.stageUI = 'normal';
									}
								case 'donate':
									CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
									selectedSomethin = false;
									item.visible = true;
									// Si no hay cambio de estado, asegúrate de que el SFX y Webi vuelvan
									spookyMusic.volume = 0.6;
									webiSprite.alpha = 1; // Hacer Webi visible de nuevo
								default:
									trace('Menu Item ${option} doesn\'t do anything');
									selectedSomethin = false;
									item.visible = true;
									// Si no hay cambio de estado, asegúrate de que el SFX y Webi vuelvan
									spookyMusic.volume = 0.6;
									webiSprite.alpha = 1; // Hacer Webi visible de nuevo
							}
						}
					});
				});

				for (memb in menuItems)
				{
					if(memb == item)
						continue;
					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
				if (leftItem != null && leftItem != item) FlxTween.tween(leftItem, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				if (rightItem != null && rightItem != item) FlxTween.tween(rightItem, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});

				// La línea anterior de desvanecer Webi directamente se ha movido al onComplete del flicker.
				// FlxTween.tween(webiSprite, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
			}
			else if (controls.justPressed('debug_1') || (touchPad != null && touchPad.buttonE.justPressed))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				// --- Desvanecer el SFX de fondo y Webi al cambiar de estado ---
				FlxG.sound.fadeOut(spookyMusic, fadeOutDuration, 0);
				FlxTween.tween(webiSprite, {alpha: 0}, fadeOutDuration, {
					ease: FlxEase.quadOut,
					onComplete: function(t:FlxTween) {
						MusicBeatState.switchState(new MasterEditorMenu());
					}
				});
			}
		}
	}

	function changeItem(change:Int = 0)
	{
		if (change != 0 || lastSelectedColumn != curColumn || (curColumn == CENTER && lastSelectedIndex != curSelected) || (curColumn == LEFT && lastSelectedIndex != curSelected)) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if(change != 0) {
			if (curColumn == LEFT) {
				curColumn = CENTER;
				curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
			} else {
				curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
			}
		}

		for (i => item in menuItems)
		{
			if (i == curSelected && curColumn == CENTER) {
				item.animation.play('selected');
				FlxTween.tween(item.scale, {x: 1.05, y: 1.05}, 0.2, {ease: FlxEase.quadOut});
			} else {
				item.animation.play('idle');
				FlxTween.tween(item.scale, {x: 0.95, y: 0.95}, 0.2, {ease: FlxEase.quadOut});
			}
			item.centerOffsets();
		}

		if (leftItem != null) {
			if (curColumn == LEFT) {
				leftItem.animation.play('selected');
				FlxTween.tween(leftItem.scale, {x: 1.05, y: 1.05}, 0.2, {ease: FlxEase.quadOut});
			} else {
				leftItem.animation.play('idle');
				FlxTween.tween(leftItem.scale, {x: 0.95, y: 0.95}, 0.2, {ease: FlxEase.quadOut});
			}
			leftItem.centerOffsets();
		}

		if (rightItem != null) {
			rightItem.animation.play('idle');
			FlxTween.tween(rightItem.scale, {x: 0.95, y: 0.95}, 0.2, {ease: FlxEase.quadOut});
			rightItem.centerOffsets();
		}

		lastSelectedColumn = curColumn;
		lastSelectedIndex = curSelected;
	}

	function getSelectedMenuItem():FlxSprite
	{
		switch(curColumn)
		{
			case CENTER:
				return menuItems.members[curSelected];
			case LEFT:
				return leftItem;
			case RIGHT:
				return rightItem;
		}
		return null;
	}

	function startWebiDanceTween() {
		if (webiDanceTween != null) {
			webiDanceTween.cancel();
		}

		var originalY = webiSprite.y;
		var originalX = webiSprite.x;

		webiDanceTween = FlxTween.tween(webiSprite, {y: originalY - webiDanceOffset}, 0.15, {
			ease: FlxEase.sineOut,
			onComplete: function(t:FlxTween) {
				FlxTween.tween(webiSprite, {y: originalY + webiDanceOffset * 0.5}, 0.1, {
					ease: FlxEase.sineIn,
					onComplete: function(t:FlxTween) {
						FlxTween.tween(webiSprite, {y: originalY}, 0.15, {
							ease: FlxEase.sineOut,
							onComplete: function(t:FlxTween) {
								FlxTween.tween(webiSprite, {x: originalX - 5, angle: -5}, 0.1, {
									ease: FlxEase.quadInOut,
									onComplete: function(t:FlxTween) {
										FlxTween.tween(webiSprite, {x: originalX + 5, angle: 5}, 0.1, {
											ease: FlxEase.quadInOut,
											onComplete: function(t:FlxTween) {
												FlxTween.tween(webiSprite, {x: originalX, angle: 0}, 0.1, {
													ease: FlxEase.quadInOut,
													onComplete: function(t:FlxTween) {
														FlxTween.wait(0.3, function(t:FlxTween) {
															// Solo si Webi no se está desvaneciendo
															if (webiSprite.alpha > 0) {
																startWebiDanceTween();
															}
														});
													}
												});
											}
										});
									}
								});
							}
						});
					}
				});
			}
		});
	}

	// Función para desvanecer el SFX de fondo y Webi al destruir el estado
	override function destroy() {
		super.destroy();
		var fadeOutDuration:Float = 0.4; // Usa la misma duración para consistencia
		if (spookyMusic != null && spookyMusic.active) {
			spookyMusic.fadeOut(fadeOutDuration, 0);
		}
		if (webiSprite != null && webiSprite.alpha > 0) {
			FlxTween.tween(webiSprite, {alpha: 0}, fadeOutDuration, {
				ease: FlxEase.quadOut
			});
		}
	}
}
