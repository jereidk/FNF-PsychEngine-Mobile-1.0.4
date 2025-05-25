package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxMath;
import flixel.group.FlxGroup;
import options.OptionsState;
import lime.app.Application;

enum MainMenuColumn {
    CENTER;
}

typedef MenuOption = {
    var id:String;
    var label:String;
    var tooltip:String;
}

class MainMenuState extends MusicBeatState
{
    public static var washosEngineVersion:String = '0.0.1';
    public static var curSelected:Int = 0;
    public static var curColumn:MainMenuColumn = CENTER;

    var menuItems:Array<FlxSprite> = [];
    var optionLabels:Array<FlxText> = [];
    var menuOptions:Array<MenuOption>;
    var magenta:FlxSprite;
    var tooltipText:FlxText;
    var tooltipBG:FlxSprite;
    var webi:WebiSpooky;
    static var showOutdatedWarning:Bool = true;
    var selectedSomethin:Bool = false;

    override function create()
    {
        super.create();
        setupOptions();
        setupBackground();
        setupMenu();
        setupFooter();
        setupTooltip();
        setupWebi();

        FlxG.camera.follow(null); // Cámara fija

        addTouchPad('NONE', 'E');
        changeItem();
    }

    function setupOptions()
    {
        menuOptions = [
            { id: "story_mode", label: "Modo Historia", tooltip: "¡Juega la campaña principal!" },
            { id: "freeplay", label: "Freeplay", tooltip: "Juega cualquier canción libremente." },
            #if MODS_ALLOWED
            { id: "mods", label: "Mods", tooltip: "Explora y juega mods de la comunidad." },
            #end
            { id: "credits", label: "Créditos", tooltip: "Conoce al equipo detrás del juego." },
            #if ACHIEVEMENTS_ALLOWED
            { id: "achievements", label: "Logros", tooltip: "Mira tus logros desbloqueados." },
            #end
            { id: "options", label: "Opciones", tooltip: "Configura el juego a tu gusto." }
        ];
    }

    function setupBackground()
    {
        var yScroll:Float = 0.22;
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
    }

    function setupMenu()
    {
        var spacing = 90;
        var startY = FlxG.height / 2 - ((menuOptions.length) * spacing) / 2 + 20;
        var menuX = 80; // Izquierda con margen

        for (i in 0...menuOptions.length)
        {
            var option = menuOptions[i];
            var item = createMenuSprite(option, menuX, startY + spacing * i);
            menuItems.push(item);
            add(item);

            var labelTxt = new FlxText(item.x + item.width + 24, item.y + (item.height / 2 - 19), 0, option.label, 36);
            labelTxt.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            labelTxt.ID = i;
            optionLabels.push(labelTxt);
            add(labelTxt);
        }
    }

    function createMenuSprite(option:MenuOption, x:Float, y:Float):FlxSprite
    {
        var spr:FlxSprite = new FlxSprite(x, y);
        spr.frames = Paths.getSparrowAtlas('mainmenu/menu_' + option.id);
        spr.animation.addByPrefix('idle', option.id + ' idle', 24, true);
        spr.animation.addByPrefix('selected', option.id + ' selected', 24, true);
        spr.animation.play('idle');
        spr.updateHitbox();
        spr.antialiasing = ClientPrefs.data.antialiasing;
        spr.scrollFactor.set();
        spr.centerOffsets();
        spr.ID = menuItems.length; // For mapping
        return spr;
    }

    function setupFooter()
    {
        var washVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "Washos Engine v" + washosEngineVersion, 12);
        washVer.scrollFactor.set();
        washVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(washVer);

