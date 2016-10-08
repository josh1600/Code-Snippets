/*
    -- Credit to: zylozi
    DESC:
        allows addition of the gobblegums back into any map easily.

    NOTE:
        Missing some of the rare effects.
*/

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\hud_message_shared;
#using scripts\zm\_zm_weap_cymbal_monkey;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_powerups;
#using scripts\shared\ai\zombie_death;
#using scripts\zm\_zm_traps;
#using scripts\zm\_zm_pack_a_punch;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_perks;
#using scripts\zm\gametypes\_globallogic_player;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_weap_cymbal_monkey.gsc;

#precache( "fx", "zombie/fx_elec_player_md_zmb" );
#precache( "fx", "zombie/fx_elec_player_sm_zmb" );
#precache( "fx", "zombie/fx_elec_player_torso_zmb" );
#precache( "fx", "dlc0/factory/fx_laser_hotspot_factory" );

#precache( "string", "ZM_VACANT_BOONS_ACTIVATION_KEYBIND" );
#precache( "string", "ZM_VACANT_BOONS_CANCEL_KEYBIND" );

// To use in another script, do: player thread _zm_boons::random_boon_effect();
//************************************************************
// Handler
//************************************************************
function setup_boons()
{
	level._effect["elec_md"]							= "zombie/fx_elec_player_md_zmb";
	level._effect["elec_sm"]							= "zombie/fx_elec_player_sm_zmb";
	level._effect["elec_torso"]							= "zombie/fx_elec_player_torso_zmb";
    level._effect["player_slide_exp"]                   = "player/fx_plyr_land_dust_dirt_xlg";

    callback::on_spawned( &on_player_spawned );
    zm::register_actor_damage_callback( &on_actor_damage );
    zm::register_player_damage_callback( &on_player_damage );

    level.get_player_perk_purchase_limit            = &get_player_perk_purchase_limit;
    level._game_module_player_laststand_callback    = &on_laststand;
}

//************************************************************
// Callbacks
//************************************************************
function on_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType  ) //self is an enemy
{
    if( !IsPlayer( inflictor ) )
    {
        if( isDefined( attacker.boon_sword_flay ) && attacker.boon_sword_flay )
        {
            if( meansofdeath == "MOD_MELEE" )
            {
                damage = damage * 5;
            }
        }

        if( meansofdeath == "MOD_MELEE" )
        {
            if( isDefined( attacker.boon_pop_shocks ) && isDefined( attacker.boon_charges ) && attacker.boon_pop_shocks == true )
            {
                attacker.boon_charges--;
                attacker thread update_boon_charge_hud( attacker.boon_charges, "Attacks" );

                attacker thread pop_shock_zombies();

                if( attacker.boon_charges <= 0 )
                {
                    attacker notify( "pop_shocks_expired" );
                }
            }
        }
    }

    return damage;
}

function on_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    if( self.boon_danger_closest == true )
    {
        if( sMeansOfDeath == "MOD_EXPLOSIVE" || sMeansOfDeath == "MOD_GRENADE" || sMeansOfDeath == "MOD_EXPLOSIVE_SPLASH" || sMeansOfDeath == "MOD_GRENADE_SPLASH"  )
        {
            iDamage = 0;
        }
    }

    if( !isPlayer( eInflictor ) )
    {
        if( self.boon_burned_out == true )
        {
            if( isDefined( self.boon_charges ) && self.boon_charges > 0 )
            {
                self thread immolate_nearby_zombies();
                self.boon_charges--;
                self thread update_boon_charge_hud( self.boon_charges, "Hits" );

                if( self.boon_charges <= 0 )
                    self notify( "burned_out_expired" );
            }
            else
            {
                self notify( "burned_out_expired" );
            }
        }
    }

    return iDamage;
}

function on_laststand(eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
    if( isDefined( self.boon_coagulant ) && self.boon_coagulant == true )
    {
        self.n_bleedout_time_multiplier = 2;
    }
}

function get_player_perk_purchase_limit()
{
    limit = level.perk_purchase_limit;

    // Allow this extra bottle, and then end the boon
    if( self.num_perks == limit )
    {
        limit = limit + 1;
        self notify( "unquenchable_expired" );
    }

    return limit;
}

function on_player_spawned()
{
    self thread setup_boon_vars();
    self thread on_player_death();

}

function on_player_death()
{
    self endon( "disconnect" );
    self waittill( "death" );

    self thread cleanup_boon_setup();
}

//************************************************************
// Setup
//************************************************************
function setup_boon_vars()
{
    self.boon_coagulant                 = false;
    self.boon_endless_stream            = false;
    self.boon_sword_flay                = false;
    self.boon_danger_closest            = false;
    self.boon_now_you_see_me            = false;
    self.boon_dead_of_nuclear_winter    = false;
    self.boon_aftertaste                = false;
    self.boon_burned_out                = false;
    self.boon_ephemeral_enhancement     = false;
    self.boon_im_feeling_lucky          = false;
    self.boon_immolation_liquidation    = false;
    self.boon_licensed_contractor       = false;
    self.boon_phoenix_up                = false;
    self.boon_pop_shocks                = false;
    self.boon_unquenchable              = false;
    self.boon_whos_keeping_score        = false;
    self.boon_fatal_contraption         = false;
    self.boon_crawl_space               = false;
    self.boon_disorderly_combat         = false;
    self.boon_slaughter_slide           = false;
    self.boon_mind_blown                = false;
    self.boon_cache_back                = false;
    self.boon_kill_joy                  = false;
    self.boon_on_the_house              = false;
    self.boon_wall_power                = false;
    self.boon_undead_man_walking        = false;
    self.boon_fear_in_headlights        = false;
    self.boon_temporal_gift             = false;
    self.boon_crate_power               = false;
    self.boon_bullet_boost              = false;
    self.boon_killing_time              = false;
    self.boon_perkaholic                = false;
    self.boon_head_drama                = false;
    self.boon_secret_shopper            = false;
    self.boon_shopping_free             = false;
    self.boon_near_death_experience     = false;
    self.boon_profit_sharing            = false;
    self.boon_round_robbin              = false;
    self.boon_self_medication           = false;

    self.hasBoon = false;
    self.phoenix_up_revive = false;

    self thread setup_keybind_hud();
    self thread monitor_cancel();
}

function cleanup_boon_setup()
{
    self notify( "burned_out_expired" );
    self notify( "pop_shocks_expired" );

    self.hasBoon = false;
    self.weapon_currently_papped = false;
    self.phoenix_up_revive = false;

    self thread cleanup_boon_charge_hud();
    self thread cleanup_boon_charge_timer();
    self thread cleanup_keybind_hud();
}

