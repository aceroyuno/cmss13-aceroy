//---------------------------------------------------

//Generic parent object.
/obj/item/weapon/gun/revolver
	flags_equip_slot = SLOT_WAIST
	w_class = SIZE_MEDIUM
	origin_tech = "combat=3;materials=2"
	matter = list("metal" = 2000)
	fire_sound = 'sound/weapons/gun_44mag_v3.ogg'
	reload_sound = 'sound/weapons/gun_44mag_speed_loader.wav'
	cocked_sound = 'sound/weapons/gun_revolver_spun.ogg'
	unload_sound = 'sound/weapons/gun_44mag_open_chamber.wav'
	var/chamber_close_sound = 'sound/weapons/gun_44mag_close_chamber.wav'
	var/hand_reload_sound = 'sound/weapons/gun_revolver_load3.ogg'
	var/spin_sound = 'sound/effects/spin.ogg'
	var/thud_sound = 'sound/effects/thud.ogg'
	var/trick_delay = 6
	var/recent_trick //So they're not spamming tricks.
	var/russian_roulette = 0 //God help you if you do this.
	type_of_casings = "bullet"
	flags_gun_features = GUN_CAN_POINTBLANK|GUN_INTERNAL_MAG|GUN_ONE_HAND_WIELDED
	wield_delay = WIELD_DELAY_VERY_FAST //If you modify your revolver to be two-handed, it will still be fast to aim
	gun_skill_category = SKILL_PISTOLS
	movement_acc_penalty_mult = 3
	has_empty_icon = FALSE
	has_open_icon = TRUE

/obj/item/weapon/gun/revolver/New()
	..() //Do all that other stuff.
	replace_cylinder(current_mag.current_rounds)

/obj/item/weapon/gun/revolver/set_gun_config_values()
	..()
	fire_delay = config.mhigh_fire_delay
	accuracy_mult = config.base_hit_accuracy_mult
	accuracy_mult_unwielded = config.base_hit_accuracy_mult - config.low_hit_accuracy_mult
	scatter = config.low_scatter_value
	scatter_unwielded = config.high_scatter_value
	damage_mult = config.base_hit_damage_mult
	recoil = config.min_recoil_value
	recoil_unwielded = config.med_recoil_value


/obj/item/weapon/gun/revolver/examine(mob/user)
	..()
	var/message = "[current_mag.chamber_closed? "It's closed.": "It's open with [current_mag.current_rounds] round\s loaded."]"
	to_chat(user, message)

/obj/item/weapon/gun/revolver/proc/rotate_cylinder(mob/user) //Cylinder moves backward.
	current_mag.chamber_position = current_mag.chamber_position == 1 ? current_mag.max_rounds : current_mag.chamber_position - 1

/obj/item/weapon/gun/revolver/proc/spin_cylinder(mob/user)
	if(current_mag.chamber_closed) //We're not spinning while it's open. Could screw up reloading.
		current_mag.chamber_position = rand(1,current_mag.max_rounds)
		to_chat(user, SPAN_NOTICE("You spin the cylinder."))
		playsound(user, cocked_sound, 25, 1)
		russian_roulette = !russian_roulette //Sets to play RR. Resets when the gun is emptied.

/obj/item/weapon/gun/revolver/proc/replace_cylinder(number_to_replace)
	current_mag.chamber_contents = list()
	current_mag.chamber_contents.len = current_mag.max_rounds
	var/i
	for(i = 1 to current_mag.max_rounds) //We want to make sure to populate the cylinder.
		current_mag.chamber_contents[i] = i > number_to_replace ? "empty" : "bullet"
	current_mag.chamber_position = max(1,number_to_replace)

/obj/item/weapon/gun/revolver/proc/empty_cylinder()
	for(var/i = 1 to current_mag.max_rounds)
		current_mag.chamber_contents[i] = "empty"

//The cylinder is always emptied out before a reload takes place.
/obj/item/weapon/gun/revolver/proc/add_to_cylinder(mob/user) //Bullets are added forward.
	//First we're going to try and replace the current bullet.
	if(!current_mag.current_rounds)
		current_mag.chamber_contents[current_mag.chamber_position] = "bullet"
	else //Failing that, we'll try to replace the next bullet in line.
		if((current_mag.chamber_position + 1) > current_mag.max_rounds)
			current_mag.chamber_contents[1] = "bullet"
			current_mag.chamber_position = 1
		else
			current_mag.chamber_contents[current_mag.chamber_position + 1] = "bullet"
			current_mag.chamber_position++
	playsound(user, hand_reload_sound, 25, 1)
	return 1