        var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
        fnfVer.scrollFactor.set();
        fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(fnfVer);
    }

    function setupTooltip()
    {
        tooltipBG = new FlxSprite(0, 0).makeGraphic(410, 48, 0xAA111122);
        tooltipBG.scrollFactor.set();
        tooltipBG.alpha = 0;
        add(tooltipBG);

        tooltipText = new FlxText(0, 0, 400, "", 18);
        tooltipText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        tooltipText.scrollFactor.set();
        tooltipText.alpha = 0;
        add(tooltipText);
    }

    function setupWebi()
    {
        // WebiSpooky recibirá la ruta de la imagen real
        webi = new WebiSpooky(FlxG.width - 320, FlxG.height / 2 - 160, Paths.image('Webi'));
        add(webi);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (webi != null)
            webi.danceTime += elapsed;

        if (!selectedSomethin)
        {
            handleNavigation();
            handleSelection();
            handleDebug();
        }
        updateTooltip();
    }

    function handleNavigation()
    {
        if (controls.UI_UP_P)
            changeItem(-1);
        if (controls.UI_DOWN_P)
            changeItem(1);

        if (controls.BACK)
        {
            selectedSomethin = true;
            FlxG.mouse.visible = false;
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new TitleState());
        }
    }

    function handleSelection()
    {
        var selectedItem = getSelectedItem();
        if (controls.ACCEPT)
        {
            FlxG.sound.play(Paths.sound('confirmMenu'));
            selectedSomethin = true;
            FlxG.mouse.visible = false;
            if (ClientPrefs.data.flashing)
                FlxFlicker.flicker(magenta, 1.1, 0.15, false);

            var option = getSelectedOption();
            animateSelection(selectedItem);

            FlxFlicker.flicker(selectedItem, 1, 0.06, false, false, function(flick:FlxFlicker)
            {
                switch (option)
                {
                    case "story_mode": MusicBeatState.switchState(new StoryMenuState());
                    case "freeplay": MusicBeatState.switchState(new FreeplayState());
                    #if MODS_ALLOWED
                    case "mods": MusicBeatState.switchState(new ModsMenuState());
                    #end
                    #if ACHIEVEMENTS_ALLOWED
                    case "achievements": MusicBeatState.switchState(new AchievementsMenuState());
                    #end
                    case "credits": MusicBeatState.switchState(new CreditsState());
                    case "options":
                        MusicBeatState.switchState(new OptionsState());
                        OptionsState.onPlayState = false;
                        if (PlayState.SONG != null)
                        {
                            PlayState.SONG.arrowSkin = null;
                            PlayState.SONG.splashSkin = null;
                            PlayState.stageUI = 'normal';
                        }
                    default:
                        trace('Menu Item ${option} doesn\'t do anything');
                        selectedSomethin = false;
                        selectedItem.visible = true;
                }
            });
            for (item in menuItems)
            {
                if(item == selectedItem)
                    continue;
                FlxTween.tween(item, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
            }
        }
    }

    function handleDebug()
    {
        if (controls.justPressed('debug_1') || touchPad.buttonE.justPressed)
        {
            selectedSomethin = true;
            FlxG.mouse.visible = false;
            MusicBeatState.switchState(new MasterEditorMenu());
        }
    }

    function getSelectedItem():FlxSprite
    {
        return menuItems[curSelected];
    }

    function getSelectedOption():String
    {
        return menuOptions[curSelected].id;
    }

    function changeItem(change:Int = 0)
    {
        curSelected = FlxMath.wrap(curSelected + change, 0, menuOptions.length - 1);

        // Reset visuals
        for (i in 0...menuItems.length)
        {
            var item = menuItems[i];
            item.animation.play('idle');
            item.alpha = 0.8;
            item.color = FlxColor.WHITE;
            FlxTween.tween(item.scale, {x: 1, y: 1}, 0.13, {ease: FlxEase.quadOut});
            optionLabels[i].color = FlxColor.WHITE;
            optionLabels[i].alpha = 0.85;
        }

        // Select current
        var selectedItem = getSelectedItem();
        selectedItem.animation.play('selected');
        selectedItem.alpha = 1.0;
        selectedItem.color = 0xFFFBD8FF;
        FlxTween.tween(selectedItem.scale, {x: 1.17, y: 1.17}, 0.19, {ease: FlxEase.backOut});
        animateSelection(selectedItem);

        optionLabels[curSelected].color = FlxColor.YELLOW;
        optionLabels[curSelected].alpha = 1.0;
    }

    function animateSelection(item:FlxSprite)
    {
        if (item == null) return;
        FlxTween.tween(item.scale, {x: 1.23, y: 1.23}, 0.14, {
            ease: FlxEase.elasticOut,
            onComplete: function(_) {
                FlxTween.tween(item.scale, {x: 1.17, y: 1.17}, 0.11, {ease: FlxEase.quadOut});
            }
        });
    }

    function updateTooltip()
    {
        var option:MenuOption = menuOptions[curSelected];
        var item = getSelectedItem();

        tooltipText.text = option.label + " - " + option.tooltip;
        tooltipText.x = item.x + item.width + 40;
        tooltipText.y = item.y + (item.height/2) - 24;
        tooltipBG.x = tooltipText.x - 8;
        tooltipBG.y = tooltipText.y - 4;

        FlxTween.tween(tooltipText, {alpha: 1}, 0.14);
        FlxTween.tween(tooltipBG, {alpha: 0.9}, 0.14);
    }
}

// --- WebiSpooky: animación de baile desde código sobre PNG ---
class WebiSpooky extends FlxGroup
{
    public var danceTime:Float = 0;
    var posX:Float;
    var posY:Float;
    var base:FlxSprite;
    var head:FlxSprite;
    var armLeft:FlxSprite;
    var armRight:FlxSprite;

    public function new(x:Float, y:Float, imgAsset:String)
    {
        super();
        posX = x;
        posY = y;

        // Imagen base de Webi (251x337)
        base = new FlxSprite(posX, posY).loadGraphic(imgAsset);
        base.setGraphicSize(167, 224); // Escala proporcional para que quepa bien
        base.antialiasing = true;
        base.updateHitbox();
        add(base);

        // Brazos cartoon (negros, simulando spooky month)
        armLeft = new FlxSprite(posX + 40, posY + 120);
        armLeft.makeGraphic(20, 70, FlxColor.BLACK);
        armLeft.origin.set(10,10);
        add(armLeft);

        armRight = new FlxSprite(posX + 110, posY + 120);
        armRight.makeGraphic(20, 70, FlxColor.BLACK);
        armRight.origin.set(10,10);
        add(armRight);

        // Cabeza cartoon encima para animar
        head = new FlxSprite(posX + 42, posY + 20);
        head.makeGraphic(83, 83, FlxColor.WHITE);
        head.antialiasing = true;
        add(head);
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        // Baile Spooky Month: Alterna los brazos y la cabeza
        var t = danceTime;
        var dance = Math.floor((t*2)%2) == 0;

        // Brazos: rotación hacia arriba alternando
        var armAngle = dance ? -65 : 65;
        armLeft.angle = armAngle + Math.sin(t*5)*7;
        armRight.angle = -armAngle + Math.cos(t*5)*7;

        armLeft.y = posY+120 - Math.abs(Math.sin(t*2)*12);
        armRight.y = posY+120 - Math.abs(Math.cos(t*2)*12);

        // Cabeza bailando de un lado a otro
        head.x = posX + 42 + Math.sin(t*2)*11;
        head.angle = dance ? -13 : 13;
    }
}