//************************************************************
// Utility
//************************************************************
function random_boon_effect()
{
     self.hasBoon = true;

    r = RandomIntRange( 0, 20 );
    //r = 19;

    switch( r )
    {
        case 0: self thread setup_boon_coagulant(); break;
        case 1: self thread setup_boon_endless_stream(); break;
        case 2: self thread setup_boon_sword_flay(); break;
        case 3: self thread setup_boon_danger_closest(); break;
        case 4: self thread setup_boon_now_you_see_me(); break;
        case 5: self thread setup_boon_dead_of_nuclear_winter(); break;
        case 6: self thread setup_boon_burned_out(); break;
        case 7: self thread setup_boon_ephemeral_enhancement(); break;
        case 8: self thread setup_boon_im_feeling_lucky(); break;
        case 9: self thread setup_boon_immolation_liquidation(); break;
        case 10: self thread setup_boon_licensed_contractor(); break;
        case 11: self thread setup_boon_pop_shocks(); break;
        case 12: self thread setup_unquenchable(); break;
        case 13: self thread setup_boon_whos_keeping_score(); break;
        case 14: self thread setup_boon_fatal_contraption(); break;
        case 15: self thread setup_boon_disorderly_combat(); break;
        case 16: self thread setup_boon_slaughter_slide(); break;
        case 17: self thread setup_boon_mind_blown(); break;
        case 18: self thread setup_boon_cache_back(); break;
        case 19: self thread setup_boon_kill_joy(); break;
        default: break;
    }
}

function debug_distance()
{
    originOne = ( 0, 0, 0 );
    originTwo = ( 0, 0, 0 );

    while(1)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            originOne = self getOrigin();
        }

        if( self ActionSlotTwoButtonPressed() )
        {
            while( self ActionSlotTwoButtonPressed() )
                wait(0.05);

            originTwo = self getOrigin();
        }

        if( self ActionSlotThreeButtonPressed() )
        {
            while( self ActionSlotThreeButtonPressed() )
                wait(0.05);

            self iPrintLnBold( distanceSquared( originOne, originTwo ) );
        }

        wait(0.05);
    }
}

//************************************************************
// HUD
//************************************************************
function boon_charge_hud( amount, text )
{
    if( isDefined( self.boon_charge_text ) )
        self.boon_charge_text destroy();

    self.boon_charge_text = hud::createFontString( "extrabig", 2.0 );
	self.boon_charge_text hud::setPoint( "CENTER", "BOTTOM", 0, -80 );
    self.boon_charge_text.glowAlpha = 1;
	self.boon_charge_text.hideWhenInMenu = false;
	self.boon_charge_text.archived = false;
    self.boon_charge_text setText( amount + " " + text );
}

function update_boon_charge_hud( amount, text )
{
    if( isDefined( self.boon_charge_text ) )
        self.boon_charge_text setText( amount + " " + text );
}

function call_boon_charge_timer( parent, time )
{
    self.boon_timer = hud::createFontString( "extrabig", 1.6 );
	self.boon_timer hud::setPoint( "CENTER", "BOTTOM", 0, 10 );
    self.boon_timer hud::setParent( parent );
    self.boon_timer.glowAlpha = 1;
	self.boon_timer.hideWhenInMenu = true;
	self.boon_timer.archived = false;
    self.boon_timer setTimer(time);

    wait(time);

    self.boon_timer destroy();
}

function cleanup_boon_charge_hud()
{
    if( isDefined( self.boon_charge_text ) )
        self.boon_charge_text destroy();
}

function cleanup_boon_charge_timer()
{
    if( isDefined( self.boon_timer ) )
        self.boon_timer destroy();
}

function create_boon_info( name, desc )
{
    self endon( "disconnect" );
    self endon( "death" );

    self thread destroy_boon_info();

    self.boonName = hud::createFontString( "extrabig", 2.0 );
	self.boonName hud::setPoint( "TOP", undefined, 0, 2 );
    self.boonName setText( name );
    self.boonName.glowAlpha = 1;
	self.boonName.hideWhenInMenu = true;
	self.boonName.archived = false;
	self.boonName setCOD7DecodeFX( 200, 60000, 600 );

    self.boonDesc = hud::createFontString( "extrabig", 1.6 );
	self.boonDesc hud::setParent( self.boonName );
	self.boonDesc hud::setPoint( "TOP", "BOTTOM", 0, 0 );
	self.boonDesc.glowAlpha = 1;
	self.boonDesc.hideWhenInMenu = true;
	self.boonDesc.archived = false;
	self.boonDesc setText( desc );
    //self.boonDesc setCOD7DecodeFX( 200, 5000, 600 );

    wait(5);

    if( isDefined( self.boonName ) )
    {
        self.boonName FadeOverTime(2);
        self.boonName.alpha = 0;
    }

    if( isDefined( self.boonDesc ) )
    {
        self.boonDesc FadeOverTime(2);
        self.boonDesc.alpha = 0;
    }

    wait(2);

    if( isDefined( self.boonName ) )
        self.boonName destroy();

    if( isDefined( self.boonDesc ) )
        self.boonDesc destroy();
}

function destroy_boon_info()
{
    if( isDefined( self.boonName ) )
        self.boonName destroy();

    if( isDefined( self.boonDesc ) )
        self.boonDesc destroy();
}


function setup_keybind_hud()
{
    self endon( "disconnect" );
    self endon( "death" );

    self.keybindUse = hud::createFontString( "extrabig", 1.2 );
	self.keybindUse hud::setPoint( "LEFT", "LEFT", 20, 60 );
    self.keybindUse.glowAlpha = 1;
	self.keybindUse.hideWhenInMenu = true;
	self.keybindUse.archived = false;
    self.keybindUse setText( &"ZM_VACANT_BOONS_ACTIVATION_KEYBIND" );

    self.keybindCancel = hud::createFontString( "extrabig", 1.2 );
	self.keybindCancel hud::setPoint( "LEFT", "LEFT", 20, 80 );
    self.keybindCancel.glowAlpha = 1;
	self.keybindCancel.hideWhenInMenu = true;
	self.keybindCancel.archived = false;
    self.keybindCancel setText( &"ZM_VACANT_BOONS_CANCEL_KEYBIND" );
    self.keybindCancel.alpha = 1;

    while(1)
    {
        if( self.hasBoon == true )
        {
            self.keybindCancel.alpha = 1;

            if( self.boon_now_you_see_me == true || self.boon_dead_of_nuclear_winter == true || self.boon_ephemeral_enhancement == true || self.boon_im_feeling_lucky == true || self.boon_immolation_liquidation == true || self.boon_licensed_contractor == true || self.boon_whos_keeping_score == true || self.boon_fatal_contraption == true || self.boon_crawl_space == true || self.boon_mind_blown == true || self.boon_cache_back == true || self.boon_kill_joy == true || self.boon_on_the_house == true || self.boon_fear_in_headlights == true || self.boon_temporal_gift == true || self.boon_bullet_boost == true || self.boon_killing_time == true || self.boon_round_robbin == true )
            {
                self.keybindUse.alpha = 1;
            }
            else
            {
                self.keybindUse.alpha = 0;
            }
        }
        else
        {
            self.keybindUse.alpha = 0;
            self.keybindCancel.alpha = 0;
        }
        wait(0.05);
    }
}