/obj/item/weapon/gun/revolver/reload(mob/user, obj/item/ammo_magazine/magazine)
	if(flags_gun_features & GUN_BURST_FIRING) return

	if(!magazine || !istype(magazine))
		to_chat(user, SPAN_WARNING("That's not gonna work!"))
		return

	if(magazine.current_rounds <= 0)
		to_chat(user, SPAN_WARNING("That [magazine.name] is empty!"))
		return

	if(istype(magazine, /obj/item/ammo_magazine/handful)) //Looks like we're loading via handful.
		if(current_mag.chamber_closed)
			to_chat(user, SPAN_WARNING("You can't load anything when the cylinder is closed!"))
			return
		if(!current_mag.current_rounds && current_mag.caliber == magazine.caliber) //Make sure nothing's loaded and the calibers match.
			replace_ammo(user, magazine) //We are going to replace the ammo just in case.
			current_mag.match_ammo(magazine)
			current_mag.transfer_ammo(magazine,user,1) //Handful can get deleted, so we can't check through it.
			add_to_cylinder(user)
		//If bullets still remain in the gun, we want to check if the actual ammo matches.
		else if(magazine.default_ammo == current_mag.default_ammo) //Ammo datums match, let's see if they are compatible.
			if(current_mag.transfer_ammo(magazine,user,1))
				add_to_cylinder(user)//If the magazine is deleted, we're still fine.
		else
			to_chat(user, "[current_mag] is [current_mag.current_rounds ? "already loaded with some other ammo. Better not mix them up." : "not compatible with that ammo."]") //Not the right kind of ammo.
	else //So if it's not a handful, it's an actual speedloader.
		if(current_mag.gun_type == magazine.gun_type) //Has to be the same gun type.
			if(current_mag.chamber_closed) // If the chamber is closed unload it
				unload(user)
			if(current_mag.transfer_ammo(magazine,user,magazine.current_rounds))//Make sure we're successful.
				replace_ammo(user, magazine) //We want to replace the ammo ahead of time, but not necessary here.
				current_mag.match_ammo(magazine)
				replace_cylinder(current_mag.current_rounds)
				playsound(user, reload_sound, 25, 1) // Reloading via speedloader.
				if(!current_mag.chamber_closed) // If the chamber is open, we close it
					unload(user)
		else
			to_chat(user, SPAN_WARNING("That [magazine] doesn't fit!"))

/obj/item/weapon/gun/revolver/unload(mob/user)
	if(flags_gun_features & GUN_BURST_FIRING) return

	if(current_mag.chamber_closed) //If it's actually closed.
		to_chat(user, SPAN_NOTICE("You clear the cylinder of [src]."))
		make_casing(type_of_casings)
		empty_cylinder()
		current_mag.create_handful(user)
		current_mag.chamber_closed = !current_mag.chamber_closed
		russian_roulette = !russian_roulette //Resets the RR variable.
		playsound(src, chamber_close_sound, 25, 1)
	else
		current_mag.chamber_closed = !current_mag.chamber_closed
		playsound(src, unload_sound, 25, 1)
	update_icon()
	return

/obj/item/weapon/gun/revolver/make_casing()
	if(current_mag.used_casings)
		. = ..()
		current_mag.used_casings = 0 //Always dump out everything.

/obj/item/weapon/gun/revolver/able_to_fire(mob/user)
	. = ..()
	if(. && istype(user) && !current_mag.chamber_closed)
		to_chat(user, SPAN_WARNING("Close the cylinder!"))
		return 0

/obj/item/weapon/gun/revolver/ready_in_chamber()
	if(current_mag.current_rounds > 0)
		if(current_mag.chamber_contents[current_mag.chamber_position] == "bullet")
			current_mag.current_rounds-- //Subtract the round from the mag.
			in_chamber = create_bullet(ammo, initial(name))
			return in_chamber
	else
		if(current_mag.chamber_closed)
			unload(null)

/obj/item/weapon/gun/revolver/load_into_chamber(mob/user)
//		if(active_attachable) active_attachable = null
	if(ready_in_chamber())
		return in_chamber
	rotate_cylinder() //If we fail to return to chamber the round, we just move the firing pin some.