function cleanup_keybind_hud()
{
    if( isDefined( self.keybindUse ) )
        self.keybindUse destroy();

    if( isDefined( self.keybindCancel ) )
        self.keybindCancel destroy();

}

function monitor_cancel()
{
    self endon( "disconnect" );
    self endon( "death" );

    while(1)
    {
        if( self ActionSlotFourButtonPressed() )
        {
            while( self ActionSlotFourButtonPressed() )
                wait(0.05);

            self notify( "cancel_boon" );
            self.hasBoon = false;
            self thread cleanup_boon_charge_hud();
            self thread cleanup_boon_charge_timer();

            if( self.boon_coagulant == true )
            {
                self.boon_coagulant = false;
                self thread create_boon_info( "Coagulant", "has faded..." );
            }
            else if( self.boon_endless_stream == true )
            {
                self.boon_endless_stream = false;
                self thread create_boon_info( "Endless Stream", "has faded..." );
            }
            else if( self.boon_sword_flay == true )
            {
                self.boon_sword_flay = false;
                self thread create_boon_info( "Sword Flay", "has faded..." );
            }
            else if( self.boon_danger_closest == true )
            {
                self.boon_danger_closest = false;
                self thread create_boon_info( "Danger Closest", "has faded..." );
            }
            else if( self.boon_now_you_see_me == true )
            {
                self.boon_now_you_see_me = false;
                self.attracting_zombies = false;
                self thread create_boon_info( "Now You See Me", "has faded..." );
            }
            else if( self.boon_dead_of_nuclear_winter == true )
            {
                self.boon_dead_of_nuclear_winter = false;
                self thread create_boon_info( "Dead of Nuclear Winter", "has faded..." );
            }
            else if( self.boon_burned_out == true )
            {
                self.boon_burned_out = false;
                self thread create_boon_info( "Burned Out", "has faded..." );
            }
            else if( self.boon_ephemeral_enhancement == true )
            {
                self.boon_ephemeral_enhancement = false;
                self thread create_boon_info( "Ephemeral Enhancement", "has faded..." );
            }
            else if( self.boon_im_feeling_lucky == true )
            {
                self.boon_im_feeling_lucky = false;
                self thread create_boon_info( "I'm Feeling Lucky", "has faded..." );
            }
            else if( self.boon_immolation_liquidation == true )
            {
                self.boon_immolation_liquidation = false;
                self thread create_boon_info( "Immolation Liquidation", "has faded..." );
            }
            else if( self.boon_licensed_contractor == true )
            {
                self.boon_licensed_contractor = false;
                self thread create_boon_info( "Licensed Contractor", "has faded..." );
            }
            else if( self.boon_pop_shocks == true )
            {
                self.boon_pop_shocks = false;
                self thread create_boon_info( "Pop Shocks", "has faded..." );
            }
            else if( self.boon_unquenchable == true )
            {
                self.boon_unquenchable = false;
                self thread create_boon_info( "Unquenchable", "has faded..." );
            }
            else if( self.boon_whos_keeping_score == true )
            {
                self.boon_whos_keeping_score = false;
                self thread create_boon_info( "Who's Keeping Score?", "has faded..." );
            }
            else if( self.boon_fatal_contraption == true )
            {
                self.boon_fatal_contraption = false;
                self thread create_boon_info( "Fatal Contraption", "has faded..." );
            }
            else if( self.boon_crawl_space == true )
            {
                self.boon_crawl_space = false;
                self thread create_boon_info( "Crawl Space", "has faded..." );
            }
            else if( self.boon_disorderly_combat == true )
            {
                self.boon_disorderly_combat = false;
                self thread create_boon_info( "Disorderly Combat", "has faded..." );
            }
            else if( self.boon_slaughter_slide == true )
            {
                self.boon_slaughter_slide = false;
                self thread create_boon_info( "Slaughter Slide", "has faded..." );
            }
            else if( self.boon_mind_blown == true )
            {
                self.boon_mind_blown = false;
                self thread create_boon_info( "Mind Blown", "has faded..." );
            }
            else if( self.boon_cache_back == true )
            {
                self.boon_cache_back = false;
                self thread create_boon_info( "Cache Back", "has faded..." );
            }
            else if( self.boon_kill_joy == true )
            {
                self.boon_kill_joy = false;
                self thread create_boon_info( "Kill Joy", "has faded..." );
            }
            else if( self.boon_on_the_house == true )
            {
                self.boon_on_the_house = false;
                self thread create_boon_info( "On The House", "has faded..." );
            }
            else if( self.boon_wall_power == true )
            {
                self.boon_wall_power = false;
                self thread create_boon_info( "Wall Power", "has faded..." );
            }
            else if( self.boon_undead_man_walking == true )
            {
                self.boon_undead_man_walking = false;
                self thread create_boon_info( "Undead Man Walking", "has faded..." );
            }
            else if( self.boon_fear_in_headlights == true )
            {
                self.boon_fear_in_headlights = false;
                self thread create_boon_info( "Fear in Headlights", "has faded..." );
            }
            else if( self.boon_temporal_gift == true )
            {
                self.boon_temporal_gift = false;
                self thread create_boon_info( "Temporal Gift", "has faded..." );
            }
            else if( self.boon_crate_power == true )
            {
                self.boon_crate_power = false;
                self thread create_boon_info( "Crate Power", "has faded..." );
            }
            else if( self.boon_bullet_boost == true )
            {
                self.boon_bullet_boost = false;
                self thread create_boon_info( "Bullet Boost", "has faded..." );
            }
            else if( self.boon_killing_time == true )
            {
                self.boon_killing_time = false;
                self thread create_boon_info( "Killing Time", "has faded..." );
            }
            else if( self.boon_perkaholic == true )
            {
                self.boon_perkaholic = false;
                self thread create_boon_info( "Perkaholic", "has faded..." );
            }
            else if( self.boon_head_drama == true )
            {
                self.boon_head_drama = false;
                self thread create_boon_info( "Head Drama", "has faded..." );
            }
            else if( self.boon_secret_shopper == true )
            {
                self.boon_secret_shopper = false;
                self thread create_boon_info( "Secret Shopper", "has faded..." );
            }
            else if( self.boon_shopping_free == true )
            {
                self.boon_shopping_free = false;
                self thread create_boon_info( "Shopping Free", "has faded..." );
            }
            else if( self.boon_near_death_experience == true )
            {
                self.boon_near_death_experience = false;
                self thread create_boon_info( "Near Death Experience", "has faded..." );
            }
            else if( self.boon_profit_sharing == true )
            {
                self.boon_profit_sharing = false;
                self thread create_boon_info( "Profit Sharing", "has faded..." );
            }
            else if( self.boon_round_robbin == true )
            {
                self.boon_round_robbin = false;
                self thread create_boon_info( "Round Robbin'", "has faded..." );
            }
            else if( self.boon_self_medication == true )
            {
                self.boon_self_medication = false;
                self thread create_boon_info( "Self Medication", "has faded..." );
            }
        }

        wait(0.05);
    }
}