/obj/item/weapon/gun/revolver/reload_into_chamber(mob/user)
	current_mag.chamber_contents[current_mag.chamber_position] = "blank" //We shot the bullet.
	current_mag.used_casings++ //We add this only if we actually fired the bullet.
	rotate_cylinder()
	return 1

/obj/item/weapon/gun/revolver/delete_bullet(obj/item/projectile/projectile_to_fire, refund = 0)
	qdel(projectile_to_fire)
	if(refund)
		current_mag.current_rounds++
	return 1

// FLUFF
/obj/item/weapon/gun/revolver/unique_action(mob/user)
	spin_cylinder(user)

/obj/item/weapon/gun/revolver/proc/revolver_basic_spin(mob/living/carbon/human/user, direction = 1, obj/item/weapon/gun/revolver/double)
	set waitfor = 0
	playsound(user, spin_sound, 25, 1)
	if(double)
		user.visible_message("[user] deftly flicks and spins [src] and [double]!",SPAN_NOTICE("You flick and spin [src] and [double]!"),  null, 3)
		animation_wrist_flick(double, 1)
	else 
		user.visible_message("[user] deftly flicks and spins [src]!",SPAN_NOTICE("You flick and spin [src]!"),  null, 3)

	animation_wrist_flick(src, direction)
	sleep(3)
	if(loc && user) playsound(user, thud_sound, 25, 1)

/obj/item/weapon/gun/revolver/proc/revolver_throw_catch(mob/living/carbon/human/user)
	set waitfor = 0
	user.visible_message("[user] deftly flicks [src] and tosses it into the air!", SPAN_NOTICE("You flick and toss [src] into the air!"), null, 3)
	var/img_layer = MOB_LAYER+0.1
	var/image/trick = image(icon,user,icon_state,img_layer)
	switch(pick(1,2))
		if(1) animation_toss_snatch(trick)
		if(2) animation_toss_flick(trick, pick(1,-1))

	invisibility = 100
	for(var/mob/M in viewers(user))
		to_chat(M, trick)
	sleep(5)
	trick.loc = null
	if(loc && user)
		invisibility = 0
		playsound(user, thud_sound, 25, 1)
		if(user.get_inactive_hand())
			user.visible_message("[user] catches [src] with the same hand!", SPAN_NOTICE("You catch [src] as it spins in to your hand!"), null, 3)
		else
			user.visible_message("[user] catches [src] with his other hand!", SPAN_NOTICE("You snatch [src] with your other hand! Awesome!"), null, 3)
			user.temp_drop_inv_item(src)
			user.put_in_inactive_hand(src)
			user.swap_hand()
			user.update_inv_l_hand(0)
			user.update_inv_r_hand()

/obj/item/weapon/gun/revolver/proc/revolver_trick(mob/living/carbon/human/user)
	if(world.time < (recent_trick + trick_delay) ) return //Don't spam it.
	if(!istype(user)) return //Not human.
	var/chance = -5
	chance = user.health < 6 ? 0 : user.health - 5

	//Pain is largely ignored, since it deals its own effects on the mob. We're just concerned with health.
	//And this proc will only deal with humans for now.

	var/obj/item/weapon/gun/revolver/double = user.get_inactive_hand()
	if(prob(chance))
		switch(rand(1,8))
			if(1)
				revolver_basic_spin(user, -1)
			if(2)
				revolver_basic_spin(user, 1)
			if(3)
				revolver_throw_catch(user)
			if(4)
				revolver_basic_spin(user, 1)
			if(5)
				//???????????
			if(6)
				var/arguments[] = istype(double) ? list(user, 1, double) : list(user, -1)
				revolver_basic_spin(arglist(arguments))

			if(7)
				var/arguments[] = istype(double) ? list(user, -1, double) : list(user, 1)
				revolver_basic_spin(arglist(arguments))
			if(8)
				if(istype(double))
					spawn(0)
						double.revolver_throw_catch(user)
					revolver_throw_catch(user)
				else
					revolver_throw_catch(user)
	else
		if(prob(10)) 
			to_chat(user, SPAN_WARNING("You fumble with [src] like an idiot... Uncool."))
		else 
			user.visible_message(SPAN_INFO("<b>[user]</b> fumbles with [src] like a huge idiot!"), null, null, 3)

	recent_trick = world.time //Turn on the delay for the next trick.

//-------------------------------------------------------
//M44 Revolver

/obj/item/weapon/gun/revolver/m44
	name = "\improper M44 combat revolver"
	desc = "A bulky revolver, occasionally carried by assault troops and officers in the Colonial Marines, as well civilian law enforcement. Fires .44 Magnum rounds."
	icon_state = "m44r"
	item_state = "m44r"
	current_mag = /obj/item/ammo_magazine/internal/revolver/m44
	force = 8
	flags_gun_features = GUN_INTERNAL_MAG|GUN_CAN_POINTBLANK|GUN_ONE_HAND_WIELDED|GUN_AMMO_COUNTER
	attachable_allowed = list(
						/obj/item/attachable/bayonet,
						/obj/item/attachable/reddot,
						/obj/item/attachable/reflex,
						/obj/item/attachable/flashlight,
						/obj/item/attachable/heavy_barrel,
						/obj/item/attachable/quickfire,
						/obj/item/attachable/extended_barrel,
						/obj/item/attachable/compensator,
						/obj/item/attachable/stock/revolver,
						/obj/item/attachable/scope,
						/obj/item/attachable/lasersight,
						/obj/item/attachable/scope/mini,
						/obj/item/attachable/scope/mini_iff)
	var/folded = FALSE // Used for the stock attachment, to check if we can shoot or not

/obj/item/weapon/gun/revolver/m44/New()
	..()
	attachable_offset = list("muzzle_x" = 27, "muzzle_y" = 21,"rail_x" = 12, "rail_y" = 23, "under_x" = 21, "under_y" = 18, "stock_x" = 16, "stock_y" = 20)

/obj/item/weapon/gun/revolver/m44/set_gun_config_values()
	..()
	fire_delay = config.mhigh_fire_delay
	accuracy_mult = config.base_hit_accuracy_mult
	accuracy_mult_unwielded = config.base_hit_accuracy_mult - config.low_hit_accuracy_mult
	scatter = config.low_scatter_value
	scatter_unwielded = config.high_scatter_value
	damage_mult = config.base_hit_damage_mult
	recoil = config.min_recoil_value
	recoil_unwielded = config.med_recoil_value


/obj/item/weapon/gun/revolver/m44/able_to_fire(mob/user)
	if (folded)
		to_chat(user, SPAN_NOTICE("You need to unfold the stock to fire!"))
		return 0
	else
		return ..()

//-------------------------------------------------------
//RUSSIAN REVOLVER //Based on the 7.62mm Russian revolvers.

/obj/item/weapon/gun/revolver/upp
	name = "\improper N-Y 7.62mm revolver"
	desc = "The Nagant-Yamasaki 7.62 is an effective killing machine designed by a consortion of shady Not-Americans. It is frequently found in the hands of criminals or mercenaries."
	icon_state = "ny762"
	item_state = "ny762"
	origin_tech = "combat=3;materials=1;syndicate=3"
	fire_sound = 'sound/weapons/gun_pistol_medium.ogg'
	current_mag = /obj/item/ammo_magazine/internal/revolver/upp
	force = 8
	attachable_allowed = list(/obj/item/attachable/compensator)

/obj/item/weapon/gun/revolver/upp/New()
	..()
	attachable_offset = list("muzzle_x" = 28, "muzzle_y" = 21,"rail_x" = 14, "rail_y" = 23, "under_x" = 24, "under_y" = 19, "stock_x" = 24, "stock_y" = 19)

/obj/item/weapon/gun/revolver/upp/set_gun_config_values()
	..()
	fire_delay = config.low_fire_delay
	accuracy_mult = config.base_hit_accuracy_mult
	accuracy_mult_unwielded = config.base_hit_accuracy_mult - config.med_hit_accuracy_mult
	scatter = config.med_scatter_value
	scatter_unwielded = config.high_scatter_value
	damage_mult = config.base_hit_damage_mult + config.min_hit_damage_mult
	recoil = 0
	recoil_unwielded = 0


//-------------------------------------------------------
//357 REVOLVER //Based on the generic S&W 357.

/obj/item/weapon/gun/revolver/small
	name = "\improper S&W .357 revolver"
	desc = "A lean .357 made by Smith & Wesson. A timeless classic, from antiquity to the future."
	icon_state = "sw357"
	item_state = "ny762" //PLACEHOLDER
	fire_sound = 'sound/weapons/gun_pistol_medium.ogg'
	current_mag = /obj/item/ammo_magazine/internal/revolver/small
	force = 6