//*************************
// Boon: Coagulant
//*************************
function setup_boon_coagulant()
{
    self endon( "cancel_boon" );

    if( self.boon_coagulant == true )
        return;

    self endon( "disconnect" );
    self endon( "death" );

    self thread create_boon_info( "Coagulant", "Bleedout time is doubled. Lasts for 20 minutes." );

    self.boon_coagulant = true;

    // 20 minutes
    wait(1200);

    self.boon_coagulant = false;

    self thread create_boon_info( "Coagulant", "has faded..." );
    self.hasBoon = false;
}

//*************************
// Boon: Endless Stream
//*************************
function setup_boon_endless_stream()
{
    self endon( "cancel_boon" );

    if( self.boon_endless_stream == true )
        return;

    self endon( "disconnect" );
    self endon( "death" );

    self thread create_boon_info( "Endless Stream", "Ammo in the clip is instantly replenished. Lasts for 60 seconds." );
    self.boon_endless_stream = true;

    self thread boon_charge_hud( "Endless Stream!", "" );
    self thread call_boon_charge_timer(self.boon_charge_text, 60);

    while(self.boon_endless_stream)
    {
        curWeapon = self GetCurrentWeapon();
        self setWeaponAmmoClip( curWeapon, 99 );

        wait(0.05);
    }

    self thread cleanup_boon_charge_hud();

    self.boon_endless_stream = false;
    self.hasBoon = false;

    self thread create_boon_info( "Endless Stream", "has faded..." );
}

//*************************
// Boon: Sword Flay
//*************************
function setup_boon_sword_flay()
{
    self endon( "cancel_boon" );

    if( self.boon_sword_flay == true )
        return;

    self.boon_sword_flay = true;

    self thread create_boon_info( "Sword Flay", "Melee attacks will inflict 5x more damage on zombies. Lasts for 60 seconds." );

    self thread boon_charge_hud( "Sword Flay!", "" );
    self thread call_boon_charge_timer(self.boon_charge_text, 60);

    wait( 60 );

    self thread cleanup_boon_charge_hud();

    self.boon_sword_flay = false;
    self.hasBoon = false;

    self thread create_boon_info( "Sword Flay", "has faded..." );
}

//*************************
// Boon: Danger Closest
//*************************
function setup_boon_danger_closest()
{
    self endon( "cancel_boon" );

    if( self.boon_danger_closest == true )
        return;

    self.boon_danger_closest = true;
    self.boon_charges = 3;

    self thread create_boon_info( "Danger Closest", "Explosives no longer harm you. Lasts for 3 rounds." );

    self thread boon_charge_hud( self.boon_charges, "Rounds" );
    self thread monitor_danger_closest();
}

function monitor_danger_closest()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    while(self.boon_charges > 0)
    {
        level waittill( "start_of_round" );
        self.boon_charges--;
        self thread update_boon_charge_hud( self.boon_charges, "Rounds" );
    }

    self thread cleanup_boon_charge_hud();

    self thread create_boon_info( "Danger Closest", "has faded..." );
    self.boon_danger_closest = false;
    self.hasBoon = false;
}

//*************************
// Boon: Now You See Me
//*************************
function setup_boon_now_you_see_me()
{
    if( self.boon_now_you_see_me == true )
        return;

    self.boon_now_you_see_me = true;
    self.boon_charges = 2;
    self.attracting_zombies = false;

    self thread create_boon_info( "Now You See Me", "All zombies will chase you. 2 activations." );

    self thread boon_charge_hud( self.boon_charges, "Charges" );
    self thread monitor_now_you_see_me();
}

function monitor_now_you_see_me()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() && !self.attracting_zombies )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            self.attracting_zombies = true;

            self thread call_boon_charge_timer(self.boon_charge_text, 10);

            counter = 0;
            while(counter<200)
            {
                self thread attract_zombies();
                counter++;
                wait(0.05);
            }

            self.attracting_zombies = false;

        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_now_you_see_me = false;
    self.hasBoon = false;

    self thread create_boon_info( "Now You See Me", "has faded..." );
}

function attract_zombies()
{
	self endon( "disconnect" );
    self endon( "cancel_boon" );

    max_attract_dist    = level.monkey_attract_dist;
    num_attractors      = level.num_monkey_attractors;
    attract_dist_diff   = level.monkey_attract_dist_diff;

    valid_poi = zm_utility::check_point_in_enabled_zone( self.origin, undefined, undefined );

    if ( IS_TRUE( level.move_valid_poi_to_navmesh ) )
    {
        valid_poi = self _zm_weap_cymbal_monkey::move_valid_poi_to_navmesh( valid_poi );
    }

    if ( isdefined( level.check_valid_poi ) )
    {
        valid_poi = self [[ level.check_valid_poi ]]( valid_poi );
    }

    if(valid_poi)
    {
        //self iPrintLnBold( "ATTRACTING" );
        self zm_utility::create_zombie_point_of_interest( max_attract_dist, num_attractors, 10000 );
        self.attract_to_origin = true;
        self thread zm_utility::create_zombie_point_of_interest_attractor_positions( 4, attract_dist_diff );
		self thread zm_utility::wait_for_attractor_positions_complete();
    }
}

//*************************
// Boon: Dead of Nuclear Winter
//*************************
function setup_boon_dead_of_nuclear_winter()
{
    if( self.boon_dead_of_nuclear_winter == true )
        return;

    self.boon_dead_of_nuclear_winter = true;
    self.boon_charges = 2;
    self thread create_boon_info( "Dead of Nuclear Winter", "Spawns a Nuke Power-Up. 2 activations." );

    self thread boon_charge_hud( self.boon_charges, "Charges" );
    self thread monitor_dead_of_nuclear_winter();
}

function monitor_dead_of_nuclear_winter()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "nuke", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_dead_of_nuclear_winter = false;
    self.hasBoon = false;

    self thread create_boon_info( "Dead of Nuclear Winter", "has faded..." );
}