/obj/item/weapon/gun/revolver/small/New()
	..()
	attachable_offset = list("muzzle_x" = 30, "muzzle_y" = 19,"rail_x" = 12, "rail_y" = 21, "under_x" = 20, "under_y" = 15, "stock_x" = 20, "stock_y" = 15)

/obj/item/weapon/gun/revolver/small/set_gun_config_values()
	..()
	fire_delay = config.low_fire_delay
	accuracy_mult = config.base_hit_accuracy_mult
	accuracy_mult_unwielded = config.base_hit_accuracy_mult - config.low_hit_accuracy_mult
	scatter = config.med_scatter_value
	scatter_unwielded = config.med_scatter_value
	damage_mult = config.base_hit_damage_mult
	recoil = 0
	recoil_unwielded = 0

/obj/item/weapon/gun/revolver/small/unique_action(mob/user)
	revolver_trick(user)

//-------------------------------------------------------
//BURST REVOLVER //Mateba is pretty well known. The cylinder folds up instead of to the side.

/obj/item/weapon/mateba_key
	name = "mateba barrel key"
	desc = "Used to swap the barrels of a mateba revolver."
	icon = 'icons/obj/items/items.dmi'
	icon_state = "matebakey"
	flags_atom = FPRINT|CONDUCT
	force = 5.0
	w_class = SIZE_TINY
	throwforce = 5.0
	throw_speed = 3
	throw_range = 5
	attack_verb = list("stabbed")

/obj/item/weapon/gun/revolver/mateba
	name = "\improper Mateba autorevolver"
	desc = "The Mateba is a powerful, fast-firing revolver that uses its own recoil to rotate the cylinders. It uses heavy .454 rounds."
	icon_state = "mateba"
	item_state = "mateba"
	origin_tech = "combat=4;materials=3"
	fire_sound = 'sound/weapons/gun_mateba.ogg'
	current_mag = /obj/item/ammo_magazine/internal/revolver/mateba
	force = 15
	attachable_allowed = list(
						/obj/item/attachable/reddot,
						/obj/item/attachable/reflex,
						/obj/item/attachable/flashlight,
						/obj/item/attachable/heavy_barrel,
						/obj/item/attachable/quickfire,
						/obj/item/attachable/compensator,
						/obj/item/attachable/mateba,
						/obj/item/attachable/mateba/long,
						/obj/item/attachable/mateba/short)
	var/default_barrel = /obj/item/attachable/mateba

/obj/item/weapon/gun/revolver/mateba/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/weapon/mateba_key))
		if(attachments["special"])
			var/obj/item/attachable/R = attachments["special"]
			visible_message(SPAN_NOTICE("[user] begins stripping [R] from [src]."),
			SPAN_NOTICE("You begin stripping [R] from [src]."), null, 4)

			if(!do_after(usr, 35, INTERRUPT_ALL, BUSY_ICON_FRIENDLY))
				return

			if(!(R == attachments[R.slot]))
				return

			visible_message(SPAN_NOTICE("[user] unlocks and removes [R] from [src]."),
			SPAN_NOTICE("You unlocks removes [R] from [src]."), null, 4)
			R.Detach(src)
			if(attachments["muzzle"])
				var/obj/item/attachable/M = attachments["muzzle"]
				M.Detach(src)
			playsound(src, 'sound/handling/attachment_remove.ogg', 15, 1, 4)
			update_icon()
	else if(istype(I, /obj/item/attachable))
		var/obj/item/attachable/A = I
		if(A.slot == "muzzle" && !attachments["special"])
			to_chat(user, SPAN_WARNING("You need to attach a barrel first!"))
			return
	. = ..()

/obj/item/weapon/gun/revolver/mateba/New()
	..()
	attachable_offset = list("muzzle_x" = 25, "muzzle_y" = 20,"rail_x" = 11, "rail_y" = 24, "under_x" = 19, "under_y" = 17, "stock_x" = 19, "stock_y" = 17, "special_x" = 23, "special_y" = 22)
	var/obj/item/attachable/mateba/Q = new default_barrel(src)
	Q.Attach(src)
	update_icon()