//*************************
// Boon: Aftertaste
//*************************

//*************************
// Boon: Burned Out
//*************************
function setup_boon_burned_out()
{
    self endon( "cancel_boon" );

    if( self.boon_burned_out == true )
        return;

    self.boon_burned_out = true;
    self.boon_charges = 2;

    self thread create_boon_info( "Burned Out", "The next time the player takes damage, nearby zombies burst into fire. Lasts 2 hits." );

    self thread boon_charge_hud( self.boon_charges, "Hits" );

    self waittill( "burned_out_expired" );

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_burned_out = false;
    self.hasBoon = false;

    self thread create_boon_info( "Burned Out", "has faded..." );
}

function immolate_nearby_zombies()
{
    player = self;
    zombies = getEntArray( "zombie", "targetname" );

    if( !isDefined( zombies ) )
        return;

    foreach( zombie in zombies )
    {
        // 1 map unit approx. = 135 distance units
        distance = DistanceSquared( player getOrigin(), zombie getOrigin() );

        if( distance < 25920 )
        {
            zombie thread zm_traps::zombie_flame_watch();
            zombie playsound("zmb_ignite");

            zombie thread zombie_death::flame_death_fx();
            PlayFxOnTag( level._effect["character_fire_death_torso"], zombie, "J_SpineLower" );

            wait( randomfloat(1.25) );

            zombie dodamage(zombie.health + 666, zombie.origin, player);
        }
    }
}

//*************************
// Boon: Ephemeral Enhancement
//*************************
function setup_boon_ephemeral_enhancement()
{
    if( self.boon_ephemeral_enhancement == true )
        return;

    self.boon_ephemeral_enhancement = true;
    self.boon_charges = 2;
    self.weapon_currently_papped = false;

    self thread create_boon_info( "Ephemeral Enhancement", "Turns the weapon in the player's hands into the Pack-A-Punched version for 60 seconds. 2 activations." );

    self thread boon_charge_hud( self.boon_charges, "Charges" );
    self thread monitor_ephemeral_enhancement();
    self thread monitor_cancel_ephemeral_enhancement();
}

function monitor_cancel_ephemeral_enhancement()
{
    self endon( "ephemeral_enhancement_over" );
    self waittill( "cancel_boon" );

    if(self.weapon_currently_papped)
    {
        self.currentClip_ee = self getWeaponAmmoClip( self.upgrade_weapon_ee );
        self.currentStock_ee = self getWeaponAmmoStock( self.upgrade_weapon_ee );

        self takeWeapon(self.upgrade_weapon_ee);
        self giveWeapon( self.oldWeapon_ee );
        self SwitchToWeapon( self.oldWeapon_ee );
        self SetWeaponAmmoClip( self.oldWeapon_ee, self.currentClip_ee );
        self SetWeaponAmmoStock( self.oldWeapon_ee, self.currentStock_ee );
    }

    self thread cleanup_boon_charge_hud();

    self.boon_ephemeral_enhancement = false;
    self.hasBoon = false;

    self thread create_boon_info( "Ephemeral Enhancement", "has faded..." );
}

function monitor_ephemeral_enhancement()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            self thread upgrade_current_weapon();
        }

        wait(0.05);
    }

    // Wait for the final effect to end
    while(self.weapon_currently_papped)
        wait(0.05);

    // Cleanup
    self notify( "ephemeral_enhancement_over" );
    self thread cleanup_boon_charge_hud();

    self.boon_ephemeral_enhancement = false;
    self.hasBoon = false;

    self thread create_boon_info( "Ephemeral Enhancement", "has faded..." );
}

function upgrade_current_weapon()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Return if effect is already active
    if( isDefined( self.weapon_currently_papped ) && self.weapon_currently_papped == true )
    {
        self iPrintLnBold( "Effect still active." );
        self.boon_charges++;
        self thread update_boon_charge_hud( self.boon_charges, "Charges" );
        return;
    }

    self.weapon_currently_papped = true;

    self.curWeapon_ee = self getCurrentWeapon();
    self.oldWeapon_ee = self.curWeapon_ee;

    self.currentClip_ee = self getWeaponAmmoClip( self.curWeapon_ee );
    self.currentStock_ee = self getWeaponAmmoStock( self.curWeapon_ee );

    if ( !self zm_weapons::can_upgrade_weapon( self.curWeapon_ee ) && !zm_weapons::weapon_supports_aat( self.curWeapon_ee ) )
	{
        self iPrintLnBold( "Try a different weapon." );

        // Restore charge
        self.weapon_currently_papped = false;
        self.boon_charges++;
        self thread update_boon_charge_hud( self.boon_charges, "Charges" );

		return;
	}
    else
    {
        self.upgrade_weapon_ee = zm_weapons::get_upgrade_weapon( self.curWeapon_ee, true );

        self takeWeapon( self.curWeapon_ee );
        self giveWeapon( self.upgrade_weapon_ee );
        self SwitchToWeapon( self.upgrade_weapon_ee );
        self SetWeaponAmmoClip( self.upgrade_weapon_ee, self.currentClip_ee );
        self SetWeaponAmmoStock( self.upgrade_weapon_ee, self.currentStock_ee );
    }

    self thread call_boon_charge_timer(self.boon_charge_text, 60);

    wait(60);

    self.weapon_currently_papped = false;

    self.currentClip_ee = self getWeaponAmmoClip( self.upgrade_weapon_ee );
    self.currentStock_ee = self getWeaponAmmoStock( self.upgrade_weapon_ee );

    self takeWeapon(self.upgrade_weapon_ee);
    self giveWeapon( self.oldWeapon_ee );
    self SwitchToWeapon( self.oldWeapon_ee );
    self SetWeaponAmmoClip( self.oldWeapon_ee, self.currentClip_ee );
    self SetWeaponAmmoStock( self.oldWeapon_ee, self.currentStock_ee );
}

//*************************
// Boon: I'm Feeling Lucky
//*************************
function setup_boon_im_feeling_lucky()
{
    if( self.boon_im_feeling_lucky == true )
        return;

    self.boon_im_feeling_lucky = true;
    self.boon_charges = 2;
    self thread create_boon_info( "I'm Feeling Lucky", "Spawns a random Power-Up. 2 activations." );

    self thread boon_charge_hud( self.boon_charges, "Charges" );
    self thread monitor_im_feeling_lucky();
}


function monitor_im_feeling_lucky()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            r = RandomIntRange( 0, 9 );

            if( r == 1 )
            {
                level thread zm_powerups::specific_powerup_drop( "double_points", ( org[0], org[1], org[2] ) );
            }
            else if( r == 2 )
            {
                level thread zm_powerups::specific_powerup_drop( "minigun", ( org[0], org[1], org[2] ) );
            }
            else if( r == 3 )
            {
                level thread zm_powerups::specific_powerup_drop( "shield_charge", ( org[0], org[1], org[2] ) );
            }
            else if( r == 4 )
            {
                level thread zm_powerups::specific_powerup_drop( "nuke", ( org[0], org[1], org[2] ) );
            }
            else if( r == 5 )
            {
                level thread zm_powerups::specific_powerup_drop( "insta_kill", ( org[0], org[1], org[2] ) );
            }
            else if( r == 6 )
            {
                level thread zm_powerups::specific_powerup_drop( "full_ammo", ( org[0], org[1], org[2] ) );
            }
            else if( r == 7 )
            {
                level thread zm_powerups::specific_powerup_drop( "free_perk", ( org[0], org[1], org[2] ) );
            }
            else if( r == 8 )
            {
                level thread zm_powerups::specific_powerup_drop( "fire_sale", ( org[0], org[1], org[2] ) );
            }
            else if( r == 0 )
            {
                level thread zm_powerups::specific_powerup_drop( "carpenter", ( org[0], org[1], org[2] ) );
            }
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_im_feeling_lucky = false;
    self.hasBoon = false;

    self thread create_boon_info( "I'm Feeling Lucky", "has faded..." );
}

//*************************
// Boon: Immolation Liquidation
//*************************
function setup_boon_immolation_liquidation()
{
    if( self.boon_immolation_liquidation == true )
        return;

    self.boon_immolation_liquidation = true;
    self.boon_charges = 3;
    self thread create_boon_info( "Immolation Liquidation", "Spawns a Fire Sale Power-Up. 3 activations." );

    self thread boon_charge_hud( self.boon_charges, "Charges" );
    self thread monitor_immolation_liquidation();
}

function monitor_immolation_liquidation()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "fire_sale", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_immolation_liquidation = false;
    self.hasBoon = false;

    self thread create_boon_info( "Immolation Liquidation", "has faded..." );
}

//*************************
// Boon: Licensed Contractor
//*************************
function setup_boon_licensed_contractor()
{
    if( self.boon_licensed_contractor == true )
        return;

    self.boon_licensed_contractor = true;
    self.boon_charges = 3;

    self thread create_boon_info( "Licensed Contractor", "Spawns a Carpenter Power-Up. 3 activations." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_licensed_contractor();
}


function monitor_licensed_contractor()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "carpenter", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_licensed_contractor = false;
    self.hasBoon = false;

    self thread create_boon_info( "Licensed Contractor", "has faded..." );
}

//*************************
// Boon: Phoenix Up
//*************************

//*************************
// Boon: Pop Shocks
//*************************
function setup_boon_pop_shocks()
{
    self endon( "cancel_boon" );

    if( self.boon_pop_shocks == true )
        return;

    self.boon_pop_shocks = true;
    self.boon_charges = 5;

    self thread create_boon_info( "Pop Shocks", "Melee attacks trigger an electrostatic discharge, electrocuting nearby Zombies. 5 attacks." );
    self thread boon_charge_hud( self.boon_charges, "Attacks" );

    self waittill( "pop_shocks_expired" );

    self thread cleanup_boon_charge_hud();

    self.boon_pop_shocks = false;
    self.hasBoon = false;

    self thread create_boon_info( "Pop Shocks", "has faded..." );
}

function pop_shock_zombies()
{
    zombies = getEntArray( "zombie", "targetname" );

    if( !isDefined( zombies ) )
        return;

    foreach( zombie in zombies )
    {
        // 1 map unit approx. = 135 distance units
        distance = DistanceSquared( self getOrigin(), zombie getOrigin() );

        if( distance < 25920 )
        {
            self iPrintLnBold( "zombie hit" );
            playsoundatposition("wpn_zmb_electrap_zap", zombie.origin);

            zombie thread electroctute_death_fx();
            zombie notify( "bhtn_action_notify", "electrocute" );

            wait( randomfloat(1.25) );

            zombie playsound("wpn_zmb_electrap_zap");
            zombie dodamage(zombie.health + 666, zombie.origin, self);
        }
    }
}

function electroctute_death_fx()
{
	if (isdefined(level._effect["elec_torso"]))
		PlayFxOnTag( level._effect["elec_torso"], self, "J_SpineLower" );

	self playsound ("zmb_elec_jib_zombie");

	wait 1;

	tagArray = [];
	tagArray[0] = "J_Elbow_LE";
	tagArray[1] = "J_Elbow_RI";
	tagArray[2] = "J_Knee_RI";
	tagArray[3] = "J_Knee_LE";
	tagArray = array::randomize( tagArray );

	if (isdefined(level._effect["elec_md"]))
		PlayFxOnTag( level._effect["elec_md"], self, tagArray[0] );
	self playsound ("zmb_elec_jib_zombie");

	wait 1;
	self playsound ("zmb_elec_jib_zombie");

	tagArray[0] = "J_Wrist_RI";
	tagArray[1] = "J_Wrist_LE";
	if( !isdefined( self.a.gib_ref ) || self.a.gib_ref != "no_legs" )
	{
		tagArray[2] = "J_Ankle_RI";
		tagArray[3] = "J_Ankle_LE";
	}
	tagArray = array::randomize( tagArray );

	if (isdefined(level._effect["elec_sm"]))
	{
		PlayFxOnTag( level._effect["elec_sm"], self, tagArray[0] );
		PlayFxOnTag( level._effect["elec_sm"], self, tagArray[1] );
	}

}

//*************************
// Boon: Respin Cycle
//*************************

//*************************
// Boon: Unquenchable
//*************************
function setup_unquenchable()
{
    self endon( "disconnect" );
    self endon( "cancel_boon" );

    if( self.boon_unquenchable == true )
        return;

    self.boon_unquenchable = true;

    self thread create_boon_info( "Unquenchable", "Can buy an extra Perk-a-Cola." );

    // Revert boon status early
    self.hasBoon = false;

    self waittill( "unquenchable_expired" );

    self.boon_unquenchable = false;
    self thread create_boon_info( "Unquenchable", "has faded..." );
}

//*************************
// Boon: Who's Keeping Score
//*************************
function setup_boon_whos_keeping_score()
{
    if( self.boon_whos_keeping_score == true )
        return;

    self.boon_whos_keeping_score = true;
    self.boon_charges = 2;

    self thread create_boon_info( "Who's Keeping Score?", "Spawns a Double Points Power-Up. 2 activations." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_whos_keeping_score();
}


function monitor_whos_keeping_score()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "double_points", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_whos_keeping_score = false;
    self.hasBoon = false;

    self thread create_boon_info( "Who's Keeping Score?", "has faded..." );
}