/obj/item/weapon/gun/revolver/mateba/set_gun_config_values()
	..()
	fire_delay = config.max_fire_delay
	burst_amount = config.low_burst_value
	burst_delay = config.med_fire_delay
	accuracy_mult = config.base_hit_accuracy_mult
	accuracy_mult_unwielded = config.base_hit_accuracy_mult - config.hmed_hit_accuracy_mult
	scatter = config.med_scatter_value
	burst_scatter_mult = config.med_scatter_value
	scatter_unwielded = config.med_scatter_value
	damage_mult = config.base_hit_damage_mult + config.min_hit_damage_mult
	recoil = config.min_recoil_value
	recoil_unwielded = config.med_recoil_value



/obj/item/weapon/gun/revolver/mateba/admiral
	name = "\improper Mateba autorevolver custom++"
	desc = "The Mateba is a powerful, fast-firing revolver that uses its own recoil to rotate the cylinders. This version is snubnosed, engraved with gold, tinted black, and highly customized for a high-ranking admiral. It uses heavy .454 rounds."
	icon_state = "amateba"
	item_state = "amateba"
	attachable_allowed = list(
					/obj/item/attachable/reddot,
					/obj/item/attachable/reflex,
					/obj/item/attachable/flashlight,
					/obj/item/attachable/heavy_barrel,
					/obj/item/attachable/quickfire,
					/obj/item/attachable/compensator,
					/obj/item/attachable/mateba/dark,
					/obj/item/attachable/mateba/long/dark,
					/obj/item/attachable/mateba/short/dark)
	default_barrel = /obj/item/attachable/mateba/dark

/obj/item/weapon/gun/revolver/mateba/engraved
	name = "\improper Mateba autorevolver engraved"
	desc = "The Mateba is a powerful, fast-firing revolver that uses its own recoil to rotate the cylinders. We have all heard of it, but on this version you glance a scratched engraving, barely readable. Is it your name?"
	icon_state = "aamateba"
	item_state = "aamateba"

/obj/item/weapon/gun/revolver/mateba/cmateba
	name = "\improper Mateba autorevolver special"
	desc = "The Mateba is a powerful, fast-firing revolver that uses its own recoil to rotate the cylinders. It uses heavy .454 rounds. This version is a limited edition produced for the USCM, and issued in extremely small amounts. Was a mail-order item back in 2172, and is highly sought after by officers across many different battalions. This one is stamped 'Major Ike Saker, 7th 'Falling Falcons' Battalion.'"
	icon_state = "cmateba"
	item_state = "cmateba"
	New()
		..()
		select_gamemode_skin(/obj/item/weapon/gun/revolver/mateba/cmateba)
//-------------------------------------------------------
//MARSHALS REVOLVER //Spearhead exists in Alien cannon.

/obj/item/weapon/gun/revolver/cmb
	name = "\improper CMB Spearhead autorevolver"
	desc = "An automatic revolver chambered in .357. Commonly issued to Colonial Marshals. It has three select fire options, safe, single, and burst."
	icon_state = "spearhead"
	item_state = "spearhead"
	fire_sound = 'sound/weapons/gun_44mag2.ogg'
	current_mag = /obj/item/ammo_magazine/internal/revolver/cmb
	force = 12
	attachable_allowed = list(
						/obj/item/attachable/reddot,
						/obj/item/attachable/reflex,
						/obj/item/attachable/flashlight,
						/obj/item/attachable/extended_barrel,
						/obj/item/attachable/heavy_barrel,
						/obj/item/attachable/quickfire,
						/obj/item/attachable/compensator)

/obj/item/weapon/gun/revolver/cmb/New()
	..()
	attachable_offset = list("muzzle_x" = 29, "muzzle_y" = 22,"rail_x" = 11, "rail_y" = 25, "under_x" = 20, "under_y" = 18, "stock_x" = 20, "stock_y" = 18)

/obj/item/weapon/gun/revolver/cmb/set_gun_config_values()
	..()
	fire_delay = config.mhigh_fire_delay*2
	burst_amount = config.med_burst_value
	burst_delay = config.high_fire_delay
	accuracy_mult = config.base_hit_accuracy_mult
	accuracy_mult_unwielded = config.base_hit_accuracy_mult - config.med_hit_accuracy_mult
	scatter = config.med_scatter_value
	scatter_unwielded = config.med_scatter_value
	damage_mult = config.base_hit_damage_mult + config.min_hit_damage_mult
	recoil = config.min_recoil_value
	recoil_unwielded = config.med_recoil_value