//*************************
// Boon: Fatal Contraption
//*************************
function setup_boon_fatal_contraption()
{
    if( self.boon_fatal_contraption == true )
        return;

    self.boon_fatal_contraption = true;
    self.boon_charges = 2;

    self thread create_boon_info( "Fatal Contraption", "Spawns a Death Machine Power-Up. 3 activations." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_fatal_contraption();
}


function monitor_fatal_contraption()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "minigun", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_fatal_contraption = false;
    self.hasBoon = false;

    self thread create_boon_info( "Fatal Contraption", "has faded..." );
}

//*************************
// Boon: Crawl Space
//*************************
function setup_boon_crawl_space()
{
    if( self.boon_crawl_space == true )
        return;

    self.boon_crawl_space = true;
    self.boon_charges = 5;

    self thread create_boon_info( "Crawl Space", "All nearby zombies become crawlers. 5 activations." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_crawl_space();
}

function monitor_crawl_space()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            self thread gib_zombies();
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_crawl_space = false;
    self.hasBoon = false;

    self thread create_boon_info( "Crawl Space", "has faded..." );
}

function gib_zombies()
{
    zombies = getEntArray( "zombie", "targetname" );

    if( !isDefined( zombies ) )
        return;

    foreach( zombie in zombies )
    {
        // 1 map unit approx. = 135 distance units
        distance = DistanceSquared( self getOrigin(), zombie getOrigin() );

        if( distance < 25920 )
        {
            self iPrintLnBold( "zombie gib" );

            zombie.a.gib_ref = "right_leg";
			zombie thread zombie_death::do_gib();

            zombie.a.gib_ref = "left_leg";
			zombie thread zombie_death::do_gib();


        }
    }
}

//*************************
// Boon: Disorderly Combat
//*************************
function setup_boon_disorderly_combat()
{
    if( self.boon_disorderly_combat == true )
        return;

    self.boon_disorderly_combat = true;

    self thread create_boon_info( "Disorderly Combat", "Gives a random gun every 10 seconds. Lasts 5 minutes." );
    self thread boon_charge_hud( "Disorderly Combat", "" );

    self thread monitor_disorderly_combat();
}

function monitor_disorderly_combat()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    time = 0;

    self.curWeapon_dc = self getCurrentWeapon();
    self takeWeapon( self.curWeapon_dc );
    self thread monitor_disorderly_combat_cancel();

    self thread call_boon_charge_timer( self.boon_charge_text, 300 );
    // Effect
    while(time < 300)
    {
        self.oldWeapon_dc = self thread randomizeWeapon();
        wait(10);
        time = time + 10;
        self takeWeapon( self.oldWeapon_dc );
    }

    // Cleanup
    self notify( "disorderly_combat_over" );
    self takeWeapon( self.oldWeapon_dc );
    self giveWeapon( self.curWeapon_dc );

    self thread cleanup_boon_charge_hud();

    self.boon_disorderly_combat = false;
    self.hasBoon = false;

    self thread create_boon_info( "Disorderly Combat", "has faded..." );
}

function monitor_disorderly_combat_cancel()
{
    self endon( "disorderly_combat_over" );
    self waittill( "cancel_boon" );

    self takeWeapon( self.oldWeapon_dc );
    self giveWeapon( self.curWeapon_dc );
}

function randomizeWeapon()
{
    max = 56;
    r = RandomIntRange( 0, max );

    switch( r )
    {
        case 0: newWeapon = getWeapon( "pistol_standard" ); break;
        case 1: newWeapon = getWeapon( "pistol_standard_upgraded" ); break;
        case 2: newWeapon = getWeapon( "ray_gun" ); break;
        case 3: newWeapon = getWeapon( "ray_gun_upgraded" ); break;
        case 4: newWeapon = getWeapon( "tesla_gun" ); break;
        case 5: newWeapon = getWeapon( "tesla_gun_upgraded" ); break;
        case 6: newWeapon = getWeapon( "ar_accurate" ); break;
        case 7: newWeapon = getWeapon( "ar_accurate_upgraded" ); break;
        case 8: newWeapon = getWeapon( "ar_cqb" ); break;
        case 9: newWeapon = getWeapon( "ar_cqb_upgraded" ); break;
        case 10: newWeapon = getWeapon( "ar_damage" ); break;
        case 11: newWeapon = getWeapon( "ar_damage_upgraded" ); break;
        case 12: newWeapon = getWeapon( "ar_longburst" ); break;
        case 13: newWeapon = getWeapon( "ar_longburst_upgraded" ); break;
        case 14: newWeapon = getWeapon( "ar_marksman" ); break;
        case 15: newWeapon = getWeapon( "ar_marksman_upgraded" ); break;
        case 16: newWeapon = getWeapon( "ar_standard" ); break;
        case 17: newWeapon = getWeapon( "ar_standard_upgraded" ); break;
        case 18: newWeapon = getWeapon( "lmg_cqb" ); break;
        case 19: newWeapon = getWeapon( "lmg_cqb_upgraded" ); break;
        case 20: newWeapon = getWeapon( "lmg_heavy" ); break;
        case 21: newWeapon = getWeapon( "lmg_heavy_upgraded" ); break;
        case 22: newWeapon = getWeapon( "lmg_light" ); break;
        case 23: newWeapon = getWeapon( "lmg_light_upgraded" ); break;
        case 24: newWeapon = getWeapon( "lmg_slowfire" ); break;
        case 25: newWeapon = getWeapon( "lmg_slowfire_upgraded" ); break;
        case 26: newWeapon = getWeapon( "pistol_burst" ); break;
        case 27: newWeapon = getWeapon( "pistol_burst_upgraded" ); break;
        case 28: newWeapon = getWeapon( "pistol_fullauto" ); break;
        case 29: newWeapon = getWeapon( "pistol_fullauto_upgraded" ); break;
        case 30: newWeapon = getWeapon( "shotgun_fullauto" ); break;
        case 31: newWeapon = getWeapon( "shotgun_fullauto_upgraded" ); break;
        case 32: newWeapon = getWeapon( "shotgun_precision" ); break;
        case 33: newWeapon = getWeapon( "shotgun_precision_upgraded" ); break;
        case 34: newWeapon = getWeapon( "shotgun_pump" ); break;
        case 35: newWeapon = getWeapon( "shotgun_pump_upgraded" ); break;
        case 36: newWeapon = getWeapon( "shotgun_semiauto" ); break;
        case 37: newWeapon = getWeapon( "shotgun_semiauto_upgraded" ); break;
        case 38: newWeapon = getWeapon( "launcher_standard" ); break;
        case 39: newWeapon = getWeapon( "launcher_standard_upgraded" ); break;
        case 40: newWeapon = getWeapon( "smg_burst" ); break;
        case 41: newWeapon = getWeapon( "smg_burst_upgraded" ); break;
        case 42: newWeapon = getWeapon( "smg_capacity" ); break;
        case 43: newWeapon = getWeapon( "smg_capacity_upgraded" ); break;
        case 44: newWeapon = getWeapon( "smg_fastfire" ); break;
        case 45: newWeapon = getWeapon( "smg_fastfire_upgraded" ); break;
        case 46: newWeapon = getWeapon( "smg_standard" ); break;
        case 47: newWeapon = getWeapon( "smg_standard_upgraded" ); break;
        case 48: newWeapon = getWeapon( "smg_versatile" ); break;
        case 49: newWeapon = getWeapon( "smg_versatile_upgraded" ); break;
        case 50: newWeapon = getWeapon( "sniper_fastbolt" ); break;
        case 51: newWeapon = getWeapon( "sniper_fastbolt_upgraded" ); break;
        case 52: newWeapon = getWeapon( "sniper_fastsemi" ); break;
        case 53: newWeapon = getWeapon( "sniper_fastsemi_upgraded" ); break;
        case 54: newWeapon = getWeapon( "sniper_powerbolt" ); break;
        case 55: newWeapon = getWeapon( "sniper_powerbolt_upgraded" ); break;
        default: newWeapon = getWeapon( "pistol_standard" ); break;
    }

    self giveWeapon( newWeapon );
    self switchToWeapon( newWeapon );

    return newWeapon;
}

//*************************
// Boon: Slaughter Slide
//*************************
function setup_boon_slaughter_slide()
{
    if( self.boon_slaughter_slide == true )
        return;

    self.boon_slaughter_slide = true;
    self.boon_charges = 6;

    self thread create_boon_info( "Slaughter Slide", "Create 2 lethal explosions by sliding. " );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_slaughter_slide_start();
    self thread monitor_slaughter_slide_end();
}

function monitor_slaughter_slide_end()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        self waittill( "slide_end" );

        self.boon_charges--;
        self thread update_boon_charge_hud( self.boon_charges, "Charges" );

        self thread damage_zombies( 25920, 1000 );

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_slaughter_slide = false;
    self.hasBoon = false;

    self thread create_boon_info( "Slaughter Slide", "has faded..." );
}

function monitor_slaughter_slide_start()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        self waittill( "slide_begin" );

        self thread damage_zombies( 25920, 1000 );

        wait(0.05);
    }
}

function damage_zombies( dist, damage )
{
    zombies = getEntArray( "zombie", "targetname" );

    foreach( zombie in zombies )
    {
        if( !isDefined( zombie ) )
            continue;

        distance = DistanceSquared( self getOrigin(), zombie getOrigin() );

        if( distance < dist )
        {
            zombie thread zm_traps::zombie_flame_watch();
            zombie playsound("zmb_ignite");

            zombie thread zombie_death::flame_death_fx();
            PlayFxOnTag( level._effect["character_fire_death_torso"], zombie, "J_SpineLower" );

            zombie dodamage(damage, zombie.origin, self);
        }
    }
}

//*************************
// Boon: Mind Blown
//*************************
function setup_boon_mind_blown()
{
    if( self.boon_mind_blown == true )
        return;

    self.boon_mind_blown = true;
    self.boon_charges = 5;

    self thread create_boon_info( "Mind Blown", "Gib the heads of all the zombies you can see, killing them. 3 activations." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_mind_blown();
}

function monitor_mind_blown()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            self thread gib_zombie_heads();
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_mind_blown = false;
    self.hasBoon = false;

    self thread create_boon_info( "Mind Blown", "has faded..." );
}

function gib_zombie_heads()
{
    zombies = getEntArray( "zombie", "targetname" );

    if( !isDefined( zombies ) )
        return;

    foreach( zombie in zombies )
    {
        visibility = zombie SightConeTrace( self.origin + ( 0, 0, 32 ), self, self.angles, 180 );

        //self iPrintLnBold( visibility );
        if( visibility > 0 )
        {
            zombie dodamage(99999, zombie.origin, self);

            zombie.a.gib_ref = "head";
			zombie thread zombie_death::do_gib();
        }
    }
}

//*************************
// Boon: Cache Back
//*************************
function setup_boon_cache_back()
{
    if( self.boon_cache_back == true )
        return;

    self.boon_cache_back = true;
    self.boon_charges = 1;

    self thread create_boon_info( "Cache Back", "Spawns a Max Ammo Power-Up. 1 activation." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_cache_back();
}


function monitor_cache_back()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "full_ammo", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_cache_back = false;
    self.hasBoon = false;

    self thread create_boon_info( "Cache Back", "has faded..." );
}

//*************************
// Boon: Kill Joy
//*************************
function setup_boon_kill_joy()
{
    if( self.boon_kill_joy == true )
        return;

    self.boon_kill_joy = true;
    self.boon_charges = 2;

    self thread create_boon_info( "Kill Joy", "Spawns an Insta-Kill Power-Up.. 2 activations." );
    self thread boon_charge_hud( self.boon_charges, "Charges" );

    self thread monitor_kill_joy();
}


function monitor_kill_joy()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "cancel_boon" );

    // Effect
    while(self.boon_charges > 0)
    {
        if( self ActionSlotOneButtonPressed() )
        {
            while( self ActionSlotOneButtonPressed() )
                wait(0.05);

            self.boon_charges--;
            self thread update_boon_charge_hud( self.boon_charges, "Charges" );

            org = self.origin;
            org = ( org[0], org[1], org[2] );

            level thread zm_powerups::specific_powerup_drop( "insta_kill", ( org[0], org[1], org[2] ) );
        }

        wait(0.05);
    }

    // Cleanup
    self thread cleanup_boon_charge_hud();

    self.boon_kill_joy = false;
    self.hasBoon = false;

    self thread create_boon_info( "Cache Back", "has faded..." );
}

//*************************
// Boon: On the House
//*************************

//*************************
// Boon: Wall Power
//*************************

//*************************
// Boon: Undead Man Walking
//*************************

//*************************
// Boon: Fear in Headlights
//*************************

//*************************
// Boon: Temporal Gift
//*************************

//*************************
// Boon: Crate Power
//*************************

//*************************
// Boon: Bullet Boost
//*************************

//*************************
// Boon: Killing Time
//*************************

//*************************
// Boon: Perkaholic
//*************************

//*************************
// Boon: Head Drama
//*************************

//*************************
// Boon: Secret Shopper
//*************************

//*************************
// Boon: Shopping Free
//*************************

//*************************
// Boon: Near Death Experience
//*************************

//*************************
// Boon: Profit Sharing
//*************************

//*************************
// Boon: Round Robbin'
//*************************

//*************************
// Boon: Self Medication
//*************************
